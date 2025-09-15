local Viewport = {}

-- Virtual design resolution
Viewport.vw = 3840
Viewport.vh = 2160

-- Calculated
Viewport.scale = 1
Viewport.ox = 0
Viewport.oy = 0

function Viewport.setup(vw, vh)
    Viewport.vw = vw or Viewport.vw
    Viewport.vh = vh or Viewport.vh
    local sw, sh = love.graphics.getDimensions()
    Viewport.resize(sw, sh)
end

function Viewport.resize(sw, sh)
    local sx = sw / Viewport.vw
    local sy = sh / Viewport.vh
    Viewport.scale = math.min(sx, sy)
    -- center (letterbox) offsets
    Viewport.ox = math.floor((sw - Viewport.vw * Viewport.scale) / 2)
    Viewport.oy = math.floor((sh - Viewport.vh * Viewport.scale) / 2)
end

function Viewport.apply()
    love.graphics.push()
    love.graphics.translate(Viewport.ox, Viewport.oy)
    love.graphics.scale(Viewport.scale, Viewport.scale)
end

function Viewport.unapply()
    love.graphics.pop()
end

function Viewport.toVirtual(x, y)
    local vx = (x - Viewport.ox) / Viewport.scale
    local vy = (y - Viewport.oy) / Viewport.scale
    return vx, vy
end

function Viewport.getWidth()
    return Viewport.vw
end

function Viewport.getHeight()
    return Viewport.vh
end

return Viewport

