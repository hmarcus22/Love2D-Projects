local HoverUtils = {}

-- Returns last matching index (topmost in typical draw stacking)
function HoverUtils.topmostIndex(items, hitFn)
    local top
    for i = 1, #items do
        if hitFn(items[i], i) then top = i end
    end
    return top
end

-- Asymmetric tween step for hover amount
-- amt: current [0..1], target: 0 or 1, dt, inSpeed, outSpeed
function HoverUtils.stepAmount(amt, target, dt, inSpeed, outSpeed)
    local inS = inSpeed or 12
    local outS = outSpeed or inS
    local kIn = math.min(1, (dt or 0) * inS)
    local kOut = math.min(1, (dt or 0) * outS)
    local k = (target > amt) and kIn or kOut
    return amt + (target - amt) * k
end

-- Compute scaled draw rect from base rect + hover amount and scale factor
function HoverUtils.scaledRect(x, y, w, h, amount, hoverScale)
    local amt = amount or 0
    local hs = hoverScale or 0
    local s = 1 + hs * amt
    local dw = math.floor(w * s)
    local dh = math.floor(h * s)
    local dx = x - math.floor((dw - w) / 2)
    local dy = y - math.floor((dh - h) / 2)
    return dx, dy, dw, dh
end

-- Simple point-in-rect
function HoverUtils.hit(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Hit test against scaled rect (computed with current amount/scale)
function HoverUtils.hitScaled(mx, my, x, y, w, h, amount, hoverScale)
    local dx, dy, dw, dh = HoverUtils.scaledRect(x, y, w, h, amount, hoverScale)
    return HoverUtils.hit(mx, my, dx, dy, dw, dh)
end

-- Draw soft hover shadow behind a rect
function HoverUtils.drawShadow(dx, dy, dw, dh, amount)
    local amt = amount or 0
    if amt <= 0.01 then return end
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", dx + 2, dy + 2, dw + 12, dh + 12, 10, 10)
    love.graphics.setColor(0, 0, 0, 0.12)
    love.graphics.rectangle("fill", dx + 1, dy + 1, dw + 6, dh + 6, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
end

return HoverUtils

