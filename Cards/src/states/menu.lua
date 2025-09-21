local Gamestate = require "libs.hump.gamestate"
local fighter_select = require "src.states.fighter_select"
local Viewport = require "src.viewport"

local menu = {}

function menu:draw()
    Viewport.apply()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Card Game Prototype", 0, 200, Viewport.getWidth(), "center")
    love.graphics.printf("Press ENTER to Choose Your Fighter", 0, 300, Viewport.getWidth(), "center")
    Viewport.unapply()
end

function menu:keypressed(key)
    if key == "return" then
        Gamestate.switch(fighter_select)
    end
end

return menu
