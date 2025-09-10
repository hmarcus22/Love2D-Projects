local Gamestate = require "libs.hump.gamestate"

local pause = {}

function pause:draw()
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", 0,0, love.graphics.getWidth(), love.graphics.getHeight())
    
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Paused", 0, 150, love.graphics.getWidth(), "center")
    love.graphics.printf("ESC to Resume", 0, 250, love.graphics.getWidth(), "center")
    love.graphics.printf("R to Restart", 0, 300, love.graphics.getWidth(), "center")
    love.graphics.printf("Q to Quit to Menu", 0, 350, love.graphics.getWidth(), "center")
end

function pause:keypressed(key)
    if key == "escape" then
        Gamestate.pop() -- resume
    elseif key == "r" then
        local game = require "src.states.game"
        Gamestate.switch(game, true) -- restart new game
    elseif key == "q" then
        local menu = require "src.states.menu"
        Gamestate.switch(menu)
    end
end

return pause