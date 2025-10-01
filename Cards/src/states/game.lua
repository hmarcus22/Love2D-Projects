local Gamestate = require "libs.hump.gamestate"
local GameState = require "src.gamestate"
local Input = require "src.input"
local Viewport = require "src.viewport"
local pause = require "src.states.pause"
local replay_match = require "src.replay"

local game = {}

function game:enter(from, draftedPlayers)
    if type(draftedPlayers) ~= "table" then
        error("Game state requires drafted players! Did you skip draft?")
    end

    local Player = require "src.player"
    local factory = require "src.card_factory"

    local newPlayers = {}
    for i, p in ipairs(draftedPlayers) do
        local fighter = p.getFighter and p:getFighter() or p.fighter
        local fighterId = p.fighterId or (fighter and fighter.id)

        local player = Player{
            id = p.id,
            maxHandSize = p.maxHandSize,
            maxBoardCards = p.maxBoardCards,
            fighter = fighter,
            fighterId = fighterId,
        }

        -- Append drafted cards (player:setFighter rebuilds fighter deck)
        if p.deck then
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
        for _, card in ipairs(player.deck or {}) do
            table.insert(ids, card.id)
        end
        self.initialDeckIds[i] = ids
    end

    self.gs = GameState:newFromDraft(newPlayers)
    local Globals = require "src.globals"
    Globals.activeGame = self
end

function game:restartBattle()
    if not (self.initialPlayerProps and self.initialDeckIds) then return end

    local Player = require "src.player"
    local factory = require "src.card_factory"

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
    if not self.gs then return end
    self.gs:update(dt)
    Input:update(self.gs, dt)
    local HudRenderer = require "src.renderers.hud_renderer"
    if HudRenderer.update then
        HudRenderer.update(dt)
    end

    -- Transition back to menu when match ends
    if self.gs and self.gs.matchWinner and not self._matchHandled then
        self._matchHandled = true
        -- Lazy-require menu here to avoid circular requires
        Gamestate.switch(require "src.states.menu")
        return
    end
end

function game:draw()
    Viewport.apply()
    if self.gs and self.gs.draw then
        self.gs:draw()
    end
    local HudRenderer = require "src.renderers.hud_renderer"
    if HudRenderer.drawDeckSummaryPopup then
        HudRenderer.drawDeckSummaryPopup()
    end
    if HudRenderer.drawRoundOverPopup then
        HudRenderer.drawRoundOverPopup(love.graphics.getWidth())
    end
    Viewport.unapply()
end

function game:mousepressed(x, y, button)
    if not self.gs then return end
    local vx, vy = Viewport.toVirtual(x, y)
    local HudRenderer = require "src.renderers.hud_renderer"
    local screenW = love.graphics.getWidth()
    local btnW, btnH = 120, 32
    local btnY = 8

    for i, player in ipairs(self.gs.players or {}) do
        local btnX = (i == 1) and 24 or (screenW - btnW - 24)
        if vx >= btnX and vx <= btnX + btnW and vy >= btnY and vy <= btnY + btnH then
            if HudRenderer.showDeckSummary then
                HudRenderer.showDeckSummary(player)
            end
            return
        end
    end

    Input:mousepressed(self.gs, vx, vy, button)
end

function game:mousereleased(x, y, button)
    if not self.gs then return end
    local vx, vy = Viewport.toVirtual(x, y)
    Input:mousereleased(self.gs, vx, vy, button)
end

function game:keypressed(key)
    if key == "escape" then
        Gamestate.push(pause)
        return
    end
    if self.gs then
        Input:keypressed(self.gs, key)
    end
end

function game:wheelmoved(dx, dy)
    if not self.gs then return end
    -- Only scroll when hovering the combat log panel
    local mx, my = love.mouse.getPosition()
    local Viewport = require "src.viewport"
    mx, my = Viewport.toVirtual(mx, my)
    local ResolveRenderer = require "src.renderers.resolve_renderer"
    local panelX, panelY, panelW, panelH = ResolveRenderer.getLogPanelRect(self.gs, love.graphics.getWidth())
    if not (mx >= panelX and mx <= panelX + panelW and my >= panelY and my <= panelY + panelH) then
        return
    end
    -- Positive dy is wheel up in LÖVE; scroll up increases offset
    local step = 3
    local maxLines = self.gs.maxResolveLogLines or 14
    local filtered = ResolveRenderer.getFilteredLog(self.gs)
    local total = #filtered
    local maxOffset = math.max(0, total - maxLines)
    local current = self.gs.resolveLogScroll or 0
    if dy > 0 then
        self.gs.resolveLogScroll = math.min(maxOffset, current + step)
    elseif dy < 0 then
        self.gs.resolveLogScroll = math.max(0, current - step)
    end
end

return game

