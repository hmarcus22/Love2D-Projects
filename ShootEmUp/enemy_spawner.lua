local Enemy = require "enemy"
local Projectile = require "projectile"
local Vector = require "HUMP.vector"
local World = require "world"


local EnemySpawner = {}

function EnemySpawner:spawn(timer)
    local enemy = Enemy(love.math.random(16 , 1024 - 16), 0, 16, 120)
    enemy.canTargetPlayer = love.math.random() < 0.5

    enemy.onShoot = function(x, y)
        print("Enemy fired!")
        local bullet
        if enemy.canTargetPlayer then
            bullet = Projectile:fromTarget(Vector(x, y), World.player.pos)
        else
            bullet = Projectile(x, y, 4, 10)
            bullet.velocity = Vector(0, bullet.speed)
        end
        table.insert(World.enemyBullets, bullet)
    end

    table.insert(World.enemies, enemy)
    self:scheduleShot(enemy, timer)
end

function EnemySpawner:scheduleShot(enemy, timer)
    local interval = love.math.random(1, 3)
    enemy.cooldownDuration = interval
    enemy.cooldownTimer = interval

    timer:after(interval, function()
        if not enemy.isDestroyed then
            enemy:shoot()
            self:scheduleShot(enemy, timer)
        end
    end)
end

return EnemySpawner