-- unified_animation_engine.lua
-- Core 3D animation system with physics simulation and phase management

local Class = require 'libs.HUMP.class'
local Config = require 'src.config'
local UnifiedAnimationEngine = Class{}

-- Animation phase constants
local PHASES = {
    PREPARATION = "preparation",
    LAUNCH = "launch", 
    FLIGHT = "flight",
    APPROACH = "approach",
    IMPACT = "impact",
    SETTLE = "settle",
    BOARD_STATE = "board_state",
    GAME_RESOLVE = "game_resolve"
}

-- Easing functions
local function easeOutQuad(t) return 1 - (1 - t) * (1 - t) end
local function easeOutCubic(t) return 1 - (1 - t) * (1 - t) * (1 - t) end
local function easeOutQuart(t) return 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t) end
local function easeOutQuint(t) return 1 - (1 - t) * (1 - t) * (1 - t) * (1 - t) * (1 - t) end
local function easeInOutQuad(t) return t < 0.5 and 2 * t * t or 1 - 2 * (1 - t) * (1 - t) end
local function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4
    return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end
local function easeOutBack(t, s)
    s = s or 1.70158
    t = t - 1
    return (t * t * ((s + 1) * t + s) + 1)
end

local EASING_FUNCTIONS = {
    linear = function(t) return t end,
    easeOutQuad = easeOutQuad,
    easeOutCubic = easeOutCubic,
    easeOutQuart = easeOutQuart,
    easeOutQuint = easeOutQuint,
    easeInOutQuad = easeInOutQuad,
    easeOutElastic = easeOutElastic,
    easeOutBack = easeOutBack
}

function UnifiedAnimationEngine:init()
    self.activeAnimations = {}
    self.animationSpecs = require('src.unified_animation_specs')
    self.debugMode = true -- TEMPORARY: Enable debug logging to diagnose animation issues
end

-- Start a new animation sequence for a card
function UnifiedAnimationEngine:startAnimation(card, animationType, config)
    if Config and Config.debug then
        print("[UnifiedEngine] startAnimation called - Card:", card and card.id or "nil", "Type:", animationType)
    end
    
    if not card or not animationType then 
        print("[UnifiedEngine] ERROR: Missing card or animationType")
        return 
    end
    
    -- Get animation specification for this card/type
    local spec = self:getAnimationSpec(card, animationType, config)
    if not spec then
        print("[UnifiedEngine] ERROR: No spec found for", card.id or "unknown", animationType)
        return
    end
    
    if Config and Config.debug then
        print("[UnifiedEngine] Found spec for", card.id or "unknown", "- total duration:", self:calculateTotalDuration(spec))
    end
    
    -- Create animation instance
    local animation = {
        card = card,
        type = animationType,
        spec = spec,
        startTime = love.timer.getTime(),
        currentPhase = nil,
        phaseStartTime = 0,
        totalDuration = self:calculateTotalDuration(spec),
        config = config or {},
        state = {},
        onComplete = config and config.onComplete -- Store completion callback
    }
    
    if Config and Config.debug then
        print("[UnifiedEngine] Created animation instance - Duration:", animation.totalDuration)
    end
    
    -- Initialize animation state
    self:initializeAnimationState(animation)
    
    -- Store reference
    self.activeAnimations[card] = animation
    if Config and Config.debug then
        print("[UnifiedEngine] Animation stored for card:", card.id or "unknown")
    end
    
    if self.debugMode then
        print("[UnifiedEngine] Started", animationType, "for", card.id or "unknown")
    end
    
    return animation
end

-- Update all active animations
function UnifiedAnimationEngine:update(dt)
    -- Safety check for abnormal dt values
    if dt > 1.0 or dt <= 0 then
        if Config and Config.debug then
            print("[UnifiedEngine] Skipping update - invalid dt:", dt)
        end
        return
    end
    
    local activeCount = 0
    local maxIterations = 100 -- Prevent infinite loops
    local iterations = 0
    
    for card, animation in pairs(self.activeAnimations) do
        iterations = iterations + 1
        if iterations > maxIterations then
            if Config and Config.debug then
                print("[UnifiedEngine] Warning: Too many animations detected, breaking loop")
            end
            break
        end
        
        activeCount = activeCount + 1
        self:updateAnimation(animation, dt)
    end
    
    if activeCount > 0 and self.debugMode and Config and Config.debug then
        print("[UnifiedEngine] Updating", activeCount, "active animations with dt:", string.format("%.4f", dt))
    end
