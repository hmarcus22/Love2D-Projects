-- Simple test script to verify texture cache graphics scaling
local CardTextureCache = require "src.renderers.card_texture_cache"
local Config = require "src.config"

-- Enable texture cache
Config.ui = Config.ui or {}
Config.ui.useCardTextureCache = true

-- Create a test card with some text
local testCard = {
    x = 100, y = 100, w = 100, h = 150,
    name = "Test Card",
    cost = 3,
    attack = 2,
    defense = 4,
    description = "This is a test card with some description text that should be crisp when rendered.",
    artKey = nil -- No art for this test
}

function love.load()
    print("Testing texture cache graphics scaling...")
    
    -- Test at different sizes to verify scaling
    local sizes = {
        {w = 50, h = 75, name = "Small"},
        {w = 100, h = 150, name = "Medium"},
        {w = 200, h = 300, name = "Large"},
        {w = 300, h = 450, name = "X-Large"}
    }
    
    for i, size in ipairs(sizes) do
        print(string.format("Testing %s size (%dx%d):", size.name, size.w, size.h))
        
        local texture, renderWidth, renderHeight = CardTextureCache.getTexture(testCard, size.w, size.h)
        
        if texture then
            local textureW, textureH = texture:getDimensions()
            print(string.format("  Texture dimensions: %dx%d", textureW, textureH))
            print(string.format("  Render dimensions: %dx%d", renderWidth, renderHeight))
            print(string.format("  Scale factor: %.2fx%.2f", textureW/size.w, textureH/size.h))
        else
            print("  Failed to generate texture!")
        end
    end
    
    -- Print cache stats
    local stats = CardTextureCache.getStats()
    print(string.format("Cache stats - Hits: %d, Misses: %d, Evictions: %d", 
          stats.hits, stats.misses, stats.evictions))
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Check console for texture cache test results", 10, 10)
    love.graphics.print("Press ESC to exit", 10, 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end