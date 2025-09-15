local Input = {}
local Viewport = require "src.viewport"

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end

local function hoveredBoardSlot(gs, playerIndex, x, y)
    for i, _ in ipairs(gs.players[playerIndex].boardSlots) do
        local sx, sy = gs:getBoardSlotPosition(playerIndex, i)
        if pointInRect(x, y, sx, sy, 100, 150) then
            return i
        end
    end
    return nil
end

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end
    local current = gs:getCurrentPlayer()

    if gs.phase ~= "play" then return end

    -- Click-to-draw from current player's deck (only during play phase)
    local deckX, deckY = 20, Viewport.getHeight() - 170
    if gs.phase == "play" and x >= deckX and x <= deckX + 100 and y >= deckY and y <= deckY + 150 then
        gs:drawCardToPlayer(gs.currentPlayer)
        return
    end

    -- Pick up a hand card (top-down)
    for i = #current.slots, 1, -1 do
        local c = current.slots[i].card
        if c and c:isHovered(x, y) then
            gs.draggingCard = c
            c.dragging = true
            c.offsetX = x - c.x
            c.offsetY = y - c.y
            -- free its hand slot temporarily so the outline shows
            current.slots[i].card = nil
            break
        end
    end
end

function Input:mousereleased(gs, x, y, button)
    if button ~= 1 or not gs.draggingCard then return end
    local card = gs.draggingCard
    local current = gs:getCurrentPlayer()

    if gs.discardStack and gs.discardStack:isHovered(x, y) then
        gs:discardCard(card)
    else
        if gs.phase == "play" and card.owner == current then
            local def = card.definition or {}
            local isModifier = def.mod ~= nil
            if isModifier then
                -- try play onto any hovered occupied board slot (ally or enemy), based on drop position
                local targetPi, targetIdx = nil, nil
                for pi = 1, #gs.players do
                    local idx = hoveredBoardSlot(gs, pi, x, y)
                    if idx and gs.players[pi].boardSlots[idx].card then
                        targetPi, targetIdx = pi, idx
                        break
                    end
                end
                if targetPi and targetIdx then
                    local retargetOffset = nil
                    if def.mod and def.mod.retarget then
                        -- decide left/right by drop x relative to target slot center
                        local sx, sy = gs:getBoardSlotPosition(targetPi, targetIdx)
                        local centerX = sx + 50
                        retargetOffset = (x < centerX) and -1 or 1
                    end
                    local ok = gs:playModifierOnSlot(card, targetPi, targetIdx, retargetOffset)
                    if not ok and card.owner then card.owner:snapCard(card, gs) end
                else
                    if card.owner then card.owner:snapCard(card, gs) end
                end
            else
                -- normal card: must be dropped on an empty slot of current player
                local idx = hoveredBoardSlot(gs, gs.currentPlayer, x, y)
                if idx and (not current.boardSlots[idx].card) then
                    gs:playCardFromHand(card, idx)
                else
                    if card.owner then card.owner:snapCard(card, gs) end
                end
            end
        else
            if card.owner then card.owner:snapCard(card, gs) end
        end
    end

    card.dragging = false
    gs.draggingCard = nil
    gs.highlightDiscard = false
end

function Input:keypressed(gs, key)
    if key == "space" then
        gs:advanceTurn()
    end
end

return Input
