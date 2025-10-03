local Gamestate = require 'libs.hump.gamestate'
local Card = require 'src.card'
local CardDefs = require 'src.card_definitions'
local AnimationSpecs = require 'src.animation_specs'
local AnimationManager = require 'src.animation_manager'
local CardRenderer = require 'src.card_renderer'
local Config = require 'src.config'
local Viewport = require 'src.viewport'
local TunerOverlay = require 'src.tuner_overlay'

local anim_lab = { }

function anim_lab:init()
  self.animations = AnimationManager.new()
  self.attackerIndex = 1
  self.defenderIndex = 1
  self.cards = {}
  for _, def in ipairs(CardDefs) do
    table.insert(self.cards, def)
  end
  table.sort(self.cards, function(a,b) return a.id < b.id end)
end

function anim_lab:enter()
  self:init()
end

function anim_lab:draw()
  love.graphics.clear(0.08,0.08,0.1,1)
  Viewport.apply()
  love.graphics.setColor(1,1,1,1)
  love.graphics.print("Animation Lab", 20, 18)
  love.graphics.print("(Up/Down) Select Card | (W/S) Select Prop | Space: Play | Esc: Back | F10: Tuner", 20, 40)
  local y = 70
  local attackerId = self.cards[self.attackerIndex].id
  love.graphics.print("Card (Edited): " .. attackerId, 20, y)
  y = y + 20
  love.graphics.print("Prop: " .. (self.cards[self.defenderIndex].id), 20, y)
  y = y + 24
  love.graphics.print("Overrides: " .. tostring(Config.ui.useAnimationOverrides), 20, y)
  y = y + 36
  love.graphics.setColor(0.9,0.9,1,0.85)
  love.graphics.print("Press T to toggle overrides flag | Ctrl+S save anim overrides (in tuner)", 20, y)
  -- Tuner overlay drawn after animations
  Viewport.unapply()
  if self.animations and self.animations.draw then self.animations:draw() end
  -- Draw overlay last so it sits on top
  TunerOverlay.draw('anim_lab')
end

local function buildTempCard(def, x, y)
  local c = {
    id = def.id,
    name = def.name,
    definition = def,
    x = x, y = y,
    w = (Config.layout and Config.layout.cardW) or 128,
    h = (Config.layout and Config.layout.cardH) or 192,
  }
  return c
end

function anim_lab:playOnce()
  if not self.cards[self.attackerIndex] then return end
  local defA = self.cards[self.attackerIndex]
  local defD = self.cards[self.defenderIndex]
  -- Positions: left attacker, right defender
  local w = Viewport.getWidth()
  local h = Viewport.getHeight()
  local leftX = w * 0.25 - ((Config.layout.cardW or 128)/2)
  local rightX = w * 0.65 - ((Config.layout.cardW or 128)/2)
  local midY = h * 0.5 - ((Config.layout.cardH or 192)/2)
  local attacker = buildTempCard(defA, leftX, midY)
  local target = buildTempCard(defD, rightX, midY)
  self.lastAttacker = attacker
  self.lastDefender = target
  local spec = AnimationSpecs.getCardSpec(attacker.id)
  local duration = Config.ui.cardFlightDuration or 0.35
  local overshoot = Config.ui.cardFlightOvershoot or 0
  local arcHeight = (Config.ui.cardFlightCurve == 'arc') and (Config.ui.cardFlightArcHeight or 140) or 0
  local slamStyle = false
  if Config.ui.useAnimationOverrides and spec and spec.flight then
    duration = spec.flight.duration or duration
    overshoot = spec.flight.overshoot or overshoot
    if spec.flight.arcScale and arcHeight > 0 then arcHeight = arcHeight * spec.flight.arcScale end
    if spec.flight.slamStyle then slamStyle = true end
  end
  self.animations:add({
    type='card_flight',
    card = attacker,
    fromX = attacker.x, fromY = attacker.y,
    toX = target.x, toY = target.y,
    duration = duration,
    overshootFactor = overshoot,
    arcHeight = arcHeight,
    slamStyle = slamStyle,
    onComplete = function()
      -- queue impact
      self.animations:add({
        type='card_impact',
        card = attacker,
        duration = Config.ui.cardImpactDuration or 0.28,
        squashScale = Config.ui.cardImpactSquashScale or 0.85,
        flashAlpha = Config.ui.cardImpactFlashAlpha or 0.55,
      })
    end
  })
end

function anim_lab:update(dt)
  if self.animations then self.animations:update(dt) end
  TunerOverlay.update(dt, 'anim_lab', self)
end

function anim_lab:keypressed(key)
  if key == 'escape' then
    local menu = require 'src.states.menu'
    Gamestate.switch(menu)
  elseif key == 'space' then
    self:playOnce()
  elseif key == 'up' then
    self.attackerIndex = (self.attackerIndex - 2) % #self.cards + 1
  elseif key == 'down' then
    self.attackerIndex = (self.attackerIndex % #self.cards) + 1
  elseif key == 'w' then
    self.defenderIndex = (self.defenderIndex - 2) % #self.cards + 1
  elseif key == 's' then
    self.defenderIndex = (self.defenderIndex % #self.cards) + 1
  elseif key == 't' then
    Config.ui.useAnimationOverrides = not Config.ui.useAnimationOverrides
  end
  -- Pass through to tuner overlay (after our handling so toggles work)
  TunerOverlay.keypressed(key, 'anim_lab', self)
  -- Save / reset via overlay shortcuts when open (handled inside overlay)
end

return anim_lab