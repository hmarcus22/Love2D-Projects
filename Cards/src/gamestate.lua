local Card = require "src.card"
local Deck = require "src.deck"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"
local Layout = require "src.game_layout"
local Initialiser = require "src.game_initialiser"
local BoardRenderer = require "src.renderers.board_renderer"
local HudRenderer = require "src.renderers.hud_renderer"
local ResolveRenderer = require "src.renderers.resolve_renderer"

local GameState = {}
GameState.__index = GameState

GameState.buildLayoutCache = Layout.buildCache
GameState.getLayout = Layout.getLayout
GameState.getCardDimensions = Layout.getCardDimensions
GameState.getHandMetrics = Layout.getHandMetrics
GameState.getHandY = Layout.getHandY
GameState.getDeckPosition = Layout.getDeckPosition
GameState.getDiscardPosition = Layout.getDiscardPosition
GameState.getDeckRect = Layout.getDeckRect
GameState.getBoardMetrics = Layout.getBoardMetrics
GameState.getBoardY = Layout.getBoardY
GameState.refreshLayoutPositions = Layout.refreshPositions

GameState.initPlayers = Initialiser.initPlayers
GameState.initTurnOrder = Initialiser.initTurnOrder
GameState.initRoundState = Initialiser.initRoundState
GameState.initUiState = Initialiser.initUiState
GameState.initAttachments = Initialiser.initAttachments
GameState.initResolveState = Initialiser.initResolveState
GameState.applyInitialEnergy = Initialiser.applyInitialEnergy
GameState.dealStartingHandsFromPlayerDecks = Initialiser.dealStartingHandsFromPlayerDecks

function GameState:new()
    local gs = setmetatable({}, self)

    gs:buildLayoutCache()

    local cards = {}
    for i = 1, 20 do
        table.insert(cards, Card(i, "Card " .. i))
    end
    gs.deck = Deck(cards)
    gs.deck:shuffle()

    gs:initPlayers({
        Player{ id = 1, maxHandSize = 5 },
        Player{ id = 2, maxHandSize = 5 },
    })
    gs:initTurnOrder()
    gs:initRoundState()
    gs:initUiState(true)
    gs:initAttachments()
    gs:initResolveState()
    gs:applyInitialEnergy()

    local startN = (Config.rules.startingHand or 3)
    for playerIndex = 1, #gs.players do
        for _ = 1, startN do
            gs:drawCardToPlayer(playerIndex)
        end
    end

    gs:updateCardVisibility()
    gs:refreshLayoutPositions()

    return gs
end

