local Enemy = require "enemy"
local Projectile = require "projectile"
local Vector = require "HUMP.vector"
local World = require "world"


local EnemySpawner = {}

EnemySpawner.waveNumber = 0
EnemySpawner.enemiesPerWave = 5
EnemySpawner.spawnInterval = 0.5 -- seconds between each enemy
EnemySpawner.timeBetweenWaves = 5
EnemySpawner.timer = nil
EnemySpawner.active = false

function EnemySpawner:init(timer)
    self.timer = timer
end

function EnemySpawner:startWaves(player, enemyBullets, enemyList)
    self.active = true
    self.waveNumber = 0
    self:scheduleNextWave(player, enemyBullets, enemyList)
end

function EnemySpawner:scheduleNextWave(player, enemyBullets, enemyList)
    self.waveNumber = self.waveNumber + 1
    local totalEnemies = self.enemiesPerWave + (self.waveNumber - 1) * 2

    for i = 1, totalEnemies do
        self.timer:after((i - 1) * self.spawnInterval, function()
            self:spawn(player, enemyBullets, enemyList, self.timer)
        end)
    end
        self.timer:after(totalEnemies * self.spawnInterval + self.timeBetweenWaves, function()
        self:scheduleNextWave(player, enemyBullets, enemyList)
    end)
end


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