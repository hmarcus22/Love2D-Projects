local Gamestate = require "libs.hump.gamestate"
local game = require "src.states.game"
local Player = require "src.player"
local factory = require "src.card_factory"
local Viewport = require "src.viewport"
local Config = require "src.config"

local DEFAULT_DECK_SIZE = 12
local DEFAULT_DRAFT_POOL = {
    { id = "punch", count = 12 },
    { id = "kick", count = 8 },
    { id = "block", count = 12 },
    { id = "guard", count = 6 },
    { id = "feint", count = 6 },
    { id = "rally", count = 6 },
    { id = "banner", count = 4 },
    { id = "adrenaline_rush", count = 4 },
    { id = "taunt", count = 4 },
    { id = "hex", count = 4 },
    { id = "counter", count = 4 },
    { id = "uppercut", count = 4 },
    { id = "roundhouse", count = 3 },
}

local CHOICES_PER_PICK = 3

local Button = require "src.ui.button"
local AssetCache = require "src.asset_cache"
local Blur = require "src.shaders.blur"
local HoverUtils = require "src.ui.hover_utils"
local draft = {}
draft._autoDraftButton = nil

-- Helpers to lay out player deck columns (left/right) during draft
local function computeDeckRowRects(deck, side, layout, screenW, screenH, topMargin)
    local rects = {}
    local baseW = layout.cardW or 100
    local baseH = layout.cardH or 150
    local w = baseW
    local h = baseH
    local draftCfg = Config.draft or {}
    local gapX = draftCfg.deckRowGap or 24
    local overlap = draftCfg.deckOverlap or 0
    if overlap < 0 then overlap = 0 elseif overlap > 0.95 then overlap = 0.95 end
    local spacingX = math.max(1, math.floor(w * (1 - overlap)) + gapX)
    local sideGap = layout.sideGap or 30
    local startX = (side == 'left') and sideGap or (screenW - sideGap - w)
    local xMin = sideGap
    local xMax = screenW - sideGap - w
    local deckTopOffset = draftCfg.deckTopOffset
    local rowY = (topMargin or 60) + (deckTopOffset ~= nil and deckTopOffset or (baseH + 24))
    local wrapEnabled = draftCfg.deckWrap == true
    local rowGap = draftCfg.deckWrapRowGap or 18

    local x = startX
    for i, c in ipairs(deck or {}) do
        rects[i] = { x = x, y = rowY, w = w, h = h, card = c }
        if side == 'left' then
            local nextX = x + spacingX
            if wrapEnabled and nextX > xMax then
                rowY = rowY + h + rowGap
                x = startX
            else
                x = nextX
            end
        else -- right side
            local nextX = x - spacingX
            if wrapEnabled and nextX < xMin then
                rowY = rowY + h + rowGap
                x = startX
            else
                x = nextX
            end
        end
    end
    return rects
end

local function buildDraftPool()
    local draftConfig = Config.draft or {}
    local poolConfig = draftConfig.pool or DEFAULT_DRAFT_POOL
    local pool = {}
    for _, entry in ipairs(poolConfig) do
        local id = entry.id
        local count = entry.count or 1
        if id and count > 0 then
            for _, card in ipairs(factory.createCopies(id, count)) do
                table.insert(pool, card)
            end
        end
    end
    return pool
end

function draft:shuffleDraftPool()
    for i = #self.draftPool, 2, -1 do
        local j = love.math.random(i)
        self.draftPool[i], self.draftPool[j] = self.draftPool[j], self.draftPool[i]
    end
end

function draft:enter(previous, players)
    local rules = Config.rules or {}
    local maxHand = rules.maxHandSize or 5
    local maxBoard = rules.maxBoardCards or 3

    if players and #players > 0 then
        self.players = {}
        for idx, p in ipairs(players) do
            p.maxHandSize = p.maxHandSize or maxHand
            p.maxBoardCards = p.maxBoardCards or maxBoard
            p.deck = {}
            self.players[idx] = p
        end
    else
        self.players = {
            Player{ id = 1, maxHandSize = maxHand, maxBoardCards = maxBoard },
            Player{ id = 2, maxHandSize = maxHand, maxBoardCards = maxBoard },
        }
    end

    self.currentPlayer = 1

    local draftConfig = Config.draft or {}
    self.targetDeckSize = draftConfig.deckSize or DEFAULT_DECK_SIZE

    self.draftPool = buildDraftPool()
    self:shuffleDraftPool()

    self.choices = {}
    self:nextChoices()
