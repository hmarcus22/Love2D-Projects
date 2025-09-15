local Gamestate = require "libs.hump.gamestate"
local Viewport = require "src.viewport"

local pause = {}

function pause:draw()
    Viewport.apply()
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", 0, 0, Viewport.getWidth(), Viewport.getHeight())

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Paused", 0, 150, Viewport.getWidth(), "center")
    love.graphics.printf("ESC to Resume", 0, 250, Viewport.getWidth(), "center")
    love.graphics.printf("R to Restart", 0, 300, Viewport.getWidth(), "center")
    love.graphics.printf("Q to Quit to Menu", 0, 350, Viewport.getWidth(), "center")
    Viewport.unapply()
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
