local Config = require "src.config"
local Viewport = require "src.viewport"

local Layout = {}

local function resolve()
    local layout = Config.layout or {}
    return {
        slotSpacing = layout.slotSpacing or 110,
        cardW = layout.cardW or 100,
        cardH = layout.cardH or 150,
        handBottomMargin = layout.handBottomMargin or 20,
        boardTopMargin = layout.boardTopMargin or 80,
        boardHandGap = layout.boardHandGap or 30,
        sideGap = layout.sideGap or 30,
    }
end

function Layout.buildCache(state)
    state.layoutCache = resolve()
    return state.layoutCache
end

function Layout.getLayout(state)
    return state.layoutCache or Layout.buildCache(state)
end

function Layout.getCardDimensions(state)
    local layout = Layout.getLayout(state)
    return layout.cardW, layout.cardH
end

function Layout.getHandMetrics(state, player)
    local layout = Layout.getLayout(state)
    local maxHand = (player and player.maxHandSize) or (Config.rules.maxHandSize or 5)
    maxHand = math.max(1, maxHand)
    local width = layout.cardW + layout.slotSpacing * (maxHand - 1)
    local startX = math.floor((Viewport.getWidth() - width) / 2)
    return startX, width, layout, maxHand
end

function Layout.getHandY(state)
    local layout = Layout.getLayout(state)
    return Viewport.getHeight() - layout.cardH - layout.handBottomMargin
end

function Layout.getDeckPosition(state)
    local currentPlayer = state.players and state.players[state.currentPlayer]
    local startX, _, layout = Layout.getHandMetrics(state, currentPlayer)
    local x = startX - layout.cardW - layout.sideGap
    if x < layout.sideGap then
        x = layout.sideGap
    end
    return x, Layout.getHandY(state)
end

function Layout.getDiscardPosition(state)
    local currentPlayer = state.players and state.players[state.currentPlayer]
    local startX, width, layout = Layout.getHandMetrics(state, currentPlayer)
    local x = startX + width + layout.sideGap
    local maxX = Viewport.getWidth() - layout.cardW - layout.sideGap
    if x > maxX then
        x = maxX
    end
    return x, Layout.getHandY(state)
end

function Layout.getDeckRect(state)
    local x, y = Layout.getDeckPosition(state)
    local layout = Layout.getLayout(state)
    return x, y, layout.cardW, layout.cardH
end

function Layout.getBoardMetrics(state, playerIndex)
    local layout = Layout.getLayout(state)
    local player = state.players and state.players[playerIndex]
    local count = (player and player.maxBoardCards) or state.maxBoardCards or (Config.rules.maxBoardCards or 3)
    count = math.max(1, count)
    local width = layout.cardW + layout.slotSpacing * (count - 1)
    local startX = math.floor((Viewport.getWidth() - width) / 2)
    return startX, width, layout, count
end

function Layout.getBoardY(state, playerIndex)
    local layout = Layout.getLayout(state)
    if playerIndex == state.currentPlayer then
        return Layout.getHandY(state) - layout.cardH - layout.boardHandGap
    end
    return layout.boardTopMargin
end

function Layout.refreshPositions(state)
    local layout = Layout.getLayout(state)
    if state.deckStack then
        local dx, dy = Layout.getDeckPosition(state)
        state.deckStack.x, state.deckStack.y = dx, dy
        state.deckStack.w, state.deckStack.h = layout.cardW, layout.cardH
    end
    if state.discardStack then
        local sx, sy = Layout.getDiscardPosition(state)
        state.discardStack.x, state.discardStack.y = sx, sy
        state.discardStack.w, state.discardStack.h = layout.cardW, layout.cardH
    end
    if Config.rules.showDiscardPile and state.discardPile and #state.discardPile > 0 and state.discardStack then
        local top = state.discardPile[#state.discardPile]
        top.x, top.y = state.discardStack.x, state.discardStack.y
        top.w, top.h = layout.cardW, layout.cardH
    end
end

return Layout
