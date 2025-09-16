local Gamestate = require "libs.hump.gamestate"
local Viewport = require "src.viewport"
local Config = require "src.config"

local pause = {}

function pause:draw()
    Viewport.apply()
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", 0, 0, Viewport.getWidth(), Viewport.getHeight())

    love.graphics.setColor(1,1,1)
    love.graphics.printf("Paused", 0, 150, Viewport.getWidth(), "center")
    love.graphics.printf("ESC to Resume", 0, 250, Viewport.getWidth(), "center")
    love.graphics.printf("R to Restart", 0, 300, Viewport.getWidth(), "center")
    love.graphics.printf("Q to Quit to Menu", 0, 350, Viewport.getWidth(), "center")

    -- Runtime rule toggles
    local y = 420
    local function onoff(b) return b and "On" or "Off" end
    local w = Viewport.getWidth()
    love.graphics.printf(string.format("[D] Manual Draw: %s", onoff(Config.rules.allowManualDraw)), 0, y, w, "center"); y = y + 20
    love.graphics.printf(string.format("[X] Manual Discard: %s", onoff(Config.rules.allowManualDiscard)), 0, y, w, "center"); y = y + 20
    love.graphics.printf(string.format("[P] Show Discard Pile: %s", onoff(Config.rules.showDiscardPile)), 0, y, w, "center"); y = y + 20
    love.graphics.printf(string.format("[1] Auto Draw On Turn Start: %d", Config.rules.autoDrawOnTurnStart or 0), 0, y, w, "center"); y = y + 20
    love.graphics.printf(string.format("[2] Auto Draw Per Round: %d", Config.rules.autoDrawPerRound or 0), 0, y, w, "center"); y = y + 20
    Viewport.unapply()
end

function pause:keypressed(key)
    if key == "escape" then
        Gamestate.pop() -- resume
    elseif key == "r" then
        local game = require "src.states.game"
        Gamestate.switch(game, true) -- restart new game
    elseif key == "q" then
        local menu = require "src.states.menu"
        Gamestate.switch(menu)
    elseif key == "d" then
        Config.rules.allowManualDraw = not Config.rules.allowManualDraw
    elseif key == "x" then
        Config.rules.allowManualDiscard = not Config.rules.allowManualDiscard
    elseif key == "p" then
        Config.rules.showDiscardPile = not Config.rules.showDiscardPile
    elseif key == "1" then
        local n = (Config.rules.autoDrawOnTurnStart or 0)
        Config.rules.autoDrawOnTurnStart = (n + 1) % 3 -- cycle 0..2
    elseif key == "2" then
        local n = (Config.rules.autoDrawPerRound or 0)
        Config.rules.autoDrawPerRound = (n + 1) % 3 -- cycle 0..2
    end
end

return pause
