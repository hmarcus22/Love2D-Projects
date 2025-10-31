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
  
  -- Create two tanks with intuitive positioning for correct camera view
  local leftX = -self.terrain.width * 0.25   -- Tank 1 at NEGATIVE X (appears LEFT on screen)
  local rightX = self.terrain.width * 0.25   -- Tank 2 at POSITIVE X (appears RIGHT on screen)
  
  self.tanks = {
    Tank({  -- Tank 1 - Green tank - appears LEFT on screen
      x = leftX,   -- Negative X
      y = self.terrain:heightAt(leftX),
      color = { 0.2, 0.8, 0.3 },  -- Green
      dir = 1,   -- Faces right (toward other tank)
      angle = math.rad(45)   -- Points toward other tank
    }),
    Tank({  -- Tank 2 - Red tank - appears RIGHT on screen
      x = rightX,  -- Positive X
      y = self.terrain:heightAt(rightX),
      color = { 0.8, 0.2, 0.3 },  -- Red
      dir = -1,  -- Faces left (toward other tank)
      angle = math.rad(135)  -- Points toward other tank
    })
  }
  
  -- Player health system
  self.maxHealth = 100
  self.playerHealth = { self.maxHealth, self.maxHealth }  -- Health for player 1 and 2
  self.playerNames = { "Player 1", "Player 2" }
  
  self.currentPlayer = 1  -- Start with Player 1 (green tank, left side)
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
  
  -- Handle tank damage
  if collision.type == 'tank' then
    -- Find which player was hit
    local hitPlayer = nil
    for i, tank in ipairs(self.tanks) do
      if tank == collision.tank then
        hitPlayer = i
        break
      end
    end
    
    if hitPlayer then
      -- Deal damage (25% of max health per hit)
      local damage = math.floor(self.maxHealth * 0.25)
      self.playerHealth[hitPlayer] = math.max(0, self.playerHealth[hitPlayer] - damage)
      
      -- Check for game over
      if self.playerHealth[hitPlayer] <= 0 then
        self.winner = (hitPlayer == 1) and 2 or 1  -- Other player wins
        self.gameState = 'gameover'
      end
    end
  elseif collision.type == 'terrain' then
    -- Create crater in terrain for destructible terrain effect
    local craterRadius = 8 + math.random() * 4  -- Random crater size between 8-12 units
    self.terrain:createCrater(collision.x, collision.y, craterRadius)
    
    -- Update tank positions if they're affected by terrain changes
    for i, tank in ipairs(self.tanks) do
      local newGroundHeight = self.terrain:heightAt(tank.x)
      tank.y = newGroundHeight
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
end

-- Proper 2D HUD using lovr.mirror callback
function Game:drawHUD(pass)
  -- Get actual window dimensions
  local pixwidth = lovr.system.getWindowWidth()
  local pixheight = lovr.system.getWindowHeight()
  
  if not pixwidth or not pixheight then
    return -- Skip HUD if dimensions unavailable
  end
  
  -- Set up screen-space coordinate system
  local aspect = pixwidth / pixheight
  local height = 2  -- Screen height in coordinate units
  local width = aspect * height
  
  -- Create orthographic projection matrix for screen space
  local matrix = lovr.math.newMat4():orthographic(-width/2, width/2, -height/2, height/2, -1, 1)
  
  -- Create font for text rendering (scale for screen space)
  local font = lovr.graphics.getDefaultFont()
  local textScale = height / pixheight * 40  -- Reduced from 80 to match smaller HUD panels
  
  -- Switch to 2D screen space
  pass:origin()
  pass:setViewPose(1, lovr.math.newMat4())
  pass:setProjection(1, matrix)
  pass:setDepthTest() -- Clear depth buffer from 3D scene
  
  self:_draw2DHUD(pass, width, height, font, textScale)
end

