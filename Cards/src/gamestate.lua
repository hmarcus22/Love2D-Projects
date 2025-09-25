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

local DEFAULT_BACKGROUND_COLOR = { 0.2, 0.5, 0.2 }

local RESOLVE_STEP_HANDLERS = {
    block = "resolveBlockStep",
    attack = "resolveAttackStep",
    heal = "resolveHealStep",
    cleanup = "resolveCleanupStep",
}


local function sumSlotBlock(player)
    local total = 0
    if player and player.boardSlots then
        for _, slot in ipairs(player.boardSlots) do
            total = total + (slot.block or 0)
        end
    end
    return total
end

local function consumeSlotBlock(player, slotIndex, amount)
    if not player or not player.boardSlots or not slotIndex then return 0 end
    local slot = player.boardSlots[slotIndex]
    if not slot or amount <= 0 then return 0 end
    local before = slot.block or 0
    local absorbed = math.min(before, amount)
    if absorbed > 0 then
        slot.block = before - absorbed
    end
    player.block = sumSlotBlock(player)
    return absorbed
end

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

    local rules = Config.rules or {}
    local defaultHand = rules.maxHandSize or 5
    gs:initPlayers({
        Player{ id = 1, maxHandSize = defaultHand, maxBoardCards = rules.maxBoardCards },
        Player{ id = 2, maxHandSize = defaultHand, maxBoardCards = rules.maxBoardCards },
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

    gs.pendingRetarget = nil
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

    gs.pendingRetarget = nil
    gs:updateCardVisibility()
    gs:refreshLayoutPositions()
    return gs
end
function GameState:getTurnBackgroundColor()
    local base = DEFAULT_BACKGROUND_COLOR
    local player = self:getCurrentPlayer()
    local color = player and player.getFighterColor and player:getFighterColor() or nil
    if not color then
        return base[1], base[2], base[3]
    end

    local accentR = math.max(0, math.min(1, color[1] or base[1]))
    local accentG = math.max(0, math.min(1, color[2] or base[2]))
    local accentB = math.max(0, math.min(1, color[3] or base[3]))

    local blend = 0.7
    local r = base[1] + (accentR - base[1]) * blend
    local g = base[2] + (accentG - base[2]) * blend
    local b = base[3] + (accentB - base[3]) * blend

    return r, g, b
end

function GameState:draw()
    self:refreshLayoutPositions()

    local r, g, b = self:getTurnBackgroundColor()
    love.graphics.clear(r, g, b, 1)

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
    local layout = self:getLayout()
    local hoverSpeed = layout.handHoverSpeed or 12
    local lerpFactor = math.min(1, hoverSpeed * dt)
    if self.players then
        for _, player in ipairs(self.players) do
            if player.slots then
                local isCurrent = (self.players and self.players[self.currentPlayer] == player)
                for _, slot in ipairs(player.slots) do
                    local card = slot.card
                    if card then
                        local target = card.handHoverTarget or 0
                        if not isCurrent then
                            target = 0
                        end
                        if card.dragging then
                            target = 0
                        end
                        local amount = card.handHoverAmount or 0
                        amount = amount + (target - amount) * lerpFactor
                        if target == 0 and math.abs(amount) < 0.001 then
                            amount = 0
                        end
                        card.handHoverAmount = amount
                    end
                end
            end
        end
    end
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
                self.turnActionCount = 0
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
                    local base = Config.rules.energyStart or 0
                    local inc = Config.rules.energyIncrementPerRound or 0
                    local refill = base + (self.roundIndex * inc)
                    local maxEnergy = Config.rules.energyMax
                    if maxEnergy then
                        refill = math.min(refill, maxEnergy)
                    end
                    for _, p in ipairs(self.players) do
                        p.energy = refill
                    end
                    self:addLog(string.format("Energy refilled to %d (round %d)", refill, self.roundIndex))
                end

                -- auto-draw for each player at start of new round (config + fighter bonus)
                local perRound = Config.rules.autoDrawPerRound or 0
                for pi = 1, #self.players do
                    local player = self.players[pi]
                    local bonus = player and player.getDrawBonus and player:getDrawBonus("roundStart") or 0
                    local total = perRound + (bonus or 0)
                    for i = 1, total do
                        self:drawCardToPlayer(pi)
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
    if self:hasPendingRetarget() then return false end
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


    -- Restrict +block modifiers to block cards, +attack modifiers to attack cards
    if m.block and m.block > 0 then
        local baseBlock = (slot.card.definition and slot.card.definition.block) or 0
        if baseBlock <= 0 then
            if owner then owner:snapCard(card, self) end
            self:addLog("Block modifier can only target a card with block")
            return false
        end
    end
    if m.attack and m.attack > 0 then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        if baseAttack <= 0 then
            if owner then owner:snapCard(card, self) end
            self:addLog("Attack modifier can only target a card with attack")
            return false
        end
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
        local cost = self:getEffectiveCardCost(owner, card)
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
    local cardName = card.name or "modifier"
    local directionLabel
    local selectionPending = false

    if m.retarget then
        if retargetOffset ~= nil then
            stored.retargetOffset = retargetOffset
            if retargetOffset == 0 then
                directionLabel = "straight"
            else
                directionLabel = retargetOffset < 0 and "left" or "right"
            end
        else
            selectionPending = true
        end
    end

    table.insert(self.attachments[targetPlayerIndex][slotIndex], stored)

    -- discard the modifier card (modifiers do not occupy board slots)
    self:discardCard(card)

    if selectionPending then
        self:initiateRetargetSelection(owner, targetPlayerIndex, slotIndex, stored, cardName)
        return true
    end

    if directionLabel then
        self:addLog(string.format("P%d plays %s (%s) on P%d slot %d", owner.id or 0, cardName, directionLabel, targetPlayerIndex, slotIndex))
    else
        self:addLog(string.format("P%d plays %s on P%d slot %d", owner.id or 0, cardName, targetPlayerIndex, slotIndex))
    end

    self:registerTurnAction()
    self.lastActionWasPass = false

    self:nextPlayer()

    self:maybeFinishPlayPhase()

    return true
end

-- Current player passes. Two consecutive passes (by different players) trigger resolve.
function GameState:passTurn()

    if self.phase ~= "play" then return end
    if self.hasPendingRetarget and self:hasPendingRetarget() then return end

    local pid = self.currentPlayer

    self:addLog(string.format("P%d passes", pid))

    local triggerResolve = false
    local isFirstAction = (self.turnActionCount or 0) == 0

    if self.lastActionWasPass and self.lastPassBy and self.lastPassBy ~= pid and isFirstAction then

        triggerResolve = true

    end

    self.lastActionWasPass = true

    self.lastPassBy = pid

    self:nextPlayer()

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

    if self.players then
        for pi, player in ipairs(self.players) do
            local passive = player.getBoardPassiveMods and player:getBoardPassiveMods()
            if passive then
                local entry = self.activeMods[pi]
                local slotCount = self.maxBoardCards or player.maxBoardCards or #player.boardSlots or 0
                for s = 1, slotCount do
                    entry.perSlot[s] = entry.perSlot[s] or emptyMods()
                    addMods(entry.perSlot[s], passive)
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
    local total = base
    if side then
        total = total + (side.global[key] or 0)
        local perSlot = side.perSlot
        if perSlot then
            local sm = perSlot[slotIndex]
            if sm then
                total = total + (sm[key] or 0)
            end
        end
    end

    if key == "attack" and total > 0 then
        local player = self.players and self.players[playerIndex] or nil
        local slot = player and player.boardSlots and player.boardSlots[slotIndex] or nil
        local card = slot and slot.card or nil
        local variance = card and card.statVariance or nil
        local roll = variance and variance.attack or 0
        if roll ~= 0 then
            total = total + roll
        end
    end

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

    self.pendingRetarget = nil

    for _, player in ipairs(self.players or {}) do
        player.block = 0
        for _, slot in ipairs(player.boardSlots or {}) do
            slot.block = 0
        end
    end

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

function GameState:resolveBlockStep(slotIndex)
    for idx, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot then
            local def = slot.card and slot.card.definition or nil
            local add = self:getEffectiveStat(idx, slotIndex, def, "block")
            if add and add > 0 then
                slot.block = (slot.block or 0) + add
                player.block = sumSlotBlock(player)
                local source = slot.card and slot.card.name or "passive"
                self:addLog(string.format("Slot %d [Block]: P%d +%d block (%s) -> slot %d, total %d", slotIndex, player.id or 0, add, source, slot.block or 0, player.block or 0))
            end
        end
    end
end

function GameState:resolveHealStep(slotIndex)
    for idx, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot and slot.card and slot.card.definition then
            local def = slot.card.definition
            local heal = self:getEffectiveStat(idx, slotIndex, def, "heal")
            if heal and heal > 0 then
                local maxHealth = player.maxHealth or 20
                local before = player.health or maxHealth
                player.health = math.min(before + heal, maxHealth)
                local gained = player.health - before
                if gained > 0 then
                    self:addLog(string.format("Slot %d [Heal]: P%d +%d HP (%s) -> %d/%d", slotIndex, player.id or 0, gained, slot.card.name or "", player.health, maxHealth))
                end
            end
        end
    end
end

function GameState:resolveAttackStep(slotIndex)
    local players = self.players or {}
    local p1, p2 = players[1], players[2]

    local function atkAt(playerIdx, idx)
        local player = players[playerIdx]
        local slot = player and player.boardSlots and player.boardSlots[idx]
        if slot and slot.card and slot.card.definition then
            local card = slot.card
            -- Combo logic: apply bonus if combo requirements met
            if player.canPlayCombo and player:canPlayCombo(card) then
                player:applyComboBonus(card)
            end
            -- Ultimate logic: apply effect if ultimate
            if player.canPlayUltimate and player:canPlayUltimate(card) and card.effect then
                self:applyUltimateEffect(playerIdx, idx, card)
            end
            return self:getEffectiveStat(playerIdx, idx, card.definition, "attack") or 0
        end
        return 0
    end
-- Apply ultimate card effects (simple implementation)
function GameState:applyUltimateEffect(playerIdx, slotIdx, card)
    if card.effect == "swap_enemies" then
        -- Swap all enemy card positions
        local enemyIdx = (playerIdx == 1) and 2 or 1
        local enemy = self.players[enemyIdx]
        if enemy and enemy.boardSlots then
            local slots = enemy.boardSlots
            for i = 1, math.floor(#slots / 2) do
                slots[i], slots[#slots - i + 1] = slots[#slots - i + 1], slots[i]
            end
            self:addLog(string.format("Ultimate: P%d swaps all enemy cards!", playerIdx))
        end
    elseif card.effect == "aoe_attack" then
        -- Deal attack to all enemy cards
        local enemyIdx = (playerIdx == 1) and 2 or 1
        local enemy = self.players[enemyIdx]
        if enemy and enemy.boardSlots then
            for i, slot in ipairs(enemy.boardSlots) do
                local damage = card.attack or 0
                if damage > 0 then
                    local before = enemy.health or enemy.maxHealth or 20
                    enemy.health = before - damage
                    self:addLog(string.format("Ultimate: P%d deals %d to P%d (slot %d)", playerIdx, damage, enemyIdx, i))
                end
            end
        end
    end
end

    local function targetIndexFor(playerIdx, srcIdx)
        local mods = self.activeMods and self.activeMods[playerIdx] and self.activeMods[playerIdx].perSlot[srcIdx]
        local offset = mods and mods.retargetOffset or 0
        local target = srcIdx + offset
        local maxSlots = self.maxBoardCards or (players[playerIdx] and #players[playerIdx].boardSlots) or 0
        if target < 1 or target > maxSlots then
            target = srcIdx
        end
        return target
    end

    local a1 = atkAt(1, slotIndex)
    local a2 = atkAt(2, slotIndex)
    if a1 <= 0 and a2 <= 0 then
        return
    end

    local t1 = targetIndexFor(1, slotIndex)
    local t2 = targetIndexFor(2, slotIndex)

    local blockTargetP2 = (p2 and p2.boardSlots and p2.boardSlots[t1] and p2.boardSlots[t1].block) or 0
    local blockTargetP1 = (p1 and p1.boardSlots and p1.boardSlots[t2] and p1.boardSlots[t2].block) or 0
    local absorb2 = math.min(blockTargetP2, a1)
    local absorb1 = math.min(blockTargetP1, a2)

    consumeSlotBlock(p2, t1, absorb2)
    consumeSlotBlock(p1, t2, absorb1)

    local remainder1 = a2 - absorb1
    local remainder2 = a1 - absorb2

    if remainder2 > 0 and p2 then
        p2.health = (p2.health or p2.maxHealth or 20) - remainder2
    end
    if remainder1 > 0 and p1 then
        p1.health = (p1.health or p1.maxHealth or 20) - remainder1
    end

    if a1 > 0 then
        local suffix = (t1 ~= slotIndex) and string.format(" -> slot %d (feint)", t1) or ""
        self:addLog(string.format("Slot %d: P1 attacks P2 for %d (block %d, dmg %d)%s", slotIndex, a1, absorb2, math.max(0, remainder2), suffix))
    end
    if a2 > 0 then
        local suffix = (t2 ~= slotIndex) and string.format(" -> slot %d (feint)", t2) or ""
        self:addLog(string.format("Slot %d: P2 attacks P1 for %d (block %d, dmg %d)%s", slotIndex, a2, absorb1, math.max(0, remainder1), suffix))
    end
end

function GameState:resolveCleanupStep(slotIndex)
    for _, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot and slot.card then
            self:addLog(string.format("Slot %d: P%d discards %s", slotIndex, player.id or 0, slot.card.name or "card"))
            self:discardCard(slot.card)
            slot.card = nil
        end
        if slot then
            slot.block = 0
        end
    end

    for idx, player in ipairs(self.players or {}) do
        if (player.health or 0) <= 0 then
            print(string.format("Player %d has been defeated!", idx))
            self:addLog(string.format("Player %d is defeated!", idx))
        end
    end
end

function GameState:performResolveStep(step)
    local handlerName = RESOLVE_STEP_HANDLERS[step.kind]
    if handlerName and self[handlerName] then
        self[handlerName](self, step.slot)
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
    card.statVariance = nil
    table.insert(self.discardPile, card)
end

function GameState:getCurrentPlayer()
    return self.players[self.currentPlayer]
end

function GameState:registerTurnAction()
    self.turnActionCount = (self.turnActionCount or 0) + 1
end

function GameState:nextPlayer(shouldAutoDraw)
    local players = self.players
    if not players or #players == 0 then
        return
    end

    local nextIndex = self:findNextPlayerIndex() or self.currentPlayer
    if nextIndex then
        self.currentPlayer = nextIndex
    end

    self.microStarter = self.currentPlayer
    self.turnActionCount = 0
    self.playsInRound = 0
    self:updateCardVisibility()

    if shouldAutoDraw ~= false then
        self:drawCardsForTurnStart()
    end
end

-- Advance the turn respecting the micro-round alternation.
-- Debug helper used by the space key; does not alter playedCount.
function GameState:advanceTurn()

    if self.phase ~= "play" then return end
    if self:hasPendingRetarget() then return end

    self.lastActionWasPass = false

    self:nextPlayer()

end



-- check if both have placed 3, if so go to resolve
function GameState:maybeFinishPlayPhase()
    local allDone = true
    for _, player in ipairs(self.players or {}) do
        if self:hasBoardCapacity(player) then
            allDone = false
            break
        end
    end

    if allDone then
        print("Both players have finished placing cards! Switching to resolve phase.")
        self:startResolve()
    end
end

function GameState:hasBoardCapacity(player)
    if not player then
        return false
    end

    local limit = self.maxBoardCards or player.maxBoardCards or #(player.boardSlots or {})
    local played = self.playedCount and self.playedCount[player.id] or 0
    return played < limit
end

function GameState:getEffectiveCardCost(player, card)
    local def = card and card.definition
    local cost = def and def.cost or 0
    if not def or not player then
        return cost
    end

    local adjust = def.costAdjust
    if adjust then
        local ruleType = adjust.type
        if ruleType == "belowHalfHealth" then
            local maxHealth = player.maxHealth or 0
            local current = player.health or maxHealth
            local threshold = adjust.threshold or 0.5
            if maxHealth > 0 and current <= maxHealth * threshold then
                cost = adjust.cost or cost
            end
        end

        local minCost = adjust.min
        if minCost ~= nil then
            cost = math.max(cost, minCost)
        end

        local maxCost = adjust.max
        if maxCost ~= nil then
            cost = math.min(cost, maxCost)
        end
    end

    if cost < 0 then
        cost = 0
    end

    return cost
end
function GameState:canAffordCard(player, card)
    if Config.rules.energyEnabled == false then
        return true, 0
    end

    local cost = self:getEffectiveCardCost(player, card)
    local energy = player and player.energy or 0
    if cost <= energy then
        return true, cost
    end

    return false, cost
end

function GameState:deductEnergyForCard(player, cost)
    if Config.rules.energyEnabled == false or not player then
        return
    end

    local amount = cost or 0
    if amount > 0 then
        player.energy = (player.energy or 0) - amount
    end
end

function GameState:applyCardVariance(player, card)
    local def = card and card.definition
    if not def then
        card.statVariance = nil
        return
    end

    local fighter = player and player.getFighter and player:getFighter() or nil
    local passives = fighter and fighter.passives or nil
    local roll = self:rollVarianceForStat(player, card, def, passives, 'attack', 'attackVariance')
    card.statVariance = roll and { attack = roll } or nil
end

function GameState:rollVarianceForStat(player, card, def, passives, statKey, passiveKey)
    if not def then return nil end
    local base = def[statKey]
    if not base or base <= 0 then return nil end

    local config = passives and passives[passiveKey] or nil
    local amount = self:getVarianceAmount(config)
    if amount <= 0 then return nil end

    local rng = (love and love.math and love.math.random) or math.random
    local roll = ((rng(2) == 1) and 1 or -1) * amount

    local delta = roll > 0 and ('+' .. roll) or tostring(roll)
    local cardName = card and (card.name or (card.definition and card.definition.name)) or 'card'
    local playerId = player and player.id or 0
    local msg = string.format("P%d %s variance %s on %s", playerId, statKey, delta, cardName)
    self:addLog(msg)
    print(msg)

    return roll
end

function GameState:initiateRetargetSelection(owner, sourcePlayerIndex, slotIndex, attachment, cardName)
    local opponentIndex = (sourcePlayerIndex == 1 and 2) or 1
    if not (self.players and self.players[opponentIndex]) then
        opponentIndex = sourcePlayerIndex
        for idx, _ in ipairs(self.players or {}) do
            if idx ~= sourcePlayerIndex then
                opponentIndex = idx
                break
            end
        end
    end
    self.pendingRetarget = {
        ownerId = owner and owner.id or 0,
        sourcePlayerIndex = sourcePlayerIndex,
        sourceSlotIndex = slotIndex,
        opponentPlayerIndex = opponentIndex,
        attachment = attachment,
        cardName = cardName or 'Feint',
    }
    self:addLog(string.format("P%d plays %s on slot %d - choose opposing slot", self.pendingRetarget.ownerId or 0, cardName or 'Feint', slotIndex))
end

function GameState:hasPendingRetarget()
    return self.pendingRetarget ~= nil
end

function GameState:getPendingRetarget()
    return self.pendingRetarget
end

function GameState:selectRetargetSlot(playerIndex, slotIndex)
    local pending = self.pendingRetarget
    if not pending then
        return false
    end

    local sourceSlot = pending.sourceSlotIndex
    local offset
    if playerIndex == pending.opponentPlayerIndex then
        offset = slotIndex - sourceSlot
        if math.abs(offset) > 1 then
            self:addLog('Feint can only target adjacent opposing slots')
            return false
        end
    elseif playerIndex == pending.sourcePlayerIndex then
        if slotIndex ~= sourceSlot then
            self:addLog('Choose straight, left, or right relative to the current slot')
            return false
        end
        offset = 0
    else
        return false
    end

    local opponentSlots = self.players and self.players[pending.opponentPlayerIndex] and self.players[pending.opponentPlayerIndex].boardSlots or {}
    local maxSlots = self.maxBoardCards or #opponentSlots
    if slotIndex < 1 or slotIndex > (maxSlots > 0 and maxSlots or #opponentSlots) then
        self:addLog('Feint target out of range')
        return false
    end

    if pending.attachment then
        pending.attachment.retargetOffset = offset
    end

    local direction = (offset == 0) and 'straight' or (offset < 0 and 'left' or 'right')
    self:addLog(string.format('Feint retarget -> %s (slot %d)', direction, slotIndex))

    self.pendingRetarget = nil
    self:registerTurnAction()
    self.lastActionWasPass = false
    self:nextPlayer()
    self:maybeFinishPlayPhase()
    return true
end

function GameState:getVarianceAmount(config)
    if type(config) == 'table' then
        return config.amount or config.value or config.delta or 0
    end
    return config or 0
end

function GameState:onCardPlaced(player, card, slotIndex)
    card.zone = 'board'
    card.faceUp = true

    local id = player and player.id
    if id then
        self.playedCount[id] = (self.playedCount[id] or 0) + 1
    end

    self:registerTurnAction()

    if id then
        local limit = self.maxBoardCards or player.maxBoardCards or #(player.boardSlots or {})
        print(string.format(
            "Player %d placed a card in slot %d. Played %d/%d cards.",
            id,
            slotIndex,
            self.playedCount[id],
            limit
        ))
    end

    self.lastActionWasPass = false
    self:nextPlayer()
    self:maybeFinishPlayPhase()
end

function GameState:playerCanStillPlay(player)
    return self:hasBoardCapacity(player)
end

function GameState:findNextPlayerIndex()
    local players = self.players
    local count = players and #players or 0
    if count == 0 then
        return nil
    end

    local originalIndex = self.currentPlayer or 1
    local candidate = originalIndex
    for _ = 1, count do
        candidate = (candidate % count) + 1
        if candidate ~= originalIndex and self:playerCanStillPlay(players[candidate]) then
            return candidate
        end
    end

    return (originalIndex % count) + 1
end

function GameState:drawCardsForTurnStart()
    if self.phase ~= 'play' then
        return
    end

    local base = Config.rules.autoDrawOnTurnStart or 0
    local currentPlayer = self:getCurrentPlayer()
    if not currentPlayer then
        return
    end
    local bonus = currentPlayer and currentPlayer.getDrawBonus and currentPlayer:getDrawBonus('turnStart') or 0
    local total = base + (bonus or 0)
    if total <= 0 then
        return
    end
    for i = 1, total do
        self:drawCardToPlayer(self.currentPlayer)
    end
end

function GameState:playCardFromHand(card, slotIndex)
    if self.phase ~= "play" then
        return
    end

    if self:hasPendingRetarget() then
        return
    end

    local current = self:getCurrentPlayer()
    if not current or card.owner ~= current then
        return
    end

    if not self:hasBoardCapacity(current) then
        current:snapCard(card, self)
        return
    end

    local canPay, cost = self:canAffordCard(current, card)
    if not canPay then
        current:snapCard(card, self)
        self:addLog("Not enough energy")
        return
    end

    if not current:playCardToBoard(card, slotIndex, self) then
        current:snapCard(card, self)
        return
    end

    self:deductEnergyForCard(current, cost)
    self:applyCardVariance(current, card)
    self:onCardPlaced(current, card, slotIndex)
end

-- Manually refill energy based on current roundIndex and config
function GameState:refillEnergyNow(manual)
    if Config.rules.energyEnabled ~= false then
        local base = Config.rules.energyStart or 0
        local inc = Config.rules.energyIncrementPerRound or 0
        local refill = base + ((self.roundIndex or 0) * inc)
        local maxEnergy = Config.rules.energyMax
        if maxEnergy then
            refill = math.min(refill, maxEnergy)
        end
        for _, p in ipairs(self.players) do
            p.energy = refill
        end
        if manual then
            self:addLog(string.format("Energy refilled to %d (manual)", refill))
        end
    end
end

return GameState
