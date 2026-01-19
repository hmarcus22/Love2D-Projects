
local config = require "config"
local Board = require "board"
local Card = require "card"
local board

local function shuffle(deck)
    for i = #deck, 2, -1 do
        local j = love.math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

local function buildDraftPool()
    local suits = { "hearts", "diamonds", "spades", "cloves" }
    local deck = {}
    for _, suit in ipairs(suits) do
        for rank = 1, 13 do
            table.insert(deck, Card(rank, suit))
        end
    end
    shuffle(deck)
    return deck
end

love.load = function()
    love.window.setMode(config.window.width, config.window.height, {
        resizable = config.window.resizable,
        fullscreen = config.window.fullscreen,
    })
    love.window.setTitle(config.window.title)

    board = Board()
    local draftPool = buildDraftPool()
    board:setupFromDraftPool(draftPool)
end

love.keypressed = function(key)
    if key == "escape" then
        love.event.quit()
    end
    -- Additional key handling can go here
end

love.draw = function()
    local r, g, b = love.math.colorFromBytes(
        config.colors.background[1],
        config.colors.background[2],
        config.colors.background[3]
    )
    love.graphics.clear(r, g, b)
    
    if board then
        board:draw()
    end
end

love.update = function(dt)
    -- Game update logic can go here
end
