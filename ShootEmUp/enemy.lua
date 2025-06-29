local Class = require "hump.class"
local Vector = require "hump.vector"


Enemy = Class{}

    function Enemy:init(x, y , radius, speed)
        self.pos = Vector(x, y)
        self.size = Vector(radius, 0)
        self.shape = "circle"
        self.speed = speed
        self.score = 10
        self.shootCooldown = love.math.random(1, 3)
        self.shootTimer = 0
        
    end

    function Enemy:update(dt)

        self.pos.y = self.pos.y + self.speed * dt
        self.shootTimer = self.shootTimer + dt
        if self.shootTimer >= self.shootCooldown then
            self.shootTimer = 0
            self.shootCooldown = love.math.random(1, 3)
            self:shoot()
        end
        
    end

    function Enemy:shoot()

        if self.onShoot then
            self.onShoot(self.pos.x, self.pos.y)
        end
        
    end

    function Enemy:draw()
        love.graphics.setColor(1, .2, .2, 1)
        love.graphics.circle("fill", self.pos.x, self.pos.y, self.size.x)
        
    end

return Enemy