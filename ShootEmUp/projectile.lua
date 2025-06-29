local Class = require "hump.class"
local Vector = require "hump.vector"

local Projectile = Class{}

    function Projectile:init(x, y, width, height)
        self.pos = Vector(x, y)
        self.size = Vector(4 or width, 10 or height)
        self.shape = "rectangle"
        self.speed = 300
        self.velocity = Vector(0, -self.speed)
    end

    function Projectile:fromTarget(origin, target)
        local proj = Projectile(origin.x, origin.y, 4, 10)
        local direction = (target - origin):normalized()
        proj.velocity = direction * proj.speed
        return proj
    end

    function Projectile:update(dt)

        self.pos = self.pos + self.velocity * dt
        
    end

    function Projectile:draw()
        love.graphics.setColor(.5, .5, .5, 1)
        love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)
        
    end
return Projectile