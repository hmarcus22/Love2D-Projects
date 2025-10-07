-- Animation Builder: Centralized parameter building for card play animations
-- Follows DEV_NOTES pattern: logic/ contains no Love2D calls, returns data structures

local AnimationBuilder = {}
local Config = require "src.config"

-- Build complete animation sequence for card play (flight -> impact -> glow -> optional delay)
function AnimationBuilder.buildCardPlaySequence(gameState, card, slotIndex, onAdvanceTurn)
    local player = card.owner
    local slot = player.boardSlots[slotIndex]
    
    -- Get positions
    local fromX, fromY = card.x, card.y
    local targetX, targetY = gameState:getBoardSlotPosition(player.id, slotIndex)
    
    -- Build flight parameters from config + specs
    local flightParams = AnimationBuilder._buildFlightParams(card)
    
    -- Create placement completion handler
    local placed = false
    local function onFlightComplete()
        if placed then return end
        placed = true
        slot._incoming = nil
        slot.card = card
        card.animX = nil; card.animY = nil
        gameState:placeCardWithoutAdvancing(player, card, slotIndex)
        gameState.currentPlayer = player.id
        gameState:updateCardVisibility()
        
        -- Queue impact sequence if enabled
        if Config.ui.cardImpactEnabled and gameState.animations then
            local impactAnim = AnimationBuilder._buildImpactAnimation(gameState, card, slotIndex, onAdvanceTurn)
            gameState.animations:add(impactAnim)
        else
            onAdvanceTurn()
        end
    end
    
    -- Build flight animation
    local flightAnim = {
        type = "card_flight",
        card = card,
        fromX = fromX, fromY = fromY,
        toX = targetX, toY = targetY,
        duration = flightParams.duration,
        arcHeight = flightParams.arcHeight,
        overshootFactor = flightParams.overshoot,
        slamStyle = flightParams.slamStyle,
        verticalMode = flightParams.verticalMode,
        onComplete = onFlightComplete
    }
    
    return { flightAnim }
end

-- Build flight parameters from config + animation specs
function AnimationBuilder._buildFlightParams(card)
    local duration = (Config.ui and Config.ui.cardFlightDuration) or 0.35
    local overshoot = (Config.ui and Config.ui.cardFlightOvershoot) or 0
    local arcHeightBase = (Config.ui and Config.ui.cardFlightArcHeight) or 140
    local slamStyle = false
    local verticalMode = nil
    
    -- Apply per-card spec overrides if enabled
    if Config.ui.useAnimationOverrides then
        local AnimSpecs = require 'src.animation_specs'
        local spec = AnimSpecs.getCardSpec(card.id)
        if spec and spec.flight then
            duration = spec.flight.duration or duration
            overshoot = spec.flight.overshoot or overshoot
            if spec.flight.arcScale and spec.flight.arcScale ~= 1 then
                arcHeightBase = arcHeightBase * spec.flight.arcScale
            end
            if spec.flight.slamStyle then slamStyle = true end
            verticalMode = spec.flight.verticalMode
        end
    end
    
    -- Determine final arc height
    local arcHeight = 0
    if (Config.ui and Config.ui.cardFlightCurve == 'arc') or slamStyle then
        arcHeight = arcHeightBase
    end
    
    return {
        duration = duration,
        overshoot = overshoot,
        arcHeight = arcHeight,
        slamStyle = slamStyle,
        verticalMode = verticalMode
    }
end

