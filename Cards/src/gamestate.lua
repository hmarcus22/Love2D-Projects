local Card = require "src.card"
local Deck = require "src.deck"
local Actions = require "src.actions"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"
local Layout = require "src.game_layout"
local PlayerManager = require "src.player_manager"
local Initialiser = require "src.game_initialiser"
local BoardRenderer = require "src.renderers.board_renderer"
local HudRenderer = require "src.renderers.hud_renderer"
local ResolveRenderer = require "src.renderers.resolve_renderer"
local Resolve = require "src.resolve"
local CardRenderer = require "src.card_renderer"
local RoundManager = require "src.logic.round_manager"
local DEFAULT_BACKGROUND_COLOR = { 0.2, 0.5, 0.2 }


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
        -- Ultimate-style AOE: apply once and skip normal per-target damage
        if card.definition and card.definition.ultimate then
            local value = context.attack or card.definition.attack or 0
            self:performAoeAttack(attackerIdx, value)
            context.skipDamage = true
        end
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
            gs:drawCardToPlayer(playerIndex)
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

    gs.roundWins = { [1] = 0, [2] = 0 }
    gs.matchWinner = nil
    gs.logger = require("src.game_logger")()

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

    local layout = self:getLayout()
    local screenW = Viewport.getWidth()

    BoardRenderer.draw(self, layout)

    if self.deckStack and self.deckStack.draw then
        self.deckStack:draw()
    end
    if self.discardStack and self.discardStack.draw then
        self.discardStack:draw()
    end

    for index, player in ipairs(self.players or {}) do
        local isCurrent = (index == self.currentPlayer)
        player:drawHand(isCurrent, self)
    end

    ResolveRenderer.draw(self, layout, screenW)

    if self.draggingCard then
        local card = self.draggingCard
        if not card.w or not card.h then
            local cw, ch = self:getCardDimensions()
            card.w = card.w or cw
            card.h = card.h or ch
        end
        CardRenderer.draw(card)
    end

    if HudRenderer.draw then
        HudRenderer.draw(self, layout, screenW)
    end


