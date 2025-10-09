-- unified_animation_manager.lua
-- Coordinates all animation systems (flight, board state, resolve)

local Class = require 'libs.HUMP.class'
local Timer = require 'libs.HUMP.timer'
local Config = require 'src.config'
local UnifiedAnimationEngine = require('src.unified_animation_engine')
local BoardStateAnimator = require('src.board_state_animator')
local ResolveAnimator = require('src.resolve_animator')

local UnifiedAnimationManager = Class{}

function UnifiedAnimationManager:init()
    if Config and Config.debug then
        print("[UnifiedAnimManager] Initializing animation system...")
    end
    
    -- Initialize sub-systems
    self.flightEngine = UnifiedAnimationEngine()
    self.boardStateAnimator = BoardStateAnimator()
    self.resolveAnimator = ResolveAnimator()
    
    -- HUMP timer for animation sequencing
    self.timer = Timer.new()
    
    -- Global settings
    self.debugMode = false
    self.enabled = true -- Re-enabled now that freeze issue is resolved
    self.gameState = nil -- Will be set by adapter for impact effects
    
    -- Integration with existing animation manager
    self.legacyAnimationManager = nil -- Set during migration
    
    if Config and Config.debug then
        print("[UnifiedAnimManager] Animation system initialized and ENABLED")
    end
end

-- Set gameState reference for impact effects
function UnifiedAnimationManager:setGameState(gameState)
    self.gameState = gameState
end

-- Update all animation systems
function UnifiedAnimationManager:update(dt)
    if not self.enabled then return end
    
    -- Safety check for abnormal dt values that could cause infinite loops
    if dt > 1.0 then
        if Config and Config.debug then
            print("[UnifiedAnimManager] Warning: Large dt value detected:", dt, "- clamping to 1.0")
        end
        dt = 1.0
    end
    
    if dt <= 0 then
        if Config and Config.debug then
            print("[UnifiedAnimManager] Warning: Invalid dt value:", dt, "- skipping update")
        end
        return
    end
    
    -- Update HUMP timer for animation sequencing
    self.timer:update(dt)
    
    -- Update all animation subsystems
    self.flightEngine:update(dt)
    self.boardStateAnimator:update(dt)
    self.resolveAnimator:update(dt)
end

-- FLIGHT ANIMATIONS (card throwing)
function UnifiedAnimationManager:playCard(card, targetX, targetY, animationType, callback)
    animationType = animationType or "unified" -- Use unified spec by default
    
    if not self.enabled then
        if callback then callback() end
        return false
    end
    
    if Config and Config.debug then
        print("[UnifiedAnimManager] playCard called:")
        print("  Card:", card and card.id or "nil")
        print("  Target:", targetX, targetY)
        print("  Type:", animationType)
        print("  Callback:", callback and "present" or "nil")
    end
    
    local config = {
        targetX = targetX,
        targetY = targetY,
        gameState = self.gameState, -- Include gameState for impact effects
        onComplete = callback
    }
    
    local result = self.flightEngine:startAnimation(card, animationType, config)
    if Config and Config.debug then
        print("  Result:", result and "SUCCESS" or "FAILED")
    end
    
    return result
end

-- Stop flight animation for a card
function UnifiedAnimationManager:stopCardAnimation(card)
    self.flightEngine:stopAnimation(card)
end

-- Check if card has active flight animation
function UnifiedAnimationManager:isCardAnimating(card)
    return self.flightEngine:hasActiveAnimation(card)
end

-- BOARD STATE ANIMATIONS (ongoing card behavior)
function UnifiedAnimationManager:addCardToBoard(card)
    self.boardStateAnimator:addCard(card)
end

function UnifiedAnimationManager:removeCardFromBoard(card)
    self.boardStateAnimator:removeCard(card)
end

-- Set interaction state for board cards
function UnifiedAnimationManager:setCardHover(card, enabled)
    self.boardStateAnimator:setCardInteraction(card, "hover", enabled)