-- Build impact animation with FX triggers and completion handling
function AnimationBuilder._buildImpactAnimation(gameState, card, slotIndex, onAdvanceTurn)
    local player = card.owner
    local impactParams = AnimationBuilder._buildImpactParams(card)
    
    local function onImpactStart()
        -- Special FX for certain cards
        if card.id == 'body_slam' then
            local ImpactFX = require 'src.impact_fx'
            local sx, sy = gameState:getBoardSlotPosition(player.id, slotIndex)
            ImpactFX.triggerShake(gameState, impactParams.shakeDur or 0.25, impactParams.shakeMag or 6)
            ImpactFX.triggerDust(gameState, sx + card.w/2, sy + card.h - 8, impactParams.dustCount or 1)
        end
        
        -- NEW: Trigger knockback effects
        local AnimationSpecs = require 'src.animation_specs'
        local BoardEffects = require 'src.effects.board_effects'
        local spec = AnimationSpecs.getCardSpec(card.id)
        if spec and spec.knockback and spec.knockback.enabled then
            -- CORE LOGIC: Calculate impact coordinates
            local sx, sy = gameState:getBoardSlotPosition(player.id, slotIndex)
            local impactX = sx + card.w/2
            local impactY = sy + card.h/2
            
            -- CORE LOGIC: Find opponent board
            local opponentBoard = nil
            for _, p in pairs(gameState.players) do
                if p.id ~= player.id then
                    opponentBoard = p.boardSlots
                    break
                end
            end
            
            if opponentBoard then
                -- CORE LOGIC: Determine fade behavior
                local shouldFadeOut = (card.id == 'body_slam')
                -- CORE LOGIC: Trigger knockback system
                BoardEffects.triggerKnockback(card, impactX, impactY, opponentBoard, spec.knockback, shouldFadeOut, gameState)
            end
        end
    end
    
    local function onImpactComplete()
        -- Queue slot glow
        local slotX, slotY = gameState:getBoardSlotPosition(player.id, slotIndex)
        local glowAnim = {
            type = 'slot_glow',
            duration = (Config.ui.cardSlotGlowDuration or 0.35),
            maxAlpha = (Config.ui.cardSlotGlowAlpha or 0.55),
            slot = { x = slotX, y = slotY, w = card.w, h = card.h }
        }
        gameState.animations:add(glowAnim)
        
        -- Optional hold delay before advancing turn
        local hold = impactParams.holdExtra or 0
        if hold > 0 and gameState.animations then
            local delayAnim = { type = "delay", duration = hold, onComplete = onAdvanceTurn }
            gameState.animations:add(delayAnim)
        else
            onAdvanceTurn()
        end
    end
    
    return {
        type = "card_impact",
        card = card,
        gameState = gameState,
        duration = impactParams.duration,
        squashScale = impactParams.squashScale,
        flashAlpha = impactParams.flashAlpha,
        onStart = onImpactStart,
        onComplete = onImpactComplete
    }
end

-- Build impact parameters from config + animation specs
function AnimationBuilder._buildImpactParams(card)
    local duration = (Config.ui.cardImpactDuration or 0.28)
    local squashScale = (Config.ui.cardImpactSquashScale or 0.85)
    local flashAlpha = (Config.ui.cardImpactFlashAlpha or 0.55)
    local holdExtra = (Config.ui.cardImpactHoldExtra or 0)
    local shakeDur = 0.25
    local shakeMag = 6
    local dustCount = 1
    
    -- Apply per-card spec overrides if enabled
    if Config.ui.useAnimationOverrides then
        local AnimSpecs = require 'src.animation_specs'
        local spec = AnimSpecs.getCardSpec(card.id)
        if spec and spec.impact then
            duration = spec.impact.duration or duration
            squashScale = spec.impact.squashScale or squashScale
            flashAlpha = spec.impact.flashAlpha or flashAlpha
            holdExtra = spec.impact.holdExtra or holdExtra
            shakeDur = spec.impact.shakeDur or shakeDur
            shakeMag = spec.impact.shakeMag or shakeMag
            dustCount = spec.impact.dustCount or dustCount
        end
    end
    
    return {
        duration = duration,
        squashScale = squashScale,
        flashAlpha = flashAlpha,
        holdExtra = holdExtra,
        shakeDur = shakeDur,
        shakeMag = shakeMag,
        dustCount = dustCount
    }
end

return AnimationBuilder