local deckSummaryPopup = nil
local roundOverPopup = nil

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
        timer = 3.5, -- seconds to show
    }
end

local function showRoundOver(winner, score, onNext)
    local text = string.format("Round Over!\nPlayer %d wins the round!\nScore: %d-%d", winner, score[1], score[2])
    roundOverPopup = {
        text = text,
        timer = 2.5,
        onNext = onNext
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
            roundOverPopup = nil
            if roundOverPopup and roundOverPopup.onNext then roundOverPopup.onNext() end
        end
    end
end

local Config = require "src.config"
        -- Show round over popup if present
        if roundOverPopup then
            local w, h = 340, 120
            local x, y = (screenW - w) / 2, 120
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.rectangle("fill", x, y, w, h, 16, 16)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, w, h, 16, 16)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 0)
            love.graphics.printf(roundOverPopup.text, x, y + 32, w, "center")
        end
local function drawDeckSummaryPopup()
    if not deckSummaryPopup then return end
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local w = Config.ui.deckPopupW
    local h = Config.ui.deckPopupH
    local x, y = (screenW - w) / 2, (screenH - h) / 2
    love.graphics.setColor(Config.colors.deckPopupBg)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    love.graphics.setColor(Config.colors.deckPopupBorder)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Deck Contents:", x, y + 18, w, "center")
    love.graphics.printf(deckSummaryPopup.text, x + 16, y + 48, w - 32, "left")
end

local Config = require "src.config"

