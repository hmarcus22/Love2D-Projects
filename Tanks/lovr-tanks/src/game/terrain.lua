local Class = require 'hump.class'

local Terrain = Class:extend()

function Terrain:init(opts)
  opts = opts or {}
  self.width = opts.width or 200
  self.depth = opts.depth or 6
  self.samples = opts.samples or 512  -- Increased from 128 to 512 for higher resolution
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
  
  -- Generate static decorative elements once (to prevent flickering)
  self:_generateStaticDetails()
end

function Terrain:_generateStaticDetails()
  -- Pre-generate all decorative elements to prevent flickering
  self.staticDetails = {}
  self.environmentalFeatures = {}  -- Trees, water, paths
  local numDetails = 25
  
  -- Use a fixed seed for consistent decoration placement
  math.randomseed(42)  -- Fixed seed for reproducible results
  
  -- Generate basic decorative elements
  for i = 1, numDetails do
    local x = (math.random() - 0.5) * self.width * 0.85
    local surfaceHeight = self:heightAt(x)
    
    if surfaceHeight > 5 then
      -- Check if this area is rocky (same logic as terrain generation)
      local noiseX = math.floor(x * 0.05) * 20
      local colorNoise = lovr.math.noise(noiseX, 0, 123) * 2 - 1
      local heightRatio = math.min(1.0, surfaceHeight / self.maxHeight)
      local isRockyArea = (heightRatio > 0.7 and colorNoise > 0.2)
      
      local detail = {
        x = x,
        y = surfaceHeight,
        isRocky = isRockyArea,
        type = math.random(5),
        size = 0.3 + math.random() * 1.0,
        colorR = math.random(),
        colorG = math.random(),
        colorB = math.random()
      }
      
      table.insert(self.staticDetails, detail)
    end
  end
  
  -- Generate environmental features
  -- (Trees and water features removed for cleaner terrain)
  
  -- Restore random seed
  math.randomseed(os.time())
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
    
    -- Enhanced terrain coloring with texture variation
    local heightRatio = math.min(1.0, actualHeight / self.maxHeight)
    
    -- Add subtle color noise for texture variation (reduced and stabilized)
    local noiseX = math.floor(cx * 0.05) * 20  -- Larger, stable noise patches
    local colorNoise = lovr.math.noise(noiseX, 0, 123) * 2 - 1  -- -1 to 1
    local colorVariation = colorNoise * 0.08  -- Reduced variation to prevent flickering
    
    -- Determine if this is a rocky outcrop based on height and steepness
    local isRocky = false
    if i > 1 and i < self.samples - 1 then
      local prevHeight = math.max(self.heights[i-1], 5)
      local nextHeight = math.max(self.heights[i+1], 5)
      local steepness = math.abs(actualHeight - prevHeight) + math.abs(actualHeight - nextHeight)
      -- Rocky outcrops on steep slopes or very high terrain
      isRocky = (steepness > 12) or (heightRatio > 0.85 and colorNoise > 0.4)
    end
    
    -- Surface section (uniform grass layer thickness)
    local grassThickness = 3  -- Uniform grass layer thickness
    local surfaceHeight = grassThickness
    local surfaceY = actualHeight - grassThickness * 0.5
    
    if isRocky then
      -- Rocky outcrop colors (gray stone) - SURFACE LAYER ONLY
      local rockR = 0.4 + colorVariation * 0.2
      local rockG = 0.4 + colorVariation * 0.2
      local rockB = 0.5 + colorVariation * 0.15
      pass:setColor(rockR, rockG, rockB)
    else
      -- Surface color: grass-like green-brown gradient with variation
      local grassR = (0.3 + heightRatio * 0.3) + colorVariation
      local grassG = (0.5 + heightRatio * 0.3) + colorVariation * 0.8
      local grassB = (0.2 + heightRatio * 0.1) + colorVariation * 0.5
      pass:setColor(grassR, grassG, grassB)
    end
    pass:box(cx, surfaceY, z, segment, surfaceHeight, depth)
    
    -- Underground section (below grass layer) - ALWAYS DIRT/EARTH COLOR
    local undergroundHeight = terrainHeight - grassThickness
    if undergroundHeight > 0 then
      local undergroundY = actualHeight - grassThickness - undergroundHeight * 0.5
      
      -- Underground is ALWAYS earth/dirt color (never rocky)
      local earthR = (0.4 + heightRatio * 0.2) + colorVariation * 0.2
      local earthG = (0.25 + heightRatio * 0.15) + colorVariation * 0.15
      local earthB = (0.1 + heightRatio * 0.1) + colorVariation * 0.1
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
  -- Draw pre-generated static decorative elements (no more flickering!)
  if not self.staticDetails then return end
  
  for _, detail in ipairs(self.staticDetails) do
    local x = detail.x
    local surfaceHeight = self:heightAt(x)  -- Get current height (may have changed due to craters)
    
    if surfaceHeight > 2 then  -- Only draw if terrain still exists
      if detail.isRocky then
        -- Rocky area decorations
        if detail.type <= 2 then
          -- Large rock formations
          pass:setColor(0.45 + detail.colorR * 0.15, 0.45 + detail.colorG * 0.15, 0.55 + detail.colorB * 0.1)
          local width = 1.5 + detail.size * 0.5
          local height = 1.0 + detail.size * 0.5
          local depth = 1.0 + detail.size * 0.5
          pass:box(x, surfaceHeight + height * 0.5, 0, width, height, depth)
        else
          -- Boulder
          pass:setColor(0.5 + detail.colorR * 0.1, 0.4 + detail.colorG * 0.1, 0.4 + detail.colorB * 0.1)
          pass:sphere(x, surfaceHeight + detail.size * 0.5, 0, detail.size)
        end
      else
        -- Grassy area decorations
        if detail.type == 1 then
          -- Small scattered rocks
          pass:setColor(0.5 + detail.colorR * 0.1, 0.4 + detail.colorG * 0.1, 0.3 + detail.colorB * 0.1)
          pass:box(x, surfaceHeight + detail.size * 0.5, 0, detail.size, detail.size, detail.size)
        elseif detail.type == 2 then
          -- Grass tufts
          local grassR = 0.2 + detail.colorR * 0.2
          local grassG = 0.5 + detail.colorG * 0.3
          local grassB = 0.2 + detail.colorB * 0.2
          pass:setColor(grassR, grassG, grassB)
          local height = 1 + detail.size * 1.5
          pass:cylinder(x, surfaceHeight + height * 0.5, 0, 0.2 + detail.size * 0.1, height)
        elseif detail.type == 3 then
          -- Bushes
          local bushR = 0.25 + detail.colorR * 0.2
          local bushG = 0.4 + detail.colorG * 0.3
          local bushB = 0.15 + detail.colorB * 0.15
          pass:setColor(bushR, bushG, bushB)
          pass:sphere(x, surfaceHeight + detail.size * 0.4, 0, detail.size)
        elseif detail.type == 4 then
          -- Single flower
          local flowerColors = {
            {0.8, 0.2, 0.3}, -- Red
            {0.7, 0.7, 0.2}, -- Yellow
            {0.3, 0.2, 0.8}, -- Blue
            {0.8, 0.4, 0.8}  -- Pink
          }
          local colorIndex = math.floor(detail.colorR * 4) + 1
          local color = flowerColors[colorIndex] or flowerColors[1]
          pass:setColor(color[1], color[2], color[3])
          pass:sphere(x, surfaceHeight + 0.2, 0, 0.1)
        else
          -- Dead branch
          pass:setColor(0.3 + detail.colorR * 0.2, 0.2 + detail.colorG * 0.1, 0.1)
          local thickness = 0.2 + detail.size * 0.1
          pass:cylinder(x, surfaceHeight + thickness * 0.5, 0, thickness, thickness * 2)
        end
      end
    end
  end
end

return Terrain

