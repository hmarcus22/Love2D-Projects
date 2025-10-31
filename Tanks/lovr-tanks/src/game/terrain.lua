local Class = require 'hump.class'

local Terrain = Class:extend()

function Terrain:init(opts)
  opts = opts or {}
  self.width = opts.width or 200
  self.depth = opts.depth or 6
  self.samples = opts.samples or 128
  self.maxHeight = opts.maxHeight or 30
  self.offset = opts.seed or 123.456
  self.heights = {}
  self:_generate()
end

function Terrain:_fbm(x)
  -- Simple fractal noise for 1D height
  local n = 0
  local amp = 1
  local freq = 0.03
  for i = 1, 4 do
    n = n + amp * (lovr.math.noise(x * freq + self.offset, i * 37.1, 0) * 2 - 1)
    amp = amp * 0.5
    freq = freq * 2
  end
  return n
end

function Terrain:_generate()
  self.heights = {}
  for i = 0, self.samples - 1 do
    local x = (i / (self.samples - 1)) * self.width - self.width / 2
    local h = self:_fbm(x)
    self.heights[i + 1] = (self.maxHeight * 0.5) + h * (self.maxHeight * 0.5)
  end
end

function Terrain:heightAt(x)
  -- Linear interpolation between sample points
  local t = (x + self.width / 2) / self.width
  if t <= 0 then return self.heights[1] end
  if t >= 1 then return self.heights[#self.heights] end
  local f = (self.samples - 1) * t
  local i = math.floor(f)
  local fract = f - i
  local h1 = self.heights[i + 1]
  local h2 = self.heights[i + 2]
  return h1 + (h2 - h1) * fract
end

function Terrain:draw(pass)
  -- Draw the actual terrain segments (baseplate removed - terrain extends down instead)
  local segment = self.width / (self.samples - 1)
  local z = 0
  local depth = self.depth
  
  pass:setColor(0.6, 0.4, 0.2) -- Brown terrain color
  
  for i = 1, self.samples - 1 do
    local x = -self.width / 2 + (i - 1) * segment
    local h = self.heights[i]
    if h > 0.1 then
      local cx = x + segment * 0.5
      -- Make terrain segments extend way down below the surface
      local terrainHeight = h + 120  -- Add 120 units of height below surface
      local cy = h * 0.5 - 60  -- Center the box so it extends down from surface
      pass:box(cx, cy, z, segment, terrainHeight, depth)
    end
  end
end

return Terrain

