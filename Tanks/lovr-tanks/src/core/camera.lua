local Class = require 'hump.class'

local Camera = Class:extend()

function Camera:init(opts)
  opts = opts or {}
  self.fovy = opts.fovy or math.rad(45) -- Slightly wider field of view
  self.near = opts.near or 0.1
  self.far = opts.far or 2000
  
  -- Camera positioned for side-view tanks game
  self.position = { x = 0, y = 60, z = 200 } -- Higher and further back
  self.target = { x = 0, y = 20, z = 0 }
  self.up = { x = 0, y = 1, z = 0 }
  
  -- Camera bounds for ensuring both tanks are visible
  self.minX = -400
  self.maxX = 400
  self.minZ = 150  -- Minimum distance to keep tanks visible
  self.maxZ = 300  -- Maximum distance
end

function Camera:setLookAt(px, py, pz, tx, ty, tz)
  self.position.x, self.position.y, self.position.z = px, py, pz
  self.target.x, self.target.y, self.target.z = tx, ty, tz
end

function Camera:updateToShowBothTanks(tank1, tank2)
  -- Calculate the center point between both tanks
  local centerX = (tank1.x + tank2.x) / 2
  local centerY = (tank1.y + tank2.y) / 2
  
  -- Calculate distance between tanks
  local tankDistance = math.abs(tank1.x - tank2.x)
  
  -- Zoom in more for closer, more engaging view
  local terrainWidth = 600
  -- Reduced multipliers for closer camera
  local baseDistance = terrainWidth * 0.5  -- Was 0.8 - much closer now
  local extraDistance = tankDistance * 0.4  -- Slightly more responsive to tank distance
  local cameraDistance = math.max(self.minZ, math.min(self.maxZ, baseDistance + extraDistance))
  
  -- Position camera closer and lower for more engaging view
  self.position.x = centerX
  self.position.y = centerY + 25  -- Lower: was 40
  self.position.z = cameraDistance
  
  -- Look at the battlefield center
  self.target.x = centerX
  self.target.y = centerY - 2  -- Look slightly below center
  self.target.z = 0
end

function Camera:apply(pass)
  -- Simplified camera setup - LÖVR handles viewport automatically
  -- Apply camera transform
  pass:push()
  
  -- Create view matrix manually
  local dx = self.target.x - self.position.x
  local dy = self.target.y - self.position.y
  local dz = self.target.z - self.position.z
  local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
  
  if distance > 0 then
    -- Normalize direction
    dx, dy, dz = dx/distance, dy/distance, dz/distance
    
    -- Apply camera transform
    pass:translate(-self.position.x, -self.position.y, -self.position.z)
    
    -- Rotate to look at target
    local yaw = math.atan2(dx, dz)
    local pitch = math.asin(-dy)
    
    pass:rotate(-pitch, 1, 0, 0)  -- Pitch rotation
    pass:rotate(-yaw, 0, 1, 0)    -- Yaw rotation
  else
    pass:translate(-self.position.x, -self.position.y, -self.position.z)
  end
end

function Camera:restore(pass)
  pass:pop()
end

return Camera

