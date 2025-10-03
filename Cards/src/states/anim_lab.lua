local Gamestate = require 'libs.hump.gamestate'
local CardDefs = require 'src.card_definitions'
local Config = require 'src.config'
local Viewport = require 'src.viewport'
local TunerOverlay = require 'src.tuner_overlay'
local GameState = require 'src.gamestate'
local Player = require 'src.player'
local CardFactory = require 'src.card_factory'
local Input = require 'src.input'

local anim_lab = {}

-- Build & cache card definitions list (for tuner / selection)
local function buildDefList()
  local list = {}
  for _, d in ipairs(CardDefs) do list[#list+1] = d end
  table.sort(list, function(a,b) return a.id < b.id end)
  return list
end

function anim_lab:init()
  self.cards = buildDefList()
  self.attackerIndex = 1
  -- Create two blank players with generous limits
  local p1 = Player{ id=1, maxHandSize=10, maxBoardCards=3 }
  local p2 = Player{ id=2, maxHandSize=10, maxBoardCards=3 }
  p1.deck = {}; p2.deck = {}
  self.gs = GameState:newFromDraft({p1,p2})
  -- Give lots of energy for testing
  p1.energy, p2.energy = 99, 99
  -- Lab flags
  self.autoRefill = true -- auto keep a test copy in current player's hand
end

function anim_lab:enter()
  self:init()
end

-- Spawn a copy of currently selected definition into current player's hand
function anim_lab:spawnTestCard()
  local def = self.cards[self.attackerIndex]
  if not def or not self.gs then return end
  local player = self.gs:getCurrentPlayer()
  if not player then return end
  local card = CardFactory.createCard(def.id)
  player:addCard(card)
  self.gs:refreshLayoutPositions()
end

local function handHasDef(player, defId)
  if not player or not player.slots then return false end
  for _, slot in ipairs(player.slots) do
    if slot.card and slot.card.id == defId then return true end
  end
  return false
end

-- Ensure a test card copy exists when autoRefill enabled
function anim_lab:ensureTestCard()
  if not self.autoRefill then return end
  local def = self.cards[self.attackerIndex]
  if not def then return end
  local player = self.gs and self.gs:getCurrentPlayer()
  if not player then return end
  if handHasDef(player, def.id) then return end
  -- Avoid spawning while a flight of same def is mid-air (optional)
  if self.gs and self.gs.animations then
    for _, a in ipairs(self.gs.animations.queue or {}) do
      if a.type=='card_flight' and a.card and a.card.id == def.id then return end
    end
  end
  self:spawnTestCard()
end

function anim_lab:update(dt)
  if not self.gs then return end
  -- Keep players energized
  for _, p in ipairs(self.gs.players or {}) do p.energy = 99 end
  self:ensureTestCard()
  TunerOverlay.update(dt, 'anim_lab', self)
  self.gs:update(dt)
end

function anim_lab:draw()
  if not self.gs then return end
  Viewport.apply()
  -- Delegate to GameState draw (includes board, hand, animations, impacts)
  self.gs:draw()
  -- Overlay instructional text
  love.graphics.setColor(1,1,1,0.9)
  love.graphics.print("Animation Lab - Using full gameplay pipeline", 20, 14)
  love.graphics.print("Up/Down: select card  |  Space: force spawn copy  |  Tab: switch player  |  C: clear board  |  T: toggle overrides", 20, 32)
  love.graphics.print("Selected: " .. (self.cards[self.attackerIndex] and self.cards[self.attackerIndex].id or 'nil'), 20, 50)
  love.graphics.setColor(1,1,1,1)
  TunerOverlay.draw('anim_lab')
  Viewport.unapply()
end

function anim_lab:keypressed(key)
  if key == 'escape' then
    local menu = require 'src.states.menu'
    Gamestate.switch(menu)
    return
  elseif key == 'up' then
    self.attackerIndex = (self.attackerIndex - 2) % #self.cards + 1
  elseif key == 'down' then
    self.attackerIndex = (self.attackerIndex % #self.cards) + 1
  elseif key == 'space' then
    self:spawnTestCard()
  elseif key == 'tab' then
    if self.gs then
      self.gs.currentPlayer = (self.gs.currentPlayer == 1) and 2 or 1
      self.gs:updateCardVisibility()
      self.gs:refreshLayoutPositions()
    end
  elseif key == 'c' then
    -- Clear all board slots (leave hand as-is)
    if self.gs then
      for _, p in ipairs(self.gs.players or {}) do
        for i, slot in ipairs(p.boardSlots or {}) do slot.card = nil end
      end
    end
  elseif key == 't' then
    Config.ui.useAnimationOverrides = not Config.ui.useAnimationOverrides
  end
  -- Pass through to tuner for save/reset shortcuts
  TunerOverlay.keypressed(key, 'anim_lab', self)
end

function anim_lab:mousepressed(x,y,button)
  local vx, vy = Viewport.toVirtual(x,y)
  if TunerOverlay.mousepressed(vx, vy, button, 'anim_lab', self) then return end
  if not self.gs then return end
  Input:mousepressed(self.gs, vx, vy, button)
end

function anim_lab:mousereleased(x,y,button)
  local vx, vy = Viewport.toVirtual(x,y)
  if TunerOverlay.mousereleased(vx, vy, button) then return end
  if not self.gs then return end
  Input:mousereleased(self.gs, vx, vy, button)
  -- After a successful play, auto-refill may add new copy next update
end

return anim_lab