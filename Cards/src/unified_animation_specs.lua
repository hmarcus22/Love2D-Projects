-- unified_animation_specs.lua
-- Unified animation specifications for the 3D animation system

local specs = {}

-- Base unified animation specification
specs.unified = {
    -- Phase 1: Preparation (card anticipation before throwing)
    preparation = {
        duration = 0.3,
        scale = 1.1,
        elevation = 5,
        rotation = -5, -- degrees
        easing = "easeOutQuad"
    },
    
    -- Phase 2: Launch (initial throwing motion)
    launch = {
        duration = 0.2,
        angle = 25, -- degrees above horizontal
        initialVelocity = 800, -- pixels per second
        acceleration = 200,
        easing = "easeOutCubic"
    },
    
    -- Phase 3: Flight (projectile motion with physics)
    flight = {
        duration = 0.35, -- Match current working timing
        physics = {
            gravity = 980, -- pixels per second squared
            airResistance = 0.02,
            mass = 1.0
        },
        trajectory = {
            type = "ballistic", -- "ballistic", "guided", "straight"
            height = 140 -- Match current working arc height
        },
        effects = {
            trail = {
                enabled = true,
                length = 5,
                fadeTime = 0.3
            },
            rotation = {
                tumble = true,
                speed = 1.5 -- rotations per duration
            },
            scale = {
                breathing = true,
                min = 0.95,
                max = 1.05
            }
        }
    },
    
    -- Phase 4: Approach (final targeting/homing)
    approach = {
        duration = 0.3,
        guidingFactor = 0.5, -- how much to correct toward target
        anticipation = {
            scale = 1.2,
            rotation = 10 -- degrees
        },
        easing = "easeOutQuart"
    },
    
    -- Phase 5: Impact (collision with target/board)
    impact = {
        duration = 0.4,
        collision = {
            squash = 0.85, -- Match current working scale
            bounce = 1.3, -- scale during rebound
            restitution = 0.6 -- energy retained after collision
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
        duration = 0.6,
        elasticity = 0.8, -- spring strength
        damping = 0.9, -- energy loss per oscillation
        finalScale = 1.0,
        finalRotation = 0,
        finalElevation = 0,
        easing = "easeOutElastic"
    },
    
    -- Phase 7: Board State (ongoing animations while on board)
    board_state = {
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
        attack_strike = {
            duration = 0.6,
            phases = {
                windup = {duration = 0.2, scale = 1.15, rotation = -15},
                strike = {duration = 0.2, velocity = 400, target_offset = {x = 20, y = 0}},
                recoil = {duration = 0.2, easing = "easeOutBack"}
            }
        },
        defensive_push = {
            duration = 0.5,
            phases = {
                brace = {duration = 0.15, scale = 0.95},
                push = {duration = 0.2, velocity = -200},
                settle = {duration = 0.15, easing = "easeOutElastic"}
            }
        }
    }
}

-- Style presets for different card types
specs.styles = {
    -- Aggressive cards (attacks)
    aggressive = {
        -- Use default flight animation (explicitly defined for compatibility)
        preparation = {
            duration = 0.3,
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
        -- Special aggressive resolve animations
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
            duration = 0.3,
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
    
    -- Modifier cards (buffs, debuffs)
    modifier = {
        preparation = {
            duration = 0.35,
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
    }
}

-- Card-specific overrides
specs.cards = {
    -- Wild Swing - extra chaotic animation
    wild_swing = {
        baseStyle = "aggressive",
        flight = {
            effects = {
                rotation = {
                    tumble = true,
                    speed = 3.0 -- Extra chaotic tumbling
                }
            }
        },
        impact = {
            effects = {
                screen = {
                    shake = {
                        intensity = 15, -- Maximum chaos
                        duration = 0.4
                    }
                }
            }
        }
    },
    
    -- Quick Jab - fast and precise (using card ID "punch")
    punch = {
        baseStyle = "aggressive",
        preparation = {
            duration = 0.15 -- Extra quick prep
        },
        launch = {
            angle = 15, -- Very direct
            initialVelocity = 1000
        },
        flight = {
            duration = 0.5 -- Shorter flight time
        }
    },
    
    -- Corner Rally - defensive positioning (using card ID "rally")
    rally = {
        baseStyle = "defensive",
        board_state = {
            conditional = {
                rally_position = {
                    protective_stance = {
                        scale = 1.08,
                        brightness = 1.1,
                        pulse_frequency = 0.8
                    }
                }
            }
        }
    },
    
    -- Guard - steady defensive stance
    guard = {
        baseStyle = "defensive",
        settle = {
            finalScale = 1.05, -- Stays slightly enlarged
            easing = "easeOutQuad" -- More solid, less bouncy
        },
        board_state = {
            idle = {
                breathing = {
                    amplitude = 0.01 -- Very subtle breathing
                }
            }
        }
    },
    
    -- Adrenaline Rush - energetic modifier
    adrenaline_rush = {
        baseStyle = "modifier",
        flight = {
            effects = {
                scale = {
                    breathing = true,
                    min = 0.85,
                    max = 1.25 -- Very pronounced pulsing
                }
            }
        },
        board_state = {
            conditional = {
                adrenaline_active = {
                    energy_pulse = {
                        scale_min = 0.9,
                        scale_max = 1.2,
                        frequency = 2.5 -- Fast pulsing
                    }
                }
            }
        }
    },
    
    -- Body Slam - heavy slam attack
    body_slam = {
        preparation = {
            duration = 0.3,
            scale = 1.2, -- More dramatic preparation
            rotation = -10
        },
        flight = {
            duration = 0.55, -- Match slam_body profile
            trajectory = {
                height = 189, -- 140 * 1.35 arcScale from old system
                type = "slam_drop" -- Custom slam trajectory
            },
            effects = {
                trail = {
                    enabled = true,
                    length = 8, -- More dramatic trail
                    fadeTime = 0.4
                }
            }
        },
        impact = {
            duration = 0.6, -- Longer impact for dramatic effect
            collision = {
                squash = 0.7, -- More compression
                bounce = 1.4
            },
            effects = {
                screen = {
                    shake = {
                        intensity = 12, -- Much stronger shake
                        duration = 0.4
                    }
                },
                particles = {
                    count = 25, -- More particles
                    spread = 60
                }
            }
        },
        -- Add knockback equivalent
        game_resolve = {
            area_knockback = {
                enabled = true,
                radius = 600,
                force = 500,
                duration = 1.0,
                falloff = "linear"
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