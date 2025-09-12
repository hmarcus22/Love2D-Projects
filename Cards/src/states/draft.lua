local Gamestate = require "libs.hump.gamestate"
local Card = require "src.card"
local game = require "src.states.game"
local Player = require "src.player"
local factory = require "src.card_factory"

local MAX_HAND_SIZE = 5
local MAX_BOARD_CARDS = 3

local draft = {}

function draft:enter()
    -- setup players with empty decks
   self.players = {
        Player{ id = 1, maxHandSize = MAX_HAND_SIZE, maxBoardCards = MAX_BOARD_CARDS },
        Player{ id = 2, maxHandSize = MAX_HAND_SIZE, maxBoardCards = MAX_BOARD_CARDS }
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

    -- shuffle draft pool
    for i = #self.draftPool, 2, -1 do
        local j = love.math.random(i)
        self.draftPool[i], self.draftPool[j] = self.draftPool[j], self.draftPool[i]
    end

    -- deal first 3
    self.choices = {}
    self:nextChoices()
end

function draft:nextChoices()
    -- only refill if no choices left
    if #self.choices == 0 then
        for i = 1, 3 do
            local c = table.remove(self.draftPool)
            if c then
                c.x = 200 + (i-1) * 150
                c.y = 250
                table.insert(self.choices, c)
            end
        end
    end
end

function draft:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Draft Phase", 0, 40, love.graphics.getWidth(), "center")
    love.graphics.printf("Player " .. self.currentPlayer .. " choose a card", 0, 80, love.graphics.getWidth(), "center")

    -- draw current choices
    for _, c in ipairs(self.choices) do
        c:draw()
    end

    -- screen height
    local screenH = love.graphics.getHeight()

    -- show drafted cards at the bottom
    for i, p in ipairs(self.players) do
        -- stack rows: player 1 above player 2
        local rowY = screenH - (i * 90)

        love.graphics.setColor(1,1,1)
        love.graphics.printf("Player " .. i .. " deck (" .. #p.deck .. "/12):",
            20, rowY - 20, love.graphics.getWidth(), "left")

        local startX = 40
        for j, c in ipairs(p.deck) do
            local cx = startX + (j-1) * 60
            local cy = rowY

            -- mini card box
            love.graphics.setColor(1,1,1)
            love.graphics.rectangle("fill", cx, cy, 50, 70, 6, 6)
            love.graphics.setColor(0,0,0)
            love.graphics.rectangle("line", cx, cy, 50, 70, 6, 6)

            -- card name (truncated if too long)
            love.graphics.printf(c.name, cx+2, cy+25, 46, "center")
        end
    end
end


function draft:mousepressed(x, y, button)
    if button ~= 1 then return end

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
