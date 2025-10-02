local Class = require "libs.hump.class"

local Player = Class{}
local Viewport = require "src.viewport"
local FighterCatalog = require "src.fighter_definitions"
local HoverUtils = require "src.ui.hover_utils"

local DEBUG_PLAYER_LOG = false

local function log(...)
    if DEBUG_PLAYER_LOG then
        print(...)
    end
end

function Player:init(args)
    self.id = args.id
    self.maxHandSize = args.maxHandSize or 5
    self.maxBoardCards = args.maxBoardCards or 3
    self.maxHealth = args.maxHealth or 20
    self.health = args.health or self.maxHealth
    self.block = 0
    self.slots = {}
    self.deck = {}
    self.boardSlots = {}
    self.prevCardId = nil
    self.lastCardId = nil
    self.roundPunchCount = 0

    self.fighterId = nil
    self.fighter = nil
    if args.fighter or args.fighterId then
        self:setFighter(args.fighter or args.fighterId)
    end

    for i = 1, self.maxHandSize do
        self.slots[i] = { x = 0, y = 0, card = nil }
    end

    for i = 1, self.maxBoardCards do
        self.boardSlots[i] = { x = 0, y = 0, card = nil, block = 0 }
    end
end

function Player:setFighter(fighter)
    local resolved = fighter
    if type(fighter) == "string" then
        resolved = FighterCatalog.byId[fighter]
    end
    self.fighter = resolved or nil
    if resolved then
        self.fighterId = resolved.id
        -- Add starter, signature, combo, and ultimate cards to deck
        local factory = require "src.card_factory"
        self.deck = {}
        local function addCards(cardIds)
            if cardIds then
                for _, id in ipairs(cardIds) do
                    table.insert(self.deck, factory.createCard(id))
                end
            end
        end
        addCards(resolved.starterCards)
        addCards(resolved.signatureCards)
        if resolved.comboCards then
            addCards(resolved.comboCards)
        end
        if resolved.ultimate then
            table.insert(self.deck, factory.createCard(resolved.ultimate))
        end
        self.prevCardId = nil
        self.lastCardId = nil
        self.roundPunchCount = 0
    else
        self.fighterId = type(fighter) == "string" and fighter or nil
    end
end
-- Combo and ultimate logic
function Player:canPlayCombo(card)
    if not card or not card.combo then
        return false
    end
    return self.prevCardId ~= nil and self.prevCardId == card.combo.after
end

function Player:canPlayUltimate(card)
    return card.ultimate == true
end

function Player:applyComboBonus(card)
    if not card or not card.combo then
        return false
    end
    if card.comboApplied or not self:canPlayCombo(card) then
        return false
    end

    local applied = false
    if card.combo.bonus then
        card.comboVariance = card.comboVariance or {}
        for k, v in pairs(card.combo.bonus) do
            if type(v) == "number" then
                card.comboVariance[k] = (card.comboVariance[k] or 0) + v
                applied = true
            end
        end
    end
    if applied then
        card.comboApplied = true
    end
    return applied
end

function Player:getFighter()
    return self.fighter
end

function Player:getFighterColor()
    local f = self.fighter
    return f and f.color or nil
end

function Player:getBoardPassiveMods()
    local f = self.fighter
    local passives = f and f.passives or nil
    return passives and passives.boardSlot or nil
end

function Player:getDrawBonus(trigger)
    local f = self.fighter
    local passives = f and f.passives or nil
    local draw = passives and passives.draw or nil
    if not draw then
        return 0
    end
    return draw[trigger] or draw.default or 0
end

function Player:isCardFavored(def)
    local fighter = self.fighter
    if not fighter or not fighter.favoredTags then
        return false
    end
    local definitionTags = def and def.tags
    if not definitionTags then
        return false
    end
    for _, wanted in ipairs(fighter.favoredTags) do
        for _, tag in ipairs(definitionTags) do
            if tag == wanted then
                return true
            end
        end
    end
    return false
