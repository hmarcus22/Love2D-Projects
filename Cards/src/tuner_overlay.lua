local Config = require "src.config"
local Viewport = require "src.viewport"
local Deep = require "src.utils.deep"
local Tunables = require "src.tunable_defs"
local UnifiedSpecs = require 'src.unified_animation_specs'

local Overlay = {
  open = false,
  controls = {},
  scroll = 0,
  active = nil,
  context = 'game',
  collapsedCategories = {}, -- Track which categories are collapsed
  editingDefaults = false, -- Toggle between card-specific and default editing
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

  -- Inject dynamic unified animation spec controls in anim_lab context
  if context == 'anim_lab' and Overlay._labOwner and Overlay._labOwner.cards then
    local owner = Overlay._labOwner
    local def = owner.cards[owner.attackerIndex]
    if def then
      local cid = def.id
      
      -- Get base unified spec and card-specific overrides
      local baseSpec = UnifiedSpecs.unified
      local cardSpec = UnifiedSpecs[cid] or {}
      
      categories['Unified Animation'] = categories['Unified Animation'] or {}
      
      -- Mode toggle header
      local modeText = Overlay.editingDefaults and "EDITING: Default Animations (affects all cards)" or ("EDITING: " .. cid .. " (card-specific)")
      table.insert(categories['Unified Animation'], { 
        kind='hint', 
        text=modeText
      })
      
      -- Mode toggle button
      local toggleText = Overlay.editingDefaults and "Switch to Card-Specific" or "Switch to Default Editing"
      table.insert(categories['Unified Animation'], { 
        kind='button', 
        text=toggleText,
        action='toggle_editing_mode'
      })
      
      -- Helper function to get current value with card override or default based on mode
      local function getCurrentValue(phase, key, defaultValue)
        if Overlay.editingDefaults then
          -- Editing defaults - show base spec values
          if baseSpec[phase] and baseSpec[phase][key] ~= nil then
            return baseSpec[phase][key]
          end
          return defaultValue
        else
          -- Editing card-specific - show card overrides or base
          if cardSpec[phase] and cardSpec[phase][key] ~= nil then
            return cardSpec[phase][key]
          elseif baseSpec[phase] and baseSpec[phase][key] ~= nil then
            return baseSpec[phase][key]
          end
          return defaultValue
        end
      end
      
      -- Helper function to get nested value
      local function getNestedValue(phase, path, defaultValue)
        if Overlay.editingDefaults then
          -- Editing defaults - show base spec values
          local current = baseSpec[phase]
          if not current then return defaultValue end
          
          for segment in path:gmatch("[^%.]+") do
            if current[segment] == nil then return defaultValue end
            current = current[segment]
          end
          return current or defaultValue
        else
          -- Editing card-specific - show card overrides or base
          local current = cardSpec[phase] or baseSpec[phase]
          if not current then return defaultValue end
          
          for segment in path:gmatch("[^%.]+") do
            if current[segment] == nil then
              current = baseSpec[phase]
              if not current then return defaultValue end
              for innerSegment in path:gmatch("[^%.]+") do
                if current[innerSegment] == nil then return defaultValue end
                current = current[innerSegment]
              end
              return current
            end
            current = current[segment]
          end
          return current or defaultValue
        end
      end
      
      -- Flight Phase Controls
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Phase 3: Flight"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='flight', dynKey='duration', 
        label='Flight Duration', type='number', min=0.05, max=2.0, step=0.01, 
        value=getCurrentValue('flight', 'duration', 0.35)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='flight', dynKey='trajectory.height', 
        label='Trajectory Height', type='number', min=0, max=300, step=5, 
        value=getNestedValue('flight', 'trajectory.height', 140)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='flight', dynKey='trajectory.type', 
        label='Trajectory Type', type='enum', 
        options={'ballistic', 'guided', 'straight', 'slam_drop'}, 
        value=getNestedValue('flight', 'trajectory.type', 'ballistic')
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='flight', dynKey='physics.gravity', 
        label='Gravity', type='number', min=200, max=2000, step=10, 
        value=getNestedValue('flight', 'physics.gravity', 980)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='flight', dynKey='physics.airResistance', 
        label='Air Resistance', type='number', min=0.0, max=0.1, step=0.001, 
        value=getNestedValue('flight', 'physics.airResistance', 0.02)
      })
      
      -- Preparation Phase Controls
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Phase 1: Preparation"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='preparation', dynKey='duration', 
        label='Prep Duration', type='number', min=0.05, max=1.0, step=0.01, 
        value=getCurrentValue('preparation', 'duration', 0.3)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='preparation', dynKey='scale', 
        label='Prep Scale', type='number', min=0.8, max=1.5, step=0.01, 
        value=getCurrentValue('preparation', 'scale', 1.1)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='preparation', dynKey='elevation', 
        label='Prep Elevation', type='number', min=0, max=20, step=1, 
        value=getCurrentValue('preparation', 'elevation', 5)
      })
      
      -- Launch Phase Controls
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Phase 2: Launch"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='launch', dynKey='duration', 
        label='Launch Duration', type='number', min=0.05, max=0.8, step=0.01, 
        value=getCurrentValue('launch', 'duration', 0.2)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='launch', dynKey='angle', 
        label='Launch Angle', type='number', min=0, max=60, step=1, 
        value=getCurrentValue('launch', 'angle', 25)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='launch', dynKey='initialVelocity', 
        label='Initial Velocity', type='number', min=200, max=1200, step=10, 
        value=getCurrentValue('launch', 'initialVelocity', 800)
      })
      
      -- Impact Phase Controls  
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Phase 5: Impact"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='impact', dynKey='duration', 
        label='Impact Duration', type='number', min=0.05, max=1.0, step=0.01, 
        value=getCurrentValue('impact', 'duration', 0.4)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='impact', dynKey='collision.squash', 
        label='Squash Scale', type='number', min=0.5, max=1.0, step=0.01, 
        value=getNestedValue('impact', 'collision.squash', 0.85)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='impact', dynKey='collision.bounce', 
        label='Bounce Scale', type='number', min=1.0, max=2.0, step=0.01, 
        value=getNestedValue('impact', 'collision.bounce', 1.3)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='impact', dynKey='effects.screen.shake.intensity', 
        label='Shake Intensity', type='number', min=0, max=20, step=0.5, 
        value=getNestedValue('impact', 'effects.screen.shake.intensity', 6)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='impact', dynKey='effects.screen.shake.duration', 
        label='Shake Duration', type='number', min=0, max=1, step=0.01, 
        value=getNestedValue('impact', 'effects.screen.shake.duration', 0.25)
      })
      
      -- Settle Phase Controls
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Phase 6: Settle"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='settle', dynKey='duration', 
        label='Settle Duration', type='number', min=0.05, max=2.0, step=0.01, 
        value=getCurrentValue('settle', 'duration', 0.6)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='settle', dynKey='elasticity', 
        label='Elasticity', type='number', min=0.1, max=1.0, step=0.01, 
        value=getCurrentValue('settle', 'elasticity', 0.8)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='settle', dynKey='damping', 
        label='Damping', type='number', min=0.1, max=1.0, step=0.01, 
        value=getCurrentValue('settle', 'damping', 0.9)
      })
      
      -- Board State Phase Controls
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Board State Phase"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='board_state', dynKey='idle.breathing.enabled', 
        label='Breathing Enabled', type='boolean', 
        value=getNestedValue('board_state', 'idle.breathing.enabled', true)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='board_state', dynKey='idle.breathing.amplitude', 
        label='Breathing Amplitude', type='number', min=0, max=0.1, step=0.001, 
        value=getNestedValue('board_state', 'idle.breathing.amplitude', 0.02)
      })
      
      -- Game Resolve Phase Controls (for knockback-style effects)
      table.insert(categories['Unified Animation'], { 
        kind='header', 
        text="Game Resolve Phase"
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='game_resolve', dynKey='area_knockback.enabled', 
        label='Area Knockback Enabled', type='boolean', 
        value=getNestedValue('game_resolve', 'area_knockback.enabled', false)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='game_resolve', dynKey='area_knockback.radius', 
        label='Knockback Radius', type='number', min=50, max=800, step=10, 
        value=getNestedValue('game_resolve', 'area_knockback.radius', 80)
      })
      
      table.insert(categories['Unified Animation'], { 
        _dynamic=true, dynGroup='game_resolve', dynKey='area_knockback.force', 
        label='Knockback Force', type='number', min=10, max=600, step=10, 
        value=getNestedValue('game_resolve', 'area_knockback.force', 50)
      })
      
      -- Save / Reset buttons hint
      table.insert(categories['Unified Animation'], { 
        kind='hint', 
        text='Shift+S: save unified anim overrides | Shift+R: reset this card'
      })
    end
  end

  local panelH = hHeader
  local panelTitle = animLab and 'Tuner (Animation Lab)' or ('Tuner ('..context..')')
  table.insert(controls, { kind='panel', x=x, y=y, w=w, h=0, title=panelTitle })
  y = y + hHeader
  panelH = panelH + 8

  -- Category sections
  for cat, defs in pairs(categories) do
    -- Check if category is collapsed (default to true for most categories)
    local isCollapsed = Overlay.collapsedCategories[cat]
    if isCollapsed == nil then
      -- Default state: collapse everything except key categories
      isCollapsed = not (cat == 'Card Text' or cat == 'Layout' or cat == 'Card Rendering')
      Overlay.collapsedCategories[cat] = isCollapsed
    end
    
    local indicator = isCollapsed and "▶" or "▼"
    local categoryText = indicator .. " " .. cat
    table.insert(controls, { kind='category_header', text=categoryText, category=cat, x=innerX, y=y, w=innerW, h=rowH, collapsed=isCollapsed })
    y = y + rowH
    panelH = panelH + rowH
    
    -- Only show category contents if not collapsed
    if not isCollapsed then
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
          elseif d.kind == 'button' then
            table.insert(controls, { kind='button', text=d.text, action=d.action, x=innerX, y=y, w=innerW, h=rowH })
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
        elseif d.kind == 'button' then
          table.insert(controls, { kind='button', text=d.text, action=d.action, x=innerX, y=y, w=innerW, h=rowH })
          y = y + rowH
          panelH = panelH + rowH
        end
      end
    end
    
    -- Add spacing only if category was expanded
    if not isCollapsed then
      panelH = panelH + 8
      y = y + 8
    end
  end

  -- Footer hint
  table.insert(controls, { kind='hint', text='F10: toggle  |  Ctrl+S: save  Ctrl+R: reset visible', x=innerX, y=y, w=innerW, h=rowH })
  panelH = panelH + rowH

  -- Update panel height
  controls[1].h = panelH
  return controls
