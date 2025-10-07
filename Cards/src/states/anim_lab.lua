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
  
  -- Create single neutral player for the testing hand area
  local testPlayer = Player{ id=1, maxHandSize=10, maxBoardCards=3 }
  testPlayer.deck = {}
  testPlayer.energy = 99
  
  -- Create dummy second player to maintain GameState structure
  local dummyPlayer = Player{ id=2, maxHandSize=10, maxBoardCards=3 }
  dummyPlayer.deck = {}
  dummyPlayer.energy = 99
  
  self.gs = GameState:newFromDraft({testPlayer, dummyPlayer})
  self.gs.currentPlayer = 1 -- Always use player 1 as the "thrower"
  
  -- Lab flags
  self.autoRefill = true -- auto keep a test copy in current player's hand
  self.showPreview = true -- show selected card preview
end

function anim_lab:enter()
  self:init()
end

-- Place selected card as prop in specific slot (1-6, covering both board sides)
function anim_lab:placeProp(slotNumber)
  if slotNumber < 1 or slotNumber > 6 then return end
  local def = self.cards[self.attackerIndex]
  if not def then return end
  
  -- Determine which player's board (slots 1-3 = player 1, slots 4-6 = player 2)
  local playerIndex = (slotNumber <= 3) and 1 or 2
  local slotIndex = (slotNumber <= 3) and slotNumber or (slotNumber - 3)
  
  local player = self.gs.players[playerIndex]
  local slot = player.boardSlots[slotIndex]
  if not slot then return end
  
  -- Create prop card and place it directly
  local propCard = CardFactory.createCard(def.id)
  propCard.faceUp = true
  slot.card = propCard
  
  -- Position the card
  local x, y = self.gs:getBoardSlotPosition(playerIndex, slotIndex)
  propCard.x, propCard.y = x, y
  propCard.w = (Config.layout and Config.layout.cardW) or 100
  propCard.h = (Config.layout and Config.layout.cardH) or 150
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

-- Ensure a test card copy exists when autoRefill enabled (only if hand is empty)
function anim_lab:ensureTestCard()
  if not self.autoRefill then return end
  local player = self.gs and self.gs:getCurrentPlayer()
  if not player then return end
  
  -- Only auto-spawn if hand is completely empty
  local handEmpty = true
  for _, slot in ipairs(player.slots or {}) do
    if slot.card then
      handEmpty = false
      break
    end
  end
  
  if not handEmpty then return end -- Hand has cards, don't auto-spawn
  
  local def = self.cards[self.attackerIndex]
  if not def then return end
  
  -- Avoid spawning while a flight of same def is mid-air (optional)
  if self.gs and self.gs.animations then
    for _, a in ipairs(self.gs.animations.queue or {}) do
      if a.type=='card_flight' and a.card and a.card.id == def.id then return end
    end
  end
  self:spawnTestCard()
end

-- Print all available combos to console for reference
function anim_lab:printComboList()
  print("\n=== ANIMATION LAB COMBO LIST ===")
  print("7: Quick Jab → Jab-Cross")
  print("8: Attack + Feint → Counterplay")
  print("9: Card + Rally → Wild Swing")
  print("0: Guard Hands → Suplex")
  print("-: Guard Hands → Ground Pound")
  print("=: Attack + Feint → Shadow Step")
  print("[: Card + Rally → Bottle Smash")
  print("W: Show this list")
  print("\nInstructions: Cards are added to hand. Play prerequisite cards to board, then combo card should glow!")
  print("For modifier combos: Play base card + modifier together, then combo card glows.")
  print("================================\n")
end

