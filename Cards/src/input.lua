local Input = {}

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end

local function hoveredBoardSlot(player, x, y)
    for i, bslot in ipairs(player.boardSlots) do
        if pointInRect(x, y, bslot.x, bslot.y, 100, 150) then
            return i
        end
    end
    return nil
end

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end
    local current = gs:getCurrentPlayer()

    -- Click-to-draw from current player's deck
    local deckX, deckY = 20, love.graphics.getHeight() - 170
    if x >= deckX and x <= deckX + 100 and y >= deckY and y <= deckY + 150 then
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
            local idx = hoveredBoardSlot(current, x, y)
            if idx and (not current.boardSlots[idx].card) then
                gs:playCardFromHand(card, idx)  -- 🔴 pass chosen slot
            else
                if card.owner then card.owner:snapCard(card) end
            end
        else
            if card.owner then card.owner:snapCard(card) end
        end
    end

    card.dragging = false
    gs.draggingCard = nil
    gs.highlightDiscard = false
end

function Input:keypressed(gs, key)
    if key == "space" then
        gs:nextPlayer()
    end
end

return Input
