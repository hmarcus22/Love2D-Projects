local Class = require "libs.hump.class"

local Player = Class{}

function Player:init(id, y, maxHandSize)
    self.id = id
    self.y = y
    self.maxHandSize = maxHandSize or 5
    self.slots = {}
    self.deck = {}

    -- precompute slot positions
    for i = 1, self.maxHandSize do
        table.insert(self.slots, {
            x = 150 + (i - 1) * 110,
            y = self.y,
            card = nil
        })
    end

    -- 🔹 board (play area) slots: 3 fixed positions
    -- place them between the players: above bottom hand / below top hand
    local boardY = (self.y > 200) and (self.y - 180) or (self.y + 180)
    self.boardSlots = {
        { x = 320, y = boardY, card = nil },
        { x = 430, y = boardY, card = nil },
        { x = 540, y = boardY, card = nil },
    }
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
            card.x = slot.x
            card.y = slot.y
            slot.card = card
            print("Adding card", card.name, "to slot", i, "Player", self.id)
            return true
        end
    end
    return false -- no free slot
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

    -- 🔴 compact hand: shift cards left into empty slots
    self:compactHand()
end

function Player:compactHand()
    local targetIndex = 1
    for i = 1, self.maxHandSize do
        local slot = self.slots[i]
        if slot.card then
            local c = slot.card
            if i ~= targetIndex then
                -- move card down to lowest free slot
                self.slots[i].card = nil
                self.slots[targetIndex].card = c
                c.slotIndex = targetIndex
                c.x = self.slots[targetIndex].x
                c.y = self.slots[targetIndex].y
            end
            targetIndex = targetIndex + 1
        end
    end
end


-- snap card back to its assigned slot
function Player:snapCard(card)
    if card.slotIndex and self.slots[card.slotIndex] then
        local slot = self.slots[card.slotIndex]
        card.x = slot.x
        card.y = slot.y
        slot.card = card
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

function Player:playCardToBoard(card)
    -- remove from hand slot
    if card.slotIndex and self.slots[card.slotIndex] and self.slots[card.slotIndex].card == card then
        self.slots[card.slotIndex].card = nil
    end
    card.slotIndex = nil

    -- put into first free board slot
    for i, bslot in ipairs(self.boardSlots) do
        if not bslot.card then
            bslot.card = card
            card.zone = "board"
            card.owner = self
            card.x, card.y = bslot.x, bslot.y
            -- (optional) face-up on board
            card.faceUp = true
            return true
        end
    end
    return false -- no free board slot
end

-- draw slots + cards
function Player:drawSlots()
    for i, slot in ipairs(self.slots) do
        -- draw empty slot outline
        love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
        love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)

        -- draw card if present
        if slot.card then
            slot.card:draw()
        end
    end
end

function Player:drawBoard()
    for i, slot in ipairs(self.boardSlots) do
        love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
        love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)
        if slot.card then
            slot.card:draw()
        end
    end
end

return Player
