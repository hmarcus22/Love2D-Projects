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

function Terrain:createCrater(x, y, radius)
  -- Create a crater by reducing terrain height in the affected area
  local craterDepth = radius * 0.8  -- Crater depth proportional to radius
  
  -- Find the range of terrain samples affected by the crater
  local leftX = x - radius
  local rightX = x + radius
  
  -- Store crater information for visual enhancement
  if not self.craters then
    self.craters = {}
  end
  
  table.insert(self.craters, {
    x = x,
    y = y,
    radius = radius,
    depth = craterDepth
  })
  
  for i = 1, self.samples do
    local sampleX = (i - 1) / (self.samples - 1) * self.width - self.width / 2
    
    -- Check if this sample is within crater radius
    if sampleX >= leftX and sampleX <= rightX then
      local distanceFromCenter = math.abs(sampleX - x)
      
      if distanceFromCenter <= radius then
        -- Calculate crater depth using a smooth falloff (inverted parabola)
        local normalizedDistance = distanceFromCenter / radius
        local depthMultiplier = 1 - (normalizedDistance * normalizedDistance)
        local actualDepth = craterDepth * depthMultiplier
        
        -- Reduce terrain height (but don't go below minimum)
        self.heights[i] = math.max(2, self.heights[i] - actualDepth)
      end
    end
  end
  
  print(string.format("Created crater at X:%.1f, radius:%.1f, depth:%.1f", x, radius, craterDepth))
end

function Terrain:_drawCraterDetails(pass)
  -- Draw crater-specific visual enhancements (debris only, no dark circles)
  if not self.craters then return end
  
  for _, crater in ipairs(self.craters) do
    -- Add some debris around crater edge (but no dark crater floor)
    local numDebris = math.floor(crater.radius * 0.3)
    for i = 1, numDebris do
      local angle = (i / numDebris) * math.pi * 2 + math.random() * 0.5
      local distance = crater.radius * (0.7 + math.random() * 0.5)
      local debrisX = crater.x + math.cos(angle) * distance
      local debrisY = self:heightAt(debrisX)
      
      if debrisY > 2 then  -- Only place debris on existing terrain
        -- Small debris chunks (rock/dirt)
        pass:setColor(0.3, 0.2, 0.1)
        local size = 0.3 + math.random() * 0.6
        pass:box(debrisX, debrisY + size * 0.5, 0, size, size, size)
      end
    end
  end
end

function Terrain:draw(pass)
  -- Draw the actual terrain segments with enhanced visuals
  local segment = self.width / (self.samples - 1)
  local z = 0
  local depth = self.depth
  
  for i = 1, self.samples - 1 do
    local x = -self.width / 2 + (i - 1) * segment
    local h = self.heights[i]
    -- Ensure minimum height to prevent gaps, and always draw terrain segments
    local minHeight = 5  -- Minimum terrain height to prevent gaps
    local actualHeight = math.max(h, minHeight)
    
    local cx = x + segment * 0.5
    -- Make terrain segments extend way down below the surface
    local terrainHeight = actualHeight + 120  -- Add 120 units of height below surface
    local cy = actualHeight * 0.5 - 60  -- Center the box so it extends down from surface
    
    -- Enhanced terrain coloring based on height and position
    local heightRatio = math.min(1.0, actualHeight / self.maxHeight)
    
    -- Surface section (uniform grass layer thickness)
    local grassThickness = 3  -- Uniform grass layer thickness
    local surfaceHeight = grassThickness
    local surfaceY = actualHeight - grassThickness * 0.5
    
    -- Surface color: grass-like green-brown gradient
    local grassR = 0.3 + heightRatio * 0.3  -- 0.3 to 0.6
    local grassG = 0.5 + heightRatio * 0.3  -- 0.5 to 0.8  
    local grassB = 0.2 + heightRatio * 0.1  -- 0.2 to 0.3
    pass:setColor(grassR, grassG, grassB)
    pass:box(cx, surfaceY, z, segment, surfaceHeight, depth)
    
    -- Underground section (below grass layer)
    local undergroundHeight = terrainHeight - grassThickness
    if undergroundHeight > 0 then
      local undergroundY = actualHeight - grassThickness - undergroundHeight * 0.5
      
      -- Underground color: darker brown-red earth
      local earthR = 0.4 + heightRatio * 0.2  -- 0.4 to 0.6
      local earthG = 0.25 + heightRatio * 0.15  -- 0.25 to 0.4
      local earthB = 0.1 + heightRatio * 0.1   -- 0.1 to 0.2
      pass:setColor(earthR, earthG, earthB)
      pass:box(cx, undergroundY, z, segment, undergroundHeight, depth)
    end
  end
  
  -- Add some decorative surface details
  self:_drawSurfaceDetails(pass)
  
  -- Draw crater-specific enhancements
  self:_drawCraterDetails(pass)
  
  -- Reset color
  pass:setColor(1, 1, 1)
end

function Terrain:_drawSurfaceDetails(pass)
  -- Add small decorative elements on the terrain surface
  local numDetails = 15  -- Number of decorative elements
  
  for i = 1, numDetails do
    local x = (math.random() - 0.5) * self.width * 0.8  -- Don't place at edges
    local surfaceHeight = self:heightAt(x)
    
    if surfaceHeight > 5 then  -- Only on reasonably high terrain
      local detailType = math.random(3)
      
      if detailType == 1 then
        -- Small rocks
        pass:setColor(0.5, 0.4, 0.3)
        local size = 0.5 + math.random() * 1.0
        pass:box(x, surfaceHeight + size * 0.5, 0, size, size, size)
      elseif detailType == 2 then
        -- Grass tufts (small green cylinders)
        pass:setColor(0.2, 0.6, 0.3)
        local height = 1 + math.random() * 2
        pass:cylinder(x, surfaceHeight + height * 0.5, 0, 0.3, height)
      else
        -- Small bushes (green spheres)
        pass:setColor(0.3, 0.5, 0.2)
        local size = 0.8 + math.random() * 0.8
        pass:sphere(x, surfaceHeight + size * 0.5, 0, size)
      end
    end
  end
end

return Terrain