end

-- Toggle editing mode between defaults and card-specific
function Overlay.toggleEditingMode()
  Overlay.editingDefaults = not Overlay.editingDefaults
  -- Rebuild controls to reflect new mode
  Overlay.controls = build_controls(Overlay.context)
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
    -- Clear texture cache if font size, panel size, Y offset, or panel alpha changed
    if def.path and (def.path:find('FontSize') or def.path:find('PanelHeight') or def.path:find('PanelPadding') or def.path:find('YOffset') or def.path:find('PanelAlpha')) then
      local CardTextureCache = require "src.renderers.card_texture_cache"
      CardTextureCache.onFontChange()
    end
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
      local activeCtrl = Overlay.active.control
      -- For non-dynamic controls, try to find by path as fallback
      if not activeCtrl and Overlay.active.def and Overlay.active.def.path then
        activeCtrl = find_control(Overlay.active.def.path, 'slider')
      end
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
      local activeCtrl = Overlay.active.control
      -- For non-dynamic controls, try to find by path as fallback
      if not activeCtrl and Overlay.active.def and Overlay.active.def.path then
        activeCtrl = find_control(Overlay.active.def.path, 'color')
      end
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
    elseif c.kind == 'category_header' then
      -- Draw clickable category header
      love.graphics.setColor(1, 1, 0.8, 1)
      love.graphics.printf(c.text or '', c.x, y + 6, c.w, 'left')
      love.graphics.setColor(1, 1, 1, 1)
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
    elseif c.kind == 'button' then
      -- Draw button background
      local bg_color = c.pressed and {0.4, 0.6, 0.4, 1} or {0.3, 0.3, 0.3, 1}
      love.graphics.setColor(bg_color[1], bg_color[2], bg_color[3], bg_color[4])
      love.graphics.rectangle('fill', c.x, y + 2, c.w, c.h - 4, 4, 4)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle('line', c.x, y + 2, c.w, c.h - 4, 4, 4)
      -- Draw button text
      love.graphics.printf(c.text or '', c.x, y + 6, c.w, 'center')
    end
  end
