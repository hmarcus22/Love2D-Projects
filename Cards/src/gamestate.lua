local Card = require "src.card"
local Deck = require "src.deck"
local Actions = require "src.actions"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"
local Layout = require "src.game_layout"
local PlayerManager = require "src.player_manager"
local BoardRenderer = require "src.renderers.board_renderer"
local HudRenderer = require "src.renderers.hud_renderer"
local ResolveRenderer = require "src.renderers.resolve_renderer"
local Resolve = require "src.resolve"

local DEFAULT_BACKGROUND_COLOR = { 0.2, 0.5, 0.2 }

local RESOLVE_STEP_HANDLERS = {
    block = "resolveBlockStep",
    attack = "resolveAttackStep",
    heal = "resolveHealStep",
    cleanup = "resolveCleanupStep",
}


local Deck = require "src.deck"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"
local Layout = require "src.game_layout"
local Initialiser = require "src.game_initialiser"
local BoardRenderer = require "src.renderers.board_renderer"
local HudRenderer = require "src.renderers.hud_renderer"
local ResolveRenderer = require "src.renderers.resolve_renderer"
local Resolve = require "src.resolve"

local DEFAULT_BACKGROUND_COLOR = { 0.2, 0.5, 0.2 }




local RESOLVE_STEP_HANDLERS = {
    block = "resolveBlockStep",
    attack = "resolveAttackStep",
    heal = "resolveHealStep",
    cleanup = "resolveCleanupStep",
}

local GameState = {}
GameState.__index = GameState

function GameState:getDeckRect()
    return Layout.getDeckRect(self)
end

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

GameState.buildLayoutCache = Layout.buildCache
GameState.getBoardMetrics = Layout.getBoardMetrics
GameState.getBoardY = Layout.getBoardY
GameState.refreshLayoutPositions = Layout.refreshPositions

GameState.initPlayers = PlayerManager.initPlayers
GameState.initTurnOrder = PlayerManager.initTurnOrder
GameState.initRoundState = PlayerManager.initRoundState
GameState.initUiState = Initialiser.initUiState
GameState.initAttachments = PlayerManager.initAttachments
GameState.initResolveState = Initialiser.initResolveState
GameState.applyInitialEnergy = Initialiser.applyInitialEnergy
GameState.dealStartingHandsFromPlayerDecks = Initialiser.dealStartingHandsFromPlayerDecks

function GameState:resetRoundFlags()
    local count = self.players and #self.players or 0
    self.invulnerablePlayers = {}
    self.specialAttackMultipliers = {}
    self.skipTurnActive = {}
    self.stunNextRound = self.stunNextRound or {}
    for i = 1, count do
        self.invulnerablePlayers[i] = false
        self.specialAttackMultipliers[i] = {}
        self.skipTurnActive[i] = false
        local player = self.players and self.players[i] or nil
        if player then
            player.prevCardId = nil
            player.lastCardId = nil
            player.roundPunchCount = 0
        end
    end
end

function GameState:activateRoundStatuses()
    local count = self.players and #self.players or 0
    if count == 0 then return end
    self.skipTurnActive = self.skipTurnActive or {}
    for i = 1, count do
        if self.stunNextRound and self.stunNextRound[i] then
            self.skipTurnActive[i] = true
            self.stunNextRound[i] = false
            self:addLog(string.format("Player %d is stunned at the start of the round!", i))
            if self.logger then
                self.logger:log_event("stun_round_start", { player = i })
            end
        elseif self.skipTurnActive[i] == nil then
            self.skipTurnActive[i] = false
        end
    end
end

function GameState:ensureCurrentPlayerReady()
    local count = self.players and #self.players or 0
    if count == 0 then return end
    local iterations = 0
    while self.skipTurnActive and self.skipTurnActive[self.currentPlayer] and iterations < count do
        self.skipTurnActive[self.currentPlayer] = false
        self:addLog(string.format("Player %d is stunned and skips a turn!", self.currentPlayer))
        if self.logger then
            self.logger:log_event("stun_skip_turn", { player = self.currentPlayer })
        end
        local nextIndex = self:findNextPlayerIndex()
        if not nextIndex or nextIndex == self.currentPlayer then
            break
        end
        self.currentPlayer = nextIndex
        iterations = iterations + 1
    end
