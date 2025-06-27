local Class = require "hump.class"
local Vector = require "hump.vector"

Player = Class{}

    function Player:init(x, y, width, height)
        self.pos = Vector(x, y)
        self.size = Vector(width, height)
        self.shape = "rectangle"
        self.speed = 200
    end

    function Player:update(dt)

        local velocity = Vector(0, 0)

        if love.keyboard.isDown("up") then
            velocity.y = -self.speed * dt
        end
        if love.keyboard.isDown("down") then
            velocity.y = self.speed * dt
        end
        if love.keyboard.isDown("left") then
            velocity.x = -self.speed * dt
        end
        if love.keyboard.isDown("right") then
            velocity.x = self.speed * dt
        end
        
        self.pos = self.pos + velocity
    end

    function Player:draw()

        love.graphics.setColor(.2, 1, .2, 1)
        love.graphics.rectangle("fill", self.pos.x, self.pos.y, self.size.x, self.size.y)

    end
return Player
