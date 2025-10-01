local Gamestate = require "libs.hump.gamestate"
local draft = require "src.states.draft"
local Player = require "src.player"
local Config = require "src.config"
local Viewport = require "src.viewport"
local Assets = require "src.asset_cache"

local fighter_select = {}

local function getFighterCatalog()
    local catalog = Config.fighters or {}
    return catalog.list or {}, catalog.byId or {}
end

local function defaultDimensions()
    local layout = Config.layout or {}
    local cardW = (layout.cardW or 100) * 1.4
    local cardH = (layout.cardH or 150) * 1.15
    local spacing = (layout.slotSpacing or (cardW + 30)) * 1.1
    return cardW, cardH, spacing
end

function fighter_select:enter()
    local list, byId = getFighterCatalog()
    self.fighters = list
    self.fightersById = byId
    self.currentPlayer = 1
    self.selections = {}
    self.buttons = {}
    self.portraitScaleMode = self.portraitScaleMode or 'cover_top' -- contain | cover | cover_top

    local function candidatePortraits(f)
        local cands = {}
        -- 1) Explicit field wins if provided in config
        if f.portrait then table.insert(cands, f.portrait) end
        -- 2) From name and shortName with underscores
        if f.name then table.insert(cands, ("assets/fighters/%s.png"):format((f.name:gsub(" ", "_")))) end
        if f.shortName then table.insert(cands, ("assets/fighters/%s.png"):format((f.shortName:gsub(" ", "_")))) end
        -- 3) From id transformed to Title_Case
        if f.id then
            local title = f.id:gsub("_+", " ")
            title = title:gsub("%f[%a].", string.upper)
            title = title:gsub(" ", "_")
            table.insert(cands, ("assets/fighters/%s.png"):format(title))
        end
        -- 4) Known swapped variants seen in repo (Steel/Street)
        if f.name then
            local swapped = f.name:gsub("Steel", "__TMP__"):gsub("Street", "Steel"):gsub("__TMP__", "Street")
            if swapped ~= f.name then
                table.insert(cands, ("assets/fighters/%s.png"):format(swapped:gsub(" ", "_")))
            end
        end
        return cands
    end

    -- Optional placeholder used when a portrait cannot be found
    local placeholder = Assets.image("assets/fighters/placeholder.png")

    for i, fighter in ipairs(self.fighters) do
        local img
        for _, p in ipairs(candidatePortraits(fighter)) do
            img = Assets.image(p)
            if img then break end
        end
        if not img and placeholder then
            img = placeholder
        end
        self.buttons[i] = { fighter = fighter, portrait = img, claimedBy = nil }
    end

    self:updateButtonPositions()
end

function fighter_select:updateButtonPositions()
    local cardW, cardH, spacing = defaultDimensions()
    local count = #self.buttons
    if count == 0 then
        return
    end

    local screenW = Viewport.getWidth()
    local screenH = Viewport.getHeight()
    local totalWidth = cardW + spacing * math.max(0, count - 1)
    local startX = math.floor((screenW - totalWidth) / 2)
    local y = math.floor((screenH - cardH) / 2)

    for index, entry in ipairs(self.buttons) do
        entry.x = startX + (index - 1) * spacing
        entry.y = y
        entry.w = cardW
        entry.h = cardH
    end
end

function fighter_select:update()
    self:updateButtonPositions()
end

local function drawImageFit(img, x, y, w, h)
    local iw, ih = img:getWidth(), img:getHeight()
    if iw <= 0 or ih <= 0 then return end
    local scale = math.min(w / iw, h / ih)
    local dw, dh = iw * scale, ih * scale
    local dx = x + (w - dw) / 2
    local dy = y + (h - dh) / 2
    love.graphics.draw(img, dx, dy, 0, scale, scale)
    return dx, dy, dw, dh
end

