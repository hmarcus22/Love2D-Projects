-- unified_animation_manager.lua
-- Coordinates all animation systems (flight, board state, resolve)

local Class = require 'libs.HUMP.class'
local Timer = require 'libs.HUMP.timer'
local Config = require 'src.config'
local UnifiedAnimationEngine = require('src.unified_animation_engine')
local BoardStateAnimator = require('src.board_state_animator')
local ResolveAnimator = require('src.resolve_animator')

local UnifiedAnimationManager = Class{}

-- PERFORMANCE: Disable debug output to prevent console hang
local DEBUG_MANAGER = false -- Set to true only when debugging manager issues

-- Debug print wrapper to easily disable all manager debug output
local function debugPrint(...)
    if DEBUG_MANAGER then
        print(...)
    end
end

function UnifiedAnimationManager:init()
    debugPrint("[UnifiedAnimManager] Initializing animation system...")
    
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
    
    debugPrint("[UnifiedAnimManager] Animation system initialized and ENABLED")
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
            debugPrint("[UnifiedAnimManager] Warning: Large dt value detected:", dt, "- clamping to 1.0")
        end
        dt = 1.0
    end
    
    if dt <= 0 then
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Warning: Invalid dt value:", dt, "- skipping update")
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
function UnifiedAnimationManager:playCard(card, targetX, targetY, animationType, callback, options)
    animationType = animationType or "unified" -- Use unified spec by default
    
    if not self.enabled then
        if callback then callback() end
        return false
    end
    
    debugPrint("[UnifiedAnimManager] playCard called:")
    debugPrint("  Card:", card and card.id or "nil")
    debugPrint("  Target:", targetX, targetY)
    debugPrint("  Type:", animationType)
    debugPrint("  Callback:", callback and "present" or "nil")
    
    local config = {
        targetX = targetX,
        targetY = targetY,
        gameState = self.gameState, -- Include gameState for impact effects
        onComplete = callback
    }
    -- Forward optional animation style to engine spec resolver
    if options and options.animationStyle then
        config.animationStyle = options.animationStyle
    end
    -- Forward early-placement callback for landing handoff
    if options and options.onPlace then
        config.onPlace = options.onPlace
    end
    
    local result = self.flightEngine:startAnimation(card, animationType, config)
    debugPrint("  Result:", result and "SUCCESS" or "FAILED")
    
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
        debugPrint("[UnifiedAnimManager] Connected to legacy animation manager")
    end
end

-- Fallback to legacy system if unified animation not available
function UnifiedAnimationManager:playCardLegacy(card, targetX, targetY, callback)
    if self.legacyAnimationManager then
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Falling back to legacy animation")
        end
        return self.legacyAnimationManager:playCard(card, targetX, targetY, callback)
    else
        debugPrint("[UnifiedAnimManager] No legacy manager available")
        if callback then callback() end
    end
end

-- MIGRATION HELPERS
-- These help transition from the old system to the new unified system

function UnifiedAnimationManager:migrateFromLegacy(enabled)
    if enabled then
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Migration enabled - using unified system")
        end
        self.enabled = true
    else
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Migration disabled - using legacy system")
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
            debugPrint("[UnifiedAnimManager] Debug mode enabled")
        end
    else
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Debug mode disabled")
        end
    end
end

-- Test animations in sequence
function UnifiedAnimationManager:runAnimationTest(card)
    if not card then
        debugPrint("[UnifiedAnimManager] No card provided for test")
        return
    end
    
    if Config and Config.debug then
        debugPrint("[UnifiedAnimManager] Running animation test sequence...")
    end
    
    -- Test flight animation
    local targetX = card.x + 200
    local targetY = card.y - 50
    
    self:playCard(card, targetX, targetY, "test_flight")
    if Config and Config.debug then
        debugPrint("[UnifiedAnimManager] Started flight animation")
    end
    
    -- After flight completes, add to board
    self.timer:after(2.0, function()
        self:addCardToBoard(card)
        if Config and Config.debug then
            debugPrint("[UnifiedAnimManager] Added to board state")
        end
        
        -- Test interaction states with proper timing
        self.timer:after(1.0, function()
            self:setCardHover(card, true)
            if Config and Config.debug then
                debugPrint("[UnifiedAnimManager] Applied hover state")
            end
            
            self.timer:after(0.5, function()
                self:setCardSelected(card, true)
                if Config and Config.debug then
                    debugPrint("[UnifiedAnimManager] Applied selected state")
                end
                
                self.timer:after(0.5, function()
                    self:setCardDragging(card, true)
                    if Config and Config.debug then
                        debugPrint("[UnifiedAnimManager] Applied dragging state")
                    end
                    
                    self.timer:after(1.0, function()
                        self:setCardDragging(card, false)
                        debugPrint("[UnifiedAnimManager] Removed dragging state")
                        
                        -- Test resolve animation
                        self.timer:after(0.5, function()
                            self:startAttackAnimation(card, nil)
                            debugPrint("[UnifiedAnimManager] Started attack animation")
                            debugPrint("[UnifiedAnimManager] Animation test sequence complete")
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
    
    debugPrint("[UnifiedAnimManager] Status:")
    debugPrint("  Enabled:", status.enabled)
    debugPrint("  Debug Mode:", status.debugMode)
    debugPrint("  Flight Animations:", status.flightAnimations)
    debugPrint("  Board State Cards:", status.boardStateCards)
    debugPrint("  Resolve Animations:", status.resolveAnimations)
end

-- CLEANUP METHODS
function UnifiedAnimationManager:stopAllAnimations()
    debugPrint("[UnifiedAnimManager] Stopping all animations")
    
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
    debugPrint("[UnifiedAnimManager] Resetting animation system")
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

-- RENDER BRIDGE: Get list of cards currently being animated
-- This method is called by Player:drawHand() to determine which cards should be rendered
-- with their animated positions during flight phases. It queries the UnifiedAnimationEngine
-- for active animations and extracts the card objects for rendering purposes.
-- Flow: Player:drawHand() -> gs.animations:getActiveAnimatingCards() -> this method -> UnifiedAnimationEngine
function UnifiedAnimationManager:getActiveAnimatingCards()
    local animatingCards = {}
    
    -- Check flight engine for actively animating cards
    if self.flightEngine and self.flightEngine.getActiveAnimations then
        local activeAnimations = self.flightEngine:getActiveAnimations()
        if activeAnimations then
            for _, animation in pairs(activeAnimations) do
                if animation.card then
                    table.insert(animatingCards, animation.card)
                end
            end
        end
    end
    
    return animatingCards
end

-- Extended variant: include phase info per active animation
function UnifiedAnimationManager:getActiveAnimationEntries()
    local entries = {}
    if self.flightEngine and self.flightEngine.getActiveAnimations then
        local activeAnimations = self.flightEngine:getActiveAnimations()
        if activeAnimations then
            for _, animation in pairs(activeAnimations) do
                if animation.card then
                    entries[#entries+1] = { card = animation.card, phase = animation.currentPhase }
                end
            end
        end
    end
    return entries
end

-- Report whether any time-blocking animations are active
-- Considers flight and resolve animations; excludes board-idle effects
function UnifiedAnimationManager:hasActiveAnimations()
    if self.flightEngine and self.flightEngine.activeAnimations then
        for _ in pairs(self.flightEngine.activeAnimations) do
            return true
        end
    end
    if self.resolveAnimator and self.resolveAnimator.hasActiveAnimations and self.resolveAnimator:hasActiveAnimations() then
        return true
    end
    return false
end

return UnifiedAnimationManager
