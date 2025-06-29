local World = require "world"
local Player = require "player"
local Projectile = require "projectile"
local Timer = require "hump.timer"
local Background = require "background"

local Input = require "input"
local EnemySpawner = require "enemy_spawner"


local timer = Timer.new()
local player

function love.load()

    Input:load()
    love.window.setMode(1024, 1500)
    screenW, screenH = love.graphics.getDimensions()
    Background:init(screenW, screenH, 100) -- 100 stars per layer
    player = Player(400, 300, 32, 32)
    World:load()
    World:initPlayer(player)
    EnemySpawner:init(timer)
    EnemySpawner:startWaves()

end

function love.keypressed(key)

   Input:keypressed(key)

end

function love.update(dt)

    timer:update(dt)

    Input:update(dt, World.player,
        function() -- fireCallback
            local bullet = Projectile(World.player.pos.x + 16, World.player.pos.y)
            World:addBullet(bullet)
        end,
        function() -- spawnEnemyCallback
            EnemySpawner:spawn(timer)
        end
    )

   World:update(dt)

   Background:update(dt)
    
end


function love.draw()
    Background:draw()
    World:draw()
   
end