return {
  window = {
    width = 2000,
    height = 1200,
    flags = {
      resizable = true,
      highdpi = false,
      minwidth = 800,
      minheight = 480,
    },
  },
  rules = {
    maxHandSize = 5,
    maxBoardCards = 3,
    startingHand = 4,

    allowManualDraw = true,
    allowManualDiscard = true,
    showDiscardPile = true,

    autoDrawPerRound = 2,      -- draw X for each player after resolve
    autoDrawOnTurnStart = 2,   -- draw X for current player on turn start

    -- Energy / cost system
    energyEnabled = true,      -- enforce card costs when playing
    energyStart = 3,           -- starting energy at round 0
    energyIncrementPerRound = 1, -- energy added to the refill each round
  },
  draft = {
    deckSize = 12,
    pool = {
      { id = "strike", count = 10 },
      { id = "heal", count = 5 },
      { id = "block", count = 10 },
      { id = "fireball", count = 4 },
      { id = "banner", count = 4 },
      { id = "hex", count = 4 },
      { id = "rally", count = 3 },
      { id = "duelist", count = 3 },
      { id = "feint", count = 5 },
    },
  },
  ui = {
    showDeckCount = true,
  },
  layout = {
    designWidth = 2000,
    designHeight = 1200,
    scaleFactor = 2.0,
    slotSpacing = 110,
    cardW = 100,
    cardH = 150,
    handBottomMargin = 20,
    boardTopMargin = 80,
    boardHandGap = 30,
    sideGap = 30,
  }
}

