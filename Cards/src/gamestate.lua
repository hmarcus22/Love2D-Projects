local Card = require "src.card"
local Deck = require "src.deck"
local Player = require "src.player"
local Viewport = require "src.viewport"
local Config = require "src.config"

local function resolveLayoutConfig()
    local layout = Config.layout or {}
    return {
        slotSpacing = layout.slotSpacing or 110,
        cardW = layout.cardW or 100,
        cardH = layout.cardH or 150,
        handBottomMargin = layout.handBottomMargin or 20,
        boardTopMargin = layout.boardTopMargin or 80,
        boardHandGap = layout.boardHandGap or 30,
        sideGap = layout.sideGap or 30,
    }
end

local GameState = {}
GameState.__index = GameState

function GameState:buildLayoutCache()
    self.layoutCache = resolveLayoutConfig()
    return self.layoutCache
end

function GameState:getLayout()
    return self.layoutCache or self:buildLayoutCache()
end

function GameState:getCardDimensions()
    local layout = self:getLayout()
    return layout.cardW, layout.cardH
end

function GameState:getHandMetrics(player)
    local layout = self:getLayout()
    local maxHand = (player and player.maxHandSize) or (Config.rules.maxHandSize or 5)
    maxHand = math.max(1, maxHand)
    local width = layout.cardW + layout.slotSpacing * (maxHand - 1)
    local startX = math.floor((Viewport.getWidth() - width) / 2)
    return startX, width, layout, maxHand
end

function GameState:getHandY()
    local layout = self:getLayout()
    return Viewport.getHeight() - layout.cardH - layout.handBottomMargin
end

function GameState:getDeckPosition()
    local currentPlayer = self.players and self.players[self.currentPlayer]
    local startX, _, layout = self:getHandMetrics(currentPlayer)
    local x = startX - layout.cardW - layout.sideGap
    if x < layout.sideGap then
        x = layout.sideGap
    end
    return x, self:getHandY()
end

function GameState:getDiscardPosition()
    local currentPlayer = self.players and self.players[self.currentPlayer]
    local startX, width, layout = self:getHandMetrics(currentPlayer)
    local x = startX + width + layout.sideGap
    local maxX = Viewport.getWidth() - layout.cardW - layout.sideGap
    if x > maxX then
        x = maxX
    end
    return x, self:getHandY()
end

function GameState:getDeckRect()
    local x, y = self:getDeckPosition()
    local layout = self:getLayout()
    return x, y, layout.cardW, layout.cardH
end

function GameState:getBoardMetrics(playerIndex)
    local layout = self:getLayout()
    local player = self.players and self.players[playerIndex]
    local count = (player and player.maxBoardCards) or self.maxBoardCards or (Config.rules.maxBoardCards or 3)
    count = math.max(1, count)
    local width = layout.cardW + layout.slotSpacing * (count - 1)
    local startX = math.floor((Viewport.getWidth() - width) / 2)
    return startX, width, layout, count
end

function GameState:getBoardY(playerIndex)
    local layout = self:getLayout()
    if playerIndex == self.currentPlayer then
        return self:getHandY() - layout.cardH - layout.boardHandGap
    end
    return layout.boardTopMargin
end