end

function GameState:isPlayerInvulnerable(playerIndex)
    return self.invulnerablePlayers and self.invulnerablePlayers[playerIndex]
end

function GameState:handleCardPlayed(player, card, slotIndex)
    if not player or not card then
        return
    end
    player.prevCardId = player.lastCardId
    player.lastCardId = card.id
    if card.id == "punch" then
        player.roundPunchCount = (player.roundPunchCount or 0) + 1
    end
    self:recordSpecialEffectOnPlay(player, card, slotIndex)
end

function GameState:recordSpecialEffectOnPlay(player, card, slotIndex)
    if not card or not card.definition or not player then
        return
    end
    local effect = card.definition.effect
    if effect == "double_attack_one_round" then
        self.specialAttackMultipliers = self.specialAttackMultipliers or {}
        self.specialAttackMultipliers[player.id] = self.specialAttackMultipliers[player.id] or {}
        self.specialAttackMultipliers[player.id][slotIndex] = 2
        self:addLog(string.format("P%d powers up %s for this round!", player.id or 0, card.name or "card"))
    end
end

function GameState:swapEnemyBoard(defenderIdx)
    local enemy = self.players and self.players[defenderIdx] or nil
    if not enemy or not enemy.boardSlots then
        return
    end
    local slots = enemy.boardSlots
    local n = #slots
    for i = 1, math.floor(n / 2) do
        slots[i], slots[n - i + 1] = slots[n - i + 1], slots[i]
    end
    self:addLog(string.format("Ultimate: P%d's formation is flipped!", defenderIdx))
    self:refreshLayoutPositions()
end

function GameState:performAoeAttack(attackerIdx, attackValue)
    if attackValue <= 0 then
        return
    end
    local enemyIdx = (attackerIdx == 1) and 2 or 1
    local enemy = self.players and self.players[enemyIdx] or nil
    if not enemy then
        return
    end
    local hits = 0
    if enemy.boardSlots then
        for _, slot in ipairs(enemy.boardSlots) do
            if slot.card then
                hits = hits + 1
            end
        end
    end
    if hits == 0 then
        hits = 1
    end
    local total = attackValue * hits
    local before = enemy.health or enemy.maxHealth or 20
    enemy.health = math.max(0, before - total)
    self:addLog(string.format("Ultimate: P%d strikes every foe for %d (total %d)", attackerIdx, attackValue, total))
end

function GameState:knockOffBoard(playerIdx, slotIdx, sourceIdx)
    local defender = self.players and self.players[playerIdx] or nil
    if not defender or not defender.boardSlots or not slotIdx then
        return false
    end
    local slot = defender.boardSlots[slotIdx]
    if slot and slot.card then
        local removed = slot.card
        slot.card = nil
        slot.block = 0
        self:discardCard(removed)
        self:addLog(string.format("Ultimate: P%d throws P%d's %s out of the ring!", sourceIdx or 0, playerIdx or 0, removed.name or "card"))
        self:refreshLayoutPositions()
        return true
    end
    return false
end

function GameState:queueStun(playerIdx, sourceIdx)
    self.stunNextRound = self.stunNextRound or {}
    if not self.stunNextRound[playerIdx] then
        self.stunNextRound[playerIdx] = true
        self:addLog(string.format("Ultimate: P%d stuns P%d for the next round!", sourceIdx or 0, playerIdx or 0))
        if self.logger then
            self.logger:log_event("stun_applied", { target = playerIdx, source = sourceIdx })
        end
    end
end