end
function draft:updateChoicePositions()
    local layout = Config.layout or {}
    local cardW = layout.cardW or 100
    local cardH = layout.cardH or 150
    local draftCfg = Config.draft or {}
    local gap = (draftCfg.cardGap ~= nil) and draftCfg.cardGap or ((layout.sideGap or 30) * 2)
    local spacing = cardW + gap
    local count = #self.choices
    if count == 0 then return end

    local totalWidth = cardW + spacing * math.max(0, count - 1)
    local startX = math.floor((Viewport.getWidth() - totalWidth) / 2)
    -- Draft row uses its own top margin (falls back to boardTopMargin)
    local topMargin = draftCfg.topMargin or (layout.boardTopMargin or 60)
    local choiceY = topMargin + 12

    for i, c in ipairs(self.choices) do
        c.x = startX + (i - 1) * spacing
        c.y = choiceY
        c.w = cardW
        c.h = cardH
    end
end

function draft:update(dt)
    local Tuner = require "src.tuner_overlay"
    Tuner.update(dt, 'draft', self)
    -- Update hover state and tween amounts for choices
    self:updateChoicePositions()
    local layout = Config.layout or {}
    local draftCfg = Config.draft or {}
    local inSpeed = (draftCfg.hoverInSpeed or draftCfg.hoverSpeed or layout.handHoverInSpeed or layout.handHoverSpeed or 12)
    local outSpeed = (draftCfg.hoverOutSpeed or draftCfg.hoverSpeed or layout.handHoverOutSpeed or layout.handHoverSpeed or 12)
    local kIn = math.min(1, (dt or 0) * inSpeed)
    local kOut = math.min(1, (dt or 0) * outSpeed)
    local mx, my = love.mouse.getPosition()
    mx, my = Viewport.toVirtual(mx, my)
    do
        local useScaled = (draftCfg.hoverHitScaled == true)
        local hoverScale = (draftCfg.hoverScale or (layout.handHoverScale or 0.06))
        local topIdx = HoverUtils.topmostIndex(self.choices, function(c)
            if useScaled then
                return HoverUtils.hitScaled(mx, my, c.x, c.y, (c.w or 100), (c.h or 150), c.handHoverAmount or 0, hoverScale)
            else
                return HoverUtils.hit(mx, my, c.x, c.y, (c.w or 100), (c.h or 150))
            end
        end)
        for i = 1, #self.choices do
            local c = self.choices[i]
            local hovered = (i == topIdx)
            c._hovered = hovered
            c.handHoverTarget = hovered and 1 or 0
            c.handHoverAmount = HoverUtils.stepAmount(c.handHoverAmount or 0, c.handHoverTarget or 0, dt, inSpeed, outSpeed)
        end
    end

    -- Update hover tween for player deck columns
    local layout = Config.layout or {}
    local draftCfg = Config.draft or {}
    local topMargin = draftCfg.topMargin or (layout.boardTopMargin or 60)
    local leftRects = computeDeckRowRects(self.players[1].deck or {}, 'left', layout, Viewport.getWidth(), Viewport.getHeight(), topMargin)
    local rightRects = computeDeckRowRects(self.players[2].deck or {}, 'right', layout, Viewport.getWidth(), Viewport.getHeight(), topMargin)
    do
        local useScaled = (draftCfg.hoverHitScaled == true)
        local hoverScale = (draftCfg.deckHoverScale or draftCfg.hoverScale or (layout.handHoverScale or 0.06))
        local leftTop = HoverUtils.topmostIndex(leftRects, function(r)
            if useScaled then
                return HoverUtils.hitScaled(mx, my, r.x, r.y, r.w, r.h, r.card.handHoverAmount or 0, hoverScale)
            else
                return HoverUtils.hit(mx, my, r.x, r.y, r.w, r.h)
            end
        end)
        for i = 1, #leftRects do
            local r = leftRects[i]
            local c = r.card
            local hovered = (i == leftTop)
            c.handHoverTarget = hovered and 1 or 0
            c.handHoverAmount = HoverUtils.stepAmount(c.handHoverAmount or 0, c.handHoverTarget or 0, dt, inSpeed, outSpeed)
        end
    end
    do
        local useScaled = (draftCfg.hoverHitScaled == true)
        local hoverScale = (draftCfg.deckHoverScale or draftCfg.hoverScale or (layout.handHoverScale or 0.06))
        local rightTop = HoverUtils.topmostIndex(rightRects, function(r)
            if useScaled then
                return HoverUtils.hitScaled(mx, my, r.x, r.y, r.w, r.h, r.card.handHoverAmount or 0, hoverScale)
            else
                return HoverUtils.hit(mx, my, r.x, r.y, r.w, r.h)
            end
        end)
        for i = 1, #rightRects do
            local r = rightRects[i]
            local c = r.card
            local hovered = (i == rightTop)
            c.handHoverTarget = hovered and 1 or 0
            c.handHoverAmount = HoverUtils.stepAmount(c.handHoverAmount or 0, c.handHoverTarget or 0, dt, inSpeed, outSpeed)
        end
    end
