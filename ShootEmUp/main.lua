local Enemy = require "enemy"
local Player = require "player"
local Projectile = require "projectile"
local Collision = require "collision"
local Timer = require "hump.timer"

local bullets = {}
local enemyBullets = {}
local enemies = {}

local timer = Timer.new()
local player
local screenW, screenH

function love.load()
    
    love.window.setMode(1024, 1500)
    player = Player(400, 300, 32, 32)
    screenW, screenH = love.window.getMode() 

end

function love.keypressed(key)

    if key == "space" then
        local bullet = Projectile(player.pos.x + 16, player.pos.y)
        table.insert(bullets, bullet)
    end
    if key == "e" then
        local enemy = Enemy(love.math.random(16 , screenW - 16), 0, 16, 120)
        enemy.onShoot = function (x, y)
            local bullet = Projectile(x,y)
            bullet.speed = -300
            table.insert(enemyBullets, bullet)
            
        end
        table.insert(enemies, enemy)
        local function scheduleEnemyShot(enemy)
        local interval = love.math.random(1, 3)
        enemy.cooldownDuration = interval
        enemy.cooldownTimer = interval
        timer:after(interval, function()
                        if not enemy.isDestroyed then
                            enemy:shoot()
                            scheduleEnemyShot(enemy) -- Reschedule for next shot
                        end
                    end
                    )
        end
        scheduleEnemyShot(enemy)
    end
    if key == "escape" then
        love.event.quit()
    end
end

function love.update(dt)

    timer:update(dt)
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
    -- Update enamy bullets
    for i = #enemyBullets, 1, -1 do
        local b = enemyBullets[i]
        b:update(dt)
        if b.pos.y > screenH then
            table.remove(enemyBullets, i)
        end
        if Collision:check(player, b) then
            table.remove(enemyBullets, i)
            player.lives = player.lives -1
            if player.lives == 0 then
                love.event.quit()
            end
        end
    end
    --Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(dt)
        if e.pos.y > screenH + e.size.x then
            table.remove(enemies, i)
        end
    end
    --Check enemy bullet collision
    for i = #bullets, 1, -1 do
    local bullet = bullets[i]
        for j = #enemies, 1, -1 do
            local enemy = enemies[j]
            if Collision:check(bullet, enemy) then
                enemy.isDestroyed = true
                table.remove(bullets, i)
                table.remove(enemies, j)
                player.score = player.score + enemy.score
                break
            end
        end
    end
    
    --Check enemy player collision
    for i = #enemies, 1, -1 do
    local enemy = enemies[i]
        if Collision:check(player, enemy) then
            table.remove(enemies, i)
            player.lives = player.lives - 1
            if player.lives == 0 then
                love.event.quit( )
            end
            
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
    --Enemy bullets
    for _, b in ipairs(enemyBullets) do
    b:draw()
    end
    --Enemies
    for _, e in ipairs(enemies) do
        e:draw()
    end
end