local Config = require "src.config"
local Viewport = require "src.viewport"
local Deep = require "src.utils.deep"
local Tunables = require "src.tunable_defs"
local AnimationSpecs = require 'src.animation_specs'

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
  local animLab = (context == 'anim_lab')
  local function allowAnimLab(def)
    if not animLab then return true end
    -- Only show a curated subset of animation-related global fields in animation lab context
    if def.path == 'ui.useAnimationOverrides' then return true end
    if def.path:match('^ui%.cardFlight') then return true end
    if def.path:match('^ui%.cardImpact') then return true end
    return false
  end
  for _, def in ipairs(Tunables) do
    local ctxOk = (def.context == 'all' or def.context == context)
    if animLab then
      -- In anim_lab we ignore the original context gating and apply our allow list
      if allowAnimLab(def) then
        categories[def.category or 'General'] = categories[def.category or 'General'] or {}
        table.insert(categories[def.category or 'General'], def)
      end
    else
      if ctxOk then
        categories[def.category or 'General'] = categories[def.category or 'General'] or {}
        table.insert(categories[def.category or 'General'], def)
      end
    end
  end

  -- Inject dynamic per-card animation spec controls in anim_lab context
  if context == 'anim_lab' and Overlay._labOwner and Overlay._labOwner.cards then
    local owner = Overlay._labOwner
    local def = owner.cards[owner.attackerIndex]
    if def then
      local cid = def.id
      local spec = AnimationSpecs.getCardSpec(cid)
      categories['Anim Card'] = categories['Anim Card'] or {}
      local flight = spec.flight or {}
      local function addDyn(pathKey, label, value, min, max, step)
        table.insert(categories['Anim Card'], { _dynamic=true, dynGroup='flight', dynKey=pathKey, label=label, type='number', min=min, max=max, step=step, value=value })
      end
      addDyn('duration', 'Flight Duration*', flight.duration or 0.35, 0.05, 2.0, 0.01)
      addDyn('overshoot', 'Flight Overshoot*', flight.overshoot or 0, 0, 0.8, 0.01)
      addDyn('arcScale', 'Arc Scale*', flight.arcScale or 1, 0.05, 3.0, 0.01)
      table.insert(categories['Anim Card'], { _dynamic=true, dynGroup='flight', dynKey='slamStyle', label='Slam Style*', type='boolean', value = flight.slamStyle or false })
      table.insert(categories['Anim Card'], { _dynamic=true, dynGroup='flight', dynKey='profile', label='Profile*', type='enum', options={'default','slam_body'}, value=flight.profile or 'default' })
      -- Save / Reset buttons are represented as hints for now
      table.insert(categories['Anim Card'], { kind='hint', text='Ctrl+S saves config overrides; Shift+S saves anim overrides; Shift+R resets this card' })
    end
  end

  local panelH = hHeader
  local panelTitle = animLab and 'Tuner (Animation Lab)' or ('Tuner ('..context..')')
  table.insert(controls, { kind='panel', x=x, y=y, w=w, h=0, title=panelTitle })
  y = y + hHeader
  panelH = panelH + 8

  -- Category sections
  for cat, defs in pairs(categories) do
    table.insert(controls, { kind='label', text=cat, x=innerX, y=y, w=innerW, h=rowH })
    y = y + rowH
    panelH = panelH + rowH
    table.sort(defs, function(a,b)
      local al = a.label or (a.def and a.def.label) or ''
      local bl = b.label or (b.def and b.def.label) or ''
      return al < bl
    end)
    for _, d in ipairs(defs) do
      local val = Deep.get_by_path(Config, d.path)
      if d._dynamic then
        -- Build dynamic control row without relying on Config path
        if d.type == 'number' then
          table.insert(controls, { kind='slider', def=d, value=d.value, x=innerX, y=y, w=innerW, h=rowH, _dynamic=true })
          y = y + rowH; panelH = panelH + rowH
        elseif d.type == 'boolean' then
          table.insert(controls, { kind='checkbox', def=d, value=d.value and true or false, x=innerX, y=y, w=innerW, h=rowH, _dynamic=true })
          y = y + rowH; panelH = panelH + rowH
        elseif d.type == 'enum' then
          table.insert(controls, { kind='enum', def=d, value=d.value, options=d.options or {}, x=innerX, y=y, w=innerW, h=rowH, _dynamic=true })
          y = y + rowH; panelH = panelH + rowH
        elseif d.kind == 'hint' then
          table.insert(controls, { kind='hint', text=d.text, x=innerX, y=y, w=innerW, h=rowH })
          y = y + rowH; panelH = panelH + rowH
        end
      elseif d.type == 'number' then
        table.insert(controls, { kind='slider', def=d, value=val, x=innerX, y=y, w=innerW, h=rowH })
        y = y + rowH
        panelH = panelH + rowH
      elseif d.type == 'boolean' then
        table.insert(controls, { kind='checkbox', def=d, value=val and true or false, x=innerX, y=y, w=innerW, h=rowH })
        y = y + rowH
        panelH = panelH + rowH
      elseif d.type == 'color' then
        local col = {0,0,0,1}
        if type(val) == 'table' then
          col[1] = val[1] or 0; col[2] = val[2] or 0; col[3] = val[3] or 0; col[4] = val[4] ~= nil and val[4] or 1
        end
        table.insert(controls, { kind='color', def=d, value=col, x=innerX, y=y, w=innerW, h=rowH })
        y = y + rowH
        panelH = panelH + rowH
      elseif d.type == 'enum' then
        table.insert(controls, { kind='enum', def=d, value=val, x=innerX, y=y, w=innerW, h=rowH, options=d.options or {} })
        y = y + rowH
        panelH = panelH + rowH
      end
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
  -- Special handling: if changing overlayColor with RGBA, map A to overlayAlpha
  if def.path == 'draft.background.overlayColor' and type(value) == 'table' then
    local rgb = { value[1] or 0, value[2] or 0, value[3] or 0 }
    Config.set(def.path, rgb)
    if value[4] ~= nil then
      Config.set('draft.background.overlayAlpha', clamp(value[4], 0, 1))
    end
  else
    Config.set(def.path, value)
  end
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
  if context == 'anim_lab' then Overlay._labOwner = owner end
  Overlay.controls = build_controls(Overlay.context)

  -- Resolve active control against freshly built controls
  local function find_control(defPath, kind)
    for _, c in ipairs(Overlay.controls) do
      if c.def and c.def.path == defPath and c.kind == kind then return c end
    end
    return nil
  end

  if Overlay.active then
    local kind = Overlay.active.kind
    if kind == 'slider' then
      local activeCtrl = find_control(Overlay.active.def.path, 'slider') or Overlay.active.control or Overlay.active
      if activeCtrl then
        local mx, my = love.mouse.getPosition()
        mx, my = Viewport.toVirtual(mx, my)
        local trackX = activeCtrl.x + 120
        local trackW = activeCtrl.w - 180
        local t = clamp((mx - trackX) / trackW, 0, 1)
        local v = activeCtrl.def.min + t * (activeCtrl.def.max - activeCtrl.def.min)
        v = round_to_step(v, activeCtrl.def.step or 0)
        if activeCtrl.def.step and activeCtrl.def.step >= 1 then v = math.floor(v + 0.0) end
        activeCtrl.value = v
        if activeCtrl._dynamic then
          -- Apply dynamic change to animation spec override
          Overlay.applyDynamicChange(owner, activeCtrl.def, v)
          activeCtrl.value = v
        else
          apply_change(activeCtrl.def, v, owner, Overlay.context)
        end
      end
    elseif kind == 'color' then
      local activeCtrl = find_control(Overlay.active.def.path, 'color') or Overlay.active.control
      if activeCtrl and Overlay.active.channel then
        local mx, my = love.mouse.getPosition()
        mx, my = Viewport.toVirtual(mx, my)
        -- Compute track rects
        local tx = activeCtrl.x + 120
        local tw = activeCtrl.w - 180
        local spacing = 8
        local cw = math.max(10, math.floor((tw - spacing*3) / 4))
        local idx = Overlay.active.channel
        local chx = tx + (idx-1) * (cw + spacing)
        local t = clamp((mx - chx) / cw, 0, 1)
        local v = round_to_step(t, 0.01)
        if idx == 4 then v = round_to_step(t, 0.01) end
        v = clamp(v, 0, 1)
        activeCtrl.value[idx] = v
        apply_change(activeCtrl.def, { activeCtrl.value[1], activeCtrl.value[2], activeCtrl.value[3], activeCtrl.value[4] }, owner, Overlay.context)
      end
    end
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
    elseif c.kind == 'enum' then
      love.graphics.setColor(1,1,1,1)
      love.graphics.printf(c.def.label or c.def.path, c.x, y + 6, c.w - 120, 'left')
      local bx = c.x + c.w - 120
      local bw = 112
      love.graphics.setColor(0.2,0.2,0.2,1)
      love.graphics.rectangle('fill', bx, y + 4, bw, c.h - 8, 6, 6)
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle('line', bx, y + 4, bw, c.h - 8, 6, 6)
      local current = tostring(c.value)
      love.graphics.printf(current, bx + 8, y + 8, bw - 16, 'left')
    elseif c.kind == 'color' then
      -- label
      love.graphics.setColor(1,1,1,1)
      love.graphics.printf(c.def.label or c.def.path, c.x, y + 6, 116, 'left')
      -- swatch
      local swx = c.x + 120
      local swy = y + 4
      love.graphics.setColor(c.value[1] or 0, c.value[2] or 0, c.value[3] or 0, c.value[4] or 1)
      love.graphics.rectangle('fill', swx, swy, 20, c.h - 8, 3, 3)
      love.graphics.setColor(1,1,1,1)
      love.graphics.rectangle('line', swx, swy, 20, c.h - 8, 3, 3)
      -- four mini sliders
      local tx = swx + 28
      local tw = c.w - (tx - c.x) - 8
      local spacing = 8
      local cw = math.max(12, math.floor((tw - spacing*3) / 4))
      local ty = y + 12
      for i = 1, 4 do
        local chx = tx + (i - 1) * (cw + spacing)
        local t = clamp((c.value[i] or 0), 0, 1)
        love.graphics.setColor(0.2,0.2,0.2,1)
        love.graphics.rectangle('fill', chx, ty, cw, 4, 2, 2)
        love.graphics.setColor(0.6,0.6,0.6,1)
        love.graphics.rectangle('line', chx, ty, cw, 4, 2, 2)
        local fx = chx + t * cw
        love.graphics.setColor(0.3,0.7,0.9,1)
        love.graphics.circle('fill', fx, ty + 2, 5)
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
        Overlay.active = { kind='slider', def=c.def, control=c }
        return true
      end
    elseif c.kind == 'checkbox' then
      local r = { x = c.x, y = cy, w = c.w, h = c.h }
      if pointIn(x, y, r) then
        c.value = not c.value
        if c._dynamic then
          Overlay.applyDynamicChange(owner, c.def, c.value and true or false)
        else
          apply_change(c.def, c.value and true or false, owner, Overlay.context)
        end
        return true
      end
    elseif c.kind == 'enum' then
      local r = { x = c.x, y = cy, w = c.w, h = c.h }
      if pointIn(x, y, r) then
        -- Cycle through options
        local opts = c.options or {}
        if #opts > 0 then
            local idx = 1
            for i, v in ipairs(opts) do if v == c.value then idx = i break end end
            local nextVal = opts[(idx % #opts) + 1]
            c.value = nextVal
            if c._dynamic then
              Overlay.applyDynamicChange(owner, c.def, nextVal)
            else
              apply_change(c.def, nextVal, owner, Overlay.context)
            end
        end
        return true
      end
    elseif c.kind == 'color' then
      -- Determine channel hit
      local swx = c.x + 120
      local tx = swx + 28
      local tw = c.w - (tx - c.x) - 8
      local spacing = 8
      local cw = math.max(12, math.floor((tw - spacing*3) / 4))
      local ty = cy + 12
      for iChan = 1, 4 do
        local chx = tx + (iChan - 1) * (cw + spacing)
        local r = { x = chx, y = ty - 10, w = cw, h = 20 }
        if pointIn(x, y, r) then
          Overlay.active = { kind='color', def=c.def, control=c, channel=iChan }
          return true
        end
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
  local shift = love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
  if ctrl and (key == 's') then
    if context == 'anim_lab' and shift then
      -- Save animation overrides
      local AnimationSpecs = require 'src.animation_specs'
      AnimationSpecs.saveOverrides()
    else
      Config.saveOverrides()
    end
    return true
  elseif ctrl and (key == 'r') then
    -- Reset all visible tunables
    local visible = {}
    if context == 'anim_lab' and shift then
      -- Reset current card animation spec
      if owner and owner.cards then
        local def = owner.cards[owner.attackerIndex]
        if def then
          local AnimationSpecs = require 'src.animation_specs'
          AnimationSpecs.resetCard(def.id)
        end
      end
    else
      for _, c in ipairs(Overlay.controls or {}) do
        if c.def and c.def.path then
          Config.reset(c.def.path)
        end
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

-- Apply dynamic (per-card animation) changes from overlay
function Overlay.applyDynamicChange(owner, def, value)
  if not owner or not owner.cards then return end
  local cardDef = owner.cards[owner.attackerIndex]
  if not cardDef then return end
  if not (def.dynGroup == 'flight') then return end
  local AnimationSpecs = require 'src.animation_specs'
  local patch = { flight = { [def.dynKey] = value } }
  AnimationSpecs.setCardSpec(cardDef.id, patch)
end

return Overlay
