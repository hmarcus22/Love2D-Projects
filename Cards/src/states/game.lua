local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local Viewport = require "src.viewport"
local pause = require "src.states.pause"
local replay_match = require "src.replay"

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
            -- Ensure fighter-specific cards are included
            player:setFighter(fighter or fighterId)
            -- Add drafted cards (if any) on top
            if p.deck then
                local factory = require "src.card_factory"
                for _, c in ipairs(p.deck) do
                    if type(c) == "string" then
                        table.insert(player.deck, factory.createCard(c))
                    elseif type(c) == "table" and c.id then
                        table.insert(player.deck, factory.createCard(c.id))
                    end
                end
            end
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

function game:update(dt)
    self.gs:update(dt)
    Input:update(self.gs, dt)
    local HudRenderer = require "src.renderers.hud_renderer"
    if HudRenderer.update then HudRenderer.update(dt) end
end
function game:draw()
    Viewport.apply()
    self.gs:draw()
    local HudRenderer = require "src.renderers.hud_renderer"
    if HudRenderer.drawDeckSummaryPopup then HudRenderer.drawDeckSummaryPopup() end
    Viewport.unapply()
end

function game:mousepressed(x, y, button)
    local vx, vy = Viewport.toVirtual(x, y)
    local HudRenderer = require "src.renderers.hud_renderer"
    local screenW = love.graphics.getWidth()
    local btnW, btnH = 120, 32
    local btnY = 8
    -- Check deck inspect buttons
    for i, player in ipairs(self.gs.players or {}) do
        local btnX = (i == 1) and 24 or (screenW - btnW - 24)
        if vx >= btnX and vx <= btnX + btnW and vy >= btnY and vy <= btnY + btnH then
            HudRenderer.showDeckSummary(player)
            return
        end
    end
    Input:mousepressed(self.gs, vx, vy, button)
end
function game:mousereleased(x, y, button)
    local vx, vy = Viewport.toVirtual(x, y)
    Input:mousereleased(self.gs, vx, vy, button)
end

function game:keypressed(key)
    if key == "r" then
        -- Start replay from log file
        replaying = true
        if type(replay_log_path) ~= "string" or replay_log_path == "" then
            replay_log_path = "match_log.json"
        end
        replay_match(replay_log_path)
        return
    end
    if key == "escape" then
        Gamestate.push(pause)
    else
        Input:keypressed(self.gs, key)
    end
end

return game
