local M = {}

local imageCache = {}

local function configureFilters(path, img)
    if not img then return end
    -- Improve portrait quality when scaled by enabling mipmaps and linear filtering
    local isPortrait = path and path:find("assets/fighters/", 1, true) ~= nil
    local isCardArt = path and path:find("assets/cards/", 1, true) ~= nil
    if isPortrait or isCardArt then
        -- If mipmaps were not provided at creation, this is a no-op; we create with mipmaps below
        if img.setFilter then img:setFilter('linear', 'linear', 8) end
        if img.setMipmapFilter then img:setMipmapFilter('linear') end
    end
end

local function loadImage(path)
    if not path or path == "" then return nil end
    if imageCache[path] ~= nil then return imageCache[path] end
    local ok = love.filesystem.getInfo(path)
    if not ok then
        imageCache[path] = false
        return nil
    end
    local isPortrait = path:find("assets/fighters/", 1, true) ~= nil
    local isCardArt = path:find("assets/cards/", 1, true) ~= nil
    local flags = (isPortrait or isCardArt) and { mipmaps = true } or nil
    local img = love.graphics.newImage(path, flags)
    configureFilters(path, img)
    imageCache[path] = img or false
    return img
end

function M.image(path)
    local img = loadImage(path)
    if img then return img end
    return nil
end

return M
