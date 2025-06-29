local World = require "world"
local Player = require "player"
local Projectile = require "projectile"
local Timer = require "hump.timer"

local Input = require "input"
local EnemySpawner = require "enemy_spawner"


local timer = Timer.new()
local player

function love.load()

    Input:load()
    love.window.setMode(1024, 1500)
    player = Player(400, 300, 32, 32)
    World:load()
    World:initPlayer(player)

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
    
end


function love.draw()

    World:draw()
   
end