end

function draft:nextChoices()
    local desired = CHOICES_PER_PICK or 3
    while #self.choices < desired do
        local card = table.remove(self.draftPool)
        if not card then break end
        table.insert(self.choices, card)
    end

    self:updateChoicePositions()
end

function draft:draw()
    Viewport.apply()
    love.graphics.setColor(1, 1, 1)
    local screenW = Viewport.getWidth()
    local screenH = Viewport.getHeight()
    -- Background
    self:drawBackground(screenW, screenH)
    love.graphics.printf("Draft Phase", 0, 40, screenW, "center")

    self:drawPrompt(screenW)
    self:drawChoices()
    self:drawPlayerDecks(screenW, screenH)
    self:drawAutoDraftButton(screenW, screenH)
    do
        local Tuner = require "src.tuner_overlay"
        Tuner.draw('draft')
    end
    Viewport.unapply()
end

function draft:drawBackground(screenW, screenH)
    local bgCfg = (Config.draft and Config.draft.background) or {}
    local path = bgCfg.path or "assets/backgrounds/Draft.png"
    if self._bgPath ~= path then
        self._bgImage = AssetCache.image(path)
        self._bgPath = path
    end
    local img = self._bgImage
    if not img then return end
    local imgW, imgH = img:getDimensions()
    if (imgW or 0) <= 0 or (imgH or 0) <= 0 then return end
    local mode = bgCfg.fit or "cover"
    local tint = bgCfg.tint or {1, 1, 1, 1}

    -- determine draw transform (cover or stretch)
    local s, dx, dy, sx, sy
    if mode == "stretch" then
        sx = screenW / imgW
        sy = screenH / imgH
        dx, dy = 0, 0
    else
        s = math.max(screenW / imgW, screenH / imgH)
        sx, sy = s, s
        local drawW = imgW * s
        local drawH = imgH * s
        dx = (screenW - drawW) / 2
        dy = (screenH - drawH) / 2
    end

    local blurAmount = bgCfg.blurAmount or bgCfg.blur or 0
    local blurPasses = math.max(1, bgCfg.blurPasses or 1)

    if blurAmount and blurAmount > 0 then
        -- lazy init canvases sized to the virtual screen
        if (not self._bgCanvasA) or self._bgCanvasW ~= screenW or self._bgCanvasH ~= screenH then
            self._bgCanvasA = love.graphics.newCanvas(screenW, screenH)
            self._bgCanvasB = love.graphics.newCanvas(screenW, screenH)
            self._bgCanvasW, self._bgCanvasH = screenW, screenH
        end
        local cA, cB = self._bgCanvasA, self._bgCanvasB

        -- draw base image into A
        love.graphics.push('all')
        love.graphics.setCanvas(cA)
        love.graphics.clear(0,0,0,0)
        love.graphics.setColor(tint[1], tint[2], tint[3], (tint[4] or 1))
        love.graphics.draw(img, dx, dy, 0, sx, sy)
        love.graphics.setColor(1,1,1,1)
        love.graphics.pop()

        -- blur passes: A -> B (horizontal), B -> A (vertical)
        local shader = Blur.get()
        for i = 1, blurPasses do
            love.graphics.push('all')
            love.graphics.setCanvas(cB)
            love.graphics.clear(0,0,0,0)
            love.graphics.setShader(shader)
            shader:send("direction", {1.0, 0.0})
            shader:send("radius", blurAmount)
            love.graphics.draw(cA, 0, 0)
            love.graphics.pop()

            love.graphics.push('all')
            love.graphics.setCanvas(cA)
            love.graphics.clear(0,0,0,0)
            love.graphics.setShader(shader)
            shader:send("direction", {0.0, 1.0})
            shader:send("radius", blurAmount)
            love.graphics.draw(cB, 0, 0)
            love.graphics.pop()
        end
        love.graphics.setShader()
        love.graphics.setCanvas()

        -- draw final to screen
        love.graphics.setColor(1,1,1,1)
        love.graphics.draw(cA, 0, 0)
    else
        -- no blur: draw directly
        love.graphics.setColor(tint[1], tint[2], tint[3], (tint[4] or 1))
        love.graphics.draw(img, dx, dy, 0, sx, sy)
        love.graphics.setColor(1,1,1,1)
    end

    -- Optional overlay fade on top (e.g., black with alpha)
    local overlayAlpha = bgCfg.overlayAlpha or 0
    local overlayColor = bgCfg.overlayColor or {0,0,0}
    if overlayAlpha and overlayAlpha > 0 then
        love.graphics.setColor(overlayColor[1] or 0, overlayColor[2] or 0, overlayColor[3] or 0, overlayAlpha)
        love.graphics.rectangle('fill', 0, 0, screenW, screenH)
        love.graphics.setColor(1,1,1,1)
    end
