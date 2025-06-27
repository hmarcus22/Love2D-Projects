local Class = require "hump.class"
local Vector = require "hump.vector"

Player = Class{}

    function Player:init(x, y, width, height)
        self.pos = Vector(x, y)
        self.width = width
        self.height = height
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

return Player