end

-- Update a single animation
function UnifiedAnimationEngine:updateAnimation(animation, dt)
    local currentTime = love.timer.getTime()
    local elapsed = currentTime - animation.startTime
    local progress = math.min(elapsed / animation.totalDuration, 1.0)
    
    if self.debugMode and Config and Config.debug then
        print("[UnifiedEngine] Updating animation for", animation.card.id or "unknown", 
              "- Elapsed:", string.format("%.2f", elapsed), 
              "- Progress:", string.format("%.2f", progress))
    end
    
    -- Determine current phase
    local newPhase = self:getCurrentPhase(animation, elapsed)
    
    -- Handle phase transitions
    if newPhase ~= animation.currentPhase then
        if self.debugMode and Config and Config.debug then
            print("[UnifiedEngine] Phase change:", animation.currentPhase or "nil", "->", newPhase or "nil")
        end
        self:onPhaseChange(animation, animation.currentPhase, newPhase)
        animation.currentPhase = newPhase
        animation.phaseStartTime = currentTime
    end
    
    -- Update current phase
    if animation.currentPhase then
        self:updatePhase(animation, animation.currentPhase, dt)
    end
    
    -- Check for completion
    if progress >= 1.0 or animation.forceComplete then
        if self.debugMode and Config and Config.debug then
            print("[UnifiedEngine] Animation complete for", animation.card.id or "unknown")
        end
        self:completeAnimation(animation)
    end
end

-- Get animation specification for a card
function UnifiedAnimationEngine:getAnimationSpec(card, animationType, config)
    local specs = self.animationSpecs
    if not specs then return nil end
    
    -- Check for style override in config first
    if config and config.animationStyle and specs.styles and specs.styles[config.animationStyle] then
        if Config and Config.debug then
            print("[UnifiedEngine] Using animation style:", config.animationStyle)
        end
        local styleSpec = specs.styles[config.animationStyle]
        if styleSpec.baseStyle then
            -- Use base style with overrides
            local baseSpec = specs.styles[styleSpec.baseStyle] or specs.unified
            return self:mergeSpecs(baseSpec, styleSpec)
        else
            return styleSpec
        end
    end
    
    -- Debug: Show card ID lookup
    local cardId = card.definition and card.definition.id
    if Config and Config.debug then
        print("[UnifiedEngine] Spec lookup - card.id:", card.id, "card.definition.id:", cardId)
    end
    
    -- Check for card-specific override
    if cardId and specs.cards and specs.cards[cardId] then
        if Config and Config.debug then
            print("[UnifiedEngine] Found card-specific spec for:", cardId)
        end
        local cardSpec = specs.cards[cardId]
        if cardSpec.baseStyle then
            -- Use base style with overrides
            local baseSpec = specs.styles[cardSpec.baseStyle]
            if baseSpec then
                return self:mergeSpecs(baseSpec, cardSpec)
            end
        else
            return cardSpec
        end
    end
    
    if Config and Config.debug then
        print("[UnifiedEngine] Using default unified spec for:", cardId or card.id or "unknown")
    end
    -- Use default unified spec
    return specs.unified
end

-- Merge animation specs (card overrides on base style)
function UnifiedAnimationEngine:mergeSpecs(base, override)
    local merged = {}
    
    -- Deep copy base
    for k, v in pairs(base) do
        if type(v) == "table" then
            merged[k] = {}
            for k2, v2 in pairs(v) do
                merged[k][k2] = v2
            end
        else
            merged[k] = v
        end
    end
    
    -- Apply overrides
    for k, v in pairs(override) do
        if type(v) == "table" and merged[k] and type(merged[k]) == "table" then
            for k2, v2 in pairs(v) do
                merged[k][k2] = v2
            end
        else
            merged[k] = v
        end
    end
    
    return merged
end

