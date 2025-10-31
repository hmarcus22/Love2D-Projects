local Class = require 'hump.class'

local Tank = Class:extend()

function Tank:init(opts)
  opts = opts or {}
  self.color = opts.color or { 0.2, 0.8, 0.3 }
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.z = 0
  self.radius = opts.radius or 4.0  -- Double again: was 2.0
  self.bodyHeight = self.radius * 1.2  -- Slightly taller than wide
  self.barrelLength = 8.0  -- Double: was 4.0
  self.barrelThickness = 0.8  -- Double: was 0.4
  self.angle = opts.angle or math.rad(45)
  self.dir = opts.dir or 1 -- 1 faces right, -1 faces left
  self.moveSpeed = opts.moveSpeed or 10
  self.health = 100
end

function Tank:update(dt, terrain)
  -- snap y to terrain
  self.y = terrain:heightAt(self.x)
end

function Tank:move(dx, terrain)
  self.x = self.x + dx
  -- clamp to world bounds
  local halfW = (terrain.width * 0.5) - 1.0
  if self.x < -halfW then self.x = -halfW end
  if self.x > halfW then self.x = halfW end
  
  -- Always update Y to follow terrain height
  self.y = terrain:heightAt(self.x)
end

function Tank:aim(dAngle)
  if self.dir > 0 then
    -- Right-facing tank: normal angle change (up increases, down decreases)
    self.angle = self.angle + dAngle
    -- Clamp: 5° to 85° (pointing right and up)
    local minA = math.rad(5)
    local maxA = math.rad(85)
    self.angle = math.max(minA, math.min(maxA, self.angle))
  else
    -- Left-facing tank: invert angle change (up decreases, down increases)
    self.angle = self.angle - dAngle
    -- Clamp: 95° to 175° (pointing left and up)
    local minA = math.rad(95)
    local maxA = math.rad(175)
    self.angle = math.max(minA, math.min(maxA, self.angle))
  end
end

function Tank:barrelTip()
  local bx = self.x
  local by = self.y + self.bodyHeight
  local a = self.angle
  local dx = math.cos(a) * self.barrelLength
  local dy = math.sin(a) * self.barrelLength
  return bx + dx, by + dy
end

function Tank:draw(pass)
  -- Tank body - main hull
  pass:setColor(self.color[1], self.color[2], self.color[3], 1.0)
  local bodyWidth = 7.0
  local bodyDepth = 4.0
  pass:box(self.x, self.y + self.bodyHeight * 0.5, self.z, bodyWidth, self.bodyHeight, bodyDepth)

  -- Tank turret (smaller box on top)
  local turretSize = 4.0
  pass:setColor(self.color[1] * 0.8, self.color[2] * 0.8, self.color[3] * 0.8, 1.0) -- Slightly darker
  pass:box(self.x, self.y + self.bodyHeight + 1.0, self.z, turretSize, 2.0, turretSize)

  -- Main cannon barrel - use the tank's actual angle directly
  local bx = self.x
  local by = self.y + self.bodyHeight + 1.0  -- From turret center
  local length = self.barrelLength
  
  -- Use the actual angle (aiming logic already handles direction)
  local displayAngle = self.angle
  
  -- Calculate barrel position accounting for rotation
  local barrelCenterX = bx + math.cos(displayAngle) * (length * 0.5)
  local barrelCenterY = by + math.sin(displayAngle) * (length * 0.5)
  
  -- Create proper rotation matrix for the barrel
  pass:push()
  pass:translate(barrelCenterX, barrelCenterY, self.z)
  pass:rotate(0, 0, 1, displayAngle)  -- Rotate around Z axis
  
  -- Draw barrel (now centered at origin after transform)
  pass:setColor(0.3, 0.3, 0.3, 1.0) -- Dark gray barrel
  pass:box(0, 0, 0, length, self.barrelThickness, self.barrelThickness)
  
  -- Barrel tip (muzzle)
  pass:setColor(0.1, 0.1, 0.1, 1.0) -- Very dark
  pass:box(length * 0.4, 0, 0, length * 0.2, self.barrelThickness * 1.2, self.barrelThickness * 1.2)
  
  pass:pop()

  -- Tank tracks/treads (decorative boxes on sides)
  pass:setColor(0.2, 0.2, 0.2, 1.0) -- Dark gray tracks
  local trackWidth = 1.0
  local trackOffset = (bodyWidth + trackWidth) * 0.5
  -- Left track
  pass:box(self.x - trackOffset, self.y + self.bodyHeight * 0.3, self.z, trackWidth, self.bodyHeight * 0.6, bodyDepth * 1.1)
  -- Right track
  pass:box(self.x + trackOffset, self.y + self.bodyHeight * 0.3, self.z, trackWidth, self.bodyHeight * 0.6, bodyDepth * 1.1)

  -- Health bar (positioned above turret)
  local hpw = bodyWidth
  local hpratio = math.max(0, math.min(1, self.health / 100))
  pass:setColor(0.1, 0.1, 0.1, 1.0)
  pass:box(self.x, self.y + self.bodyHeight + 3.5, self.z, hpw, 0.6, 0.4)
  
  -- Health fill (green to red based on health)
  local healthR = 1 - hpratio
  local healthG = hpratio
  pass:setColor(healthR, healthG, 0.1, 1.0)
  pass:box(self.x - (hpw * (1 - hpratio)) * 0.5, self.y + self.bodyHeight + 3.5, self.z, hpw * hpratio, 0.5, 0.5)

  -- Reset color
  pass:setColor(1, 1, 1, 1)
end

return Tank

