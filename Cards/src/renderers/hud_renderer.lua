local deckSummaryPopup = nil

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

local function update(dt)
    if deckSummaryPopup then
        deckSummaryPopup.timer = deckSummaryPopup.timer - dt
        if deckSummaryPopup.timer <= 0 then deckSummaryPopup = nil end
    end
end

local function drawDeckSummaryPopup()
    if not deckSummaryPopup then return end
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local w, h = 320, 240
    local x, y = (screenW - w) / 2, (screenH - h) / 2
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x, y, w, h, 12, 12)
    love.graphics.printf("Deck Contents:", x, y + 18, w, "center")
    love.graphics.printf(deckSummaryPopup.text, x + 16, y + 48, w - 32, "left")
end

local Config = require "src.config"

local function drawTurnBanner(state, screenW)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(string.format("Player %d's turn", state.currentPlayer), 0, 20, screenW, "center")

    local p1 = state.players[1]
    local p2 = state.players[2]
    if p1 then
        love.graphics.printf(
            string.format("P1 HP: %d  Block: %d  Energy: %d", p1.health or 0, p1.block or 0, p1.energy or 0),
            0, 50, screenW, "center"
        )
    end
    if p2 then
        love.graphics.printf(
            string.format("P2 HP: %d  Block: %d  Energy: %d", p2.health or 0, p2.block or 0, p2.energy or 0),
            0, 70, screenW, "center"
        )
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
    if not state._passButton then
        state._passButton = Button:new{
            x = bx, y = by, w = bw, h = bh,
            label = "Pass",
            color = {0.85, 0.85, 0.85, 1},
            hoveredColor = state.highlightPass and {0.95, 0.95, 0.95, 1} or {0.85, 0.85, 0.85, 1},
            textColor = {0, 0, 0, 1},
            enabled = state.phase == "play",
            visible = true,
            id = "pass_btn",
            onClick = function()
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
            state._deckButtons[i] = Button:new{
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
    drawDraggingCard(state)
    drawDeckSummaryPopup()
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
}

return HudRenderer