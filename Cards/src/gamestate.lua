local Card = require "src.card"
local Deck = require "src.deck"
local Player = require "src.player"
local Viewport = require "src.viewport"

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
    local handY = Viewport.getHeight() - 170
    local lastSlotX = 150 + (self.players[1].maxHandSize - 1) * slotSpacing

    gs.discardStack = Card(-2, "Discard", lastSlotX + 150, handY)
    gs.discardStack.faceUp = false
    gs.discardPile = {} -- holds actual discarded cards
    gs.highlightDiscard = false
    gs.phase = "play"         -- "play" | "resolve"
    gs.playedCount = {}
    for _, p in ipairs(gs.players) do
        gs.playedCount[p.id] = 0
    end

    -- turn order (micro-round of one card each)
    gs.roundStarter = 1
    gs.playsInRound = 0

    -- resolve animation state
    gs.resolveQueue = {}
    gs.resolveIndex = 0
    gs.resolveTimer = 0
    gs.resolveStepDuration = 0.5
    gs.resolveCurrentStep = nil

    -- log of resolve events
    gs.resolveLog = {}
    gs.maxResolveLogLines = 14

    -- log of resolve events
    gs.resolveLog = {}
    gs.maxResolveLogLines = 14


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
    local handY = Viewport.getHeight() - 170
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

    -- turn order (micro-round of one card each)
    gs.roundStarter = 1
    gs.playsInRound = 0

    -- resolve animation state
    gs.resolveQueue = {}
    gs.resolveIndex = 0
    gs.resolveTimer = 0
    gs.resolveStepDuration = 0.5
    gs.resolveCurrentStep = nil

    -- log of resolve events
    gs.resolveLog = {}
    gs.maxResolveLogLines = 14

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

    -- show health/block for both players
    local p1 = self.players[1]
    local p2 = self.players[2]
    love.graphics.setColor(1,1,1)
    love.graphics.print(string.format("P1 HP: %d  Block: %d", p1.health or 0, p1.block or 0), 20, 40)
    love.graphics.print(string.format("P2 HP: %d  Block: %d", p2.health or 0, p2.block or 0), 20, 60)

    local screenH = Viewport.getHeight()
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

    -- resolve highlight overlay
    if self.phase == "resolve" and self.resolveCurrentStep then
        local step = self.resolveCurrentStep
        local colors = {
            block = {0.2, 0.4, 0.9, 0.35},
            heal = {0.2, 0.8, 0.2, 0.35},
            attack = {0.9, 0.2, 0.2, 0.35},
            cleanup = {0.6, 0.6, 0.6, 0.3}
        }
        local c = colors[step.kind] or {1,1,0,0.3}
        love.graphics.setColor(c[1], c[2], c[3], c[4])
        for pi = 1, #self.players do
            local sx, sy = self:getBoardSlotPosition(pi, step.slot)
            love.graphics.rectangle("fill", sx, sy, 100, 150, 8, 8)
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf(string.format("Resolving %s on slot %d", step.kind, step.slot), 0, 20, Viewport.getWidth(), "center")
    end

    -- draw resolve log panel (right side)
    local panelW = 280
    local panelX = Viewport.getWidth() - panelW - 16
    local panelY = 80
    local lineH = 16
    local titleH = 20
    local visibleLines = math.min(#self.resolveLog, self.maxResolveLogLines or 14)
    local panelH = titleH + visibleLines * lineH + 10
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.print("Log", panelX + 8, panelY + 4)
    love.graphics.setColor(1,1,1,1)
    local startIdx = math.max(1, #self.resolveLog - (self.maxResolveLogLines or 14) + 1)
    local y = panelY + titleH
    for i = startIdx, #self.resolveLog do
        love.graphics.printf(self.resolveLog[i], panelX + 8, y, panelW - 16, "left")
        y = y + lineH
    end
end

-- returns x,y for a given player's slot index, relative to current turn
function GameState:getBoardSlotPosition(playerIndex, slotIndex)
    local screenH = Viewport.getHeight()
    local boardYTop = 80
    local boardYBottom = screenH - 350

    local isCurrent = (playerIndex == self.currentPlayer)
    local y = isCurrent and boardYBottom or boardYTop
    local x = 320 + (slotIndex-1)*110

    return x, y
end

-- returns x,y for a given player's hand slot index (always bottom for current)
function GameState:getHandSlotPosition(slotIndex)
    local handY = Viewport.getHeight() - 170
    local x = 150 + (slotIndex - 1) * 110
    return x, handY
end

function GameState:update(dt)
    local mx, my = love.mouse.getPosition()
    mx, my = Viewport.toVirtual(mx, my)
    if self.draggingCard then
        self.draggingCard.x = mx - self.draggingCard.offsetX
        self.draggingCard.y = my - self.draggingCard.offsetY

        -- highlight discard pile if hovered
        self.highlightDiscard = self.discardStack:isHovered(mx, my)
    else
        self.highlightDiscard = false
    end

    -- resolve animation progression
    if self.phase == "resolve" then
        self.resolveTimer = self.resolveTimer - dt
        if self.resolveTimer <= 0 then
            self.resolveIndex = self.resolveIndex + 1
            if self.resolveIndex > #self.resolveQueue then
                -- finished resolution
                for _, p in ipairs(self.players) do
                    self.playedCount[p.id] = 0
                end
                -- start next play phase with alternating starter
                self.currentPlayer = self.roundStarter or 1
                self.phase = "play"
                self.resolveQueue = {}
                self.resolveIndex = 0
                self.resolveCurrentStep = nil
                self:addLog("Round resolved. Back to play.")
                self:updateCardVisibility()
            else
                local step = self.resolveQueue[self.resolveIndex]
                self.resolveCurrentStep = step
                self:performResolveStep(step)
                self.resolveTimer = self.resolveStepDuration
            end
        end
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

-- Apply effects of all cards on board, then clean up and start next round
function GameState:startResolve()
    self.phase = "resolve"
    self.resolveQueue = {}
    self.resolveIndex = 0
    self.resolveTimer = 0
    self.resolveCurrentStep = nil
    self:addLog("--- Begin Resolution ---")

    local maxSlots = self.maxBoardCards or (#self.players[1].boardSlots)

    -- Pass 1: Block additions per slot
    for s = 1, maxSlots do
        table.insert(self.resolveQueue, { kind = "block", slot = s })
    end
    -- Pass 2: Attacks per slot (simultaneous within slot)
    for s = 1, maxSlots do
        table.insert(self.resolveQueue, { kind = "attack", slot = s })
    end
    -- Pass 3: Heals per slot (after block and attack)
    for s = 1, maxSlots do
        table.insert(self.resolveQueue, { kind = "heal", slot = s })
    end
    -- Pass 4: Cleanup (discard) per slot
    for s = 1, maxSlots do
        table.insert(self.resolveQueue, { kind = "cleanup", slot = s })
    end
end

function GameState:performResolveStep(step)
    local s = step.slot
    if step.kind == "block" then
        for _, p in ipairs(self.players) do
            local slot = p.boardSlots[s]
            if slot and slot.card and slot.card.definition then
                local def = slot.card.definition
                if def.block and def.block > 0 then
                    p.block = (p.block or 0) + def.block
                    self:addLog(string.format("Slot %d: P%d gains %d block (%s)", s, p.id or 0, def.block, slot.card.name or ""))
                end
            end
        end
    elseif step.kind == "heal" then
        for _, p in ipairs(self.players) do
            local slot = p.boardSlots[s]
            if slot and slot.card and slot.card.definition then
                local def = slot.card.definition
                if def.heal and def.heal > 0 then
                    local mh = p.maxHealth or 20
                    local before = p.health or mh
                    p.health = math.min(before + def.heal, mh)
                    local gained = p.health - before
                    if gained > 0 then
                        self:addLog(string.format(
                            "Slot %d [Heal]: P%d +%d HP (%s) -> %d/%d",
                            s, p.id or 0, gained, slot.card.name or "", p.health, mh
                        ))
                    end
                end
            end
        end
    elseif step.kind == "attack" then
        local function atkAt(p, idx)
            local slot = p.boardSlots[idx]
            if slot and slot.card and slot.card.definition and slot.card.definition.attack then
                return slot.card.definition.attack or 0
            end
            return 0
        end
        local p1, p2 = self.players[1], self.players[2]
        local a1 = atkAt(p1, s)
        local a2 = atkAt(p2, s)
        if a1 > 0 or a2 > 0 then
            -- compute absorption using pre-step block values (simultaneous within slot)
            local preB1 = p1.block or 0
            local preB2 = p2.block or 0
            local absorb2 = math.min(preB2, a1)
            local absorb1 = math.min(preB1, a2)
            p2.block = preB2 - absorb2
            p1.block = preB1 - absorb1
            local r1 = a2 - absorb1
            local r2 = a1 - absorb2
            if r2 > 0 then p2.health = (p2.health or p2.maxHealth or 20) - r2 end
            if r1 > 0 then p1.health = (p1.health or p1.maxHealth or 20) - r1 end
            if a1 > 0 then
                self:addLog(string.format("Slot %d: P1 attacks P2 for %d (block %d, dmg %d)", s, a1, absorb2, math.max(0, r2)))
            end
            if a2 > 0 then
                self:addLog(string.format("Slot %d: P2 attacks P1 for %d (block %d, dmg %d)", s, a2, absorb1, math.max(0, r1)))
            end
        end
    elseif step.kind == "cleanup" then
        for _, p in ipairs(self.players) do
            local slot = p.boardSlots[s]
            if slot and slot.card then
                self:addLog(string.format("Slot %d: P%d discards %s", s, p.id or 0, slot.card.name or "card"))
                self:discardCard(slot.card)
                slot.card = nil
            end
        end

        -- Optional victory check
        for idx, p in ipairs(self.players) do
            if (p.health or 0) <= 0 then
                print(string.format("Player %d has been defeated!", idx))
                self:addLog(string.format("Player %d is defeated!", idx))
            end
        end
    end
end

function GameState:addLog(msg)
    self.resolveLog = self.resolveLog or {}
    table.insert(self.resolveLog, msg)
    local limit = self.maxResolveLogLines or 14
    while #self.resolveLog > limit do
        table.remove(self.resolveLog, 1)
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

-- Advance the turn respecting the micro-round alternation.
-- Debug helper used by the space key; does not alter playedCount.
function GameState:advanceTurn()
    if self.phase ~= "play" then return end
    if (self.playsInRound or 0) == 0 then
        self.playsInRound = 1
        self:nextPlayer()
    else
        -- Complete the micro-round and toggle next starter
        self.playsInRound = 0
        if self.roundStarter == 1 then
            self.roundStarter = 2
        else
            self.roundStarter = 1
        end
        self.currentPlayer = self.roundStarter
        self:updateCardVisibility()
    end
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
        print("Both players have finished placing cards! Switching to resolve phase.")
        self:startResolve()
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

        -- 🟢 Debug info
        print(string.format(
            "Player %d placed a card in slot %d. Played %d/%d cards.",
            pid, slotIndex, self.playedCount[pid], self.maxBoardCards
        ))

        -- micro-round handling: one card per player, alternate starting player next round
        if self.playsInRound == 0 then
            self.playsInRound = 1
            self:nextPlayer()
        else
            -- second play in the micro-round
            self.playsInRound = 2
            -- toggle starter for next micro-round
            if self.roundStarter == 1 then
                self.roundStarter = 2
            else
                self.roundStarter = 1
            end
            -- set next current player to new starter (unless we enter resolve)
            self.currentPlayer = self.roundStarter
            self.playsInRound = 0
            self:updateCardVisibility()
        end

        self:maybeFinishPlayPhase()
    else
        current:snapCard(card, self)
    end
end

return GameState
