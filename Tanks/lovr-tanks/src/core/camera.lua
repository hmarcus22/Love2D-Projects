local Class = require 'hump.class'

local Camera = Class:extend()

function Camera:init(opts)
  opts = opts or {}
  self.fovy = opts.fovy or math.rad(60)
  self.near = opts.near or 0.1
  self.far = opts.far or 2000
  self.position = { x = 0, y = 40, z = 140 }
  self.target = { x = 0, y = 20, z = 0 }
  self.up = { x = 0, y = 1, z = 0 }
end

function Camera:setLookAt(px, py, pz, tx, ty, tz)
  self.position.x, self.position.y, self.position.z = px, py, pz
  self.target.x, self.target.y, self.target.z = tx, ty, tz
end

function Camera:apply(pass)
  -- Simplified LÖVR camera setup using transform matrix
  -- For desktop LÖVR, we can use the transform matrix approach
  pass:push()
  
  -- Create a view transform by translating and rotating the world
  -- First translate to move camera to origin
  pass:translate(-self.position.x, -self.position.y, -self.position.z)
  
  -- Calculate look direction for basic rotation
  local dx = self.target.x - self.position.x
  local dy = self.target.y - self.position.y
  local dz = self.target.z - self.position.z
  local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
  
  if distance > 0 then
    dx, dy, dz = dx/distance, dy/distance, dz/distance
    -- Simple rotation around Y axis for side-view camera
    local angle = math.atan2(dx, dz)
    pass:rotate(-angle, 0, 1, 0)
  end
end

function Camera:restore(pass)
  pass:pop()
end

return Camera

