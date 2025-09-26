local Input = {}
local Config = require "src.config"

local function pointInRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx+rw and y >= ry and y <= ry+rh
end

local function hoveredBoardSlot(gs, playerIndex, x, y)
    local cardW, cardH = gs:getCardDimensions()
    for i, _ in ipairs(gs.players[playerIndex].boardSlots) do
        local sx, sy = gs:getBoardSlotPosition(playerIndex, i)
        if pointInRect(x, y, sx, sy, cardW, cardH) then
            return i
        end
    end
    return nil
end

function Input:handleRetargetClick(gs, x, y)
    local pending = gs.getPendingRetarget and gs:getPendingRetarget()
    if not pending then
        return true
    end

    local opponent = pending.opponentPlayerIndex
    local sourcePlayer = pending.sourcePlayerIndex
    local targetSlot = nil
    if gs.players and gs.players[opponent] then
        targetSlot = hoveredBoardSlot(gs, opponent, x, y)
    end
    if targetSlot then
        gs:selectRetargetSlot(opponent, targetSlot)
        return true
    end

    local sourceSlot = nil
    if gs.players and gs.players[sourcePlayer] then
        sourceSlot = hoveredBoardSlot(gs, sourcePlayer, x, y)
    end
    if sourceSlot and sourceSlot == pending.sourceSlotIndex then
        gs:selectRetargetSlot(sourcePlayer, sourceSlot)
        return true
    end

    return true
end

function Input:mousepressed(gs, x, y, button)
    if button ~= 1 then return end

    if gs.hasPendingRetarget and gs:hasPendingRetarget() then
        self:handleRetargetClick(gs, x, y)
        return
    end

    local current = gs:getCurrentPlayer()

    if gs.phase ~= "play" then return end

    -- Click-to-draw from current player's deck (only during play phase)
    local deckX, deckY, deckW, deckH = gs:getDeckRect()
    if Config.rules.allowManualDraw and gs.phase == "play" and gs.deckStack and pointInRect(x, y, deckX, deckY, deckW, deckH) then
        gs:drawCardToPlayer(gs.currentPlayer)
        return
    end

    -- Click Pass button using Button object for accurate hitbox
    if gs.phase == "play" and gs._passButton and gs._passButton:isHovered(x, y) then
        gs._passButton:click(x, y)
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
            c.faceUp = true -- Always show card face while dragging
            local cardW, cardH = gs:getCardDimensions()
            c.w = cardW or 100
            c.h = cardH or 150
            -- Do NOT remove the card from its slot while dragging
            -- current.slots[i].card = nil
            break
        end
    end
end

function Input:mousereleased(gs, x, y, button)
    if gs.hasPendingRetarget and gs:hasPendingRetarget() then
        return
    end

    if button ~= 1 or not gs.draggingCard then return end
    local card = gs.draggingCard
    local current = gs:getCurrentPlayer()
    local cardW = select(1, gs:getCardDimensions())

    if Config.rules.allowManualDiscard and Config.rules.showDiscardPile and gs.discardStack and gs.discardStack:isHovered(x, y) then
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
                        retargetOffset = nil
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
                    local ok = gs:playCardFromHand(card, idx)
                    if not ok and card.owner then card.owner:snapCard(card, gs) end
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
    if gs.hasPendingRetarget and gs:hasPendingRetarget() then
        return
    end

    if key == "space" then
        gs:advanceTurn()
    elseif key == "return" or key == "kpenter" then
        gs:passTurn()
    end
end

function Input:update(gs, dt)
    -- Animate dragging card to follow mouse
    if gs.draggingCard then
        local mx, my = love.mouse.getPosition()
        local Viewport = require "src.viewport"
        mx, my = Viewport.toVirtual(mx, my)
        gs.draggingCard.x = mx - (gs.draggingCard.offsetX or 0)
        gs.draggingCard.y = my - (gs.draggingCard.offsetY or 0)
        gs.draggingCard.faceUp = true -- Always show card face while dragging
        print(string.format("[DEBUG] Dragging card '%s' at (%.1f, %.1f)", gs.draggingCard.name or "?", gs.draggingCard.x, gs.draggingCard.y))
    end
end

return Input
