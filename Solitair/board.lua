-- Game board. Contain 7 slots + 1 slot for draw pile and a slot for discard. 4 slots to move card to.
-- each of the seven first slots can contain multiple cards
-- Layout is 4 playing slots on top to the left. draw and discard to the top right. 7 slots under first row of slots, evenly spaced.

local Class = require 'HUMP.class'
local config = require 'config'
local slots = 7

local Board = Class {}
local function cardColor(card)
    if card.suit == "hearts" or card.suit == "diamonds" then
        return "red"
    end
    return "black"
end

local function isOppositeColor(a, b)
    return cardColor(a) ~= cardColor(b)
end

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
    self.dragging = nil
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

function Board:flipTopTableauCard(slot)
    if slot < 1 or slot > slots then
        error("Invalid slot number: " .. tostring(slot))
    end
    local pile = self.tableau[slot]
    local topCard = pile[#pile]
    if topCard and not topCard.isFaceUp then
        self:setCardFace(topCard, true)
    end
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

function Board:shuffleDraftPool()
    --shuffles a standard playing card deck of 52 cards into a draft pool and returns it.
    local suits = {"hearts", "diamonds", "clubs", "spades"}
    local draftPool = {}
    for _, suit in ipairs(suits) do
        for rank = 1, 13 do
            table.insert(draftPool, {rank = rank, suit = suit})
        end
    end
    for i = #draftPool, 2, -1 do
        local j = math.random(i)
        draftPool[i], draftPool[j] = draftPool[j], draftPool[i]
    end
    return draftPool
end

function Board:getLayout()
    local screenW, screenH = love.graphics.getDimensions()
    local cardW = config.card.width
    local cardH = config.card.height

    local spacingX = math.floor(cardW * 0.1)
    local spacingY = math.floor(cardH * 0.3)
    local gapTop = math.max(16, math.floor(spacingX / 2))
    local topRowY = math.max(20, math.floor((screenH - (cardH * 2 + spacingY)) * 0.1))

    local tableauWidth = (slots * cardW) + ((slots - 1) * spacingX)
    local tableauStartX = math.max(0, math.floor((screenW - tableauWidth) / 2))
    local tableauStartY = topRowY + cardH + spacingY

    return {
        cardW = cardW,
        cardH = cardH,
        spacingX = spacingX,
        spacingY = spacingY,
        gapTop = gapTop,
        topRowY = topRowY,
        tableauWidth = tableauWidth,
        tableauStartX = tableauStartX,
        tableauStartY = tableauStartY,
    }
end

function Board:startDrag(x, y)
    if self.dragging then
        return false
    end

    local layout = self:getLayout()
    local drawX = layout.tableauStartX + layout.tableauWidth + layout.gapTop
    local discardX = drawX + layout.cardW + layout.gapTop
    local discardY = layout.topRowY

    local topDiscard = self.discardPile[#self.discardPile]
    if topDiscard and topDiscard.isFaceUp then
        if x >= discardX and x <= discardX + layout.cardW and y >= discardY and y <= discardY + layout.cardH then
            table.remove(self.discardPile)
            self.dragging = {
                card = topDiscard,
                cards = { topDiscard },
                fromCol = "discard",
                x = discardX,
                y = discardY,
                offsetX = x - discardX,
                offsetY = y - discardY,
            }
            return true
        end
    end

    for col = 1, slots do
        local pile = self.tableau[col]
        if #pile > 0 then
            local cardX = layout.tableauStartX + (col - 1) * (layout.cardW + layout.spacingX)
            for idx = #pile, 1, -1 do
                local card = pile[idx]
                if card.isFaceUp then
                    local cardY = layout.tableauStartY + (idx - 1) * layout.spacingY
                    if x >= cardX and x <= cardX + layout.cardW and y >= cardY and y <= cardY + layout.cardH then
                        local valid = true
                        for i = idx, #pile do
                            if not pile[i].isFaceUp then
                                valid = false
                                break
                            end
                            if i > idx then
                                local prev = pile[i - 1]
                                local curr = pile[i]
                                if curr.rank ~= prev.rank - 1 or not isOppositeColor(curr, prev) then
                                    valid = false
                                    break
                                end
                            end
                        end
                        if not valid then
                            return false
                        end

                        local cards = {}
                        for i = idx, #pile do
                            table.insert(cards, pile[i])
                        end
                        for i = #pile, idx, -1 do
                            table.remove(pile, i)
                        end

                        self.dragging = {
                            card = cards[1],
                            cards = cards,
                            fromCol = col,
                            x = cardX,
                            y = cardY,
                            offsetX = x - cardX,
                            offsetY = y - cardY,
                        }
                        return true
                    end
                else
                    break
                end
            end
        end
    end

    return false
end

function Board:dragTo(x, y)
    if not self.dragging then
        return
    end
    self.dragging.x = x - self.dragging.offsetX
    self.dragging.y = y - self.dragging.offsetY
end

function Board:endDrag(x, y, game)
    if not self.dragging then
        return
    end

    local layout = self:getLayout()
    local targetCol = nil
    local targetFoundation = nil
    for col = 1, slots do
        local colX = layout.tableauStartX + (col - 1) * (layout.cardW + layout.spacingX)
        if x >= colX and x <= colX + layout.cardW then
            targetCol = col
            break
        end
    end

    for i = 1, 4 do
        local fx = layout.tableauStartX + (i - 1) * (layout.cardW + layout.spacingX)
        local fy = layout.topRowY
        if x >= fx and x <= fx + layout.cardW and y >= fy and y <= fy + layout.cardH then
            targetFoundation = i
            break
        end
    end

    local moved = false
    if targetFoundation then
        if #self.dragging.cards == 1 then
            if not game or not game.canMoveToFoundation or game:canMoveToFoundation(self.dragging.card, targetFoundation) then
                table.insert(self.foundations[targetFoundation], self.dragging.card)
                moved = true
            end
        end
    elseif targetCol then
        if not game or not game.canMoveToTableau or game:canMoveToTableau(self.dragging.card, targetCol) then
            for _, card in ipairs(self.dragging.cards) do
                table.insert(self.tableau[targetCol], card)
            end
            moved = true
        end
    end

    if moved then
        if self.dragging.fromCol ~= "discard" then
            self:flipTopTableauCard(self.dragging.fromCol)
        end
    else
        if self.dragging.fromCol == "discard" then
            for _, card in ipairs(self.dragging.cards) do
                table.insert(self.discardPile, card)
            end
        else
            for _, card in ipairs(self.dragging.cards) do
                table.insert(self.tableau[self.dragging.fromCol], card)
            end
        end
    end
    self.dragging = nil
end

function Board:draw()
    local layout = self:getLayout()
    local cardW = layout.cardW
    local cardH = layout.cardH
    local spacingX = layout.spacingX
    local spacingY = layout.spacingY
    local gapTop = layout.gapTop
    local topRowY = layout.topRowY
    local tableauWidth = layout.tableauWidth
    local tableauStartX = layout.tableauStartX
    local tableauStartY = layout.tableauStartY

    local function drawCard(card, x, y)
        if card and card.texture then
            local scaleX = cardW / card.texture:getWidth()
            local scaleY = cardH / card.texture:getHeight()
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("fill", x, y, cardW, cardH)
            love.graphics.draw(card.texture, x, y, 0, scaleX, scaleY)
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", x, y, cardW, cardH)
        end
    end

    love.graphics.setColor(1, 1, 1)

    -- Foundations (top-left)
    for i = 1, 4 do
        local x = tableauStartX + (i - 1) * (cardW + spacingX)
        local y = topRowY
        local topCard = self.foundations[i][#self.foundations[i]]
        drawCard(topCard, x, y)
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("F" .. i, x + 6, y + 6)
        love.graphics.setColor(1, 1, 1)
    end

    -- Draw pile and discard (top-right, close to foundations)
    local drawY = topRowY
    local drawX = tableauStartX + tableauWidth + gapTop
    local discardX = drawX + cardW + gapTop
    local discardY = drawY
    local topDraw = self.drawPile[#self.drawPile]
    drawCard(topDraw, drawX, drawY)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Draw", drawX + 6, drawY + 6)
    love.graphics.setColor(1, 1, 1)
    local topDiscard = self.discardPile[#self.discardPile]
    drawCard(topDiscard, discardX, discardY)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Discard", discardX + 6, discardY + 6)
    love.graphics.setColor(1, 1, 1)

    -- Tableau (bottom row)
    for col = 1, slots do
        local x = tableauStartX + (col - 1) * (cardW + spacingX)
        local y = tableauStartY
        if #self.tableau[col] == 0 then
            love.graphics.rectangle("line", x, y, cardW, cardH)
        end
        love.graphics.setColor(0, 0, 0)
        love.graphics.print("T" .. col, x + 6, y + 6)
        love.graphics.setColor(1, 1, 1)

        for i, card in ipairs(self.tableau[col]) do
            local cardY = y + (i - 1) * spacingY
            drawCard(card, x, cardY)
        end
    end

    if self.dragging then
        for i, card in ipairs(self.dragging.cards) do
            local cardY = self.dragging.y + (i - 1) * spacingY
            drawCard(card, self.dragging.x, cardY)
        end
    end
end

return Board
