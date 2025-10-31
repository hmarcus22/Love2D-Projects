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
  self.minZ = 50   -- Much closer minimum for better tank visibility
  -- maxZ will be calculated based on terrain width to prevent seeing world's end
  self.maxZ = 800  -- Will be overridden by setTerrainBounds()
  
  -- Terrain dimensions (will be set by setTerrainBounds)
  self.terrainWidth = 600  -- Default, will be updated
end

function Camera:setTerrainBounds(terrainWidth)
  self.terrainWidth = terrainWidth
  -- Calculate max distance needed to show full terrain width
  -- Using field of view to calculate required distance
  local halfFOV = self.fovy * 0.5
  local requiredDistance = (terrainWidth * 0.6) / math.tan(halfFOV)
  self.maxZ = math.max(600, requiredDistance) -- At least 600, but scale with terrain
  
  print("Camera bounds set - minZ:", self.minZ, "maxZ:", self.maxZ, "terrain width:", terrainWidth)
end

function Camera:setLookAt(px, py, pz, tx, ty, tz)
  self.position.x, self.position.y, self.position.z = px, py, pz
  self.target.x, self.target.y, self.target.z = tx, ty, tz
end

function Camera:updateToShowBothTanks(tank1, tank2)
  -- Calculate the dynamic midpoint between both tanks (X-axis only)
  local centerX = (tank1.x + tank2.x) / 2
  -- Don't follow Y-axis - keep camera at fixed height
  
  -- Calculate horizontal distance between tanks for zoom
  local tankDistance = math.abs(tank1.x - tank2.x)
  
  -- Camera distance: close when tanks are together, far when they're apart
  local baseDistance = 100  -- Good starting view
  local zoomFactor = tankDistance * 0.5  -- Zoom out as tanks spread apart
  local cameraDistance = math.max(self.minZ, math.min(self.maxZ, baseDistance + zoomFactor))
  
  -- Store old position to see if it changes
  local oldX = self.position.x
  
  -- Position camera to look at the dynamic midpoint (X-axis only)
  self.position.x = centerX     -- FOLLOW the midpoint horizontally
  self.position.y = 50          -- Lower camera position
  self.position.z = cameraDistance  -- Back from the midpoint
  
  -- Look AT a point ABOVE the midpoint to shift terrain toward bottom of screen
  self.target.x = centerX       -- LOOK AT the midpoint horizontally
  self.target.y = 40            -- LOOK UP to shift terrain down on screen
  self.target.z = 0             -- Look at ground level
  
  -- Debug: Print camera position to verify Y changes
  print(string.format("CAMERA Y-POS: %.1f, TARGET Y: %.1f", self.position.y, self.target.y))
  
  -- Only show significant camera changes
  if math.abs(centerX - oldX) > 1.0 then
    print(string.format("CAMERA MOVED: X %.1f->%.1f (Tank1:%.1f Tank2:%.1f)", 
                        oldX, centerX, tank1.x, tank2.x))
  end
end

function Camera:apply(pass)
  -- Use LÖVR's built-in look-at functionality for proper camera transforms
  pass:push()
  
  -- Create vec3 objects for lookAt function
  local eye = lovr.math.newVec3(self.position.x, self.position.y, self.position.z)
  local target = lovr.math.newVec3(self.target.x, self.target.y, self.target.z)
  local up = lovr.math.newVec3(0, 1, 0)
  
  -- Create a proper view matrix using lookAt
  local viewMatrix = lovr.math.newMat4()
  viewMatrix:lookAt(eye, target, up)
  
  -- Apply the view transformation
  pass:transform(viewMatrix)
end

function Camera:restore(pass)
  pass:pop()
end

return Camera

