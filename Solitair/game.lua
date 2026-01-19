local Class = require "HUMP.class"
local Board = require "board"
local Card = require "card"
local Input = require "input"

local Game = Class {}

function Game:init()
    self.board = Board()
    self:reset()
    Input.bind(self)
end

function Game:reset()
    local draftPool = self:buildDraftPool()
    self.board:setupFromDraftPool(draftPool)
end

function Game:buildDraftPool()
    local suits = { "hearts", "diamonds", "spades", "cloves" }
    local deck = {}
    for _, suit in ipairs(suits) do
        for rank = 1, 13 do
            table.insert(deck, Card(rank, suit))
        end
    end
    self:shuffle(deck)
    return deck
end

function Game:shuffle(deck)
    for i = #deck, 2, -1 do
        local j = love.math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

function Game:canMoveToTableau(card, targetCol)
    return true
end

function Game:canMoveToFoundation(card, foundation)
    return true
end

function Game:update(dt)
end

function Game:mousePressed(x, y, button)
    if button ~= 1 then
        return
    end
    if self:handleDrawDiscardClick(x, y) then
        return
    end
    self.board:startDrag(x, y)
end

function Game:mouseReleased(x, y, button)
    if button == 1 then
        self.board:endDrag(x, y)
    end
end

function Game:mouseMoved(x, y)
    self.board:dragTo(x, y)
end

function Game:handleDrawDiscardClick(x, y)
    local layout = self.board:getLayout()
    local drawX = layout.tableauStartX + layout.tableauWidth + layout.gapTop
    local drawY = layout.topRowY
    local discardX = drawX + layout.cardW + layout.gapTop
    local discardY = drawY

    local inDraw = x >= drawX and x <= drawX + layout.cardW and y >= drawY and y <= drawY + layout.cardH
    local inDiscard = x >= discardX and x <= discardX + layout.cardW and y >= discardY and y <= discardY + layout.cardH

    if inDraw then
        if #self.board.drawPile > 0 then
            local card = table.remove(self.board.drawPile)
            self.board:setCardFace(card, true)
            table.insert(self.board.discardPile, card)
        elseif #self.board.discardPile > 0 then
            for i = #self.board.discardPile, 1, -1 do
                local card = table.remove(self.board.discardPile, i)
                self.board:setCardFace(card, false)
                table.insert(self.board.drawPile, card)
            end
        end
        return true
    end

    if inDiscard then
        return false
    end

    return false
end

function Game:draw()
    if self.board then
        self.board:draw()
    end
end

return Game
