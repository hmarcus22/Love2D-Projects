local Card = require "src.card"
local Deck = require "src.deck"
local Player = require "src.player"

local GameState = {}
GameState.__index = GameState

function GameState:new()
    local gs = setmetatable({}, self)

    -- build deck
    local cards = {}
    for i = 1, 20 do
        table.insert(cards, Card(i, "Card " .. i))
    end
    gs.deck = Deck(cards)
    gs.deck:shuffle()

    -- create players
    gs.players = {
        Player(1, 400),
        Player(2, 50)
    }
    gs.currentPlayer = 1

    -- table objects
    gs.allCards = {}
    gs.draggingCard = nil

    -- deck stack (UI element)
    gs.deckStack = Card(-1, "Deck", 450, 225)
    gs.deckStack.faceUp = false

    -- discard pile (UI element)
    gs.discardStack = Card(-2, "Discard", 600, 225)
    gs.discardStack.faceUp = false
    gs.discardPile = {} -- holds actual discarded cards
    gs.highlightDiscard = false

    -- initial deal
    for p = 1, #gs.players do
        for i = 1, 3 do
            gs:drawCardToPlayer(p)
        end
    end

    gs:updateCardVisibility()

    return gs
end

function GameState:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.print("Player " .. self.currentPlayer .. "'s turn (SPACE to switch)", 20, 20)

    -- draw deck stack
    self.deckStack:draw()
    love.graphics.print("Cards left: " .. self.deck:count(), self.deckStack.x, self.deckStack.y + self.deckStack.h + 5)

    -- draw discard pile (top card or placeholder)
    if #self.discardPile > 0 then
        self.discardPile[#self.discardPile]:draw()
    else
        self.discardStack:draw()
    end

    -- draw player slots
    for _, p in ipairs(self.players) do
        p:drawSlots()
    end

    -- draw all cards
    for _, c in ipairs(self.allCards) do
        c:draw()
    end

    -- highlight discard pile if needed
    if self.highlightDiscard then
        local x, y = self.discardStack.x, self.discardStack.y
        local w, h = self.discardStack.w, self.discardStack.h

        -- slightly bigger than the card
        local pad = 6
        love.graphics.setColor(1, 0, 0, 0.9)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", x - pad, y - pad, w + pad*2, h + pad*2, 10, 10)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1,1,1,1)
    end
end

function GameState:update(dt)
    local mx, my = love.mouse.getPosition()
    if self.draggingCard then
        self.draggingCard.x = mx - self.draggingCard.offsetX
        self.draggingCard.y = my - self.draggingCard.offsetY

        -- highlight discard pile if hovered
        self.highlightDiscard = self.discardStack:isHovered(mx, my)
    else
        self.highlightDiscard = false
    end
end

function GameState:mousepressed(x, y, button)
    if button ~= 1 then return end

    -- deck clicked? (only for current player)
    if self.deckStack:isHovered(x, y) then
        self:drawCardToPlayer(self.currentPlayer)
        return
    end

    -- only check current player's cards
    local current = self.players[self.currentPlayer]
    for i = #current.hand, 1, -1 do
        local c = current.hand[i]
        if c:isHovered(x, y) then
            self.draggingCard = c
            c.dragging = true
            c.offsetX = x - c.x
            c.offsetY = y - c.y

            -- bring to front in allCards
            for j = #self.allCards, 1, -1 do
                if self.allCards[j] == c then
                    table.remove(self.allCards, j)
                    table.insert(self.allCards, c)
                    break
                end
            end
            break
        end
    end
end

function GameState:mousereleased(x, y, button)
    if button == 1 and self.draggingCard then
        if self.discardStack:isHovered(x, y) then
            self:discardCard(self.draggingCard)
        else
            if self.draggingCard.owner then
                self.draggingCard.owner:snapCard(self.draggingCard)
            end
        end

        self.draggingCard.dragging = false
        self.draggingCard = nil
        self.highlightDiscard = false
    end
end

function GameState:keypressed(key)
    if key == "space" then
        self.currentPlayer = self.currentPlayer % #self.players + 1
        self:updateCardVisibility()
    end
end

function GameState:updateCardVisibility()
    for i, p in ipairs(self.players) do
        local isCurrent = (i == self.currentPlayer)
        for _, c in ipairs(p.hand) do
            c.faceUp = isCurrent
        end
    end
end

function GameState:drawCardToPlayer(playerIndex)
    local c = self.deck:drawCard()
    if not c then return end
    local p = self.players[playerIndex]
    local success = p:addCard(c)
    if success then
        table.insert(self.allCards, c)
    else
        -- hand full: put card back (or discard automatically)
        table.insert(self.deck.cards, 1, c) -- put back on top
    end
end


function GameState:discardCard(card)
    -- remove from player's hand
    for _, p in ipairs(self.players) do
        p:removeCard(card)
    end

    -- remove from allCards
    for i, c in ipairs(self.allCards) do
        if c == card then
            table.remove(self.allCards, i)
            break
        end
    end

    -- put into discard pile
    card.x = self.discardStack.x
    card.y = self.discardStack.y
    card.faceUp = true -- ensure discard is always visible
    table.insert(self.discardPile, card)
end

return GameState