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
    autoDrawOnTurnStart = 0,   -- draw X for current player on turn start

    -- Energy / cost system
    energyEnabled = true,      -- enforce card costs when playing
    energyStart = 3,           -- starting energy at round 0
    energyIncrementPerRound = 1, -- energy added to the refill each round
  },
  ui = {
    showDeckCount = true,
  },
  layout = {
    slotSpacing = 110,
    cardW = 100,
    cardH = 150,
    handBottomMargin = 20,
    boardTopMargin = 80,
    boardHandGap = 30,
    sideGap = 30,
  }
}
