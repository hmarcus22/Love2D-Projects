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
  
  -- Debug: check where thickness is coming from
  print("===== ARROW INIT DEBUG =====")
  print("opts.thickness=" .. tostring(opts.thickness))
  print("Config.ui.arrowThickness=" .. tostring(Config.ui.arrowThickness))
  print("==========================")
  
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
    
    -- Debug: verify values are correct
    print("===== ARROW SHAPE DEBUG =====")
    print("baseW=" .. baseW .. ", tipW=" .. tipW .. ", thickness=" .. self.thickness)
    print("=============================")
    
    local left = {}
    local right = {}
    for i = 0, samples do
      local t = i / samples
      local wLin = baseW + (tipW - baseW) * t
      
      -- Alternative concavity curve: gentler, more compatible with large tapers
      local midCurve
      if self.shapeCfg.curveStyle == "gentle" then
        -- Smoother curve that peaks later, works better with large tapers
        midCurve = 4 * t * (1 - t) -- Parabolic: smoother, peaks at t=0.5
      else
        -- Original sine curve
        midCurve = math.sin(math.pi * t) -- Single peak at middle (t=0.5)
      end
      
      -- Apply concavity by curving inward from the straight taper line
      -- This creates curved sides without affecting the base/tip widths
      local w = wLin * (1 - conc * midCurve)
      -- Ensure we never go below a minimum width
      w = math.max(1, w)
      local cx = g.sx + g.ux * (t * Lshaft)
      local cy = g.sy + g.uy * (t * Lshaft)
      local lx = cx + g.px * (w * 0.5)
      local ly = cy + g.py * (w * 0.5)
      local rx = cx - g.px * (w * 0.5)
      local ry = cy - g.py * (w * 0.5)
      table.insert(left, {lx - g.ox, ly - g.oy})
      table.insert(right, {rx - g.ox, ry - g.oy})
    end
    vertsShaft = {}
    -- left side forward
    for i = 1, #left do
      vertsShaft[#vertsShaft+1] = left[i][1]
      vertsShaft[#vertsShaft+1] = left[i][2]
    end
    -- right side backward
    for i = #right, 1, -1 do
      vertsShaft[#vertsShaft+1] = right[i][1]
      vertsShaft[#vertsShaft+1] = right[i][2]
    end
    love.graphics.polygon("fill", unpack(vertsShaft))
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