function GameState:attemptAssassinate(attackerIdx, defenderIdx)
    local enemy = self.players and self.players[defenderIdx] or nil
    if not enemy then
        return false
    end
    local maxHealth = enemy.maxHealth or 20
    local threshold = math.floor(maxHealth / 2)
    local current = enemy.health or maxHealth
    if current <= threshold then
        enemy.health = 0
        self:addLog(string.format("Ultimate: P%d executes P%d!", attackerIdx or 0, defenderIdx or 0))
        if enemy.boardSlots then
            for _, slot in ipairs(enemy.boardSlots) do
                if slot.card then
                    self:discardCard(slot.card)
                    slot.card = nil
                end
                slot.block = 0
            end
        end
        self:refreshLayoutPositions()
        return true
    end
    self:addLog(string.format("Ultimate: P%d attempts Assassinate but the target withstands it.", attackerIdx or 0))
    return false
end

function GameState:applyCardEffectsDuringAttack(attackerIdx, defenderIdx, originSlotIdx, targetSlotIdx, card, context)
    if not card or not card.definition then
        return
    end
    context = context or {}
    local effect = card.definition.effect
    if not effect then
        return
    end
    card.effectsTriggered = card.effectsTriggered or {}
    if effect == "double_attack_one_round" then
        return
    end
    if effect == "avoid_all_attacks" then
        if not self:isPlayerInvulnerable(attackerIdx) then
            self.invulnerablePlayers[attackerIdx] = true
            self:addLog(string.format("Ultimate: P%d cannot be targeted for the rest of the round!", attackerIdx))
        end
        card.effectsTriggered[effect] = true
        return
    end
    if card.effectsTriggered[effect] then
        return
    end
    if effect == "swap_enemies" then
        self:swapEnemyBoard(defenderIdx)
    elseif effect == "aoe_attack" then
        local value = context.attack or card.definition.attack or 0
        self:performAoeAttack(attackerIdx, value)
    elseif effect == "ko_below_half_hp" then
        if self:attemptAssassinate(attackerIdx, defenderIdx) then
            context.skipDamage = true
        end
    elseif effect == "knock_off_board" then
        if self:knockOffBoard(defenderIdx, targetSlotIdx, attackerIdx) then
            context.ignoreBlock = true
        end
    elseif effect == "stun_next_round" then
        self:queueStun(defenderIdx, attackerIdx)
    end
    card.effectsTriggered[effect] = true
end

function GameState:new()
    gs.roundWins = { [1] = 0, [2] = 0 }
    gs.matchWinner = nil
    local gs = setmetatable({}, self)
    gs.logger = require("src.game_logger")()

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
    gs:initRoundState()

function GameState:getDiscardPosition()
    return Layout.getDiscardPosition(self)
end
    gs:initUiState(true)
    gs.hasSharedDeck = true
    gs:initAttachments()
    gs:resetRoundFlags()
    gs:activateRoundStatuses()
    gs:ensureCurrentPlayerReady()
    gs:initResolveState()
    gs:applyInitialEnergy()

    local startN = (Config.rules.startingHand or 3)
    for playerIndex = 1, #gs.players do
        for _ = 1, startN do
            BoardManager.drawCardToPlayer(gs, playerIndex)
        end
    end

    gs.pendingRetarget = nil
    gs:updateCardVisibility()
    gs:refreshLayoutPositions()

    gs.logger:log_event("game_start", { players = { gs.players[1].id, gs.players[2].id } })

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
    gs.hasSharedDeck = false
    gs:initAttachments()
    gs:resetRoundFlags()
    gs:activateRoundStatuses()
    gs:ensureCurrentPlayerReady()
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

function GameState:getHandY()
    return Layout.getHandY(self)
end

-- returns rect for the Pass button (x, y, w, h)
function GameState:new()
    local gs = setmetatable({}, self)
    gs.roundWins = { [1] = 0, [2] = 0 }
    gs.matchWinner = nil
    gs.logger = require("src.game_logger")()

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
    gs:initRoundState()

    gs:initUiState(true)
    gs.hasSharedDeck = true
    gs:initAttachments()
    gs:resetRoundFlags()
    gs:activateRoundStatuses()
    gs:ensureCurrentPlayerReady()
    gs:initResolveState()
    gs:applyInitialEnergy()

    local startN = (Config.rules.startingHand or 3)
    for playerIndex = 1, #gs.players do
        for _ = 1, startN do
            BoardManager.drawCardToPlayer(gs, playerIndex)
        end
    end

    gs.pendingRetarget = nil
    gs:updateCardVisibility()
    gs:refreshLayoutPositions()

    gs.logger:log_event("game_start", { players = { gs.players[1].id, gs.players[2].id } })

    return gs
