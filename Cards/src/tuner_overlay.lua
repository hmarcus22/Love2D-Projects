local Config = require "src.config"
local Viewport = require "src.viewport"
local Deep = require "src.utils.deep"
local Tunables = require "src.tunable_defs"

local Overlay = {
  open = false,
  controls = {},
  scroll = 0,
  active = nil,
  context = 'game',
}

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end

local function round_to_step(v, step)
  if not step or step <= 0 then return v end
  return math.floor((v / step) + 0.5) * step
end

function Overlay.isOpen()
  return Overlay.open == true
end

function Overlay.toggle()
  Overlay.open = not Overlay.open
  if not Overlay.open then
    Overlay.active = nil
  end
end

-- Build visible controls for current context
local function build_controls(context)
  context = context or 'game'
  local screenW = Viewport.getWidth()
  local x = screenW - 340
  local y = 12
  local w = 328
  local hHeader = 28
  local rowH = 28
  local innerX = x + 12
  local innerW = w - 24

  local controls = {}
  local categories = {}
  for _, def in ipairs(Tunables) do
    if def.context == 'all' or def.context == context then
      categories[def.category or 'General'] = categories[def.category or 'General'] or {}
      table.insert(categories[def.category or 'General'], def)
    end
  end

  local panelH = hHeader
  table.insert(controls, { kind='panel', x=x, y=y, w=w, h=0, title='Tuner ('..context..')' })
  y = y + hHeader
  panelH = panelH + 8

  -- Category sections
  for cat, defs in pairs(categories) do
    table.insert(controls, { kind='label', text=cat, x=innerX, y=y, w=innerW, h=rowH })
    y = y + rowH
    panelH = panelH + rowH
    table.sort(defs, function(a,b) return a.label < b.label end)
    for _, d in ipairs(defs) do
      local val = Deep.get_by_path(Config, d.path)
      if d.type == 'number' then
        table.insert(controls, { kind='slider', def=d, value=val, x=innerX, y=y, w=innerW, h=rowH })
      elseif d.type == 'boolean' then
        table.insert(controls, { kind='checkbox', def=d, value=val and true or false, x=innerX, y=y, w=innerW, h=rowH })
      end
      y = y + rowH
      panelH = panelH + rowH
    end
    panelH = panelH + 8
    y = y + 8
  end

  -- Footer hint
  table.insert(controls, { kind='hint', text='F10: toggle  |  Ctrl+S: save  Ctrl+R: reset visible', x=innerX, y=y, w=innerW, h=rowH })
  panelH = panelH + rowH

  -- Update panel height
  controls[1].h = panelH
  return controls
end

local function pointIn(x, y, r)
  return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function apply_change(def, value, owner, context)
  Config.set(def.path, value)
  -- Trigger minimal refresh for immediate feedback
  if context == 'game' and owner and owner.gs then
    if owner.gs.buildLayoutCache then owner.gs:buildLayoutCache() end
    if owner.gs.refreshLayoutPositions then owner.gs:refreshLayoutPositions() end
  elseif context == 'draft' and owner and owner.updateChoicePositions then
    owner:updateChoicePositions()
  end
end

function Overlay.update(dt, context, owner)
  if not Overlay.open then return end
  Overlay.context = context or Overlay.context
  Overlay.controls = build_controls(Overlay.context)
  -- Dragging active slider
  if Overlay.active and Overlay.active.kind == 'slider' then
    local mx, my = love.mouse.getPosition()
    mx, my = Viewport.toVirtual(mx, my)
    local c = Overlay.active
    local trackX = c.x + 120
    local trackW = c.w - 180
    local t = clamp((mx - trackX) / trackW, 0, 1)
    local v = c.def.min + t * (c.def.max - c.def.min)
    v = round_to_step(v, c.def.step or 0)
    if c.def.step and c.def.step >= 1 then v = math.floor(v + 0.0) end
    c.value = v
    apply_change(c.def, v, owner, Overlay.context)
  end
end

