local Config = require "src.config"

local RoundManager = {}

local function resetPlayedCount(state)
    if not state.playedCount then
        return
    end

    for id in pairs(state.playedCount) do
        state.playedCount[id] = 0
    end
end

local function refillEnergyForRound(state, rules, roundIndex)
    if rules.energyEnabled == false then
        return
    end

    local startE = rules.energyStart or 0
    local incE = rules.energyIncrementPerRound or 0
    local steps = math.max(0, (roundIndex or 0) - 1)
    local target = startE + steps * incE
    local maxE = rules.energyMax
    if maxE and maxE > 0 then
        target = math.min(target, maxE)
    end
    if target < 0 then
        target = 0
    end

    for _, player in ipairs(state.players or {}) do
        player.energy = target
    end
end

local function autoDrawForPlayers(state, rules)
    local amount = rules.autoDrawPerRound or 0
    if amount <= 0 then
        return
    end

    for idx = 1, #(state.players or {}) do
        for _ = 1, amount do
            state:drawCardToPlayer(idx)
        end
    end
end

function RoundManager.finishResolve(state)
    state.phase = "play"
    state.resolveCurrentStep = nil
    state.resolveQueue = {}
    state.resolveIndex = 0
    state.resolveTimer = 0
    state.activeMods = nil

    state.lastActionWasPass = false
    state.lastPassBy = nil
    state.turnActionCount = 0

    resetPlayedCount(state)

    if state.initAttachments then
        state:initAttachments()
    end

    if state.resetRoundFlags then
        state:resetRoundFlags()
    end
    if state.activateRoundStatuses then
        state:activateRoundStatuses()
    end

    local rules = Config.rules or {}

    autoDrawForPlayers(state, rules)

    local newRoundIndex = (state.roundIndex or 0) + 1
    state.roundIndex = newRoundIndex

    refillEnergyForRound(state, rules, newRoundIndex)

    local playerCount = state.players and #state.players or 0
    if playerCount > 0 then
        local start = state.roundStartPlayer or 1
        state.roundStartPlayer = (start % playerCount) + 1
        state.microStarter = state.roundStartPlayer
        state.currentPlayer = state.roundStartPlayer
    end

    if state.ensureCurrentPlayerReady then
        state:ensureCurrentPlayerReady()
    end
    if state.updateCardVisibility then
        state:updateCardVisibility()
    end
    if state.drawCardsForTurnStart then
        state:drawCardsForTurnStart()
    end

    if state.addLog then
        state:addLog("Resolve phase complete")
    end
end

return RoundManager