end

function UnifiedAnimationManager:setCardSelected(card, enabled)
    self.boardStateAnimator:setCardInteraction(card, "selected", enabled)
end

function UnifiedAnimationManager:setCardDragging(card, enabled)
    self.boardStateAnimator:setCardInteraction(card, "dragging", enabled)
end

-- RESOLVE ANIMATIONS (combat effects)
function UnifiedAnimationManager:startAttackAnimation(attackCard, targetCard)
    return self.resolveAnimator:startAttackStrike(attackCard, targetCard)
end

function UnifiedAnimationManager:startDefenseAnimation(defendCard, attackCard)
    return self.resolveAnimator:startDefensivePush(defendCard, attackCard)
end

-- Check if resolve animations are playing
function UnifiedAnimationManager:isResolvePlaying()
    return self.resolveAnimator:hasActiveAnimations()
end

-- Wait for resolve animations to complete
function UnifiedAnimationManager:waitForResolve(callback)
    if not self:isResolvePlaying() then
        if callback then callback() end
        return
    end
    
    -- Use HUMP timer to check again next frame
    self.timer:after(0.016, function()
        self:waitForResolve(callback)
    end)
end

-- LEGACY INTEGRATION METHODS
-- These provide compatibility with the existing animation system during migration

function UnifiedAnimationManager:setLegacyManager(legacyManager)
    self.legacyAnimationManager = legacyManager
    if Config and Config.debug then
        print("[UnifiedAnimManager] Connected to legacy animation manager")
    end
end

-- Fallback to legacy system if unified animation not available
function UnifiedAnimationManager:playCardLegacy(card, targetX, targetY, callback)
    if self.legacyAnimationManager then
        if Config and Config.debug then
            print("[UnifiedAnimManager] Falling back to legacy animation")
        end
        return self.legacyAnimationManager:playCard(card, targetX, targetY, callback)
    else
        print("[UnifiedAnimManager] No legacy manager available")
        if callback then callback() end
    end
end

-- MIGRATION HELPERS
-- These help transition from the old system to the new unified system

function UnifiedAnimationManager:migrateFromLegacy(enabled)
    if enabled then
        if Config and Config.debug then
            print("[UnifiedAnimManager] Migration enabled - using unified system")
        end
        self.enabled = true
    else
        if Config and Config.debug then
            print("[UnifiedAnimManager] Migration disabled - using legacy system")
        end
        self.enabled = false
    end
end

-- Convert legacy animation specs to unified format
function UnifiedAnimationManager:convertLegacySpec(legacySpec)
    -- This would convert old animation_specs format to unified format
    -- Implementation depends on the specific legacy format
    
    local unified = {
        preparation = {
            duration = legacySpec.prep_time or 0.3,
            scale = legacySpec.prep_scale or 1.1
        },
        flight = {
            duration = legacySpec.flight_time or 0.8,
            physics = {
                gravity = legacySpec.gravity or 980
            }
        }
    }
    
    return unified
end

-- DEBUG AND TESTING METHODS
function UnifiedAnimationManager:setDebugMode(enabled)
    self.debugMode = enabled
    self.flightEngine:setDebugMode(enabled)
    self.boardStateAnimator:setDebugMode(enabled)
    self.resolveAnimator:setDebugMode(enabled)
    
    if enabled then
        if Config and Config.debug then
            print("[UnifiedAnimManager] Debug mode enabled")
        end
    else
        if Config and Config.debug then
            print("[UnifiedAnimManager] Debug mode disabled")
        end
    end
end

