-- CardRenderer: decouples card rendering from card logic
local CardRenderer = {}
local Config = require "src.config"
local CardTextureCache = require "src.renderers.card_texture_cache"

-- Font cache for different sizes
local fontCache = {}
local defaultFont = love.graphics.getFont()

-- Get font for specified size with better font for scaling
local function getFont(size)
    size = size or 12
    if not fontCache[size] then
        -- Try to use a better font for text clarity
        local success, font = pcall(function()
            -- Try to load a system font that scales better
            return love.graphics.newFont("arial.ttf", size)
        end)
        
        if success and font then
            fontCache[size] = font
        else
            -- Fallback to default font with better filtering
            fontCache[size] = love.graphics.newFont(size)
            fontCache[size]:setFilter("linear", "linear")
        end
    end
    return fontCache[size]
end

-- Get configured font size with fallback
local function getFontSize(configKey, fallback)
    return (Config.ui and Config.ui[configKey]) or fallback or 12
end

-- Get configured panel size with fallback
local function getPanelSize(configKey, fallback)
    return (Config.ui and Config.ui[configKey]) or fallback or 10
end

-- Count all tokens that will be displayed for a card
local function countAllTokens(card)
    if not card.definition then return 0 end
    
    local count = 0
    
    -- Basic stat tokens
    if card.definition.attack and card.definition.attack > 0 then count = count + 1 end
    if card.definition.block and card.definition.block > 0 then count = count + 1 end
    if card.definition.heal and card.definition.heal > 0 then count = count + 1 end
    
    -- Modifier tokens
    if card.definition.mod then count = count + 1 end
    
    -- Effect tokens
    if card.definition.effect then count = count + 1 end
    
    return count
end

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

-- Main draw function - uses texture cache for consistent scaling
function CardRenderer.draw(card)
    local useCache = (Config.ui and Config.ui.useCardTextureCache) and not card._suppressShadow
    if useCache then
        CardRenderer.drawWithTexture(card)
    else
        CardRenderer.drawDirect(card)
    end
end

-- Draw card using pre-rendered texture (scale like card art)
function CardRenderer.drawWithTexture(card)
    local x = (card.animX ~= nil) and card.animX or card.x
    local y = (card.animY ~= nil) and card.animY or card.y
    local w, h = card.w, card.h
    local scaleX = card.impactScaleX or 1
    local scaleY = card.impactScaleY or 1
    local cx = x + w/2
    local cy = y + h/2
    
    -- Get pre-rendered high-resolution texture
    local texture, renderWidth, renderHeight = CardTextureCache.getTexture(card)
    
    if not texture then
        -- Fallback to direct rendering
        CardRenderer.drawDirect(card)
        return
    end
    
    -- Draw shadow if needed
    if not card._suppressShadow then
        CardRenderer.drawCardShadow(card, x, y, w, h, scaleX, scaleY)
    end
    
    -- Uniform scaling to exactly fill the card frame
    -- Since all cards have same 10:15 aspect ratio, use width-based scaling for consistency
    local scale = w / renderWidth
    
    -- Draw the pre-rendered texture scaled uniformly to fill card frame
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scaleX, scaleY)
    love.graphics.translate(-w/2, -h/2)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(texture, 0, 0, 0, scale, scale)
    
    love.graphics.pop()
    
    -- Draw post-texture effects (glow, flash, etc.)
    CardRenderer.drawPostTextureEffects(card, x, y, w, h, scaleX, scaleY)
end

