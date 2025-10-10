-- animation_util.lua
-- Shared helpers for unified animation system

local Config = require 'src.config'

local AnimationUtil = {}

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

AnimationUtil.easing = {
    linear = function(t) return t end,
    easeOutQuad = easeOutQuad,
    easeOutCubic = easeOutCubic,
    easeOutQuart = easeOutQuart,
    easeOutQuint = easeOutQuint,
    easeInOutQuad = easeInOutQuad,
    easeOutElastic = easeOutElastic,
    easeOutBack = easeOutBack
}

function AnimationUtil.getEasing(name)
    return AnimationUtil.easing[name] or AnimationUtil.easing.linear
end

-- Math helpers
function AnimationUtil.lerp(a, b, t) return a + (b - a) * t end
function AnimationUtil.clamp(x, minv, maxv)
    if x < minv then return minv end
    if x > maxv then return maxv end
    return x
end
function AnimationUtil.saturate(t) return AnimationUtil.clamp(t, 0.0, 1.0) end

-- Clamp dt into a sane range to prevent runaway loops
function AnimationUtil.clampDt(dt, minDt, maxDt)
    minDt = minDt or 0.000001
    maxDt = maxDt or 1.0
    if not dt or dt <= 0 then return 0 end
    if dt > maxDt then return maxDt end
    if dt < minDt then return minDt end
    return dt
end

-- Table helpers
function AnimationUtil.deepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then out[k] = AnimationUtil.deepCopy(v) else out[k] = v end
    end
    return out
end

-- Shallow merge tables; if values are tables, merge one level deep
function AnimationUtil.mergeSpecs(base, override)
    local merged = AnimationUtil.deepCopy(base or {})
    for k, v in pairs(override or {}) do
        if type(v) == 'table' and type(merged[k]) == 'table' then
            for k2, v2 in pairs(v) do
                merged[k][k2] = v2
            end
        else
            merged[k] = v
        end
    end
    return merged
end

function AnimationUtil.getByPath(tbl, path, defaultValue)
    local cur = tbl
    for part in tostring(path):gmatch("[^%.]+") do
        if type(cur) ~= 'table' then return defaultValue end
        cur = cur[part]
        if cur == nil then return defaultValue end
    end
    return cur
end

-- Normalize known trajectory type synonyms
function AnimationUtil.normalizeTrajectoryType(t)
    if type(t) ~= 'string' then return nil end
    local n = string.lower(t)
    if n == 'ballistic' then return 'physics' end
    if n == 'physics' or n == 'interpolated' or n == 'guided' then return n end
    return n
end

-- Debug printer factory
function AnimationUtil.makeDebugPrinter(enabled, prefix)
    local pfx = prefix or ''
    return function(...)
        if enabled or (Config and Config.debug) then
            if pfx ~= '' then io.write(pfx .. ' ') end
            print(...)
        end
    end
end

return AnimationUtil

