local Enemy = require "enemy"
local Player = require "player"
local Projectile = require "projectile"
local Collision = require "collision"
local bullets = {}
local enemies = {}



function checkCollision(a, b)
    return a.pos.x < b.pos.x + b.size.x and
           b.pos.x < a.pos.x + a.size.x and
           a.pos.y < b.pos.y + b.size.y and
           b.pos.y < a.pos.y + a.size.y
end

function love.load()
    player = Player(400, 300, 32, 32)
end

function love.keypressed(key)
    if key == "space" then
        local bullet = Projectile(player.pos.x + 16, player.pos.y)
        table.insert(bullets, bullet)
    end
    if key == "e" then
        local enemy = Enemy(love.math.random(16 , 784), 0, 16, 120)
        table.insert(enemies, enemy)
    end
    if key == "escape" then
        love.event.quit()
    end
end

function love.update(dt)
    --Check player input
   player:update(dt)
    -- Update bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i] 
        b:update(dt)
        if b.pos.y < 0 then
            table.remove(bullets, i)
        end
    end
    --Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(dt)
        if e.pos.y > 600 then
            table.remove(enemies, i)
        end
    end
    --Check enemy bullet collision
    for i = #bullets, 1, -1 do
    local bullet = bullets[i]
        for j = #enemies, 1, -1 do
            local enemy = enemies[j]
            if Collision:check(bullet, enemy) then
                table.remove(bullets, i)
                table.remove(enemies, j)
                break
            end
        end
    end
    --Check enemy player collision
    for i = #enemies, 1, -1 do
    local enemy = enemies[i]
        if Collision:check(player, enemy) then
            love.event.quit( )
        end
    end
end


function love.draw()
    --Player
    player:draw()
    --Bullets
    for _, b in ipairs(bullets) do
        b:draw()
    end
    --Enemies
    for _, e in ipairs(enemies) do
        e:draw()
    end
end