--[[
DEPRECATED — Legacy Animation Spec Defaults
Replaced by src/unified_animation_specs.lua. Do NOT require at runtime.

Current source of truth:

Unified specs: src/unified_animation_specs.lua
Plan/docs: UNIFIED_ANIMATION_PLAN.md, UNIFIED_ANIMATION_IMPLEMENTATION.md
Kept only for historical reference.
]]--

-- animation_specs_defaults.lua
-- Base defaults for animation specs (global + per-card). Keep minimal; customize via overrides.

return {
  global = {
    flight = {
      duration = 0.35,
      overshoot = 0.12,
      arcHeight = 140,
      easing = 'easeOutQuad',
      arcEnabled = true,
      verticalMode = 'standard_arc', -- standard_arc | hang_drop | plateau_drop
    },
    impact = {
      squashScale = 0.85,
      flashAlpha = 0.55,
      holdExtra = 0.10,
      shakeMag = 6,
      shakeDur = 0.25,
      dustCount = 1,
    },
    knockback = {
      enabled = false,
      radius = 80,
      force = 50,
      duration = 0.6,
      falloff = 'linear',
      direction = 'radial',
      angle = 0,
    },
    debug = {
      showPath = false,
    }
  },
  cards = {
    -- Example: body_slam gets profile but relies on flight_profiles metadata for deep tweaks
    body_slam = {
      flight = { profile = 'slam_body' },
      knockback = {
        enabled = true,
        radius = 600,    -- Good coverage without being excessive
        force = 500,     -- MUCH stronger force for dramatic effect (was 250)
        duration = 1.0,  -- Faster wrestling impact feel - quick and punchy
        falloff = 'linear',
        direction = 'radial',
      }
    }
  }
}
