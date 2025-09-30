local Card = require "src.card"
local Config = require "src.config"

local Initialiser = {}

function Initialiser.initPlayers(state, players)
    state.players = players
    state.playedCount = {}
    for _, player in ipairs(players) do
        assert(player.id, "Player missing id!")
        state.playedCount[player.id] = 0
    end
    local first = players[1]
    state.maxBoardCards = (first and first.maxBoardCards) or (Config.rules.maxBoardCards or 3)
end

function Initialiser.initTurnOrder(state)
    state.roundStartPlayer = love.math.random(#state.players)
    state.microStarter = state.roundStartPlayer
    state.currentPlayer = state.roundStartPlayer
end

function Initialiser.initRoundState(state)
    state.roundIndex = 0
    state.phase = "play"
    state.playsInRound = 0
    state.turnActionCount = 0
end

function Initialiser.initUiState(state, hasSharedDeck)
    state.allCards = {}
    state.draggingCard = nil

    if hasSharedDeck then
        state.deckStack = Card(-1, "Deck", 0, 0)
        state.deckStack.faceUp = false
    else
        state.deckStack = nil
    end

    state.discardStack = Card(-2, "Discard", 0, 0)
    state.discardStack.faceUp = false
    state.discardPile = {}
    state.highlightDiscard = false
    state.highlightPass = false
end

function Initialiser.initAttachments(state)
    state.attachments = {}
    for index = 1, #state.players do
        state.attachments[index] = {}
    end
end

function Initialiser.initResolveState(state)
    state.resolveQueue = {}
    state.resolveIndex = 0
    state.resolveTimer = 0
    state.resolveStepDuration = 0.5
    state.resolveCurrentStep = nil

    state.resolveLog = {}
    state.maxResolveLogLines = 14
    table.insert(state.resolveLog, string.format("Coin toss: P%d starts", state.roundStartPlayer))
end

function Initialiser.applyInitialEnergy(state)
    if Config.rules.energyEnabled ~= false then
        local startE = Config.rules.energyStart or 0
        local maxE = Config.rules.energyMax
        local value = startE
        if maxE then
            value = math.min(value, maxE)
        end
        for _, player in ipairs(state.players) do
            player.energy = value
        end
    end
end

function Initialiser.dealStartingHandsFromPlayerDecks(state)
    for _, player in ipairs(state.players) do
        local startN = (Config.rules.startingHand or player.maxHandSize or 3)
        for _ = 1, startN do
            local card = table.remove(player.deck)
            if card then
                player:addCard(card)
                table.insert(state.allCards, card)
            end
        end
    end
end

return Initialiser

