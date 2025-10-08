# 3D Card Animation System Redesign Proposal

## Current Problems

### 🔴 Fragmented Configuration
- Animation properties scattered across multiple files
- `animation_specs_defaults.lua` vs `flight_profiles.lua` vs card definitions
- Developers need to understand 3+ different systems

### 🔴 Confusing Parameters  
```lua
-- Current: What does this actually do?
arcHeight = 140,
overshoot = 0.12,
slamStyle = true,
verticalMode = 'hang_drop'
```

### 🔴 Inconsistent Structure
- Some cards use `flightProfile = 'slam_body'`  
- Others use animation spec overrides
- No clear pattern for new cards

### 🔴 Limited Expressiveness
- Hard to create varied, realistic 3D motions
- Physics simulation is basic
- No clear phases for complex animations

## Proposed Solution: Unified 3D Animation System

### ✅ Clear Phase Structure
Every animation follows intuitive real-world phases:
1. **Preparation** - Card windup/setup
2. **Launch** - Initial throw motion
3. **Flight** - 3D trajectory simulation  
4. **Approach** - Final targeting
5. **Impact** - Collision and effects
6. **Settle** - Card reaches final position
7. **Board State** - Ongoing animations while cards are on the board
8. **Game Resolve** - Visual effects for game logic (damage numbers, health bars, status effects)

### ✅ Intuitive Physics Parameters
```lua
-- Proposed: Clear, realistic physics
physics = {
    gravity = 980,        -- Real-world gravity
    airResistance = 0.02, -- Drag coefficient  
    mass = 1.0,           -- Card weight
    windEffect = 0.0      -- Environmental forces
}

trajectory = {
    type = "ballistic",   -- Natural physics
    height = 200,         -- Peak altitude
    arcShape = "natural", -- Realistic arc
    hangTime = 0.3        -- Time at peak
}
```

### ✅ Consistent Card Configuration
```lua
-- All cards follow same pattern:
body_slam = {
    baseStyle = "heavy_slam",           -- Use preset
    flight = {                          -- Override specifics
        trajectory = { height = 400 }   
    }
}
```

### ✅ Rich Visual Effects
- Trail systems during flight
- Particle effects on impact  
- Screen shake and flash
- Natural tumbling/rotation
- Scale breathing and anticipation

## Implementation Benefits

### 🎯 **Developer Experience**
- **Single source of truth** for all animation properties
- **Intuitive naming** that matches real-world physics
- **Preset styles** for quick setup ("heavy_slam", "quick_strike")
- **Granular overrides** for unique cards

### 🎯 **Animation Quality**  
- **Realistic 3D motion** with proper physics simulation
- **Rich visual feedback** with particles, trails, shake
- **Smooth phase transitions** for polished feel
- **Consistent timing** across all cards

### 🎯 **Maintainability**
- **Clear structure** makes debugging easier
- **Modular design** allows independent phase tuning
- **Preset system** reduces code duplication
- **Override pattern** keeps customization clean

### 🎯 **Animation Lab Integration**
- **Phase-by-phase preview** in animation lab
- **Real-time parameter tuning** for each phase
- **Visual physics debugging** (trajectory paths, forces)
- **Resolve animation testing** (damage numbers, health bars, status effects)
- **A/B testing** different animation styles

## Migration Strategy

### Phase 1: Create New System
1. Implement unified animation spec structure
2. Create physics simulation engine  
3. Build preset animation styles
4. Add phase-based animation manager

### Phase 2: Gradual Migration
1. Convert existing cards one-by-one
2. Maintain backward compatibility
3. Update animation lab to use new system
4. Add visual debugging tools

### Phase 3: Complete Transition  
1. Remove old animation files
2. Update all cards to new system
3. Add advanced effects (particles, trails)
4. Polish and optimize performance

## Example Conversions

### Current Body Slam
```lua
-- Scattered across multiple files:
body_slam = { flight = { profile = 'slam_body' } }  -- animation_specs_defaults
slam_body = { duration = 0.55, slamStyle = true }   -- flight_profiles  
flightProfile = 'slam_body'                         -- card_definitions
```

### Proposed Body Slam  
```lua
-- Single, clear definition:
body_slam = {
    baseStyle = "heavy_slam",
    preparation = { duration = 0.25, scale = 1.15 },
    flight = { 
        trajectory = { height = 400, hangTime = 0.6 },
        physics = { mass = 2.0, gravity = 1200 }
    },
    impact = { 
        effects = { screen = { shake = 12 } }
    }
}
```

## Conclusion

This unified system would transform card animations from a confusing collection of scattered parameters into an intuitive, powerful 3D motion system that's easy to understand, maintain, and extend.

The phase-based approach mirrors real physical card throwing, making it intuitive for developers to create and tune animations that feel natural and impactful.