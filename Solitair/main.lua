local config = require "config"

love.load = function()
    love.window.setMode(config.window.width, config.window.height, {
        resizable = config.window.resizable,
        fullscreen = config.window.fullscreen,
    })
    love.window.setTitle(config.window.title)
    
    -- Additional initialization code can go here
end

love.keypressed = function(key)
    if key == "escape" then
        love.event.quit()
    end
    -- Additional key handling can go here
end

love.draw = function()
    love.graphics.clear(config.colors.background[1], config.colors.background[2], config.colors.background[3])
    
    -- Drawing code can go here
end

love.update = function(dt)
    -- Game update logic can go here
end