-- Setup a specific combo for testing
function anim_lab:setupCombo(setupCardId, comboCardId, comboName, attackCardId)
  local player = self.gs and self.gs:getCurrentPlayer()
  if not player then 
    print("No player found")
    return 
  end
  
  print("Animation Lab: Setting up " .. comboName .. " combo test...")
  
  -- Clear existing board cards and hand
  for i, slot in ipairs(player.boardSlots or {}) do 
    slot.card = nil 
  end
  for i, slot in ipairs(player.slots or {}) do 
    slot.card = nil 
  end
  
  -- Reset player state
  player.prevCardId = nil
  
  -- If an attack card is needed (for feint combos), add it first
  if attackCardId then
    local attackCard = CardFactory.createCard(attackCardId)
    if attackCard then
      player:addCard(attackCard)
      print("  → Added " .. (attackCard.definition.name or attackCardId) .. " to hand")
    end
  end
  
  -- Add setup card to hand
  local setupCard = CardFactory.createCard(setupCardId)
  if setupCard then
    player:addCard(setupCard)
    print("  → Added " .. (setupCard.definition.name or setupCardId) .. " to hand")
  end
  
  -- Add combo card to hand
  local comboCard = CardFactory.createCard(comboCardId)
  if comboCard then
    player:addCard(comboCard)
    print("  → Added " .. (comboCard.definition.name or comboCardId) .. " to hand")
    if attackCardId then
      print("  → Play attack + feint together, then combo card should glow!")
    else
      print("  → Play the first card, then the second should glow for combo!")
    end
  end
  
  self.gs:refreshLayoutPositions()
end

-- Handle card selection change
function anim_lab:selectCard(newIndex)
  self.attackerIndex = newIndex
  -- No auto-spawning during selection - let user browse freely
  -- Auto-refill will only happen in update() if hand becomes completely empty
end

function anim_lab:update(dt)
  if not self.gs then return end
  -- Keep players energized
  for _, p in ipairs(self.gs.players or {}) do p.energy = 99 end
  
  -- Ensure we're in play phase for card playing
  if self.gs.phase ~= "play" then
    self.gs.phase = "play"
  end
  
  -- Check for auto-refill (only when hand is completely empty)
  -- Temporarily disabled for debugging: self:ensureTestCard()
  TunerOverlay.update(dt, 'anim_lab', self)
  
  -- Update input for drag behavior (tension calculation, etc.)
  Input:update(self.gs, dt)
  
  self.gs:update(dt)
  
  -- FORCE: Keep player 1 active in animation lab to see knockback effects
  self.gs.currentPlayer = 1
end

function anim_lab:draw()
  if not self.gs then return end
  Viewport.apply()
  
  -- Custom draw without player info HUD (cleaner for lab)
  self:drawGameWithoutHUD()
  
  -- Draw info panels
  self:drawInfoPanels()
  
  TunerOverlay.draw('anim_lab')
  Viewport.unapply()
end

