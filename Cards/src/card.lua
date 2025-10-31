local Class = require "libs.hump.class"
local Assets = require "src.asset_cache"

local Card = Class{}

local DEFAULT_BACK_ART_PATH = "assets/cards/back.png"
local backArtImage = nil
local backArtPath = nil

function Card:setBackArt(path)
    backArtPath = path
    if not path or path == "" then
        backArtImage = nil
        return nil
    end

    local image = Assets.image(path)
    if image then
        backArtImage = image
    else
        backArtImage = nil
    end
    return backArtImage
end

function Card:getBackArt()
    return backArtImage, backArtPath
end

function Card:init(id, name, x, y)
    self.id = id
    self.name = name
    self.x, self.y = x or 0, y or 0
    self.w, self.h = 100, 150
    self.faceUp = true
    self.dragging = false
    self.offsetX, self.offsetY = 0, 0
    self.slotIndex = nil
    self.owner = nil
    self.definition = nil -- will be attached by factory
    self.handHoverTarget = 0
    self.handHoverAmount = 0
    self.statVariance = nil
    self.art = nil
    self.artPath = nil
end

function Card:setArt(image, path)
    self.art = image
    self.artPath = path
end

local function drawCardStats(self, statY, descTop)
    if not self.definition then
        return statY
    end

    local function drawStat(label, textValue, color)
        if not textValue or textValue == "" then
            return
        end
        if statY + 18 > descTop - 4 then
            return
        end
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", self.x + 10, statY, 14, 14, 2, 2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", self.x + 10, statY, 14, 14, 2, 2)
        love.graphics.printf(label .. ": " .. textValue,
            self.x + 30, statY - 2, self.w - 40, "left")
        statY = statY + 18
    end

    if self.definition.attack and self.definition.attack > 0 then
        local base = self.definition.attack
        local variance = self.statVariance and self.statVariance.attack or 0
        local textValue = tostring(base)
        if variance ~= 0 then
            textValue = textValue .. string.format(" (%+d)", variance)
        end
        drawStat("Attack", textValue, {0.8, 0.2, 0.2})
    end

    if self.definition.block and self.definition.block > 0 then
        drawStat("Block", tostring(self.definition.block), {0.2, 0.4, 0.8})
    end

    if self.definition.heal and self.definition.heal > 0 then
        drawStat("Heal", tostring(self.definition.heal), {0.2, 0.8, 0.2})
    end

    return statY
end

local function drawArt(image, x, y, w, h, descTop, statY)
    if not image then
        return statY
    end
    local imgW, imgH = image:getDimensions()
    if imgW <= 0 or imgH <= 0 then
        return statY
    end

    local artAreaTop = y + 34
    local artAreaBottom = descTop - 6
    if artAreaBottom <= artAreaTop + 32 then
        return statY
    end

    local maxW = w - 16
    local maxH = artAreaBottom - artAreaTop
    local scale = math.min(maxW / imgW, maxH / imgH)
    if scale <= 0 or scale == math.huge then
        return statY
    end

    local drawW = imgW * scale
    local drawH = imgH * scale
    local artX = x + (w - drawW) / 2
    local artY = artAreaTop + (maxH - drawH) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, artX, artY, 0, scale, scale)
    return math.max(statY, artY + drawH + 10)
end

local function drawBackArt(x, y, w, h)
    if not backArtImage then
        return false
    end
    local imgW, imgH = backArtImage:getDimensions()
    if imgW <= 0 or imgH <= 0 then
        return false
    end
    local scale = math.min(w / imgW, h / imgH)
    if scale <= 0 or scale == math.huge then
        return false
    end
    local drawW = imgW * scale
    local drawH = imgH * scale
    local artX = x + (w - drawW) / 2
    local artY = y + (h - drawH) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(backArtImage, artX, artY, 0, scale, scale)
    return true
end

-- Card logic only; rendering is handled by CardRenderer

function Card:isHovered(mx, my)
    return mx > self.x and mx < self.x + self.w and my > self.y and my < self.y + self.h
end

if not Card:getBackArt() then
    if love and love.filesystem and love.filesystem.getInfo then
        local info = love.filesystem.getInfo(DEFAULT_BACK_ART_PATH)
        if info then
            Card:setBackArt(DEFAULT_BACK_ART_PATH)
        end
    end
end

return Card