function GameState:refreshLayoutPositions()
    local layout = self:getLayout()
    if self.deckStack then
        local dx, dy = self:getDeckPosition()
        self.deckStack.x, self.deckStack.y = dx, dy
        self.deckStack.w, self.deckStack.h = layout.cardW, layout.cardH
    end
    if self.discardStack then
        local sx, sy = self:getDiscardPosition()
        self.discardStack.x, self.discardStack.y = sx, sy
        self.discardStack.w, self.discardStack.h = layout.cardW, layout.cardH
    end
    if Config.rules.showDiscardPile and self.discardPile and #self.discardPile > 0 and self.discardStack then
        local top = self.discardPile[#self.discardPile]
        top.x, top.y = self.discardStack.x, self.discardStack.y
        top.w, top.h = layout.cardW, layout.cardH
    end
end
function GameState:initPlayers(players)
    self.players = players
    self.playedCount = {}
    for _, player in ipairs(players) do
        assert(player.id, "Player missing id!")
        self.playedCount[player.id] = 0
    end
    local first = players[1]
    self.maxBoardCards = (first and first.maxBoardCards) or (Config.rules.maxBoardCards or 3)
end

function GameState:initTurnOrder()
    self.roundStartPlayer = love.math.random(#self.players)
    self.microStarter = self.roundStartPlayer
    self.currentPlayer = self.roundStartPlayer
end

function GameState:initRoundState()
    self.roundIndex = 0
    self.phase = "play"
    self.playsInRound = 0
end

function GameState:initUiState(hasSharedDeck)
    self.allCards = {}
    self.draggingCard = nil

    if hasSharedDeck then
        self.deckStack = Card(-1, "Deck", 0, 0)
        self.deckStack.faceUp = false
    else
        self.deckStack = nil
    end

    self.discardStack = Card(-2, "Discard", 0, 0)
    self.discardStack.faceUp = false
    self.discardPile = {}
    self.highlightDiscard = false
    self.highlightPass = false
end

function GameState:initAttachments()
    self.attachments = {}
    for index = 1, #self.players do
        self.attachments[index] = {}
    end
end

function GameState:initResolveState()
    self.resolveQueue = {}
    self.resolveIndex = 0
    self.resolveTimer = 0
    self.resolveStepDuration = 0.5
    self.resolveCurrentStep = nil

    self.resolveLog = {}
    self.maxResolveLogLines = 14
    table.insert(self.resolveLog, string.format("Coin toss: P%d starts", self.roundStartPlayer))
end

function GameState:applyInitialEnergy()
    if Config.rules.energyEnabled ~= false then
        local startE = Config.rules.energyStart or 3
        for _, player in ipairs(self.players) do
            player.energy = startE
        end
    end
end

function GameState:dealStartingHandsFromPlayerDecks()
    for _, player in ipairs(self.players) do
        local startN = (Config.rules.startingHand or player.maxHandSize or 3)
        for _ = 1, startN do
            local card = table.remove(player.deck)
            if card then
                player:addCard(card)
                table.insert(self.allCards, card)
            end
        end
    end
end
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
local function summarizeModifierEffects(mods)
    local direction, attack, block, heal = nil, 0, 0, 0
    for _, mod in ipairs(mods) do
        if mod.retargetOffset then direction = mod.retargetOffset end
        attack = attack + (mod.attack or 0)
        block = block + (mod.block or 0)
        heal = heal + (mod.heal or 0)
    end
    return direction, attack, block, heal
end

local function drawModifierDecorations(mods, slotX, slotY, cardW, cardH)
    local direction, attack, block, heal = summarizeModifierEffects(mods)
    if (attack ~= 0) or (block ~= 0) or (heal ~= 0) or direction then
        love.graphics.setColor(1, 1, 0, 0.6)
        love.graphics.rectangle("line", slotX - 2, slotY - 2, cardW + 4, cardH + 4, 8, 8)
    end

    if direction then
        love.graphics.setColor(0.9, 0.2, 0.2, 0.8)
        local triX = slotX + (direction < 0 and math.floor(cardW * 0.1) or (cardW - math.floor(cardW * 0.1)))
        local triY = slotY + math.floor(cardH * 0.08)
        if direction < 0 then
            love.graphics.polygon("fill", triX, triY, triX + 10, triY - 6, triX + 10, triY + 6)
        else
            love.graphics.polygon("fill", triX, triY, triX - 10, triY - 6, triX - 10, triY + 6)
        end
    end

    local function drawBadge(x, y, bg, text)
        love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] or 0.9)
        love.graphics.rectangle("fill", x - 1, y - 1, 34, 16, 4, 4)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", x - 1, y - 1, 34, 16, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(text, x, y + 2, 32, "center")
    end

    local badgeX = slotX + 6
    local badgeY = slotY + 28
    if attack ~= 0 then
        local txt = (attack > 0 and "+" .. attack or tostring(attack)) .. " A"
        drawBadge(badgeX, badgeY, {0.8, 0.2, 0.2, 0.9}, txt)
        badgeX = badgeX + 36
    end
    if block ~= 0 then
        local txt = (block > 0 and "+" .. block or tostring(block)) .. " B"
        drawBadge(badgeX, badgeY, {0.2, 0.4, 0.8, 0.9}, txt)
        badgeX = badgeX + 36
    end
    if heal ~= 0 then
        local txt = (heal > 0 and "+" .. heal or tostring(heal)) .. " H"
        drawBadge(badgeX, badgeY, {0.2, 0.8, 0.2, 0.9}, txt)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function GameState:drawTurnBanner(screenW)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Player %d's turn", self.currentPlayer), 0, 20, screenW, "center")

    local p1 = self.players[1]
    local p2 = self.players[2]
    if p1 then
        love.graphics.printf(string.format("P1 HP: %d  Block: %d  Energy: %d", p1.health or 0, p1.block or 0, p1.energy or 0), 0, 50, screenW, "center")
    end
    if p2 then
        love.graphics.printf(string.format("P2 HP: %d  Block: %d  Energy: %d", p2.health or 0, p2.block or 0, p2.energy or 0), 0, 70, screenW, "center")
    end
end

