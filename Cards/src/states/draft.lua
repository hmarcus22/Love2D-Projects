local Gamestate = require "libs.hump.gamestate"
local game = require "src.states.game"
local Player = require "src.player"
local factory = require "src.card_factory"
local Viewport = require "src.viewport"
local Config = require "src.config"

local DEFAULT_DECK_SIZE = 14
local DEFAULT_DRAFT_POOL = {
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
}

local draft = {}

local function buildDraftPool()
    local draftConfig = Config.draft or {}
    local poolConfig = draftConfig.pool or DEFAULT_DRAFT_POOL
    local pool = {}
    for _, entry in ipairs(poolConfig) do
        local id = entry.id
        local count = entry.count or 1
        if id and count > 0 then
            for _, card in ipairs(factory.createCopies(id, count)) do
                table.insert(pool, card)
            end
        end
    end
    return pool
end

function draft:shuffleDraftPool()
    for i = #self.draftPool, 2, -1 do
        local j = love.math.random(i)
        self.draftPool[i], self.draftPool[j] = self.draftPool[j], self.draftPool[i]
    end
end

function draft:enter(previous, players)
    local rules = Config.rules or {}
    local maxHand = rules.maxHandSize or 5
    local maxBoard = rules.maxBoardCards or 3

    if players and #players > 0 then
        self.players = {}
        for idx, p in ipairs(players) do
            p.maxHandSize = p.maxHandSize or maxHand
            p.maxBoardCards = p.maxBoardCards or maxBoard
            p.deck = {}
            self.players[idx] = p
        end
    else
        self.players = {
            Player{ id = 1, maxHandSize = maxHand, maxBoardCards = maxBoard },
            Player{ id = 2, maxHandSize = maxHand, maxBoardCards = maxBoard },
        }
    end

    self.currentPlayer = 1

    local draftConfig = Config.draft or {}
    self.targetDeckSize = draftConfig.deckSize or DEFAULT_DECK_SIZE

    self.draftPool = buildDraftPool()
    self:shuffleDraftPool()

    self.choices = {}
    self:nextChoices()
end
function draft:updateChoicePositions()
    local layout = Config.layout or {}
    local cardW = layout.cardW or 100
    local cardH = layout.cardH or 150
    local gap = (layout.sideGap or 30) * 2
    local spacing = cardW + gap
    local count = #self.choices
    if count == 0 then return end

    local totalWidth = cardW + spacing * math.max(0, count - 1)
    local startX = math.floor((Viewport.getWidth() - totalWidth) / 2)
    local choiceY = math.floor((Viewport.getHeight() - cardH) / 2)

    for i, c in ipairs(self.choices) do
        c.x = startX + (i - 1) * spacing
        c.y = choiceY
    end
end

function draft:nextChoices()
    if #self.choices > 0 then return end

    for _ = 1, 3 do
        local card = table.remove(self.draftPool)
        if not card then break end
        table.insert(self.choices, card)
    end

    self:updateChoicePositions()
end

function draft:draw()
    Viewport.apply()
    love.graphics.setColor(1, 1, 1)
    local screenW = Viewport.getWidth()
    love.graphics.printf("Draft Phase", 0, 40, screenW, "center")

    local prompt = string.format("Player %d choose a card", self.currentPlayer)
    local current = self.players and self.players[self.currentPlayer]
    if current and current.getFighter then
        local fighter = current:getFighter()
        if fighter then
            local label = fighter.shortName or fighter.name or ""
            prompt = string.format("Player %d (%s) choose a card", self.currentPlayer, label)
        end
    end
    love.graphics.printf(prompt, 0, 80, screenW, "center")

    self:updateChoicePositions()

    local highlightPlayer = self.players and self.players[self.currentPlayer]
    for _, c in ipairs(self.choices) do
        c:draw()
        if highlightPlayer and highlightPlayer.isCardFavored and highlightPlayer:isCardFavored(c.definition) then
            love.graphics.setColor(1, 1, 0.4, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", c.x - 6, c.y - 6, (c.w or 100) + 12, (c.h or 150) + 12, 12, 12)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    local screenH = Viewport.getHeight()
    local miniCardW = 50
    local miniCardH = 70
    local miniSpacing = 60

    for i, p in ipairs(self.players) do
        local rowY = screenH - (i * 90)

        love.graphics.setColor(1, 1, 1)
        local fighter = p.getFighter and p:getFighter()
        local fighterLabel = fighter and (fighter.shortName or fighter.name)
        local header = string.format("Player %d deck (%d/%d)", i, #p.deck, self.targetDeckSize)
        if fighterLabel and fighterLabel ~= "" then
            header = header .. string.format(" - %s", fighterLabel)
        end
        love.graphics.printf(header .. ":", 0, rowY - 30, screenW, "center")

        local count = math.max(1, #p.deck)
        local totalWidth = miniCardW + miniSpacing * math.max(0, count - 1)
        local startX = math.floor((screenW - totalWidth) / 2)

        if #p.deck == 0 then
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.rectangle("line", startX, rowY, miniCardW, miniCardH, 6, 6)
            love.graphics.setColor(1, 1, 1)
        else
            for j, c in ipairs(p.deck) do
                local cx = startX + (j - 1) * miniSpacing
                local cy = rowY

                love.graphics.setColor(1, 1, 1)
                love.graphics.rectangle("fill", cx, cy, miniCardW, miniCardH, 6, 6)
                love.graphics.setColor(0, 0, 0)
                love.graphics.rectangle("line", cx, cy, miniCardW, miniCardH, 6, 6)

                love.graphics.printf(c.name, cx + 2, cy + 25, miniCardW - 4, "center")
            end
        end
    end
    Viewport.unapply()
end
function draft:mousepressed(x, y, button)
    if button ~= 1 then return end
    x, y = Viewport.toVirtual(x, y)
    self:updateChoicePositions()

    for i, card in ipairs(self.choices) do
        if card:isHovered(x, y) then
            table.insert(self.players[self.currentPlayer].deck, card)
            table.remove(self.choices, i)

            local allComplete = true
            for _, player in ipairs(self.players) do
                if #player.deck < self.targetDeckSize then
                    allComplete = false
                    break
                end
            end

            if allComplete then
                Gamestate.switch(game, self.players)
                return
            end

            self:nextChoices()
            self.currentPlayer = self.currentPlayer % #self.players + 1
            break
        end
    end
end

return draft