-- Calculate total animation duration
function UnifiedAnimationEngine:calculateTotalDuration(spec)
    local total = 0
    local phases = {"preparation", "launch", "flight", "approach", "impact", "settle", "board_state", "game_resolve"}
    
    for _, phase in ipairs(phases) do
        if spec[phase] and spec[phase].duration then
            total = total + spec[phase].duration
        end
    end
    
    return total > 0 and total or 1.0 -- Fallback duration
end

-- Determine which phase should be active at elapsed time
function UnifiedAnimationEngine:getCurrentPhase(animation, elapsed)
    local spec = animation.spec
    local timeAccum = 0
    local phases = {"preparation", "launch", "flight", "approach", "impact", "settle", "board_state", "game_resolve"}
    
    for _, phase in ipairs(phases) do
        if spec[phase] and spec[phase].duration then
            timeAccum = timeAccum + spec[phase].duration
            if elapsed <= timeAccum then
                return phase
            end
        end
    end
    
    return "game_resolve" -- Default final phase (was "settle")
end

-- Handle phase transitions
function UnifiedAnimationEngine:onPhaseChange(animation, oldPhase, newPhase)
    if self.debugMode then
        print("[UnifiedAnim] Phase change:", oldPhase, "->", newPhase)
        print("[UnifiedAnim] Card:", animation.card.id or "unknown", "at position:", animation.card.x, animation.card.y)
    end
    
    -- Initialize phase-specific state
    if newPhase == "launch" then
        self:initializeLaunchPhase(animation)
    elseif newPhase == "flight" then
        self:initializeFlightPhase(animation)
    elseif newPhase == "impact" then
        self:initializeImpactPhase(animation)
    elseif newPhase == "board_state" then
        self:initializeBoardStatePhase(animation)
    elseif newPhase == "game_resolve" then
        self:initializeGameResolvePhase(animation)
    end
end

-- Initialize animation state
function UnifiedAnimationEngine:initializeAnimationState(animation)
    local card = animation.card
    
    if Config and Config.debug then
        print("[UnifiedEngine] Initializing animation state for:", card.id or "unknown")
        print("[UnifiedEngine] Initial card position: x=", card.x, "y=", card.y)
    end
    
    -- Store original position
    animation.state.originalX = card.x
    animation.state.originalY = card.y
    animation.state.originalZ = card.animZ or 0
    animation.state.originalScale = card.scale or 1
    animation.state.originalRotation = card.rotation or 0
    
    -- Initialize physics state for flight
    animation.state.velocity = {x = 0, y = 0, z = 0}
    animation.state.position = {
        x = card.x, 
        y = card.y, 
        z = card.animZ or 0
    }
    
    -- Set initial animation position to prevent disappearing
    card.animX = card.x
    card.animY = card.y
    card.animZ = card.animZ or 0
    
    -- Initialize alpha for animation system
    card.animAlpha = card.animAlpha or 1.0
    
    -- Mark card as being managed by unified animation system
    card._unifiedAnimationActive = true
    
    if Config and Config.debug then
        print("[UnifiedEngine] Set animX=", card.animX, "animY=", card.animY, "animZ=", card.animZ)
        print("[UnifiedEngine] Marked card as unified animation active")
    end
end

-- Initialize launch phase
-- Initialize launch phase
function UnifiedAnimationEngine:initializeLaunchPhase(animation)
    local spec = animation.spec.launch
    if not spec then return end
    
    -- Only calculate velocity for physics-based flight
    local flightSpec = animation.spec.flight
    if flightSpec and flightSpec.trajectory and flightSpec.trajectory.type == "physics" then
        -- Physics-based flight needs velocity calculations
        local config = animation.config
        local targetX = config.targetX or animation.state.originalX
        local targetY = config.targetY or animation.state.originalY
        
        local dx = targetX - animation.state.originalX
        local dy = targetY - animation.state.originalY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance > 0 then
            -- Use safer velocity values by default
            local angle = math.rad(spec.angle or 25)
            local speed = spec.initialVelocity or 400 -- Reduced default
            
            -- Normalize direction
            local dirX = dx / distance
            local dirY = dy / distance
            
            -- Calculate initial velocity
            animation.state.velocity.x = dirX * speed * math.cos(angle)
            animation.state.velocity.y = dirY * speed * math.cos(angle)
            animation.state.velocity.z = speed * math.sin(angle)
        end
    end
    
    if Config and Config.debug then
        print("[UnifiedEngine] Launch phase initialized")
    end
