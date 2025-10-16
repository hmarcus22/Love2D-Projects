local ResolveRenderer = {}
local Viewport = require "src.viewport"

-- Classify a log line into a coarse type for coloring/filtering
local function classify(s)
    if not s then return 'sys' end
    local sl = tostring(s):lower()
    local function has(needle)
        return sl:find(needle, 1, true) ~= nil
    end

    -- Ultimates: highlight any ultimate actions distinctly
    if has('ultimate:') then
        return 'ult'
    end

    -- Combat: attacks and offensives (attack step)
    if has('[attack]') or has(' attacks ') or has(' hits ') or has(' strikes ') then
        return 'atk'
    end
    -- Buffs that influence combat
    if has('powers up') then
        return 'atk'
    end

    -- Block step and block gains
    if has('[block]') then
        return 'blk'
    end
    -- Avoid misclassifying attack lines that mention block absorption; check plain block fallback after attack checks
    if has(' block ') or sl:match("%+%d+%s*block") then
        return 'blk'
    end

    -- Heals
    if has('[heal]') or has(' hp') or has('heals') then
        return 'heal'
    end
    -- Energy gains (separate from heals)
    if has('[energy]') or has(' energy') then
        return 'energy'
    end

    -- System/state updates, round/match flow, stuns, resolve start/end, draws/discards
    if has('resolve phase') or has('resolving') or has('unknown resolve step') then
        return 'sys'
    end
    if has('round') or has('match') or has('double ko') or has('wins the') then
        return 'sys'
    end
    if has('coin toss') or has('starts') then
        return 'sys'
    end
    if has('stun') or has('untargetable') or has('invulnerable') then
        return 'sys'
    end
    if has('draws ') or has('discards ') or has('pass') then
        return 'sys'
    end

    return 'sys'
end

local function matchesFilter(kind, filter)
    if not filter or filter == 'all' then return true end
    if filter == 'combat' then return (kind == 'atk' or kind == 'blk' or kind == 'ult') end
    if filter == 'heals' then return (kind == 'heal') end
    if filter == 'energy' then return (kind == 'energy') end
    if filter == 'system' then return (kind == 'sys') end
    return true
end

local function getFilteredLog(state)
    local raw = state.resolveLog or {}
    local filter = state.resolveLogFilter or 'all'
    local out = {}
    for _, msg in ipairs(raw) do
        if matchesFilter(classify(msg), filter) then
            table.insert(out, msg)
        end
    end
    return out, filter
end

-- Public: expose filtered log for input/scroll logic
function ResolveRenderer.getFilteredLog(state)
    return getFilteredLog(state)
end

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
            local cfgOk, Cfg = pcall(require, 'src.config')
            local useFancy = cfgOk and Cfg and Cfg.ui and Cfg.ui.arrows and Cfg.ui.arrows.apply and Cfg.ui.arrows.apply.resolve or false
            local arrow = Arrow({ax, ay}, {bx2, by2}, {
                color = {0.9, 0.2, 0.2, 0.8},
                thickness = 2,
                headSize = 12,
                useFancy = useFancy,
            })
            -- TEMP DISABLED: arrow:draw() -- Testing for asymmetry interference
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
    local filtered, filter = getFilteredLog(state)
    local total = #filtered
    local visibleLines = math.min(total, maxLines)
    local maxOffset = math.max(0, total - maxLines)
    local offset = math.max(0, math.min(math.floor(state.resolveLogScroll or 0), maxOffset))
    local panelH = titleH + visibleLines * lineH + 10

    -- Panel
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    local labelMap = { all = "All", combat = "Combat", heals = "Heals", energy = "Energy", system = "System" }
    local header = string.format("Combat Log - %s  [L to change]", labelMap[filter] or "All")
    love.graphics.print(header, panelX + 8, panelY + 4)
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

    for i = startIdx, total do
        local msg = filtered[i]
        local kind = classify(msg)

        -- Color by type
        if kind == 'ult' then
            love.graphics.setColor(1.0, 0.85, 0.4, 1)
        elseif kind == 'atk' then
            love.graphics.setColor(0.95, 0.45, 0.4, 1)
        elseif kind == 'blk' then
            love.graphics.setColor(0.45, 0.65, 0.95, 1)
        elseif kind == 'heal' then
            love.graphics.setColor(0.45, 0.95, 0.45, 1)
        elseif kind == 'energy' then
            love.graphics.setColor(0.35, 0.95, 0.95, 1)
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
    local filtered = getFilteredLog(state)
    local total = #filtered
    local visibleLines = math.min(total, maxLines)
    local panelH = titleH + visibleLines * lineH + 10
    return panelX, panelY, panelW, panelH
end

function ResolveRenderer.draw(state, layout, screenW)
    ResolveRenderer.drawOverlay(state, layout, screenW)
    ResolveRenderer.drawLog(state, screenW)
end

return ResolveRenderer
