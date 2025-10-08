local Card = require "src.card"
local Deck = require "src.deck"
local Actions = require "src.logic.actions"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"
local Layout = require "src.game_layout"
local PlayerManager = require "src.logic.player_manager"
local Initialiser = require "src.logic.game_initialiser"
local BoardRenderer = require "src.renderers.board_renderer"
local HudRenderer = require "src.renderers.hud_renderer"
local ResolveRenderer = require "src.renderers.resolve_renderer"
local Resolve = require "src.logic.resolve"
local AnimationManager = require "src.animation_manager"
local CardRenderer = require "src.card_renderer"
local RoundManager = require "src.logic.round_manager"
local DEFAULT_BACKGROUND_COLOR = { 0.2, 0.5, 0.2 }

--[[
GAMESTATE SPECIAL FLAGS:

Animation Lab Testing Flags:
- gs.isAnimationLab = true       -- Enables cross-player combo detection
- gs.suppressPlayerAdvance = true -- Prevents automatic nextPlayer() calls

These flags allow the animation lab to test card sequences and combos
while maintaining game rule integrity in normal gameplay.
--]]

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
            -- Note: prevCardId is NOT reset here - it should persist during a fight for combo detection
            -- Only reset lastCardId and roundPunchCount between rounds
            player.lastCardId = nil
            player.roundPunchCount = 0
        end
    end
    -- Clear any active board effects (knockback animations)
    local BoardEffects = require 'src.effects.board_effects'
    BoardEffects.reset()
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
    
    -- Clear hover and combo state when card is played to prevent highlights from persisting
    card.handHoverTarget = 0
    card.handHoverAmount = 0
    print("[PLAY] Clearing comboGlow for played card:", card.definition and card.definition.name or "unknown")
    card.comboGlow = false
    
    -- Set prevCardId to the card that was just played (for combo detection)
    print("[PLAY] Player", player.id, "Setting prevCardId from", player.prevCardId, "to", card.id, "for card:", card.definition and card.definition.name or "unknown")
    player.prevCardId = card.id
    print("[PLAY] Player", player.id, "prevCardId confirmed set to:", player.prevCardId)
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
    -- Prevent double application if already triggered earlier (e.g., early trigger for smoke bomb)
    if effect and card.effectsTriggered and card.effectsTriggered[effect] then
        return
    end
    if effect == "double_attack_one_round" then
        self.specialAttackMultipliers = self.specialAttackMultipliers or {}
        self.specialAttackMultipliers[player.id] = self.specialAttackMultipliers[player.id] or {}
        self.specialAttackMultipliers[player.id][slotIndex] = 2
        self:addLog(string.format("P%d powers up %s for this round!", player.id or 0, card.name or "card"))
    elseif effect == "avoid_all_attacks" then
        -- Immediate: smoke bomb style invulnerability for the rest of the round
        if not self:isPlayerInvulnerable(player.id) then
            self.invulnerablePlayers[player.id] = true
            self:addLog(string.format("P%d uses %s and becomes untargetable this round!", player.id or 0, card.name or "smoke bomb"))
        end
        card.effectsTriggered = card.effectsTriggered or {}
        card.effectsTriggered[effect] = true
    elseif effect == "knock_off_board" then
        -- Check if this card has knockback animation - if so, defer the removal
        local AnimSpecs = require 'src.animation_specs'
        local spec = AnimSpecs.getCardSpec(card.id)
        local hasKnockback = spec and spec.knockback and spec.knockback.enabled
        
        if hasKnockback then
            -- Defer removal until knockback completes - BoardEffects will handle it
            self:addLog(string.format("Body Slam crashes through the opposition!"))
            return -- Don't remove cards now, let knockback animation handle it
        end
        
        -- Immediate: knock the opposing card(s) off the board right away (original logic)
        local applied = false
        if card.id == 'body_slam' then
            -- Enhanced behavior: remove ALL opposing board cards (board wipe)
            local opponentIndex = (player.id == 1) and 2 or 1
            local opponent = self.players and self.players[opponentIndex]
            if opponent and opponent.boardSlots then
                for i, oslot in ipairs(opponent.boardSlots) do
                    if oslot.card then
                        if self:knockOffBoard(opponentIndex, i, player.id) then
                            applied = true
                        end
                    end
                end
            end
        end
        if not applied then
            -- Fallback to original single-target logic (mirrored lane / retarget)
            local Targeting = require "src.logic.targeting"
            local targets = Targeting.collectAttackTargets(self, player.id, slotIndex) or {}
            for _, t in ipairs(targets) do
                if self:knockOffBoard(t.player, t.slot, player.id) then
                    applied = true
                end
            end
        end
        if applied then
            card.effectsTriggered = card.effectsTriggered or {}
            card.effectsTriggered[effect] = true
            self:addLog(string.format("%s crashes through the opposition!", card.name or "Body Slam"))
        end
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
    local attacker = self.players and self.players[attackerIdx] or nil
    if not enemy or not attacker then
        return
    end
    local hits = 0
    local totalCounterDamage = 0
    
    if enemy.boardSlots then
        for _, slot in ipairs(enemy.boardSlots) do
            if slot.card then
                hits = hits + 1
                
                -- CHECK FOR COUNTER RETALIATION: Each counter card hit by AOE retaliates
                if slot.card.definition and slot.card.definition.effect == "counter_retaliate" then
                    local counterDamage = slot.card.definition.counterDamage or 0
                    totalCounterDamage = totalCounterDamage + counterDamage
                    
                    if counterDamage > 0 then
                        self:addLog(string.format(
                            "Counter: %s retaliates for %d damage!",
                            slot.card.name or "counter",
                            counterDamage
                        ))
                    end
                end
            end
        end
    end
    if hits == 0 then
        hits = 1
    end
    local total = attackValue * hits
    local before = enemy.health or enemy.maxHealth or 20
    enemy.health = math.max(0, before - total)
    
    -- Apply total counter damage to attacker
    if totalCounterDamage > 0 then
        local beforeCounter = attacker.health or attacker.maxHealth or 20
        attacker.health = math.max(0, beforeCounter - totalCounterDamage)
        self:addLog(string.format("Total counter damage: %d", totalCounterDamage))
    end
    
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

