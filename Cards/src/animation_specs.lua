-- animation_specs.lua
-- Loads default animation specs + optional overrides, provides normalized per-card specs
local Deep = require 'src.utils.deep'
local Profiles = require 'src.flight_profiles'

local defaults = require 'src.animation_specs_defaults'

local AnimationSpecs = {}
local overrides = nil -- loaded diff table
local merged = nil    -- deep merged defaults + overrides
local cache = {}      -- normalized per-card spec cache

local function safeLoadOverrides()
  if not love or not love.filesystem then return {} end
  local info = love.filesystem.getInfo('card_animation_overrides.lua')
  if not info then return {} end
  local chunk, err = love.filesystem.load('card_animation_overrides.lua')
  if not chunk then
    print('[AnimSpecs] Failed to load overrides:', err)
    return {}
  end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= 'table' then
    print('[AnimSpecs] Overrides file returned non-table')
    return {}
  end
  return data
end

function AnimationSpecs.load()
  overrides = safeLoadOverrides()
  merged = Deep.clone(defaults)
  if overrides.cards then
    merged.cards = merged.cards or {}
    for cid, patch in pairs(overrides.cards) do
      merged.cards[cid] = merged.cards[cid] or {}
      Deep.merge(merged.cards[cid], patch)
    end
  end
  cache = {}
end

local function resolveEasing(name)
  if name == 'easeOutQuad' then
    return function(t) return 1 - (1 - t) * (1 - t) end
  elseif name == 'linear' then
    return function(t) return t end
  end
  return function(t) return 1 - (1 - t) * (1 - t) end
end

local function clone(tbl)
  local t = {}
  for k,v in pairs(tbl or {}) do
    if type(v) == 'table' then t[k] = clone(v) else t[k] = v end
  end
  return t
end

local function normalize(cardId)
  local global = merged.global or {}
  local gFlight = global.flight or {}
  local gImpact = global.impact or {}
  local gDebug  = global.debug or {}
  local card = (merged.cards and merged.cards[cardId]) or {}
  local cFlight = card.flight or {}
  local cImpact = card.impact or {}
  local spec = {
    flight = clone(gFlight); impact = clone(gImpact); debug = clone(gDebug)
  }
  Deep.merge(spec.flight, cFlight)
  Deep.merge(spec.impact, cImpact)

  -- Derived / sanitation
  spec.flight.duration = math.max(0.01, spec.flight.duration or 0.35)
  spec.flight.overshoot = math.max(0, spec.flight.overshoot or 0)
  spec.flight.arcHeight = math.max(0, spec.flight.arcHeight or 0)
  spec.flight.arcScale  = spec.flight.arcScale or 1
  spec.flight.profile = spec.flight.profile or 'default'

  local prof = Profiles.get(spec.flight.profile)
  spec.flight.profileMeta = prof
  -- Only adopt profile metadata if overrides are enabled (checked later in gamestate) but include them for potential use.
  if prof.duration and spec.flight.duration == gFlight.duration then
    -- Only auto-apply profile duration if user hasn't explicitly overridden
    spec.flight.duration = prof.duration
  end
  if prof.overshoot ~= nil and spec.flight.overshoot == gFlight.overshoot then
    spec.flight.overshoot = prof.overshoot
  end
  if prof.arcScale and spec.flight.arcScale == 1 then
    spec.flight.arcScale = prof.arcScale
  end
  if prof.slamStyle then spec.flight.slamStyle = true end

  spec.flight.easingFn = resolveEasing(spec.flight.easing)

  return spec
end

function AnimationSpecs.getCardSpec(cardId)
  if not merged then AnimationSpecs.load() end
  if cache[cardId] then return cache[cardId] end
  local spec = normalize(cardId)
  cache[cardId] = spec
  return spec
end

function AnimationSpecs.setCardSpec(cardId, patch)
  if not merged then AnimationSpecs.load() end
  merged.cards = merged.cards or {}
  merged.cards[cardId] = merged.cards[cardId] or { flight = {}, impact = {} }
  Deep.merge(merged.cards[cardId], patch)
  cache[cardId] = nil
end

local function buildDiffCard(defaultCard, mergedCard)
  local diff = {}
  for section, data in pairs(mergedCard) do
    local base = defaultCard and defaultCard[section] or nil
    if type(data) == 'table' then
      for k,v in pairs(data) do
        local baseV = base and base[k]
        if baseV ~= v then
          diff[section] = diff[section] or {}
          diff[section][k] = v
        end
      end
    end
  end
  return next(diff) and diff or nil
end

function AnimationSpecs.saveOverrides()
  if not merged then return false end
  local diff = { cards = {} }
  for cid, mergedCard in pairs(merged.cards or {}) do
    local base = (defaults.cards and defaults.cards[cid]) or {}
    local d = buildDiffCard(base, mergedCard)
    if d then diff.cards[cid] = d end
  end
  if not next(diff.cards) then
    print('[AnimSpecs] No diffs to save.')
    return true
  end
  local Serialize = require 'src.utils.serialize'
  local body = 'return ' .. Serialize.to_lua(diff, 0) .. '\n'
  if love and love.filesystem then
    local ok, err = love.filesystem.write('card_animation_overrides.lua', body)
    if not ok then
      print('[AnimSpecs] Failed to write overrides:', err)
      return false
    end
    print('[AnimSpecs] Overrides saved.')
    return true
  end
  return false
end

function AnimationSpecs.resetCard(cardId)
  if not merged then AnimationSpecs.load() end
  if merged.cards then merged.cards[cardId] = nil end
  cache[cardId] = nil
end

function AnimationSpecs.resetAll()
  overrides = {}
  merged = Deep.clone(defaults)
  cache = {}
end

return AnimationSpecs
