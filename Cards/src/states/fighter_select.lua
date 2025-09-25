local Gamestate = require "libs.hump.gamestate"
local draft = require "src.states.draft"
local Player = require "src.player"
local Config = require "src.config"
local Viewport = require "src.viewport"

local fighter_select = {}

local function getFighterCatalog()
    local catalog = Config.fighters or {}
    return catalog.list or {}, catalog.byId or {}
end

local function defaultDimensions()
    local layout = Config.layout or {}
    local cardW = (layout.cardW or 100) * 1.4
    local cardH = (layout.cardH or 150) * 1.15
    local spacing = (layout.slotSpacing or (cardW + 30)) * 1.1
    return cardW, cardH, spacing
end

function fighter_select:enter()
    local list, byId = getFighterCatalog()
    self.fighters = list
    self.fightersById = byId
    self.currentPlayer = 1
    self.selections = {}
    self.buttons = {}

    for i, fighter in ipairs(self.fighters) do
        self.buttons[i] = { fighter = fighter, claimedBy = nil }
    end

    self:updateButtonPositions()
end

function fighter_select:updateButtonPositions()
    local cardW, cardH, spacing = defaultDimensions()
    local count = #self.buttons
    if count == 0 then
        return
    end

    local screenW = Viewport.getWidth()
    local screenH = Viewport.getHeight()
    local totalWidth = cardW + spacing * math.max(0, count - 1)
    local startX = math.floor((screenW - totalWidth) / 2)
    local y = math.floor((screenH - cardH) / 2)

    for index, entry in ipairs(self.buttons) do
        entry.x = startX + (index - 1) * spacing
        entry.y = y
        entry.w = cardW
        entry.h = cardH
    end
end

function fighter_select:update()
    self:updateButtonPositions()
end

local function drawButton(entry)
    local fighter = entry.fighter
    local color = (fighter and fighter.color) or { 0.7, 0.7, 0.7 }
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1

    local fillAlpha = entry.claimedBy and 0.8 or 0.25
    local borderAlpha = entry.claimedBy and 0.95 or 0.7

    love.graphics.setColor(r, g, b, fillAlpha)
    love.graphics.rectangle("fill", entry.x, entry.y, entry.w, entry.h, 16, 16)

    love.graphics.setColor(r, g, b, borderAlpha)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", entry.x, entry.y, entry.w, entry.h, 16, 16)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(fighter.name or "Fighter", entry.x, entry.y + 14, entry.w, "center")

    love.graphics.setColor(1, 1, 1, 0.85)
    local descY = entry.y + 46
    love.graphics.printf(fighter.description or "", entry.x + 12, descY, entry.w - 24, "left")

    if entry.claimedBy then
        local label = string.format("P%d", entry.claimedBy)
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", entry.x, entry.y + entry.h - 44, entry.w, 36, 12, 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label .. " locked", entry.x, entry.y + entry.h - 38, entry.w, "center")
    end
end

function fighter_select:draw()
    Viewport.apply()

    local screenW = Viewport.getWidth()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Fighter", 0, 60, screenW, "center")

    local instruction
    if self.currentPlayer and self.currentPlayer <= 2 then
        instruction = string.format("Player %d, pick your champion", self.currentPlayer)
    else
        instruction = "Waiting for selections..."
    end
    love.graphics.printf(instruction, 0, 100, screenW, "center")

    for _, entry in ipairs(self.buttons) do
        drawButton(entry)
    end

    Viewport.unapply()
end

local function within(entry, x, y)
    return x >= entry.x and x <= (entry.x + entry.w) and y >= entry.y and y <= (entry.y + entry.h)
end

function fighter_select:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local vx, vy = Viewport.toVirtual(x, y)
    for _, entry in ipairs(self.buttons) do
        if within(entry, vx, vy) then
            if not entry.claimedBy then
                self:claim(entry)
            end
            return
        end
    end
end

function fighter_select:claim(entry)
    if not self.currentPlayer then
        return
    end

    entry.claimedBy = self.currentPlayer
    self.selections[self.currentPlayer] = entry.fighter

    if self.currentPlayer == 1 then
        self.currentPlayer = 2
        return
    end

    -- If player 2 just picked but player 1 somehow missing, cycle back.
    if not self.selections[1] then
        self.currentPlayer = 1
        entry.claimedBy = nil
        self.selections[2] = nil
        return
    end

    self:startDraft()
end

function fighter_select:startDraft()
    local rules = Config.rules or {}
    local maxHand = rules.maxHandSize or 5
    local maxBoard = rules.maxBoardCards or 3

    local players = {}
    for i = 1, 2 do
        local fighter = self.selections[i]
        local args = {
            id = i,
            maxHandSize = maxHand,
            maxBoardCards = maxBoard,
        }
        local player = Player(args)
        if fighter then
            player:setFighter(fighter)
        end
        players[i] = player
    end

    Gamestate.switch(draft, players)
end

return fighter_select
