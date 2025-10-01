local M = {}

local imageCache = {}

local function loadImage(path)
    if not path or path == "" then return nil end
    if imageCache[path] ~= nil then return imageCache[path] end
    local ok = love.filesystem.getInfo(path)
    if not ok then
        imageCache[path] = false
        return nil
    end
    local img = love.graphics.newImage(path)
    imageCache[path] = img or false
    return img
end

function M.image(path)
    local img = loadImage(path)
    if img then return img end
    return nil
end

return M

