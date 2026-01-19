
local config = require "config"
local Game = require "game"
local game

love.load = function()
    love.window.setMode(config.window.width, config.window.height, {
        resizable = config.window.resizable,
        fullscreen = config.window.fullscreen,
    })
    love.window.setTitle(config.window.title)

    game = Game()
end

love.draw = function()
    local r, g, b = love.math.colorFromBytes(
        config.colors.background[1],
        config.colors.background[2],
        config.colors.background[3]
    )
    love.graphics.clear(r, g, b)
    
    if game then
        game:draw()
    end
end

love.update = function(dt)
    if game then
        game:update(dt)
    end
end