function Overlay.draw(context)
  if not Overlay.open then return end
  context = context or Overlay.context
  local controls = Overlay.controls
  if not controls or #controls == 0 then return end

  -- Apply scroll
  local scroll = Overlay.scroll or 0

  for _, c in ipairs(controls) do
    local y = c.y - scroll
    if c.kind == 'panel' then
      love.graphics.setColor(0,0,0,0.75)
      love.graphics.rectangle('fill', c.x, c.y, c.w, c.h, 10, 10)
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle('line', c.x, c.y, c.w, c.h, 10, 10)
      love.graphics.printf(c.title or 'Tuner', c.x, c.y + 6, c.w, 'center')
    elseif c.kind == 'label' then
      love.graphics.setColor(1,1,0.8,1)
      love.graphics.printf(c.text or '', c.x, y + 6, c.w, 'left')
      love.graphics.setColor(1,1,1,1)
    elseif c.kind == 'slider' then
      -- label
      love.graphics.setColor(1,1,1,1)
      love.graphics.printf(c.def.label or c.def.path, c.x, y + 6, 116, 'left')
      -- track
      local tx = c.x + 120
      local tw = c.w - 180
      local ty = y + 12
      love.graphics.setColor(0.2,0.2,0.2,1)
      love.graphics.rectangle('fill', tx, ty, tw, 4, 2, 2)
      local t = (c.value - c.def.min) / (c.def.max - c.def.min)
      t = clamp(t, 0, 1)
      local fx = tx + t * tw
      love.graphics.setColor(0.3,0.7,0.3,1)
      love.graphics.circle('fill', fx, ty + 2, 6)
      love.graphics.setColor(1,1,1,1)
      -- numeric
      local valStr = string.format(c.def.step and c.def.step >= 1 and "%.0f" or "%.2f", c.value)
      love.graphics.printf(valStr, tx + tw + 8, y + 6, 52, 'right')
    elseif c.kind == 'checkbox' then
      love.graphics.setColor(1,1,1,1)
      love.graphics.printf(c.def.label or c.def.path, c.x, y + 6, c.w - 28, 'left')
      local bx = c.x + c.w - 28
      local by = y + 5
      love.graphics.setColor(0.2,0.2,0.2,1)
      love.graphics.rectangle('fill', bx, by, 20, 20, 4, 4)
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle('line', bx, by, 20, 20, 4, 4)
      if c.value then
        love.graphics.setColor(0.3,0.8,0.3,1)
        love.graphics.rectangle('fill', bx+4, by+4, 12, 12, 2, 2)
        love.graphics.setColor(1,1,1,1)
      end
    elseif c.kind == 'hint' then
      love.graphics.setColor(0.85,0.85,0.85,1)
      love.graphics.printf(c.text or '', c.x, y + 6, c.w, 'center')
      love.graphics.setColor(1,1,1,1)
    end
  end
end

function Overlay.mousepressed(x, y, button, context, owner)
  if not Overlay.open then return false end
  Overlay.context = context or Overlay.context
  -- hit test controls
  for i = #Overlay.controls, 1, -1 do
    local c = Overlay.controls[i]
    local cy = c.y - (Overlay.scroll or 0)
    if c.kind == 'slider' then
      local r = { x = c.x + 120, y = cy, w = c.w - 120, h = c.h }
      if pointIn(x, y, r) then
        Overlay.active = c
        return true
      end
    elseif c.kind == 'checkbox' then
      local r = { x = c.x, y = cy, w = c.w, h = c.h }
      if pointIn(x, y, r) then
        c.value = not c.value
        apply_change(c.def, c.value and true or false, owner, Overlay.context)
        return true
      end
    elseif c.kind == 'panel' then
      local r = { x=c.x, y=c.y, w=c.w, h=c.h }
      if pointIn(x, y, r) then return true end
    end
  end
  return false
end

function Overlay.mousereleased(x, y, button)
  if not Overlay.open then return false end
  Overlay.active = nil
  return true
end

function Overlay.wheelmoved(dx, dy)
  if not Overlay.open then return false end
  Overlay.scroll = clamp((Overlay.scroll or 0) - (dy or 0) * 20, 0, 10000)
  return true
end

function Overlay.keypressed(key, context, owner)
  if key == 'f10' then
    Overlay.toggle()
    return true
  end
  if not Overlay.open then return false end
  local ctrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
  if ctrl and (key == 's') then
    Config.saveOverrides()
    return true
  elseif ctrl and (key == 'r') then
    -- Reset all visible tunables
    local visible = {}
    for _, c in ipairs(Overlay.controls or {}) do
      if c.def and c.def.path then
        Config.reset(c.def.path)
      end
    end
    -- apply refresh once for the context
    if context == 'game' and owner and owner.gs then
      if owner.gs.buildLayoutCache then owner.gs:buildLayoutCache() end
      if owner.gs.refreshLayoutPositions then owner.gs:refreshLayoutPositions() end
    elseif context == 'draft' and owner and owner.updateChoicePositions then
      owner:updateChoicePositions()
    end
    return true
  end
  return false
end

return Overlay

