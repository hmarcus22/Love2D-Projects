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
    width = 200,
    depth = 6,
    samples = 128,
    maxHeight = 30,
    seed = 42
  })
  
  -- Create two tanks at opposite ends
  local leftX = -self.terrain.width * 0.4
  local rightX = self.terrain.width * 0.4
  
  self.tanks = {
    Tank({
      x = leftX,
      y = self.terrain:heightAt(leftX),
      color = { 0.2, 0.8, 0.3 },
      dir = 1,
      angle = math.rad(45)
    }),
    Tank({
      x = rightX,
      y = self.terrain:heightAt(rightX),
      color = { 0.8, 0.2, 0.3 },
      dir = -1,
      angle = math.rad(135)
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
  
  -- Input state
  self.keys = {}
end

function Game:update(dt)
  Timer.update(dt)
  
  -- Update all tanks
  for _, tank in ipairs(self.tanks) do
    tank:update(dt, self.terrain)
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
  
  -- Movement
  if self.keys['left'] then
    tank:move(-self.moveSpeed * dt, self.terrain)
  elseif self.keys['right'] then
    tank:move(self.moveSpeed * dt, self.terrain)
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
  local focusX, focusY = 0, 20
  
  if self.projectile and self.projectile.alive then
    -- Follow projectile
    focusX = self.projectile.x
    focusY = self.projectile.y + 10
  else
    -- Focus on current tank
    local tank = self.tanks[self.currentPlayer]
    focusX = tank.x
    focusY = tank.y + 10
  end
  
  -- Side view camera position
  self.camera:setLookAt(
    focusX, focusY + 30, 140,  -- camera position
    focusX, focusY, 0          -- look at target
  )
end

function Game:_fire()
  local tank = self.tanks[self.currentPlayer]
  local power = self.minPower + (self.maxPower - self.minPower) * (self.chargeTime / self.maxChargeTime)
  
  local tipX, tipY = tank:barrelTip()
  local vx = math.cos(tank.angle) * power
  local vy = math.sin(tank.angle) * power
  
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
  
  -- Set terrain color and draw
  pass:setColor(0.6, 0.4, 0.2)
  self.terrain:draw(pass)
  
  -- Draw tanks
  for _, tank in ipairs(self.tanks) do
    tank:draw(pass)
  end
  
  -- Draw projectile
  if self.projectile then
    self.projectile:draw(pass)
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
  
  if self.gameState == 'charging' then
    -- Draw charge bar in 3D space above tank
    local barWidth = 4
    local barHeight = 0.5
    local chargeRatio = self.chargeTime / self.maxChargeTime
    
    -- Background
    pass:setColor(0.2, 0.2, 0.2)
    pass:box(tank.x, tank.y + tank.bodyHeight + 2, 0, barWidth, barHeight, 0.1)
    
    -- Charge fill
    pass:setColor(1, 1 - chargeRatio, 0) -- Yellow to red
    local fillWidth = barWidth * chargeRatio
    pass:box(tank.x - (barWidth - fillWidth) * 0.5, tank.y + tank.bodyHeight + 2, 0, fillWidth, barHeight * 0.8, 0.12)
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