local Class = require "libs.hump.class"

local Player = Class{}

function Player:init(id, y, maxHandSize)
    self.id = id
    self.hand = {}
    self.y = y
    self.maxHandSize = maxHandSize or 5
    self.slots = {}

    for i = 1, self.maxHandSize do
        table.insert(self.slots, {
            x = 150 + (i - 1) * 110,
            y = self.y,
            card = nil
        })
    end
end

function Player:getSlotX(slotIndex)
    return 150 + (slotIndex - 1) * 110
end

function Player:addCard(card)
    -- find first empty slot
    for i, slot in ipairs(self.slots) do
        if not slot.card then
            card.slotIndex = i
            card.owner = self
            card.x = slot.x
            card.y = slot.y
            slot.card = card   -- 🔴 attach card to slot
            table.insert(self.hand, card)
            print("Adding card", card.name, "to slot", i, "Player", self.id)

            return true
        end
    end
    return false -- no free slot
end

function Player:removeCard(card)
    if card.slotIndex and self.slots[card.slotIndex] then
        self.slots[card.slotIndex].card = nil
    end
    for i, c in ipairs(self.hand) do
        if c == card then
            table.remove(self.hand, i)
            break
        end
    end
    print("Removing card", card.name, "from slot", card.slotIndex, "Player", self.id)
    card.owner = nil   -- 🔴 no longer belongs to a player
    card.slotIndex = nil
end

function Player:repositionHand()
    for i, c in ipairs(self.hand) do
        c.slotIndex = i
        c.x = self:getSlotX(i)
        c.y = self.y
    end
end

function Player:snapCard(card)
    if card.slotIndex then
        local slot = self.slots[card.slotIndex]
        card.x = slot.x
        card.y = slot.y
        slot.card = card -- re-attach card to slot
    end
end


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

function Player:drawCard()
    if not self.deck or #self.deck == 0 then
        print("No cards left in deck")
        return nil
    end

    print("Drawing card for player " .. self.id)

    local c = table.remove(self.deck)
    local success = self:addCard(c)
    if not success then
        print("Hand full, cannot draw")
        table.insert(self.deck, c)
        return nil
    end
    return c
end

-- draw slot outlines only
function Player:drawSlotOutlines()
    for i, slot in ipairs(self.slots) do
        love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
        love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)
    end
end

-- draw only the cards in slots
function Player:drawCards()
    for i, slot in ipairs(self.slots) do
        if slot.card then
            slot.card:draw()
        end
    end
end



return Player