-- Draw game elements without the player info HUD
function anim_lab:drawGameWithoutHUD()
  self.gs:refreshLayoutPositions()
  local r, g, b = self.gs:getTurnBackgroundColor()
  love.graphics.clear(r, g, b, 1)
  
  local layout = self.gs:getLayout()
  local screenW = Viewport.getWidth()
  
  local BoardRenderer = require 'src.renderers.board_renderer'
  local ResolveRenderer = require 'src.renderers.resolve_renderer'
  
  -- Draw board
  BoardRenderer.draw(self.gs, layout)
  
  -- Draw deck and discard stacks
  if self.gs.deckStack and self.gs.deckStack.draw then
    self.gs.deckStack:draw()
  end
  if self.gs.discardStack and self.gs.discardStack.draw then
    self.gs.discardStack:draw()
  end
  
  -- Draw hands (without player info HUD)
  for index, player in ipairs(self.gs.players or {}) do
    local isCurrent = (index == self.gs.currentPlayer)
    player:drawHand(isCurrent, self.gs)
  end
  
  -- Draw resolve log but skip the player info HUD parts
  ResolveRenderer.draw(self.gs, layout, screenW)
  
  -- Draw drag arrow (copied from GameState:draw for authentic gameplay feel)
  if self.gs.draggingCard then
    local card = self.gs.draggingCard
    if card.dragCursorX and card.dragCursorY then
      love.graphics.setColor(0.95, 0.8, 0.2, 0.85)
      -- Anchor arrow start to the card's current (pressed) visual position, not the original pick-up center
      local sx = (card.x or 0) + (card.w or 0)/2
      local sy = (card.y or 0) + (card.h or 0)/2
      local ex, ey = card.dragCursorX, card.dragCursorY
      local dx, dy = ex - sx, ey - sy
      local dist = math.sqrt(dx*dx + dy*dy)
      local thick = math.min(16, math.max(3, dist * 0.04))
      love.graphics.setLineWidth(thick)
      love.graphics.line(sx, sy, ex, ey)
      love.graphics.setLineWidth(1)
      local angle = math.atan2(dy, dx)
      local ah = 22
      local aw = 14
      local baseX = ex - math.cos(angle) * ah
      local baseY = ey - math.sin(angle) * ah
      local leftAngle = angle + 2.4
      local rightAngle = angle - 2.4
      local lx = baseX + math.cos(leftAngle) * aw
      local ly = baseY + math.sin(leftAngle) * aw
      local rx = baseX + math.cos(rightAngle) * aw
      local ry = baseY + math.sin(rightAngle) * aw
      love.graphics.polygon("fill", ex, ey, lx, ly, rx, ry)
      love.graphics.setColor(1,1,1,1)
    end
  end
  
  -- Draw animations on top
  if self.gs.animations and self.gs.animations.draw then
    local ImpactFX = require 'src.impact_fx'
    local pushed = ImpactFX.applyShakeTransform(self.gs)
    self.gs.animations:draw()
    ImpactFX.drawDust(self.gs)
    if pushed then love.graphics.pop() end
  end
end

function anim_lab:drawInfoPanels()
  local screenW = Viewport.getWidth()
  love.graphics.setColor(0,0,0,0.8)
  love.graphics.rectangle('fill', 10, 10, 550, 160, 8, 8)
  love.graphics.setColor(1,1,1,1)
  love.graphics.rectangle('line', 10, 10, 550, 160, 8, 8)
  
  -- Instructions
  love.graphics.setColor(1,1,0.8,1)
  love.graphics.print("Animation Lab - Bowling Ball Style Testing", 20, 20)
  love.graphics.setColor(0.9,0.9,0.9,1)
  love.graphics.print("Up/Down: select card  |  Space: spawn test card  |  1-6: place prop in slot", 20, 38)
  love.graphics.print("Drag test card to any slot to see animation  |  C: clear all props", 20, 54)
  love.graphics.print("A: toggle auto-refill  |  P: toggle preview  |  T: toggle overrides  |  R: resolve phase", 20, 70)
  love.graphics.print("7: Quick Jab → Jab-Cross  |  8: Feint → Counterplay  |  9: Rally → Wild Swing", 20, 86)
  love.graphics.print("0: Guard → Suplex  |  -/=: More combos  |  W: show all combos", 20, 102)
  
  -- Animation tweaking workflow
  love.graphics.setColor(1,0.8,0.8,1)
  love.graphics.print("F10: open tuner  |  Shift+S: save custom animation  |  Shift+R: reset card", 20, 118)
  
  -- Selected card info
  local def = self.cards[self.attackerIndex]
  love.graphics.setColor(1,1,1,1)
  love.graphics.print("Selected Card: " .. (def and def.id or 'nil'), 20, 124)
  love.graphics.print("Auto-refill: " .. (self.autoRefill and 'ON (when hand empty)' or 'OFF'), 280, 124)
  love.graphics.print("Overrides: " .. (Config.ui.useAnimationOverrides and 'ON' or 'OFF'), 280, 140)
  
  -- Game phase status for testing
  local phase = self.gs and self.gs.phase or "none"
  love.graphics.setColor(0.8, 1, 0.8, 1)
  love.graphics.print("Game Phase: " .. phase, 20, 140)
  
  -- Slot layout guide
  love.graphics.setColor(0,0,0,0.8)
  love.graphics.rectangle('fill', screenW - 200, 10, 190, 100, 8, 8)
  love.graphics.setColor(1,1,1,1)
  love.graphics.rectangle('line', screenW - 200, 10, 190, 100, 8, 8)
  
  love.graphics.setColor(1,1,0.8,1)
  love.graphics.print("Prop Slots (Number Keys)", screenW - 190, 20)
  love.graphics.setColor(0.9,0.9,0.9,1)
  love.graphics.print("Top Row:    1   2   3", screenW - 190, 40)
  love.graphics.print("Bottom Row: 4   5   6", screenW - 190, 58)
  love.graphics.print("Drag from hand to test!", screenW - 190, 80)
  
  -- Card preview panel (if enabled and card selected)
  if self.showPreview and def then
    self:drawCardPreview(def)
  end
