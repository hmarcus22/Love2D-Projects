local Input = {}

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end

local function hoveredBoardSlot(p, x, y)
    for i, bslot in ipairs(p.boardSlots) do
        if pointInRect(x, y, bslot.x, bslot.y, 100, 150) then
            return i
        end
    end
    return nil
end

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end

    local current = gs:getCurrentPlayer()

    -- detect click on current player's deck
    local deckX = (gs.currentPlayer == 1) and 20 or 880
    local deckY = current.y
    if x >= deckX and x <= deckX + 100 and y >= deckY and y <= deckY + 150 then
        gs:drawCardToPlayer(gs.currentPlayer)
        return
    end

    -- check cards (from top down)
    for i = #current.slots, 1, -1 do
        local c = current.slots[i].card
        if c and c:isHovered(x, y) then
            gs.draggingCard = c
            c.dragging = true
            c.offsetX = x - c.x
            c.offsetY = y - c.y
            -- free its slot temporarily
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
        -- if we're in play phase and released over current player's board area -> play it
        if gs.phase == "play" and card.owner == current then
            local idx = hoveredBoardSlot(current, x, y)
            if idx then
                -- Let GameState handle rules & turn advance
                gs:playCardFromHand(card)
                gs.draggingCard = nil
                gs.highlightDiscard = false
                return
            end
        end
        -- otherwise snap back to hand
        if card.owner then
            card.owner:snapCard(card)
        end
    end

    gs.draggingCard.dragging = false
    gs.draggingCard = nil
    gs.highlightDiscard = false
end


function Input:keypressed(gs, key)
    if key == "space" then
        gs:nextPlayer()
    end
end

return Input
