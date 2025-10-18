-- impact_fx.lua
-- Centralized lightweight impact / landing effects (shake, dust, etc.)
local ImpactFX = {}

function ImpactFX.triggerShake(state, duration, magnitude)
  state._shake = { t = 0, dur = duration or 0.25, mag = magnitude or 6 }
end

function ImpactFX.triggerDust(state, x, y, count)
  state._dustBursts = state._dustBursts or {}
  local n = math.max(1, math.floor(tonumber(count) or 1))
  local twoPi = math.pi * 2
  for i = 1, n do
    -- Small random offset so multiple rings form a visible burst
    local angle = (love.math and love.math.random and love.math.random() or math.random()) * twoPi
    local offset = 4 + ((love.math and love.math.random and love.math.random() or math.random()) * 12)
    local ox = math.cos(angle) * offset
    local oy = math.sin(angle) * offset
    -- Slight duration variance to avoid perfectly synchronized rings
    local durRand = (love.math and love.math.random and love.math.random() or math.random())
    local dur = 0.28 + durRand * 0.14 -- ~0.28..0.42s
    table.insert(state._dustBursts, { x = x + ox, y = y + oy, t = 0, dur = dur })
  end
end

function ImpactFX.update(state, dt)
  if state._shake then
    state._shake.t = state._shake.t + dt
    if state._shake.t >= state._shake.dur then
      state._shake = nil
    end
  end
  if state._dustBursts then
    for i = #state._dustBursts, 1, -1 do
      local b = state._dustBursts[i]
      b.t = b.t + dt
      if b.t >= b.dur then table.remove(state._dustBursts, i) end
    end
    if #state._dustBursts == 0 then state._dustBursts = nil end
  end
end

function ImpactFX.applyShakeTransform(state)
  if not state._shake then return false end
  local k = 1 - (state._shake.t / state._shake.dur)
  local mag = state._shake.mag * k
  local ox = (love.math.random() * 2 - 1) * mag
  local oy = (love.math.random() * 2 - 1) * mag
  love.graphics.push()
  love.graphics.translate(ox, oy)
  return true
end

function ImpactFX.drawDust(state)
  if not state._dustBursts then return end
  -- Determine a scale reference from current card dimensions to keep visuals consistent at any resolution
  local refW, refH = 100, 150
  if state and state.getCardDimensions then
    local w, h = state:getCardDimensions()
    if type(w) == 'number' and w > 0 then refW = w end
    if type(h) == 'number' and h > 0 then refH = h end
  else
    local ok, Config = pcall(require, 'src.config')
    if ok and Config and Config.layout then
      refW = Config.layout.cardW or refW
      refH = Config.layout.cardH or refH
    end
  end
  local maxDim = math.max(refW, refH)

  for _, b in ipairs(state._dustBursts) do
    local t = b.t / b.dur
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local alpha = 1 - t
    -- Radius grows well beyond the card, scaled by layout size
    local startR = maxDim * 0.18
    local endR = maxDim * 1.05
    local radius = startR + (endR - startR) * (t ^ 0.5)

    love.graphics.setColor(1, 0.9, 0.6, alpha * 0.6)
    local lw = math.max(1, (maxDim * 0.025) * (1 - t))
    love.graphics.setLineWidth(lw)
    love.graphics.circle('line', b.x, b.y, radius)
    love.graphics.setColor(1,1,1,1)
  end
  -- Restore default line width
  love.graphics.setLineWidth(1)
end

return ImpactFX