-- All the post-texture effects
function CardRenderer.drawPostTextureEffects(card, x, y, w, h, scaleX, scaleY)
    local cx, cy = x + w/2, y + h/2
    
    -- Dragging border
    if card.dragging then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setLineWidth(5)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(scaleX, scaleY)
            love.graphics.translate(-cx, -cy)
        end
        
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.setLineWidth(1)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.pop()
        end
    end
    
    -- Hover glow
    local amt = card.handHoverAmount or 0
    if amt and amt > 0.01 then
        local glowCfg = (Config.layout and Config.layout.hoverGlow) or {}
        local color = glowCfg.color or {1, 1, 0.8, 0.85}
        local alpha = (color[4] or 0.85) * math.min(1, amt)
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        local lw = (glowCfg.width or 3) + (amt * (glowCfg.extraWidth or 2))
        love.graphics.setLineWidth(lw)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(scaleX, scaleY)
            love.graphics.translate(-cx, -cy)
        end
        
        love.graphics.rectangle("line", x - 4, y - 4, w + 8, h + 8, 12, 12)
        love.graphics.setLineWidth(1)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.pop()
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Impact flash
    if card.impactFlash and card.impactFlash > 0.01 then
        love.graphics.setColor(1, 1, 0.6, card.impactFlash)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.scale(scaleX, scaleY)
            love.graphics.translate(-cx, -cy)
        end
        
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.pop()
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Shadow drawing
function CardRenderer.drawCardShadow(card, x, y, w, h, scaleX, scaleY)
    local z = card.animZ or 0
    if z < 0 then z = 0 end
    local showShadow = z > 2 or card.dragging or (card.handHoverAmount and card.handHoverAmount > 0.02)
    
    if showShadow then
        local ui = Config.ui or {}
        local shadowScaleMin = ui.cardShadowMinScale or 0.85
        local shadowScaleMax = ui.cardShadowMaxScale or 1.08
        local shadowAlphaMin = ui.cardShadowMinAlpha or 0.25
        local shadowAlphaMax = ui.cardShadowMaxAlpha or 0.55
        local norm = 0
        local arcRef = ui.cardFlightArcHeight or 140
        if arcRef > 0 then norm = math.min(1, z / arcRef) end
        local sScale = shadowScaleMax - (shadowScaleMax - shadowScaleMin) * norm
        local sAlpha = shadowAlphaMax - (shadowAlphaMax - shadowAlphaMin) * norm
        
        local shadowW = w * sScale
        local shadowH = h * sScale * 0.98
        local sx = x + (w - shadowW) / 2
        local sy = y + (h - shadowH) / 2 + 4
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.push()
            local cx, cy = x + w/2, y + h/2
            love.graphics.translate(cx, cy)
            love.graphics.scale(scaleX, scaleY)
            love.graphics.translate(-cx, -cy)
        end
        
        love.graphics.setColor(0, 0, 0, sAlpha)
        love.graphics.rectangle("fill", sx, sy, shadowW, shadowH, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        
        if scaleX ~= 1 or scaleY ~= 1 then
            love.graphics.pop()
        end
    end
end

-- Direct rendering (for texture generation) - SIMPLIFIED with configurable fonts
function CardRenderer.drawDirect(card)
    local x = (card.animX ~= nil) and card.animX or card.x
    local y = (card.animY ~= nil) and card.animY or card.y
    local w, h = card.w, card.h
    local scaleX = card.impactScaleX or 1
    local scaleY = card.impactScaleY or 1
    local cx = x + w/2
    local cy = y + h/2
    
    -- Position override for downstream helpers
    local restorePos = false
    local oldX, oldY
    if (card.x ~= x) or (card.y ~= y) then
        oldX, oldY = card.x, card.y
        card.x, card.y = x, y
        restorePos = true
    end
    
    local function restore()
        if restorePos then
            card.x, card.y = oldX, oldY
            restorePos = false
        end
    end
    
    if scaleX ~= 1 or scaleY ~= 1 then
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(scaleX, scaleY)
        love.graphics.translate(-cx, -cy)
    end
    
    -- Shadow (only when not suppressed)
    if not card._suppressShadow then
        CardRenderer.drawCardShadow(card, x, y, w, h, 1, 1) -- No double scaling
    end
    
    -- Z elevation
    local z = card.animZ or 0
    if z > 0 then
        y = y - z
        card.y = y
    end
    
    -- Background/art
    local usedCover = false
    if card.faceUp and card.art then
        usedCover = CardRenderer.drawArtCover(card.art, x, y, w, h)
    end
    if not usedCover then
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end
    
    -- Border
    if card.dragging then
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", x, y, w, h, 8, 8)
    end

    -- Face down cards
    local faceUp = card.faceUp
    if not faceUp then
        if CardRenderer.drawBackArt(card) then 
            if scaleX ~= 1 or scaleY ~= 1 then love.graphics.pop() end
            restore()
            return 
        end
        love.graphics.setColor(0.2, 0.2, 0.6)
        local backFont = getFont(getFontSize('cardBackFontSize', 10))
        love.graphics.setFont(backFont)
        love.graphics.printf("Deck", x, y + h / 2 - 6, w, "center")
        love.graphics.setFont(defaultFont)
        if scaleX ~= 1 or scaleY ~= 1 then love.graphics.pop() end
        restore()
        return
    end

    -- Name panel
    local layout = Config.layout or {}
    local nameAlpha = (layout.cardNamePanelAlpha ~= nil) and layout.cardNamePanelAlpha or 0.78
    local namePanelHeight = getPanelSize('cardNamePanelHeight', 26)
    local nameYOffset = getPanelSize('cardNameYOffset', 8)
    love.graphics.setColor(1, 1, 1, nameAlpha)
    love.graphics.rectangle("fill", x + 4, y + nameYOffset - 2, w - 8, namePanelHeight, 6, 6)
    love.graphics.setColor(0, 0, 0)
    local nameFont = getFont(getFontSize('cardNameFontSize', 10))
    love.graphics.setFont(nameFont)
    love.graphics.printf(card.name, x, y + nameYOffset, w, "center")
    love.graphics.setFont(defaultFont)
    
    -- Cost circle
    if card.definition and card.definition.cost then
        love.graphics.setColor(0.9, 0.9, 0.3)
        love.graphics.circle("fill", x + 15, y + 15, 12)
        love.graphics.setColor(0, 0, 0)
        local costFont = getFont(getFontSize('cardCostFontSize', 8))
        love.graphics.setFont(costFont)
        love.graphics.printf(tostring(card.definition.cost), x, y + 9, 30, "center")
        love.graphics.setFont(defaultFont)
    end
    
    local descYOffset = getPanelSize('cardDescYOffset', 60)
    local statsYOffset = getPanelSize('cardStatsYOffset', 44)
    local descTop = y + h - descYOffset
    local statY = y + 48
    
    -- Stats background
    if card.definition then
        local statsCount = countAllTokens(card)
        if statsCount > 0 then
            local statsY = y + statsYOffset
            local statsPanelHeight = getPanelSize('cardStatsPanelHeight', 18)
            local statsH = math.min((descTop - 6) - statsY, statsCount * statsPanelHeight + 6)
            if statsH and statsH > 4 then
                local statsAlpha = (layout.cardStatsPanelAlpha ~= nil) and layout.cardStatsPanelAlpha or 0.66
                love.graphics.setColor(1, 1, 1, statsAlpha)
                love.graphics.rectangle("fill", x + 4, statsY, w - 8, statsH, 6, 6)
            end
        end
    end
    
    -- Art and stats
    if not usedCover then
        statY = CardRenderer.drawArt(card.art, x, y, w, h, descTop, statY)
    end
    statY = CardRenderer.drawCardStats(card, x, y + statsYOffset, descTop)
    
    -- Description
    if card.definition and card.definition.description then
        local descPadding = getPanelSize('cardDescPanelPadding', 8)
        local descY = descTop - 4
        local descH = math.max(10, h - (descTop - y) - descPadding)
        local descAlpha = (layout.cardDescPanelAlpha ~= nil) and layout.cardDescPanelAlpha or 0.78
        love.graphics.setColor(1, 1, 1, descAlpha)
        love.graphics.rectangle("fill", x + 4, descY, w - 8, descH, 6, 6)
        love.graphics.setColor(0.1, 0.1, 0.1)
        local descFont = getFont(getFontSize('cardDescFontSize', 7))
        love.graphics.setFont(descFont)
        love.graphics.printf(card.definition.description, x + 5, descTop, w - 10, "center")
        love.graphics.setFont(defaultFont)
    end

    -- Post-texture effects (when not using texture cache)
    if not (Config.ui and Config.ui.useCardTextureCache) then
        CardRenderer.drawPostTextureEffects(card, x, y, w, h, scaleX, scaleY)
    end

    if scaleX ~= 1 or scaleY ~= 1 then
        love.graphics.pop()
    end
    restore()
end

-- Stats drawing helper
function CardRenderer.drawCardStats(card, x, statY, descTop)
    if not card.definition then return statY end
    
    local function drawStat(label, textValue, color)
        if not textValue or textValue == "" then return end
        if statY + 18 > descTop - 4 then return end
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", x + 10, statY, 14, 14, 2, 2)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", x + 10, statY, 14, 14, 2, 2)
        local statFont = getFont(getFontSize('cardStatFontSize', 8))
        love.graphics.setFont(statFont)
        love.graphics.printf(label .. ": " .. textValue, x + 30, statY - 2, card.w - 40, "left")
        love.graphics.setFont(defaultFont)
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
    
    -- Modifier tokens (Purple)
    if card.definition.mod then
        local mod = card.definition.mod
        if mod.attack and mod.attack ~= 0 then
            local sign = mod.attack > 0 and "+" or ""
            local target = mod.target == "ally" and "Ally" or "Enemy"
            drawStat(target, sign .. mod.attack .. " ATK", {0.7, 0.3, 0.8})
        end
        if mod.block and mod.block ~= 0 then
            local sign = mod.block > 0 and "+" or ""
            local target = mod.target == "ally" and "Ally" or "Enemy"
            drawStat(target, sign .. mod.block .. " BLK", {0.7, 0.3, 0.8})
        end
        if mod.retarget then
            drawStat("Special", "Retarget", {1.0, 0.5, 0.1})
        end
    end
    
    -- Special effect tokens (Orange)
    if card.definition.effect then
        if card.definition.effect == "aoe_attack" then
            drawStat("Special", "AOE", {1.0, 0.5, 0.1})
        end
    end
    
    -- Combo tokens (Orange)
    if card.definition.combo then
        drawStat("Combo", "After " .. (card.definition.combo.after or "?"), {1.0, 0.5, 0.1})
    end
    
    return statY
end

-- Art drawing helpers (unchanged)
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

-- Debug and utility functions
function CardRenderer.setTextureCache(enabled)
    if Config.ui then
        Config.ui.useCardTextureCache = enabled
    end
end

function CardRenderer.drawDebugInfo()
    if not (Config.ui and Config.ui.cardTextureDebugInfo) then return end
    
    local stats = CardTextureCache.getStats()
    local lines = {
        string.format("Card Texture Cache:"),
        string.format("  Size: %d/%d", stats.size, 100),
        string.format("  Hits: %d (%.1f%%)", stats.hits, (stats.hitRate or 0) * 100),
        string.format("  Misses: %d", stats.misses),
        string.format("  Evictions: %d", stats.evictions),
    }
    
    local x, y = 10, 10
    local lineHeight = 16
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 5, y - 5, 180, #lines * lineHeight + 10, 4, 4)
    
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
        love.graphics.print(line, x, y + (i - 1) * lineHeight)
    end
end

return CardRenderer