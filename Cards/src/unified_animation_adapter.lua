-- unified_animation_adapter.lua
-- Compatibility layer bridging legacy AnimationManager interface to unified system
--
-- ANIMATION ARCHITECTURE OVERVIEW:
-- ================================
-- GameState (gs.animations) -> UnifiedAnimationAdapter (this file) -> UnifiedAnimationManager -> UnifiedAnimationEngine
--
-- KEY METHODS FOR RENDERING:
-- - getActiveAnimatingCards(): Critical bridge method that allows Player:drawHand() to detect and render
--   cards that are currently animating. Without this method, cards animate invisibly in the background.
-- 
-- FLOW FOR CARD FLIGHT ANIMATIONS:
-- 1. Card played -> UnifiedAnimationEngine stores animation in activeAnimations table
-- 2. Player:drawHand() calls gs.animations:getActiveAnimatingCards() 
-- 3. This adapter delegates to UnifiedAnimationManager:getActiveAnimatingCards()
-- 4. Manager queries UnifiedAnimationEngine:getActiveAnimations() 
-- 5. Engine returns activeAnimations table (CRITICAL: was returning wrong table before fix)
-- 6. Cards are rendered with their animated positions during flight phases

local Class = require 'libs.HUMP.class'
local Timer = require 'libs.HUMP.timer'
local Config = require 'src.config'
local UnifiedAnimationManager = require('src.unified_animation_manager')
local UnifiedSpecs = require('src.unified_animation_specs')

local UnifiedAnimationAdapter = Class{}

-- PERFORMANCE: Disable debug output to prevent console hang  
local DEBUG_ADAPTER = false -- Set to true only when debugging adapter issues

-- Debug print wrapper to easily disable all adapter debug output
local function debugPrint(...)
    if DEBUG_ADAPTER then
        print(...)
    end
end

function UnifiedAnimationAdapter:init()
    self.unifiedManager = UnifiedAnimationManager()
    self.legacyManager = nil
    self.migrationEnabled = true -- Re-enabled after confirming legacy system works
    
    -- HUMP timer for animation monitoring
    self.timer = Timer.new()
    
    -- Create compatibility layer for existing AnimationManager interface
    self.queue = {} -- Legacy interface expects this
    -- Local effect storage for unified-only UI effects (e.g., slot glow)
    self.slotGlows = {}
    
    -- Initialize legacy manager immediately if migration is disabled
    if not self.migrationEnabled then
        self:createMinimalLegacyManager()
    end
    
    if Config and Config.debug then
        debugPrint("[UnifiedAdapter] Animation adapter initialized")
    end
end

-- Legacy AnimationManager.new() compatibility
function UnifiedAnimationAdapter.new()
    return UnifiedAnimationAdapter()
end

-- Set gameState reference for impact effects
function UnifiedAnimationAdapter:setGameState(gameState)
    self.unifiedManager:setGameState(gameState)
end

-- Update both unified and legacy systems
function UnifiedAnimationAdapter:update(dt)
    debugPrint("[UnifiedAdapter] Update called with dt:", string.format("%.4f", dt))
    
    -- Clamp dt via shared util
    local Util = require 'src.animation_util'
    dt = Util.clampDt(dt)
    if dt <= 0 then return end
    
    -- Update HUMP timer
    self.timer:update(dt)
    
    -- Update unified system
    debugPrint("[UnifiedAdapter] Calling unifiedManager:update(dt)")
    self.unifiedManager:update(dt)

    -- Update legacy system if present
    if self.legacyManager then
        self.legacyManager:update(dt)
    end

    -- Update local UI effects (slot glow timeline)
    if self.slotGlows and #self.slotGlows > 0 then
        for i = #self.slotGlows, 1, -1 do
            local g = self.slotGlows[i]
            g.t = (g.t or 0) + dt
            if g.t >= (g.duration or 0.35) then
                table.remove(self.slotGlows, i)
            end
        end
    end
end

-- Main animation entry point - routes to appropriate system
function UnifiedAnimationAdapter:add(anim)
    if not self.migrationEnabled and self.legacyManager then
        return self.legacyManager:add(anim)
    end
    
    -- Handle different animation types
    if anim.type == "card_flight" then
        self:handleCardFlightAnimation(anim)
    elseif anim.type == "unified_card_play" then
        self:handleUnifiedCardPlayAnimation(anim)
    elseif anim.type == "slot_glow" then
        self:handleSlotGlowAnimation(anim)
    elseif anim.type == "delay" then
        -- Unified handling of passive wait animations
        local d = math.max(0, anim.duration or 0)
        if d <= 0 then
            if anim.onComplete then pcall(anim.onComplete) end
            return
        end
        self.timer:after(d, function()
            if anim.onComplete then pcall(anim.onComplete) end
        end)
    else
        -- Unknown type, pass to legacy if available
        if self.legacyManager then
            return self.legacyManager:add(anim)
        end
    end
