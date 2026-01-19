// Game board. Contain 7 slots + 1 slot for draw pile and a slot for discard. 4 slots to move card to.
// each of the seven first slots can contain multiple cards
// Layout is 4 playing slots on top to the left. draw and discard to the top right. 7 slots under first row of slots, evenly spaced.

Class = require 'HUMP.class'
local slots = 7

local Board = Class() {
    init = function(self)
        self.tableau = {}
        for i = 1, slots do
            self.tableau[i] = {}
        end
    end
}

function Board:addCardToTableau(card, slot)
    if slot < 1 or slot > slots then
        error("Invalid slot number: " .. tostring(slot))
    end
    table.insert(self.tableau[slot], card)
end

function Board:removeCardFromTableau(slot)
    if slot < 1 or slot > slots then
        error("Invalid slot number: " .. tostring(slot))
    end
    return table.remove(self.tableau[slot])
end

function Board:draw()
    -- Draw the board
end

return Board
