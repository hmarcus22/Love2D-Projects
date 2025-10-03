-- flight_profiles.lua
-- Central registry for custom horizontal flight progress shaping.
-- Each profile function takes normalized time p (0..1) and returns adjusted horizontal progress (0..1).
-- Keep pure (no side-effects) so they can be reused / previewed.

local Profiles = {}

-- Default: linear pass-through (actual easing still applied after via easing/back logic)
Profiles.default = function(p) return p end

-- Utility: resolve a profile entry (function or table)
function Profiles.get(name)
    local v = Profiles[name]
    if not v then return { horizontal = Profiles.default } end
    if type(v) == 'function' then return { horizontal = v } end
    return v
end

-- Slam body: custom timing with its own tuning independent of global defaults.
-- Fields:
--  duration   : flight duration override
--  overshoot  : override overshootFactor (nil = use global)
--  arcScale   : multiply base arc height (if arc enabled) OR apply to supplied arcHeight
--  slamStyle  : tells animation_manager to use special vertical hover+drop path
Profiles.slam_body = {
    duration = 0.55,
    overshoot = 0,
    arcScale = 1.35,
    slamStyle = true,
    horizontal = function(p)
        if p < 0.55 then
            local halfP = p / 0.55
            local outQuad = 1 - (1 - halfP) * (1 - halfP)
            return outQuad * 0.70
        else
            local tailP = (p - 0.55) / 0.45
            local k = math.sin(tailP * math.pi * 0.5)
            return 0.70 + k * 0.30
        end
    end
}

return Profiles