end

-- Initialize flight phase  
function UnifiedAnimationEngine:initializeFlightPhase(animation)
    local spec = animation.spec.flight
    if not spec then return end
    
    -- Set up physics simulation
    animation.state.physics = {
        gravity = spec.physics and spec.physics.gravity or 980,
        airResistance = spec.physics and spec.physics.airResistance or 0.02,
        mass = spec.physics and spec.physics.mass or 1.0
    }
end

-- Initialize impact phase
function UnifiedAnimationEngine:initializeImpactPhase(animation)
    local spec = animation.spec.impact
    if not spec then return end
    
    -- Get gameState reference from config
    local gameState = animation.config and animation.config.gameState
    if not gameState then
        if Config and Config.debug then
            print("[UnifiedEngine] Warning: No gameState reference for impact effects")
        end
        return
    end
    
    -- Trigger impact effects using existing ImpactFX system
    if spec.effects and spec.effects.screen and spec.effects.screen.shake then
        local shake = spec.effects.screen.shake
        local ImpactFX = require 'src.impact_fx'
        -- Trigger screen shake with animation parameters
        ImpactFX.triggerShake(
            gameState,
            shake.duration or 0.25,
            shake.intensity or 6
        )
        
        if Config and Config.debug then
            print("[UnifiedEngine] Triggered screen shake:", shake.intensity, shake.duration)
        end
    end
    
    if spec.effects and spec.effects.particles then
        local particles = spec.effects.particles
        local ImpactFX = require 'src.impact_fx'
        local card = animation.card
        -- Trigger particle effects at card position
        ImpactFX.triggerDust(
            gameState,
            (card.animX or card.x) + (card.w or 50) / 2,
            (card.animY or card.y) + (card.h or 70) - 8,
            particles.count or 15
        )
        
        if Config and Config.debug then
            print("[UnifiedEngine] Triggered particle effects:", particles.count, particles.type)
        end
    end
end

-- Initialize board state phase
function UnifiedAnimationEngine:initializeBoardStatePhase(animation)
    local spec = animation.spec.board_state
    if not spec then return end
    
    if Config and Config.debug then
        print("[UnifiedEngine] Initializing board state phase")
    end
    
    -- Board state phase setup
    -- This is where board integration logic would be triggered
end

-- Initialize game resolve phase
function UnifiedAnimationEngine:initializeGameResolvePhase(animation)
    local spec = animation.spec.game_resolve
    if not spec then return end
    
    if Config and Config.debug then
        print("[UnifiedEngine] Initializing game resolve phase")
    end
    
    -- Game resolve phase setup
    -- This is where final game logic would be triggered
end

-- Update specific animation phase
function UnifiedAnimationEngine:updatePhase(animation, phase, dt)
    local card = animation.card
    local spec = animation.spec[phase]
    if not spec then 
        if Config and Config.debug then
            print("[UnifiedEngine] WARNING: No spec found for phase:", phase, "for card:", card.id or "unknown")
        end
        return 
    end
    
    local phaseElapsed = love.timer.getTime() - animation.phaseStartTime
    local phaseProgress = math.min(phaseElapsed / math.max(spec.duration or 1.0, 0.001), 1.0) -- Ensure no division by zero
    
    if Config and Config.debug and phaseElapsed > 0.1 and phaseElapsed < 5.0 then -- Only log for reasonable timeframes
        print("[UnifiedEngine] Phase:", phase, "Progress:", string.format("%.2f", phaseProgress), "Duration:", spec.duration or "nil")
    end
    
    if phase == "preparation" then
        self:updatePreparationPhase(animation, spec, phaseProgress)
    elseif phase == "launch" then
        self:updateLaunchPhase(animation, spec, phaseProgress, dt)
    elseif phase == "flight" then
        self:updateFlightPhase(animation, spec, phaseProgress, dt)
    elseif phase == "approach" then
        self:updateApproachPhase(animation, spec, phaseProgress)
    elseif phase == "impact" then
        self:updateImpactPhase(animation, spec, phaseProgress)
    elseif phase == "settle" then
        self:updateSettlePhase(animation, spec, phaseProgress)
    elseif phase == "board_state" then
        self:updateBoardStatePhase(animation, spec, phaseProgress)
    elseif phase == "game_resolve" then
        self:updateGameResolvePhase(animation, spec, phaseProgress)
    end
