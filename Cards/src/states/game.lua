local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local Viewport = require "src.viewport"
local pause = require "src.states.pause"

local game = {}

function game:enter(from, draftedPlayers)
    if type(draftedPlayers) == "table" then
        local Player = require "src.player"
        local factory = require "src.card_factory"
        local newPlayers = {}
        for i, p in ipairs(draftedPlayers) do
            -- create proper Player object
            local fighter = p.getFighter and p:getFighter() or p.fighter
            local fighterId = p.fighterId or (fighter and fighter.id)
            local player = Player{
                id = p.id,
                maxHandSize = p.maxHandSize,
                maxBoardCards = p.maxBoardCards,
                fighter = fighter,
                fighterId = fighterId
            }
            -- copy drafted deck into player's deck
            player.deck = p.deck
            newPlayers[i] = player
        end
        -- snapshot initial decks (by def id) and player props for restart
        self.initialPlayerProps = {}
        self.initialDeckIds = {}
        for i, player in ipairs(newPlayers) do
            self.initialPlayerProps[i] = {
                id = player.id,
                maxHandSize = player.maxHandSize,
                maxBoardCards = player.maxBoardCards,
                fighterId = player.fighterId,
            }
            local ids = {}
            for _, c in ipairs(player.deck or {}) do
                table.insert(ids, c.id)
            end
            self.initialDeckIds[i] = ids
        end
        self.gs = GameState:newFromDraft(newPlayers)
        local Globals = require "src.globals"
        Globals.activeGame = self
    else
        error("Game state requires drafted players! Did you skip draft?")
    end
end

-- Restart the battle with the originally drafted decks (new card instances)
function game:restartBattle()
    if not (self.initialPlayerProps and self.initialDeckIds) then return end
    local Player = require "src.player"
    local factory = require "src.card_factory"
    local GameState = require "src.gamestate"

    local newPlayers = {}
    for i, props in ipairs(self.initialPlayerProps) do
        local player = Player{
            id = props.id,
            maxHandSize = props.maxHandSize,
            maxBoardCards = props.maxBoardCards,
            fighterId = props.fighterId,
        }
        player.deck = {}
        for _, defId in ipairs(self.initialDeckIds[i] or {}) do
            table.insert(player.deck, factory.createCard(defId))
        end
        newPlayers[i] = player
    end
    self.gs = GameState:newFromDraft(newPlayers)
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
