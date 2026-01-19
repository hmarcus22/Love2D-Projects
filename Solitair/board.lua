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

function Board:reset()
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

function Board:setCardFace(card, isFaceUp)
    card.isFaceUp = isFaceUp
    if card.loadTexture then
        card.texture = card:loadTexture()
    end
end

function Board:setupFromDraftPool(draftPool)
    self:reset()
    if type(draftPool) ~= "table" then
        error("Draft pool must be a table of cards.")
    end

    for row = 1, slots do
        for col = row, slots do
            local card = table.remove(draftPool)
            if not card then
                error("Draft pool ran out of cards while dealing.")
            end
            local faceUp = (col == row)
            self:setCardFace(card, faceUp)
            table.insert(self.tableau[col], card)
        end
    end

    while #draftPool > 0 do
        table.insert(self.drawPile, table.remove(draftPool))
    end
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
    local screenW, screenH = love.graphics.getDimensions()
    local cardW = config.card.width
    local cardH = config.card.height

    local spacingX = math.floor(cardW * 0.1)
    local spacingY = math.floor(cardH * 0.1)
    local gapTop = math.max(16, math.floor(spacingX / 2))
    local topRowY = math.max(20, math.floor((screenH - (cardH * 2 + spacingY)) * 0.1))

    local tableauWidth = (slots * cardW) + ((slots - 1) * spacingX)
    local tableauStartX = math.max(0, math.floor((screenW - tableauWidth) / 2))
    local tableauStartY = topRowY + cardH + spacingY

    love.graphics.setColor(1, 1, 1)

    -- Foundations (top-left)
    for i = 1, 4 do
        local x = tableauStartX + (i - 1) * (cardW + spacingX)
        local y = topRowY
        love.graphics.rectangle("line", x, y, cardW, cardH)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("F" .. i, x + 6, y + 6)
        love.graphics.setColor(1, 1, 1)
    end

    -- Draw pile and discard (top-right, close to foundations)
    local drawY = topRowY
    local drawX = tableauStartX + tableauWidth + gapTop
    local discardX = drawX + cardW + gapTop
    local discardY = drawY
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
        local x = tableauStartX + (col - 1) * (cardW + spacingX)
        local y = tableauStartY
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
