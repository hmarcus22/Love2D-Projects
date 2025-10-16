local Class = require "libs.hump.class"
local Vector = require "libs.hump.vector"
local Config = require "src.config"
local Viewport = require "src.viewport"

local Arrow = Class()
local unpack = table.unpack or unpack

-- Lazy-loaded shaders
local outlineShader
local fadeShader

local function ensureShaders()
  if not outlineShader then
    outlineShader = love.graphics.newShader("src/shaders/arrow_outline.glsl")
  end
  if not fadeShader then
    fadeShader = love.graphics.newShader("src/shaders/arrow_alpha_gradient.glsl")
  end
end

function Arrow:init(startPos, endPos, opts)
  opts = opts or {}
  self.start = Vector(startPos.x or startPos[1], startPos.y or startPos[2])
  self.finish = Vector(endPos.x or endPos[1], endPos.y or endPos[2])
  self.color = opts.color or Config.colors.arrow
  
  self.thickness = opts.thickness or Config.ui.arrowThickness
  self.headSize = opts.headSize or Config.ui.arrowHeadSize
  
  self.thickness = opts.thickness or Config.ui.arrowThickness
  self.headSize = opts.headSize or Config.ui.arrowHeadSize

  local cfg = Config.ui.arrows or {}
  -- Allow per-instance override via opts.useFancy (true/false); otherwise fall back to global
  if opts.useFancy ~= nil then
    self.fancyEnabled = opts.useFancy and true or false
  else
    self.fancyEnabled = cfg.enabled == true
  end
  self.fillColor = (opts.fillColor ~= nil) and opts.fillColor or cfg.fillColor or self.color
  self.outlineCfg = (opts.outline ~= nil) and opts.outline or cfg.outline or { enabled = true, size = 3, color = {1,1,1,1} }
  self.fadeCfg = (opts.fadeAll ~= nil) and opts.fadeAll or cfg.fadeAll or { enabled = true, gamma = 1.0 }
  self.innerGradientCfg = (opts.innerGradient ~= nil) and opts.innerGradient or cfg.innerGradient or { enabled = false }
  self.rasterCfg = (opts.raster ~= nil) and opts.raster or cfg.raster or { oversample = 1.0, useDPIScale = false, maxSize = 2048 }
  self.shapeCfg = (opts.shape ~= nil) and opts.shape or cfg.shape or { enabled = true, concavity = 0.18, segments = 14, tipWidth = nil }

  -- Reusable canvases (allocated on first draw)
  self._mask = nil   -- arrow mask (white RGBA with alpha shape)
  self._comp = nil   -- composite (outline + fill)
end

local function computeGeometry(self)
  local sx, sy = self.start.x, self.start.y
  local fx, fy = self.finish.x, self.finish.y
  local dx, dy = fx - sx, fy - sy
  local len = math.sqrt(dx*dx + dy*dy)
  if len == 0 then return nil end
  local ux, uy = dx/len, dy/len
  local px, py = -uy, ux
  local half = self.thickness * 0.5
  local head = self.headSize

  -- Base of arrow head
  local bx, by = fx - ux * head, fy - uy * head

  -- Shaft quad
  local q1x, q1y = sx + px*half, sy + py*half
  local q2x, q2y = bx + px*half, by + py*half
  local q3x, q3y = bx - px*half, by - py*half
  local q4x, q4y = sx - px*half, sy - py*half

  -- Head triangle
  local h1x, h1y = fx, fy
  local h2x, h2y = bx + px*(head*0.5), by + py*(head*0.5)
  local h3x, h3y = bx - px*(head*0.5), by - py*(head*0.5)

  -- Bounding box with padding - account for shaped shaft maximum width
  local maxShaftWidth = self.thickness
  if self.shapeCfg and self.shapeCfg.enabled then
    local baseW = self.thickness
    local tipW = self.shapeCfg.tipWidth or baseW
    maxShaftWidth = math.max(baseW, tipW, self.thickness)
  end
  local shaftHalf = maxShaftWidth * 0.5
  
  -- Extend bounding box to include maximum shaft width
  local shaftMinX = math.min(sx - shaftHalf, fx - shaftHalf)
  local shaftMaxX = math.max(sx + shaftHalf, fx + shaftHalf)
  local shaftMinY = math.min(sy - shaftHalf, fy - shaftHalf)
  local shaftMaxY = math.max(sy + shaftHalf, fy + shaftHalf)
  
  local minx = math.min(q1x,q2x,q3x,q4x,h1x,h2x,h3x,shaftMinX) - 2
  local miny = math.min(q1y,q2y,q3y,q4y,h1y,h2y,h3y,shaftMinY) - 2
  local maxx = math.max(q1x,q2x,q3x,q4x,h1x,h2x,h3x,shaftMaxX) + 2
  local maxy = math.max(q1y,q2y,q3y,q4y,h1y,h2y,h3y,shaftMaxY) + 2
  local w = math.ceil(maxx - minx)
  local h = math.ceil(maxy - miny)

  return {
    sx=sx, sy=sy, fx=fx, fy=fy,
    ux=ux, uy=uy, px=px, py=py, len=len,
    bx=bx, by=by,
    q1x=q1x, q1y=q1y, q2x=q2x, q2y=q2y, q3x=q3x, q3y=q3y, q4x=q4x, q4y=q4y,
    h1x=h1x, h1y=h1y, h2x=h2x, h2y=h2y, h3x=h3x, h3y=h3y,
    ox=minx, oy=miny, w=w, h=h
  }
