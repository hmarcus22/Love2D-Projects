local Input = {}

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end

    local current = gs.players[gs.currentPlayer]

    -- detect deck click (unchanged) ...

    -- check cards
    for i = #current.hand, 1, -1 do
        local c = current.hand[i]
        if c:isHovered(x, y) then
            gs.draggingCard = c
            c.dragging = true
            c.offsetX = x - c.x
            c.offsetY = y - c.y
            -- free its slot temporarily
            if c.slotIndex then
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