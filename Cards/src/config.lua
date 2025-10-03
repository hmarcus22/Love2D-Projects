local fighters = require "src.fighter_definitions"
local Deep = require "src.utils.deep"
local Serialize = require "src.utils.serialize"

-- Defaults (original values)
local defaults = {
  window = {
    width = 1000,
    height = 600,
    flags = {
      resizable = true,
      highdpi = false,
      minwidth = 800,
      minheight = 480,
    },
  },
  rules = {
    maxHandSize = 6,
    maxBoardCards = 3,
    startingHand = 6,

    allowManualDraw = true,
    allowManualDiscard = true,
    showDiscardPile = true,

    autoDrawPerRound = 2,      -- draw X for each player after resolve
    autoDrawOnTurnStart = 2,   -- draw X for current player on turn start

    -- Energy / cost system
    energyEnabled = true,      -- enforce card costs when playing
    energyStart = 2,           -- starting energy at round 0
    energyIncrementPerRound = 2, -- energy added to the refill each round
    energyMax = 6,             -- cap the per-round energy refill
  },
  draft = {
    deckSize = 12,
    -- Vertical position of the draft choice row (in virtual pixels from top)
    topMargin = 100,
    -- Horizontal gap between draft choice cards (pixels added between card edges)
    cardGap = 18,
    -- Vertical offset for the player deck rows below topMargin (smaller = closer to header text)
    deckTopOffset = 240,
    -- Horizontal gap between cards in each player's deck row
    deckRowGap = 24,
    -- Fraction of card width to overlap in deck rows (0 = no overlap)
    deckOverlap = 0.95,
    -- Wrap long deck rows into multiple lines during draft
    deckWrap = true,
    deckWrapRowGap = 20,
    -- Draft-specific hover tuning
    hoverSpeed = 16,
    hoverInSpeed = 16,
    hoverOutSpeed = 24,
    hoverScale = 0.22,
    deckHoverScale = 0.18,
    -- Background for draft screen
    background = {
      path = "assets/backgrounds/Draft.png",
      fit = "cover", -- cover or stretch
      -- tint = {1, 1, 1, 1}, -- optional tint/alpha (modulates the image)
      -- Blur controls
      blurAmount = 2,   -- 0 = off; try 2..6 for soft blur
      blurPasses = 2,   -- number of horizontal+vertical pass pairs
      -- Overlay fade drawn on top (use black + alpha for a soft fade)
      overlayColor = {0, 0, 0},
      overlayAlpha = 0.6,
    },
    pool = {
      { id = "punch", count = 12 },
      { id = "kick", count = 8 },
      { id = "block", count = 12 },
      { id = "guard", count = 6 },
      { id = "feint", count = 6 },
      { id = "rally", count = 6 },
      { id = "banner", count = 4 },
      { id = "adrenaline_rush", count = 4 },
      { id = "taunt", count = 4 },
      { id = "hex", count = 4 },
      { id = "counter", count = 4 },
      { id = "uppercut", count = 4 },
      { id = "roundhouse", count = 3 },
    },
  },
  fighters = fighters,
  ui = {
    showDeckCount = false,
    buttonW = 120,
    buttonH = 32,
    cardFlightEnabled = true,
    cardFlightDuration = 0.35,
  cardFlightCurve = "arc", -- 'arc' or 'linear'
  cardFlightArcHeight = 140,
  cardFlightOvershoot = 0.12,
  -- If false, per-card/profile override metadata (duration/overshoot/arcScale/slamStyle) are ignored;
  -- horizontal shaping still applies but timing falls back to global defaults.
  useAnimationOverrides = true,
    cardImpactEnabled = true,
    cardImpactDuration = 0.28,
    cardImpactSquashScale = 0.85, -- vertical squash minimum
    cardImpactFlashAlpha = 0.55,
  cardImpactHoldExtra = 0.1, -- extra pause after impact before advancing turn
  cardHoverBaseLift = 18,
  cardDragExtraLift = 24,
  cardShadowMinScale = 0.85,
  cardShadowMaxScale = 1.08,
  cardShadowMinAlpha = 0.25,
  cardShadowMaxAlpha = 0.55,
  cardSlotGlowDuration = 0.35,
  cardSlotGlowAlpha = 0.55,
    deckPopupW = 320,
    deckPopupH = 240,
    arrowHeadSize = 16,
    arrowThickness = 3,
  },
  colors = {
    button = {0.2, 0.2, 0.6, 0.85},
    buttonHover = {0.35, 0.35, 0.8, 1},
    passButton = {0.85, 0.85, 0.85, 1},
    passButtonHover = {0.95, 0.95, 0.95, 1},
    arrow = {1, 1, 0, 1},
    attackArrow = {0.9, 0.2, 0.2, 0.8},
    deckPopupBg = {0, 0, 0, 0.85},
    deckPopupBorder = {1, 1, 1, 1},
  },
  layout = {
    designWidth = 1000,
    designHeight = 600,
    scaleFactor = 1.0,
    pixelPerfect = true,
    slotSpacing = 132,
    cardW = 128,
    cardH = 192,
    handBottomMargin = -40,
    handAreaWidth = 560,
    handReferenceCount = 5,
    handMinSpacingFactor = 0.35,
    handHoverLift = 56,
    handHoverSpeed = 14,
    handHoverInSpeed = 14,
    handHoverOutSpeed = 20,
    handHoverScale = 0.2,
    -- Use the visually scaled hover size for hand hit-testing (hover/click)
    handHoverHitScaled = false,
    -- Hover glow styling (used across states)
    hoverGlow = {
      color = {1, 1, 0.8, 0.85},
      width = 3,
      extraWidth = 2,
    },
    -- Card text panel opacities
    cardNamePanelAlpha = 0.78,
    cardStatsPanelAlpha = 0.66,
    cardDescPanelAlpha = 0.78,
    boardTopMargin = 36,
    boardHandGap = 64,
    boardRowMinGap = 20,
    sideGap = 30,
  }
}

