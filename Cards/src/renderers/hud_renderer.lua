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
    update = update,
    drawDeckSummaryPopup = drawDeckSummaryPopup,
    drawRoundOverPopup = drawRoundOverPopup,
    showDeckSummary = showDeckSummary,
    showRoundOver = showRoundOver,
}

return HudRenderer
