-- unified_animation_adapter.lua
-- Migration adapter that connects the unified animation system with existing game logic

local Class = require 'libs.HUMP.class'
local Timer = require 'libs.HUMP.timer'
local UnifiedAnimationManager = require('src.unified_animation_manager')
local Config = require('src.config')

local UnifiedAnimationAdapter = Class{}

function UnifiedAnimationAdapter:init()
    if Config and Config.debug then
        print("[UnifiedAdapter] Starting adapter initialization...")
    end
    
    self.unifiedManager = UnifiedAnimationManager()
    self.legacyManager = nil
    self.migrationEnabled = true -- Re-enabled after confirming legacy system works
    
    -- HUMP timer for animation monitoring
    if Config and Config.debug then
        print("[UnifiedAdapter] Creating adapter timer...")
    end
    self.timer = Timer.new()
    
    -- Create compatibility layer for existing AnimationManager interface
    self.queue = {} -- Legacy interface expects this
    
    -- Initialize legacy manager immediately if migration is disabled
    if not self.migrationEnabled then
        self:createMinimalLegacyManager()
    end
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Initialized animation adapter")
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

-- Update both systems
function UnifiedAnimationAdapter:update(dt)
    -- Update timer for animation monitoring
    self.timer:update(dt)
    
    self.unifiedManager:update(dt)
    
    if self.legacyManager then
        self.legacyManager:update(dt)
    end
end

-- Legacy add() method - convert to unified system or pass to legacy
function UnifiedAnimationAdapter:add(anim)
    if Config and Config.debug then
        print("[UnifiedAdapter] ADD CALLED! Type:", anim.type, "Migration enabled:", self.migrationEnabled)
    end
    
    if not self.migrationEnabled and self.legacyManager then
        return self.legacyManager:add(anim)
    end
    
    -- Handle different animation types
    if anim.type == "card_flight" then
        if Config and Config.debug then
            print("[UnifiedAdapter] Routing to handleCardFlightAnimation")
        end
        self:handleCardFlightAnimation(anim)
    elseif anim.type == "unified_card_play" then
        if Config and Config.debug then
            print("[UnifiedAdapter] Routing to handleUnifiedCardPlayAnimation")
        end
        self:handleUnifiedCardPlayAnimation(anim)
    elseif anim.type == "slot_glow" then
        self:handleSlotGlowAnimation(anim)
    else
        if Config and Config.debug then
            print("[UnifiedAdapter] Unknown animation type:", anim.type)
        end
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
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Converting card_flight animation for card:", card.id or "unknown")
        print("  From:", anim.fromX, anim.fromY, "To:", anim.toX, anim.toY)
        print("  Migration enabled:", self.migrationEnabled)
    end
    
    if not self.migrationEnabled then
        if Config and Config.debug then
            print("[UnifiedAdapter] Migration disabled - using legacy system")
        end
        if self.legacyManager then
            return self.legacyManager:add(anim)
        else
            print("[UnifiedAdapter] ERROR: Migration disabled but no legacy manager!")
            return
        end
    end
    
    -- Start unified animation with callback
    local animation = self.unifiedManager:playCard(card, anim.toX, anim.toY, "card_flight", anim.onComplete)
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Started unified animation:", animation and "SUCCESS" or "FAILED")
    end
end

-- Handle new unified card play animation with full 8-phase system
function UnifiedAnimationAdapter:handleUnifiedCardPlayAnimation(anim)
    local card = anim.card
    if not card then 
        print("[UnifiedAdapter] ERROR: No card provided to handleUnifiedCardPlayAnimation")
        return 
    end
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Starting unified card play animation for card:", card.id or "unknown")
        print("  Full 8-phase pipeline enabled")
        print("  From:", anim.fromX, anim.fromY, "To:", anim.targetX, anim.targetY)
    end
    
    if not self.migrationEnabled then
        if Config and Config.debug then
            print("[UnifiedAdapter] Migration disabled - falling back to legacy flight")
        end
        -- Convert to legacy card_flight format
        local legacyAnim = {
            type = "card_flight",
            card = card,
            fromX = anim.fromX,
            fromY = anim.fromY,
            toX = anim.targetX,
            toY = anim.targetY,
            duration = anim.flight.duration,
            arcHeight = anim.flight.trajectory.height,
            onComplete = anim.onComplete
        }
        return self:handleCardFlightAnimation(legacyAnim)
    end
    
    -- Start full unified animation pipeline
    local animation = self.unifiedManager:playCard(card, anim.targetX, anim.targetY, "unified", anim.onComplete)
    
    if Config and Config.debug then
        print("[UnifiedAdapter] Started full unified animation:", animation and "SUCCESS" or "FAILED")
    end
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
    
    -- Start monitoring after a brief delay to ensure animation has started
    self.timer:after(0.016, checkCompletion)
end

-- Handle slot glow animations (keep in legacy for now)
function UnifiedAnimationAdapter:handleSlotGlowAnimation(anim)
    if self.legacyManager then
        self.legacyManager:add(anim)
    else
        -- Create minimal legacy manager just for glow effects
        self:createMinimalLegacyManager()
        self.legacyManager:add(anim)
    end
end

-- Create minimal legacy manager for unsupported animations
function UnifiedAnimationAdapter:createMinimalLegacyManager()
    local AnimationManager = require('src.animation_manager')
    self.legacyManager = AnimationManager.new()
    if Config and Config.debug then
        print("[UnifiedAdapter] Created minimal legacy manager for unsupported animations")
    end
