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
    -- Prefer phase-aware entries when available
    local entries = (gs.animations.getActiveAnimationEntries and gs.animations:getActiveAnimationEntries()) or nil
    local animating = entries or (gs.animations:getActiveAnimatingCards() or {})
    if #animating == 0 then return end

    -- Build a simple list of cards for sorting when using entries
    local sortList = animating
    if entries then
        sortList = {}
        for _, e in ipairs(entries) do sortList[#sortList+1] = e.card end
    end

    table.sort(sortList, sortAnimating)

    local function isOnBoard(card)
        if not gs or not gs.players then return false end
        for _, player in ipairs(gs.players or {}) do
            for _, slot in ipairs(player.boardSlots or {}) do
                if slot.card == card then return true end
            end
        end
        return false
    end

    -- Default card size fallback from layout
    local layout = gs.getLayout and gs:getLayout() or {}
    local defaultW = layout.cardW or 100
    local defaultH = layout.cardH or 150

    for idx, ref in ipairs(animating) do
        local card = ref.card or ref
        local phase = ref.phase
        -- Skip if card is already on the board; BoardRenderer will draw it and
        -- CardRenderer will honor animX/animY for smooth landing without double-draw.
        -- But always draw during flight/approach to guarantee visibility.
        if phase == 'flight' or phase == 'approach' or not isOnBoard(card) then
            -- Determine draw rect without mutating base card fields
            local x = (card.animX ~= nil) and card.animX or card.x
            local y = (card.animY ~= nil) and card.animY or card.y
            local w = card.w or defaultW
            local h = card.h or defaultH
            if x and y and w and h then
                CardRenderer.drawAt(card, x, y, w, h)
            end
        end
    end
end

return AnimationOverlay
