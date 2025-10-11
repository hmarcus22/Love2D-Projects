-- Card Texture Cache: Pre-renders cards to textures for consistent scaling
-- Solves text reflow issues when cards scale during animations

local CardTextureCache = {}
local Config = require "src.config"

-- Cache storage
local textureCache = {}
local canvasPool = {} -- Reuse canvases to avoid constant allocation

-- Render settings
local RENDER_SCALE = 2.0 -- Render at 2x for crisp downscaling
local MAX_CACHE_SIZE = 100 -- Limit memory usage
local cacheStats = { hits = 0, misses = 0, evictions = 0 }

-- Generate cache key for a card configuration
local function getCacheKey(cardId, faceUp, variance)
    local varianceKey = ""
    if variance then
        for stat, val in pairs(variance) do
            varianceKey = varianceKey .. stat .. ":" .. tostring(val) .. ";"
        end
    end
    
    -- Include font sizes in cache key for proper invalidation when fonts change
    local ui = Config.ui or {}
    local fontKey = string.format("f%d_%d_%d_%d_%d", 
        ui.cardNameFontSize or 12,
        ui.cardCostFontSize or 10, 
        ui.cardStatFontSize or 10,
        ui.cardDescFontSize or 9,
        ui.cardBackFontSize or 12
    )
    
    -- Simple key - no dimensions, render once at high quality
    return string.format("%s_%s_%s_%s", 
        cardId or "unknown", 
        faceUp and "up" or "down",
        varianceKey,
        fontKey)
end

-- Get or create a canvas for rendering
local function getCanvas(width, height)
    local key = string.format("%dx%d", width, height)
    if not canvasPool[key] then
        canvasPool[key] = love.graphics.newCanvas(width, height)
    end
    return canvasPool[key]
end

