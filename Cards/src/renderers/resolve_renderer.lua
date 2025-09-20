local ResolveRenderer = {}

function ResolveRenderer.drawOverlay(state, layout, screenW)
    if state.phase ~= "resolve" or not state.resolveCurrentStep then return end

    local cardW, cardH = layout.cardW, layout.cardH
    local step = state.resolveCurrentStep
    local colors = {
        block = {0.2, 0.4, 0.9, 0.35},
        heal = {0.2, 0.8, 0.2, 0.35},
        attack = {0.9, 0.2, 0.2, 0.35},
        cleanup = {0.6, 0.6, 0.6, 0.3},
    }
    local color = colors[step.kind] or {1, 1, 0, 0.3}

    if step.kind ~= "attack" then
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        for playerIndex = 1, #state.players do
            local sx, sy = state:getBoardSlotPosition(playerIndex, step.slot)
            love.graphics.rectangle("fill", sx, sy, cardW, cardH, 8, 8)
        end
    else
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        for playerIndex = 1, #state.players do
            local sx, sy = state:getBoardSlotPosition(playerIndex, step.slot)
            love.graphics.rectangle("fill", sx, sy, cardW, cardH, 8, 8)

            local mods = state.activeMods and state.activeMods[playerIndex] and state.activeMods[playerIndex].perSlot and state.activeMods[playerIndex].perSlot[step.slot]
            local offset = mods and mods.retargetOffset or 0
            local targetSlot = step.slot + offset
            local maxSlots = state.maxBoardCards or (#state.players[playerIndex].boardSlots)
            if targetSlot < 1 or targetSlot > maxSlots then
                targetSlot = step.slot
            end
            local enemyIndex = (playerIndex == 1) and 2 or 1
            local tx, ty = state:getBoardSlotPosition(enemyIndex, targetSlot)
            love.graphics.setColor(0.9, 0.2, 0.2, 0.8)
            local ax = sx + cardW / 2
            local ay = sy + cardH / 2
            local bx2 = tx + cardW / 2
            local by2 = ty + cardH / 2
            love.graphics.setLineWidth(2)
            love.graphics.line(ax, ay, bx2, by2)
            love.graphics.setColor(0.9, 0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", tx, ty, cardW, cardH, 8, 8)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("Resolving %s on slot %d", step.kind, step.slot), 0, 20, screenW, "center")
end

function ResolveRenderer.drawLog(state, screenW)
    local panelW = 280
    local panelX = screenW - panelW - 16
    local panelY = 80
    local lineH = 16
    local titleH = 20
    local visibleLines = math.min(#state.resolveLog, state.maxResolveLogLines or 14)
    local panelH = titleH + visibleLines * lineH + 10

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.print("Log", panelX + 8, panelY + 4)

    love.graphics.setColor(1, 1, 1, 1)
    local startIdx = math.max(1, #state.resolveLog - (state.maxResolveLogLines or 14) + 1)
    local y = panelY + titleH
    for i = startIdx, #state.resolveLog do
        love.graphics.printf(state.resolveLog[i], panelX + 8, y, panelW - 16, "left")
        y = y + lineH
    end
end

function ResolveRenderer.draw(state, layout, screenW)
    ResolveRenderer.drawOverlay(state, layout, screenW)
    ResolveRenderer.drawLog(state, screenW)
end

return ResolveRenderer
