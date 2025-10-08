-- proposed_animation_system.lua
-- UNIFIED 3D CARD ANIMATION SYSTEM PROPOSAL
-- 
-- This system treats each card animation as a complete 3D motion sequence
-- with distinct phases that mirror real physical card throwing

local ANIMATION_PHASES = {
    "preparation",  -- Card setup/windup before throw
    "launch",       -- Initial throw motion  
    "flight",       -- Main trajectory through 3D space
    "approach",     -- Final targeting/descent
    "impact",       -- Contact with target
    "settle",       -- Post-impact effects and resolution
    "resolve"       -- Game logic execution and cleanup
}

-- UNIFIED ANIMATION STRUCTURE
-- Every card animation follows this consistent structure
local UnifiedAnimationSpec = {
    
    -- === PREPARATION PHASE ===
    preparation = {
        duration = 0.1,           -- Time for card prep/windup
        scale = 1.05,             -- Card grows slightly 
        rotation = 5,             -- Slight tilt in degrees
        elevation = 10,           -- Lift off surface (Z-axis)
        easing = "easeOutQuad"
    },
    
    -- === LAUNCH PHASE ===
    launch = {
        duration = 0.15,          -- Quick explosive start
        initialVelocity = 800,    -- Starting speed (pixels/sec)
        acceleration = -200,      -- Deceleration during launch
        angle = 25,               -- Launch angle (degrees above horizontal)
        spin = {
            axis = "y",           -- Rotation axis (x, y, z)
            rate = 180,           -- Degrees per second
            decay = 0.95          -- Spin reduction factor per frame
        },
        easing = "easeOutCubic"
    },
    
    -- === FLIGHT PHASE === (Main trajectory)
    flight = {
        -- PHYSICS SIMULATION
        physics = {
            gravity = 980,        -- Downward acceleration (pixels/sec²)
            airResistance = 0.02, -- Velocity reduction factor
            mass = 1.0,           -- Card mass (affects gravity/resistance)
            windEffect = 0.0      -- Side drift influence
        },
        
        -- TRAJECTORY CONTROL
        trajectory = {
            type = "ballistic",   -- ballistic | guided | teleport | slam
            height = 200,         -- Peak height above start point
            arcShape = "natural", -- natural | high | low | straight
            horizontalCurve = 0,  -- Side-to-side curve amount
            hangTime = 0.3        -- Time spent at peak height
        },
        
        -- VISUAL EFFECTS DURING FLIGHT
        effects = {
            trail = {
                enabled = true,
                length = 5,       -- Number of trail segments
                fade = 0.8,       -- Opacity reduction per segment
                color = {1,1,1,0.6}
            },
            rotation = {
                tumble = true,    -- Card tumbles naturally
                speed = 1.0,      -- Tumble speed multiplier
                axis = "auto"     -- auto | x | y | z | random
            },
            scale = {
                min = 0.95,       -- Smallest scale during flight
                max = 1.1,        -- Largest scale during flight
                breathing = true  -- Subtle size pulsing
            }
        }
    },
    
    -- === APPROACH PHASE ===
    approach = {
        duration = 0.2,           -- Time for final targeting
        targetLock = true,        -- Snap to precise target position
        deceleration = 0.3,       -- Speed reduction factor
        rotation = {
            alignToTarget = true, -- Rotate to face impact angle
            finalAngle = 0        -- Final rotation (degrees)
        },
        anticipation = {
            pause = 0.05,         -- Brief pause before impact
            intensity = 1.2       -- Scale increase for emphasis
        }
    },
    
    -- === IMPACT PHASE ===
    impact = {
        -- COLLISION RESPONSE
        collision = {
            squash = 0.8,         -- Scale compression (0.8 = 20% squash)
            bounce = 1.15,        -- Scale rebound factor
            duration = 0.15,      -- Total squash+bounce time
            shockwave = true      -- Ripple effect from impact
        },
        
        -- VISUAL EFFECTS
        effects = {
            flash = {
                enabled = true,
                color = {1, 1, 1}, -- RGB
                intensity = 0.7,   -- Alpha peak
                duration = 0.1     -- Flash fade time
            },
            particles = {
                type = "dust",     -- dust | sparks | energy | custom
                count = 8,         -- Number of particles
                spread = 90,       -- Emission angle (degrees)
                velocity = 150     -- Initial particle speed
            },
            screen = {
                shake = 4,         -- Screen shake magnitude
                duration = 0.2     -- Shake duration
            }
        }
    },
    
    -- === SETTLE PHASE ===
    settle = {
        duration = 0.3,           -- Time to reach final state
        finalPosition = "auto",   -- auto | exact | offset
        stabilization = {
            rotation = 0,         -- Final rotation angle
            scale = 1.0,          -- Final scale
            elevation = 0         -- Final Z position
        },
        easing = "easeOutElastic" -- Satisfying settle motion
    },
    
    -- === RESOLVE PHASE ===
    resolve = {
        delay = 0.1,              -- Wait before game logic
        effects = "immediate",    -- immediate | delayed | queued
        cleanup = true            -- Remove temporary effects
    }
}

-- PREDEFINED ANIMATION STYLES
-- These provide easy-to-use presets for common card types
local ANIMATION_STYLES = {
    
    -- Quick, direct attacks
    quick_strike = {
        flight = {
            trajectory = { type = "guided", height = 50, arcShape = "low" },
            physics = { gravity = 500 }
        },
        impact = { collision = { squash = 0.9, bounce = 1.1 } }
    },
    
    -- Heavy, devastating attacks  
    heavy_slam = {
        preparation = { duration = 0.2, scale = 1.1 },
        flight = {
            trajectory = { type = "slam", height = 300, hangTime = 0.4 },
            physics = { gravity = 1200, mass = 2.0 }
        },
        impact = {
            collision = { squash = 0.7, bounce = 1.2, shockwave = true },
            effects = { screen = { shake = 8 } }
        }
    },
    
    -- Magical/energy attacks
    energy_blast = {
        flight = {
            trajectory = { type = "guided", height = 100 },
            effects = {
                trail = { color = {0.5, 1, 1, 0.8} },
                scale = { breathing = true, min = 0.9, max = 1.2 }
            }
        },
        impact = {
            effects = {
                particles = { type = "energy", count = 12 },
                flash = { color = {0.5, 1, 1}, intensity = 0.9 }
            }
        }
    },
    
    -- Defensive/support cards
    defensive = {
        preparation = { duration = 0.05 },
        flight = {
            trajectory = { type = "teleport", height = 20 },
            effects = { rotation = { tumble = false } }
        },
        impact = { collision = { squash = 0.95, bounce = 1.05 } }
    }
}

-- CARD-SPECIFIC OVERRIDES
-- Individual cards can override any aspect of their animation
local CARD_OVERRIDES = {
    
    body_slam = {
        baseStyle = "heavy_slam",
        flight = {
            trajectory = { hangTime = 0.6, height = 400 },
            effects = { rotation = { speed = 0.5 } }
        },
        impact = {
            effects = { screen = { shake = 12 } }
        }
    },
    
    quick_jab = {
        baseStyle = "quick_strike", 
        flight = {
            trajectory = { height = 30 }
        }
    },
    
    wild_swing = {
        baseStyle = "quick_strike",
        flight = {
            trajectory = { horizontalCurve = 30 }, -- Unpredictable path
            effects = { rotation = { speed = 2.0, axis = "random" } }
        }
    }
}

return {
    phases = ANIMATION_PHASES,
    unified = UnifiedAnimationSpec,
    styles = ANIMATION_STYLES,
    cards = CARD_OVERRIDES
}