-- Render a card to a texture at high resolution for scaling
local function renderCardToTexture(card)
    -- Use exact 10:15 aspect ratio at high resolution
    local aspectWidth, aspectHeight = 10, 15  -- Card aspect ratio
    local scale = 30  -- Higher resolution: 300x450 for better text
    local baseWidth = aspectWidth * scale
    local baseHeight = aspectHeight * scale
    local canvas = getCanvas(baseWidth, baseHeight)
    
    -- Store original card properties (including transforms that should NOT be baked into the texture)
    local oldX, oldY, oldW, oldH = card.x, card.y, card.w, card.h
    local oldAnimX, oldAnimY = card.animX, card.animY
    local oldScaleX, oldScaleY = card.impactScaleX, card.impactScaleY
    local oldAnimZ = card.animZ
    local oldRotation = card.rotation
    
    -- Set card to exact position and size for consistent texture rendering
    card.x, card.y = 0, 0
    card.animX, card.animY = nil, nil  -- Clear animation offsets
    card.w, card.h = baseWidth, baseHeight
    card.impactScaleX, card.impactScaleY = 1, 1
    card.animZ = nil                   -- Prevent vertical lift from affecting baked texture
    card.rotation = nil                -- Prevent rotation from affecting baked texture
    
    -- Render to canvas
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    -- Reset any active transforms/scissors from game rendering (e.g., Viewport.apply())
    -- so baking happens in canvas pixel space (0..baseW, 0..baseH)
    if love.graphics.origin then love.graphics.origin() end
    if love.graphics.setScissor then love.graphics.setScissor() end
    love.graphics.clear(0, 0, 0, 0) -- Transparent background
    
    -- Use existing card renderer but without scaling transforms
    local CardRenderer = require "src.card_renderer"
    
    -- Disable shadow for texture rendering (we'll add it back during draw)
    card._suppressShadow = true
    
    CardRenderer.drawDirect(card)  -- Force direct rendering to avoid texture recursion
    
    -- Restore all card properties
    card._suppressShadow = nil
    card.x, card.y = oldX, oldY
    card.animX, card.animY = oldAnimX, oldAnimY
    card.w, card.h = oldW, oldH
    card.impactScaleX, card.impactScaleY = oldScaleX, oldScaleY
    card.animZ = oldAnimZ
    card.rotation = oldRotation
    
    love.graphics.setCanvas()
    love.graphics.pop()
    
    -- Create texture from canvas
    local imageData = canvas:newImageData()
    local texture = love.graphics.newImage(imageData)
    -- Respect pixelPerfect layout setting to avoid subpixel blurring/offsets
    local pixelPerfect = (Config.layout and Config.layout.pixelPerfect) or false
    if pixelPerfect then
        texture:setFilter("nearest", "nearest")
    else
        texture:setFilter("linear", "linear") -- Smooth scaling
    end
    
    return texture, baseWidth, baseHeight
end

-- Evict oldest entries when cache gets too large
local function evictOldEntries()
    local keys = {}
    for key in pairs(textureCache) do
        table.insert(keys, key)
    end
    
    -- Simple LRU: remove oldest entries
    table.sort(keys, function(a, b) 
        return textureCache[a].lastUsed < textureCache[b].lastUsed 
    end)
    
    local toRemove = math.max(0, #keys - MAX_CACHE_SIZE + 10) -- Remove 10 extra to avoid constant eviction
    for i = 1, toRemove do
        local key = keys[i]
        if textureCache[key].texture then
            textureCache[key].texture:release()
        end
        textureCache[key] = nil
        cacheStats.evictions = cacheStats.evictions + 1
    end
end

-- Get cached texture or create new one
function CardTextureCache.getTexture(card)
    -- Generate simple cache key
    local key = getCacheKey(card.id, card.faceUp, card.statVariance)
    
    -- Check cache
    local cached = textureCache[key]
    if cached then
        cached.lastUsed = love.timer.getTime()
        cacheStats.hits = cacheStats.hits + 1
        return cached.texture, cached.renderWidth, cached.renderHeight
    end
    
    -- Cache miss - render new texture
    cacheStats.misses = cacheStats.misses + 1
    
    -- Render texture at high resolution for scaling
    local texture, actualW, actualH = renderCardToTexture(card)
    
    -- Cache the result
    textureCache[key] = {
        texture = texture,
        renderWidth = actualW,
        renderHeight = actualH,
        lastUsed = love.timer.getTime()
    }
    
    -- Evict old entries if cache is too large
    local count = 0
    for _ in pairs(textureCache) do count = count + 1 end
    if count > MAX_CACHE_SIZE then
        evictOldEntries()
    end
    
    return texture, actualW, actualH
end

-- Clear cache (useful when card definitions change)
function CardTextureCache.clear()
    -- Release cached textures
    for key, cached in pairs(textureCache) do
        if cached.texture then
            cached.texture:release()
        end
    end
    textureCache = {}
    cacheStats = { hits = 0, misses = 0, evictions = 0 }
    -- Also release pooled canvases to avoid stale GPU state/resolution mismatches
    for key, canvas in pairs(canvasPool) do
        if canvas and canvas.release then
            canvas:release()
        end
        canvasPool[key] = nil
    end
end

-- Clear cache when font sizes change (textures need re-rendering)
function CardTextureCache.onFontChange()
    CardTextureCache.clear()
end

-- Clear cache when window resizes (no longer needed but kept for API compatibility)
function CardTextureCache.onWindowResize()
    -- Clear textures and canvases so regenerated content matches new resolution/state
    CardTextureCache.clear()
end

-- Clear cache for specific card
function CardTextureCache.clearCard(cardId)
    local toRemove = {}
    for key, cached in pairs(textureCache) do
        if string.find(key, "^" .. cardId .. "_") then
            table.insert(toRemove, key)
            if cached.texture then
                cached.texture:release()
            end
        end
    end
    for _, key in ipairs(toRemove) do
        textureCache[key] = nil
    end
end

-- Get cache statistics
function CardTextureCache.getStats()
    return {
        size = 0, -- Count current entries
        hits = cacheStats.hits,
        misses = cacheStats.misses,
        evictions = cacheStats.evictions,
        hitRate = cacheStats.hits > 0 and (cacheStats.hits / (cacheStats.hits + cacheStats.misses)) or 0
    }
end

-- Update size count
local function updateStats()
    local stats = CardTextureCache.getStats()
    local count = 0
    for _ in pairs(textureCache) do count = count + 1 end
    stats.size = count
    return stats
end

-- Override getStats to include current size
function CardTextureCache.getStats()
    local stats = {
        hits = cacheStats.hits,
        misses = cacheStats.misses,
        evictions = cacheStats.evictions,
        hitRate = cacheStats.hits > 0 and (cacheStats.hits / (cacheStats.hits + cacheStats.misses)) or 0
    }
    local count = 0
    for _ in pairs(textureCache) do count = count + 1 end
    stats.size = count
    return stats
end

-- Cleanup function for shutdown
function CardTextureCache.cleanup()
    CardTextureCache.clear()
    for _, canvas in pairs(canvasPool) do
        canvas:release()
    end
    canvasPool = {}
end

return CardTextureCache
