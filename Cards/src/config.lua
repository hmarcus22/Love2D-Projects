local fighters = require "src.fighter_definitions"
local Deep = require "src.utils.deep"
local Serialize = require "src.utils.serialize"

-- Defaults (original values)
local defaults = {
  debug = false, -- Master debug flag - DISABLED to prevent console spam
  debugCategories = {
    animations = false,      -- Animation system debug (disabled for cleaner output)
    animationInit = true,    -- Animation initialization only
    animationErrors = true,  -- Animation errors only
    general = true,          -- General debug info
  },
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
    
    -- Impact and visual effects (moved to layout.highlights.impact)
    cardImpactEnabled = true,      -- Use layout.highlights.impact.enabled instead
    cardImpactDuration = 0.28,     -- Use layout.highlights.impact.duration instead
    cardImpactSquashScale = 0.85,  -- Use layout.highlights.impact.squashScale instead
    cardImpactFlashAlpha = 0.55,   -- Use layout.highlights.impact.flashAlpha instead
  cardImpactHoldExtra = 0.1,       -- Use layout.highlights.impact.holdExtra instead
  
  -- Shadow effects (moved to layout.highlights.shadow)
  cardShadowMinScale = 0.85,       -- Use layout.highlights.shadow.minScale instead
  cardShadowMaxScale = 1.08,       -- Use layout.highlights.shadow.maxScale instead
  cardShadowMinAlpha = 0.25,       -- Use layout.highlights.shadow.minAlpha instead
  cardShadowMaxAlpha = 0.55,       -- Use layout.highlights.shadow.maxAlpha instead
  
  -- Slot effects (moved to layout.highlights.slot)
  cardSlotGlowDuration = 0.35,     -- Use layout.highlights.slot.duration instead
  cardSlotGlowAlpha = 0.55,        -- Use layout.highlights.slot.alpha instead
  
  -- Other visual settings
  cardHoverBaseLift = 18,
  cardDragExtraLift = 24,
  
  -- Card rendering system
    useCardTextureCache = true, -- Pre-render cards to textures for consistent scaling
    cardTextureDebugInfo = false, -- Show cache statistics overlay
    -- Debug: visualize animation landing/ownership
    debugAnimationLanding = true,
  
  -- Card text sizing
  cardNameFontSize = 10,        -- Card name text size
  cardCostFontSize = 8,         -- Energy cost number size  
  cardStatFontSize = 8,         -- Attack/Block/Heal stat text size
  cardDescFontSize = 7,         -- Description text size
  cardBackFontSize = 10,        -- "Deck" text on card backs
  
  -- Text background panel sizing
  cardNamePanelHeight = 26,     -- Height of name background panel
  cardStatsPanelHeight = 18,    -- Height per line for stats background panel
  cardDescPanelPadding = 8,     -- Padding around description background panel
  
  -- Text vertical positioning
  cardNameYOffset = 8,          -- Vertical offset for card name from top
  cardStatsYOffset = 44,        -- Vertical offset for stats area from top
  cardDescYOffset = 60,         -- Vertical offset for description from bottom
    deckPopupW = 320,
    deckPopupH = 240,
    arrowHeadSize = 50,
    arrowThickness = 150,
    -- Fancy arrow rendering (gradient + outline)
    arrows = {
      enabled = true, -- enable shader-based fancy arrows
      -- Default fill for fancy arrows (used if provided); can be tuned live
      fillColor = {1, 1, 0, 1},
      -- Rasterization quality controls (for high-res/retina/fullscreen)
      raster = {
        oversample = 1.0,        -- extra raster scale multiplier
        useDPIScale = false,     -- multiply by love.window.getDPIScale()
        maxSize = 2048,          -- clamp canvas size to this (both dimensions)
      },
      -- Shape controls for the shaft
      shape = {
        enabled = true,          -- enable tapered/curved shaft
        concavity = 0.8,        -- 0..0.6: inward curve at the middle
        segments = 14,           -- sampling resolution along the shaft
        tipWidth = 10,          -- if nil, matches arrow head base width; else a pixel width
      },
      -- Decide where fancy arrows are used by default
      apply = {
        drag = true,             -- use fancy arrow when dragging cards
        attackIndicators = false,-- attack target indicators on board
        modifiers = false,       -- small modifier direction arrows
        resolve = false,         -- resolve-phase arrows
      },
      outline = {
        enabled = true,
        size = 1,                     -- outline thickness in pixels
        color = {1, 1, 1, 1},         -- outline color (default white)
      },
      -- Post-composite alpha fade for entire arrow (outline included)
      fadeAll = {
        enabled = true,
        gamma = 1.0,                  -- controls fade curve along length
      },
      -- Optional inner color gradient (disabled by default; not needed when fadeAll is on)
      innerGradient = {
        enabled = false,
        startColor = {1, 1, 0, 0},    -- transparent tail
        endColor = {1, 1, 0, 1},      -- opaque tip
        gamma = 1.0,
      },
    },
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
    
    -- Consolidated highlight system configuration
    highlights = {
      -- Hover highlights (mouse over cards in hand)
      hover = {
        color = {1, 1, 0.8, 0.85},  -- Warm yellow-white
        width = 3,
        extraWidth = 2,  -- Additional width when fully hovered
        lift = 56,       -- Vertical lift amount
        scale = 0.2,     -- Scale factor for hover growth
        speed = 14,      -- Animation speed
        inSpeed = 14,    -- Speed when hovering in
        outSpeed = 20,   -- Speed when hovering out
      },
      -- Combo highlights (green-white cycling when combo available)
      combo = {
        greenColor = {0.0, 1.0, 0.0, 1.0},  -- Pure bright green
        whiteColor = {1.0, 1.0, 1.0, 1.0},  -- Pure white
        cycleSpeed = 4,   -- Sine wave cycle speed
        width = 6,        -- Thicker than hover
        borderRadius = 15,
        borderOffset = 4, -- Distance from card edge
      },
      -- Impact effects (when cards hit the board)
      impact = {
        enabled = true,
        flashColor = {1, 1, 0.6},  -- Yellow-white flash
        flashAlpha = 0.55,         -- Flash opacity
        duration = 0.28,           -- Total impact duration
        squashScale = 0.85,        -- Vertical compression amount
        holdExtra = 0.1,           -- Extra pause after impact
      },
      -- Board slot highlights (valid drop targets)
      slot = {
        duration = 0.35,
        alpha = 0.55,
      },
      -- Shadow effects (elevation-based shadows)
      shadow = {
        minScale = 0.85,
        maxScale = 1.08,
        minAlpha = 0.25,
        maxAlpha = 0.55,
      },
    },
    -- Card text panel opacities
    cardNamePanelAlpha = 0.78,
    cardStatsPanelAlpha = 0.66,
    cardDescPanelAlpha = 0.78,
    
    -- Layout positioning
    boardTopMargin = 36,
    boardHandGap = 64,
    boardRowMinGap = 20,
    sideGap = 30,
    
    -- Legacy compatibility (moved to highlights section above)
    handHoverLift = 56,        -- Use highlights.hover.lift instead
    handHoverSpeed = 14,       -- Use highlights.hover.speed instead
    handHoverInSpeed = 14,     -- Use highlights.hover.inSpeed instead
    handHoverOutSpeed = 20,    -- Use highlights.hover.outSpeed instead
    handHoverScale = 0.2,      -- Use highlights.hover.scale instead
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

