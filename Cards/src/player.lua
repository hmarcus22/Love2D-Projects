local Class = require "libs.hump.class"

local Player = Class{}

function Player:init(id, y, maxHandSize)
    self.id = id
    self.hand = {}
    self.y = y
    self.maxHandSize = maxHandSize or 5
end

function Player:getSlotX(slotIndex)
    return 150 + (slotIndex - 1) * 110
end

function Player:addCard(card)
    if #self.hand >= self.maxHandSize then
        return false -- hand is full
    end

    local slotIndex = #self.hand + 1
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
        c.x = self:getSlotX(i)
        c.y = self.y
    end
end

function Player:drawSlots()
    -- Draw empty slots as placeholders
    love.graphics.setColor(0.7, 0.7, 0.7, 0.3)
    for i = 1, self.maxHandSize do
        local x = self:getSlotX(i)
        love.graphics.rectangle("line", x, self.y, 100, 150, 8, 8)
    end
end

return Player