end

function anim_lab:drawCardPreview(def)
  local screenW = Viewport.getWidth()
  local screenH = Viewport.getHeight()
  local panelW, panelH = 200, 280
  local panelX = screenW - panelW - 20
  local panelY = screenH - panelH - 20
  
  -- Panel background
  love.graphics.setColor(0,0,0,0.9)
  love.graphics.rectangle('fill', panelX, panelY, panelW, panelH, 8, 8)
  love.graphics.setColor(1,1,1,1)
  love.graphics.rectangle('line', panelX, panelY, panelW, panelH, 8, 8)
  
  -- Create temporary card for preview
  local CardFactory = require 'src.card_factory'
  local CardRenderer = require 'src.card_renderer'
  local previewCard = CardFactory.createCard(def.id)
  previewCard.x = panelX + 10
  previewCard.y = panelY + 10
  previewCard.w = 120  -- Increased from 100 for better token visibility
  previewCard.h = 180  -- Increased from 150 to maintain aspect ratio
  previewCard.faceUp = true
  -- Removed _suppressShadow to allow texture cache usage
  
  -- Draw card
  CardRenderer.draw(previewCard)
  
  -- Animation spec info
  local AnimSpecs = require 'src.animation_specs'
  local spec = AnimSpecs.getCardSpec(def.id)
  love.graphics.setColor(1,1,0.8,1)
  love.graphics.print("Animation Info:", panelX + 120, panelY + 15)
  love.graphics.setColor(0.9,0.9,0.9,1)
  local y = panelY + 35
  if spec and spec.flight then
    love.graphics.print("Duration: " .. (spec.flight.duration or 'default'), panelX + 120, y)
    y = y + 15
    love.graphics.print("Overshoot: " .. (spec.flight.overshoot or 'default'), panelX + 120, y)
    y = y + 15
    love.graphics.print("Arc Scale: " .. (spec.flight.arcScale or 'default'), panelX + 120, y)
    y = y + 15
    love.graphics.print("Profile: " .. (spec.flight.profile or 'default'), panelX + 120, y)
    y = y + 15
    if spec.flight.verticalMode then
      love.graphics.print("V-Mode: " .. spec.flight.verticalMode, panelX + 120, y)
      y = y + 15
    end
  else
    love.graphics.print("Using defaults", panelX + 120, y)
  end
end

