return {
  rules = {
    maxHandSize = 5,
    maxBoardCards = 3,
    startingHand = 3,

    allowManualDraw = true,
    allowManualDiscard = true,
    showDiscardPile = true,

    autoDrawPerRound = 0,      -- draw X for each player after resolve
    autoDrawOnTurnStart = 0,   -- draw X for current player on turn start
  },
  ui = {
    showDeckCount = true,
  },
  layout = {
    slotSpacing = 110,
    handLeftX = 150,
    cardW = 100,
    cardH = 150,
  }
}

