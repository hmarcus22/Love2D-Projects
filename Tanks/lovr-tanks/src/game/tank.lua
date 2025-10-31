local Class = require 'hump.class'

local Tank = Class:extend()

function Tank:init(opts)
  opts = opts or {}
  self.color = opts.color or { 0.2, 0.8, 0.3 }
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.z = 0
  self.radius = opts.radius or 1.2
  self.bodyHeight = self.radius
  self.barrelLength = 3.0
  self.barrelThickness = 0.4
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
  self.y = terrain:heightAt(self.x)
end

function Tank:aim(dAngle)
  self.angle = self.angle + dAngle
  -- Clamp between 5° and 85° w.r.t facing
  local minA = math.rad(5)
  local maxA = math.rad(85)
  if self.dir < 0 then
    -- mirror around pi
    local a = math.pi - self.angle
    a = math.max(minA, math.min(maxA, a))
    self.angle = math.pi - a
  else
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
  pass:setColor(self.color)
  -- Body
  pass:box(self.x, self.y + self.bodyHeight * 0.5, self.z, 2.4, self.bodyHeight, 1.2)

  -- Barrel (as a thin box rotated around Z)
  local bx = self.x
  local by = self.y + self.bodyHeight
  local length = self.barrelLength
  -- Create rotation quaternion around Z axis for LÖVR
  local q = lovr.math.quat(0, 0, math.sin(self.angle/2), math.cos(self.angle/2))
  -- center offset so that box starts at turret top
  local cx = bx + math.cos(self.angle) * (length * 0.5)
  local cy = by + math.sin(self.angle) * (length * 0.5)
  pass:box(cx, cy, self.z, length, self.barrelThickness, self.barrelThickness, q)

  -- Health bar (simple)
  local hpw = 2.4
  local hpratio = math.max(0, math.min(1, self.health / 100))
  pass:setColor(0.1, 0.1, 0.1)
  pass:box(self.x, self.y + self.bodyHeight + 1.0, self.z, hpw, 0.2, 0.1)
  pass:setColor(0.8, 0.1, 0.1)
  pass:box(self.x - (hpw * (1 - hpratio)) * 0.5, self.y + self.bodyHeight + 1.0, self.z, hpw * hpratio, 0.18, 0.12)

  pass:setColor(1, 1, 1)
end

return Tank

