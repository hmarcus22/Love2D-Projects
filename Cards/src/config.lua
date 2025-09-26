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
    deckSize = 14,
    pool = {
      { id = "punch", count = 10 },
      { id = "kick", count = 8 },
      { id = "block", count = 10 },
      { id = "guard", count = 6 },
      { id = "uppercut", count = 4 },
      { id = "feint", count = 4 },
      { id = "taunt", count = 3 },
      { id = "guard_up", count = 3 },
      { id = "adrenaline_rush", count = 3 },
      { id = "counter", count = 3 },
      { id = "roundhouse", count = 2 },
    },
  },
  fighters = fighters,
  ui = {
    showDeckCount = true,
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
    slotSpacing = 110,
    cardW = 100,
    cardH = 150,
    handBottomMargin = 20,
    handAreaWidth = 560,
    handReferenceCount = 5,
    handMinSpacingFactor = 0.35,
    handHoverLift = 24,
    handHoverSpeed = 12,
    boardTopMargin = 80,
    boardHandGap = 30,
    sideGap = 30,
  }
}
