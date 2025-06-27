local Class = require "hump.class"
local Vector = require "hump.vector"

local Projectile = Class{}

    function Projectile:init(x, y, width, height)
        self.pos = Vector(x, y)
        self.width = 4 or width
        self.height = 10 or height
        self.speed = 300
    end

function Projectile:update(dt)

    self.pos.y = self.pos.y - self.speed * dt
    
end

return Projectile