end

function Overlay.mousepressed(x, y, button, context, owner)
  if not Overlay.open then return false end
  Overlay.context = context or Overlay.context
  -- hit test controls
  for i = #Overlay.controls, 1, -1 do
    local c = Overlay.controls[i]
    -- Apply scroll offset only to non-panel controls (panels are fixed)
    local cy = c.kind == 'panel' and c.y or (c.y - (Overlay.scroll or 0))
    if c.kind == 'category_header' then
      local r = { x = c.x, y = cy, w = c.w, h = c.h }
      if pointIn(x, y, r) then
        -- Toggle collapse state for this category
        Overlay.collapsedCategories[c.category] = not (Overlay.collapsedCategories[c.category] or false)
        -- Rebuild controls to reflect new state
        Overlay.controls = build_controls(Overlay.context)
        return true
      end
    elseif c.kind == 'slider' then
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
    elseif c.kind == 'button' then
      local cy = c.y - (Overlay.scroll or 0)
      local r = { x = c.x, y = cy, w = c.w, h = c.h }
      if pointIn(x, y, r) then
        c.pressed = true
        if c.action == 'toggle_editing_mode' then
          Overlay.toggleEditingMode()
        elseif c.action and type(c.action) == 'function' then
          c.action()
        end
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
  
  -- Clear button pressed states
  for _, c in ipairs(Overlay.controls) do
    if c.kind == 'button' then
      c.pressed = false
    end
  end
  
  -- If we have an active control being dragged, handle it
  if Overlay.active then
    Overlay.active = nil
    return true -- Consume the event since we were interacting with a control
  end
  
  -- Check if the release is within the overlay panel area
  for i = #Overlay.controls, 1, -1 do
    local c = Overlay.controls[i]
    if c.kind == 'panel' then
      local r = { x=c.x, y=c.y, w=c.w, h=c.h }
      if pointIn(x, y, r) then 
        return true -- Consume event if released within overlay panel
      end
    end
  end
  
  return false -- Don't consume the event, let it pass through to game systems
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
      -- Save unified animation overrides
      local UnifiedSpecs = require 'src.unified_animation_specs'
      UnifiedSpecs.saveOverrides()
    else
      Config.saveOverrides()
    end
    return true
  elseif ctrl and (key == 'r') then
    -- Reset all visible tunables
    local visible = {}
    if context == 'anim_lab' and shift then
      -- Reset current card unified animation spec
      if owner and owner.cards then
        local def = owner.cards[owner.attackerIndex]
        if def then
          local UnifiedSpecs = require 'src.unified_animation_specs'
          UnifiedSpecs.resetCard(def.id)
        end
      end
    else
      local shouldClearCache = false
      for _, c in ipairs(Overlay.controls or {}) do
        if c.def and c.def.path then
          Config.reset(c.def.path)
          if c.def.path:find('FontSize') then
            shouldClearCache = true
          end
        end
      end
      -- Clear texture cache if any font size was reset
      if shouldClearCache then
        local CardTextureCache = require "src.renderers.card_texture_cache"
        CardTextureCache.onFontChange()
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

