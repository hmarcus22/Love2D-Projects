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
        self.cooldownDuration = love.math.random(1, 3)
        self.cooldownTimer = self.cooldownDuration
        self.isDestroyed = false
        
    end

    function Enemy:update(dt)

        self.pos.y = self.pos.y + self.speed * dt
        self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
        
    end

    function Enemy:shoot()

        if self.onShoot then
            self.onShoot(self.pos.x, self.pos.y)
        end
        
    end

    function Enemy:draw()
        love.graphics.setColor(1, .2, .2, 1)
        love.graphics.circle("fill", self.pos.x, self.pos.y, self.size.x)

        local barWidth = 30
        local barHeight = 4
        local x = self.pos.x - barWidth / 2
        local y = self.pos.y + self.size.x + 5

        local progress = 1 - (self.cooldownTimer / self.cooldownDuration)
        love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
        love.graphics.rectangle("fill", x, y, barWidth, barHeight)
        love.graphics.setColor(0.2, 0.8, 1.0, 1.0)
        love.graphics.rectangle("fill", x, y, barWidth * progress, barHeight)
        
    end

return Enemy