end

function draft:drawPrompt(screenW)
    local prompt = string.format("Player %d choose a card", self.currentPlayer)
    local current = self.players and self.players[self.currentPlayer]
    if current and current.getFighter then
        local fighter = current:getFighter()
        if fighter then
            local label = fighter.shortName or fighter.name or ""
            prompt = string.format("Player %d (%s) choose a card", self.currentPlayer, label)
        end
    end
    love.graphics.printf(prompt, 0, 80, screenW, "center")
end

function draft:drawChoices()
    self:updateChoicePositions()
    local highlightPlayer = self.players and self.players[self.currentPlayer]
    local CardRenderer = require "src.card_renderer"
    -- Draw non-hovered first, then hovered last for top stacking
    local hoverScale = (Config.draft and Config.draft.hoverScale) or (Config.layout and Config.layout.handHoverScale) or 0.06
    local function drawChoice(c)
        local amt = c.handHoverAmount or 0
        local baseW, baseH = c.w or 100, c.h or 150
        local dx, dy, dw, dh = HoverUtils.scaledRect(c.x, c.y, baseW, baseH, amt, hoverScale)

        -- Shadow rendering now handled centrally in main game draw loop
        -- Draft shadows can be added to ShadowRenderer.drawDraftShadows() if needed

        -- Temporarily set card rect for rendering
        local oldx, oldy, oldw, oldh = c.x, c.y, c.w, c.h
        c.x, c.y, c.w, c.h = dx, dy, dw, dh
        CardRenderer.draw(c)
        -- Favored highlight around the scaled rect
        if highlightPlayer and highlightPlayer.isCardFavored and highlightPlayer:isCardFavored(c.definition) then
            love.graphics.setColor(1, 1, 0.4, 0.9)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", dx - 6, dy - 6, dw + 12, dh + 12, 12, 12)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1, 1)
        end
        -- Restore
        c.x, c.y, c.w, c.h = oldx, oldy, oldw, oldh
    end

    for _, c in ipairs(self.choices) do
        if not c._hovered then drawChoice(c) end
    end
    for _, c in ipairs(self.choices) do
        if c._hovered then drawChoice(c) end
    end
end

