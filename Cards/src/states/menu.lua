local Gamestate = require "libs.hump.gamestate"
local game = require "src.states.game"

local menu = {}

function menu:draw()
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Card Game Prototype", 0, 200, love.graphics.getWidth(), "center")
    love.graphics.printf("Press ENTER to Start New Game", 0, 300, love.graphics.getWidth(), "center")
end

function menu:keypressed(key)
    if key == "return" then
        Gamestate.switch(game, true) -- true means "start new"
    end
end

return menu