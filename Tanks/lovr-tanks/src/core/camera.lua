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
  
  -- Camera bounds for ensuring both tanks are visible (wider range for zoom)
  self.minX = -400
  self.maxX = 400
  self.minZ = 50   -- Much closer minimum for better tank visibility
  self.maxZ = 600  -- Farthest zoom (when tanks are apart)
end

function Camera:setLookAt(px, py, pz, tx, ty, tz)
  self.position.x, self.position.y, self.position.z = px, py, pz
  self.target.x, self.target.y, self.target.z = tx, ty, tz
end

function Camera:updateToShowBothTanks(tank1, tank2)
  -- Calculate the center point between both tanks (X only)
  local centerX = (tank1.x + tank2.x) / 2
  
  -- Calculate distance between tanks for zoom adjustment
  local tankDistance = math.abs(tank1.x - tank2.x)
  
  -- Camera distance optimized to keep tanks clearly visible
  -- Starting tank distance is ~300 units, so base should accommodate this
  local baseDistance = 60         -- Close enough for tanks to be clearly visible
  local zoomFactor = tankDistance * 0.8  -- Gentle zoom as tanks spread apart
  local cameraDistance = math.max(self.minZ, math.min(self.maxZ, baseDistance + zoomFactor))
  
  -- Camera position: POSITIVE Z to look from behind
  self.position.x = centerX    -- Follow tank center horizontally
  self.position.y = 40         -- Fixed height - never changes  
  self.position.z = cameraDistance  -- Dynamic zoom based on tank distance
  
  -- Look target: look toward the battlefield
  self.target.x = centerX      -- Look at tank center horizontally  
  self.target.y = 0            -- Fixed look height - never changes
  self.target.z = 0            -- Look at the battlefield plane
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

