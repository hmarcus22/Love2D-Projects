local CardArt = {}

local cache = {}
local missing = {}

function CardArt.load(path)
    if not path or path == '' then
        return nil
    end

    if cache[path] ~= nil then
        return cache[path]
    end

    if missing[path] then
        return nil
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    else
        print(string.format('[CardArt] Could not load "%s": %s', tostring(path), tostring(image)))
        missing[path] = true
        return nil
    end
end

return CardArt
