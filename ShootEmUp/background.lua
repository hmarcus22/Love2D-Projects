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
                size = love.math.random(1, 2),
                twinkleTime = love.math.random() * 2 * math.pi
            })
        end
    end

    self.screenW = screenW
    self.screenH = screenH
    self.shootingStars = {}
    self.shootingStarTimer = 0
    self.shootingStarCooldown = love.math.random(2, 5)
end

function Background:update(dt)
    for _, layer in ipairs(self.layers) do
        for _, star in ipairs(layer.stars) do
            star.y = star.y + layer.speed * dt
            if star.y > self.screenH then
                star.y = 0
                star.x = love.math.random(0, self.screenW)
            end
            star.twinkleTime = star.twinkleTime + dt
        end
    end

    self.shootingStarTimer = self.shootingStarTimer + dt
    if self.shootingStarTimer >= self.shootingStarCooldown then
        self.shootingStarTimer = 0
        self.shootingStarCooldown = love.math.random(3, 6)

        table.insert(self.shootingStars, {
            x = love.math.random(0, self.screenW),
            y = love.math.random(0, self.screenH / 2),
            speed = 400 + love.math.random() * 200,
            angle = math.rad(45), -- diagonal down-right
            length = 60,
            life = 1
        })
    end

    -- Update shooting stars
    -- for i = #self.shootingStars, 1, -1 do
    --     local star = self.shootingStars[i]
    --     local dx = math.cos(star.angle) * star.speed * dt
    --     local dy = math.sin(star.angle) * star.speed * dt
    --     star.x = star.x + dx
    --     star.y = star.y + dy
    --     star.life = star.life - dt

    --     if star.life <= 0 then
    --         table.remove(self.shootingStars, i)
    --     end
    -- end
end

function Background:draw()
    for _, layer in ipairs(self.layers) do
        for _, star in ipairs(layer.stars) do
            local baseR, baseG, baseB, baseA = unpack(layer.color)
            local alpha = baseA * (0.6 + 0.4 * math.sin(star.twinkleTime * 2)) -- range 0.2–1.0
            love.graphics.setColor(baseR, baseG, baseB, alpha)
            love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
        end
    end

    --Shooting star
    -- for _, star in ipairs(self.shootingStars) do
    --     love.graphics.setColor(1, 1, 1, 0.8)
    --     local x2 = star.x - math.cos(star.angle) * star.length
    --     local y2 = star.y - math.sin(star.angle) * star.length
    --     love.graphics.setLineWidth(2)
    --     love.graphics.line(star.x, star.y, x2, y2)
    -- end
end

return Background