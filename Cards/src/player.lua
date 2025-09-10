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
    if #self.hand >= self.maxHandSize then
        return false -- hand full
    end

    local slotIndex = #self.hand + 1
    card.slotIndex = slotIndex
    card.owner = self
    card.x = self:getSlotX(slotIndex)
    card.y = self.y
    table.insert(self.hand, card)
    return true
end

function Player:removeCard(card)
    for i, c in ipairs(self.hand) do
        if c == card then
            table.remove(self.hand, i)
            self:repositionHand()
            return
        end
    end
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


return Player
