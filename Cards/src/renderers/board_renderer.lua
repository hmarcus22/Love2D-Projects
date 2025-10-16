local BoardRenderer = {}
local Viewport = require "src.viewport"
local Targeting = require "src.logic.targeting"

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

local Arrow = require "src.ui.arrow"
local function drawModifierDecorations(mods, slotX, slotY, cardW, cardH)
    local direction, attack, block, heal = summarizeModifierEffects(mods)
    if (attack ~= 0) or (block ~= 0) or (heal ~= 0) or direction then
        love.graphics.setColor(1, 1, 0, 0.6)
        love.graphics.rectangle("line", slotX - 2, slotY - 2, cardW + 4, cardH + 4, 8, 8)
    end

    if direction then
        local startX = slotX + cardW / 2
        local startY = slotY + cardH / 2
        local endX = slotX + cardW / 2 + direction * (cardW * 0.45)
        local endY = slotY + cardH / 2
        local cfgOk, Cfg = pcall(require, 'src.config')
        local useFancy = cfgOk and Cfg and Cfg.ui and Cfg.ui.arrows and Cfg.ui.arrows.apply and Cfg.ui.arrows.apply.modifiers or false
        local arrow = Arrow({startX, startY}, {endX, endY}, {
            color = {0.9, 0.2, 0.2, 0.8},
            headSize = 14,
            useFancy = useFancy,
        })
        arrow:draw() -- RE-ENABLED: Fancy arrows now work with bilateral concavity!
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

function BoardRenderer.collectAttackTargets(state, playerIndex, slotIndex)
    return Targeting.collectAttackTargets(state, playerIndex, slotIndex)
end

