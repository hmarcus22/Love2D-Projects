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
    gs.phase = "play"         -- "play" | "resolve" (later)
    gs.maxBoardCards = 3      -- each player must place 3
    gs.playedCount = {}       -- per-player placed count
    for i = 1, #gs.players do gs.playedCount[i] = 0 end


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
    gs.discardStack = Card(-2, "Discard", 600, 225)
    gs.discardStack.faceUp = false
    gs.discardPile = {}
    gs.phase = "play"         -- "play" | "resolve" (later)
    gs.maxBoardCards = 3      -- each player must place 3
    gs.playedCount = {}       -- per-player placed count
    for i = 1, #gs.players do gs.playedCount[i] = 0 end

    -- deal starting hands from each player’s deck
    for _, p in ipairs(gs.players) do
        p.hand = {}
        for i = 1, 5 do
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
    love.graphics.print("Player " .. self.currentPlayer .. "'s turn (SPACE to switch)", 20, 20)

    -- per-player deck counts (no central deckStack in draft mode)
    for i, p in ipairs(self.players) do
        love.graphics.setColor(1,1,1)
        local deckX = (i == 1) and 20 or 880
        local deckY = p.y

        love.graphics.rectangle("fill", deckX, deckY, 100, 150, 8, 8)
        love.graphics.setColor(0,0,0)
        love.graphics.rectangle("line", deckX, deckY, 100, 150, 8, 8)
        love.graphics.printf("Deck\n" .. #p.deck, deckX, deckY + 50, 100, "center")
    end

    -- draw slots + cards
    for _, p in ipairs(self.players) do
        p:drawSlots()
    end

    -- board slots + cards
    for _, p in ipairs(self.players) do
        p:drawBoard()
    end
    
    -- discard pile
    if #self.discardPile > 0 then
        self.discardPile[#self.discardPile]:draw()
    else
        self.discardStack:draw()
    end

    -- draw the card being dragged on top
    if self.draggingCard then
        self.draggingCard:draw()
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
    for i = 1, #self.players do
        if self.playedCount[i] < self.maxBoardCards then
            allDone = false; break
        end
    end
    if allDone then
        self.phase = "resolve"
        -- TODO: trigger resolve phase UI/logic here later
    end
end

function GameState:playCardFromHand(card)
    if self.phase ~= "play" then return end
    local i = self.currentPlayer
    local current = self.players[i]
    if card.owner ~= current then return end
    if self.playedCount[i] >= self.maxBoardCards then
        current:snapCard(card); return
    end

    -- Move hand → board (via Board)
    local ok = current:playCardToBoard(card)
    if ok then
        card.zone = "board"
        card.faceUp = true
        self.playedCount[i] = self.playedCount[i] + 1
        self:nextPlayer()
        self:maybeFinishPlayPhase()
    else
        current:snapCard(card)
    end
end

return GameState