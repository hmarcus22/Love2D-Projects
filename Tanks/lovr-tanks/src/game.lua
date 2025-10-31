local Class = require 'hump.class'
local Timer = require 'hump.timer'
local Camera = require 'core.camera'
local Terrain = require 'game.terrain'
local Tank = require 'game.tank'
local Projectile = require 'game.projectile'

local Game = Class:extend()

function Game:init()
  self.camera = Camera()
  self.terrain = Terrain({
    width = 600,  -- Much wider terrain to fill landscape window
    depth = 6,    
    samples = 200,  -- More samples for the wider terrain
    maxHeight = 30,
    seed = 42
  })
  
  -- Configure camera with terrain dimensions to prevent seeing world's end
  self.camera:setTerrainBounds(self.terrain.width)
  
  -- Create two tanks with intuitive positioning for camera view
  local leftX = self.terrain.width * 0.25    -- Green tank at POSITIVE X (appears LEFT on screen)
  local rightX = -self.terrain.width * 0.25  -- Red tank at NEGATIVE X (appears RIGHT on screen)
  
  self.tanks = {
    Tank({  -- Tank 1 - Green tank - appears LEFT on screen
      x = leftX,   -- Positive X
      y = self.terrain:heightAt(leftX),
      color = { 0.2, 0.8, 0.3 },
      dir = -1,  -- Faces left (toward red tank)
      angle = math.rad(135)  -- Points toward red tank
    }),
    Tank({  -- Tank 2 - Red tank - appears RIGHT on screen
      x = rightX,  -- Negative X
      y = self.terrain:heightAt(rightX),
      color = { 0.8, 0.2, 0.3 },
      dir = 1,   -- Faces right (toward green tank)
      angle = math.rad(45)   -- Points toward green tank
    })
  }
  
  self.currentPlayer = 1
  self.projectile = nil
  self.gameState = 'aiming' -- 'aiming', 'charging', 'firing', 'gameover'
  self.chargeTime = 0
  self.maxChargeTime = 1.2
  self.minPower = 15
  self.maxPower = 80
  self.aimSpeed = math.rad(45) -- 45 degrees per second
  self.moveSpeed = 10
  self.winner = nil
  
  -- Visual effects
  self.muzzleFlash = nil  -- {x, y, z, timer, intensity}
  self.muzzleFlashDuration = 0.15  -- Flash duration in seconds
  self.impactEffect = nil  -- {x, y, z, timer, particles}
  self.impactDuration = 0.8  -- Impact effect duration
  
  -- Input state
  self.keys = {}
end

function Game:update(dt)
  Timer.update(dt)
  
  -- Update all tanks
  for _, tank in ipairs(self.tanks) do
    tank:update(dt, self.terrain)
  end
  
  -- Update muzzle flash
  if self.muzzleFlash then
    self.muzzleFlash.timer = self.muzzleFlash.timer - dt
    self.muzzleFlash.intensity = self.muzzleFlash.timer / self.muzzleFlashDuration
    if self.muzzleFlash.timer <= 0 then
      self.muzzleFlash = nil
    end
  end
  
  -- Update impact effects
  if self.impactEffect then
    self.impactEffect.timer = self.impactEffect.timer - dt
    local progress = 1 - (self.impactEffect.timer / self.impactDuration)
    
    -- Update particles
    for _, particle in ipairs(self.impactEffect.particles) do
      particle.x = particle.x + particle.vx * dt
      particle.y = particle.y + particle.vy * dt
      particle.vy = particle.vy - 15 * dt  -- Gravity on particles
      particle.life = 1 - progress
    end
    
    if self.impactEffect.timer <= 0 then
      self.impactEffect = nil
    end
  end
  
  -- Update projectile if active
  if self.projectile then
    local collision = self.projectile:update(dt, self.terrain, self.tanks)
    if collision then
      self:_handleCollision(collision)
      self.projectile = nil
      self:_nextTurn()
    elseif not self.projectile.alive then
      self.projectile = nil
      self:_nextTurn()
    end
  end
  
  -- Handle game state
  if self.gameState == 'aiming' then
    self:_updateAiming(dt)
  elseif self.gameState == 'charging' then
    self:_updateCharging(dt)
  end
  
  -- Update camera to focus on current tank or projectile
  self:_updateCamera()
end

function Game:_updateAiming(dt)
  local tank = self.tanks[self.currentPlayer]
  
  -- Movement (corrected for proper camera perspective)
  if self.keys['left'] then
    tank:move(-self.moveSpeed * dt, self.terrain)  -- Move negative X (left on screen)
  elseif self.keys['right'] then
    tank:move(self.moveSpeed * dt, self.terrain)   -- Move positive X (right on screen)
  end
  
  -- Aiming
  if self.keys['up'] then
    tank:aim(self.aimSpeed * dt)
  elseif self.keys['down'] then
    tank:aim(-self.aimSpeed * dt)
  end
end

function Game:_updateCharging(dt)
  self.chargeTime = self.chargeTime + dt
  if self.chargeTime > self.maxChargeTime then
    self.chargeTime = self.maxChargeTime
  end
end

function Game:_updateCamera()
  -- Always ensure both tanks are visible
  self.camera:updateToShowBothTanks(self.tanks[1], self.tanks[2])
end

function Game:_fire()
  local tank = self.tanks[self.currentPlayer]
  local power = self.minPower + (self.maxPower - self.minPower) * (self.chargeTime / self.maxChargeTime)
  
  local tipX, tipY = tank:barrelTip()
  local vx = math.cos(tank.angle) * power
  local vy = math.sin(tank.angle) * power
  
  -- Create muzzle flash at barrel tip
  self.muzzleFlash = {
    x = tipX,
    y = tipY,
    z = 0,
    timer = self.muzzleFlashDuration,
    intensity = 1.0
  }
  
  self.projectile = Projectile({
    x = tipX,
    y = tipY,
    vx = vx,
    vy = vy
  })
  
  self.gameState = 'firing'
  self.chargeTime = 0