end
function Player:getHand()
    local cards = {}
    for _, slot in ipairs(self.slots) do
        if slot.card then
            cards[#cards + 1] = slot.card
        end
    end
    return cards
end

function Player:addCard(card)
    for i, slot in ipairs(self.slots) do
        if not slot.card then
            card.slotIndex = i
            card.owner = self
            card.statVariance = nil
            slot.card = card
            return true
        end
    end
    log("Hand full for Player " .. self.id)
    return false
end

function Player:removeCard(card)
    local oldSlot = card.slotIndex
    if oldSlot and self.slots[oldSlot] and self.slots[oldSlot].card == card then
        self.slots[oldSlot].card = nil
    end

    log("Removing card", card.name, "from slot", oldSlot, "Player", self.id)
    card.statVariance = nil
    card.owner = nil
    card.slotIndex = nil

    self:compactHand()
end

function Player:compactHand()
    local target = 1
    for i = 1, self.maxHandSize do
        local slot = self.slots[i]
        local card = slot.card
        if card then
            if i ~= target then
                self.slots[i].card = nil
                local targetSlot = self.slots[target]
                targetSlot.card = card
                card.slotIndex = target
                card.x, card.y = targetSlot.x, targetSlot.y
            end
            target = target + 1
        end
    end
end

function Player:compactHand(gs)
    -- Remove gaps in hand slots and update card positions
    local newSlots = {}
    local idx = 1
    for i, slot in ipairs(self.slots) do
        if slot.card then
            slot.card.slotIndex = idx
            local x, y = gs:getHandSlotPosition(idx, self)
            slot.card.x = x
            slot.card.y = y
            newSlots[idx] = { card = slot.card }
            idx = idx + 1
        end
    end
    -- Fill remaining slots
    for i = idx, #self.slots do
        newSlots[i] = { card = nil }
    end
    self.slots = newSlots
end

function Player:snapCard(card, gs)
    if not card.slotIndex then
        return
    end

    local x, y = gs:getHandSlotPosition(card.slotIndex, self)
    card.x = x
    card.y = y
    card.statVariance = nil
    self.slots[card.slotIndex].card = card
end

function Player:drawCard()
    if not self.deck or #self.deck == 0 then
        log("No cards left in deck")
        return nil
    end

    log("Drawing card for player " .. self.id)

    local card = table.remove(self.deck)
    if not self:addCard(card) then
        log("Hand full, cannot draw")
        table.insert(self.deck, card)
        return nil
    end

    return card
end

function Player:drawHand(isCurrent, gs)
    if not isCurrent then
        return
    end

    local baseLayout = gs and gs:getLayout() or {}
    local cardW = baseLayout.cardW or 100
    local cardH = baseLayout.cardH or 150
    local bottomMargin = baseLayout.handBottomMargin or 20

    local startX, spacing, handY, activeLayout = 150, (baseLayout.slotSpacing or 110), 0, baseLayout
    if gs then
        startX, _, activeLayout, _, spacing = gs:getHandMetrics(self)
        spacing = spacing or activeLayout.slotSpacing or cardW
        handY = gs:getHandY()
        cardW = activeLayout.cardW or cardW
        cardH = activeLayout.cardH or cardH
        bottomMargin = activeLayout.handBottomMargin or bottomMargin
    else
        handY = Viewport.getHeight() - cardH - bottomMargin
    end

    local liftAmount = activeLayout.handHoverLift or math.floor(cardH * 0.15)
    local mx, my
    if gs then
        local rawX, rawY = love.mouse.getPosition()
        mx, my = Viewport.toVirtual(rawX, rawY)
    end

    for i, slot in ipairs(self.slots) do
        local x = startX + (i - 1) * spacing
        local y = handY
        slot.x, slot.y = x, y

        local card = slot.card
        if card and (not gs or card ~= gs.draggingCard) then
            local lift = liftAmount * (card.handHoverAmount or 0)
            card.x = x
            card.y = y - lift
            -- Ensure hand cards adopt current layout size
            card.w = cardW
            card.h = cardH
        end
    end

    local hoveredCard
    if gs and mx and my then
        local useScaled = activeLayout.handHoverHitScaled == true
        local hoverScale = (activeLayout.handHoverScale or 0.06)
        for idx = #self.slots, 1, -1 do
            local card = self.slots[idx].card
            if card and not card.dragging then
                if useScaled then
                    local amt = card.handHoverAmount or 0
                    if HoverUtils.hitScaled(mx, my, card.x, card.y, cardW, cardH, amt, hoverScale) then
                        hoveredCard = card
                        break
                    end
                else
                    if card:isHovered(mx, my) then
                        hoveredCard = card
                        break
                    end
                end
            end
        end
    end

    for _, slot in ipairs(self.slots) do
        local card = slot.card
        if card and card ~= gs.draggingCard then
            if gs and card == hoveredCard and not card.dragging then
                card.handHoverTarget = 1
            else
                card.handHoverTarget = 0
            end

            -- Draw non-hovered cards (topmost hovered is drawn later)
            if card ~= hoveredCard then
                local CardRenderer = require "src.card_renderer"
                local amount = card.handHoverAmount or 0
                local hoverScale = (activeLayout.handHoverScale or 0.06)
                local dx, dy, dw, dh = HoverUtils.scaledRect(card.x, card.y, cardW, cardH, amount, hoverScale)
                card.w, card.h = dw, dh
                card.x, card.y = dx, dy
                CardRenderer.draw(card)
            end
        end
    end

    if hoveredCard and (not gs or (hoveredCard ~= gs.draggingCard)) then
        -- Ensure fully visible when hand is peeked off-screen: add extra lift if needed
        local vh = Viewport.getHeight()
        local baseLayout = gs and gs:getLayout() or {}
        local cardW = baseLayout.cardW or 100
        local cardH = baseLayout.cardH or 150
        local margin = 4
        local hoverScale = (baseLayout.handHoverScale or 0.06)
        local amount = hoveredCard.handHoverAmount or 0
        local drawX, drawY, newW, newH = HoverUtils.scaledRect(hoveredCard.x, hoveredCard.y, cardW, cardH, amount, hoverScale)
        local bottomEdge = drawY + newH
        local hidden = math.max(0, bottomEdge - (vh - margin))
        if hidden > 0 then
            drawY = drawY - hidden
        end
        hoveredCard.x = drawX
        hoveredCard.y = drawY
        hoveredCard.w = newW
        hoveredCard.h = newH

        -- Soft shadow behind hovered card (drawn before the card)
        HoverUtils.drawShadow(drawX, drawY, newW, newH, amount)

        local CardRenderer = require "src.card_renderer"
        CardRenderer.draw(hoveredCard)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Smoothly tween hand hover amount toward target for each card
function Player:updateHandHover(gs, dt)
    if not gs or not self.slots then return end
    local layout = gs:getLayout() or {}
    local inSpeed = layout.handHoverInSpeed or layout.handHoverSpeed or 12
    local outSpeed = layout.handHoverOutSpeed or layout.handHoverSpeed or 12
    if (inSpeed <= 0 and outSpeed <= 0) then return end
    for _, slot in ipairs(self.slots) do
        local card = slot.card
        if card then
            local target = card.handHoverTarget or 0
            local amt = card.handHoverAmount or 0
            amt = HoverUtils.stepAmount(amt, target, dt, inSpeed, outSpeed)
            card.handHoverAmount = amt
        end
    end
end

return Player
