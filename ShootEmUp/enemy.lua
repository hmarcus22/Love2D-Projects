local Class = require "hump.class"

Enemy = Class{}
    function Enemy:init(x, y ,width, height, speed)
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.speed = speed
        
    end

    return Enemy