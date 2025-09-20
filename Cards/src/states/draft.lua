local Gamestate = require "libs.hump.gamestate"
local Card = require "src.card"
local game = require "src.states.game"
local Player = require "src.player"
local factory = require "src.card_factory"
local Viewport = require "src.viewport"
local Config = require "src.config"

-- Config-driven limits for hand and board sizes

local draft = {}

function draft:enter()
    -- setup players with empty decks
   self.players = {
        Player{ id = 1, maxHandSize = (Config.rules.maxHandSize or 5), maxBoardCards = (Config.rules.maxBoardCards or 3) },
        Player{ id = 2, maxHandSize = (Config.rules.maxHandSize or 5), maxBoardCards = (Config.rules.maxBoardCards or 3) }
    }
    self.players[1].deck = {}
    self.players[2].deck = {}
    self.currentPlayer = 1

    -- build draft pool from card pool
    self.draftPool = {}
    -- add 10 Strikes
    for _, c in ipairs(factory.createCopies("strike", 10)) do
        table.insert(self.draftPool, c)
    end
    -- add 5 Heals
    for _, c in ipairs(factory.createCopies("heal", 5)) do
        table.insert(self.draftPool, c)
    end
    -- add 10 Blocks
    for _, c in ipairs(factory.createCopies("block", 10)) do
        table.insert(self.draftPool, c)
    end
    -- add 4 Fireballs
    for _, c in ipairs(factory.createCopies("fireball", 4)) do
        table.insert(self.draftPool, c)
    end
    -- add some modifiers
    for _, c in ipairs(factory.createCopies("banner", 4)) do
        table.insert(self.draftPool, c)
    end
    for _, c in ipairs(factory.createCopies("hex", 4)) do
        table.insert(self.draftPool, c)
    end
    for _, c in ipairs(factory.createCopies("rally", 3)) do
        table.insert(self.draftPool, c)
    end
    for _, c in ipairs(factory.createCopies("duelist", 3)) do
        table.insert(self.draftPool, c)
    end
    for _, c in ipairs(factory.createCopies("feint", 5)) do
        table.insert(self.draftPool, c)
    end

    -- shuffle draft pool
    for i = #self.draftPool, 2, -1 do
        local j = love.math.random(i)
        self.draftPool[i], self.draftPool[j] = self.draftPool[j], self.draftPool[i]
    end

    -- deal first 3
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
    -- only refill if no choices left
    if #self.choices == 0 then
        for i = 1, 3 do
            local c = table.remove(self.draftPool)
            if c then
                table.insert(self.choices, c)
            end
        end
        self:updateChoicePositions()
    end
end

function draft:draw()
    Viewport.apply()
    love.graphics.setColor(1,1,1)
    local screenW = Viewport.getWidth()
    love.graphics.printf("Draft Phase", 0, 40, screenW, "center")
    love.graphics.printf("Player " .. self.currentPlayer .. " choose a card", 0, 80, screenW, "center")

    self:updateChoicePositions()

    for _, c in ipairs(self.choices) do
        c:draw()
    end

    local screenH = Viewport.getHeight()
    local miniCardW = 50
    local miniCardH = 70
    local miniSpacing = 60

    for i, p in ipairs(self.players) do
        local rowY = screenH - (i * 90)

        love.graphics.setColor(1,1,1)
        love.graphics.printf("Player " .. i .. " deck (" .. #p.deck .. "/12):", 0, rowY - 30, screenW, "center")

        local count = math.max(1, #p.deck)
        local totalWidth = miniCardW + miniSpacing * math.max(0, count - 1)
        local startX = math.floor((screenW - totalWidth) / 2)

        if #p.deck == 0 then
            love.graphics.setColor(1,1,1,0.4)
            love.graphics.rectangle("line", startX, rowY, miniCardW, miniCardH, 6, 6)
            love.graphics.setColor(1,1,1)
        else
            for j, c in ipairs(p.deck) do
                local cx = startX + (j - 1) * miniSpacing
                local cy = rowY

                love.graphics.setColor(1,1,1)
                love.graphics.rectangle("fill", cx, cy, miniCardW, miniCardH, 6, 6)
                love.graphics.setColor(0,0,0)
                love.graphics.rectangle("line", cx, cy, miniCardW, miniCardH, 6, 6)

                love.graphics.printf(c.name, cx + 2, cy + 25, miniCardW - 4, "center")
            end
        end
    end
    Viewport.unapply()
end


function draft:mousepressed(x, y, button)
    if button ~= 1 then return end
    -- incoming x,y are screen coords; convert to virtual
    x, y = Viewport.toVirtual(x, y)
    self:updateChoicePositions()

    for i, c in ipairs(self.choices) do
        if c:isHovered(x, y) then
            -- give card to current player
            table.insert(self.players[self.currentPlayer].deck, c)

            -- remove chosen card from available choices
            table.remove(self.choices, i)

            -- check if everyone finished
            local done = true
            for _, p in ipairs(self.players) do
                if #p.deck < 12 then
                    done = false
                    break
                end
            end

            if done then
                Gamestate.switch(game, self.players)
                return
            end

            -- if no choices left, refill 3 new cards
            self:nextChoices()

            -- next player's turn
            self.currentPlayer = self.currentPlayer % #self.players + 1
            break
        end
    end
end

return draft
