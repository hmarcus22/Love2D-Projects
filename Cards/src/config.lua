local fighters = require "src.fighter_definitions"

return {
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

