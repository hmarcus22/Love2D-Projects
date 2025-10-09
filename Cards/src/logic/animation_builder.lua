-- Animation Builder: Centralized parameter building for card play animations
-- Follows DEV_NOTES pattern: logic/ contains no Love2D calls, returns data structures

local AnimationBuilder = {}
local Config = require "src.config"

-- Build complete animation sequence for card play using unified animation system
function AnimationBuilder.buildCardPlaySequence(gameState, card, slotIndex, onAdvanceTurn)
    local player = card.owner
    local slot = player.boardSlots[slotIndex]
    
    -- Get positions
    local fromX, fromY = card.x, card.y
    local targetX, targetY = gameState:getBoardSlotPosition(player.id, slotIndex)
    
    -- Create placement completion handler
    local placed = false
    local function onFlightComplete()
        if placed then return end
        placed = true
        slot._incoming = nil
        slot.card = card
        card.animX = nil; card.animY = nil
        
        -- Hand removal now happens immediately when animation starts, not here
        -- This prevents the card flickering back into hand during animation
        
        if onAdvanceTurn then onAdvanceTurn() end
    end
    
    -- Build unified animation sequence using the same simple approach as modifiers
    local unifiedAnim = {
        type = "unified_card_play",
        card = card,
        fromX = fromX,
        fromY = fromY,
        targetX = targetX,
        targetY = targetY,
        onComplete = onFlightComplete
        -- No animationStyle specified = use default unified animation
    }
    
    print("[DEBUG] buildCardPlaySequence created animation for card:", card.id or "unknown")
    print("[DEBUG] Animation type:", unifiedAnim.type)
    print("[DEBUG] From:", fromX, fromY, "To:", targetX, targetY)
    
    return { unifiedAnim }
end

-- Build animation sequence for modifier cards (fly to target, then disappear)
function AnimationBuilder.buildModifierPlaySequence(gameState, card, targetX, targetY, onComplete)
    -- Get positions
    local fromX, fromY = card.x, card.y
    
    -- Create completion handler that doesn't place the card
    local function onModifierFlightComplete()
        -- Remove any visual references to the card
        card.animX = nil
        card.animY = nil
        
        -- Call the provided completion callback
        if onComplete then onComplete() end
    end
    
    -- Build unified animation sequence with modifier style for fade effects
    local unifiedAnim = {
        type = "unified_card_play",
        card = card,
        fromX = fromX,
        fromY = fromY,
        targetX = targetX,
        targetY = targetY,
        onComplete = onModifierFlightComplete,
        
        -- Use modifier style for fade effects
        animationStyle = "modifier"
    }
    
    print("[DEBUG] buildModifierPlaySequence created animation for card:", card.id or "unknown")
    print("[DEBUG] Animation type:", unifiedAnim.type)
    print("[DEBUG] Animation style:", unifiedAnim.animationStyle)
    print("[DEBUG] From:", fromX, fromY, "To:", targetX, targetY)
    
    return { unifiedAnim }
end

