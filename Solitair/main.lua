
local config = require "config"
local Board = require "board"
local board = Board()

love.load = function()
    love.window.setMode(config.window.width, config.window.height, {
        resizable = config.window.resizable,
        fullscreen = config.window.fullscreen,
    })
    love.window.setTitle(config.window.title)
    
end

love.keypressed = function(key)
    if key == "escape" then
        love.event.quit()
    end
    -- Additional key handling can go here
end

love.draw = function()
    local r, g, b = love.math.colorFromBytes(
        config.colors.background[1],
        config.colors.background[2],
        config.colors.background[3]
    )
    love.graphics.clear(r, g, b)
    
    if board then
        board:draw()
    end
end

love.update = function(dt)
    -- Game update logic can go here
end
