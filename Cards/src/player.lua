local Class = require "libs.hump.class"

local Player = Class{}
local Viewport = require "src.viewport"
local FighterCatalog = require "src.fighter_definitions"

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

    self.fighterId = nil
    self.fighter = nil
    if args.fighter or args.fighterId then
        self:setFighter(args.fighter or args.fighterId)
    end

    for i = 1, self.maxHandSize do
        self.slots[i] = { x = 0, y = 0, card = nil }
    end

    for i = 1, self.maxBoardCards do
        self.boardSlots[i] = { x = 0, y = 0, card = nil }
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
    else
        self.fighterId = type(fighter) == "string" and fighter or nil
    end
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

function Player:snapCard(card, gs)
    if not card.slotIndex then
        return
    end

    local x, y = gs:getHandSlotPosition(card.slotIndex, self)
    card.x = x
    card.y = y
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

function Player:playCardToBoard(card, slotIndex, gs)
    if card.slotIndex and self.slots[card.slotIndex] and self.slots[card.slotIndex].card == card then
        self.slots[card.slotIndex].card = nil
    end
    card.slotIndex = nil

    local boardSlot = self.boardSlots[slotIndex]
    if not boardSlot or boardSlot.card then
        return false
    end

    boardSlot.card = card

    local x, y = gs:getBoardSlotPosition(self.id, slotIndex)
    card.x, card.y = x, y
    card.zone = "board"
    card.owner = self
    card.faceUp = true

    self:compactHand()
    return true
end

function Player:drawBoard()
    local color = self:getFighterColor()
    local r, g, b = 0.8, 0.8, 0.2
    if color then
        r = color[1] or r
        g = color[2] or g
        b = color[3] or b
    end

    for _, slot in ipairs(self.boardSlots) do
        love.graphics.setColor(r, g, b, 0.15)
        love.graphics.rectangle("fill", slot.x, slot.y, 100, 150, 8, 8)
        love.graphics.setColor(r, g, b, 0.5)
        love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)
        if slot.card then
            love.graphics.setColor(1, 1, 1, 1)
            slot.card:draw()
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
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
        if card then
            local lift = liftAmount * (card.handHoverAmount or 0)
            card.x = x
            card.y = y - lift
        end
    end

    local hoveredCard
    if gs and mx and my then
        for idx = #self.slots, 1, -1 do
            local card = self.slots[idx].card
            if card and not card.dragging and card:isHovered(mx, my) then
                hoveredCard = card
                break
            end
        end
    end

    for _, slot in ipairs(self.slots) do
        local card = slot.card
        if card then
            if gs and card == hoveredCard and not card.dragging then
                card.handHoverTarget = 1
            else
                card.handHoverTarget = 0
            end

            if card ~= hoveredCard then
                card:draw()
            end
        end
    end

    if hoveredCard and (not gs or hoveredCard ~= gs.draggingCard) then
        hoveredCard:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Player
