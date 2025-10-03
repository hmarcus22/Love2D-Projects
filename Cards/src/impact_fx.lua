-- impact_fx.lua
-- Centralized lightweight impact / landing effects (shake, dust, etc.)
local ImpactFX = {}

function ImpactFX.triggerShake(state, duration, magnitude)
  state._shake = { t = 0, dur = duration or 0.25, mag = magnitude or 6 }
end

function ImpactFX.triggerDust(state, x, y, count)
  state._dustBursts = state._dustBursts or {}
  table.insert(state._dustBursts, { x = x, y = y, t = 0, dur = 0.35 })
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
  for _, b in ipairs(state._dustBursts) do
    local t = b.t / b.dur
    local alpha = 1 - t
    local radius = 18 + 40 * (t ^ 0.6)
    love.graphics.setColor(1, 0.9, 0.6, alpha * 0.55)
    love.graphics.setLineWidth(3 * (1 - t))
    love.graphics.circle('line', b.x, b.y, radius)
    love.graphics.setColor(1,1,1,1)
    love.graphics.setLineWidth(1)
  end
end

return ImpactFX