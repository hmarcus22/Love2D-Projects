local Enemy = require "enemy"
local Projectile = require "projectile"
local Vector = require "HUMP.vector"
local World = require "world"


local EnemySpawner = {}

EnemySpawner.waveNumber = 0
EnemySpawner.enemiesPerWave = 5
EnemySpawner.spawnInterval = 0.5 -- seconds between each enemy
EnemySpawner.timeBetweenWaves = 8
EnemySpawner.timer = nil
EnemySpawner.active = false

EnemySpawner.enemyTypes = {
    basic = {
        radius = 16,
        speed = 100,
        score = 10,
        color = {1, 0.2, 0.2, 1},
        canTargetPlayer = false
    },
    sniper = {
        radius = 12,
        speed = 80,
        score = 20,
        color = {0.2, 0.2, 1, 1},
        canTargetPlayer = true
    },
    tank = {
        radius = 24,
        speed = 50,
        score = 30,
        color = {0.5, 0.5, 0.5, 1},
        canTargetPlayer = false,
        health = 3
    }
}

function EnemySpawner:init(timer)
    self.timer = timer
end

function EnemySpawner:startWaves()
    self.active = true
    self.waveNumber = 0
    self:scheduleNextWave()
end

function EnemySpawner:scheduleNextWave()
    self.waveNumber = self.waveNumber + 1
    local totalEnemies = self.enemiesPerWave + (self.waveNumber - 1) * 2
    local typeOptions = {"basic", "sniper", "tank"}

    for i = 1, totalEnemies do
        self.timer:after((i - 1) * self.spawnInterval, function()
            local typeName = typeOptions[love.math.random(1, #typeOptions)]
            self:spawn(typeName)
        end)
    end
        self.timer:after(totalEnemies * self.spawnInterval + self.timeBetweenWaves, function()
        self:scheduleNextWave()
    end)
end


function EnemySpawner:spawn(typeName)
    
    local t = self.enemyTypes[typeName or "basic"]
    
    local enemy = Enemy(love.math.random(16 , 1024 - 16), 0, t.radius, t.speed)
    enemy.score = t.score
    enemy.color = t.color
    enemy.canTargetPlayer = t.canTargetPlayer
    enemy.health = t.health or 1
    enemy.maxHealth = enemy.health

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
    self:scheduleShot(enemy)
end

function EnemySpawner:scheduleShot(enemy)
    local interval = love.math.random(1, 3)
    enemy.cooldownDuration = interval
    enemy.cooldownTimer = interval

    self.timer:after(interval, function()
        if not enemy.isDestroyed then
            enemy:shoot()
            self:scheduleShot(enemy)
        end
    end)
end

return EnemySpawner