local function drawTurnBanner(state, screenW)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Player %d's turn", state.currentPlayer), 0, 20, screenW, "center")

    local p1 = state.players[1]
    local p2 = state.players[2]
    local roundWins = state.roundWins or { [1] = 0, [2] = 0 }
    local btnW, btnH = Config.ui.deckButtonW or 120, Config.ui.deckButtonH or 32
    local btnY = 8
    local infoY = math.max(32, btnY + btnH + 24)
    local infoSpacing = 32
    local barW, barH = 120, 18
    if p1 then
        -- Health bar
        local hp = p1.health or 0
        local maxHp = p1.maxHealth or 20
        local previewHp = hp
        if state.phase == "play" then
            -- Preview health after resolve
            previewHp = hp - (state:previewIncomingDamage(1) or 0) + (state:previewIncomingHeal(1) or 0)
            previewHp = math.max(0, math.min(maxHp, previewHp))
        end
        local x, y = 24, infoY
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", x, y, barW, barH, 6, 6)
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.rectangle("fill", x, y, barW * (hp / maxHp), barH, 6, 6)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.rectangle("fill", x, y, barW * (previewHp / maxHp), barH, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("HP: %d/%d", hp, maxHp), x, y, barW, "center")
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf(string.format("Rounds Won: %d", roundWins[1] or 0), x, y + infoSpacing, barW, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Energy: %d", p1.energy or 0), x, y + infoSpacing + 18, barW, "center")
    end
    if p2 then
        local hp = p2.health or 0
        local maxHp = p2.maxHealth or 20
        local previewHp = hp
        if state.phase == "play" then
            previewHp = hp - (state:previewIncomingDamage(2) or 0) + (state:previewIncomingHeal(2) or 0)
            previewHp = math.max(0, math.min(maxHp, previewHp))
        end
        local x = screenW - barW - 56
        local y = infoY
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", x, y, barW, barH, 6, 6)
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.rectangle("fill", x, y, barW * (hp / maxHp), barH, 6, 6)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.rectangle("fill", x, y, barW * (previewHp / maxHp), barH, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("HP: %d/%d", hp, maxHp), x, y, barW, "center")
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf(string.format("Rounds Won: %d", roundWins[2] or 0), x, y + infoSpacing, barW, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Energy: %d", p2.energy or 0), x, y + infoSpacing + 18, barW, "center")
    end
end

-- Stub implementations for missing HUD methods
local CardRenderer = require "src.card_renderer"

local function drawDiscardArea(state)
    local Config = require "src.config"
    if not Config.rules.showDiscardPile then return end
    if state.discardPile and #state.discardPile > 0 then
        CardRenderer.draw(state.discardPile[#state.discardPile])
    elseif state.discardStack then
        CardRenderer.draw(state.discardStack)
    end
end

local function drawCurrentHand(state)
    local current = state:getCurrentPlayer()
    if current and current.drawHand then
        current:drawHand(true, state)
    end
end

local function drawDeckArea(state)
    local current = state:getCurrentPlayer()
    if not (current and current.deck and state.deckStack) then return end

    local deckX, deckY, deckW, deckH = state:getDeckRect()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", deckX, deckY, deckW, deckH, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", deckX, deckY, deckW, deckH, 8, 8)
    love.graphics.printf("Deck\n" .. #current.deck, deckX, deckY + math.floor(deckH * 0.33), deckW, "center")

    if Config.rules.energyEnabled ~= false then
        local energy = current.energy or 0
        local cx = deckX + math.floor(deckW * 0.2)
        local cy = deckY + math.floor(deckH * 0.2)
        love.graphics.setColor(0.95, 0.9, 0.2, 1)
        love.graphics.circle("fill", cx, cy, 16)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", cx, cy, 16)
        love.graphics.printf(tostring(energy), cx - 12, cy - 6, 24, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local Button = require "src.ui.button"
local function drawPassButton(state)
    local bx, by, bw, bh = state:getPassButtonRect()
    -- Move Pass button to the left of current player's deck button, using layout sideGap
    local deckX, deckY, deckW, deckH = state:getDeckRect()
    local layout = require('src.game_layout').getLayout(state)
    bx = deckX - bw - (layout.sideGap or 30)
    if bx < (layout.sideGap or 30) then
        bx = layout.sideGap or 30
    end
    by = deckY
    if not state._passButton then
        state._passButton = Button{
            x = bx, y = by, w = bw, h = bh,
            label = "Pass",
            color = {0.85, 0.85, 0.85, 1},
            hoveredColor = state.highlightPass and {0.95, 0.95, 0.95, 1} or {0.85, 0.85, 0.85, 1},
            textColor = {0, 0, 0, 1},
            enabled = state.phase == "play",
            visible = true,
            id = "pass_btn",
            onClick = function()
                print("[DEBUG] Pass button clicked. Phase:", state.phase)
                if state.phase == "play" then
                    state:passTurn()
                end
            end
        }
    else
        state._passButton.x = bx
        state._passButton.y = by
        state._passButton.w = bw
        state._passButton.h = bh
        state._passButton.enabled = state.phase == "play"
        state._passButton.hoveredColor = state.highlightPass and {0.95, 0.95, 0.95, 1} or {0.85, 0.85, 0.85, 1}
    end
    state._passButton:draw()
end

local function drawDraggingCard(state)
    if state.draggingCard then
    -- Debug print removed
        CardRenderer.draw(state.draggingCard)
    end
end

local function drawPostBoard(state)
    drawDiscardArea(state)
    drawCurrentHand(state)
    drawDeckArea(state)

    local Button = require "src.ui.button"
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local btnW, btnH = 120, 32
    local btnY = 8
    if not state._deckButtons then state._deckButtons = {} end
    for i, player in ipairs(state.players or {}) do
        local btnX = (i == 1) and 24 or (screenW - btnW - 24)
        if not state._deckButtons[i] then
            state._deckButtons[i] = Button{
                x = btnX, y = btnY, w = btnW, h = btnH,
                label = string.format("View P%d Deck", i),
                color = {0.2, 0.2, 0.6, 0.85},
                textColor = {1, 1, 1, 1},
                id = "deck_btn_" .. tostring(i),
                onClick = function()
                    showDeckSummary(player)
                end
            }
        else
            state._deckButtons[i].x = btnX
            state._deckButtons[i].y = btnY
        end
        state._deckButtons[i]:draw()
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawPassButton(state)
    drawDeckSummaryPopup()
    drawDraggingCard(state)
end

local HudRenderer = {
    showDeckSummary = showDeckSummary,
    update = update,
    drawDeckSummaryPopup = drawDeckSummaryPopup,
    drawTurnBanner = drawTurnBanner,
    drawPostBoard = drawPostBoard,
    drawDiscardArea = drawDiscardArea,
    drawCurrentHand = drawCurrentHand,
    drawDeckArea = drawDeckArea,
    drawPassButton = drawPassButton,
    drawDraggingCard = drawDraggingCard,
    showRoundOver = showRoundOver,
}

return HudRenderer