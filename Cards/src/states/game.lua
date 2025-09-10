local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local pause = require "src.states.pause"

local game = {}

function game:enter()
    self.gs = GameState:new()
end

function game:update(dt)
    self.gs:update(dt)
end

function game:draw()
    self.gs:draw()
end

function game:mousepressed(x, y, button)
    Input:mousepressed(self.gs, x, y, button)
end

function game:mousereleased(x, y, button)
    Input:mousereleased(self.gs, x, y, button)
end

function game:keypressed(key)
    if key == "escape" then
        Gamestate.push(pause) -- overlay pause menu
    else
        Input:keypressed(self.gs, key)
    end
end

return game