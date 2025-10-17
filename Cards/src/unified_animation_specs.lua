-- unified_animation_specs.lua
-- Unified animation specifications for the 3D animation system

local specs = {}

-- Base unified animation specification
specs.unified = {
    -- Phase 1: Preparation (card anticipation before throwing)
    preparation = {
        duration = 0.03, -- Snappier: minimal wind-up for responsiveness
        scale = 1.01,    -- Subtle anticipation only
        elevation = 2,   -- Keep slight lift
        rotation = 0,    -- No rotation during preparation for clean flight
        easing = "easeOutQuad"
    },
    
    -- Phase 2: Launch (initial throwing motion)
    launch = {
        duration = 0.05, -- Quicker launch for immediate flick feel
        angle = 25,      -- degrees above horizontal
        initialVelocity = 900, -- Higher initial speed
        acceleration = 350,
        easing = "easeOutCubic"
    },
    
    -- Phase 3: Flight (projectile motion with physics)
    flight = {
        duration = 0.2, -- Keep brisk overall flight
        easing = "easeOutQuad",
        trajectory = {
            type = "interpolated", -- Safe default: "interpolated" or "physics"
            height = 40 -- Slightly flatter arc for flick feel
        },
        physics = {
            gravity = 600, -- Only used for physics-based flight
            airResistance = 0.02,
            mass = 1.0
        },
        effects = {
            trail = {
                enabled = false, -- Disabled by default
                length = 5,
                fadeTime = 0.3
            },
            rotation = {
                tumble = false, -- No spinning by default
                speed = 0
            },
            scale = {
                breathing = false, -- Disabled by default
                useUnified = true, -- NEW: Enable unified height-scale system for all flights
                baseScale = 1.0,
                min = 0.95,
                max = 1.05
            }
        }
    },
    
    -- Phase 4: Approach (final targeting/homing)
    approach = {
        duration = 0.12, -- Slightly longer for visible glide-in
        guidingFactor = 0.72, -- Slightly stronger correction
        -- No anticipation scaling/rotation at landing to avoid visible pop
        anticipation = {
            scale = 1.0,
            rotation = 0
        },
        easing = "easeOutCubic" -- Strong deceleration to emphasize soft land
    },
    
    -- Phase 5: Impact (collision with target/board)
    impact = {
        duration = 0.10, -- Quick, no bounce
        collision = {
            squash = 1.0, -- No squash
            bounce = 1.0, -- No bounce
            restitution = 0.8
        },
        effects = {
            screen = {
                shake = {
                    intensity = 6, -- Match current working shake
                    duration = 0.25, -- Match current working duration
                    frequency = 30
                }
            },
            particles = {
                type = "impact_sparks",
                count = 15,
                spread = 45, -- degrees
                velocity = 200
            },
            sound = "card_impact"
        }
    },
    
    -- Phase 6: Settle (elastic settling into final position)
    settle = {
        duration = 0.12, -- Quicker settle
        elasticity = 0.9, -- Lower spring strength for gentle land
        damping = 0.9, -- Slightly stronger damping
        finalScale = 1.0,
        finalRotation = 0,
        finalElevation = 0,
        easing = "easeOutQuad"
    },
    
    -- Phase 7: Board State (ongoing animations while on board)
    board_state = {
        duration = 0.05, -- Very quick transition to board integration
        idle = {
            breathing = {
                enabled = true,
                amplitude = 0.02, -- scale variation
                frequency = 0.8 -- cycles per second
            },
            hover = {
                enabled = true,
                amplitude = 3, -- pixel variation
                frequency = 0.6
            }
        },
        conditional = {
            impending_doom = {
                shake_and_jump = {
                    shake_intensity = 2,
                    jump_height = 8,
                    frequency = 2.0
                }
            },
            charging = {
                energy_pulse = {
                    scale_min = 0.95,
                    scale_max = 1.1,
                    frequency = 1.5,
                    glow_intensity = 0.3
                }
            },
            shielding = {
                protective_stance = {
                    scale = 1.05,
                    brightness = 1.2,
                    pulse_frequency = 0.5
                }
            },
            disabled = {
                dimmed = {
                    brightness = 0.6,
                    saturation = 0.3,
                    slight_droop = 2 -- pixels down
                }
            }
        },
        interaction = {
            hover = {
                scale = 1.05,
                elevation = 3,
                transition_time = 0.15
            },
            selected = {
                scale = 1.1,
                elevation = 8,
                glow = true,
                transition_time = 0.2
            },
            dragging = {
                scale = 0.9,
                elevation = 15,
                tilt = 5, -- degrees
                trail = true
            }
        }
    },
    
    -- Phase 8: Game Resolve (combat animation effects)
    game_resolve = {
        duration = 0.05, -- Very quick final resolution
        attack_strike = {
            duration = 0.3,
            phases = {
                windup = {duration = 0.1, scale = 1.15, rotation = -15},
                strike = {duration = 0.1, velocity = 600, target_offset = {x = 20, y = 0}},
                recoil = {duration = 0.1, easing = "easeOutBack"}
            }
        },
        defensive_push = {
            duration = 0.25,
            phases = {
                brace = {duration = 0.15, scale = 0.95},
                push = {duration = 0.2, velocity = -200},
                settle = {duration = 0.15, easing = "easeOutElastic"}
            }
        }
    }
}

