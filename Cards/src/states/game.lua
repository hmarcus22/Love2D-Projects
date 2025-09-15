local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local Viewport = require "src.viewport"
local pause = require "src.states.pause"

local game = {}

function game:enter(from, draftedPlayers)
    if type(draftedPlayers) == "table" then
        local Player = require "src.player"
        local newPlayers = {}
        for i, p in ipairs(draftedPlayers) do
            -- create proper Player object
            local player = Player{
                id = p.id,
                maxHandSize = p.maxHandSize,
                maxBoardCards = p.maxBoardCards
            }
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
function game:draw()
    Viewport.apply()
    self.gs:draw()
    Viewport.unapply()
end

function game:mousepressed(x, y, button)
    local vx, vy = Viewport.toVirtual(x, y)
    Input:mousepressed(self.gs, vx, vy, button)
end
function game:mousereleased(x, y, button)
    local vx, vy = Viewport.toVirtual(x, y)
    Input:mousereleased(self.gs, vx, vy, button)
end

function game:keypressed(key)
    if key == "escape" then
        Gamestate.push(pause)
    else
        Input:keypressed(self.gs, key)
    end
end

return game