-- Effect hooks extracted to src/logic/effects.lua

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
    gs.animations = AnimationManager.new()
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
    gs.animations = AnimationManager.new()
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
        if card.dragCursorX and card.dragCursorY then
            love.graphics.setColor(0.95, 0.8, 0.2, 0.85)
            -- Anchor arrow start to the card's current (pressed) visual position, not the original pick-up center
            local sx = (card.x or 0) + (card.w or 0)/2
            local sy = (card.y or 0) + (card.h or 0)/2
            local ex, ey = card.dragCursorX, card.dragCursorY
            local dx, dy = ex - sx, ey - sy
            local dist = math.sqrt(dx*dx + dy*dy)
            local thick = math.min(16, math.max(3, dist * 0.04))
            love.graphics.setLineWidth(thick)
            love.graphics.line(sx, sy, ex, ey)
            love.graphics.setLineWidth(1)
            local angle = math.atan2(dy, dx)
            local ah = 22
            local aw = 14
            local baseX = ex - math.cos(angle) * ah
            local baseY = ey - math.sin(angle) * ah
            local leftAngle = angle + 2.4
            local rightAngle = angle - 2.4
            local lx = baseX + math.cos(leftAngle) * aw
            local ly = baseY + math.sin(leftAngle) * aw
            local rx = baseX + math.cos(rightAngle) * aw
            local ry = baseY + math.sin(rightAngle) * aw
            love.graphics.polygon("fill", ex, ey, lx, ly, rx, ry)
            love.graphics.setColor(1,1,1,1)
        end
    end

    if HudRenderer.draw then
        HudRenderer.draw(self, layout, screenW)
    end

    if self.animations and self.animations.draw then
        local ImpactFX = require 'src.impact_fx'
        local pushed = ImpactFX.applyShakeTransform(self)
        self.animations:draw()
        ImpactFX.drawDust(self)
        if pushed then love.graphics.pop() end
    end
    -- TODO: move inline FX drawing to ImpactFX module (refactor pending)

    -- Draw debug overlays
    local CardRenderer = require "src.card_renderer"
    CardRenderer.drawDebugInfo()

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
    -- Update hand hover tweening for players during play phase
    if self.phase == 'play' and self.players then
        for i, p in ipairs(self.players) do
            if p.updateHandHover then 
                -- Only update combo states for the current player
                local isCurrentPlayer = (self.currentPlayer == i)
                p:updateHandHover(self, dt, isCurrentPlayer)
            end
        end
    end
    if self.phase == "resolve" and self.resolveQueue and self.resolveIndex then
        -- Pause resolve while board effects are active
        local BoardEffects = require 'src.effects.board_effects'
        if BoardEffects.isActive() then
            print("[GameState] Pausing resolve phase while board effects are active")
            -- Don't advance resolve timer while knockback animations are running
        else
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
    -- Impact FX update handled centrally
    if self.animations then self.animations:update(dt) end
    -- Update impact FX (shake, dust) lifecycle
    local ImpactFX = require 'src.impact_fx'
    ImpactFX.update(self, dt)
    -- Update board effects (knockback animations)
    local BoardEffects = require 'src.effects.board_effects'
    BoardEffects.update(dt)
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
-- Core placement logic: places card in slot, triggers on-play effects, logs & counts, BUT does NOT advance turn
function GameState:placeCardWithoutAdvancing(player, card, slotIndex)
    if not player or not card then return end
    local slot = player.boardSlots and player.boardSlots[slotIndex]
    if not slot or slot.card ~= card then
        -- Allow caller to pass card not yet in slot (animated path). Place it.
        if slot and slot.card == nil then
            slot.card = card
        end
    end
    -- Hand state: card leaves hand when animation started, ensure it's not still referenced
    card.slotIndex = nil
    card.zone = 'board'
    card.faceUp = true
    slot._incoming = nil
    -- Track played count
    local id = player.id
    self.playedCount[id] = (self.playedCount[id] or 0) + 1
    -- Register action now so phase logic sees it even if turn advance is deferred
    self:registerTurnAction()
    -- Trigger on-play effects unless deferred by timing metadata
    local timing = card.definition and card.definition.effectTiming
    if timing == 'on_impact' then
        -- Defer: mark for later processing at impact moment
        card._deferPlayEffects = { playerId = player.id, slotIndex = slotIndex }
    else
        self:handleCardPlayed(player, card, slotIndex)
    end
    -- Log event without advancing turn
    if self.logger then
        self.logger:log_event("card_placed", { player = id, card = card.name or "unknown", slot = slotIndex })
    end