end
function GameState:getPassButtonRect()
    local layout = self:getLayout()
    local w = layout.passButtonW or (Config.ui and Config.ui.buttonW) or 120
    local h = layout.passButtonH or (Config.ui and Config.ui.buttonH) or 32
    local x = layout.passButtonX
    if not x then
        x = math.floor((Viewport.getWidth() - w) / 2)
    end
    local y = layout.passButtonY
    if not y then
        local bottomMargin = layout.handBottomMargin or 20
        local handBottom = (self:getHandY() or (Viewport.getHeight() - (layout.cardH or 150) - bottomMargin)) + (layout.cardH or 150)
        local maxY = Viewport.getHeight() - h - math.max(12, bottomMargin * 0.5)
        y = math.min(maxY, handBottom + 16)
    end
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
                if Config and Config.debug then
                    print(string.format("[DEBUG] Performing resolve step %d/%d: %s slot %d", self.resolveIndex, #self.resolveQueue, step.kind, step.slot))
                end
                Resolve.performResolveStep(self, step)
            end
            -- Update current step after performing
            if self.resolveIndex < #self.resolveQueue then
                self.resolveCurrentStep = self.resolveQueue[self.resolveIndex + 1]
            else
                self.resolveCurrentStep = nil
            end
        end

        if self.resolveIndex >= #self.resolveQueue then
            self:finishResolvePhase()
        end
    end
end

function GameState:updateCardVisibility()
    for i, player in ipairs(self.players or {}) do
        local isCurrent = (i == self.currentPlayer)
        for _, slot in ipairs(player.slots or {}) do
            if slot.card then
                slot.card.faceUp = isCurrent
            end
        end
        for _, slot in ipairs(player.boardSlots or {}) do
            if slot.card then
                slot.card.faceUp = true
            end
        end
    end
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


function GameState:hasBoardCapacity(player)
    if not player then
        return false
    end
    local limit = self.maxBoardCards or player.maxBoardCards or #(player.boardSlots or {})
    local played = self.playedCount and self.playedCount[player.id] or 0
    return played < limit
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
        if Config and Config.debug then print(string.format(
            "Player %d placed a card in slot %d. Played %d/%d cards.",
            id,
            slotIndex,
            self.playedCount[id],
            limit
        )) end
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

function GameState:maybeFinishPlayPhase()
    if self.phase ~= 'play' then
        return
    end

    if self.hasPendingRetarget and self:hasPendingRetarget() then
        return
    end

    local players = self.players or {}
    if #players == 0 then
        return
    end

    local allFilled = true
    for _, player in ipairs(players) do
        if self:hasBoardCapacity(player) then
            allFilled = false
            break
        end
    end

    if not allFilled then
        return
    end

    if self.addLog then
        self:addLog('All slots filled. Resolving.')
    end
    if self.logger then
        self.logger:log_event('resolve_start', { reason = 'board_full' })
    end
    if self.startResolve then
        self:startResolve()
    end
end
function GameState:findNextPlayerIndex()
    local players = self.players or {}
    local count = #players
    if count == 0 then
        return nil
    end

    local originalIndex = self.currentPlayer or 1
    local candidate = originalIndex
    for _ = 1, count do
        candidate = (candidate % count) + 1
        if candidate ~= originalIndex and self:hasBoardCapacity(players[candidate]) then
            return candidate
        end
    end

    return (originalIndex % count) + 1
end
function GameState:drawCardsForTurnStart()
    if self.phase ~= 'play' then
        return
    end

    if not self.currentPlayer then
        self.currentPlayer = self.roundStartPlayer or 1
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
    for _ = 1, total do
        self:drawCardToPlayer(self.currentPlayer)
    end
end
function GameState:getBoardSlotPosition(playerIndex, slotIndex)
    local startX, _, layout = Layout.getBoardMetrics(self, playerIndex)
    local spacing = layout.slotSpacing or 0
    local x = startX + (slotIndex - 1) * spacing
    local y = Layout.getBoardY(self, playerIndex)
    return x, y
end


function GameState:getHandSlotPosition(slotIndex, player)
    local startX, _, layout, _, spacing = self:getHandMetrics(player)
    local step = spacing or layout.slotSpacing
    local x = startX + (slotIndex - 1) * step
    local y = self:getHandY()
    return x, y
end
function GameState:getHandMetrics(player)
    return Layout.getHandMetrics(self, player)
end

function GameState:getHandY()
    return Layout.getHandY(self)
end
function GameState:getLayout()
    return Layout.getLayout(self)
end

function GameState:addLog(message)
    if not message then
        return
    end

    self.resolveLog = self.resolveLog or {}
    table.insert(self.resolveLog, message)

    local maxEntries = (self.maxResolveLogLines or 14) * 4
    if maxEntries > 0 and #self.resolveLog > maxEntries then
        local removeCount = #self.resolveLog - maxEntries
        for _ = 1, removeCount do
            table.remove(self.resolveLog, 1)
        end
    end

    print(string.format("[LOG] %s", message))
end

function GameState:finishResolvePhase()
    return RoundManager.finishResolve(self)

end

function GameState:computeActiveModifiers()
    if Resolve and Resolve.computeActiveModifiers then
        self.activeMods = Resolve.computeActiveModifiers(self)
    else
        self.activeMods = nil
    end
    return self.activeMods
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

function GameState:getEffectiveCardCost(player, card)
    local base = card and card.definition and (card.definition.cost or 0) or 0
    -- Favored tag discount (simple affinity system)
    if player and player.isCardFavored and card and card.definition then
        local ok = player:isCardFavored(card.definition)
        if ok then base = base - 1 end
    end
    if base < 0 then base = 0 end
    -- TODO: apply attachments/auras for cost if/when designed
    return base
end
function GameState:playCardFromHand(card, slotIndex)
    return Actions.playCardFromHand(self, card, slotIndex)
end

function GameState:passTurn()
    return Actions.passTurn(self)
end

function GameState:advanceTurn()
    return Actions.advanceTurn(self)
end

function GameState:playModifierOnSlot(card, targetPlayerIndex, slotIndex, retargetOffset)
    return Actions.playModifierOnSlot(self, card, targetPlayerIndex, slotIndex, retargetOffset)
end

function GameState:drawCardToPlayer(playerIndex)
    -- Shared deck path
    if self.hasSharedDeck ~= false and self.deck then
        local player = self.players and self.players[playerIndex]
        if not player then return nil end
        local card = self.deck and self.deck:draw() or nil
        if not card then return nil end
        card.owner = player
        table.insert(player.hand, card)
        if self.addLog then
            self:addLog(string.format("P%d draws %s", player.id or playerIndex, card.name or "card"))
        end
        if self.logger then
            self.logger:log_event("draw", { player = player.id or playerIndex, card = card.name or "card" })
        end
        return card
    end

    -- Per-player deck path
    local player = self.players and self.players[playerIndex]
    if player and player.drawCard then
        local card = player:drawCard()
        if card and self.logger then
            self.logger:log_event("draw", { player = player.id or playerIndex, card = card.name or card.id or "card" })
        end
        return card
    end

    return nil
end

function GameState:startResolve()
    if Resolve and Resolve.startResolve then
        return Resolve.startResolve(self)
    end
end


function GameState:registerTurnAction()
    self.turnActionCount = (self.turnActionCount or 0) + 1
end

function GameState:nextPlayer()
    self.turnActionCount = 0

    local nextIndex = self:findNextPlayerIndex()
    if not nextIndex then
        return
    end

    self.currentPlayer = nextIndex
    self:ensureCurrentPlayerReady()
    self:updateCardVisibility()
end

return GameState
