local Class = require 'hump.class'

local Projectile = Class:extend()

function Projectile:init(opts)
  opts = opts or {}
  self.x = opts.x or 0
  self.y = opts.y or 0
  self.z = 0
  self.vx = opts.vx or 0
  self.vy = opts.vy or 0
  self.radius = opts.radius or 0.3
  self.alive = true
  self.color = { 0.9, 0.9, 0.2 }
  self.trail = {}
end

function Projectile:update(dt, terrain, tanks)
  if not self.alive then return end
  local g = 9.81
  -- Integrate
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  self.vy = self.vy - g * dt

  -- Record trail (cap length)
  table.insert(self.trail, { self.x, self.y })
  if #self.trail > 64 then table.remove(self.trail, 1) end

  -- Terrain collision
  local ground = terrain:heightAt(self.x)
  if self.y <= ground then
    self.alive = false
    return { type = 'terrain', x = self.x, y = ground }
  end

  -- Tank collisions (simple circle distance in XY)
  for _, tank in ipairs(tanks) do
    local dx = self.x - tank.x
    local dy = self.y - (tank.y + tank.bodyHeight * 0.5)
    local r = tank.radius + self.radius
    if dx * dx + dy * dy <= r * r then
      self.alive = false
      return { type = 'tank', tank = tank, x = self.x, y = self.y }
    end
  end
end

function Projectile:draw(pass)
  if not self.alive then return end
  pass:setColor(self.color)
  pass:sphere(self.x, self.y, self.z, self.radius)
  pass:setColor(1, 1, 1)
end

return Projectile

