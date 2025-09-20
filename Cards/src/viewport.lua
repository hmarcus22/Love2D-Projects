local Viewport = {}

-- Virtual design resolution
Viewport.designW = 3840
Viewport.designH = 2160
Viewport.scaleFactor = 1
Viewport.vw = Viewport.designW
Viewport.vh = Viewport.designH

-- Calculated
Viewport.scale = 1
Viewport.ox = 0
Viewport.oy = 0
Viewport.sw = nil
Viewport.sh = nil

local function updateVirtualSize()
    local factor = Viewport.scaleFactor or 1
    if factor < 0.1 then factor = 0.1 end
    Viewport.vw = Viewport.designW / factor
    Viewport.vh = Viewport.designH / factor
end

function Viewport.setup(vw, vh, opts)
    if vw then Viewport.designW = vw end
    if vh then Viewport.designH = vh end
    opts = opts or {}
    if opts.scale then
        Viewport.scaleFactor = math.max(opts.scale, 0.1)
    end
    updateVirtualSize()
    local sw, sh = love.graphics.getDimensions()
    if sw == 0 or sh == 0 then
        sw, sh = Viewport.designW, Viewport.designH
    end
    Viewport.resize(sw, sh)
end

function Viewport.resize(sw, sh)
    Viewport.sw = sw
    Viewport.sh = sh
    local sx = sw / Viewport.vw
    local sy = sh / Viewport.vh
    Viewport.scale = math.min(sx, sy)
    -- center (letterbox) offsets
    Viewport.ox = math.floor((sw - Viewport.vw * Viewport.scale) / 2)
    Viewport.oy = math.floor((sh - Viewport.vh * Viewport.scale) / 2)
end

function Viewport.setScaleFactor(scale)
    Viewport.scaleFactor = math.max(scale or 1, 0.1)
    updateVirtualSize()
    if Viewport.sw and Viewport.sh then
        Viewport.resize(Viewport.sw, Viewport.sh)
    else
        local sw, sh = love.graphics.getDimensions()
        Viewport.resize(sw, sh)
    end
end

function Viewport.getScaleFactor()
    return Viewport.scaleFactor
end

function Viewport.getDesignWidth()
    return Viewport.designW
end

function Viewport.getDesignHeight()
    return Viewport.designH
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