-- UI/effects specifications not tied to card motion
specs.ui = {
    slot_glow = {
        duration = 0.35,
        maxAlpha = 0.55,
        lineWidth = 4,
        radius = 12,
        inset = 4,
        easing = "easeOutQuad",
        color = {1, 1, 0.4} -- RGB; alpha driven by maxAlpha and timeline
    }
}

-- Style presets for different card types
specs.styles = {
    -- Dramatic style available for custom card assignments (like body_slam)
    dramatic = {
        -- Use improved timing with enhanced visual effects
        preparation = {
            duration = 0.02, -- Ultra-fast for dramatic responsiveness
            scale = 1.005,
            elevation = 1,
            rotation = -2,
            easing = "easeOutQuad"
        },
        launch = {
            duration = 0.08,
            angle = 25,
            initialVelocity = 800,
            acceleration = 300,
            easing = "easeOutCubic"
        },
        flight = {
            duration = 0.2,
            physics = {
                gravity = 980,
                airResistance = 0.02,
                mass = 1.0
            },
            trajectory = {
                type = "ballistic",
                height = 50  -- Lower for more direct feeling
            },
            effects = {
                trail = {
                    enabled = true,
                    length = 5,
                    fadeTime = 0.3
                },
                rotation = {
                    tumble = true,
                    speed = 1.5
                },
                scale = {
                    breathing = true,
                    min = 0.95,
                    max = 1.05
                }
            }
        },
        approach = {
            duration = 0.1,
            guidingFactor = 0.7,
            anticipation = {
                scale = 1.1,
                rotation = 5
            },
            easing = "easeOutQuart"
        },
        impact = {
            duration = 0.15,
            collision = {
                squash = 0.9,
                bounce = 1.2,
                restitution = 0.7
            },
            effects = {
                screen = {
                    shake = {
                        intensity = 8, -- Stronger shake for attacks
                        duration = 0.3,
                        frequency = 35
                    }
                },
                particles = {
                    type = "impact_sparks",
                    count = 20, -- More particles for attacks
                    spread = 60,
                    velocity = 250
                },
                sound = "attack_impact"
            }
        },
        settle = {
            duration = 0.2,
            elasticity = 0.9,
            damping = 0.85,
            finalScale = 1.0,
            finalRotation = 0,
            finalElevation = 0,
            easing = "easeOutElastic"
        },
        -- Special dramatic resolve animations
        game_resolve = {
            attack_strike = {
                duration = 0.6,
                phases = {
                    windup = {duration = 0.2, scale = 1.15, rotation = -15},
                    strike = {duration = 0.2, velocity = 400, target_offset = {x = 20, y = 0}},
                    recoil = {duration = 0.2, easing = "easeOutBack"}
                }
            },
            heavy_slam = {
                duration = 0.8,
                phases = {
                    charge = {duration = 0.3, scale = 1.2, rotation = -20},
                    slam = {duration = 0.3, velocity = 600, target_offset = {x = 30, y = 5}},
                    recover = {duration = 0.2, easing = "easeOutElastic"}
                }
            },
            combo_strike = {
                duration = 1.0,
                phases = {
                    first_hit = {duration = 0.2, velocity = 300, target_offset = {x = 15, y = -5}},
                    second_hit = {duration = 0.2, velocity = 350, target_offset = {x = 25, y = 5}},
                    finish = {duration = 0.6, scale = 1.1, easing = "easeOutBack"}
                }
            }
        }
    },
    
    -- Defensive cards (blocks, counters)
    defensive = {
        -- Use default flight animation (explicitly defined for compatibility)
        preparation = {
            duration = 0.05, -- Instant defensive response
            scale = 1.1,
            elevation = 5,
            rotation = -5,
            easing = "easeOutQuad"
        },
        launch = {
            duration = 0.2,
            angle = 25,
            initialVelocity = 800,
            acceleration = 200,
            easing = "easeOutCubic"
        },
        flight = {
            duration = 0.35,
            physics = {
                gravity = 980,
                airResistance = 0.02,
                mass = 1.0
            },
            trajectory = {
                type = "ballistic",
                height = 140
            },
            effects = {
                trail = {
                    enabled = true,
                    length = 5,
                    fadeTime = 0.3
                },
                rotation = {
                    tumble = true,
                    speed = 1.5
                },
                scale = {
                    breathing = true,
                    min = 0.95,
                    max = 1.05
                }
            }
        },
        approach = {
            duration = 0.3,
            guidingFactor = 0.5,
            anticipation = {
                scale = 1.2,
                rotation = 10
            },
            easing = "easeOutQuart"
        },
        impact = {
            duration = 0.4,
            collision = {
                squash = 0.85,
                bounce = 1.3,
                restitution = 0.6
            },
            effects = {
                screen = {
                    shake = {
                        intensity = 6,
                        duration = 0.25,
                        frequency = 30
                    }
                },
                particles = {
                    type = "impact_sparks",
                    count = 15,
                    spread = 45,
                    velocity = 200
                },
                sound = "card_impact"
            }
        },
        settle = {
            duration = 0.6,
            elasticity = 0.8,
            damping = 0.9,
            finalScale = 1.0,
            finalRotation = 0,
            finalElevation = 0,
            easing = "easeOutElastic"
        },
        -- Special defensive resolve animations
        game_resolve = {
            defensive_push = {
                duration = 0.5,
                phases = {
                    brace = {duration = 0.15, scale = 0.95},
                    push = {duration = 0.2, velocity = -200},
                    settle = {duration = 0.15, easing = "easeOutElastic"}
                }
            },
            counter_stance = {
                duration = 0.4,
                phases = {
                    ready = {duration = 0.1, scale = 1.05, rotation = -5},
                    counter = {duration = 0.2, velocity = 300, target_offset = {x = -15, y = 0}},
                    retract = {duration = 0.1, easing = "easeOutBack"}
                }
            }
        }
    },
    
    -- Basic Attack Style - Fast, frequent-use animations for common attack cards
    basic_attack = {
        -- Use swift flight animations for playing basic attacks to board
        preparation = {
            duration = 0.02,
            scale = 1.005,
            elevation = 1,
            rotation = 0, -- No rotation for clean, fast feel
            easing = "easeOutQuad"
        },
        launch = {
            duration = 0.05,
            angle = 20, -- Lower angle for direct feel
            initialVelocity = 950, -- Fast launch
            acceleration = 400,
            easing = "easeOutCubic"
        },
        flight = {
            duration = 0.15, -- Quick flight
            physics = {
                gravity = 800,
                airResistance = 0.015,
                mass = 0.9 -- Lighter feel
            },
            trajectory = {
                type = "interpolated", -- Consistent, predictable arc
                height = 25 -- Low, fast trajectory
            },
            effects = {
                trail = { enabled = false }, -- No trail for clean look
                rotation = { tumble = false }, -- No tumbling for readability
                scale = { breathing = false } -- No breathing for consistency
            }
        },
        approach = {
            duration = 0.1, -- Quick approach
            guidingFactor = 0.8, -- More direct landing
            anticipation = {
                scale = 1.02, -- Subtle anticipation
                rotation = 2
            },
            easing = "easeOutQuad"
        },
        impact = {
            duration = 0.2, -- Quick impact
            collision = {
                squash = 0.95, -- Subtle impact effect
                bounce = 1.1,
                restitution = 0.4
            },
            effects = {
                screen = {
                    shake = {
                        intensity = 2, -- Light shake for basic attacks
                        duration = 0.1,
                        frequency = 20
                    }
                }
            }
        },
        settle = {
            duration = 0.1, -- Quick settle
            finalScale = 1.0,
            finalRotation = 0,
            finalElevation = 0,
            easing = "easeOutQuad"
        },
        -- Resolve animations using generic stage names
        game_resolve = {
            attack_strike = {
                duration = 0.5, -- Total duration: fast but satisfying
                phases = {
                    preparation = {duration = 0.1, scale = 1.05, rotation = -3}, -- Brief windup
                    action = {duration = 0.2, velocity = 400, target_offset = 0.5}, -- Lunge toward target (50% distance)
                    settle = {duration = 0.2, easing = "easeOutBack"} -- Snap back to position
                }
            },
            defensive_push = {
                duration = 0.4, -- Slightly longer for reaction feel
                phases = {
                    preparation = {duration = 0.05, scale = 0.98}, -- Brief brace
                    action = {duration = 0.2, velocity = -150, push_intensity = 0.3}, -- Pushback motion  
                    settle = {duration = 0.15, easing = "easeOutElastic"} -- Return to position
                }
            }
        }
    },
    
    -- Modifier cards (buffs, debuffs)
    -- DEPRECATED: legacy modifier preset kept for reference; not used.
    modifier_legacy = {
        preparation = {
            duration = 0.05, -- Instant modifier application
            scale = 1.08,
            elevation = 8,
            rotation = 3
        },
        launch = {
            angle = 45, -- High arc
            initialVelocity = 500,
            acceleration = 100
        },
        flight = {
            trajectory = {
                type = "guided",
                height = 150
            },
            effects = {
                trail = {
                    enabled = true,
                    length = 8, -- Longer trail
                    fadeTime = 0.5
                },
                scale = {
                    breathing = true,
                    min = 0.9,
                    max = 1.15 -- More pronounced breathing
                }
            }
        },
        impact = {
            collision = {
                squash = 0.85,
                bounce = 1.05 -- Gentle landing
            },
            effects = {
                particles = {
                    type = "magic_sparkles",
                    count = 25,
                    spread = 60
                }
            }
        },
        settle = {
            duration = 0.8, -- Longer settle with more flourish
            easing = "easeOutElastic"
        }
    },
    
    -- Modifier cards (special fade effect for application)
    modifier = {
        -- Inherit all phases from unified base
        baseStyle = "unified",
        
        -- Override only the phases where we want fade effects
        approach = {
            duration = 0.15,
            guidingFactor = 0.6,
            anticipation = {
                scale = 1.1,
                rotation = 5
            },
            easing = "easeOutQuart",
            fade = {
                startAlpha = 1.0,
                endAlpha = 0.3 -- Start fading in approach
            }
        },
        impact = {
            duration = 0.2,
            collision = {
                squash = 0.8,
                bounce = 1.2
            },
            fade = {
                startAlpha = 0.3,
                endAlpha = 0.0 -- Fully transparent by impact end
            },
            effects = {
                screen = {
                    shake = {
                        intensity = 5, -- Gentle shake for modifier application
                        duration = 0.15
                    }
                }
            }
        }
    }
}