end

function Game:_handleCollision(collision)
  -- Create impact effect at collision point
  self.impactEffect = {
    x = collision.x,
    y = collision.y,
    z = 0,
    timer = self.impactDuration,
    particles = {}
  }
  
  -- Generate impact particles
  for i = 1, 12 do
    local angle = (i / 12) * math.pi * 2
    local speed = 5 + math.random() * 10
    table.insert(self.impactEffect.particles, {
      x = collision.x,
      y = collision.y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed + math.random() * 5,
      life = 1.0,
      size = 0.2 + math.random() * 0.3
    })
  end
  
  if collision.type == 'tank' then
    collision.tank.health = collision.tank.health - 50
    if collision.tank.health <= 0 then
      -- Game over
      self.winner = (collision.tank == self.tanks[1]) and 2 or 1
      self.gameState = 'gameover'
    end
  end
end

function Game:_nextTurn()
  if self.gameState ~= 'gameover' then
    self.currentPlayer = (self.currentPlayer == 1) and 2 or 1
    self.gameState = 'aiming'
  end
end

function Game:draw(pass)
  -- Set up camera
  self.camera:apply(pass)
  
  -- Draw terrain (color set in terrain draw method)
  self.terrain:draw(pass)
  
  -- Draw tanks
  for _, tank in ipairs(self.tanks) do
    tank:draw(pass)
  end
  
  -- Draw projectile
  if self.projectile then
    self.projectile:draw(pass)
  end
  
  -- Draw muzzle flash
  if self.muzzleFlash then
    local flash = self.muzzleFlash
    local alpha = flash.intensity
    -- Bright yellow-white flash
    pass:setColor(1, 1, 0.8, alpha)
    pass:sphere(flash.x, flash.y, flash.z, 0.8 * flash.intensity)
    
    -- Outer glow effect
    pass:setColor(1, 0.6, 0.2, alpha * 0.5)
    pass:sphere(flash.x, flash.y, flash.z, 1.5 * flash.intensity)
  end
  
  -- Draw impact effects
  if self.impactEffect then
    local effect = self.impactEffect
    
    -- Draw explosion flash
    local progress = 1 - (effect.timer / self.impactDuration)
    local flashIntensity = math.max(0, 1 - progress * 3)  -- Quick bright flash
    if flashIntensity > 0 then
      pass:setColor(1, 0.8, 0.4, flashIntensity * 0.8)
      pass:sphere(effect.x, effect.y, effect.z, 2 * flashIntensity)
    end
    
    -- Draw particles
    for _, particle in ipairs(effect.particles) do
      if particle.life > 0 then
        local alpha = particle.life * 0.9
        -- Orange sparks
        pass:setColor(1, 0.6 + particle.life * 0.4, 0.2, alpha)
        pass:sphere(particle.x, particle.y, 0, particle.size * particle.life)
      end
    end
  end
  
  -- Reset color
  pass:setColor(1, 1, 1)
  
  -- Restore camera transform
  self.camera:restore(pass)
  
  -- Draw UI overlay
  self:_drawUI(pass)
end

function Game:_drawUI(pass)
  -- This is a simple approach - in a real game you'd want proper 2D UI
  -- For now, just draw some 3D text in world space
  
  local tank = self.tanks[self.currentPlayer]
  local uiY = 50
  
  -- Player indicator
  pass:setColor(1, 1, 1)
  -- You would normally use pass:text() here, but LÖVR text is complex
  -- For now, just show charge bar if charging
  
  -- Show which player is active with a small indicator
  local tank = self.tanks[self.currentPlayer]
  
  -- Active player indicator (small bright box above tank)
  pass:setColor(1, 1, 0) -- Yellow indicator
  pass:box(tank.x, tank.y + tank.bodyHeight + 1.2, 0, 0.5, 0.3, 0.1)
  
  -- Show charge bar only when charging
  if self.gameState == 'charging' then
    local barWidth = 0.8  
    local barHeight = 0.1  
    local chargeRatio = self.chargeTime / self.maxChargeTime
    
    -- Background
    pass:setColor(0.2, 0.2, 0.2)
    pass:box(tank.x, tank.y + tank.bodyHeight + 0.8, 0, barWidth, barHeight, 0.05)
    
    -- Charge fill
    pass:setColor(1, 1 - chargeRatio, 0) -- Yellow to red
    local fillWidth = barWidth * chargeRatio
    pass:box(tank.x - (barWidth - fillWidth) * 0.5, tank.y + tank.bodyHeight + 0.8, 0, fillWidth, barHeight * 0.8, 0.06)
  end
  
  if self.gameState == 'gameover' and self.winner then
    -- Simple winner display - in a real game you'd want proper text rendering
    pass:setColor(1, 1, 0)
    -- Would show "Player X Wins!" text here
  end
  
  pass:setColor(1, 1, 1)
end

function Game:keypressed(key)
  self.keys[key] = true
  
  if key == 'space' and self.gameState == 'aiming' then
    self.gameState = 'charging'
    self.chargeTime = 0
  elseif key == 'r' and self.gameState == 'gameover' then
    -- Restart game
    self:init()
  end
end

function Game:keyreleased(key)
  self.keys[key] = false
  
  if key == 'space' and self.gameState == 'charging' then
    self:_fire()
  end
end

return Game