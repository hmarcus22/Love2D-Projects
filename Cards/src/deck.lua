local Class = require "libs.hump.class"

local Deck = Class{}

function Deck:init(cards)
    self.cards = cards or {}
end

function Deck:shuffle()
    for i = #self.cards, 2, -1 do
        local j = love.math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:drawCard()
    return table.remove(self.cards)
end

function Deck:count()
    return #self.cards
end

return Deck