-- Build flight parameters from unified animation specs (legacy function, kept for compatibility)
function AnimationBuilder._buildFlightParams(card)
    local UnifiedSpecs = require 'src.unified_animation_specs'
    
    -- Get base unified spec
    local baseSpec = UnifiedSpecs.unified
    local duration = baseSpec.flight.duration
    local arcHeight = baseSpec.flight.trajectory.height
    local overshoot = 0 -- Will be handled by approach phase
    local slamStyle = false
    local verticalMode = nil
    
    -- Apply card-specific overrides if they exist
    local cardSpec = UnifiedSpecs[card.id]
    if cardSpec and cardSpec.flight then
        duration = cardSpec.flight.duration or duration
        if cardSpec.flight.trajectory then
            arcHeight = cardSpec.flight.trajectory.height or arcHeight
            if cardSpec.flight.trajectory.type == "slam_drop" then
                slamStyle = true
            end
        end
    end
    
    -- Apply any dynamic overrides from tuner overlay
    if UnifiedSpecs._cardOverrides and UnifiedSpecs._cardOverrides[card.id] then
        local overrides = UnifiedSpecs._cardOverrides[card.id]
        if overrides.flight then
            duration = overrides.flight.duration or duration
            if overrides.flight.trajectory then
                arcHeight = overrides.flight.trajectory.height or arcHeight
            end
        end
    end
    
    -- Determine final arc height (always use arc for now to match old behavior)
    local finalArcHeight = arcHeight
    
    return {
        duration = duration,
        overshoot = overshoot,
        arcHeight = finalArcHeight,
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
        local UnifiedSpecs = require 'src.unified_animation_specs'
        local BoardEffects = require 'src.effects.board_effects'
        local hasKnockback = false
        
        -- Check unified specs for knockback capability
        if UnifiedSpecs.cards and UnifiedSpecs.cards[card.id] and 
           UnifiedSpecs.cards[card.id].game_resolve and 
           UnifiedSpecs.cards[card.id].game_resolve.area_knockback then
            hasKnockback = UnifiedSpecs.cards[card.id].game_resolve.area_knockback.enabled
        end
        
        if hasKnockback then
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
        local UnifiedSpecs = require 'src.unified_animation_specs'
        local spec = nil
        
        -- Check unified specs for impact parameters
        if UnifiedSpecs.cards and UnifiedSpecs.cards[card.id] and 
           UnifiedSpecs.cards[card.id].impact then
            spec = UnifiedSpecs.cards[card.id].impact
        elseif UnifiedSpecs.unified and UnifiedSpecs.unified.impact then
            spec = UnifiedSpecs.unified.impact
        end
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

-- Build unified animation sequence using the 8-phase system
function AnimationBuilder._buildUnifiedCardPlayAnimation(card, fromX, fromY, targetX, targetY, onComplete)
    local UnifiedSpecs = require 'src.unified_animation_specs'
    
    -- Get base unified spec and card-specific spec
    local baseSpec = UnifiedSpecs.unified
    local cardSpec = (UnifiedSpecs.cards and UnifiedSpecs.cards[card.id]) or {}
    
    -- Handle baseStyle merging if present
    local resolvedSpec = baseSpec
    if cardSpec.baseStyle and UnifiedSpecs.styles and UnifiedSpecs.styles[cardSpec.baseStyle] then
        -- Merge base style with card-specific overrides
        local styleSpec = UnifiedSpecs.styles[cardSpec.baseStyle]
        resolvedSpec = {}
        
        -- Deep copy base spec
        for phase, phaseData in pairs(baseSpec) do
            resolvedSpec[phase] = {}
            for key, value in pairs(phaseData) do
                if type(value) == "table" then
                    resolvedSpec[phase][key] = {}
                    for subKey, subValue in pairs(value) do
                        resolvedSpec[phase][key][subKey] = subValue
                    end
                else
                    resolvedSpec[phase][key] = value
                end
            end
        end
        
        -- Apply style spec overrides
        for phase, phaseData in pairs(styleSpec) do
            if not resolvedSpec[phase] then resolvedSpec[phase] = {} end
            for key, value in pairs(phaseData) do
                if type(value) == "table" then
                    if not resolvedSpec[phase][key] then resolvedSpec[phase][key] = {} end
                    for subKey, subValue in pairs(value) do
                        resolvedSpec[phase][key][subKey] = subValue
                    end
                else
                    resolvedSpec[phase][key] = value
                end
            end
        end
        
        -- Apply card-specific overrides on top
        for phase, phaseData in pairs(cardSpec) do
            if phase ~= "baseStyle" then -- Skip the baseStyle property itself
                if not resolvedSpec[phase] then resolvedSpec[phase] = {} end
                for key, value in pairs(phaseData) do
                    if type(value) == "table" then
                        if not resolvedSpec[phase][key] then resolvedSpec[phase][key] = {} end
                        for subKey, subValue in pairs(value) do
                            resolvedSpec[phase][key][subKey] = subValue
                        end
                    else
                        resolvedSpec[phase][key] = value
                    end
                end
            end
        end
    elseif cardSpec and next(cardSpec) then
        -- No baseStyle, just use card-specific overrides on base
        resolvedSpec = cardSpec
    end
    
    -- Apply any dynamic overrides from tuner overlay
    local dynamicOverrides = {}
    if UnifiedSpecs._cardOverrides and UnifiedSpecs._cardOverrides[card.id] then
        dynamicOverrides = UnifiedSpecs._cardOverrides[card.id]
    end
    
    -- Helper function to get effective value with priority: dynamic > resolved spec > default
    local function getValue(phase, path, defaultValue)
        -- Check dynamic overrides first
        if dynamicOverrides[phase] then
            local current = dynamicOverrides[phase]
            for segment in path:gmatch("[^%.]+") do
                if current[segment] == nil then break end
                current = current[segment]
            end
            if current ~= nil then return current end
        end
        
        -- Check resolved spec (includes baseStyle merging)
        if resolvedSpec[phase] then
            local current = resolvedSpec[phase]
            for segment in path:gmatch("[^%.]+") do
                if current[segment] == nil then return defaultValue end
                current = current[segment]
            end
            return current
        end
        
        return defaultValue
    end
    
    -- Build unified animation configuration
    return {
        type = "unified_card_play",
        card = card,
        fromX = fromX,
        fromY = fromY,
        targetX = targetX,
        targetY = targetY,
        onComplete = onComplete,
        
        -- Phase configurations
        preparation = {
            duration = getValue('preparation', 'duration', 0.3),
            scale = getValue('preparation', 'scale', 1.1),
            elevation = getValue('preparation', 'elevation', 5),
            rotation = getValue('preparation', 'rotation', -5),
            easing = getValue('preparation', 'easing', "easeOutQuad")
        },
        
        launch = {
            duration = getValue('launch', 'duration', 0.2),
            angle = getValue('launch', 'angle', 25),
            initialVelocity = getValue('launch', 'initialVelocity', 800),
            acceleration = getValue('launch', 'acceleration', 200),
            easing = getValue('launch', 'easing', "easeOutCubic")
        },
        
        flight = {
            duration = getValue('flight', 'duration', 0.35),
            physics = {
                gravity = getValue('flight', 'physics.gravity', 980),
                airResistance = getValue('flight', 'physics.airResistance', 0.02),
                mass = getValue('flight', 'physics.mass', 1.0)
            },
            trajectory = {
                type = getValue('flight', 'trajectory.type', "ballistic"),
                height = getValue('flight', 'trajectory.height', 140)
            },
            effects = {
                trail = {
                    enabled = getValue('flight', 'effects.trail.enabled', true),
                    length = getValue('flight', 'effects.trail.length', 5),
                    fadeTime = getValue('flight', 'effects.trail.fadeTime', 0.3)
                },
                rotation = {
                    tumble = getValue('flight', 'effects.rotation.tumble', true),
                    speed = getValue('flight', 'effects.rotation.speed', 1.5)
                }
            }
        },
        
        approach = {
            duration = getValue('approach', 'duration', 0.3),
            guidingFactor = getValue('approach', 'guidingFactor', 0.5),
            anticipation = {
                scale = getValue('approach', 'anticipation.scale', 1.2),
                rotation = getValue('approach', 'anticipation.rotation', 10)
            },
            easing = getValue('approach', 'easing', "easeOutQuart")
        },
        
        impact = {
            duration = getValue('impact', 'duration', 0.4),
            collision = {
                squash = getValue('impact', 'collision.squash', 0.85),
                bounce = getValue('impact', 'collision.bounce', 1.3),
                restitution = getValue('impact', 'collision.restitution', 0.6)
            },
            effects = {
                screen = {
                    shake = {
                        intensity = getValue('impact', 'effects.screen.shake.intensity', 6),
                        duration = getValue('impact', 'effects.screen.shake.duration', 0.25),
                        frequency = getValue('impact', 'effects.screen.shake.frequency', 30)
                    }
                },
                particles = {
                    type = getValue('impact', 'effects.particles.type', "impact_sparks"),
                    count = getValue('impact', 'effects.particles.count', 15),
                    spread = getValue('impact', 'effects.particles.spread', 45),
                    velocity = getValue('impact', 'effects.particles.velocity', 200)
                }
            }
        },
        
        settle = {
            duration = getValue('settle', 'duration', 0.6),
            elasticity = getValue('settle', 'elasticity', 0.8),
            damping = getValue('settle', 'damping', 0.9),
            finalScale = getValue('settle', 'finalScale', 1.0),
            finalRotation = getValue('settle', 'finalRotation', 0),
            finalElevation = getValue('settle', 'finalElevation', 0),
            easing = getValue('settle', 'easing', "easeOutElastic")
        }
    }
end

return AnimationBuilder