local Collision = require "collision"

local screenW, screenH

local World = {}

World.player = nil
World.bullets = {}
World.enemyBullets = {}
World.enemies = {}

function World:reset()
    self.player = nil
    self.bullets = {}
    self.enemyBullets = {}
    self.enemies = {}
end

function World:initPlayer(player)
    self.player = player
end

function World:addBullet(bullet)
    table.insert(self.bullets, bullet)
end

function World:addEnemyBullet(bullet)
    table.insert(self.enemyBullets, bullet)
end

function World:addEnemy(enemy)
    table.insert(self.enemies, enemy)
end

function World:load()
    screenW, screenH = love.window.getMode() 
end

function World:update(dt)
    
    self.player:update(dt)

    for i = #self.bullets, 1, -1 do
        local b = self.bullets[i] 
        b:update(dt)
        if b.pos.y < 0 then
            table.remove(self.bullets, i)
        end
    end
    -- Update enamy bullets
    for i = #self.enemyBullets, 1, -1 do
        local b = self.enemyBullets[i]
        b:update(dt)
        if b.pos.y > screenH then
            table.remove(self.enemyBullets, i)
        end
        if Collision:check(self.player, b) then
            table.remove(self.enemyBullets, i)
            self.player.lives = self.player.lives -1
            if self.player.lives == 0 then
                love.event.quit()
            end
        end
    end
    --Update enemies
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        e:update(dt)
        if e.pos.y > screenH + e.size.x then
            table.remove(self.enemies, i)
        end
    end

    Collision:checkAll(self.bullets, self.enemies, function(bullet, enemy, i, j)
        table.remove(self.bullets, i)
        enemy.health = (enemy.health or 1) - 1
         if enemy.health <= 0 then
            table.remove(self.enemies, j)
            self.player.score = self.player.score + enemy.score
            enemy.isDestroyed = true
        end
        
    end)
    
end

function World:draw()

     --Player
    self.player:draw()
    --Bullets
    for _, b in ipairs(self.bullets) do
        b:draw()
    end
    --Enemy bullets
    for _, b in ipairs(self.enemyBullets) do
    b:draw()
    end
    --Enemies
    for _, e in ipairs(self.enemies) do
        e:draw()
    end

    for _, e in ipairs(self.enemies) do
        Collision:debugDraw(e)
    end
    
end

return World