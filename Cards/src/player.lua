local Class = require "libs.hump.class"

local Player = Class{}

function Player:init(args)
    self.id = args.id
    self.maxHandSize = args.maxHandSize or 5
    self.maxBoardCards = args.maxBoardCards or 3
    self.slots = {}
    self.deck = {}
    self.boardSlots = {}

    -- create empty hand slots
    for i = 1, self.maxHandSize do
        table.insert(self.slots, { x = 0, y = 0, card = nil })
    end

    -- create board slots, positions set later
    for i = 1, self.maxBoardCards do
        table.insert(self.boardSlots, { x = 0, y = 0, card = nil })
    end
end


-- helper: get all cards currently in hand
function Player:getHand()
    local cards = {}
    for _, slot in ipairs(self.slots) do
        if slot.card then
            table.insert(cards, slot.card)
        end
    end
    return cards
end

-- add a card to the lowest free slot
function Player:addCard(card)
    for i, slot in ipairs(self.slots) do
        if not slot.card then
            card.slotIndex = i
            card.owner = self
            slot.card = card
            return true
        end
    end
    print("Hand full for Player " .. self.id)
    return false
end

-- remove a card from its slot
function Player:removeCard(card)
    local oldSlot = card.slotIndex
    if oldSlot and self.slots[oldSlot] and self.slots[oldSlot].card == card then
        self.slots[oldSlot].card = nil
    end
    print("Removing card", card.name, "from slot", oldSlot, "Player", self.id)
    card.owner = nil
    card.slotIndex = nil

    -- compact after a successful removal (e.g., discard)
    self:compactHand()
end


function Player:compactHand()
    local target = 1
    for i = 1, self.maxHandSize do
        local slot = self.slots[i]
        if slot.card then
            local c = slot.card
            if i ~= target then
                -- move card into the lowest empty slot
                self.slots[i].card = nil
                local tslot = self.slots[target]
                tslot.card = c
                c.slotIndex = target
                c.x, c.y = tslot.x, tslot.y
            end
            target = target + 1
        end
    end
end


-- snap card back to its assigned slot
function Player:snapCard(card, gs)
    if card.slotIndex then
        local x, y = gs:getHandSlotPosition(card.slotIndex)
        card.x = x
        card.y = y
        self.slots[card.slotIndex].card = card
    end
end

-- draw one card from deck into hand
function Player:drawCard()
    if not self.deck or #self.deck == 0 then
        print("No cards left in deck")
        return nil
    end

    print("Drawing card for player " .. self.id)

    local c = table.remove(self.deck)
    if not self:addCard(c) then
        print("Hand full, cannot draw")
        table.insert(self.deck, c) -- put back
        return nil
    end
    return c
end

function Player:playCardToBoard(card, slotIndex, gs)
    -- remove from hand
    if card.slotIndex and self.slots[card.slotIndex] and self.slots[card.slotIndex].card == card then
        self.slots[card.slotIndex].card = nil
    end
    card.slotIndex = nil

    -- choose board slot
    local bslot = self.boardSlots[slotIndex]
    if not bslot or bslot.card then return false end
    bslot.card = card

    local x, y = gs:getBoardSlotPosition(self.id, slotIndex)
    card.x, card.y = x, y
    card.zone = "board"
    card.owner = self
    card.faceUp = true

    -- compact hand
    self:compactHand()
    return true
end

function Player:drawBoard()
    for i, slot in ipairs(self.boardSlots) do
        love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
        love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)
        if slot.card then slot.card:draw() end
    end
end

function Player:drawHand(isCurrent)
    if not isCurrent then return end
    local handY = love.graphics.getHeight() - 170

    for i, slot in ipairs(self.slots) do
        local x = 150 + (i - 1) * 110

        -- update card position
        if slot.card then
            slot.card.x = x
            slot.card.y = handY
        end

        -- slot outline
        love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
        love.graphics.rectangle("line", x, handY, 100, 150, 8, 8)

        -- card
        if slot.card then
            slot.card:draw()
        end
    end
end



return Player
