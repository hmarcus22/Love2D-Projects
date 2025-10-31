-- resolve_animator.lua
-- Manages resolve phase animations during combat resolution

local Class = require 'libs.HUMP.class'
local ResolveAnimator = Class{}

function ResolveAnimator:init()
    self.activeResolveAnimations = {}
    self.animationSpecs = require('src.unified_animation_specs')
    self.debugMode = false
end

-- Start a resolve animation (attack, block, etc.)
function ResolveAnimator:startResolveAnimation(card, animationType, target, config)
    if not card or not animationType then return end
    
    local spec = self:getResolveSpec(card, animationType)
    if not spec then
        print("[ResolveAnim] No resolve spec found for", animationType)
        return
    end
    
    -- Mark card as in-resolve so board-state idle/interaction won't fight visuals
    card._inResolve = true
    -- Debug: mark kick-active for roundhouse attack stabs so renderer can tint
    if animationType == 'attack_strike' and card.id == 'roundhouse' then
        card._debugKickActiveCount = (card._debugKickActiveCount or 0) + 1
    end

    local animation = {
        card = card,
        target = target,
        type = animationType,
        spec = spec,
        startTime = love.timer.getTime(),
        currentPhase = nil,
        phaseStartTime = 0,
        config = config or {},
        state = {}
    }
    
    -- Initialize state
    self:initializeResolveState(animation)
    
    -- Store animation
    table.insert(self.activeResolveAnimations, animation)
    
    if self.debugMode then
        print("[ResolveAnim] Started", animationType, "for", card.id or "unknown")
    end
    
    return animation
end

-- Update all resolve animations
function ResolveAnimator:update(dt)
    for i = #self.activeResolveAnimations, 1, -1 do
        local animation = self.activeResolveAnimations[i]
        
        if self:updateResolveAnimation(animation, dt) then
            -- Animation completed
            table.remove(self.activeResolveAnimations, i)
        end
    end
end

-- Update a single resolve animation
function ResolveAnimator:updateResolveAnimation(animation, dt)
    local currentTime = love.timer.getTime()
    local elapsed = currentTime - animation.startTime
    local effectiveElapsed = elapsed
    -- For roundhouse, subtract any active/frozen time from elapsed so phase selection and completion truly pause
    if animation.card and animation.card.id == 'roundhouse' then
        -- Accumulate previous freeze windows in a timeline accumulator
        local accum = animation.state.timelineFreezeAccum or 0
        local active = 0
        local fs = animation.card._roundhouseFreezeStartTime
        local fe = animation.card._roundhouseFreezeEndTime
        if fs and fe then
            if currentTime < fe then
                active = math.max(0, currentTime - fs)
            else
                -- Window ended; fold into accumulator and clear card flags
                accum = accum + math.max(0, fe - fs)
                animation.card._roundhouseFreezeStartTime = nil
                animation.card._roundhouseFreezeEndTime = nil
            end
        end
        animation.state.timelineFreezeAccum = accum
        effectiveElapsed = math.max(0, elapsed - accum - active)
    end
    
    -- Determine current phase
    local newPhase = self:getCurrentResolvePhase(animation, effectiveElapsed)
    
    -- Handle phase transitions
    if newPhase ~= animation.currentPhase then
        self:onResolvePhaseChange(animation, animation.currentPhase, newPhase)
        animation.currentPhase = newPhase
        animation.phaseStartTime = currentTime
    end
    
    -- Update current phase
    if animation.currentPhase then
        self:updateResolvePhase(animation, animation.currentPhase, dt)
    end
    
    -- Check for completion
    local totalDuration = self:calculateResolveDuration(animation.spec)
    if effectiveElapsed >= totalDuration then
        self:completeResolveAnimation(animation)
        return true -- Animation completed
    end
    
    return false -- Animation continues
end

-- Initialize resolve animation state
function ResolveAnimator:initializeResolveState(animation)
    local card = animation.card
    
    animation.state.originalX = card.x
    animation.state.originalY = card.y
    animation.state.originalScale = card.scale or 1.0
    animation.state.originalRotation = card.rotation or 0
    animation.state.originalZ = card.animZ or 0
    
    -- Calculate target position if we have a target
    if animation.target then
        animation.state.targetX = animation.target.x
        animation.state.targetY = animation.target.y
    else
        animation.state.targetX = card.x
        animation.state.targetY = card.y
    end
end

-- Get resolve animation specification
function ResolveAnimator:getResolveSpec(card, animationType)
    local specs = self.animationSpecs
    if not specs then return nil end
    
    -- Check for card-specific override
    local cardId = card.definition and card.definition.id
    if cardId and specs.cards and specs.cards[cardId] then
        local cardSpec = specs.cards[cardId]
        if cardSpec.game_resolve and cardSpec.game_resolve[animationType] then
            return cardSpec.game_resolve[animationType]
        end
    end
    
    -- Check unified spec
    if specs.unified.game_resolve and specs.unified.game_resolve[animationType] then
        return specs.unified.game_resolve[animationType]
    end
    
    return nil
