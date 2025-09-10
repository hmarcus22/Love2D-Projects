local Gamestate = require "libs.hump.gamestate"

local pause = {}

function pause:draw()
    -- dim the background
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", 0,0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Paused", 0, 200, love.graphics.getWidth(), "center")
    love.graphics.printf("Press ESC to Resume", 0, 300, love.graphics.getWidth(), "center")
end

function pause:keypressed(key)
    if key == "escape" then
        Gamestate.pop() -- return to game
    end
end

return pause