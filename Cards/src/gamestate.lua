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
    Player{ id = 1, maxHandSize = 5 },
    Player{ id = 2, maxHandSize = 5 }
    }
    gs.currentPlayer = 1

    -- table objects
    gs.allCards = {}
    gs.draggingCard = nil

    -- deck stack (UI element)
    gs.deckStack = Card(-1, "Deck", 450, 225)
    gs.deckStack.faceUp = false

    -- discard pile (UI element)
    local slotSpacing = 110
    local handY = love.graphics.getHeight() - 170
    local lastSlotX = 150 + (self.players[1].maxHandSize - 1) * slotSpacing

    gs.discardStack = Card(-2, "Discard", lastSlotX + 150, handY)
    gs.discardStack.faceUp = false
    gs.discardPile = {} -- holds actual discarded cards
    gs.highlightDiscard = false
    gs.phase = "play"         -- "play" | "resolve" (later)
    gs.playedCount = {}
    for _, p in ipairs(gs.players) do
        gs.playedCount[p.id] = 0
    end


    -- initial deal
    for p = 1, #gs.players do
        for i = 1, 3 do
            gs:drawCardToPlayer(p)
        end
    end

    gs:updateCardVisibility()

    return gs
end

function GameState:newFromDraft(draftedPlayers)
    local gs = setmetatable({}, self)

    gs.players = draftedPlayers
    gs.currentPlayer = 1
    gs.allCards = {}
    gs.draggingCard = nil
    gs.deckStack = nil -- no shared deck in this mode (each has their own)

    -- discard placement (based on hand slots)
    local slotSpacing = 110
    local handY = love.graphics.getHeight() - 170
    local lastSlotX = 150 + (gs.players[1].maxHandSize - 1) * slotSpacing
    gs.discardStack = Card(-2, "Discard", lastSlotX + 150, handY)
    gs.discardStack.faceUp = false
    gs.discardPile = {}

    gs.phase = "play"
    gs.maxBoardCards = draftedPlayers[1].maxBoardCards or 3   -- ✅ set this
    gs.playedCount = {}
    for _, p in ipairs(gs.players) do
        assert(p.id, "Player missing id!")                     -- debug safety
        gs.playedCount[p.id] = 0
    end

    -- deal starting hands
    for _, p in ipairs(gs.players) do
        for i = 1, p.maxHandSize do
            local c = table.remove(p.deck)
            if c then
                p:addCard(c)
                table.insert(gs.allCards, c)
            end
        end
    end

    gs:updateCardVisibility()
    return gs
end



function GameState:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.print("Player " .. self.currentPlayer .. "'s turn", 20, 20)

    local screenH = love.graphics.getHeight()
    local boardYTop = 80
    local boardYBottom = screenH - 350

    for i, p in ipairs(self.players) do
        for s, slot in ipairs(p.boardSlots) do
            local slotX, slotY = self:getBoardSlotPosition(i, s)

            -- draw slot outline
            love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
            love.graphics.rectangle("line", slotX, slotY, 100, 150, 8, 8)

            -- update card position if a card is placed
            if slot.card then
                slot.card.x = slotX
                slot.card.y = slotY
                slot.card:draw()
            end
        end
    end


    -- discard pile
    if #self.discardPile > 0 then
        self.discardPile[#self.discardPile]:draw()
    else
        self.discardStack:draw()
    end

    -- draw current player's hand at bottom
    local current = self:getCurrentPlayer()
    current:drawHand(true)

    -- current player's deck
    local deckX, deckY = 20, screenH - 170
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("fill", deckX, deckY, 100, 150, 8, 8)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", deckX, deckY, 100, 150, 8, 8)
    love.graphics.printf("Deck\n" .. #current.deck, deckX, deckY + 50, 100, "center")

    if self.draggingCard then
        self.draggingCard:draw()
    end
end

-- returns x,y for a given player's slot index, relative to current turn
function GameState:getBoardSlotPosition(playerIndex, slotIndex)
    local screenH = love.graphics.getHeight()
    local boardYTop = 80
    local boardYBottom = screenH - 350

    local isCurrent = (playerIndex == self.currentPlayer)
    local y = isCurrent and boardYBottom or boardYTop
    local x = 320 + (slotIndex-1)*110

    return x, y
end

-- returns x,y for a given player's hand slot index (always bottom for current)
function GameState:getHandSlotPosition(slotIndex)
    local handY = love.graphics.getHeight() - 170
    local x = 150 + (slotIndex - 1) * 110
    return x, handY
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

function GameState:updateCardVisibility()
    for i, p in ipairs(self.players) do
        local isCurrent = (i == self.currentPlayer)
        for _, slot in ipairs(p.slots) do
        if slot.card then
            slot.card.faceUp = isCurrent
        end
end
    end
end

function GameState:drawCardToPlayer(playerIndex)
    local p = self.players[playerIndex]
    local c = p:drawCard()
    if c then
        table.insert(self.allCards, c) -- needed so card is drawn
    end
end


function GameState:discardCard(card)
    -- remove from the actual owner's hand
    if card.owner then
        card.owner:removeCard(card)
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
    card.faceUp = true
    table.insert(self.discardPile, card)
end

function GameState:getCurrentPlayer()
    return self.players[self.currentPlayer]
end

function GameState:nextPlayer()
    self.currentPlayer = self.currentPlayer % #self.players + 1
    self:updateCardVisibility()
end

-- check if both have placed 3, if so go to resolve
function GameState:maybeFinishPlayPhase()
    local allDone = true
    for _, p in ipairs(self.players) do
        if self.playedCount[p.id] < self.maxBoardCards then
            allDone = false
            break
        end
    end

    if allDone then
        self.phase = "resolve"
        -- TODO: trigger resolve logic/animation here
        print("Both players have finished placing cards! Switching to resolve phase.")
    end
end


function GameState:playCardFromHand(card, slotIndex)
    if self.phase ~= "play" then return end
    local current = self:getCurrentPlayer()
    local pid = current.id

    if card.owner ~= current then return end
    if self.playedCount[pid] >= self.maxBoardCards then
        current:snapCard(card, self)
        return
    end

    local ok = current:playCardToBoard(card, slotIndex, self)
    if ok then
        card.zone = "board"
        card.faceUp = true
        self.playedCount[pid] = self.playedCount[pid] + 1
        self:nextPlayer()
        self:maybeFinishPlayPhase()
    else
        current:snapCard(card, self)
    end
end


return GameState