-- CardRenderer: decouples card rendering from card logic
local CardRenderer = {}

-- Draw art to cover the entire card area while preserving aspect ratio
function CardRenderer.drawArtCover(image, x, y, w, h)
    if not image then return false end
    local imgW, imgH = image:getDimensions()
    if (imgW or 0) <= 0 or (imgH or 0) <= 0 then return false end
    local scale = math.max(w / imgW, h / imgH)
    if scale <= 0 or scale == math.huge then return false end
    local drawW = imgW * scale
    local drawH = imgH * scale
    local artX = x + (w - drawW) / 2
    local artY = y + (h - drawH) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, artX, artY, 0, scale, scale)
    return true
end

-- Draw a card (face up or down)
function CardRenderer.draw(card)
    local x, y, w, h = card.x, card.y, card.w, card.h
    -- Debug print removed
    -- Draw card background (cover art when available)
    local usedCover = false
    if card.faceUp and card.art then
        usedCover = CardRenderer.drawArtCover(card.art, x, y, w, h)
    end
    if not usedCover then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end
    -- If dragging, draw a bright yellow border for visibility
    if card.dragging then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
    end

    if not card.faceUp then
        if CardRenderer.drawBackArt(card) then return end
        love.graphics.setColor(0.2, 0.2, 0.6)
        love.graphics.printf("Deck", x, y + h / 2 - 6, w, "center")
        return
    end

    -- Soft translucent header behind name for readability over art
    love.graphics.setColor(1, 1, 1, 0.78)
    love.graphics.rectangle("fill", x + 4, y + 4, w - 8, 26, 6, 6)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(card.name, x, y + 8, w, "center")
    if not card.definition then return end
    if card.definition.cost then
        love.graphics.setColor(0.9, 0.9, 0.3)
        love.graphics.circle("fill", x + 15, y + 15, 12)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf(tostring(card.definition.cost), x, y + 9, 30, "center")
    end
    local descTop = y + h - 60
    local statY = y + 48
    -- Draw soft backdrops for stats block and description to improve legibility
    local statsCount = 0
    if card.definition.attack and card.definition.attack > 0 then statsCount = statsCount + 1 end
    if card.definition.block and card.definition.block > 0 then statsCount = statsCount + 1 end
    if card.definition.heal and card.definition.heal > 0 then statsCount = statsCount + 1 end
    if statsCount > 0 then
        local statsY = y + 44
        local statsH = math.min((descTop - 6) - statsY, statsCount * 18 + 6)
        if statsH and statsH > 4 then
            love.graphics.setColor(1, 1, 1, 0.66)
            love.graphics.rectangle("fill", x + 4, statsY, w - 8, statsH, 6, 6)
        end
    end
    if not usedCover then
        statY = CardRenderer.drawArt(card.art, x, y, w, h, descTop, statY)
    end
    statY = CardRenderer.drawCardStats(card, statY, descTop)
    if card.definition.description then
        local descY = descTop - 4
        local descH = math.max(10, h - (descTop - y) - 8)
        love.graphics.setColor(1, 1, 1, 0.78)
        love.graphics.rectangle("fill", x + 4, descY, w - 8, descH, 6, 6)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.printf(card.definition.description, x + 5, descTop, w - 10, "center")
    end
end

function CardRenderer.drawCardStats(card, statY, descTop)
    if not card.definition then return statY end
    local function drawStat(label, textValue, color)
        if not textValue or textValue == "" then return end
        if statY + 18 > descTop - 4 then return end
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", card.x + 10, statY, 14, 14, 2, 2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", card.x + 10, statY, 14, 14, 2, 2)
        love.graphics.printf(label .. ": " .. textValue, card.x + 30, statY - 2, card.w - 40, "left")
        statY = statY + 18
    end
    if card.definition.attack and card.definition.attack > 0 then
        local base = card.definition.attack
        local variance = card.statVariance and card.statVariance.attack or 0
        local textValue = tostring(base)
        if variance ~= 0 then textValue = textValue .. string.format(" (%+d)", variance) end
        drawStat("Attack", textValue, {0.8, 0.2, 0.2})
    end
    if card.definition.block and card.definition.block > 0 then
        drawStat("Block", tostring(card.definition.block), {0.2, 0.4, 0.8})
    end
    if card.definition.heal and card.definition.heal > 0 then
        drawStat("Heal", tostring(card.definition.heal), {0.2, 0.8, 0.2})
    end
    return statY
end

function CardRenderer.drawArt(image, x, y, w, h, descTop, statY)
    if not image then return statY end
    local imgW, imgH = image:getDimensions()
    if imgW <= 0 or imgH <= 0 then return statY end
    local artAreaTop = y + 34
    local artAreaBottom = descTop - 6
    if artAreaBottom <= artAreaTop + 32 then return statY end
    local maxW = w - 16
    local maxH = artAreaBottom - artAreaTop
    local scale = math.min(maxW / imgW, maxH / imgH)
    if scale <= 0 or scale == math.huge then return statY end
    local drawW = imgW * scale
    local drawH = imgH * scale
    local artX = x + (w - drawW) / 2
    local artY = artAreaTop + (maxH - drawH) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, artX, artY, 0, scale, scale)
    return math.max(statY, artY + drawH + 10)
end

function CardRenderer.drawBackArt(card)
    local image = card.getBackArt and select(1, card:getBackArt())
    if not image then return false end
    local imgW, imgH = image:getDimensions()
    if imgW <= 0 or imgH <= 0 then return false end
    local scale = math.min(card.w / imgW, card.h / imgH)
    if scale <= 0 or scale == math.huge then return false end
    local drawW = imgW * scale
    local drawH = imgH * scale
    local artX = card.x + (card.w - drawW) / 2
    local artY = card.y + (card.h - drawH) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, artX, artY, 0, scale, scale)
    return true
end

return CardRenderer