end

-- Calculate total resolve animation duration
function ResolveAnimator:calculateResolveDuration(spec)
    if spec.duration then
        return spec.duration
    end
    
    -- Sum up phases if no total duration
    local total = 0
    if spec.phases then
        for _, phase in pairs(spec.phases) do
            if phase.duration then
                total = total + phase.duration
            end
        end
    end
    
    return total > 0 and total or 1.0
end

-- Get current phase for resolve animation
function ResolveAnimator:getCurrentResolvePhase(animation, elapsed)
    local spec = animation.spec
    
    if not spec.phases then
        return "main" -- Single phase animation
    end
    
    local timeAccum = 0
    local phaseOrder = {"windup", "strike", "recoil", "brace", "push", "settle"}
    
    for _, phaseName in ipairs(phaseOrder) do
        if spec.phases[phaseName] then
            timeAccum = timeAccum + spec.phases[phaseName].duration
            if elapsed <= timeAccum then
                return phaseName
            end
        end
    end
    
    return "complete"
end

-- Handle resolve phase transitions
function ResolveAnimator:onResolvePhaseChange(animation, oldPhase, newPhase)
    if self.debugMode then
        print("[ResolveAnim] Phase change:", oldPhase, "->", newPhase)
    end
    
    -- Phase-specific initialization
    if newPhase == "strike" or newPhase == "push" then
        self:initializeMovementPhase(animation, newPhase)
    end

    -- (Removed) Temporary strike-only debug overlay control
end

-- Initialize movement phase (strike/push)
function ResolveAnimator:initializeMovementPhase(animation, phase)
    local card = animation.card
    local spec = animation.spec.phases[phase]
    
    if spec.velocity then
        -- Calculate movement vector
        local dx = animation.state.targetX - animation.state.originalX
        local dy = animation.state.targetY - animation.state.originalY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 0 then
            animation.state.velocityX = (dx / distance) * spec.velocity
            animation.state.velocityY = (dy / distance) * spec.velocity
        else
            animation.state.velocityX = spec.velocity
            animation.state.velocityY = 0
        end
        
        -- Apply target offset if specified
        if spec.target_offset then
            animation.state.velocityX = animation.state.velocityX + spec.target_offset.x
            animation.state.velocityY = animation.state.velocityY + spec.target_offset.y
        end
    end
end

-- Update specific resolve phase
function ResolveAnimator:updateResolvePhase(animation, phase, dt)
    local card = animation.card
    local spec = animation.spec
    
    if spec.phases and spec.phases[phase] then
        self:updatePhaseFromSpec(animation, spec.phases[phase], dt)
    else
        -- Single phase animation
        self:updatePhaseFromSpec(animation, spec, dt)
    end
end

