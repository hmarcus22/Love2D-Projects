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
    },
    impact = {
      squashScale = 0.85,
      flashAlpha = 0.55,
      holdExtra = 0.10,
      shakeMag = 6,
      shakeDur = 0.25,
      dustCount = 1,
    },
    debug = {
      showPath = false,
    }
  },
  cards = {
    -- Example: body_slam gets profile but relies on flight_profiles metadata for deep tweaks
    body_slam = {
      flight = { profile = 'slam_body' }
    }
  }
}
