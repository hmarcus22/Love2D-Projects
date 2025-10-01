local Card = require "src.card"
local CardArt = require "src.card_art"
local Assets = require "src.asset_cache"
local defs = require "src.card_definitions"

local defsById = {}
for _, def in ipairs(defs) do
    defsById[def.id] = def
end

local factory = {}

function factory.reloadDefinitions()
    package.loaded["src.card_definitions"] = nil
    local newDefs = require "src.card_definitions"
    defsById = {}
    for _, def in ipairs(newDefs) do
        defsById[def.id] = def
    end
end

function factory.createCard(defId, opts)
    local def = defsById[defId]
    if not def then error("Unknown card id: " .. tostring(defId)) end
    local c = Card(defId, def.name)
    c.definition = def   -- attach stats
    -- Resolve art: explicit path takes precedence; otherwise try common candidates by id/name.
    local image, artPath
    if def.art and type(def.art) == 'string' and def.art ~= '' then
        artPath = def.art
        image = Assets.image(artPath) or CardArt.load(artPath)
    else
        -- Try assets/cards/<id> and <name> variants
        local function slugifyName(name)
            if not name or name == '' then return nil end
            local s = name:gsub("'", ""):gsub("%s+", "_")
            return s
        end
        local candidates = {}
        local function add(p) table.insert(candidates, p) end
        if def.id then
            add(string.format("assets/cards/%s.png", def.id))
            add(string.format("assets/cards/%s.jpg", def.id))
            add(string.format("assets/cards/%s.jpeg", def.id))
        end
        local slug = slugifyName(def.name)
        if slug then
            add(string.format("assets/cards/%s.png", slug))
            add(string.format("assets/cards/%s.jpg", slug))
            add(string.format("assets/cards/%s.jpeg", slug))
        end
        for _, path in ipairs(candidates) do
            local img = Assets.image(path)
            if img then image, artPath = img, path break end
        end
    end
    if image then
        c:setArt(image, artPath)
    elseif def.art then
        -- Record the intended path even if not found, for debugging
        c:setArt(nil, def.art)
    end
    if opts then
        for k, v in pairs(opts) do
            c[k] = v
        end
    end
    return c
end

function factory.createCopies(defId, count, opts)
    local copies = {}
    for i = 1, count do
        table.insert(copies, factory.createCard(defId, opts))
    end
    return copies
end

return factory




