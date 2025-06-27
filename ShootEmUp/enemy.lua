local Class = require "hump.class"
local Vector = require "hump.vector"

Enemy = Class{}

    function Enemy:init(x, y , radius, speed)
        self.pos = Vector(x, y)
        self.size = Vector(radius, 0)
        self.shape = "circle"
        self.speed = speed
        self.score = 10
        
    end

    function Enemy:update(dt)

        self.pos.y = self.pos.y + self.speed * dt
        
    end

    function Enemy:draw()
        love.graphics.setColor(1, .2, .2, 1)
        love.graphics.circle("fill", self.pos.x, self.pos.y, self.size.x)
        
    end

return Enemy