local function drawButton(entry, hovered)
    local fighter = entry.fighter
    local color = (fighter and fighter.color) or { 0.7, 0.7, 0.7 }
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1

    local fillAlpha = entry.claimedBy and 0.8 or 0.25
    local borderAlpha = entry.claimedBy and 0.95 or 0.7

    -- Skip background fill when a portrait is present to avoid box artifacts
    if not entry.portrait then
        love.graphics.setColor(r, g, b, fillAlpha)
        love.graphics.rectangle("fill", entry.x, entry.y, entry.w, entry.h, 16, 16)
    end

    -- Remove outer border; keep a subtle hover highlight for text-only tiles
    if hovered and not entry.portrait then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", entry.x + 2, entry.y + 2, entry.w - 4, entry.h - 4, 14, 14)
    end
    love.graphics.setLineWidth(1)

    -- Portrait region and frame adapts to image aspect
    local pad = 4
    if entry.portrait then
        local imgX, imgY = entry.x + pad, entry.y + pad
        local imgW, imgH = entry.w - pad * 2, entry.h - pad * 2
        local iw, ih = entry.portrait:getWidth(), entry.portrait:getHeight()
        if iw > 0 and ih > 0 then
            local mode = fighter_select.portraitScaleMode or 'cover_top'
            local baseScale = (mode == 'contain') and math.min(imgW / iw, imgH / ih) or math.max(imgW / iw, imgH / ih)
            local baseDW, baseDH = iw * baseScale, ih * baseScale
            local overH = math.max(0, baseDH - imgH)
            local biasY = (mode == 'cover_top') and 1 or 0 -- 1 shows more top, cropping bottom
            local baseDX = imgX + (imgW - baseDW) / 2
            local baseDY = imgY + (imgH - baseDH) / 2 + (overH * 0.5 * biasY)

            local zoom = hovered and 1.12 or 1.0
            local drawScale = baseScale * zoom
            local drawDW, drawDH = iw * drawScale, ih * drawScale
            local drawDX = imgX + (imgW - drawDW) / 2
            local drawDY = imgY + (imgH - drawDH) / 2 + (math.max(0, drawDH - imgH) * 0.5 * biasY)

            -- Hover halo using widened stroke (avoids filled shadow boxes)
            if hovered then
                local fxh, fyh, fwh, fhh = drawDX - 2, drawDY - 2, drawDW + 4, drawDH + 4
                love.graphics.setColor(0, 0, 0, 0.25)
                love.graphics.setLineWidth(10)
                love.graphics.rectangle("line", fxh, fyh, fwh, fhh, 14, 14)
                love.graphics.setLineWidth(1)
            end

            -- Draw portrait (no cropping)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(entry.portrait, drawDX, drawDY, 0, drawScale, drawScale)

            -- Uniform frame color regardless of fighter (mid base, bright hover)
            local frameColor = {0.35, 0.35, 0.35, 0.96}
            local hoverColor = {0.98, 0.98, 0.98, 1.0}
            love.graphics.setLineWidth(3)
            love.graphics.setColor(frameColor)
            -- Frame follows the drawn image (including zoom)
            local fx, fy, fw, fh = drawDX - 2, drawDY - 2, drawDW + 4, drawDH + 4
            love.graphics.rectangle("line", fx, fy, fw, fh, 12, 12)
            if hovered then
                love.graphics.setColor(hoverColor)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", fx + 2, fy + 2, fw - 4, fh - 4, 10, 10)
            end
            love.graphics.setLineWidth(1)
        end
    else
        -- subtle inner panel if no portrait; reserve space for text below
        local textTop = entry.y + 82
        local imgX, imgY = entry.x + pad, entry.y + pad
        local imgW, imgH = entry.w - pad * 2, (textTop - entry.y) - pad * 2
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.rectangle("fill", imgX, imgY, imgW, imgH, 10, 10)
        -- Overlay strip for text legibility
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", entry.x + 2, textTop - 6, entry.w - 4, 24, 10, 10)
    end

    -- Text: omit if a portrait is present
    if not entry.portrait then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(fighter.name or "Fighter", entry.x, entry.y + 14, entry.w, "center")
        love.graphics.setColor(1, 1, 1, 0.85)
        local descY = entry.y + 46
        love.graphics.printf(fighter.description or "", entry.x + 12, descY, entry.w - 24, "left")
    end

    if entry.claimedBy then
        local label = string.format("P%d", entry.claimedBy)
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", entry.x, entry.y + entry.h - 44, entry.w, 36, 12, 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label .. " locked", entry.x, entry.y + entry.h - 38, entry.w, "center")
    end