function GameState:drawBoardSlots(layout)
    local cardW, cardH = layout.cardW, layout.cardH
    for playerIndex, player in ipairs(self.players) do
        for slotIndex, slot in ipairs(player.boardSlots) do
            local slotX, slotY = self:getBoardSlotPosition(playerIndex, slotIndex)
            love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
            love.graphics.rectangle("line", slotX, slotY, cardW, cardH, 8, 8)

            if slot.card then
                slot.card.x = slotX
                slot.card.y = slotY
                slot.card:draw()

                local mods = self.attachments and self.attachments[playerIndex] and self.attachments[playerIndex][slotIndex]
                if mods and #mods > 0 then
                    drawModifierDecorations(mods, slotX, slotY, cardW, cardH)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function GameState:drawDiscardArea()
    if not Config.rules.showDiscardPile then return end
    if self.discardPile and #self.discardPile > 0 then
        self.discardPile[#self.discardPile]:draw()
    elseif self.discardStack then
        self.discardStack:draw()
    end
end

function GameState:drawCurrentHand()
    local current = self:getCurrentPlayer()
    if current then
        current:drawHand(true, self)
    end
end

function GameState:drawDeckArea()
    local current = self:getCurrentPlayer()
    if not (current and current.deck and self.deckStack) then return end

    local deckX, deckY, deckW, deckH = self:getDeckRect()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", deckX, deckY, deckW, deckH, 8, 8)
    love.graphics.printf("Deck\n" .. #current.deck, deckX, deckY + math.floor(deckH * 0.33), deckW, "center")

    if Config.rules.energyEnabled ~= false then
        local energy = current.energy or 0
        local cx = deckX + math.floor(deckW * 0.2)
        local cy = deckY + math.floor(deckH * 0.2)
        love.graphics.setColor(0.95, 0.9, 0.2, 1)
        love.graphics.circle("fill", cx, cy, 16)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", cx, cy, 16)
        love.graphics.printf(tostring(energy), cx - 12, cy - 6, 24, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function GameState:drawPassButton()
    local bx, by, bw, bh = self:getPassButtonRect()
    if self.phase == "play" then
        if self.highlightPass then
            love.graphics.setColor(0.95, 0.95, 0.95, 1)
        else
            love.graphics.setColor(0.85, 0.85, 0.85, 1)
        end
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
    end
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.printf("Pass", bx, by + math.floor((bh - 16) / 2), bw, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function GameState:drawDraggingCard()
    if self.draggingCard then
        self.draggingCard:draw()
    end
end

function GameState:drawResolveOverlay(layout, screenW)
    if self.phase ~= "resolve" or not self.resolveCurrentStep then return end

    local cardW, cardH = layout.cardW, layout.cardH
    local step = self.resolveCurrentStep
    local colors = {
        block = {0.2, 0.4, 0.9, 0.35},
        heal = {0.2, 0.8, 0.2, 0.35},
        attack = {0.9, 0.2, 0.2, 0.35},
        cleanup = {0.6, 0.6, 0.6, 0.3},
    }
    local color = colors[step.kind] or {1, 1, 0, 0.3}

    if step.kind ~= "attack" then
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        for playerIndex = 1, #self.players do
            local sx, sy = self:getBoardSlotPosition(playerIndex, step.slot)
            love.graphics.rectangle("fill", sx, sy, cardW, cardH, 8, 8)
        end
    else
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        for playerIndex = 1, #self.players do
            local sx, sy = self:getBoardSlotPosition(playerIndex, step.slot)
            love.graphics.rectangle("fill", sx, sy, cardW, cardH, 8, 8)

            local mods = self.activeMods and self.activeMods[playerIndex] and self.activeMods[playerIndex].perSlot and self.activeMods[playerIndex].perSlot[step.slot]
            local offset = mods and mods.retargetOffset or 0
            local targetSlot = step.slot + offset
            local maxSlots = self.maxBoardCards or (#self.players[playerIndex].boardSlots)
            if targetSlot < 1 or targetSlot > maxSlots then
                targetSlot = step.slot
            end
            local enemyIndex = (playerIndex == 1) and 2 or 1
            local tx, ty = self:getBoardSlotPosition(enemyIndex, targetSlot)
            love.graphics.setColor(0.9, 0.2, 0.2, 0.8)
            local ax = sx + cardW / 2
            local ay = sy + cardH / 2
            local bx2 = tx + cardW / 2
            local by2 = ty + cardH / 2
            love.graphics.setLineWidth(2)
            love.graphics.line(ax, ay, bx2, by2)
            love.graphics.setColor(0.9, 0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", tx, ty, cardW, cardH, 8, 8)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("Resolving %s on slot %d", step.kind, step.slot), 0, 20, screenW, "center")
end

function GameState:drawResolveLog(screenW)
    local panelW = 280
    local panelX = screenW - panelW - 16
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

    love.graphics.setColor(1, 1, 1, 1)
    local startIdx = math.max(1, #self.resolveLog - (self.maxResolveLogLines or 14) + 1)
    local y = panelY + titleH
    for i = startIdx, #self.resolveLog do
        love.graphics.printf(self.resolveLog[i], panelX + 8, y, panelW - 16, "left")
        y = y + lineH
    end
end


function GameState:draw()
    self:refreshLayoutPositions()

    local screenW = Viewport.getWidth()
    local layout = self:getLayout()

    self:drawTurnBanner(screenW)
    self:drawBoardSlots(layout)
    self:drawDiscardArea()
    self:drawCurrentHand()
    self:drawDeckArea()
    self:drawPassButton()
    self:drawDraggingCard()
    self:drawResolveOverlay(layout, screenW)
    self:drawResolveLog(screenW)
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
    local startX, _, layout = self:getHandMetrics(player or (self.players and self.players[self.currentPlayer]))
    local x = startX + (slotIndex - 1) * layout.slotSpacing
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