end
function GameState:onCardPlaced(player, card, slotIndex)
    -- Backwards-compatible wrapper (instant placement path)
    self:placeCardWithoutAdvancing(player, card, slotIndex)
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
    local def = card and card.definition or nil
    local base = def and (def.cost or 0) or 0
    local cost = base

    -- Favored tag discount (simple affinity system)
    if player and player.isCardFavored and def then
        if player:isCardFavored(def) then
            cost = cost - 1
        end
    end

    -- Never below 0; and if the card has a positive base cost, enforce minimum 1
    if cost < 0 then cost = 0 end
    if base > 0 and cost < 1 then cost = 1 end

    -- TODO: apply attachments/auras for cost if/when designed
    return cost
end
function GameState:playCardFromHand(card, slotIndex)
    local player = card and card.owner
    if not player then return false end
    local slot = player.boardSlots and player.boardSlots[slotIndex]
    if not slot or slot.card then return false end
    local useFlight = (Config.ui and Config.ui.cardFlightEnabled) and self.animations ~= nil
    if not useFlight then
        return Actions.playCardFromHand(self, card, slotIndex)
    end
    -- Use shared prevalidation (applies energy, combo, variance, and requirements)
    local ok = select(1, Actions.prevalidatePlayCard(self, card, slotIndex))
    if not ok then return false end
    -- Mark slot reserved so other attempts during flight fail fast
    slot._incoming = true
    -- Temporarily remove from hand visually
    player.slots[card.slotIndex].card = nil
    player:compactHand(self)
    
    -- Build turn advancement callback
    local function queueAdvance()
        self.lastActionWasPass = false
        self:nextPlayer()
        self:maybeFinishPlayPhase()
    end
    
    -- Use AnimationBuilder to create animation sequence
    local AnimationBuilder = require 'src.logic.animation_builder'
    local animations = AnimationBuilder.buildCardPlaySequence(self, card, slotIndex, queueAdvance)
    
    -- Queue all animations
    for _, anim in ipairs(animations) do
        self.animations:add(anim)
    end
    return true
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