function GameState:newFromDraft(draftedPlayers)
    assert(type(draftedPlayers) == "table" and #draftedPlayers > 0, "Game state requires drafted players")
    local gs = setmetatable({}, self)

    gs:buildLayoutCache()

    gs:initPlayers(draftedPlayers)
    gs:initTurnOrder()
    gs:initRoundState()
    gs:initUiState(false)
    gs:initAttachments()
    gs:initResolveState()
    gs:applyInitialEnergy()
    gs:dealStartingHandsFromPlayerDecks()

    gs:updateCardVisibility()
    gs:refreshLayoutPositions()
    return gs
end
function GameState:draw()
    self:refreshLayoutPositions()

    local screenW = Viewport.getWidth()
    local layout = self:getLayout()

    HudRenderer.drawTurnBanner(self, screenW)
    BoardRenderer.draw(self, layout)
    HudRenderer.drawPostBoard(self)
    ResolveRenderer.draw(self, layout, screenW)
end

-- returns x,y for a given player's slot index, relative to current turn
function GameState:getBoardSlotPosition(playerIndex, slotIndex)
    local startX, _, layout = self:getBoardMetrics(playerIndex)
    local x = startX + (slotIndex - 1) * layout.slotSpacing
    local y = self:getBoardY(playerIndex)
    return x, y
end

-- returns x,y for a given player's hand slot index (always bottom for current)
function GameState:getHandSlotPosition(slotIndex, player)
    local startX, _, layout, _, spacing = self:getHandMetrics(player or (self.players and self.players[self.currentPlayer]))
    local step = spacing or layout.slotSpacing
    local x = startX + (slotIndex - 1) * step
    return x, self:getHandY()
end

-- returns rect for the Pass button (x, y, w, h)
function GameState:getPassButtonRect()
    local screenW = Viewport.getWidth()
    local layout = self:getLayout()
    local w, h = 100, 40
    local y = self:getHandY() + math.floor((layout.cardH - h) / 2)

    local baseX
    if Config.rules.showDiscardPile and self.discardStack then
        local discardX = self:getDiscardPosition()
        baseX = discardX + layout.cardW + layout.sideGap
    else
        local startX, width = self:getHandMetrics(self.players and self.players[self.currentPlayer])
        baseX = startX + width + layout.sideGap
    end

    local x = math.max(layout.sideGap, math.min(baseX, screenW - w - layout.sideGap))
    return x, y, w, h
end

function GameState:update(dt)
    self:refreshLayoutPositions()
    local mx, my = love.mouse.getPosition()
    mx, my = Viewport.toVirtual(mx, my)
    if self.draggingCard then
        self.draggingCard.x = mx - self.draggingCard.offsetX
        self.draggingCard.y = my - self.draggingCard.offsetY

        -- highlight discard pile if hovered and allowed
        if Config.rules.allowManualDiscard and Config.rules.showDiscardPile and self.discardStack then
            self.highlightDiscard = self.discardStack:isHovered(mx, my)
        else
            self.highlightDiscard = false
        end
    else
        self.highlightDiscard = false
    end

    -- Pass button hover (always based on mouse, independent of dragging)
    self.highlightPass = false
    if self.phase == "play" then
        local bx, by, bw, bh = self:getPassButtonRect()
        if mx >= bx and mx <= bx + bw and my >= by and my <= by + bh then
            self.highlightPass = true
        end
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
                -- start next play phase; alternate starting player per round
                self.roundStartPlayer = (self.roundStartPlayer == 1) and 2 or 1
                self.currentPlayer = self.roundStartPlayer
                self.phase = "play"
                self.resolveQueue = {}
                self.resolveIndex = 0
                self.resolveCurrentStep = nil
                -- clear attachments for next round
                self.attachments = { [1] = {}, [2] = {} }
                self:addLog("Round resolved. Back to play.")
                self:updateCardVisibility()
                self.microStarter = self.roundStartPlayer
                self:addLog(string.format("Next round: P%d starts", self.roundStartPlayer))

                -- reset pass streak on new round
                self.lastActionWasPass = false
                self.lastPassBy = nil

                -- increment round and refill energy
                if Config.rules.energyEnabled ~= false then
                    self.roundIndex = (self.roundIndex or 0) + 1
                    local base = Config.rules.energyStart or 3
                    local inc = Config.rules.energyIncrementPerRound or 0
                    local refill = base + (self.roundIndex * inc)
                    for _, p in ipairs(self.players) do
                        p.energy = refill
                    end
                    self:addLog(string.format("Energy refilled to %d (round %d)", refill, self.roundIndex))
                end

                -- auto-draw for each player at start of new round (if configured)
                local perRound = Config.rules.autoDrawPerRound or 0
                if perRound > 0 then
                    for pi = 1, #self.players do
                        for i = 1, perRound do
                            self:drawCardToPlayer(pi)
                        end
                    end
                end
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

-- Play a modifier card onto an existing card in a board slot
function GameState:playModifierOnSlot(card, targetPlayerIndex, slotIndex, retargetOffset)
    if self.phase ~= "play" then return false end
    local owner = card.owner
    if not owner then return false end

    local targetPlayer = self.players[targetPlayerIndex]
    if not targetPlayer then return false end
    local slot = targetPlayer.boardSlots[slotIndex]
    if not slot or not slot.card then return false end

    local def = card.definition or {}
    local m = def.mod
    if not m then return false end

    -- enforce target allegiance
    local isEnemy = (targetPlayer ~= owner)
    local targetOk = (m.target == "enemy" and isEnemy) or (m.target == "ally" or m.target == nil) and (not isEnemy)
    if not targetOk then
        owner:snapCard(card, self)
        return false
    end

    -- special rule: Feint (retarget) only applies to cards that attack
    if m.retarget then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        if baseAttack <= 0 then
            if owner then owner:snapCard(card, self) end
            self:addLog("Feint can only target a card with attack")
            return false
        end
    end

    -- cost check
    if Config.rules.energyEnabled ~= false then
        local cost = (card.definition and card.definition.cost) or 0
        local energy = owner.energy or 0
        if cost > energy then
            if owner then owner:snapCard(card, self) end
            self:addLog("Not enough energy")
            return false
        end
        owner.energy = energy - cost
    end

    -- record attachment to the target slot for this round
    self.attachments[targetPlayerIndex][slotIndex] = self.attachments[targetPlayerIndex][slotIndex] or {}
    local stored = {}
    for k, v in pairs(m) do stored[k] = v end
    if m.retarget and retargetOffset then
        stored.retargetOffset = retargetOffset
    end
    table.insert(self.attachments[targetPlayerIndex][slotIndex], stored)

    -- discard the modifier card (modifiers do not occupy board slots)
    self:discardCard(card)

    if stored.retargetOffset then
        local dir = stored.retargetOffset < 0 and "left" or "right"
        self:addLog(string.format("P%d plays %s (%s) on P%d slot %d", owner.id or 0, card.name or "modifier", dir, targetPlayerIndex, slotIndex))
    else
        self:addLog(string.format("P%d plays %s on P%d slot %d", owner.id or 0, card.name or "modifier", targetPlayerIndex, slotIndex))
    end

    -- micro-round progression
    if self.playsInRound == 0 then
        self.playsInRound = 1
        self:nextPlayer()
    else
        self.playsInRound = 2
        -- toggle micro-round starter (within the same round)
        self.microStarter = (self.microStarter == 1) and 2 or 1
        self.currentPlayer = self.microStarter
        self.playsInRound = 0
        self:updateCardVisibility()
        -- auto draw on turn start (for new starter), if configured
        local n = Config.rules.autoDrawOnTurnStart or 0
        if self.phase == "play" and n > 0 then
            for i = 1, n do self:drawCardToPlayer(self.currentPlayer) end
        end
    end
    -- any play breaks pass streak
    self.lastActionWasPass = false

    -- any play breaks pass streak
    self.lastActionWasPass = false

    self:maybeFinishPlayPhase()
    return true
end

-- Current player passes. Two consecutive passes (by different players) trigger resolve.
function GameState:passTurn()
    if self.phase ~= "play" then return end
    local pid = self.currentPlayer
    self:addLog(string.format("P%d passes", pid))

    local triggerResolve = false
    if self.lastActionWasPass and self.lastPassBy and self.lastPassBy ~= pid then
        triggerResolve = true
    end
    self.lastActionWasPass = true
    self.lastPassBy = pid

    if (self.playsInRound or 0) == 0 then
        self.playsInRound = 1
        self:nextPlayer()
    else
        -- complete micro-round, toggle next starter
        self.playsInRound = 2
        self.microStarter = (self.microStarter == 1) and 2 or 1
        self.currentPlayer = self.microStarter
        self.playsInRound = 0
        self:updateCardVisibility()
        -- auto draw on turn start for new starter if configured
        local n = Config.rules.autoDrawOnTurnStart or 0
        if self.phase == "play" and n > 0 then
            for i = 1, n do self:drawCardToPlayer(self.currentPlayer) end
        end
    end

    if triggerResolve then
        self:addLog("Both players pass. Resolving.")
        self:startResolve()
    end
end

-- Build a snapshot of active modifiers from modifier-type cards on the board.
-- Cards can specify definition.mod = { attack=dx, block=dx, heal=dx, target="ally|enemy", scope="all|same_slot" }
function GameState:computeActiveModifiers()
    local function emptyMods()
        return { attack = 0, block = 0, heal = 0 }
    end

    self.activeMods = {
        [1] = { global = emptyMods(), perSlot = {} },
        [2] = { global = emptyMods(), perSlot = {} },
    }

    local function addMods(dst, mod)
        if mod.attack then dst.attack = (dst.attack or 0) + mod.attack end
        if mod.block then dst.block = (dst.block or 0) + mod.block end
        if mod.heal then dst.heal = (dst.heal or 0) + mod.heal end
        if mod.retargetOffset then dst.retargetOffset = mod.retargetOffset end
    end

    for pi, p in ipairs(self.players) do
        for s, slot in ipairs(p.boardSlots) do
            local c = slot.card
            local def = c and c.definition or nil
            local m = def and def.mod or nil
            if m then
                local targetSide = (m.target == "enemy") and (pi == 1 and 2 or 1) or pi
                local entry = self.activeMods[targetSide]
                if m.scope == "same_slot" then
                    entry.perSlot[s] = entry.perSlot[s] or emptyMods()
                    addMods(entry.perSlot[s], m)
                else -- default to global/all
                    addMods(entry.global, m)
                end
            end
        end
    end

    -- add targeted attachments (played onto an existing card during play)
    if self.attachments then
        for pi = 1, #self.players do
            local sideEntry = self.activeMods[pi]
            for s, mods in pairs(self.attachments[pi] or {}) do
                for _, m in ipairs(mods) do
                    sideEntry.perSlot[s] = sideEntry.perSlot[s] or emptyMods()
                    addMods(sideEntry.perSlot[s], m)
                end
            end
        end
    end
end

-- Get the stat of a card adjusted by active modifiers affecting the owning side/slot
function GameState:getEffectiveStat(playerIndex, slotIndex, def, key)
    local base = def and def[key] or 0
    local mods = self.activeMods or {}
    local side = mods[playerIndex]
    if not side then return base end
    local total = base + (side.global[key] or 0)
    local sm = side.perSlot[slotIndex]
    if sm then total = total + (sm[key] or 0) end
    if total < 0 then total = 0 end
    return total
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

    -- snapshot modifiers from any modifier cards on the board for this round
    self:computeActiveModifiers()

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
        for idx, p in ipairs(self.players) do
            local slot = p.boardSlots[s]
            if slot and slot.card and slot.card.definition then
                local def = slot.card.definition
                local add = self:getEffectiveStat(idx, s, def, "block")
                if add and add > 0 then
                    p.block = (p.block or 0) + add
                    self:addLog(string.format("Slot %d [Block]: P%d +%d block (%s) -> %d", s, p.id or 0, add, slot.card.name or "", p.block))
                end
            end
        end
    elseif step.kind == "heal" then
        for idx, p in ipairs(self.players) do
            local slot = p.boardSlots[s]
            if slot and slot.card and slot.card.definition then
                local def = slot.card.definition
                local heal = self:getEffectiveStat(idx, s, def, "heal")
                if heal and heal > 0 then
                    local mh = p.maxHealth or 20
                    local before = p.health or mh
                    p.health = math.min(before + heal, mh)
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
        local function atkAt(playerIdx, idx)
            local p = self.players[playerIdx]
            local slot = p.boardSlots[idx]
            if slot and slot.card and slot.card.definition then
                return self:getEffectiveStat(playerIdx, idx, slot.card.definition, "attack") or 0
            end
            return 0
        end
        local function targetIndexFor(playerIdx, srcIdx)
            local mods = self.activeMods and self.activeMods[playerIdx] and self.activeMods[playerIdx].perSlot[srcIdx]
            local off = mods and mods.retargetOffset or 0
            local t = srcIdx + off
            local maxSlots = self.maxBoardCards or #self.players[playerIdx].boardSlots
            if t < 1 or t > maxSlots then
                t = srcIdx -- fallback to straight if out of range
            end
            return t
        end

        local p1, p2 = self.players[1], self.players[2]
        local a1 = atkAt(1, s)
        local a2 = atkAt(2, s)
        local t1 = targetIndexFor(1, s)
        local t2 = targetIndexFor(2, s)
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
                local suffix = (t1 ~= s) and string.format(" -> slot %d (feint)", t1) or ""
                self:addLog(string.format("Slot %d: P1 attacks P2 for %d (block %d, dmg %d)%s", s, a1, absorb2, math.max(0, r2), suffix))
            end
            if a2 > 0 then
                local suffix = (t2 ~= s) and string.format(" -> slot %d (feint)", t2) or ""
                self:addLog(string.format("Slot %d: P2 attacks P1 for %d (block %d, dmg %d)%s", s, a2, absorb1, math.max(0, r1), suffix))
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
    -- auto draw at turn start if configured and in play phase
    if self.phase == "play" then
        local n = Config.rules.autoDrawOnTurnStart or 0
        if n > 0 then
            for i = 1, n do
                self:drawCardToPlayer(self.currentPlayer)
            end
        end
    end
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
        self.microStarter = (self.microStarter == 1) and 2 or 1
        self.currentPlayer = self.microStarter
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

    -- cost check
    if Config.rules.energyEnabled ~= false then
        local cost = (card.definition and card.definition.cost) or 0
        local energy = current.energy or 0
        if cost > energy then
            current:snapCard(card, self)
            self:addLog("Not enough energy")
            return
        end
    end

    local ok = current:playCardToBoard(card, slotIndex, self)
    if ok then
        if Config.rules.energyEnabled ~= false then
            local cost = (card.definition and card.definition.cost) or 0
            if cost and cost > 0 then
                current.energy = (current.energy or 0) - cost
            end
        end
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
            self.microStarter = (self.microStarter == 1) and 2 or 1
            -- set next current player to new micro starter (unless we enter resolve)
            self.currentPlayer = self.microStarter
            self.playsInRound = 0
            self:updateCardVisibility()
            -- auto draw on turn start (for new starter), if configured
            local n = Config.rules.autoDrawOnTurnStart or 0
            if self.phase == "play" and n > 0 then
                for i = 1, n do self:drawCardToPlayer(self.currentPlayer) end
            end
        end

        -- any play breaks pass streak
        self.lastActionWasPass = false

        -- any play breaks pass streak
        self.lastActionWasPass = false

        self:maybeFinishPlayPhase()
    else
        current:snapCard(card, self)
    end
end

-- Manually refill energy based on current roundIndex and config
function GameState:refillEnergyNow(manual)
    if Config.rules.energyEnabled ~= false then
        local base = Config.rules.energyStart or 3
        local inc = Config.rules.energyIncrementPerRound or 0
        local refill = base + ((self.roundIndex or 0) * inc)
        for _, p in ipairs(self.players) do
            p.energy = refill
        end
        if manual then
            self:addLog(string.format("Energy refilled to %d (manual)", refill))
        end
    end
end

return GameState