function Game:_draw2DHUD(pass, width, height, font, textScale)
  -- HUD layout constants
  local margin = 0.1
  local panelWidth = 0.6  -- Half the original size
  local panelHeight = 0.15  -- Half the original size
  local barWidth = 0.4  -- Half the original size
  local barHeight = 0.04  -- Half the original size
  
  -- Set font for text rendering
  pass:setFont(font)
  
  -- === Player 1 HUD (Left side) ===
  local p1X = -width/2 + margin + panelWidth/2
  local p1Y = -height/2 + margin + panelHeight/2
  
  -- Player 1 background panel
  pass:setColor(0.1, 0.3, 0.1, 0.8)  -- Dark green
  pass:plane(p1X, p1Y, 0, panelWidth, panelHeight)
  
  -- Player 1 text label
  pass:setColor(0.9, 0.9, 0.9)  -- White text
  pass:text("Player 1", p1X, p1Y + panelHeight/4, 0.01, textScale)
  
  -- Player 1 health bar
  local healthRatio1 = self.playerHealth[1] / self.maxHealth
  -- Background
  pass:setColor(0.2, 0.1, 0.1)
  pass:plane(p1X, p1Y - panelHeight/4, 0.01, barWidth, barHeight)
  -- Fill
  if healthRatio1 > 0.6 then
    pass:setColor(0.2, 0.8, 0.3)  -- Green
  elseif healthRatio1 > 0.3 then
    pass:setColor(0.8, 0.8, 0.2)  -- Yellow
  else
    pass:setColor(0.8, 0.2, 0.2)  -- Red
  end
  local fillWidth1 = barWidth * healthRatio1
  if fillWidth1 > 0 then
    pass:plane(p1X - (barWidth - fillWidth1)/2, p1Y - panelHeight/4, 0.02, fillWidth1, barHeight * 0.8)
  end
  
  -- Player 1 active indicator
  if self.currentPlayer == 1 then
    pass:setColor(1, 1, 0, 0.8)  -- Yellow
    pass:plane(p1X - panelWidth/2 - 0.05, p1Y, 0.02, 0.05, panelHeight)
  end
  
  -- === Player 2 HUD (Right side) ===
  local p2X = width/2 - margin - panelWidth/2
  local p2Y = -height/2 + margin + panelHeight/2
  
  -- Player 2 background panel
  pass:setColor(0.3, 0.1, 0.1, 0.8)  -- Dark red
  pass:plane(p2X, p2Y, 0, panelWidth, panelHeight)
  
  -- Player 2 text label
  pass:setColor(0.9, 0.9, 0.9)  -- White text
  pass:text("Player 2", p2X, p2Y + panelHeight/4, 0.01, textScale)
  
  -- Player 2 health bar
  local healthRatio2 = self.playerHealth[2] / self.maxHealth
  -- Background
  pass:setColor(0.2, 0.1, 0.1)
  pass:plane(p2X, p2Y - panelHeight/4, 0.01, barWidth, barHeight)
  -- Fill
  if healthRatio2 > 0.6 then
    pass:setColor(0.2, 0.8, 0.3)  -- Green
  elseif healthRatio2 > 0.3 then
    pass:setColor(0.8, 0.8, 0.2)  -- Yellow
  else
    pass:setColor(0.8, 0.2, 0.2)  -- Red
  end
  local fillWidth2 = barWidth * healthRatio2
  if fillWidth2 > 0 then
    pass:plane(p2X - (barWidth - fillWidth2)/2, p2Y - panelHeight/4, 0.02, fillWidth2, barHeight * 0.8)
  end
  
  -- Player 2 active indicator
  if self.currentPlayer == 2 then
    pass:setColor(1, 1, 0, 0.8)  -- Yellow
    pass:plane(p2X + panelWidth/2 + 0.05, p2Y, 0.02, 0.05, panelHeight)
  end
  
  -- === Central Charge Bar ===
  if self.gameState == 'charging' then
    local centerX = 0
    local centerY = height/2 - 0.4
    
    local chargeRatio = math.min(1.0, self.chargeTime / self.maxChargeTime)
    local chargeBarWidth = 1.0
    local chargeBarHeight = 0.1
    
    -- Charge bar background
    pass:setColor(0.1, 0.1, 0.1, 0.9)
    pass:plane(centerX, centerY, 0, chargeBarWidth, chargeBarHeight)
    
    -- Charge fill
    if chargeRatio < 0.7 then
      pass:setColor(0.2, 0.8, 0.3, 0.9)  -- Green
    elseif chargeRatio < 0.9 then
      pass:setColor(0.8, 0.8, 0.2, 0.9)  -- Yellow
    else
      pass:setColor(0.8, 0.2, 0.2, 0.9)  -- Red
    end
    
    local chargeFillWidth = chargeBarWidth * chargeRatio
    if chargeFillWidth > 0 then
      pass:plane(centerX - (chargeBarWidth - chargeFillWidth)/2, centerY, 0.01, chargeFillWidth, chargeBarHeight * 0.8)
    end
    
    -- Charge percentage text
    pass:setColor(1, 1, 1)
    local percentage = math.floor(chargeRatio * 100)
    pass:text(string.format("Power: %d%%", percentage), centerX, centerY - 0.15, 0.01, textScale * 0.8)
  end
  
  -- === Game Over Screen ===
  if self.gameState == 'gameover' and self.winner then
    local centerX = 0
    local centerY = 0
    
    -- Semi-transparent overlay
    pass:setColor(0, 0, 0, 0.7)
    pass:plane(centerX, centerY, 0.1, width, height)
    
    -- Winner panel
    pass:setColor(0.2, 0.2, 0.2, 0.9)
    pass:plane(centerX, centerY, 0.2, 2, 0.8)
    
    -- Winner text
    pass:setColor(1, 1, 1)
    local winnerText = string.format("Player %d Wins!", self.winner)
    pass:text(winnerText, centerX, centerY + 0.2, 0.3, textScale * 1.2)
    
    -- Restart instruction
    pass:setColor(0.8, 0.8, 0.8)
    pass:text("Press R to restart", centerX, centerY - 0.2, 0.3, textScale * 0.9)
  end
  
  -- Reset color
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