end

local function ensureCanvas(canvas, w, h)
  if canvas and canvas:getWidth() >= w and canvas:getHeight() >= h then
    return canvas
  end
  local c = love.graphics.newCanvas(w, h)
  if c.setFilter then c:setFilter("linear", "linear") end
  return c
end

local function getRasterParams(self, g)
  local base = (Viewport and Viewport.scale) or 1
  local over = (self.rasterCfg and self.rasterCfg.oversample) or 1.0
  local dpi = 1
  if self.rasterCfg and self.rasterCfg.useDPIScale and love.window and love.window.getDPIScale then
    local ok, scale = pcall(love.window.getDPIScale)
    if ok and type(scale) == 'number' and scale > 0 then dpi = scale end
  end
  local desired = base * over * dpi
  if desired < 1 then desired = 1 end
  local maxSize = (self.rasterCfg and self.rasterCfg.maxSize) or 2048
  local limitW = maxSize / math.max(1, g.w)
  local limitH = maxSize / math.max(1, g.h)
  local used = math.min(desired, limitW, limitH)
  if used < 1 then used = 1 end
  local cw = math.max(2, math.ceil(g.w * used))
  local ch = math.max(2, math.ceil(g.h * used))
  return used, cw, ch
end

function Arrow:draw()
  if not (self.fancyEnabled and love.graphics and love.graphics.newShader) then
    -- Fallback: simple line + triangle head
    love.graphics.setColor(self.color)
    love.graphics.setLineWidth(self.thickness)
    love.graphics.line(self.start.x, self.start.y, self.finish.x, self.finish.y)

    local dir = (self.finish - self.start):normalized()
    local perp = Vector(-dir.y, dir.x)
    local headBase = self.finish - dir * self.headSize
    local left = headBase + perp * (self.headSize * 0.5)
    local right = headBase - perp * (self.headSize * 0.5)
    love.graphics.polygon("fill",
      self.finish.x, self.finish.y,
      left.x, left.y,
      right.x, right.y
    )
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    return
  end

  -- EMERGENCY BYPASS: Test concave polygon directly with Love2D (no shaders)
  if false then  -- Disable direct Love2D test - use canvas mirroring instead
    local g = computeGeometry(self)
    if not g then return end
    
    -- Create concave polygon using our perfect calculations
    local samples = math.max(2, math.floor(self.shapeCfg.segments or 14))
    local Lshaft = math.max(1, g.len - self.headSize)
    local baseW = self.thickness
    local tipW = self.shapeCfg.tipWidth or baseW
    local conc = math.max(0, math.min(self.shapeCfg.concavity or 0, 0.9))
    
    local leftSide = {}
    local rightSide = {}
    
    for i = 0, samples do
      local t = i / samples
      local wLin = baseW + (tipW - baseW) * t
      local w = wLin
      
      local concaveOffset = 0
      if conc > 0 then
        local concaveFactor = math.sin(math.pi * t)
        concaveOffset = conc * concaveFactor * 32
      end
      
      local cx = g.sx + g.ux * (t * Lshaft)
      local cy = g.sy + g.uy * (t * Lshaft)
      
      local maxOffset = w * 0.35
      local clampedOffset = math.min(concaveOffset, maxOffset)
      local halfWidth = (w * 0.5) - clampedOffset
      
      local lx = cx + g.px * halfWidth
      local ly = cy + g.py * halfWidth
      local rx = cx - g.px * halfWidth
      local ry = cy - g.py * halfWidth
      
      table.insert(leftSide, {lx, ly})
      table.insert(rightSide, {rx, ry})
    end
    
    -- Build polygon vertices
    local verts = {}
    for i = 1, #leftSide do
      verts[#verts+1] = leftSide[i][1]
      verts[#verts+1] = leftSide[i][2]
    end
    for i = #rightSide, 1, -1 do
      verts[#verts+1] = rightSide[i][1]
      verts[#verts+1] = rightSide[i][2]
    end
    
    -- DEBUG: Print vertex sequence to check for self-intersection
    print("Polygon vertex sequence (first 6 and last 6):")
    for i = 1, math.min(12, #verts), 2 do
      print(string.format("  %d: (%.1f, %.1f)", (i+1)/2, verts[i], verts[i+1]))
    end
    if #verts > 12 then
      print("  ...")
      for i = math.max(#verts-11, 13), #verts, 2 do
        print(string.format("  %d: (%.1f, %.1f)", (i+1)/2, verts[i], verts[i+1]))
      end
    end
    
    -- Check for potential self-intersection at key points
    local midLeft = leftSide[math.floor(#leftSide/2)]
    local midRight = rightSide[math.floor(#rightSide/2)]
    print(string.format("Key vertices: midLeft(%.1f,%.1f), midRight(%.1f,%.1f)", 
                       midLeft[1], midLeft[2], midRight[1], midRight[2]))
    
    -- Draw directly with Love2D (NO SHADERS)
    love.graphics.setColor(1, 1, 0, 1)  -- Yellow
    love.graphics.polygon("fill", unpack(verts))
    
    -- Draw arrowhead
    love.graphics.polygon("fill", g.h1x, g.h1y, g.h2x, g.h2y, g.h3x, g.h3y)
    
    love.graphics.setColor(1, 1, 1, 1)
    print("DIRECT LOVE2D RENDERING: Bilateral concavity test")
    return
  end

  ensureShaders()

  local g = computeGeometry(self)
  if not g then return end

  -- Prepare canvases at raster scale
  local rasterScale, cw, ch = getRasterParams(self, g)
  self._mask = ensureCanvas(self._mask, cw, ch)
  self._comp = ensureCanvas(self._comp, cw, ch)

  love.graphics.push("all")

  -- 1) Build mask (white RGBA with alpha shape)
  love.graphics.push()         -- limit origin() to this pass
  love.graphics.origin()
  love.graphics.setCanvas(self._mask)
  love.graphics.clear(0,0,0,0)
  love.graphics.scale(rasterScale, rasterScale)
  love.graphics.setColor(1,1,1,1)
  -- Build shaft polygon: tapered + optional concave sides
  local vertsShaft
  if self.shapeCfg and self.shapeCfg.enabled then
    local samples = math.max(2, math.floor(self.shapeCfg.segments or 14))
    local Lshaft = math.max(1, g.len - self.headSize)
    local baseW = self.thickness
    local tipW = self.shapeCfg.tipWidth or baseW -- Fixed: removed extra parentheses
    local conc = math.max(0, math.min(self.shapeCfg.concavity or 0, 0.9))
    
    -- DUAL CONVEX APPROACH: Draw two separate convex sides instead of one concave polygon
    local samples = math.max(2, math.floor(self.shapeCfg.segments or 14))
    local Lshaft = math.max(1, g.len - self.headSize)
    local baseW = self.thickness
    local tipW = self.shapeCfg.tipWidth or baseW
    local conc = math.max(0, math.min(self.shapeCfg.concavity or 0, 0.9))
    
    -- Calculate centerline and both sides
    local centerPoints = {}
    local leftPoints = {}
    local rightPoints = {}
    
    for i = 0, samples do
      local t = i / samples
      local wLin = baseW + (tipW - baseW) * t
      local w = wLin
      
      local concaveOffset = 0
      if conc > 0 then
        local concaveFactor = math.sin(math.pi * t)
        concaveOffset = conc * concaveFactor * 32
      end
      
      local cx = g.sx + g.ux * (t * Lshaft)
      local cy = g.sy + g.uy * (t * Lshaft)
      
      local maxOffset = w * 0.35
      local clampedOffset = math.min(concaveOffset, maxOffset)
      local halfWidth = (w * 0.5) - clampedOffset
      
      local lx = cx + g.px * halfWidth
      local ly = cy + g.py * halfWidth
      local rx = cx - g.px * halfWidth
      local ry = cy - g.py * halfWidth
      
      table.insert(centerPoints, {cx - g.ox, cy - g.oy})
      table.insert(leftPoints, {lx - g.ox, ly - g.oy})
      table.insert(rightPoints, {rx - g.ox, ry - g.oy})
    end
    
    -- Draw LEFT SIDE as convex polygon (center to left edge)
    local leftSide = {}
    for i = 1, #centerPoints do
      leftSide[#leftSide+1] = centerPoints[i][1]
      leftSide[#leftSide+1] = centerPoints[i][2]
    end
    for i = #leftPoints, 1, -1 do
      leftSide[#leftSide+1] = leftPoints[i][1]
      leftSide[#leftSide+1] = leftPoints[i][2]
    end
    love.graphics.polygon("fill", unpack(leftSide))
    
    -- Draw RIGHT SIDE as convex polygon (center to right edge)
    local rightSide = {}
    for i = 1, #centerPoints do
      rightSide[#rightSide+1] = centerPoints[i][1]
      rightSide[#rightSide+1] = centerPoints[i][2]
    end
    for i = #rightPoints, 1, -1 do
      rightSide[#rightSide+1] = rightPoints[i][1]
      rightSide[#rightSide+1] = rightPoints[i][2]
    end
    love.graphics.polygon("fill", unpack(rightSide))
    
    -- Skip the old single polygon approach
    vertsShaft = {}
  else
    -- Fallback: constant-width quad
    local q1x, q1y = g.q1x - g.ox, g.q1y - g.oy
    local q2x, q2y = g.q2x - g.ox, g.q2y - g.oy
    local q3x, q3y = g.q3x - g.ox, g.q3y - g.oy
    local q4x, q4y = g.q4x - g.ox, g.q4y - g.oy
    vertsShaft = { q1x,q1y, q2x,q2y, q3x,q3y, q4x,q4y }
    love.graphics.polygon("fill", unpack(vertsShaft))
  end

  local h1x, h1y = g.h1x - g.ox, g.h1y - g.oy
  local h2x, h2y = g.h2x - g.ox, g.h2y - g.oy
  local h3x, h3y = g.h3x - g.ox, g.h3y - g.oy
  local vertsHead = { h1x,h1y, h2x,h2y, h3x,h3y }
  love.graphics.polygon("fill", unpack(vertsHead))
  love.graphics.setCanvas()
  love.graphics.pop()          -- restore original transform

  -- 2) Composite: outline + (optional) inner fill/gradient into comp
  love.graphics.push()         -- limit origin() to this pass
  love.graphics.origin()
  love.graphics.setCanvas(self._comp)
  love.graphics.clear(0,0,0,0)

  -- Outline
  if self.outlineCfg and self.outlineCfg.enabled then
    outlineShader:send("texelSize", {1/cw, 1/ch})
    outlineShader:send("outlineSize", (self.outlineCfg.size or 3) * rasterScale)
    outlineShader:send("outlineColor", self.outlineCfg.color or {1,1,1,1})
    love.graphics.setShader(outlineShader)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(self._mask, 0, 0)
    love.graphics.setShader()
  end

  -- Inner fill (flat or optional inner gradient)
  if self.innerGradientCfg and self.innerGradientCfg.enabled then
    -- Simple inner color gradient along arrow length (mask multiplied by gradient color)
    -- Implement via immediate shader reuse of fadeShader on color would affect alpha, not RGB.
    -- For simplicity, we mimic a color gradient by drawing tail half then tip half blending.
    -- To keep it straightforward and efficient, draw flat color; the global fade will sell the look.
    love.graphics.setColor(self.fillColor)
    love.graphics.draw(self._mask, 0, 0)
  else
    love.graphics.setColor(self.fillColor)
    love.graphics.draw(self._mask, 0, 0)
  end

  love.graphics.setCanvas()
  love.graphics.pop()          -- restore original transform

  -- 3) Draw composite with tail->tip alpha fade so the whole arrow (outline+fill) fades in
  local ow, oh = self._comp:getWidth(), self._comp:getHeight()
  local tailUV = {((g.sx - g.ox) * rasterScale) / ow, ((g.sy - g.oy) * rasterScale) / oh}
  local tipUV  = {((g.fx - g.ox) * rasterScale) / ow, ((g.fy - g.oy) * rasterScale) / oh}
  fadeShader:send("tailUV", tailUV)
  fadeShader:send("tipUV", tipUV)
  fadeShader:send("gamma", (self.fadeCfg and self.fadeCfg.gamma) or 1.0)
  love.graphics.setShader((self.fadeCfg and self.fadeCfg.enabled) and fadeShader or nil)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(self._comp, g.ox, g.oy, 0, 1 / rasterScale, 1 / rasterScale)
  love.graphics.setShader()

  love.graphics.pop()
end

return Arrow