local function drawAttackIndicators(state, layout, playerIndex, slotIndex, slotX, slotY, cardW, cardH, targets)
    if not targets or #targets == 0 then
        return
    end

    local startCenterX = slotX + cardW / 2
    local startCenterY = slotY + cardH / 2

    for _, target in ipairs(targets) do
        local targetX, targetY = state:getBoardSlotPosition(target.player, target.slot)
        local targetCenterX = targetX + cardW / 2
        local targetCenterY = targetY + cardH / 2
        local dx = targetCenterX - startCenterX
        local dy = targetCenterY - startCenterY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 1 then dist = 1 end

        local insetStart = cardH * 0.5 + 6
        local insetEnd = cardH * 0.5 + 6
        local sx = startCenterX + dx / dist * insetStart
        local sy = startCenterY + dy / dist * insetStart
        local ex = targetCenterX - dx / dist * insetEnd
        local ey = targetCenterY - dy / dist * insetEnd

        local cfgOk2, Cfg2 = pcall(require, 'src.config')
        local useFancy2 = cfgOk2 and Cfg2 and Cfg2.ui and Cfg2.ui.arrows and Cfg2.ui.arrows.apply and Cfg2.ui.arrows.apply.attackIndicators or false
        local arrow = Arrow({sx, sy}, {ex, ey}, {
            color = {1, 1, 0.2, 0.85},
            headSize = 10,
            useFancy = useFancy2,
        })
        arrow:draw() -- RE-ENABLED: Fancy arrows now work with bilateral concavity!
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function BoardRenderer.draw(state, layout)
    local cardW, cardH = layout.cardW, layout.cardH
    local pending = state.hasPendingRetarget and state:hasPendingRetarget() and state:getPendingRetarget() or nil
    local validTargets = nil
    local cursorX, cursorY = nil, nil
    if pending then
        local mx, my = love.mouse.getPosition()
        if mx and my then
            cursorX, cursorY = Viewport.toVirtual(mx, my)
        end
        validTargets = {}
        local baseSlot = pending.sourceSlotIndex or 0
        local opponentIndex = pending.opponentPlayerIndex
        local sourceIndex = pending.sourcePlayerIndex
        if opponentIndex then
            validTargets[opponentIndex] = {}
            local opponentSlots = state.players and state.players[opponentIndex] and state.players[opponentIndex].boardSlots or {}
            local maxSlots = state.maxBoardCards or #opponentSlots
            if maxSlots == 0 then
                maxSlots = #opponentSlots
            end
            for offset = -1, 1 do
                local slot = baseSlot + offset
                if maxSlots <= 0 then
                    if slot == baseSlot then
                        validTargets[opponentIndex][slot] = true
                    end
                elseif slot >= 1 and slot <= maxSlots then
                    validTargets[opponentIndex][slot] = true
                end
            end
        end
        if sourceIndex then
            validTargets[sourceIndex] = validTargets[sourceIndex] or {}
            validTargets[sourceIndex][baseSlot] = true
        end
    end

    for playerIndex, player in ipairs(state.players) do
        local passiveMods = player.getBoardPassiveMods and player:getBoardPassiveMods() or nil
        local passiveBlock = passiveMods and passiveMods.block or 0
        for slotIndex, slot in ipairs(player.boardSlots) do
            local slotX, slotY = state:getBoardSlotPosition(playerIndex, slotIndex)
            -- Optional pixel snapping so slot frame aligns with textured card edges at all scales
            local Config = require 'src.config'
            local layoutCfg = Config.layout or {}
            if layoutCfg.pixelPerfect then
                slotX = math.floor(slotX + 0.5)
                slotY = math.floor(slotY + 0.5)
            end
            -- High-contrast slot outline (dark outer + light inner)
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX - 1, slotY - 1, cardW + 2, cardH + 2, 10, 10)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slotX, slotY, cardW, cardH, 8, 8)

            local isPending = pending ~= nil
            local validSlot = false
            local hoveredSlot = false
            if isPending and validTargets then
                local targetMap = validTargets[playerIndex]
                validSlot = targetMap and targetMap[slotIndex] or false
                if validSlot and cursorX and cursorY then
                    hoveredSlot = cursorX >= slotX and cursorX <= slotX + cardW and cursorY >= slotY and cursorY <= slotY + cardH
                end
            end

            local attackTargets = nil

            if slot.card then
                if slot.card.dragging and slot.card.dragX and slot.card.dragY then
                    slot.card.x = slot.card.dragX
                    slot.card.y = slot.card.dragY
                else
                slot.card.x = slotX
                slot.card.y = slotY
                end
                -- Ensure card size matches current layout for board slots
                slot.card.w = cardW
                slot.card.h = cardH
                

                
                local CardRenderer = require "src.card_renderer"
                -- Avoid double drawing: let overlay render animating cards; board draws after completion
                -- Always draw board card to ensure visibility, even while animation overlay may also render
                CardRenderer.draw(slot.card)
                -- Debug ownership marker: board = blue dot
                local ok, Config = pcall(require, 'src.config')
                if ok and Config and Config.ui and Config.ui.debugAnimationLanding then
                    love.graphics.setColor(0.2, 0.4, 1.0, 0.9)
                    love.graphics.rectangle('fill', slot.card.x + 2, slot.card.y + 2, 6, 6)
                    love.graphics.setColor(1,1,1,1)
                end

                attackTargets = BoardRenderer.collectAttackTargets(state, playerIndex, slotIndex)

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

            if isPending then
                if validSlot then
                    if hoveredSlot then
                        love.graphics.setColor(1, 1, 1, 0.18)
                        love.graphics.rectangle("fill", slotX, slotY, cardW, cardH, 8, 8)
                        love.graphics.setColor(1, 1, 0.3, 0.9)
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle("line", slotX - 2, slotY - 2, cardW + 4, cardH + 4, 10, 10)
                        love.graphics.setLineWidth(1)
                        love.graphics.setColor(1, 1, 1, 1)
                    else
                        love.graphics.setColor(1, 1, 1, 0.08)
                        love.graphics.rectangle("fill", slotX, slotY, cardW, cardH, 8, 8)
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                else
                    love.graphics.setColor(0, 0, 0, 0.35)
                    love.graphics.rectangle("fill", slotX, slotY, cardW, cardH, 8, 8)
                    love.graphics.setColor(1, 1, 1, 1)
                end
            end

            if attackTargets and #attackTargets > 0 then
                drawAttackIndicators(state, layout, playerIndex, slotIndex, slotX, slotY, cardW, cardH, attackTargets)
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