end

-- Convert legacy card_flight animation to unified system
function UnifiedAnimationAdapter:handleCardFlightAnimation(anim)
    local card = anim.card
    if not card then 
        debugPrint("[UnifiedAdapter] ERROR: No card provided to handleCardFlightAnimation")
        return 
    end
    
    if not self.migrationEnabled then
        if self.legacyManager then
            return self.legacyManager:add(anim)
        else
            debugPrint("[UnifiedAdapter] ERROR: Migration disabled but no legacy manager!")
            return
        end
    end
    
    -- Start unified animation with callback
    local animation = self.unifiedManager:playCard(card, anim.toX, anim.toY, "card_flight", anim.onComplete)
end

-- Handle new unified card play animation with full 8-phase system
function UnifiedAnimationAdapter:handleUnifiedCardPlayAnimation(anim)
    local card = anim.card
    if not card then 
        debugPrint("[UnifiedAdapter] ERROR: No card provided to handleUnifiedCardPlayAnimation")
        return 
    end
    
    if not self.migrationEnabled then
        -- Convert to legacy card_flight format
        local legacyAnim = {
            type = "card_flight",
            card = card,
            fromX = anim.fromX,
            fromY = anim.fromY,
            toX = anim.targetX,
            toY = anim.targetY,
            duration = anim.flight and anim.flight.duration or 1.0,
            arcHeight = anim.flight and anim.flight.trajectory and anim.flight.trajectory.height or 100,
            onComplete = anim.onComplete
        }
        return self:handleCardFlightAnimation(legacyAnim)
    end
    
    -- Start full unified animation pipeline (forward optional style)
    local options = { }
    if anim.animationStyle then options.animationStyle = anim.animationStyle end
    if anim.onPlace then options.onPlace = anim.onPlace end
    if anim.onHandCommit then options.onHandCommit = anim.onHandCommit end
    -- Forward game context for special effects (knockback, etc.)
    if anim.gameState then options.gameState = anim.gameState end
    if anim.player then options.player = anim.player end
    if anim.slotIndex then options.slotIndex = anim.slotIndex end
    local animation = self.unifiedManager:playCard(card, anim.targetX, anim.targetY, "unified", anim.onComplete, options)
end

-- Monitor flight animation completion and trigger callback
function UnifiedAnimationAdapter:monitorFlightCompletion(animation, callback)
    if not animation or not callback then
        if callback then callback() end
        return
    end
    
    -- Use HUMP timer to check animation completion periodically
    local function checkCompletion()
        if not self.unifiedManager:isCardAnimating(animation.card) then
            callback()
        else
            -- Check again next frame
            self.timer:after(0.016, checkCompletion)
        end
    end
    
    -- Start monitoring
    checkCompletion()
end

-- Handle slot glow animations (legacy compatibility)
function UnifiedAnimationAdapter:handleSlotGlowAnimation(anim)
    -- Unified UI effect: store lightweight timeline for adapter:draw()
    local ui = (UnifiedSpecs and UnifiedSpecs.ui and UnifiedSpecs.ui.slot_glow) or {}
    local glow = {
        t = 0,
        duration = anim.duration or ui.duration or 0.35,
        maxAlpha = anim.maxAlpha or ui.maxAlpha or 0.55,
        lineWidth = anim.lineWidth or ui.lineWidth or 4,
        radius = anim.radius or ui.radius or 12,
        inset = anim.inset or ui.inset or 4,
        easing = anim.easing or ui.easing or 'easeOutQuad',
        color = anim.color or ui.color or {1, 1, 0.4},
        slot = anim.slot -- expected: { x, y, w, h }
    }
    if glow.slot and glow.slot.x and glow.slot.y and glow.slot.w and glow.slot.h then
        table.insert(self.slotGlows, glow)
    end
end

-- Create minimal legacy manager for fallback
function UnifiedAnimationAdapter:createMinimalLegacyManager()
    self.legacyManager = {
        queue = {},
        add = function(self, anim) table.insert(self.queue, anim) end,
        update = function(self, dt) end
    }
end

-- Legacy compatibility methods
function UnifiedAnimationAdapter:isBusy()
    return self.unifiedManager and self.unifiedManager:hasActiveAnimations() or false
end

function UnifiedAnimationAdapter:clear()
    if self.unifiedManager then
        self.unifiedManager:stopAllAnimations()
    end

    if self.legacyManager then
        self.legacyManager.queue = {}
    end

    -- Clear local UI effects
    self.slotGlows = {}
end

function UnifiedAnimationAdapter:reset()
    self:clear()
    
    if Config and Config.debug then
        debugPrint("[UnifiedAdapter] Reset complete")
    end
end

-- Passthroughs to unified manager for board-state and interaction APIs
function UnifiedAnimationAdapter:addCardToBoard(card)
    if self.unifiedManager and self.unifiedManager.addCardToBoard then
        return self.unifiedManager:addCardToBoard(card)
    end