end

function fighter_select:draw()
    Viewport.apply()

    local screenW = Viewport.getWidth()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Fighter", 0, 60, screenW, "center")

    local instruction
    if self.currentPlayer and self.currentPlayer <= 2 then
        instruction = string.format("Player %d, pick your champion", self.currentPlayer)
    else
        instruction = "Waiting for selections..."
    end
    love.graphics.printf(instruction, 0, 100, screenW, "center")
    -- Scaling mode hint
    local modeLabel = (self.portraitScaleMode == 'contain') and 'Contain' or ((self.portraitScaleMode == 'cover') and 'Cover' or 'Cover (Top)')
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.printf("Portrait scale: " .. modeLabel .. "  [V to toggle]", 0, 120, screenW, "center")
    love.graphics.setColor(1, 1, 1, 1)

    local mx, my = love.mouse.getPosition()
    mx, my = Viewport.toVirtual(mx, my)
    local hoveredIndex = nil
    for i, entry in ipairs(self.buttons) do
        local hovered = (mx >= entry.x and mx <= entry.x + entry.w and my >= entry.y and my <= entry.y + entry.h)
        if hovered then hoveredIndex = i end
    end
    -- Draw non-hovered first
    for i, entry in ipairs(self.buttons) do
        if i ~= hoveredIndex then
            local hovered = false
            drawButton(entry, hovered)
        end
    end
    -- Draw hovered last so it appears above neighbors when zoomed
    if hoveredIndex then
        drawButton(self.buttons[hoveredIndex], true)
    end

    Viewport.unapply()
end

local function within(entry, x, y)
    return x >= entry.x and x <= (entry.x + entry.w) and y >= entry.y and y <= (entry.y + entry.h)
end

function fighter_select:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local vx, vy = Viewport.toVirtual(x, y)
    for _, entry in ipairs(self.buttons) do
        if within(entry, vx, vy) then
            if not entry.claimedBy then
                self:claim(entry)
            end
            return
        end
    end
end

function fighter_select:keypressed(key)
    if key == 'v' or key == 'V' then
        local order = { 'contain', 'cover', 'cover_top' }
        local cur = self.portraitScaleMode or 'cover_top'
        local idx = 1
        for i, m in ipairs(order) do if m == cur then idx = i break end end
        self.portraitScaleMode = order[(idx % #order) + 1]
    end
end

function fighter_select:claim(entry)
    if not self.currentPlayer then
        return
    end

    entry.claimedBy = self.currentPlayer
    self.selections[self.currentPlayer] = entry.fighter

    if self.currentPlayer == 1 then
        self.currentPlayer = 2
        return
    end

    -- If player 2 just picked but player 1 somehow missing, cycle back.
    if not self.selections[1] then
        self.currentPlayer = 1
        entry.claimedBy = nil
        self.selections[2] = nil
        return
    end

    self:startDraft()
end

function fighter_select:startDraft()
    local rules = Config.rules or {}
    local maxHand = rules.maxHandSize or 5
    local maxBoard = rules.maxBoardCards or 3

    local players = {}
    for i = 1, 2 do
        local fighter = self.selections[i]
        local args = {
            id = i,
            maxHandSize = maxHand,
            maxBoardCards = maxBoard,
        }
        local player = Player(args)
        if fighter then
            player:setFighter(fighter)
        end
        players[i] = player
    end

    Gamestate.switch(draft, players)
end

return fighter_select
