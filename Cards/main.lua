local GameState = require "src.gamestate"
local Input = require "src.input"

local game

function love.load()
    love.window.setMode(1000, 600)
    love.graphics.setBackgroundColor(0.2, 0.5, 0.2)
    game = GameState:new()
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.mousepressed(x, y, button)
    Input:mousepressed(game, x, y, button)
end

function love.mousereleased(x, y, button)
    Input:mousereleased(game, x, y, button)
end

function love.keypressed(key)
    Input:keypressed(game, key)
end