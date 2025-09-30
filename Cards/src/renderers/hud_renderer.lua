local Config = require "src.config"
local Viewport = require "src.viewport"
local Button = require "src.ui.button"

local deckSummaryPopup = nil
local roundOverPopup = nil

local function countHandCards(player)
    local count = 0
    for _, slot in ipairs(player.slots or {}) do
        if slot.card then
            count = count + 1
        end
    end
    return count
end

local function countBoardCards(player)
    local count = 0
    for _, slot in ipairs(player.boardSlots or {}) do
        if slot.card then
            count = count + 1
        end
    end
    return count
end

local function computeHealthPreview(state, playerIndex, player)
    local maxHealth = math.max(1, math.floor(player.maxHealth or player.health or 1))
    local health = math.max(0, math.floor(player.health or maxHealth))
    local damage = 0
    local heal = 0
    if state.previewIncomingDamage then
        damage = math.max(0, math.floor(state:previewIncomingDamage(playerIndex) or 0))
    end
    if state.previewIncomingHeal then
        heal = math.max(0, math.floor(state:previewIncomingHeal(playerIndex) or 0))
    end
    local postDamage = math.max(0, health - damage)
    local expected = math.min(maxHealth, postDamage + heal)
    return {
        maxHealth = maxHealth,
        health = health,
        damage = damage,
        heal = heal,
        expected = expected,
    }
end

local function drawHealthBar(x, y, width, preview)
    local barHeight = 20
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", x, y, width, barHeight, 10, 10)

    local expectedRatio = preview.expected / preview.maxHealth
    love.graphics.setColor(0.25, 0.8, 0.3, 0.9)
    love.graphics.rectangle("fill", x, y, width * expectedRatio, barHeight, 10, 10)

    local currentRatio = preview.health / preview.maxHealth
    if preview.expected < preview.health then
        local lossWidth = width * (preview.health - preview.expected) / preview.maxHealth
        local lossX = x + width * expectedRatio
        love.graphics.setColor(0.9, 0.2, 0.2, 0.7)
        love.graphics.rectangle("fill", lossX, y, lossWidth, barHeight, 10, 10)
    elseif preview.expected > preview.health then
        local healWidth = width * (preview.expected - preview.health) / preview.maxHealth
        local healX = x + width * currentRatio
        love.graphics.setColor(0.3, 0.6, 1.0, 0.65)
        love.graphics.rectangle("fill", healX, y, healWidth, barHeight, 10, 10)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x, y, width, barHeight, 10, 10)
    love.graphics.printf(string.format("%d / %d", preview.health, preview.maxHealth), x, y + 2, width, "center")
end

local function ensurePassButton(state)
    if not state then return end

    local x, y, w, h = state:getPassButtonRect()
    local label = "Pass (Enter)"
    local defaultColor = Config.colors.passButton or {0.85, 0.85, 0.85, 1}
    local hoverColor = Config.colors.passButtonHover or {0.95, 0.95, 0.95, 1}

    if not state._passButton then
        state._passButton = Button{
            x = x,
            y = y,
            w = w,
            h = h,
            label = label,
            color = defaultColor,
            hoveredColor = hoverColor,
            textColor = {0, 0, 0, 1},
            onClick = function()
                if state.phase == "play" and state.passTurn then
                    state:passTurn()
                end
            end,
        }
        state._passButton.defaultColor = defaultColor
    else
        local btn = state._passButton
        btn.x, btn.y, btn.w, btn.h = x, y, w, h
        btn.label = label
    end

    local btn = state._passButton
    if btn then
        btn.visible = (state.phase == "play")
        btn.enabled = (state.phase == "play")
        btn.color = state.highlightPass and btn.hoveredColor or btn.defaultColor or defaultColor
    end
end

local function drawPassButton(state)
    ensurePassButton(state)
    if state._passButton then
        state._passButton:draw()
    end
end

