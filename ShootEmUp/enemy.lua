local Class = require "hump.class"
local Vector = require "hump.vector"

Enemy = Class{}
    function Enemy:init(x, y ,width, height, speed)
        self.pos = Vector(x, y)
        self.size = Vector(width, height)
        self.speed = speed
        
    end

    function Enemy:update(dt)

        self.pos.y = self.pos.y + self.speed * dt
        
    end

    function Enemy:draw()

        love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)
        
    end

    return Enemy