-- Update phase based on specification
function ResolveAnimator:updatePhaseFromSpec(animation, phaseSpec, dt)
    local card = animation.card
    local phaseElapsed = love.timer.getTime() - animation.phaseStartTime
    local phaseDuration = phaseSpec.duration or 1.0
    local progress = math.min(phaseElapsed / phaseDuration, 1.0)
    
    -- Scale animation (combine phase scale with unified height-based scale)
    local baseScale = animation.state.originalScale or 1.0
    if phaseSpec.scale then
        local targetScale = baseScale * phaseSpec.scale
        baseScale = (animation.state.originalScale or 1.0) + (targetScale - (animation.state.originalScale or 1.0)) * progress
    end
    
    -- Rotation animation (with proper freeze accumulation for roundhouse)
    if phaseSpec.rotation then
        local targetRotation = animation.state.originalRotation + math.rad(phaseSpec.rotation)
        local rotProgress = progress
        if animation.card and animation.card.id == 'roundhouse' then
            local now = love.timer.getTime()
            local freezeEnd = animation.card._roundhouseFreezeEndTime
            animation.state.rotationFreezeAccum = animation.state.rotationFreezeAccum or 0
            -- Start or maintain an active freeze window
            if freezeEnd and (not animation.state.rotationFreezeActive) and now < freezeEnd then
                animation.state.rotationFreezeActive = true
                animation.state.rotationFreezeStart = now
            end
            -- Compute effective elapsed excluding accumulated and active freeze time
            local effectiveElapsed
            if animation.state.rotationFreezeActive then
                if freezeEnd and now < freezeEnd then
                    local active = now - (animation.state.rotationFreezeStart or now)
                    effectiveElapsed = (now - animation.phaseStartTime) - (animation.state.rotationFreezeAccum or 0) - active
                else
                    -- Freeze ended; accumulate and clear active markers
                    local added = 0
                    if animation.state.rotationFreezeStart then
                        local endTime = freezeEnd or now
                        added = math.max(0, endTime - animation.state.rotationFreezeStart)
                    end
                    animation.state.rotationFreezeAccum = (animation.state.rotationFreezeAccum or 0) + added
                    animation.state.rotationFreezeActive = nil
                    animation.state.rotationFreezeStart = nil
                    if freezeEnd and now >= freezeEnd then
                        animation.card._roundhouseFreezeEndTime = nil
                    end
                    effectiveElapsed = (now - animation.phaseStartTime) - (animation.state.rotationFreezeAccum or 0)
                end
            else
                effectiveElapsed = (now - animation.phaseStartTime) - (animation.state.rotationFreezeAccum or 0)
            end
            if effectiveElapsed < 0 then effectiveElapsed = 0 end
            rotProgress = math.min(effectiveElapsed / phaseDuration, 1.0)
        end
        card.rotation = animation.state.originalRotation + (targetRotation - animation.state.originalRotation) * rotProgress
    end

    -- Elevation (z-height) animation
    if phaseSpec.elevation then
        local targetZ = phaseSpec.elevation or 0
        local startZ = animation.state.originalZ or 0
        card.animZ = startZ + (targetZ - startZ) * progress
    end

    -- Apply unified height-scale mapping based on animZ
    do
        local ok, UnifiedHeightScale = pcall(require, 'src.unified_height_scale')
        if ok and UnifiedHeightScale and UnifiedHeightScale.getCardScale then
            local heightScale = UnifiedHeightScale.getCardScale(card) or 1.0
            card.scale = (baseScale or 1.0) * heightScale
        else
            card.scale = baseScale or 1.0
        end
    end
    
    -- Movement animation (integrate over elapsed time; do not multiply by dt again)
    -- Write to animX/animY so BoardRenderer layout does not override during resolve
    if animation.state.velocityX and animation.state.velocityY then
        local easing = self:getEasingFunction(phaseSpec.easing or "linear")
        local easedProgress = easing(progress)
        local easedTime = easedProgress * phaseDuration
        card.animX = animation.state.originalX + animation.state.velocityX * easedTime
        card.animY = animation.state.originalY + animation.state.velocityY * easedTime
    end
    
    -- Position offset animation (also via animX/animY)
    if phaseSpec.target_offset then
        local easing = self:getEasingFunction(phaseSpec.easing or "easeOutQuad")
        local easedProgress = easing(progress)
        
        card.animX = animation.state.originalX + phaseSpec.target_offset.x * easedProgress
        card.animY = animation.state.originalY + phaseSpec.target_offset.y * easedProgress
    end
end

-- Complete resolve animation
function ResolveAnimator:completeResolveAnimation(animation)
    local card = animation.card
    
    -- Reset card to original state
    card.x = animation.state.originalX
    card.y = animation.state.originalY
    card.scale = animation.state.originalScale
    if card.id ~= 'roundhouse' then
        card.rotation = animation.state.originalRotation
    end
    card.animZ = animation.state.originalZ
    -- Clear transient animated position so layout regains control fully
    card.animX = nil
    card.animY = nil
    -- (Removed) Temporary strike-only debug overlay flag
    -- Clear resolve flag so board-state animator can resume idle/interaction
    card._inResolve = nil
    -- Debug: clear kick-active when a roundhouse stab finishes
    if animation.type == 'attack_strike' and card.id == 'roundhouse' then
        local n = (card._debugKickActiveCount or 1) - 1
        if n <= 0 then
            card._debugKickActiveCount = nil
        else
            card._debugKickActiveCount = n
        end
    end
    
    if self.debugMode then
        print("[ResolveAnim] Completed", animation.type, "for", card.id or "unknown")
    end
end

-- Get easing function
local Util = require 'src.animation_util'
function ResolveAnimator:getEasingFunction(easingName)
    return Util.getEasing(easingName)
end

-- Start attack strike animation
function ResolveAnimator:startAttackStrike(attackCard, targetCard)
    return self:startResolveAnimation(attackCard, "attack_strike", targetCard)
end

-- Start defensive push animation
function ResolveAnimator:startDefensivePush(defendCard, attackCard)
    return self:startResolveAnimation(defendCard, "defensive_push", attackCard)
end

-- Check if any resolve animations are active
function ResolveAnimator:hasActiveAnimations()
    return #self.activeResolveAnimations > 0
end

-- Stop all resolve animations
function ResolveAnimator:stopAllAnimations()
    for _, animation in ipairs(self.activeResolveAnimations) do
        self:completeResolveAnimation(animation)
    end
    self.activeResolveAnimations = {}
end

-- Enable/disable debug mode
function ResolveAnimator:setDebugMode(enabled)
    self.debugMode = enabled
end

return ResolveAnimator
