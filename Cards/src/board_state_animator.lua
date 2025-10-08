-- board_state_animator.lua
-- Manages ongoing animations for cards while they're on the board

local Class = require 'libs.HUMP.class'
local BoardStateAnimator = Class{}

function BoardStateAnimator:init()
    self.activeCards = {}
    self.animationSpecs = require('src.unified_animation_specs')
    self.time = 0
    self.debugMode = false
end

-- Add a card to board state animation management
function BoardStateAnimator:addCard(card)
    if not card then return end
    
    local spec = self:getCardBoardSpec(card)
    if not spec then return end
    
    local cardState = {
        card = card,
        spec = spec,
        originalX = card.x,
        originalY = card.y,
        originalScale = card.scale or 1.0,
        startTime = self.time,
        idleState = {
            breathingPhase = 0,
            hoverPhase = 0
        },
        conditions = {},
        interactions = {
            isHovered = false,
            isSelected = false,
            isDragging = false
        }
    }
    
    self.activeCards[card] = cardState
    
    if self.debugMode then
        print("[BoardState] Added card:", card.id or "unknown")
    end
end

-- Remove a card from board state animation
function BoardStateAnimator:removeCard(card)
    if self.activeCards[card] then
        -- Reset card to original state
        local state = self.activeCards[card]
        card.scale = state.originalScale
        card.x = state.originalX
        card.y = state.originalY
        
        self.activeCards[card] = nil
        
        if self.debugMode then
            print("[BoardState] Removed card:", card.id or "unknown")
        end
    end
end

-- Update all board state animations
function BoardStateAnimator:update(dt)
    self.time = self.time + dt
    
    for card, state in pairs(self.activeCards) do
        self:updateCardState(state, dt)
    end
end

-- Update animation state for a single card
function BoardStateAnimator:updateCardState(state, dt)
    local card = state.card
    local spec = state.spec
    
    -- Update idle animations
    self:updateIdleAnimations(state, dt)
    
    -- Update conditional animations
    self:updateConditionalAnimations(state, dt)
    
    -- Update interaction animations
    self:updateInteractionAnimations(state, dt)
end

-- Update idle animations (breathing, hover)
function BoardStateAnimator:updateIdleAnimations(state, dt)
    local card = state.card
    local spec = state.spec
    
    if not spec.idle then return end
    
    -- Breathing animation
    if spec.idle.breathing and spec.idle.breathing.enabled then
        local breathing = spec.idle.breathing
        state.idleState.breathingPhase = state.idleState.breathingPhase + dt * breathing.frequency
        
        local breathingScale = 1 + math.sin(state.idleState.breathingPhase * 2 * math.pi) * breathing.amplitude
        card.scale = state.originalScale * breathingScale
    end
    
    -- Hover animation (subtle vertical movement)
    if spec.idle.hover and spec.idle.hover.enabled then
        local hover = spec.idle.hover
        state.idleState.hoverPhase = state.idleState.hoverPhase + dt * hover.frequency
        
        local hoverOffset = math.sin(state.idleState.hoverPhase * 2 * math.pi) * hover.amplitude
        card.y = state.originalY + hoverOffset
    end
end

-- Update conditional animations based on game state
function BoardStateAnimator:updateConditionalAnimations(state, dt)
    local card = state.card
    local spec = state.spec
    
    if not spec.conditional then return end
    
    -- Check for impending doom condition
    if self:checkImpendingDoom(card) then
        self:applyImpendingDoomAnimation(state, dt)
    end
    
    -- Check for charging condition
    if self:checkCharging(card) then
        self:applyChargingAnimation(state, dt)
    end
    
    -- Check for shielding condition
    if self:checkShielding(card) then
        self:applyShieldingAnimation(state, dt)
    end
    
    -- Check for disabled condition
    if self:checkDisabled(card) then
        self:applyDisabledAnimation(state, dt)
    end
end

-- Check if card is in impending doom state
function BoardStateAnimator:checkImpendingDoom(card)
    -- Example: Card will be destroyed next turn or represents a threat
    if card.definition then
        local cardId = card.definition.id
        -- Cards that might signal danger
        if cardId == "wild_swing" or cardId == "uppercut" or cardId == "roundhouse" then
            -- Check if opponent has no valid counters
            -- This is a simplified check - real implementation would check game state
            return math.random() < 0.3 -- 30% chance for demo
        end
    end
    return false
end

-- Apply impending doom animation
function BoardStateAnimator:applyImpendingDoomAnimation(state, dt)
    local card = state.card
    local spec = state.spec.conditional.impending_doom
    
    if spec and spec.shake_and_jump then
        local shake = spec.shake_and_jump
        local phase = self.time * shake.frequency
        
        -- Shake effect
        local shakeX = math.sin(phase * 15) * shake.shake_intensity
        local shakeY = math.cos(phase * 18) * shake.shake_intensity
        
        -- Jump effect
        local jumpOffset = math.abs(math.sin(phase * 2 * math.pi)) * shake.jump_height
        
        card.x = state.originalX + shakeX
        card.y = state.originalY + shakeY - jumpOffset
    end
end

-- Check if card is charging/powering up
function BoardStateAnimator:checkCharging(card)
    if card.definition then
        local cardId = card.definition.id
        -- Cards that might be charging for next turn
        if cardId == "adrenaline_rush" or cardId == "rally" then
            return true
        end
    end
    return false
end

