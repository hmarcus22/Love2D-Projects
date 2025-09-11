local Input = {}

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end

    local current = gs.players[gs.currentPlayer]

    -- detect click on current player's deck
    local deckX = (gs.currentPlayer == 1) and 20 or 880
    local deckY = current.y
    if x >= deckX and x <= deckX + 100 and y >= deckY and y <= deckY + 150 then
        gs:drawCardToPlayer(gs.currentPlayer)
        return
    end


    -- check cards
    for i = #current.hand, 1, -1 do
        local c = current.hand[i]
        if c:isHovered(x, y) then
            gs.draggingCard = c
            c.dragging = true
            c.offsetX = x - c.x
            c.offsetY = y - c.y
            -- free its slot temporarily
            if c.slotIndex and current.slots[c.slotIndex] then
                current.slots[c.slotIndex].card = nil
            end
            break
        end
    end
end


function Input:mousereleased(gs, x, y, button)
    if button == 1 and gs.draggingCard then
        if gs.discardStack:isHovered(x, y) then
            gs:discardCard(gs.draggingCard)
        else
            -- snap back into slot
            if gs.draggingCard.owner then
                gs.draggingCard.owner:snapCard(gs.draggingCard)
            end
        end
        gs.draggingCard.dragging = false
        gs.draggingCard = nil
        gs.highlightDiscard = false
    end
end

function Input:keypressed(gs, key)
    if key == "space" then
        gs.currentPlayer = gs.currentPlayer % #gs.players + 1
        gs:updateCardVisibility()
    end
end

return Input