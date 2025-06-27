local Class = require "hump.class"
local Vector = require "hump.vector"

Enemy = Class{}
    function Enemy:init(x, y ,width, height, speed)
        self.pos = Vector(x, y)
        self.width = width
        self.height = height
        self.speed = speed
        
    end

    function Enemy:update(dt)

        self.pos.y = self.pos.y + self.speed * dt
        
    end

    return Enemy