end

-- Update preparation phase
function UnifiedAnimationEngine:updatePreparationPhase(animation, spec, progress)
    local card = animation.card
    local easing = EASING_FUNCTIONS[spec.easing or "easeOutQuad"]
    local t = easing(progress)
    
    if Config and Config.debug and progress > 0.1 then
        print("[PREP] Card:", card.id, "Progress:", string.format("%.2f", progress), "Scale target:", spec.scale)
    end
    
    -- Scale effect
    if spec.scale then
        card.scale = animation.state.originalScale + (spec.scale - animation.state.originalScale) * t
        if Config and Config.debug and progress > 0.1 then
            print("[PREP] Scale applied:", string.format("%.3f", card.scale))
        end
    end
    
    -- Elevation effect
    if spec.elevation then
        card.animZ = animation.state.originalZ + spec.elevation * t
    end
    
    -- Rotation effect
    if spec.rotation then
        card.rotation = animation.state.originalRotation + math.rad(spec.rotation) * t
    end
end

-- Update launch phase
function UnifiedAnimationEngine:updateLaunchPhase(animation, spec, progress, dt)
    local card = animation.card
    
    -- Check if this is physics-based or interpolated flight
    local flightSpec = animation.spec.flight
    if flightSpec and flightSpec.trajectory and flightSpec.trajectory.type == "physics" then
        -- Physics-based launch with acceleration
        if spec.acceleration then
            local accel = spec.acceleration * dt
            animation.state.velocity.x = animation.state.velocity.x + accel * dt
            animation.state.velocity.y = animation.state.velocity.y + accel * dt
        end
        
        -- Update position based on velocity
        animation.state.position.x = animation.state.position.x + animation.state.velocity.x * dt
        animation.state.position.y = animation.state.position.y + animation.state.velocity.y * dt
        animation.state.position.z = animation.state.position.z + animation.state.velocity.z * dt
        
        card.animX = animation.state.position.x
        card.animY = animation.state.position.y
        card.animZ = animation.state.position.z
    else
        -- Simple launch for interpolated flight (DEFAULT)
        local config = animation.config
        if config.targetX and config.targetY then
            local startX = animation.state.originalX
            local startY = animation.state.originalY
            
            -- Small movement toward target during launch
            local launchDistance = 0.1
            local easing = EASING_FUNCTIONS["easeOutCubic"] or function(t) return t end
            local t = easing(progress) * launchDistance
            
            animation.state.position.x = startX + (config.targetX - startX) * t
            animation.state.position.y = startY + (config.targetY - startY) * t
            animation.state.position.z = t * 20 -- Small lift
            
            card.animX = animation.state.position.x
            card.animY = animation.state.position.y
            card.animZ = animation.state.position.z
        end
    end
end

-- Update flight phase with flexible physics and effects system
function UnifiedAnimationEngine:updateFlightPhase(animation, spec, progress, dt)
    local card = animation.card
    
    if Config and Config.debug and progress > 0.1 and progress < 0.9 then
        print("[FLIGHT] Card:", card.id, "Progress:", string.format("%.2f", progress), "Target:", 
              animation.config.targetX or "nil", animation.config.targetY or "nil")
    end
    
    -- Choose flight method based on trajectory type (default to safe interpolated)
    if spec.trajectory and spec.trajectory.type == "physics" then
        -- Physics-based flight for dynamic cards (Body Slam, etc.)
        self:updatePhysicsFlight(animation, spec, progress, dt)
    else
        -- Simple interpolated flight for smooth cards (SAFE DEFAULT)
        self:updateInterpolatedFlight(animation, spec, progress, dt)
    end
    
    -- Apply visual effects if specified
    if spec.effects then
        self:applyFlightEffects(animation, spec.effects, progress, dt)
    end
    
    -- Apply to card
    card.animX = animation.state.position.x
    card.animY = animation.state.position.y
    card.animZ = animation.state.position.z
    
    if Config and Config.debug and progress > 0.1 and progress < 0.9 then
        print("[FLIGHT] Applied position - animX:", string.format("%.1f", card.animX or 0), 
              "animY:", string.format("%.1f", card.animY or 0), "animZ:", string.format("%.1f", card.animZ or 0))
        print("[DEBUG-SET] Card " .. (card.id or "unknown") .. " animX=" .. card.animX .. " at time " .. string.format("%.3f", love.timer.getTime()))
    end
