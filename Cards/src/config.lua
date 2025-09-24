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
      { id = "kick", count = 6 },
      { id = "heal", count = 5 },
      { id = "block", count = 10 },
      { id = "fireball", count = 4 },
      { id = "banner", count = 4 },
      { id = "hex", count = 4 },
      { id = "rally", count = 3 },
      { id = "duelist", count = 3 },
      { id = "feint", count = 3 },
    },
  },
  fighters = fighters,
  ui = {
    showDeckCount = true,
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