-- Card-specific overrides
specs.cards = {
    -- Body Slam - wrestling-style animation with dynamic rotation curve
    body_slam = {
        baseStyle = "dramatic",
        preparation = {
            duration = 0.05, -- Fast power buildup
            scale = 1.15, -- Bigger preparation
            elevation = 8,
            rotation = -10 -- Wind up rotation
        },
        launch = {
            duration = 0.3,
            angle = 45, -- Steeper angle for wrestling jump
            initialVelocity = 800, -- Higher velocity for wrestling leap
            acceleration = 350 -- More powerful launch
        },
        flight = {
            duration = 0.4,
            trajectory = {
                type = "physics", -- Use physics-based flight (not interpolated)
                height = 140 -- Higher arc for dramatic wrestling jump
            },
            physics = {
                gravity = 850, -- Stronger gravity for slam effect
                airResistance = 0.008, -- Reduced air resistance for more power
                mass = 1.8 -- Heavier wrestling feel
            },
            effects = {
                trail = {
                    enabled = true, -- Enable trail for visual impact
                    length = 10, -- Longer trail for wrestling effect
                    fadeTime = 0.5
                },
                rotation = {
                    tumble = true, -- Enable wrestling rotation
                    speed = 0.8, -- Reduced speed for more controlled rotation
                    curve = "wrestling", -- Special rotation curve: slow start → peak mid-flight → slow end
                    maxRotations = 1.0 -- Limit to 360 degrees total
                },
                scale = {
                    breathing = false, -- Disable breathing to focus on height scaling
                    useUnified = true, -- NEW: Use unified height-scale system
                    baseScale = 1.0,
                    -- heightMultiplier removed - now controlled by unified system config
                },
                shadow = {
                    enabled = true, -- Enable ground shadow
                    opacity = 0.4,
                    scaleWithHeight = true,
                    maxOffset = 20 -- Maximum shadow offset at peak height
                }
            }
        },
        impact = {
            duration = 0.4,
            effects = {
                screen = {
                    shake = {
                        intensity = 20, -- Heavy impact shake
                        duration = 0.5
                    }
                }
            }
        },
        game_resolve = {
            area_knockback = {
                enabled = true,
                radius = 400, -- ~3 card widths in virtual coordinates (128*3=384)
                force = 120, -- Strong knockback force for dramatic effect
                duration = 1.2, -- Longer bounce sequence for ultimate move
                direction = "radial", -- Knock cards away from impact point
                falloff = "linear" -- Consistent force across the area
            }
        }
    }
}

