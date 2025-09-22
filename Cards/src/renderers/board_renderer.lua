local BoardRenderer = {}

local function drawPassiveBadge(x, y, w, h, color, text)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.9)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(text, x, y + 2, w, "center")
end

local function summarizeModifierEffects(mods)
    local direction, attack, block, heal = nil, 0, 0, 0
    for _, mod in ipairs(mods) do
        if mod.retargetOffset then direction = mod.retargetOffset end
        attack = attack + (mod.attack or 0)
        block = block + (mod.block or 0)
        heal = heal + (mod.heal or 0)
    end
    return direction, attack, block, heal
end

local function drawModifierDecorations(mods, slotX, slotY, cardW, cardH)
    local direction, attack, block, heal = summarizeModifierEffects(mods)
    if (attack ~= 0) or (block ~= 0) or (heal ~= 0) or direction then
        love.graphics.setColor(1, 1, 0, 0.6)
        love.graphics.rectangle("line", slotX - 2, slotY - 2, cardW + 4, cardH + 4, 8, 8)
    end

    if direction then
        love.graphics.setColor(0.9, 0.2, 0.2, 0.8)
        local triX = slotX + (direction < 0 and math.floor(cardW * 0.1) or (cardW - math.floor(cardW * 0.1)))
        local triY = slotY + math.floor(cardH * 0.08)
        if direction < 0 then
            love.graphics.polygon("fill", triX, triY, triX + 10, triY - 6, triX + 10, triY + 6)
        else
            love.graphics.polygon("fill", triX, triY, triX - 10, triY - 6, triX - 10, triY + 6)
        end
    end

    local function drawBadge(x, y, bg, text)
        love.graphics.setColor(bg[1], bg[2], bg[3], bg[4] or 0.9)
        love.graphics.rectangle("fill", x - 1, y - 1, 34, 16, 4, 4)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("line", x - 1, y - 1, 34, 16, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(text, x, y + 2, 32, "center")
    end

    local badgeX = slotX + 6
    local badgeY = slotY + 28
    if attack ~= 0 then
        local txt = (attack > 0 and "+" .. attack or tostring(attack)) .. " A"
        drawBadge(badgeX, badgeY, {0.8, 0.2, 0.2, 0.9}, txt)
        badgeX = badgeX + 36
    end
    if block ~= 0 then
        local txt = (block > 0 and "+" .. block or tostring(block)) .. " B"
        drawBadge(badgeX, badgeY, {0.2, 0.4, 0.8, 0.9}, txt)
        badgeX = badgeX + 36
    end
    if heal ~= 0 then
        local txt = (heal > 0 and "+" .. heal or tostring(heal)) .. " H"
        drawBadge(badgeX, badgeY, {0.2, 0.8, 0.2, 0.9}, txt)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function BoardRenderer.draw(state, layout)
    local cardW, cardH = layout.cardW, layout.cardH
    for playerIndex, player in ipairs(state.players) do
        local passiveMods = player.getBoardPassiveMods and player:getBoardPassiveMods() or nil
        local passiveBlock = passiveMods and passiveMods.block or 0
        for slotIndex, slot in ipairs(player.boardSlots) do
            local slotX, slotY = state:getBoardSlotPosition(playerIndex, slotIndex)
            love.graphics.setColor(0.8, 0.8, 0.2, 0.35)
            love.graphics.rectangle("line", slotX, slotY, cardW, cardH, 8, 8)

            if slot.card then
                slot.card.x = slotX
                slot.card.y = slotY
                slot.card:draw()

                local statVariance = slot.card.statVariance
                if statVariance then
                    local roll = statVariance.attack
                    if roll and roll ~= 0 then
                        local badgeW, badgeH = 36, 18
                        local badgeX = slotX + cardW - badgeW - 6
                        local badgeY = slotY + 6
                        local color = (roll > 0) and {0.25, 0.7, 0.25, 0.95} or {0.8, 0.25, 0.25, 0.95}
                        drawPassiveBadge(badgeX, badgeY, badgeW, badgeH, color, string.format("%+dA", roll))
                    end
                end

                local mods = state.attachments and state.attachments[playerIndex] and state.attachments[playerIndex][slotIndex]
                if mods and #mods > 0 then
                    drawModifierDecorations(mods, slotX, slotY, cardW, cardH)
                end
            end

            if passiveBlock ~= 0 then
                local badgeW, badgeH = 34, 16
                local badgeX = slotX + 6
                local badgeY = slotY + 6
                drawPassiveBadge(badgeX, badgeY, badgeW, badgeH, {0.2, 0.4, 0.8, 0.85}, string.format("%+dB", passiveBlock))
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return BoardRenderer
