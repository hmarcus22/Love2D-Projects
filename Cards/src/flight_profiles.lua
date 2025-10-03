-- flight_profiles.lua
-- Central registry for custom horizontal flight progress shaping.
-- Each profile function takes normalized time p (0..1) and returns adjusted horizontal progress (0..1).
-- Keep pure (no side-effects) so they can be reused / previewed.

local Profiles = {}

-- Default: linear pass-through (actual easing still applied after via easing/back logic)
function Profiles.default(p)
    return p
end

-- Slam body: accelerate quickly then slow into 70%, leaving space for dramatic vertical drop later
-- Mirrors previous inline implementation.
function Profiles.slam_body(p)
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

-- Placeholder for future profiles (arc_slow, hover_drop, etc.)
-- Add new ones here and reference by name in card definitions via flightProfile.

return Profiles
