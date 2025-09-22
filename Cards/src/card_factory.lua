local Card = require "src.card"
local CardArt = require "src.card_art"
local defs = require "src.card_definitions"

local defsById = {}
for _, def in ipairs(defs) do
    defsById[def.id] = def
end

local factory = {}

-- make one card instance by ID
function factory.createCard(defId)
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
    return c
end

-- make N copies of a card
function factory.createCopies(defId, count)
    local copies = {}
    for i = 1, count do
        table.insert(copies, factory.createCard(defId))
    end
    return copies
end

return factory




