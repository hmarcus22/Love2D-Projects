local Class = require "libs.hump.class"

local Board = Class{}

function Board:init(players)
    self.players = players
    self.maxSlots = 3
    self.slots = {}

    -- create slots per player
    for i, p in ipairs(players) do
        local y = (p.y > 200) and (p.y - 180) or (p.y + 180)
        self.slots[i] = {}
        for j = 1, self.maxSlots do
            table.insert(self.slots[i], { x = 300 + (j-1)*110, y = y, card = nil })
        end
    end
end

function Board:draw()
    for pi, pslots in ipairs(self.slots) do
        for j, slot in ipairs(pslots) do
            love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
            love.graphics.rectangle("line", slot.x, slot.y, 100, 150, 8, 8)
            if slot.card then
                slot.card:draw()
            end
        end
    end
end

function Board:placeCard(playerIndex, card)
    local pslots = self.slots[playerIndex]
    for j, slot in ipairs(pslots) do
        if not slot.card then
            slot.card = card
            card.x, card.y = slot.x, slot.y
            card.zone = "board"
            return true
        end
    end
    return false -- full
end

function Board:clear()
    for pi, pslots in ipairs(self.slots) do
        for j, slot in ipairs(pslots) do
            slot.card = nil
        end
    end
end

function Board:getCards(playerIndex)
    return self.slots[playerIndex]
end

function Board:slotIndexAt(playerIndex, x, y)
    local slots = self.slots[playerIndex]
    for i, slot in ipairs(slots) do
        if x >= slot.x and x <= slot.x + 100 and y >= slot.y and y <= slot.y + 150 then
            return i
        end
    end
    return nil
end

function Board:isSlotEmpty(playerIndex, slotIndex)
    local s = self.slots[playerIndex][slotIndex]
    return s and (s.card == nil)
end

return Board
