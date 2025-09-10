local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local pause = require "src.states.pause"

local game = {}

function game:enter(from, draftedPlayers)
    if type(draftedPlayers) == "table" then
        local Player = require "src.player"
        local newPlayers = {}
        for i, p in ipairs(draftedPlayers) do
            local player = Player(p.id, (i == 1) and 400 or 50, 5)
            -- copy drafted deck into player's deck
            player.deck = p.deck
            newPlayers[i] = player
        end
        self.gs = GameState:newFromDraft(newPlayers)
    else
        error("Game state requires drafted players! Did you skip draft?")
    end
end

function game:update(dt)  self.gs:update(dt) end
function game:draw()      self.gs:draw() end

function game:mousepressed(x, y, button)
    Input:mousepressed(self.gs, x, y, button)
end
function game:mousereleased(x, y, button)
    Input:mousereleased(self.gs, x, y, button)
end

function game:keypressed(key)
    if key == "escape" then
        Gamestate.push(pause)
    else
        Input:keypressed(self.gs, key)
    end
end

return game
