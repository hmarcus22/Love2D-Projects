local Class = require "hump.class"

Player = Class{}

    function Player:init(x, y, width, height)
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.speed = 200
    end

function Player:update(dt)
    
end

return Player
