-- proposed_animation_system.lua
-- UNIFIED 3D CARD ANIMATION SYSTEM PROPOSAL
-- 
-- This system treats each card animation as a complete 3D motion sequence
-- with distinct phases that mirror real physical card throwing

local ANIMATION_PHASES = {
    "preparation",    -- Card setup/windup before throw
    "launch",         -- Initial throw motion  
    "flight",         -- Main trajectory through 3D space
    "approach",       -- Final targeting/descent
    "impact",         -- Contact with target
    "settle",         -- Post-impact card positioning
    "board_state",    -- Ongoing animations while card is on board
    "game_resolve"    -- Game logic execution and resolve animations
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
    
    -- === BOARD STATE PHASE ===
    -- Ongoing animations while cards are actively on the board
    board_state = {
        -- IDLE ANIMATIONS (subtle ongoing movement)
        idle = {
            enabled = true,
            type = "gentle_breathing", -- gentle_breathing | hover | pulse | none
            intensity = 0.02,          -- Very subtle scale change
            speed = 2.0,               -- Breathing rate (cycles per second)
            offset = "random"          -- random | synchronized - prevent all cards moving in sync
        },
        
        -- CONDITIONAL ANIMATIONS (triggered by game state)
        conditional = {
            -- Cards that signal impending doom, threats, or special states
            impending_doom = {
                enabled = false,
                triggers = ["countdown", "threat", "ultimate_ready"],
                animation = "shake_and_jump",
                intensity = 1.0,
                frequency = 2.0,       -- Shakes per second
                jumpHeight = 8,        -- Pixels to jump up
                color_pulse = {        -- Change card tint to signal danger
                    enabled = true,
                    color = {1, 0.2, 0.2, 0.3}, -- Red warning tint
                    speed = 3.0
                }
            },
            
            -- Cards building up power/energy
            charging = {
                enabled = false,
                triggers = ["energy_building", "combo_ready"],
                animation = "energy_pulse",
                glow = {
                    enabled = true,
                    color = {0.3, 0.8, 1, 0.6}, -- Blue energy glow
                    radius = 15,
                    pulsing = true
                },
                particles = {
                    enabled = false,     -- Could add energy particles later
                    type = "energy_motes"
                }
            },
            
            -- Defensive cards showing protection
            shielding = {
                enabled = false,
                triggers = ["blocking", "defending"],
                animation = "protective_stance",
                effects = {
                    shimmer = true,      -- Subtle protective shimmer
                    border_glow = {
                        color = {0.8, 0.8, 1, 0.4}, -- Protective blue
                        thickness = 2
                    }
                }
            },
            
            -- Cards that are stunned or disabled
            disabled = {
                enabled = false,
                triggers = ["stunned", "frozen", "disabled"],
                animation = "disabled_state",
                effects = {
                    desaturate = 0.6,    -- Make card appear "drained"
                    slow_drift = true,   -- Slow random drift movement
                    status_indicator = {
                        type = "stun_stars", -- spinning stars, ice crystals, etc.
                        count = 3,
                        orbit_radius = 20
                    }
                }
            },
            
            -- Cards highlighting for player attention
            highlighted = {
                enabled = true,
                triggers = ["hoverable", "targetable", "combo_available"],
                animation = "gentle_highlight",
                glow = {
                    enabled = true,
                    color = {1, 1, 0.3, 0.3}, -- Soft yellow highlight
                    pulsing = true,
                    speed = 1.5
                }
            }
        },
        
        -- INTERACTION FEEDBACK (responses to player actions)
        interaction = {
            -- When player hovers over card
            hover = {
                enabled = true,
                scale = 1.05,          -- Slight size increase
                elevation = 5,         -- Lift slightly off board
                duration = 0.2,        -- Smooth transition time
                glow = true           -- Add subtle glow
            },
            
            -- When card is selected/clicked
            selected = {
                enabled = true,
                scale = 1.1,           -- More pronounced size increase
                elevation = 10,        -- Lift higher
                border = {
                    enabled = true,
                    color = {1, 1, 1, 0.8},
                    thickness = 3,
                    animated = true     -- Animated selection border
                }
            },
            
            -- When card is being dragged
            dragging = {
                enabled = true,
                scale = 1.15,          -- Even larger when dragging
                elevation = 20,        -- High above board
                tilt = 5,             -- Slight rotation for 3D effect
                shadow = true         -- Drop shadow
            }
        },
        
        -- TIMING AND COORDINATION
        timing = {
            staggered_start = true,    -- Cards don't all start animating at once
            sync_to_music = false,     -- Future: sync animations to background music
            performance_scaling = true -- Reduce animations if frame rate drops
        }
    },
    
    -- === GAME RESOLVE PHASE ===
    -- Visual effects for game logic execution (damage, healing, status effects)
    game_resolve = {
        -- COMBAT ANIMATIONS (Building on existing attack/defensive animations)
        combat = {
            attack = {
                enabled = true,
                type = "attack_strike",   -- Current: lightning strike forward
                distance = 25,            -- How far the card moves forward
                duration = 0.3,           -- Total attack animation time
                phases = {
                    strike = { duration = 0.2, intensity = 1.0 },      -- Fast forward movement
                    impact = { duration = 0.2, shake = 2.5 },          -- Hold + shake at impact
                    return = { duration = 0.1, fade = true }           -- Snap back with fade
                },
                direction = "auto",       -- auto | up | down | toward_target
                easing = "easeOutQuint"   -- Ultra-fast acceleration
            },
            
            defend = {
                enabled = true,
                type = "defensive_push",  -- Current: delay + push back
                distance = 18,            -- Base push distance (scaled by damage)
                duration = 0.35,          -- Total defensive animation time
                phases = {
                    anticipation = { duration = 0.15, movement = 0.5 }, -- Brief delay
                    pushback = { duration = 0.3, intensity = 1.0 },     -- Reactive push
                    shake = { duration = 0.3, frequency = 10 },         -- Recoil shake
                    recovery = { duration = 0.25, easing = "easeIn" }   -- Return to position
                },
                intensityScale = 0.1,     -- Damage multiplier for push distance
                blockReduction = 0.7,     -- Reduce push when block absorbs damage
                direction = "auto"        -- auto | away_from_attacker
            },
            
            -- NEW: Enhanced combat animations
            critical = {
                enabled = false,          -- For critical hits
                effects = ["screen_shake", "slow_motion", "enhanced_particles"]
            },
            
            counter = {
                enabled = false,          -- For counter-attacks
                type = "counter_strike",
                reflexSpeed = 1.5         -- Faster than normal attacks
            }
        },
        
        -- DAMAGE/HEALING ANIMATIONS
        damage = {
            enabled = true,
            numberStyle = "floating", -- floating | popup | shake
            color = {1, 0.2, 0.2},   -- Damage number color
            font = "large",          -- Font size for damage numbers
            duration = 1.0,          -- How long damage numbers show
            motion = "float_up"      -- float_up | bounce | fade
        },
        
        healing = {
            enabled = true,
            numberStyle = "floating",
            color = {0.2, 1, 0.2},   -- Healing number color
            font = "large",
            duration = 1.0,
            motion = "float_up"
        },
        
        -- HEALTH BAR ANIMATIONS
        healthBars = {
            animateChanges = true,
            speed = 2.0,             -- Health bar animation speed
            smoothing = "easeOutQuad", -- Easing for health changes
            flashOnDamage = true,    -- Flash red when taking damage
            flashDuration = 0.3
        },
        
        -- STATUS EFFECT INDICATORS
        statusEffects = {
            stun = {
                icon = "stun_stars",
                duration = 2.0,
                animation = "spin_around" -- spin_around | pulse | shake
            },
            poison = {
                icon = "poison_bubbles", 
                duration = 1.5,
                animation = "bubble_up"
            },
            buff = {
                icon = "buff_sparkles",
                duration = 1.0, 
                animation = "sparkle"
            }
        },
        
        -- BOARD STATE CHANGES
        boardChanges = {
            cardDestruction = {
                effect = "dissolve",     -- dissolve | explode | fade
                duration = 0.8,
                particles = true
            },
            cardMovement = {
                speed = 300,             -- Pixels per second
                easing = "easeInOutQuad",
                trail = false
            }
        },
        
        -- CHAIN REACTIONS
        chainEffects = {
            enabled = true,
            delay = 0.2,             -- Delay between chain steps
            highlight = true,        -- Highlight cards in chain
            connectionLines = false  -- Draw lines between chained cards
        },
        
        -- UI UPDATES (score, energy, etc.)
        uiUpdates = {
            score = {
                animate = true,
                duration = 0.5,
                easing = "easeOutQuart"
            },
            energy = {
                animate = true,
                duration = 0.3,
                pulseOnChange = true
            }
        }
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