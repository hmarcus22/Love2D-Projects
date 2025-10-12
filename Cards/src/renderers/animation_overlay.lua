-- animation_overlay.lua
-- Renders cards that are currently being animated by the unified animation system.
-- Responsibility: draw only. No state updates here.

local CardRenderer = require 'src.card_renderer'

local AnimationOverlay = {}

-- Sort animating cards to produce stable draw order during flight.
-- Heuristic: by Y then Z so nearer-to-bottom and lifted cards appear on top.
local function sortAnimating(a, b)
    local ay = (a.animY ~= nil) and a.animY or a.y or 0
    local by = (b.animY ~= nil) and b.animY or b.y or 0
    if ay ~= by then return ay < by end
    local az = a.animZ or 0
    local bz = b.animZ or 0
    return az < bz
end

function AnimationOverlay.draw(gs)
    if not gs or not gs.animations or not gs.animations.getActiveAnimatingCards then
        return
    end
    local animating = gs.animations:getActiveAnimatingCards() or {}
    if #animating == 0 then return end

    table.sort(animating, sortAnimating)

    for _, card in ipairs(animating) do
        -- Determine draw rect without mutating base card fields
        local x = (card.animX ~= nil) and card.animX or card.x
        local y = (card.animY ~= nil) and card.animY or card.y
        local w = card.w
        local h = card.h
        if x and y and w and h then
            CardRenderer.drawAt(card, x, y, w, h)
        end
    end
end

return AnimationOverlay

