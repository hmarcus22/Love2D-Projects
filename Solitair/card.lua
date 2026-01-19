-- Defines a card object for the Solitair game. It's color, rank, and suit are specified upon creation. And gets it's texture based on those properties.
local Class = require 'HUMP.class'
local config = require 'config'
local Card = Class {}
function Card:init(rank, suit)
    self.rank = rank
    self.suit = suit
    self.width = config.card.width
    self.height = config.card.height
    self.isFaceUp = false
    self.texture = self:loadTexture()
end

function Card:loadTexture()
    -- Card textures are sorted in folders by suit and numbered 01-13 for Ace to King. Back of card is a single texture located in assets.
    if not self.isFaceUp then
        return love.graphics.newImage('assets/back.png')
    else
        local rankStr = tostring(self.rank)
        if self.rank < 10 then
            rankStr = '0' .. rankStr
        end
        local texturePath = string.format('assets/%s/%s.png', self.suit, rankStr)
        return love.graphics.newImage(texturePath)
    end
end

return Card