function draft:drawPlayerDecks(screenW, screenH)
    local layout = Config.layout or {}
    local draftCfg = Config.draft or {}
    local topMargin = draftCfg.topMargin or (layout.boardTopMargin or 60)
    local leftRects = computeDeckRowRects(self.players[1].deck or {}, 'left', layout, screenW, screenH, topMargin)
    local rightRects = computeDeckRowRects(self.players[2].deck or {}, 'right', layout, screenW, screenH, topMargin)

    local function drawColumn(rects, playerIndex)
        local CardRenderer = require "src.card_renderer"
        -- Header above column
        local p = self.players[playerIndex]
        local fighter = p.getFighter and p:getFighter()
        local fighterLabel = fighter and (fighter.shortName or fighter.name) or ""
        local header = string.format("P%d deck (%d/%d)%s%s", playerIndex, #p.deck, self.targetDeckSize, fighterLabel ~= "" and " - " or "", fighterLabel)
        local hx = rects[1] and rects[1].x or ((playerIndex == 1) and (layout.sideGap or 30) or (screenW - (layout.sideGap or 30) - 100))
        local hy = (topMargin or 60) + 4
        love.graphics.setColor(1, 1, 1, 1)
        local align = (playerIndex == 1) and "left" or "right"
        love.graphics.printf(header, hx - 20, hy, 200, align)

        -- Draw cards: non-hovered first, hovered last
        local hoverScale = (draftCfg.deckHoverScale or draftCfg.hoverScale or (layout.handHoverScale or 0.06))
    local function drawEntry(r)
        local c = r.card
        local amt = c.handHoverAmount or 0
        local dx, dy, dw, dh = HoverUtils.scaledRect(r.x, r.y, r.w, r.h, amt, hoverScale)
        if amt > 0.01 then 
            -- Shadow rendering now handled centrally
            -- Draft shadows can be added to ShadowRenderer.drawDraftShadows() if needed
        end
        local ox, oy, ow, oh = c.x, c.y, c.w, c.h
        c.x, c.y, c.w, c.h = dx, dy, dw, dh
        CardRenderer.draw(c)
        c.x, c.y, c.w, c.h = ox, oy, ow, oh
    end
        -- Pass 1: non-hovered
        for _, r in ipairs(rects) do
            if (r.card.handHoverAmount or 0) <= 0.01 then drawEntry(r) end
        end
        -- Pass 2: hovered
        for _, r in ipairs(rects) do
            if (r.card.handHoverAmount or 0) > 0.01 then drawEntry(r) end
        end
    end

    drawColumn(leftRects, 1)
    drawColumn(rightRects, 2)
end

function draft:drawAutoDraftButton(screenW, screenH)
    local btnW, btnH = 180, 36
    local btnX = (screenW - btnW) / 2
    local btnY = screenH - 48
    if not self._autoDraftButton then
        self._autoDraftButton = Button{
            x = btnX, y = btnY, w = btnW, h = btnH,
            label = "Auto Draft (A)",
            color = {0.2, 0.5, 0.2, 0.85},
            hoveredColor = {0.3, 0.7, 0.3, 1},
            textColor = {1, 1, 1, 1},
            id = "auto_draft_btn",
            onClick = function()
                draft:autoDraftDecks()
            end
        }
    else
        self._autoDraftButton.x = btnX
        self._autoDraftButton.y = btnY
    end
    self._autoDraftButton:draw()
end
function draft:autoDraftDecks()
    -- Fill both decks with random cards from the draft pool
    for _, p in ipairs(self.players) do
        while #p.deck < self.targetDeckSize and #self.draftPool > 0 do
            local card = table.remove(self.draftPool)
            table.insert(p.deck, card)
        end
    end
    Gamestate.switch(game, self.players)
end
function draft:mousepressed(x, y, button)
    if button ~= 1 then return end
    x, y = Viewport.toVirtual(x, y)
    local Tuner = require "src.tuner_overlay"
    if Tuner.mousepressed(x, y, button, 'draft', self) then return end
    self:updateChoicePositions()

    -- Check auto draft button
    if self._autoDraftButton and self._autoDraftButton:click(x, y) then
        return
    end

    -- Select visually topmost choice under cursor by scanning from end
    for i = #self.choices, 1, -1 do
        local card = self.choices[i]
        if card:isHovered(x, y) then
            table.insert(self.players[self.currentPlayer].deck, card)
            table.remove(self.choices, i)

            local allComplete = true
            for _, player in ipairs(self.players) do
                if #player.deck < self.targetDeckSize then
                    allComplete = false
                    break
                end
            end

            if allComplete then
                Gamestate.switch(game, self.players)
                return
            end

            self:nextChoices()
            self.currentPlayer = self.currentPlayer % #self.players + 1
            break
        end
    end
end
function draft:mousereleased(x, y, button)
    x, y = Viewport.toVirtual(x, y)
    local Tuner = require "src.tuner_overlay"
    if Tuner.mousereleased(x, y, button) then return end
end
function draft:keypressed(key)
    local Tuner = require "src.tuner_overlay"
    if Tuner.keypressed(key, 'draft', self) then return end
    if key == "a" then
        self:autoDraftDecks()
    end
end

function draft:wheelmoved(dx, dy)
    local Tuner = require "src.tuner_overlay"
    if Tuner.wheelmoved(dx, dy) then return end
end

return draft