end

function GameState:getPassButtonRect()
    local layout = self:getLayout()
    local x = layout.passButtonX or 0
    local y = layout.passButtonY or 0
    local w = layout.passButtonW or 100
    local h = layout.passButtonH or 40
    return x, y, w, h
end

function GameState:update(dt)
    -- Add per-frame game update logic here if needed
    if self.phase == "resolve" and self.resolveQueue and self.resolveIndex then
        -- Set current step for visual indication
        if self.resolveIndex < #self.resolveQueue then
            self.resolveCurrentStep = self.resolveQueue[self.resolveIndex + 1]
        else
            self.resolveCurrentStep = nil
        end
        self.resolveTimer = (self.resolveTimer or 0) + (dt or 0)
        local stepDuration = self.resolveStepDuration or 0.5
        while self.resolveIndex < #self.resolveQueue and self.resolveTimer >= stepDuration do
            self.resolveTimer = self.resolveTimer - stepDuration
            self.resolveIndex = self.resolveIndex + 1
            local step = self.resolveQueue[self.resolveIndex]
            if step then
                print(string.format("[DEBUG] Performing resolve step %d/%d: %s slot %d", self.resolveIndex, #self.resolveQueue, step.kind, step.slot))
                self:performResolveStep(step)
            end
            -- Update current step after performing
            if self.resolveIndex < #self.resolveQueue then
                self.resolveCurrentStep = self.resolveQueue[self.resolveIndex + 1]
            else
                self.resolveCurrentStep = nil
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

    print("[DEBUG] GameState:passTurn called. Phase:", self.phase)
    if self.phase ~= "play" then return end
    if self.hasPendingRetarget and self:hasPendingRetarget() then return end

    local pid = self.currentPlayer

    self:addLog(string.format("P%d passes", pid))
    if self.logger then
        self.logger:log_event("pass", { player = pid })
    end

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
        if self.logger then
            self.logger:log_event("resolve_start", {})
        end
        self:startResolve()
    end
end


-- Build a snapshot of active modifiers from modifier-type cards on the board.
-- Cards can specify definition.mod = { attack=dx, block=dx, heal=dx, target="ally|enemy", scope="all|same_slot" }
function GameState:computeActiveModifiers()
    self.activeMods = Resolve.computeActiveModifiers(self)
end

-- Get the stat of a card adjusted by active modifiers affecting the owning side/slot
function GameState:getEffectiveStat(playerIndex, slotIndex, def, key)
    return Resolve.getEffectiveStat(self, playerIndex, slotIndex, def, key)
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
    Resolve.resolveBlockStep(self, slotIndex)
end

function GameState:resolveHealStep(slotIndex)
    Resolve.resolveHealStep(self, slotIndex)
end

function GameState:resolveAttackStep(slotIndex)
    local players = self.players or {}
    local p1 = players[1]
    local p2 = players[2]

    local slot1 = p1 and p1.boardSlots and p1.boardSlots[slotIndex] or nil
    local slot2 = p2 and p2.boardSlots and p2.boardSlots[slotIndex] or nil

    local card1 = slot1 and slot1.card or nil
    local card2 = slot2 and slot2.card or nil

    local a1 = 0
    if card1 and card1.definition then
        if p1 and p1.applyComboBonus and p1:applyComboBonus(card1) then
            local comboId = card1.definition.combo and card1.definition.combo.after or "combo"
            self:addLog(string.format("Combo! %s follows up %s", card1.name or "Card", comboId))
        end
        a1 = self:getEffectiveStat(1, slotIndex, card1.definition, "attack") or 0
        local multiplier = 1
        if self.specialAttackMultipliers and self.specialAttackMultipliers[1] and self.specialAttackMultipliers[1][slotIndex] then
            multiplier = self.specialAttackMultipliers[1][slotIndex]
        end
        if multiplier ~= 1 then
            a1 = math.floor(a1 * multiplier)
        end
    end

    local a2 = 0
    if card2 and card2.definition then
        if p2 and p2.applyComboBonus and p2:applyComboBonus(card2) then
            local comboId = card2.definition.combo and card2.definition.combo.after or "combo"
            self:addLog(string.format("Combo! %s follows up %s", card2.name or "Card", comboId))
        end
        a2 = self:getEffectiveStat(2, slotIndex, card2.definition, "attack") or 0
        local multiplier = 1
        if self.specialAttackMultipliers and self.specialAttackMultipliers[2] and self.specialAttackMultipliers[2][slotIndex] then
            multiplier = self.specialAttackMultipliers[2][slotIndex]
        end
        if multiplier ~= 1 then
            a2 = math.floor(a2 * multiplier)
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

    local t1 = targetIndexFor(1, slotIndex)
    local t2 = targetIndexFor(2, slotIndex)

    local ctx1 = { attack = a1 }
    local ctx2 = { attack = a2 }

    if card1 then
        self:applyCardEffectsDuringAttack(1, 2, slotIndex, t1, card1, ctx1)
        a1 = ctx1.attack or a1
    end
    if card2 then
        self:applyCardEffectsDuringAttack(2, 1, slotIndex, t2, card2, ctx2)
        a2 = ctx2.attack or a2
    end

    if (not card1 or a1 <= 0) and (not card2 or a2 <= 0) and not (ctx1.skipDamage or ctx2.skipDamage) then
        return
    end

    local blockTargetP2 = (p2 and p2.boardSlots and p2.boardSlots[t1] and p2.boardSlots[t1].block) or 0
    local blockTargetP1 = (p1 and p1.boardSlots and p1.boardSlots[t2] and p1.boardSlots[t2].block) or 0

    if ctx1.ignoreBlock then
        blockTargetP2 = 0
    end
    if ctx2.ignoreBlock then
        blockTargetP1 = 0
    end

    local invP2 = self:isPlayerInvulnerable(2)
    local invP1 = self:isPlayerInvulnerable(1)

    local absorb2 = invP2 and a1 or math.min(blockTargetP2, a1)
    local absorb1 = invP1 and a2 or math.min(blockTargetP1, a2)

    if not invP2 and absorb2 > 0 then
        consumeSlotBlock(p2, t1, absorb2)
    end
    if not invP1 and absorb1 > 0 then
        consumeSlotBlock(p1, t2, absorb1)
    end

    local remainder2 = a1 - absorb2
    local remainder1 = a2 - absorb1

    if invP2 or ctx1.skipDamage then
        remainder2 = 0
    end
    if invP1 or ctx2.skipDamage then
        remainder1 = 0
    end

    if remainder2 > 0 and p2 then
        p2.health = (p2.health or p2.maxHealth or 20) - remainder2
    end
    if remainder1 > 0 and p1 then
        p1.health = (p1.health or p1.maxHealth or 20) - remainder1
    end

    if card1 and (a1 > 0 or ctx1.skipDamage or ctx1.ignoreBlock) then
        local suffix = ""
        if t1 ~= slotIndex then
            suffix = suffix .. string.format(" -> slot %d (feint)", t1)
        end
        if invP2 then
            suffix = suffix .. " (target avoided damage)"
        elseif ctx1.skipDamage then
            suffix = suffix .. " (finisher)"
        end
        self:addLog(string.format("Slot %d: P1 attacks P2 for %d (block %d, dmg %d)%s", slotIndex, a1, absorb2, math.max(0, remainder2), suffix))
    end
    if card2 and (a2 > 0 or ctx2.skipDamage or ctx2.ignoreBlock) then
        local suffix = ""
        if t2 ~= slotIndex then
            suffix = suffix .. string.format(" -> slot %d (feint)", t2)
        end
        if invP1 then
            suffix = suffix .. " (target avoided damage)"
        elseif ctx2.skipDamage then
            suffix = suffix .. " (finisher)"
        end
        self:addLog(string.format("Slot %d: P2 attacks P1 for %d (block %d, dmg %d)%s", slotIndex, a2, absorb1, math.max(0, remainder1), suffix))
    end
end

function GameState:resolveCleanupStep(slotIndex)
    Resolve.resolveCleanupStep(self, slotIndex)

    local roundLoser = nil
    for idx, player in ipairs(self.players or {}) do
        if player.health and player.health < 0 then
            player.health = 0
        end
        if player.health == 0 then
            roundLoser = idx
        end
    end

    local function startNewRound()
        print("[DEBUG] startNewRound called: roundIndex=" .. tostring(self.roundIndex) .. " phase=" .. tostring(self.phase))
        for _, player in ipairs(self.players or {}) do
            player.health = player.maxHealth or 20
        end
        self:initRoundState()
        local hasShared = self.hasSharedDeck
        if hasShared == nil then hasShared = false end
        self.hasSharedDeck = hasShared
        self:initUiState(hasShared)
        self:initAttachments()
        self:resetRoundFlags()
        self:activateRoundStatuses()
        self:initResolveState()
        if self.dealStartingHandsFromPlayerDecks then
            self:dealStartingHandsFromPlayerDecks()
        end
        self.phase = "play"
        self:ensureCurrentPlayerReady()
        self:updateCardVisibility()
        self:refreshLayoutPositions()
        print("[DEBUG] startNewRound finished: roundIndex=" .. tostring(self.roundIndex) .. " phase=" .. tostring(self.phase))
    end

    if roundLoser then
        local winner = (roundLoser == 1) and 2 or 1
        self.roundWins[winner] = (self.roundWins[winner] or 0) + 1
        self:addLog(string.format("Player %d wins the round! (Score: %d-%d)", winner, self.roundWins[1], self.roundWins[2]))
        if self.logger then
            self.logger:log_event("round_win", { winner = winner, score = { self.roundWins[1], self.roundWins[2] } })
        end
        local HudRenderer = require "src.renderers.hud_renderer"
        HudRenderer.showRoundOver(winner, { self.roundWins[1], self.roundWins[2] }, function()
            if self.roundWins[winner] >= 2 then
                self.matchWinner = winner
                self:addLog(string.format("Player %d wins the match!", winner))
                if self.logger then
                    self.logger:log_event("match_win", { winner = winner })
                end
            else
                startNewRound()
            end
        end)
    else
        -- No round winner, but resolve finished: start new round anyway
        startNewRound()
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
    self:handleCardPlayed(player, card, slotIndex)

    if id then
        local limit = self.maxBoardCards or player.maxBoardCards or #(player.boardSlots or {})
        print(string.format(
            "Player %d placed a card in slot %d. Played %d/%d cards.",
            id,
            slotIndex,
            self.playedCount[id],
            limit
        ))
        if self.logger then
            self.logger:log_event("card_placed", {
                player = id,
                card = card.name or "unknown",
                slot = slotIndex
            })
        end
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

function GameState:getHandMetrics(player)
    return Layout.getHandMetrics(self, player)
end

function GameState:getLayout()
    return Layout.getLayout(self)
end

function GameState:previewIncomingDamage(playerIndex)
    self:computeActiveModifiers()
    return Resolve.previewIncomingDamage(self, playerIndex)
end

function GameState:previewIncomingHeal(playerIndex)
    self:computeActiveModifiers()
    return Resolve.previewIncomingHeal(self, playerIndex)
end

function GameState:getCurrentPlayer()
    return self.players and self.players[self.currentPlayer]
end

function GameState:getCardDimensions()
    return Layout.getCardDimensions(self)
end

function GameState:discardCard(card)
    return Actions.discardCard(self, card)
end

function GameState:playCardFromHand(card, slotIndex)
    return Actions.playCardFromHand(self, card, slotIndex)
end

function GameState:registerTurnAction()
    self.turnActionCount = (self.turnActionCount or 0) + 1
end

function GameState:nextPlayer()
    local nextIndex = self:findNextPlayerIndex()
    if not nextIndex then
        return
    end

    self.currentPlayer = nextIndex
    self:ensureCurrentPlayerReady()
    self:updateCardVisibility()
end

return GameState
