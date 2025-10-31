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
  local oldX = self.x
  self.x = self.x + dx
  -- clamp to world bounds
  local halfW = (terrain.width * 0.5) - 1.0
  if self.x < -halfW then self.x = -halfW end
  if self.x > halfW then self.x = halfW end
  
  -- Always update Y to follow terrain height
  self.y = terrain:heightAt(self.x)
  
  -- No debug spam - let camera debug show the movement
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

  -- Main cannon barrel - manually build from turret to muzzle without rotation
  local bx = self.x
  local by = self.y + self.bodyHeight + 1.0  -- From turret center (anchor point)
  local length = self.barrelLength
  
  -- Use the actual angle (aiming logic already handles direction)
  local displayAngle = self.angle
  
  -- Calculate barrel end position (where muzzle should be)
  local barrelEndX = bx + math.cos(displayAngle) * length
  local barrelEndY = by + math.sin(displayAngle) * length
  
  -- Calculate barrel direction and positioning manually
  local dx = barrelEndX - bx  -- X distance from turret to muzzle
  local dy = barrelEndY - by  -- Y distance from turret to muzzle
  local barrelMidX = bx + dx * 0.5  -- Barrel center X
  local barrelMidY = by + dy * 0.5  -- Barrel center Y
  
  -- Calculate the angle needed to point from turret to muzzle
  local barrelRotation = math.atan2(dy, dx)
  
  -- Draw barrel using the calculated rotation
  pass:setColor(0.3, 0.3, 0.3, 1.0) -- Dark gray barrel
  pass:push()
  pass:translate(barrelMidX, barrelMidY, self.z)  
  pass:rotate(barrelRotation, 0, 0, 1)  -- Rotate by calculated angle around Z-axis
  
  -- Draw barrel extending along X-axis after rotation
  pass:box(0, 0, 0, length, self.barrelThickness * 0.6, self.barrelThickness * 1.4)
  
  -- Bright red stripe to verify rotation
  pass:setColor(1.0, 0.0, 0.0, 1.0) -- Bright red stripe
  pass:box(0, self.barrelThickness * 0.8, 0, length * 0.3, self.barrelThickness * 0.4, self.barrelThickness * 2.0)
  
  pass:pop()
  
  -- Muzzle at the calculated end position
  pass:setColor(0.1, 0.1, 0.1, 1.0) -- Very dark
  pass:box(barrelEndX, barrelEndY, self.z, self.barrelThickness * 1.5, self.barrelThickness * 1.5, self.barrelThickness * 1.5)

  -- Tank tracks/treads (decorative boxes on sides)
  pass:setColor(0.2, 0.2, 0.2, 1.0) -- Dark gray tracks
  local trackWidth = 1.0
  local trackOffset = (bodyWidth + trackWidth) * 0.5
  -- Left track
  pass:box(self.x - trackOffset, self.y + self.bodyHeight * 0.3, self.z, trackWidth, self.bodyHeight * 0.6, bodyDepth * 1.1)
  -- Right track
  pass:box(self.x + trackOffset, self.y + self.bodyHeight * 0.3, self.z, trackWidth, self.bodyHeight * 0.6, bodyDepth * 1.1)

  -- Reset color
  pass:setColor(1, 1, 1, 1)
end

return Tank