-- Apply charging animation
function BoardStateAnimator:applyChargingAnimation(state, dt)
    local card = state.card
    local spec = state.spec.conditional.charging
    
    if spec and spec.energy_pulse then
        local pulse = spec.energy_pulse
        local phase = self.time * pulse.frequency
        
        -- Pulsing scale effect
        local pulseScale = pulse.scale_min + (pulse.scale_max - pulse.scale_min) * 
                          (math.sin(phase * 2 * math.pi) * 0.5 + 0.5)
        card.scale = state.originalScale * pulseScale
        
        -- Store glow intensity for renderer
        card.glowIntensity = pulse.glow_intensity * (math.sin(phase * 2 * math.pi) * 0.5 + 0.5)
    end
end

-- Check if card is in protective/shielding state
function BoardStateAnimator:checkShielding(card)
    if card.definition then
        local cardId = card.definition.id
        if cardId == "guard" or cardId == "block" or cardId == "counter" then
            return true
        end
    end
    return false
end

-- Apply shielding animation
function BoardStateAnimator:applyShieldingAnimation(state, dt)
    local card = state.card
    local spec = state.spec.conditional.shielding
    
    if spec and spec.protective_stance then
        local stance = spec.protective_stance
        local phase = self.time * stance.pulse_frequency
        
        -- Steady protective scale
        card.scale = state.originalScale * stance.scale
        
        -- Gentle protective pulse
        local pulseBrightness = stance.brightness * (1 + math.sin(phase * 2 * math.pi) * 0.1)
        card.brightness = pulseBrightness
    end
end

-- Check if card is disabled
function BoardStateAnimator:checkDisabled(card)
    -- Check if card is exhausted, stunned, or otherwise disabled
    return card.exhausted or card.stunned or false
end

-- Apply disabled animation
function BoardStateAnimator:applyDisabledAnimation(state, dt)
    local card = state.card
    local spec = state.spec.conditional.disabled
    
    if spec and spec.dimmed then
        local dimmed = spec.dimmed
        
        card.brightness = dimmed.brightness
        card.saturation = dimmed.saturation
        card.y = state.originalY + dimmed.slight_droop
    end
end

-- Update interaction animations
function BoardStateAnimator:updateInteractionAnimations(state, dt)
    local card = state.card
    local spec = state.spec
    
    if not spec.interaction then return end
    
    -- These would be triggered by input system
    if state.interactions.isHovered then
        self:applyHoverAnimation(state, dt)
    elseif state.interactions.isSelected then
        self:applySelectedAnimation(state, dt)
    elseif state.interactions.isDragging then
        self:applyDraggingAnimation(state, dt)
    end
end

-- Apply hover animation
function BoardStateAnimator:applyHoverAnimation(state, dt)
    local card = state.card
    local spec = state.spec.interaction.hover
    
    if spec then
        -- Smooth transition to hover state
        local targetScale = state.originalScale * spec.scale
        local targetY = state.originalY - spec.elevation
        
        card.scale = card.scale + (targetScale - card.scale) * dt / spec.transition_time
        card.y = card.y + (targetY - card.y) * dt / spec.transition_time
    end
end

-- Apply selected animation
function BoardStateAnimator:applySelectedAnimation(state, dt)
    local card = state.card
    local spec = state.spec.interaction.selected
    
    if spec then
        local targetScale = state.originalScale * spec.scale
        local targetY = state.originalY - spec.elevation
        
        card.scale = card.scale + (targetScale - card.scale) * dt / spec.transition_time
        card.y = card.y + (targetY - card.y) * dt / spec.transition_time
        
        if spec.glow then
            card.isSelected = true -- Signal to renderer to draw glow
        end
    end
end

-- Apply dragging animation
function BoardStateAnimator:applyDraggingAnimation(state, dt)
    local card = state.card
    local spec = state.spec.interaction.dragging
    
    if spec then
        card.scale = state.originalScale * spec.scale
        card.animZ = spec.elevation
        
        if spec.tilt then
            card.rotation = math.rad(spec.tilt)
        end
        
        if spec.trail then
            card.hasTrail = true -- Signal to renderer
        end
    end
end

-- Set interaction state for a card
function BoardStateAnimator:setCardInteraction(card, interactionType, enabled)
    local state = self.activeCards[card]
    if not state then return end
    
    -- Reset all interactions first
    state.interactions.isHovered = false
    state.interactions.isSelected = false
    state.interactions.isDragging = false
    
    -- Set the specified interaction
    if interactionType == "hover" then
        state.interactions.isHovered = enabled
    elseif interactionType == "selected" then
        state.interactions.isSelected = enabled
    elseif interactionType == "dragging" then
        state.interactions.isDragging = enabled
    end
end

-- Get animation specification for a card
function BoardStateAnimator:getCardBoardSpec(card)
    local specs = self.animationSpecs
    if not specs then return nil end
    
    -- Check for card-specific override
    local cardId = card.definition and card.definition.id
    if cardId and specs.cards and specs.cards[cardId] then
        local cardSpec = specs.cards[cardId]
        if cardSpec.board_state then
            return cardSpec.board_state
        elseif cardSpec.baseStyle then
            local baseSpec = specs.styles[cardSpec.baseStyle]
            if baseSpec and baseSpec.board_state then
                return baseSpec.board_state
            end
        end
    end
    
    -- Use default unified spec
    return specs.unified.board_state
end

-- Enable/disable debug mode
function BoardStateAnimator:setDebugMode(enabled)
    self.debugMode = enabled
end

-- Clear all animations
function BoardStateAnimator:clear()
    for card, _ in pairs(self.activeCards) do
        self:removeCard(card)
    end
end

return BoardStateAnimator