end

-- Legacy isBusy() compatibility
function UnifiedAnimationAdapter:isBusy()
    local unifiedBusy = self.unifiedManager:isResolvePlaying() or 
                       self:hasActiveFlightAnimations()
    
    local legacyBusy = self.legacyManager and self.legacyManager:isBusy() or false
    
    return unifiedBusy or legacyBusy
end

-- Check if unified system has active flight animations
function UnifiedAnimationAdapter:hasActiveFlightAnimations()
    local status = self.unifiedManager:getStatus()
    return status.flightAnimations > 0
end

-- Legacy draw() compatibility
function UnifiedAnimationAdapter:draw()
    -- Draw legacy animations (like slot glow)
    if self.legacyManager then
        self.legacyManager:draw()
    end
    
    -- Unified system handles its own drawing through card renderer integration
    -- No additional drawing needed here
end

-- UNIFIED SYSTEM METHODS
-- These provide direct access to unified features

function UnifiedAnimationAdapter:addCardToBoard(card)
    self.unifiedManager:addCardToBoard(card)
end

function UnifiedAnimationAdapter:removeCardFromBoard(card)
    self.unifiedManager:removeCardFromBoard(card)
end

function UnifiedAnimationAdapter:setCardHover(card, enabled)
    self.unifiedManager:setCardHover(card, enabled)
end

function UnifiedAnimationAdapter:setCardSelected(card, enabled)
    self.unifiedManager:setCardSelected(card, enabled)
end

function UnifiedAnimationAdapter:setCardDragging(card, enabled)
    self.unifiedManager:setCardDragging(card, enabled)
end

function UnifiedAnimationAdapter:startAttackAnimation(attackCard, targetCard)
    return self.unifiedManager:startAttackAnimation(attackCard, targetCard)
end

function UnifiedAnimationAdapter:startDefenseAnimation(defendCard, attackCard)
    return self.unifiedManager:startDefenseAnimation(defendCard, attackCard)
end

-- MIGRATION CONTROL

function UnifiedAnimationAdapter:enableMigration(enabled)
    self.migrationEnabled = enabled
    
    if Config and Config.debug then
        if enabled then
            print("[UnifiedAdapter] Migration enabled - using unified animation system")
        else
            print("[UnifiedAdapter] Migration disabled - falling back to legacy system")
        end
    end
    
    if not enabled and not self.legacyManager then
        self:createMinimalLegacyManager()
    end
end

function UnifiedAnimationAdapter:setDebugMode(enabled)
    self.unifiedManager:setDebugMode(enabled)
end

function UnifiedAnimationAdapter:getStatus()
    local unified = self.unifiedManager:getStatus()
    local legacy = {
        enabled = self.legacyManager ~= nil,
        queueLength = self.legacyManager and #self.legacyManager.queue or 0
    }
    
    return {
        migration = self.migrationEnabled,
        unified = unified,
        legacy = legacy
    }
end

function UnifiedAnimationAdapter:printStatus()
    local status = self:getStatus()
    
    print("[UnifiedAdapter] Status:")
    print("  Migration Enabled:", status.migration)
    print("  Unified System:", status.unified.enabled and "ACTIVE" or "INACTIVE")
    print("    Flight Animations:", status.unified.flightAnimations)
    print("    Board State Cards:", status.unified.boardStateCards) 
    print("    Resolve Animations:", status.unified.resolveAnimations)
    print("  Legacy System:", status.legacy.enabled and "ACTIVE" or "INACTIVE")
    print("    Queue Length:", status.legacy.queueLength)
end

-- ADVANCED INTEGRATION

-- Convert AnimationBuilder results to unified system
function UnifiedAnimationAdapter:processAnimationBuilderSequence(animSequence)
    if not animSequence or #animSequence == 0 then return end
    
    for _, anim in ipairs(animSequence) do
        self:add(anim)
    end
end

-- Integration with card placement system
function UnifiedAnimationAdapter:playCardToBoard(card, slotIndex, gameState, onComplete)
    local player = card.owner
    local targetX, targetY = gameState:getBoardSlotPosition(player.id, slotIndex)
    
    -- Enhanced callback that handles board state
    local enhancedCallback = function()
        if Config and Config.debug then
            print("[UnifiedAdapter] Animation completed, executing callback")
        end
        
        -- Place card normally
        if onComplete then
            local success, err = pcall(onComplete)
            if not success then
                print("[UnifiedAdapter] ERROR in original onComplete callback:", err)
            end
        end
        
        -- Add to unified board state system
        local success, err = pcall(function()
            self:addCardToBoard(card)
        end)
        if not success then
            print("[UnifiedAdapter] ERROR in addCardToBoard:", err)
        else
            if Config and Config.debug then
                print("[UnifiedAdapter] Card placed and added to board state system")
            end
        end
    end
    
    -- Create flight animation with enhanced callback
    local flightAnim = {
        type = "card_flight",
        card = card,
        fromX = card.x,
        fromY = card.y,
        toX = targetX,
        toY = targetY,
        onComplete = enhancedCallback
    }
    
    self:add(flightAnim)
end

-- Cleanup and reset
function UnifiedAnimationAdapter:reset()
    self.unifiedManager:reset()
    
    if self.legacyManager then
        -- Clear legacy queue
        self.legacyManager.queue = {}
    end
    
    print("[UnifiedAdapter] Reset complete")
end

return UnifiedAnimationAdapter