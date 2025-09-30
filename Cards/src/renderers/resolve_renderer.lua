local ResolveRenderer = {}
local Viewport = require "src.viewport"

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
            local Arrow = require "src.ui.arrow"
            local arrow = Arrow({ax, ay}, {bx2, by2}, {
                color = {0.9, 0.2, 0.2, 0.8},
                thickness = 2,
                headSize = 12
            })
            arrow:draw()
            love.graphics.setColor(0.9, 0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", tx, ty, cardW, cardH, 8, 8)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(string.format("Resolving %s on slot %d", step.kind, step.slot), 0, 20, screenW, "center")
end

function ResolveRenderer.drawLog(state, screenW)
    local panelW = 300
    local panelX = screenW - panelW - 16
    -- Move below player 2 panel (y ≈ 16 + 158 + margin)
    local panelY = 196
    local lineH = 16
    local titleH = 20
    local maxLines = state.maxResolveLogLines or 14
    local total = #state.resolveLog
    local visibleLines = math.min(total, maxLines)
    local maxOffset = math.max(0, total - maxLines)
    local offset = math.max(0, math.min(math.floor(state.resolveLogScroll or 0), maxOffset))
    local panelH = titleH + visibleLines * lineH + 10

    -- Panel
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.print("Combat Log", panelX + 8, panelY + 4)
    if maxOffset > 0 then
        local startIdxPreview = math.max(1, total - maxLines + 1 - offset)
        local pageBottom = startIdxPreview
        local pageTop = math.min(total, startIdxPreview + visibleLines - 1)
        local label = string.format("%d-%d/%d", pageBottom, pageTop, total)
        love.graphics.printf(label, panelX, panelY + 4, panelW - 8, "right")
    end

    -- Lines (clipped to panel)
    local startIdx = math.max(1, total - maxLines + 1 - offset)
    local y = panelY + titleH

    -- Set scissor in screen coordinates to clip log contents
    local clipX, clipY = panelX + 4, panelY + titleH
    local clipW, clipH = panelW - 8, panelH - titleH - 4
    local sx = math.floor(Viewport.ox + clipX * Viewport.scale)
    local sy = math.floor(Viewport.oy + clipY * Viewport.scale)
    local sw = math.floor(clipW * Viewport.scale)
    local sh = math.floor(clipH * Viewport.scale)
    love.graphics.setScissor(sx, sy, sw, sh)

    local function classify(s)
        if not s then return 'sys' end
        if s:find('%[Attack%]') or s:find('attacks') or s:find('hits') then return 'atk' end
        if s:find('%[Block%]') or s:find('block') then return 'blk' end
        if s:find('%[Heal%]') or s:find('energy') then return 'heal' end
        if s:find('round') or s:find('pass') or s:find('Resolving') then return 'sys' end
        return 'sys'
    end

    for i = startIdx, total do
        local msg = state.resolveLog[i]
        local kind = classify(msg)

        -- Color by type
        if kind == 'atk' then
            love.graphics.setColor(0.95, 0.45, 0.4, 1)
        elseif kind == 'blk' then
            love.graphics.setColor(0.45, 0.65, 0.95, 1)
        elseif kind == 'heal' then
            love.graphics.setColor(0.45, 0.95, 0.45, 1)
        else
            love.graphics.setColor(1, 1, 1, 0.95)
        end

        -- Fade older entries within the visible window
        local pos = i - startIdx + 1 -- 1..visibleLines
        local age = visibleLines - pos -- 0 newest at bottom
        local fade = 1.0
        if age >= 6 then fade = 0.55 elseif age >= 3 then fade = 0.75 end
        local r, g, b, _ = love.graphics.getColor()
        love.graphics.setColor(r, g, b, fade)

        -- Prevent embedded newlines from breaking layout; no wrapping
        local oneLine = (msg or ""):gsub("\n", " ")
        love.graphics.print(oneLine, panelX + 8, y)
        y = y + lineH
    end

    -- Clear scissor
    love.graphics.setScissor()

    love.graphics.setColor(1, 1, 1, 1)
end

-- Expose log panel bounds for hover-aware scrolling
function ResolveRenderer.getLogPanelRect(state, screenW)
    local panelW = 300
    local panelX = screenW - panelW - 16
    local panelY = 196
    local lineH = 16
    local titleH = 20
    local maxLines = state.maxResolveLogLines or 14
    local total = #(state.resolveLog or {})
    local visibleLines = math.min(total, maxLines)
    local panelH = titleH + visibleLines * lineH + 10
    return panelX, panelY, panelW, panelH
end

function ResolveRenderer.draw(state, layout, screenW)
    ResolveRenderer.drawOverlay(state, layout, screenW)
    ResolveRenderer.drawLog(state, screenW)
end

return ResolveRenderer