local function drawPlayerPanel(state, player, index)
    if not player then return end

    local layout = state:getLayout()
    local panelW = 280
    local panelH = 158
    local marginX = layout.sideGap or 30
    local x = marginX
    if index ~= 1 then
        x = Viewport.getWidth() - panelW - marginX
    end
    local y = 16
    local isCurrent = (index == state.currentPlayer)
    local accent = player.getFighterColor and player:getFighterColor() or {0.85, 0.85, 0.85}

    love.graphics.setColor(0, 0, 0, isCurrent and 0.88 or 0.7)
    love.graphics.rectangle("fill", x, y, panelW, panelH, 12, 12)
    love.graphics.setColor(accent[1] or 0.85, accent[2] or 0.85, accent[3] or 0.85, isCurrent and 0.95 or 0.75)
    love.graphics.setLineWidth(isCurrent and 3 or 2)
    love.graphics.rectangle("line", x, y, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 1)
    local fighterName = (player.fighter and player.fighter.name) or player.fighterId or ""
    local header = string.format("P%d", player.id or index)
    if fighterName ~= "" then
        header = string.format("%s - %s", header, fighterName)
    end
    love.graphics.printf(header, x + 12, y + 8, panelW - 24, "left")

    local preview = computeHealthPreview(state, index, player)
    local barX = x + 12
    local textY = y + 32

    if isCurrent then
        love.graphics.setColor(1, 1, 0.2, 1)
        love.graphics.printf("► YOUR TURN", x + 12, textY, panelW - 24, "left")
        love.graphics.setColor(1, 1, 1, 1)
        textY = textY + 18
    end

    local barY = textY
    drawHealthBar(barX, barY, panelW - 24, preview)

    local block = math.floor(player.block or 0)
    textY = barY + 28
    local forecast
    if preview.damage > 0 or preview.heal > 0 then
        forecast = string.format("Forecast: -> %d (-%d +%d)", preview.expected, preview.damage, preview.heal)
    else
        forecast = "Forecast: steady"
    end
    love.graphics.printf(forecast, x + 12, textY, panelW - 24, "left")
    textY = textY + 16
    love.graphics.printf(string.format("Block: %d", block), x + 12, textY, panelW - 24, "left")
    textY = textY + 18

    if Config.rules.energyEnabled ~= false then
        local rules = Config.rules or {}
        local energy = math.floor(player.energy or 0)
        local roundIndex = state.roundIndex or 1
        local start = rules.energyStart or 0
        local inc = rules.energyIncrementPerRound or 0
        local cap = start + math.max(0, (roundIndex - 1)) * inc
        local maxRule = rules.energyMax
        if maxRule and maxRule > 0 then
            cap = math.min(cap, maxRule)
        end
        if cap <= 0 then
            cap = maxRule or start or energy
        end
        cap = math.max(cap or 0, energy)
        local energyLine
        if cap > 0 then
            energyLine = string.format("Energy: %d/%d", energy, cap)
        else
            energyLine = string.format("Energy: %d", energy)
        end
        love.graphics.printf(energyLine, x + 12, textY, panelW - 24, "left")
        textY = textY + 18
    end

    local handCount = countHandCards(player)
    local deckCount = #(player.deck or {})
    local discardCount = #(player.discard or {})
    love.graphics.printf(string.format("Hand: %d   Deck: %d   Discard: %d", handCount, deckCount, discardCount), x + 12, textY, panelW - 24, "left")
    textY = textY + 18

    local boardCount = countBoardCards(player)
    local boardCap = player.maxBoardCards or state.maxBoardCards or #player.boardSlots or boardCount
    love.graphics.printf(string.format("Board: %d/%d", boardCount, boardCap), x + 12, textY, panelW - 24, "left")
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawHud(state)
    if not state or not state.players then return end

    for index, player in ipairs(state.players) do
        drawPlayerPanel(state, player, index)
    end

    drawPassButton(state)
end

local function getDeckSummary(deck)
    local counts = {}
    for _, card in ipairs(deck or {}) do
        local name = card.name or card.id or "?"
        counts[name] = (counts[name] or 0) + 1
    end
    local summary = {}
    for name, count in pairs(counts) do
        table.insert(summary, string.format("%s x%d", name, count))
    end
    table.sort(summary)
    return table.concat(summary, "\n")
end

local function showDeckSummary(player)
    deckSummaryPopup = {
        player = player,
        text = getDeckSummary(player.deck),
        timer = 3.5,
    }
end

local function showRoundOver(winner, score, onNext)
    local text = string.format("Round Over!\nPlayer %d wins the round!\nScore: %d-%d", winner, score[1], score[2])
    if roundOverPopup and roundOverPopup.onNext then
        roundOverPopup.onNext()
    end
    roundOverPopup = {
        text = text,
        timer = 2.5,
        onNext = onNext,
    }
end

local function update(dt)
    if deckSummaryPopup then
        deckSummaryPopup.timer = deckSummaryPopup.timer - dt
        if deckSummaryPopup.timer <= 0 then deckSummaryPopup = nil end
    end
    if roundOverPopup then
        roundOverPopup.timer = roundOverPopup.timer - dt
        if roundOverPopup.timer <= 0 then
            local cb = roundOverPopup.onNext
            roundOverPopup = nil
            if cb then cb() end
        end
    end
end

local function drawDeckSummaryPopup()
    if not deckSummaryPopup then return end

    local w, h = 280, 220
    local x, y = 20, 80

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)

    local player = deckSummaryPopup.player
    local header = string.format("Player %d Deck", player and player.id or 0)
    love.graphics.printf(header, x, y + 12, w, "center")
    love.graphics.setColor(1, 1, 0.8)
    love.graphics.printf(deckSummaryPopup.text or "", x + 12, y + 40, w - 24, "left")
    love.graphics.setColor(1, 1, 1)
end

local function drawRoundOverPopup(screenW)
    if not roundOverPopup then return end

    local w, h = 360, 140
    local x, y = (screenW - w) / 2, 120

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 18, 18)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, 18, 18)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf(roundOverPopup.text or "Round over", x + 16, y + 40, w - 32, "center")
    love.graphics.setColor(1, 1, 1)
end

local HudRenderer = {
    draw = drawHud,
    update = update,
    drawDeckSummaryPopup = drawDeckSummaryPopup,
    drawRoundOverPopup = drawRoundOverPopup,
    showDeckSummary = showDeckSummary,
    showRoundOver = showRoundOver,
}

return HudRenderer