-- Apply dynamic (unified animation) changes from overlay
function Overlay.applyDynamicChange(owner, def, value)
  if not owner or not owner.cards then return end
  local cardDef = owner.cards[owner.attackerIndex]
  if not cardDef then return end
  
  local UnifiedSpecs = require 'src.unified_animation_specs'
  
  -- Apply change to unified specs
  if Overlay.editingDefaults then
    -- Editing defaults - modify base spec
    if def.dynGroup == 'flight' then
      UnifiedSpecs.setDefaultProperty('flight', def.dynKey, value)
    elseif def.dynGroup == 'impact' then
      UnifiedSpecs.setDefaultProperty('impact', def.dynKey, value)
    elseif def.dynGroup == 'board_state' then
      UnifiedSpecs.setDefaultProperty('board_state', def.dynKey, value)
    elseif def.dynGroup == 'game_resolve' then
      UnifiedSpecs.setDefaultProperty('game_resolve', def.dynKey, value)
    end
  else
    -- Editing card-specific - modify card overrides
    if def.dynGroup == 'flight' then
      UnifiedSpecs.setCardProperty(cardDef.id, 'flight', def.dynKey, value)
    elseif def.dynGroup == 'impact' then
      UnifiedSpecs.setCardProperty(cardDef.id, 'impact', def.dynKey, value)
    elseif def.dynGroup == 'board_state' then
      UnifiedSpecs.setCardProperty(cardDef.id, 'board_state', def.dynKey, value)
    elseif def.dynGroup == 'game_resolve' then
      UnifiedSpecs.setCardProperty(cardDef.id, 'game_resolve', def.dynKey, value)
    end
  end
end

return Overlay
