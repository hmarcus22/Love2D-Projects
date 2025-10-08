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
    
    -- Determine current phase
    local newPhase = self:getCurrentResolvePhase(animation, elapsed)
    
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
    if elapsed >= totalDuration then
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
    
    -- Scale animation
    if phaseSpec.scale then
        local targetScale = animation.state.originalScale * phaseSpec.scale
        card.scale = animation.state.originalScale + (targetScale - animation.state.originalScale) * progress
    end
    
    -- Rotation animation
    if phaseSpec.rotation then
        local targetRotation = animation.state.originalRotation + math.rad(phaseSpec.rotation)
        card.rotation = animation.state.originalRotation + (targetRotation - animation.state.originalRotation) * progress
    end
    
    -- Movement animation
    if animation.state.velocityX and animation.state.velocityY then
        -- Apply easing if specified
        local easing = self:getEasingFunction(phaseSpec.easing or "linear")
        local easedProgress = easing(progress)
        
        local moveDistance = easedProgress * phaseDuration
        card.x = animation.state.originalX + animation.state.velocityX * moveDistance * dt
        card.y = animation.state.originalY + animation.state.velocityY * moveDistance * dt
    end
    
    -- Position offset animation
    if phaseSpec.target_offset then
        local easing = self:getEasingFunction(phaseSpec.easing or "easeOutQuad")
        local easedProgress = easing(progress)
        
        card.x = animation.state.originalX + phaseSpec.target_offset.x * easedProgress
        card.y = animation.state.originalY + phaseSpec.target_offset.y * easedProgress
    end
end

-- Complete resolve animation
function ResolveAnimator:completeResolveAnimation(animation)
    local card = animation.card
    
    -- Reset card to original state
    card.x = animation.state.originalX
    card.y = animation.state.originalY
    card.scale = animation.state.originalScale
    card.rotation = animation.state.originalRotation
    card.animZ = animation.state.originalZ
    
    if self.debugMode then
        print("[ResolveAnim] Completed", animation.type, "for", card.id or "unknown")
    end
end

-- Get easing function
function ResolveAnimator:getEasingFunction(easingName)
    local easingFunctions = {
        linear = function(t) return t end,
        easeOutQuad = function(t) return 1 - (1 - t) * (1 - t) end,
        easeOutCubic = function(t) return 1 - (1 - t) * (1 - t) * (1 - t) end,
        easeOutBack = function(t)
            local s = 1.70158
            t = t - 1
            return (t * t * ((s + 1) * t + s) + 1)
        end,
        easeOutElastic = function(t)
            if t == 0 or t == 1 then return t end
            local p = 0.3
            local s = p / 4
            return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
        end
    }
    
    return easingFunctions[easingName] or easingFunctions.linear
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