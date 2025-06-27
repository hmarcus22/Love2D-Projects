local Class = require "hump.class"
local Vector = require "hump.vector"

local Projectile = Class{}

    function Projectile:init(x, y, width, height)
        self.pos = Vector(x, y)
        self.size = Vector(4 or width, 10 or height)
        self.speed = 300
    end

function Projectile:update(dt)

    self.pos.y = self.pos.y - self.speed * dt
    
end

function Projectile:draw()

    love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)
    
end

return Projectile