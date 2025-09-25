local Config = require "src.config"

local HudRenderer = {}

function HudRenderer.drawTurnBanner(state, screenW)
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

function HudRenderer.drawDiscardArea(state)
    local CardRenderer = require "src.card_renderer"
    if not Config.rules.showDiscardPile then return end
    if state.discardPile and #state.discardPile > 0 then
        CardRenderer.draw(state.discardPile[#state.discardPile])
    elseif state.discardStack then
        CardRenderer.draw(state.discardStack)
    end
end

function HudRenderer.drawCurrentHand(state)
    local current = state:getCurrentPlayer()
    if current then
        current:drawHand(true, state)
    end
end

function HudRenderer.drawDeckArea(state)
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

function HudRenderer.drawPassButton(state)
    local bx, by, bw, bh = state:getPassButtonRect()
    if state.phase == "play" then
        if state.highlightPass then
            love.graphics.setColor(0.95, 0.95, 0.95, 1)
        else
            love.graphics.setColor(0.85, 0.85, 0.85, 1)
        end
    else
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
    end
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)
    love.graphics.printf("Pass", bx, by + math.floor((bh - 16) / 2), bw, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function HudRenderer.drawDraggingCard(state)
    local CardRenderer = require "src.card_renderer"
    if state.draggingCard then
        CardRenderer.draw(state.draggingCard)
    end
end

function HudRenderer.drawPostBoard(state)
    HudRenderer.drawDiscardArea(state)
    HudRenderer.drawCurrentHand(state)
    HudRenderer.drawDeckArea(state)
    HudRenderer.drawPassButton(state)
    HudRenderer.drawDraggingCard(state)
end

return HudRenderer