function anim_lab:keypressed(key)
  if key == 'escape' then
    local menu = require 'src.states.menu'
    Gamestate.switch(menu)
    return
  elseif key == 'up' then
    local newIndex = (self.attackerIndex - 2) % #self.cards + 1
    self:selectCard(newIndex)
  elseif key == 'down' then
    local newIndex = (self.attackerIndex % #self.cards) + 1
    self:selectCard(newIndex)
  elseif key == 'space' then
    self:spawnTestCard()
  elseif key == 'c' then
    -- Clear all prop slots
    if self.gs then
      for _, p in ipairs(self.gs.players or {}) do
        for i, slot in ipairs(p.boardSlots or {}) do slot.card = nil end
      end
    end
  elseif key == 'a' then
    self.autoRefill = not self.autoRefill
  elseif key == 'p' then
    self.showPreview = not self.showPreview
  elseif key == 't' then
    Config.ui.useAnimationOverrides = not Config.ui.useAnimationOverrides
  elseif key == 'r' then
    -- Manual resolve trigger for testing card interactions
    if self.gs and self.gs.phase ~= "resolve" then
      print("Animation Lab: Starting manual resolve phase...")
      local Resolve = require "src.logic.resolve"
      Resolve.startResolve(self.gs)
    else
      print("Animation Lab: Already in resolve phase or no gamestate")
    end
  elseif key == '7' then
    self:setupCombo("punch", "jab_cross", "Quick Jab → Jab-Cross")
  elseif key == '8' then
    self:setupCombo("feint", "counterplay", "Attack + Feint → Counterplay", "punch")
  elseif key == '9' then
    self:setupCombo("rally", "wild_swing", "Card + Rally → Wild Swing", "punch")
  elseif key == '0' then
    self:setupCombo("block", "suplex", "Guard Hands → Suplex")
  elseif key == '-' then
    self:setupCombo("block", "ground_pound", "Guard Hands → Ground Pound")
  elseif key == '=' then
    self:setupCombo("feint", "shadow_step", "Attack + Feint → Shadow Step", "punch")
  elseif key == '[' then
    self:setupCombo("rally", "bottle_smash", "Card + Rally → Bottle Smash", "punch")
  elseif key == 'w' then
    self:printComboList()
  -- Number keys for quick prop placement
  elseif key == '1' then
    self:placeProp(1)
  elseif key == '2' then
    self:placeProp(2)
  elseif key == '3' then
    self:placeProp(3)
  elseif key == '4' then
    self:placeProp(4)
  elseif key == '5' then
    self:placeProp(5)
  elseif key == '6' then
    self:placeProp(6)
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
  
  -- Store current player before input handling
  local originalPlayer = self.gs.currentPlayer
  
  -- Debug: Check if we're dropping a card
  if self.gs.draggingCard then
    print("Animation Lab: Dropping card", self.gs.draggingCard.id, "at", vx, vy)
    print("  Phase:", self.gs.phase or "unknown")
    print("  Current player:", self.gs.currentPlayer)
    print("  Player energy:", self.gs:getCurrentPlayer() and self.gs:getCurrentPlayer().energy or "unknown")
    print("  Card cost:", self.gs.draggingCard.definition and self.gs.draggingCard.definition.cost or "unknown")
    
    -- Check what board slots exist and their positions
    local player = self.gs:getCurrentPlayer()
    if player and player.boardSlots then
      local cardW, cardH = self.gs:getCardDimensions()
      print("  Card dimensions:", cardW, "x", cardH)
      for i, slot in ipairs(player.boardSlots) do
        local x, y = self.gs:getBoardSlotPosition(self.gs.currentPlayer, i)
        local occupied = slot.card and "occupied" or "empty"
        print("  Board slot", i, "at", x, y, "to", x+cardW, y+cardH, occupied)
      end
    end
  end
  
  Input:mousereleased(self.gs, vx, vy, button)
  
  -- Debug: Check if card was successfully played
  if self.gs.draggingCard then
    print("  Card still dragging - drop failed")
  else
    print("  Card no longer dragging - likely played successfully")
    -- Check where the cards actually are now
    local player = self.gs:getCurrentPlayer()
    if player then
      local handCount = 0
      local boardCount = 0
      for _, slot in ipairs(player.slots or {}) do
        if slot.card then handCount = handCount + 1 end
      end
      for _, slot in ipairs(player.boardSlots or {}) do
        if slot.card then boardCount = boardCount + 1 end
      end
      print("  Hand cards:", handCount, "Board cards:", boardCount)
    end
  end
  
  -- Force current player back to original after input (prevents turn switching in lab)
  self.gs.currentPlayer = originalPlayer
  
  -- After a successful play, auto-refill may add new copy next update
end

return anim_lab