local Gamestate = require "libs.hump.gamestate"

local menu  = require "src.states.menu"
local game  = require "src.states.game"
local pause = require "src.states.pause"

function love.load()
    love.window.setMode(1000, 600)
    love.graphics.setBackgroundColor(0.2, 0.5, 0.2)

    -- start at menu
    Gamestate.registerEvents()
    Gamestate.switch(menu)
end
