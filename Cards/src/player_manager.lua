-- player_manager.lua: Handles player setup, turn order, round state, attachments, visibility
local PlayerManager = {}
local Config = require("src.config")

local function dprint(...)
    if Config and Config.debug then
        print(...)
    end
end

function PlayerManager.initPlayers(self, players)
    dprint("[DEBUG] PlayerManager.initPlayers called. self:", self)
    self.players = players
    self.playedCount = {}
    for _, player in ipairs(players) do
        assert(player.id, "Player missing id!")
        self.playedCount[player.id] = 0
    end
    local first = players[1]
    self.maxBoardCards = (first and first.maxBoardCards) or (require("src.config").rules.maxBoardCards or 3)
    dprint("[DEBUG] PlayerManager.initPlayers after: players=", #self.players, "maxBoardCards=", self.maxBoardCards)
end

function PlayerManager.initTurnOrder(self)
    dprint("[DEBUG] PlayerManager.initTurnOrder called. self:", self)
    self.roundStartPlayer = love.math.random(#self.players)
    self.microStarter = self.roundStartPlayer
    self.currentPlayer = self.roundStartPlayer
    dprint("[DEBUG] PlayerManager.initTurnOrder after: roundStartPlayer=", self.roundStartPlayer, "currentPlayer=", self.currentPlayer)
end

function PlayerManager.initRoundState(self)
    dprint("[DEBUG] PlayerManager.initRoundState called. self:", self)
    local Config = require("src.config")
    self.roundIndex = (self.roundIndex or 0) + 1
    self.phase = "play"
    self.playsInRound = 0
    self.turnActionCount = 0

    local rules = Config.rules or {}
    local energyStart = rules.energyStart or 0
    local energyInc = rules.energyIncrementPerRound or 0
    local energyMax = rules.energyMax or 99
    local handSize = rules.startingHand or rules.maxHandSize or 3

    -- Reset each player's round state
    for _, player in ipairs(self.players or {}) do
    -- Increment energy per round, capped
    local newEnergy = energyStart + (self.roundIndex - 1) * energyInc
    dprint(string.format("[DEBUG] Player %d roundIndex=%d newEnergy=%d", player.id, self.roundIndex, newEnergy))
    player.energy = math.min(newEnergy, energyMax)
        player.block = 0
        player.discard = {}
        -- Reset board slots
        if player.boardSlots then
            for _, slot in ipairs(player.boardSlots) do
                slot.card = nil
                slot.block = 0
            end
        end
        -- Refill hand up to maxHandSize
        player.hand = player.hand or {}
        local missing = (player.maxHandSize or handSize) - #player.hand
        for i = 1, missing do
            if player.deck and #player.deck > 0 then
                local card = table.remove(player.deck)
                if card then
                    table.insert(player.hand, card)
                end
            end
        end
        dprint(string.format("[DEBUG] Player %d after round reset: energy=%d, hand=%d, deck=%d", player.id, player.energy, #player.hand, #(player.deck or {})))
    end

    -- Reset turn order
    self.roundStartPlayer = love.math.random(#self.players)
    self.microStarter = self.roundStartPlayer
    self.currentPlayer = self.roundStartPlayer

    -- Clear board state
    self.board = self.board or {}
    for i = 1, #self.board do
        self.board[i] = nil
    end

    -- Clear resolve queue
    self.resolveQueue = {}

    -- Re-initialize attachments and visibility
    if self.initAttachments then self:initAttachments() end
    if self.updateCardVisibility then self:updateCardVisibility() end

    dprint("[DEBUG] PlayerManager.initRoundState after: roundIndex=", self.roundIndex, "phase=", self.phase, "turnActionCount=", self.turnActionCount)
end


function PlayerManager.initAttachments(self)
    dprint("[DEBUG] PlayerManager.initAttachments called. self:", self)
    self.attachments = {}
    for index = 1, #self.players do
        self.attachments[index] = {}
    end
    dprint("[DEBUG] PlayerManager.initAttachments after: attachments=", #self.attachments)
end

function PlayerManager.updateCardVisibility(self)
    -- ...moved from GameState:updateCardVisibility...
end

return PlayerManager
