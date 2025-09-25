local Card = require "src.card"
local CardArt = require "src.card_art"
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
    if def.art then
        local image = CardArt.load(def.art)
        if image then
            c:setArt(image, def.art)
        else
            c:setArt(nil, def.art)
        end
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




