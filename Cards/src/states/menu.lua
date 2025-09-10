local Gamestate = require "libs.hump.gamestate"
local draft = require "src.states.draft"

local menu = {}

function menu:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Card Game Prototype", 0, 200, love.graphics.getWidth(), "center")
    love.graphics.printf("Press ENTER to Start Draft", 0, 300, love.graphics.getWidth(), "center")
end

function menu:keypressed(key)
    if key == "return" then
        Gamestate.switch(draft)
    end
end

return menu