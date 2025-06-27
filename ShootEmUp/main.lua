local Class = require "hump.class"
local Player = require "player"
local bullets = {}
local enemies = {}

player = Player(400, 300, 32, 32)

function checkCollision(a, b)
    return a.x < b.x + b.width and
           b.x < a.x + a.width and
           a.y < b.y + b.height and
           b.y < a.y + a.height
end

function love.load()
    
    
end

function love.keypressed(key)
    if key == "space" then
        table.insert(bullets, {x = player.x + 16, y = player.y, width = 4, height = 10})
    end
    if key == "e" then
        table.insert(enemies, {x = love.math.random(16 , 784), y = 0, width = 32, height = 32, speed = 120})
    end
    if key == "escape" then
        love.event.quit()
    end
end

function love.update(dt)
    --Check player input
    if love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("down") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
    end
    -- Update bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.y = b.y -300 * dt
        if b.y < 0 then
            table.remove(bullets, i)
        end
    end
    --Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e.y = e.y + e.speed * dt
        if e.y > 600 then
            table.remove(enemies, i)
        end
    end
    --Check enemy bullet collision
    for i = #bullets, 1, -1 do
    local bullet = bullets[i]
        for j = #enemies, 1, -1 do
            local enemy = enemies[j]
            if checkCollision(bullet, enemy) then
                table.remove(bullets, i)
                table.remove(enemies, j)
                break
            end
        end
    end
    --Check enemy player collision
    for i = #enemies, 1, -1 do
    local enemy = enemies[i]
        if checkCollision(player, enemy) then
            -- You can replace this with game over logic later
            love.event.quit( )
        end
    end
end


function love.draw()
    --Playerr
    love.graphics.rectangle("fill", player.x, player.y, player.width, player.height)
    --Bullets
    for _, b in ipairs(bullets) do
        love.graphics.rectangle("fill", b.x, b.y, b.width, b.height)
    end
    --Enemies
    for _, e in ipairs(enemies) do
        love.graphics.rectangle("fill", e.x, e.y, e.width, e.height)
    end
end