-- require("lovedebug")
local Config = require "src.config"
local Gamestate = require "libs.hump.gamestate"
local Viewport = require "src.viewport"

local menu  = require "src.states.menu"
local game  = require "src.states.game"
local pause = require "src.states.pause"

function love.load()
    local windowConfig = Config.window or {}
    local width = windowConfig.width or 1000
    local height = windowConfig.height or 600
    local flags = {
        resizable = true,
        highdpi = false,
        minwidth = 800,
        minheight = 480,
    }

    for key, value in pairs(windowConfig.flags or {}) do
        flags[key] = value
    end

    local layoutConfig = Config.layout or {}
    local designWidth = layoutConfig.designWidth or width
    local designHeight = layoutConfig.designHeight or height
    local scaleFactor = layoutConfig.scaleFactor or 1.0

    love.window.setMode(width, height, flags)
    love.graphics.setBackgroundColor(0.2, 0.5, 0.2)
    Viewport.setup(designWidth, designHeight, { scale = scaleFactor })

    -- start at menu
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end

function love.resize(w, h)
    Viewport.resize(w, h)
end