end

-- Simple interpolated flight (for default smooth cards)
function UnifiedAnimationEngine:updateInterpolatedFlight(animation, spec, progress, dt)
    local config = animation.config
    
    if config.targetX and config.targetY then
        local startX = animation.state.originalX
        local startY = animation.state.originalY
        local targetX = config.targetX
        local targetY = config.targetY
        
        if Config and Config.debug and progress > 0.1 and progress < 0.9 then
            print("[INTERP] Start:", startX, startY, "Target:", targetX, targetY, "Progress:", string.format("%.2f", progress))
        end
        
        -- Eased interpolation from start to target
        local easing = EASING_FUNCTIONS[spec.easing or "easeOutQuad"] or function(t) return t end
        local t = easing(progress)
        
        -- Calculate position along arc
        animation.state.position.x = startX + (targetX - startX) * t
        animation.state.position.y = startY + (targetY - startY) * t
        
        -- Add arc height based on spec
        local arcHeight = spec.trajectory and spec.trajectory.height or 80
        local arcProgress = math.sin(progress * math.pi) -- Creates arc shape
        animation.state.position.z = arcProgress * arcHeight
        
        if Config and Config.debug and progress > 0.1 and progress < 0.9 then
            print("[INTERP] Calculated position:", string.format("%.1f", animation.state.position.x), 
                  string.format("%.1f", animation.state.position.y), "Z:", string.format("%.1f", animation.state.position.z))
        end
        
        -- Keep card properly oriented (no rotation during interpolated flight)
        local card = animation.card
        card.rotation = animation.state.originalRotation
        card.scale = animation.state.originalScale
    end
end

-- Physics-based flight (for dynamic cards like Body Slam)
function UnifiedAnimationEngine:updatePhysicsFlight(animation, spec, progress, dt)
    local physics = animation.state.physics
    
    -- Apply gravity
    animation.state.velocity.z = animation.state.velocity.z - physics.gravity * dt
    
    -- Apply air resistance
    local resistance = physics.airResistance
    animation.state.velocity.x = animation.state.velocity.x * (1 - resistance)
    animation.state.velocity.y = animation.state.velocity.y * (1 - resistance)
    animation.state.velocity.z = animation.state.velocity.z * (1 - resistance * 0.5)
    
    -- Update position
    animation.state.position.x = animation.state.position.x + animation.state.velocity.x * dt
    animation.state.position.y = animation.state.position.y + animation.state.velocity.y * dt
    animation.state.position.z = animation.state.position.z + animation.state.velocity.z * dt
    
    -- Prevent going below ground
    if animation.state.position.z < 0 then
        animation.state.position.z = 0
        animation.state.velocity.z = 0
    end
    
    -- Safety bounds checking
    local screenBounds = 2000
    if math.abs(animation.state.position.x) > screenBounds or 
       math.abs(animation.state.position.y) > screenBounds then
        if Config and Config.debug then
            print("[UnifiedEngine] Card flew out of bounds, forcing completion")
        end
        -- Set position to target
        if animation.config.targetX and animation.config.targetY then
            animation.state.position.x = animation.config.targetX
            animation.state.position.y = animation.config.targetY
        end
        animation.state.position.z = 0
        animation.forceComplete = true
    end
    
    -- Apply trajectory shaping
    if spec.trajectory then
        self:applyTrajectoryShaping(animation, spec.trajectory, progress)
    end
end

-- Apply trajectory shaping
function UnifiedAnimationEngine:applyTrajectoryShaping(animation, trajectory, progress)
    if trajectory.type == "guided" then
        -- Guide toward target
        local config = animation.config
        if config.targetX and config.targetY then
            local guideFactor = 0.1 -- How strongly to guide
            local dx = config.targetX - animation.state.position.x
            local dy = config.targetY - animation.state.position.y
            
            animation.state.velocity.x = animation.state.velocity.x + dx * guideFactor
            animation.state.velocity.y = animation.state.velocity.y + dy * guideFactor
        end
    end