-- Test animations in sequence
function UnifiedAnimationManager:runAnimationTest(card)
    if not card then
        print("[UnifiedAnimManager] No card provided for test")
        return
    end
    
    if Config and Config.debug then
        print("[UnifiedAnimManager] Running animation test sequence...")
    end
    
    -- Test flight animation
    local targetX = card.x + 200
    local targetY = card.y - 50
    
    self:playCard(card, targetX, targetY, "test_flight")
    if Config and Config.debug then
        print("[UnifiedAnimManager] Started flight animation")
    end
    
    -- After flight completes, add to board
    self.timer:after(2.0, function()
        self:addCardToBoard(card)
        if Config and Config.debug then
            print("[UnifiedAnimManager] Added to board state")
        end
        
        -- Test interaction states with proper timing
        self.timer:after(1.0, function()
            self:setCardHover(card, true)
            if Config and Config.debug then
                print("[UnifiedAnimManager] Applied hover state")
            end
            
            self.timer:after(0.5, function()
                self:setCardSelected(card, true)
                if Config and Config.debug then
                    print("[UnifiedAnimManager] Applied selected state")
                end
                
                self.timer:after(0.5, function()
                    self:setCardDragging(card, true)
                    if Config and Config.debug then
                        print("[UnifiedAnimManager] Applied dragging state")
                    end
                    
                    self.timer:after(1.0, function()
                        self:setCardDragging(card, false)
                        print("[UnifiedAnimManager] Removed dragging state")
                        
                        -- Test resolve animation
                        self.timer:after(0.5, function()
                            self:startAttackAnimation(card, nil)
                            print("[UnifiedAnimManager] Started attack animation")
                            print("[UnifiedAnimManager] Animation test sequence complete")
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- Get status of all animation systems
function UnifiedAnimationManager:getStatus()
    local status = {
        enabled = self.enabled,
        debugMode = self.debugMode,
        flightAnimations = 0,
        boardStateCards = 0,
        resolveAnimations = 0
    }
    
    -- Count active animations
    for card, _ in pairs(self.flightEngine.activeAnimations) do
        status.flightAnimations = status.flightAnimations + 1
    end
    
    for card, _ in pairs(self.boardStateAnimator.activeCards) do
        status.boardStateCards = status.boardStateCards + 1
    end
    
    status.resolveAnimations = #self.resolveAnimator.activeResolveAnimations
    
    return status
end

-- Print status to console
function UnifiedAnimationManager:printStatus()
    local status = self:getStatus()
    
    print("[UnifiedAnimManager] Status:")
    print("  Enabled:", status.enabled)
    print("  Debug Mode:", status.debugMode)
    print("  Flight Animations:", status.flightAnimations)
    print("  Board State Cards:", status.boardStateCards)
    print("  Resolve Animations:", status.resolveAnimations)
end

-- CLEANUP METHODS
function UnifiedAnimationManager:stopAllAnimations()
    print("[UnifiedAnimManager] Stopping all animations")
    
    -- Stop flight animations
    for card, _ in pairs(self.flightEngine.activeAnimations) do
        self.flightEngine:stopAnimation(card)
    end
    
    -- Clear board state animations
    self.boardStateAnimator:clear()
    
    -- Stop resolve animations
    self.resolveAnimator:stopAllAnimations()
end

function UnifiedAnimationManager:reset()
    print("[UnifiedAnimManager] Resetting animation system")
    self:stopAllAnimations()
    
    -- Reinitialize systems
    self.flightEngine = UnifiedAnimationEngine()
    self.boardStateAnimator = BoardStateAnimator()
    self.resolveAnimator = ResolveAnimator()
    
    -- Restore debug state
    if self.debugMode then
        self:setDebugMode(true)
    end
end

-- Get list of cards currently being animated
function UnifiedAnimationManager:getActiveAnimatingCards()
    local animatingCards = {}
    
    -- Check flight engine for actively animating cards
    if self.flightEngine and self.flightEngine.getActiveAnimations then
        local activeAnimations = self.flightEngine:getActiveAnimations()
        if activeAnimations then
            for cardId, animation in pairs(activeAnimations) do
                if animation.card then
                    table.insert(animatingCards, animation.card)
                end
            end
        end
    end
    
    return animatingCards
end

return UnifiedAnimationManager