-- Dynamic editing functions for tuner overlay
specs._cardOverrides = {}

function specs.setCardProperty(cardId, phase, path, value)
    if not specs._cardOverrides[cardId] then
        specs._cardOverrides[cardId] = {}
    end
    
    if not specs._cardOverrides[cardId][phase] then
        specs._cardOverrides[cardId][phase] = {}
    end
    
    -- Handle nested paths like "trajectory.height"
    local current = specs._cardOverrides[cardId][phase]
    local pathParts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        if not current[part] then
            current[part] = {}
        end
        current = current[part]
    end
    
    current[pathParts[#pathParts]] = value
    
    -- Apply override to main specs.cards table
    if not specs.cards[cardId] then
        specs.cards[cardId] = {}
    end
    if not specs.cards[cardId][phase] then
        specs.cards[cardId][phase] = {}
    end
    
    local target = specs.cards[cardId][phase]
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        if not target[part] then
            target[part] = {}
        end
        target = target[part]
    end
    target[pathParts[#pathParts]] = value
end

function specs.setDefaultProperty(phase, path, value)
    -- Modify the base unified spec
    if not specs.unified[phase] then
        specs.unified[phase] = {}
    end
    
    -- Handle nested paths like "trajectory.height"
    local current = specs.unified[phase]
    local pathParts = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(pathParts, part)
    end
    
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        if not current[part] then
            current[part] = {}
        end
        current = current[part]
    end
    
    current[pathParts[#pathParts]] = value
end

function specs.getCardProperty(cardId, phase, path, defaultValue)
    -- First check card-specific overrides
    if specs.cards[cardId] and specs.cards[cardId][phase] then
        local current = specs.cards[cardId][phase]
        for part in path:gmatch("[^%.]+") do
            if current[part] == nil then
                break
            end
            current = current[part]
        end
        if current ~= nil then return current end
    end
    
    -- Then check base unified spec
    if specs.unified[phase] then
        local current = specs.unified[phase]
        for part in path:gmatch("[^%.]+") do
            if current[part] == nil then
                return defaultValue
            end
            current = current[part]
        end
        return current
    end
    
    return defaultValue
end

function specs.saveOverrides()
    if not love or not love.filesystem then return end
    local content = "return " .. require('src.utils.serialize')(specs._cardOverrides)
    love.filesystem.write('unified_animation_overrides.lua', content)
end

function specs.resetCard(cardId)
    specs._cardOverrides[cardId] = nil
    specs[cardId] = nil
end

return specs
