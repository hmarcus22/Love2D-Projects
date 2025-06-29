local Background = {}

function Background:init(screenW, screenH, starCount)
    self.layers = {
        {
            speed = 10, -- farthest layer
            stars = {},
            color = {0.3, 0.3, 0.3, 0.3}
        },
        {
            speed = 20,
            stars = {},
            color = {0.6, 0.6, 0.6, 0.5}
        },
        {
            speed = 60,
            stars = {},
            color = {1.0, 1.0, 1.0, 0.8}
        }
    }

    for _, layer in ipairs(self.layers) do
        for i = 1, starCount do
            table.insert(layer.stars, {
                x = love.math.random(0, screenW),
                y = love.math.random(0, screenH),
                size = love.math.random(1, 2)
            })
        end
    end

    self.screenW = screenW
    self.screenH = screenH
end

function Background:update(dt)
    for _, layer in ipairs(self.layers) do
        for _, star in ipairs(layer.stars) do
            star.y = star.y + layer.speed * dt
            if star.y > self.screenH then
                star.y = 0
                star.x = love.math.random(0, self.screenW)
            end
        end
    end
end

function Background:draw()
    for _, layer in ipairs(self.layers) do
        love.graphics.setColor(layer.color)
        for _, star in ipairs(layer.stars) do
            love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
        end
    end
end

return Background