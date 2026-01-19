-- Game board. Contain 7 slots + 1 slot for draw pile and a slot for discard. 4 slots to move card to.
-- each of the seven first slots can contain multiple cards
-- Layout is 4 playing slots on top to the left. draw and discard to the top right. 7 slots under first row of slots, evenly spaced.

local Class = require 'HUMP.class'
local config = require 'config'
local slots = 7

local Board = Class {}

function Board:init()
    self.tableau = {}
    for i = 1, slots do
        self.tableau[i] = {}
    end
    self.foundations = {}
    for i = 1, 4 do
        self.foundations[i] = {}
    end
    self.drawPile = {}
    self.discardPile = {}
end

function Board:addCardToTableau(card, slot)
    if slot < 1 or slot > slots then
        error("Invalid slot number: " .. tostring(slot))
    end
    table.insert(self.tableau[slot], card)
end

function Board:removeCardFromTableau(slot)
    if slot < 1 or slot > slots then
        error("Invalid slot number: " .. tostring(slot))
    end
    return table.remove(self.tableau[slot])
end

function Board:addCardToDrawPile(card)
    table.insert(self.drawPile, card)
end

function Board:removeCardFromDrawPile()
    return table.remove(self.drawPile)
end

function Board:addCardToDiscardPile(card)
    table.insert(self.discardPile, card)
end

function Board:removeCardFromDiscardPile()
    return table.remove(self.discardPile)
end

function Board:addCardToFoundation(card, foundation)
    if foundation < 1 or foundation > 4 then
        error("Invalid foundation number: " .. tostring(foundation))
    end
    table.insert(self.foundations[foundation], card)
end

function Board:removeCardFromFoundation(foundation)
    if foundation < 1 or foundation > 4 then
        error("Invalid foundation number: " .. tostring(foundation))
    end
    return table.remove(self.foundations[foundation])
end

function Board:draw()
    local cardW = config.card.width
    local cardH = config.card.height
    local pos = config.positions
    local startX = pos.tableauStartX
    local startY = pos.tableauStartY
    local spacingX = pos.tableauSpacingX
    local spacingY = pos.tableauSpacingY

    love.graphics.setColor(1, 1, 1)

    -- Foundations (top-left)
    for i = 1, 4 do
        local x = startX + (i - 1) * spacingX
        local y = pos.deckY
        love.graphics.rectangle("line", x, y, cardW, cardH)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("F" .. i, x + 6, y + 6)
        love.graphics.setColor(1, 1, 1)
    end

    -- Draw pile and discard (top-right)
    local marginX = pos.deckX
    local drawY = pos.deckY
    local discardX = config.window.width - cardW - marginX
    local discardY = drawY
    local drawX = discardX - spacingX
    love.graphics.rectangle("line", drawX, drawY, cardW, cardH)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Draw", drawX + 6, drawY + 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", discardX, discardY, cardW, cardH)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Discard", discardX + 6, discardY + 6)
    love.graphics.setColor(1, 1, 1)

    -- Tableau (bottom row)
    for col = 1, slots do
        local x = startX + (col - 1) * spacingX
        local y = startY + cardH + spacingY
        love.graphics.rectangle("line", x, y, cardW, cardH)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("T" .. col, x + 6, y + 6)
        love.graphics.setColor(1, 1, 1)

        for i, _ in ipairs(self.tableau[col]) do
            local cardY = y + (i - 1) * spacingY
            love.graphics.rectangle("line", x, cardY, cardW, cardH)
        end
    end
end

return Board