end

function UnifiedAnimationAdapter:removeCardFromBoard(card)
    if self.unifiedManager and self.unifiedManager.removeCardFromBoard then
        return self.unifiedManager:removeCardFromBoard(card)
    end
end

function UnifiedAnimationAdapter:setCardHover(card, enabled)
    if self.unifiedManager and self.unifiedManager.setCardHover then
        return self.unifiedManager:setCardHover(card, enabled)
    end
end

function UnifiedAnimationAdapter:setCardSelected(card, enabled)
    if self.unifiedManager and self.unifiedManager.setCardSelected then
        return self.unifiedManager:setCardSelected(card, enabled)
    end
end

function UnifiedAnimationAdapter:setCardDragging(card, enabled)
    if self.unifiedManager and self.unifiedManager.setCardDragging then
        return self.unifiedManager:setCardDragging(card, enabled)
    end
end

function UnifiedAnimationAdapter:enableMigration(enabled)
    self.migrationEnabled = enabled and true or false
    if self.unifiedManager and self.unifiedManager.migrateFromLegacy then
        self.unifiedManager:migrateFromLegacy(enabled)
    end
end

function UnifiedAnimationAdapter:setDebugMode(enabled)
    if self.unifiedManager and self.unifiedManager.setDebugMode then
        self.unifiedManager:setDebugMode(enabled)
    end
end

function UnifiedAnimationAdapter:printStatus()
    if self.unifiedManager and self.unifiedManager.printStatus then
        self.unifiedManager:printStatus()
    end
end

-- CRITICAL: Bridge method to get active animating cards from unified manager
-- This method is essential for Player:drawHand() to detect and render animating cards.
-- Without this, cards animate in the background but are not visually displayed during flight.
-- The method delegates to UnifiedAnimationManager which queries the UnifiedAnimationEngine.
function UnifiedAnimationAdapter:getActiveAnimatingCards()
    if self.unifiedManager then
        return self.unifiedManager:getActiveAnimatingCards()
    end
    return {}
end

-- Extended variant for renderers needing phase context
function UnifiedAnimationAdapter:getActiveAnimationEntries()
    if self.unifiedManager and self.unifiedManager.getActiveAnimationEntries then
        return self.unifiedManager:getActiveAnimationEntries()
    end
    return {}
end

-- Adapter-level draw for unified UI effects (engine/animators do not draw)
function UnifiedAnimationAdapter:draw()
    if not self.slotGlows or #self.slotGlows == 0 then return end
    for _, g in ipairs(self.slotGlows) do
        local p = 0
        if (g.duration or 0) > 0 then p = math.min(1, (g.t or 0) / g.duration) end
        -- easing: easeOutQuad fallback
        local function easeOutQuad(t) return 1 - (1 - t) * (1 - t) end
        local easingFn = easeOutQuad
        if g.easing == 'linear' then easingFn = function(t) return t end end
        local k = 1 - easingFn(p) -- fade out over time
        local alpha = (g.maxAlpha or 0.55) * k
        if alpha > 0.01 then
            local inset = g.inset or 4
            local x = g.slot.x - inset
            local y = g.slot.y - inset
            local w = g.slot.w + inset * 2
            local h = g.slot.h + inset * 2
            local r = g.radius or 12
            local lw = g.lineWidth or 4
            local c = g.color or {1,1,0.4}
            love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 0.4, alpha)
            love.graphics.setLineWidth(lw)
            love.graphics.rectangle('line', x, y, w, h, r, r)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1,1,1,1)
        end
    end
end

-- Expose a simple timer helper for sequencing
function UnifiedAnimationAdapter:after(delay, fn)
    local d = math.max(0, tonumber(delay) or 0)
    if d == 0 then
        if fn then pcall(fn) end
        return
    end
    if self.timer then
        self.timer:after(d, function()
            if fn then pcall(fn) end
        end)
    elseif fn then
        pcall(fn)
    end
end

-- Resolve helpers: forward resolve animations used by resolve.lua
function UnifiedAnimationAdapter:startAttackAnimation(attackCard, target)
    if self.unifiedManager and self.unifiedManager.startAttackAnimation then
        return self.unifiedManager:startAttackAnimation(attackCard, target)
    end
end

function UnifiedAnimationAdapter:hasActiveAnimations()
    if self.unifiedManager and self.unifiedManager.hasActiveAnimations then
        return self.unifiedManager:hasActiveAnimations()
    end
    return false
end

-- Expose resolve animation start for custom sequences
function UnifiedAnimationAdapter:startResolveAnimation(card, animationType, targetCard)
    if not self.unifiedManager or not self.unifiedManager.resolveAnimator then return end
    return self.unifiedManager.resolveAnimator:startResolveAnimation(card, animationType, targetCard)
end

return UnifiedAnimationAdapter