-- Limit which top-level keys we persist in overrides
local PERSIST_KEYS = { window=true, rules=true, draft=true, ui=true, colors=true, layout=true }

local function loadOverrides()
  if not love or not love.filesystem then return {} end
  local info = love.filesystem.getInfo("config_overrides.lua")
  if not info then return {} end
  local chunk, err = love.filesystem.load("config_overrides.lua")
  if not chunk then
    print("[Config] Failed to load overrides:", err)
    return {}
  end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= "table" then
    print("[Config] Overrides file returned non-table")
    return {}
  end
  return data
end

local baseDefaults = Deep.clone(defaults)
local overrides = loadOverrides()
Deep.merge(defaults, overrides)

local Config = defaults

-- Internal: set by dotted path on Config
local function setByPath(path, value)
  return Deep.set_by_path(Config, path, value)
end

local function getByPath(path)
  return Deep.get_by_path(Config, path)
end

-- Save only diffs relative to original defaults
function Config.saveOverrides()
  if not love or not love.filesystem then return false end
  local diff = Deep.diff(Config, baseDefaults, PERSIST_KEYS)
  local body = "return " .. Serialize.to_lua(diff, 0) .. "\n"
  local ok, err = love.filesystem.write("config_overrides.lua", body)
  if not ok then
    print("[Config] Failed to write overrides:", err)
    return false
  end
  print("[Config] Overrides saved.")
  return true
end

-- Reset a single path to default
function Config.reset(path)
  local def = Deep.get_by_path(baseDefaults, path)
  if def ~= nil then
    Deep.set_by_path(Config, path, Deep.clone(def))
    return true
  end
  return false
end

-- Apply a batch of { [path]=value }
function Config.applyOverrides(map)
  if type(map) ~= "table" then return end
  for p, v in pairs(map) do
    setByPath(p, v)
  end
end

-- Simple getters/setters
function Config.set(path, value)
  return setByPath(path, value)
end

function Config.get(path)
  return getByPath(path)
end

return Config

