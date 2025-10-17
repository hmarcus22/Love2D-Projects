-- Consolidated highlight utilities for all visual effects
local HighlightUtils = {}

-- Legacy compatibility
local HoverUtils = HighlightUtils

-- Get highlight configuration from config with fallbacks
local function getHighlightConfig(type, key, fallback)
    local Config = require 'src.config'
    local highlights = Config.layout and Config.layout.highlights
    if highlights and highlights[type] and highlights[type][key] ~= nil then
        return highlights[type][key]
    end
    return fallback
end

-- Draw hover glow effect around a card
function HighlightUtils.drawHover(card, x, y, w, h, amount)
    if not amount or amount <= 0.01 then return end
    
    local color = getHighlightConfig('hover', 'color', {1, 1, 0.8, 0.85})
    local width = getHighlightConfig('hover', 'width', 3)
    local extraWidth = getHighlightConfig('hover', 'extraWidth', 2)
    
    local lw = width + (amount * extraWidth)
    love.graphics.setColor(color[1], color[2], color[3], color[4] * amount)
    love.graphics.setLineWidth(lw)
    love.graphics.rectangle('line', x - lw/2, y - lw/2, w + lw, h + lw, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Draw combo glow effect (green-white cycling)
function HighlightUtils.drawCombo(card, x, y, w, h, time)
    if not card.comboGlow then return end
    
    local cycleSpeed = getHighlightConfig('combo', 'cycleSpeed', 4)
    local green = getHighlightConfig('combo', 'greenColor', {0.0, 1.0, 0.0, 1.0})
    local white = getHighlightConfig('combo', 'whiteColor', {1.0, 1.0, 1.0, 1.0})
    local width = getHighlightConfig('combo', 'width', 6)
    local borderRadius = getHighlightConfig('combo', 'borderRadius', 15)
    local borderOffset = getHighlightConfig('combo', 'borderOffset', 4)
    
    local cycle = math.sin(time * cycleSpeed) * 0.5 + 0.5  -- 0 to 1 sine wave
    
    -- Interpolate between green and white
    local r = green[1] + (white[1] - green[1]) * cycle
    local g = green[2] + (white[2] - green[2]) * cycle
    local b = green[3] + (white[3] - green[3]) * cycle
    local a = green[4] + (white[4] - green[4]) * cycle
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(width)
    love.graphics.rectangle('line', 
        x - borderOffset, y - borderOffset, 
        w + borderOffset * 2, h + borderOffset * 2, 
        borderRadius, borderRadius)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Draw impact flash effect
function HighlightUtils.drawImpact(card, x, y, w, h, flashAmount)
    if not flashAmount or flashAmount <= 0.01 then return end
    
    local flashColor = getHighlightConfig('impact', 'flashColor', {1, 1, 0.6})
    
    love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], flashAmount)
    love.graphics.rectangle('fill', x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Update hover state with proper animation timing
function HighlightUtils.updateHoverAmount(card, target, dt)
    if not card then return end
    
    local inSpeed = getHighlightConfig('hover', 'inSpeed', 14)
    local outSpeed = getHighlightConfig('hover', 'outSpeed', 20)
    
    local current = card.handHoverAmount or 0
    local updated = HighlightUtils.stepAmount(current, target, dt, inSpeed, outSpeed)
    card.handHoverAmount = updated
    return updated
end

-- Returns last matching index (topmost in typical draw stacking)
-- Topmost item detection utility
function HighlightUtils.topmostIndex(items, hitFn)
    local top
    for i = 1, #items do
        if hitFn(items[i], i) then top = i end
    end
    return top
end

-- Asymmetric tween step for amount values
function HighlightUtils.stepAmount(amt, target, dt, inSpeed, outSpeed)
    local inS = inSpeed or 12
    local outS = outSpeed or inS
    local kIn = math.min(1, (dt or 0) * inS)
    local kOut = math.min(1, (dt or 0) * outS)
    local k = (target > amt) and kIn or kOut
    return amt + (target - amt) * k
end

-- Compute scaled draw rect from base rect + hover amount and scale factor
function HighlightUtils.scaledRect(x, y, w, h, amount, hoverScale)
    local amt = amount or 0
    local hs = hoverScale or 0
    local s = 1 + hs * amt
    local dw = math.floor(w * s)
    local dh = math.floor(h * s)
    local dx = x - math.floor((dw - w) / 2)
    local dy = y - math.floor((dh - h) / 2)
    return dx, dy, dw, dh
end

-- NEW: Compute scaled draw rect using unified height-scale system
function HighlightUtils.scaledRectUnified(x, y, w, h, element)
    local UnifiedHeightScale = require 'src.unified_height_scale'
    local scaleX, scaleY = UnifiedHeightScale.getDrawScale(element)
    
    local dw = math.floor(w * scaleX)
    local dh = math.floor(h * scaleY)
    local dx = x - math.floor((dw - w) / 2)
    local dy = y - math.floor((dh - h) / 2)
    
    -- Debug output for unified scaling
    UnifiedHeightScale.debugInfo(element, "hover_rect")
    
    return dx, dy, dw, dh, scaleX, scaleY
end

-- Hit test using unified scaling
function HighlightUtils.hitScaledUnified(mx, my, x, y, w, h, element)
    local dx, dy, dw, dh = HighlightUtils.scaledRectUnified(x, y, w, h, element)
    return HighlightUtils.hit(mx, my, dx, dy, dw, dh)
end

-- Simple point-in-rect hit testing
function HighlightUtils.hit(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- Hit test against scaled rect (computed with current amount/scale)
function HighlightUtils.hitScaled(mx, my, x, y, w, h, amount, hoverScale)
    local dx, dy, dw, dh = HighlightUtils.scaledRect(x, y, w, h, amount, hoverScale)
    return HighlightUtils.hit(mx, my, dx, dy, dw, dh)
end

-- Draw soft shadow behind a rect
function HighlightUtils.drawShadow(dx, dy, dw, dh, amount)
    -- DISABLED: Shadow rendering now handled centrally by ShadowRenderer
    -- The centralized system draws shadows at the correct z-order
    return
end

-- Legacy compatibility aliases
HoverUtils.stepAmount = HighlightUtils.stepAmount
HoverUtils.scaledRect = HighlightUtils.scaledRect
HoverUtils.hit = HighlightUtils.hit
HoverUtils.hitScaled = HighlightUtils.hitScaled
HoverUtils.drawShadow = HighlightUtils.drawShadow
HoverUtils.topmostIndex = HighlightUtils.topmostIndex

-- NEW: Unified height-scale system exports
HoverUtils.scaledRectUnified = HighlightUtils.scaledRectUnified
HoverUtils.hitScaledUnified = HighlightUtils.hitScaledUnified

return HighlightUtils