end

-- Apply flight visual effects
function UnifiedAnimationEngine:applyFlightEffects(animation, effects, progress, dt)
    local card = animation.card
    
    -- Rotation effects
    if effects.rotation and effects.rotation.tumble then
        local speed = effects.rotation.speed or 1.0
        -- Use delta time instead of cumulative progress to prevent exponential rotation
        local rotationDelta = speed * 2 * math.pi * dt / animation.spec.flight.duration
        card.rotation = (card.rotation or 0) + rotationDelta
    end
    
    -- Scale breathing
    if effects.scale and effects.scale.breathing then
        local min = effects.scale.min or 0.95
        local max = effects.scale.max or 1.1
        local breathe = math.sin(progress * math.pi * 4) * 0.5 + 0.5
        card.scale = min + (max - min) * breathe
    end
end

-- Update approach phase
function UnifiedAnimationEngine:updateApproachPhase(animation, spec, progress)
    local card = animation.card
    local easing = EASING_FUNCTIONS[spec.easing or "easeOutQuart"]
    local t = easing(progress)
    
    -- Apply guidance toward target
    if spec.guidingFactor and animation.config.targetX and animation.config.targetY then
        local guideFactor = spec.guidingFactor * t
        local targetX = animation.config.targetX
        local targetY = animation.config.targetY
        
        local currentX = card.animX or card.x
        local currentY = card.animY or card.y
        
        local dx = targetX - currentX
        local dy = targetY - currentY
        
        -- Apply stronger guidance correction to ensure we reach target
        card.animX = currentX + dx * guideFactor * 0.5
        card.animY = currentY + dy * guideFactor * 0.5
    else
        -- Direct interpolation to target if no guidance factor
        if animation.config.targetX and animation.config.targetY then
            local startX = animation.state.originalX
            local startY = animation.state.originalY
            card.animX = startX + (animation.config.targetX - startX) * t
            card.animY = startY + (animation.config.targetY - startY) * t
        end
    end
    
    -- Apply anticipation effects (but skip rotation for interpolated flight cards)
    if spec.anticipation then
        if spec.anticipation.scale then
            local targetScale = animation.state.originalScale * spec.anticipation.scale
            card.scale = animation.state.originalScale + (targetScale - animation.state.originalScale) * t
        end
        
        -- Only apply rotation if this is a physics-based card
        local flightSpec = animation.spec.flight
        if spec.anticipation.rotation and flightSpec and flightSpec.trajectory and flightSpec.trajectory.type == "physics" then
            local targetRotation = animation.state.originalRotation + math.rad(spec.anticipation.rotation)
            card.rotation = animation.state.originalRotation + (targetRotation - animation.state.originalRotation) * t
        end
    end
    
    -- Ensure interpolated flight cards maintain stable rotation
    local flightSpec = animation.spec.flight
    if not flightSpec or not flightSpec.trajectory or flightSpec.trajectory.type ~= "physics" then
        card.rotation = animation.state.originalRotation or 0.0
    end
    
    -- Apply fade effects if specified
    if spec.fade then
        local startAlpha = spec.fade.startAlpha or 1.0
        local endAlpha = spec.fade.endAlpha or 1.0
        card.animAlpha = startAlpha + (endAlpha - startAlpha) * t
        
        if Config and Config.debug then
            print("[UnifiedEngine] Fade applied - t:", string.format("%.2f", t), "alpha:", string.format("%.2f", card.animAlpha))
        end
    end
end

-- Update impact phase
function UnifiedAnimationEngine:updateImpactPhase(animation, spec, progress)
    local card = animation.card
    local collision = spec.collision
    
    if collision then
        -- Squash and bounce effect
        if progress < 0.5 then
            -- Squash
            local squashT = progress * 2
            local squash = collision.squash or 0.8
            card.scale = animation.state.originalScale + (squash - animation.state.originalScale) * squashT
        else
            -- Bounce
            local bounceT = (progress - 0.5) * 2
            local bounce = collision.bounce or 1.15
            local peakScale = collision.squash or 0.8
            card.scale = peakScale + (bounce - peakScale) * bounceT
        end
    end
    
    -- Apply fade effects if specified
    if spec.fade then
        local startAlpha = spec.fade.startAlpha or 1.0
        local endAlpha = spec.fade.endAlpha or 1.0
        card.animAlpha = startAlpha + (endAlpha - startAlpha) * progress
    end
