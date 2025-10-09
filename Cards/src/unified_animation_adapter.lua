-- unified_animation_adapter.lua
-- Compatibility layer bridging legacy AnimationManager interface to unified system

local Class = require 'libs.HUMP.class'
local Timer = require 'libs.HUMP.timer'
local Config = require 'src.config'
local UnifiedAnimationManager = require('src.unified_animation_manager')

local UnifiedAnimationAdapter = Class{}

function UnifiedAnimationAdapter:init()
    self.unifiedManager = UnifiedAnimationManager()
    self.legacyManager = nil
    self.migrationEnabled = true -- Re-enabled after confirming legacy system works
    
    -- HUMP timer for animation monitoring
    self.timer = Timer.new()
    
    -- Create compatibility layer for existing AnimationManager interface
    self.queue = {} -- Legacy interface expects this
    
    -- Initialize legacy manager immediately if migration is disabled
    if not self.migrationEnabled then
        self:createMinimalLegacyManager()
    end
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Animation adapter initialized")
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
    if Config and Config.debug then
        print("[UnifiedAdapter] Update called with dt:", string.format("%.4f", dt))
    end
    
    -- Safety check for abnormal dt values
    if dt > 1.0 then
        if Config and Config.debug then
            print("[UnifiedAdapter] Warning: Large dt value detected:", dt, "- clamping to 1.0")
        end
        dt = 1.0
    end
    
    if dt <= 0 then
        if Config and Config.debug then
            print("[UnifiedAdapter] Skipping update - invalid dt:", dt)
        end
        return
    end
    
    -- Update HUMP timer
    self.timer:update(dt)
    
    -- Update unified system
    if Config and Config.debug then
        print("[UnifiedAdapter] Calling unifiedManager:update(dt)")
    end
    self.unifiedManager:update(dt)
    
    -- Update legacy system if present
    if self.legacyManager then
        self.legacyManager:update(dt)
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
        print("[UnifiedAdapter] ERROR: No card provided to handleCardFlightAnimation")
        return 
    end
    
    if not self.migrationEnabled then
        if self.legacyManager then
            return self.legacyManager:add(anim)
        else
            print("[UnifiedAdapter] ERROR: Migration disabled but no legacy manager!")
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
        print("[UnifiedAdapter] ERROR: No card provided to handleUnifiedCardPlayAnimation")
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
    
    -- Start full unified animation pipeline
    local animation = self.unifiedManager:playCard(card, anim.targetX, anim.targetY, "unified", anim.onComplete)
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
    -- For now, pass through to legacy system if available
    if self.legacyManager then
        return self.legacyManager:add(anim)
    end
    -- TODO: Convert to unified glow system when implemented
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
end

function UnifiedAnimationAdapter:reset()
    self:clear()
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Reset complete")
    end
end

-- Bridge method to get active animating cards from unified manager
function UnifiedAnimationAdapter:getActiveAnimatingCards()
    if self.unifiedManager then
        return self.unifiedManager:getActiveAnimatingCards()
    end
    return {}
end

return UnifiedAnimationAdapter