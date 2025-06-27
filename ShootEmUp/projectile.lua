local Class = require "hump.class"

local Projectile = Class{}

    function Projectile:init(x, y, width, height)
        self.x = x
        self.y = y
        self.width = 4 or width
        self.height = 10 or height        
    end

    return Projectile