end

-- Update settle phase
function UnifiedAnimationEngine:updateSettlePhase(animation, spec, progress)
    local card = animation.card
    local easing = EASING_FUNCTIONS[spec.easing or "easeOutElastic"]
    local t = easing(progress)
    
    -- Return to final stable state
    local targetScale = animation.state.originalScale
    local targetZ = 0
    local targetRotation = 0
    
    card.scale = card.scale + (targetScale - card.scale) * t
    card.animZ = (card.animZ or 0) + (targetZ - (card.animZ or 0)) * t
    card.rotation = (card.rotation or 0) + (targetRotation - (card.rotation or 0)) * t
end

-- Complete animation
function UnifiedAnimationEngine:completeAnimation(animation)
    local card = animation.card
    
    -- Set final position based on animation target
    if animation.config.targetX and animation.config.targetY then
        card.x = animation.config.targetX
        card.y = animation.config.targetY
        if Config and Config.debug then
            print("[UnifiedEngine] Set final position: x=" .. card.x .. " y=" .. card.y)
        end
    end
    
    -- Reset to stable state
    card.scale = animation.state.originalScale or 1.0
    card.rotation = animation.state.originalRotation or 0.0
    card.animX = nil
    card.animY = nil
    card.animZ = nil
    card.animAlpha = nil  -- Reset alpha to default
    
    -- Clear unified animation flag
    card._unifiedAnimationActive = nil
    
    if Config and Config.debug then
        print("[UnifiedEngine] Reset card to stable state")
    end
    
    -- Trigger completion callback if present
    if animation.onComplete then
        local success, err = pcall(animation.onComplete)
        if not success then
            print("[UnifiedEngine] ERROR in animation completion callback:", err)
            -- Don't let callback errors crash the animation system
        end
    end
    
    -- Remove from active animations
    self.activeAnimations[card] = nil
    
    if self.debugMode then
        print("[UnifiedAnim] Completed", animation.type, "for", card.id or "unknown")
    end
end

-- Stop animation for a card
function UnifiedAnimationEngine:stopAnimation(card)
    if self.activeAnimations[card] then
        self:completeAnimation(self.activeAnimations[card])
    end
end

-- Check if card has active animation
function UnifiedAnimationEngine:hasActiveAnimation(card)
    return self.activeAnimations[card] ~= nil
end

-- Enable/disable debug mode
function UnifiedAnimationEngine:setDebugMode(enabled)
    self.debugMode = enabled
end

-- Update board state phase
function UnifiedAnimationEngine:updateBoardStatePhase(animation, spec, progress)
    local card = animation.card
    
    -- Board state phase handles card integration into board systems
    -- This phase is typically very short and mostly for triggering board state updates
    if Config and Config.debug then
        print("[UnifiedEngine] Board state phase for:", card.id or "unknown")
    end
    
    -- During board state, card should maintain its animated position until animation completes
    -- Only clear animations when the entire animation sequence is finished
    -- The final position will be set in completeAnimation()
    
    -- Keep the card at its current animated position during this phase
    -- Don't clear animX/animY yet - let completeAnimation() handle the final cleanup
end

-- Update game resolve phase  
function UnifiedAnimationEngine:updateGameResolvePhase(animation, spec, progress)
    local card = animation.card
    
    -- Game resolve phase handles final game logic updates
    -- This is the final phase before animation completion
    if Config and Config.debug then
        print("[UnifiedEngine] Game resolve phase for:", card.id or "unknown")
    end
    
    -- Final cleanup and state verification
    card._unifiedAnimationActive = true -- Keep flag until completion
end

-- Get currently active animations for rendering purposes
function UnifiedAnimationEngine:getActiveAnimations()
    return self.activeAnimations or {}
end

return UnifiedAnimationEngine