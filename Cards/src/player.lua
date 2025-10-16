local Class = require "libs.hump.class"

local Player = Class{}
local Viewport = require "src.viewport"
local FighterCatalog = require "src.fighter_definitions"
local HoverUtils = require "src.ui.hover_utils"

local DEBUG_PLAYER_LOG = false

local function log(...)
    if DEBUG_PLAYER_LOG then
        print(...)
    end
end

function Player:init(args)
    self.id = args.id
    self.maxHandSize = args.maxHandSize or 5
    self.maxBoardCards = args.maxBoardCards or 3
    self.deck = {}
    self.slots = {}
    self.boardSlots = {}
    self.energy = 0
    self.maxEnergy = 0
    self.comboHighlightEnabled = true  -- Enable combo highlighting
    
    -- Initialize hand slots
    for i = 1, self.maxHandSize do
        self.slots[i] = { card = nil }
    end
    
    -- Initialize board slots
    for i = 1, self.maxBoardCards do
        self.boardSlots[i] = { card = nil }
    end
    
    -- Set fighter if provided
    if args.fighter then
        self.fighter = args.fighter
        self.fighterId = args.fighterId or (args.fighter.id)
    elseif args.fighterId then
        self.fighterId = args.fighterId
        self:setFighter(args.fighterId)
    end
end

-- Update combo glow state for all cards in hand
function Player:updateComboStates(gs)
    if not self.comboHighlightEnabled then return end
    
    log("[COMBO] Player", self.id, "updateComboStates - prevCardId:", self.prevCardId)
    
    for i, slot in ipairs(self.slots) do
        local card = slot.card
        if card then
            local cardName = card.definition and card.definition.name or "unknown"
            local canCombo = self:canPlayCombo(card.definition, gs)
            local dragging = card.dragging
            
            log("[COMBO] Slot", i, cardName, "- canCombo:", canCombo, "dragging:", dragging)
            
            -- Only show combo glow when card is in hand (not dragging/on board)
            if not card.dragging and self:canPlayCombo(card.definition, gs) then
                log("[COMBO] Setting glow=true for", cardName, "prevCardId:", self.prevCardId)
                card.comboGlow = true
            else
                if card.comboGlow then -- Only print when clearing
                    log("[COMBO] Clearing glow for", cardName, "dragging:", card.dragging)
                end
                card.comboGlow = false
            end
        end
    end
end

function Player:setFighter(fighter)
    local resolved = fighter
    if type(fighter) == "string" then
        resolved = FighterCatalog.byId[fighter]
    end
    self.fighter = resolved or nil
    if resolved then
        self.fighterId = resolved.id
        -- Add starter, signature, combo, and ultimate cards to deck
        local factory = require "src.card_factory"
        self.deck = {}
        local function addCards(cardIds)
            if cardIds then
                for _, id in ipairs(cardIds) do
                    table.insert(self.deck, factory.createCard(id))
                end
            end
        end
        addCards(resolved.starterCards)
        addCards(resolved.signatureCards)
        if resolved.comboCards then
            addCards(resolved.comboCards)
        end
        if resolved.ultimate then
            table.insert(self.deck, factory.createCard(resolved.ultimate))
        end
        self.prevCardId = nil
        self.lastCardId = nil
        self.roundPunchCount = 0
    else
        self.fighterId = type(fighter) == "string" and fighter or nil
    end
end
-- Combo and ultimate logic
function Player:canPlayCombo(card, gs)
    if not card or not card.combo then
        return false
    end
    
    -- ANIMATION LAB: Check all players' prevCardId for combo chains
    -- This enables testing sequences like "Player1: Quick Jab → Player2: Corner Rally → Player1: Wild Swing"
    -- while maintaining game rule integrity in normal play
    if gs and gs.isAnimationLab then
        if gs.players then
            for _, player in ipairs(gs.players) do
                if player.prevCardId == card.combo.after then
                    return true
                end
            end
        end
        return false
    end
    
    -- NORMAL GAMES: Only check current player's prevCardId (enforces per-player combos)
    return self.prevCardId ~= nil and self.prevCardId == card.combo.after
end

function Player:canPlayUltimate(card)
    return card.ultimate == true
end

function Player:applyComboBonus(card, gs)
    if not card or not card.combo then
        return false
    end
    if card.comboApplied or not self:canPlayCombo(card, gs) then
        return false
    end

    local applied = false
    if card.combo.bonus then
        card.comboVariance = card.comboVariance or {}
        for k, v in pairs(card.combo.bonus) do
            if type(v) == "number" then
                card.comboVariance[k] = (card.comboVariance[k] or 0) + v
                applied = true
            end
        end
    end
    if applied then
        card.comboApplied = true
    end
    return applied
end

function Player:getFighter()
    return self.fighter
end

function Player:getFighterColor()
    local f = self.fighter
    return f and f.color or nil
end

function Player:getBoardPassiveMods()
    local f = self.fighter
    local passives = f and f.passives or nil
    return passives and passives.boardSlot or nil
end

function Player:getDrawBonus(trigger)
    local f = self.fighter
    local passives = f and f.passives or nil
    local draw = passives and passives.draw or nil
    if not draw then
        return 0
    end
    return draw[trigger] or draw.default or 0
end

function Player:isCardFavored(def)
    local fighter = self.fighter
    if not fighter or not fighter.favoredTags then
        return false
    end
    local definitionTags = def and def.tags
    if not definitionTags then
        return false
    end
    for _, wanted in ipairs(fighter.favoredTags) do
        for _, tag in ipairs(definitionTags) do
            if tag == wanted then
                return true
            end
        end
    end
    return false
end
function Player:getHand()
    local cards = {}
    for _, slot in ipairs(self.slots) do
        if slot.card then
            cards[#cards + 1] = slot.card
        end
    end
    return cards
end

function Player:addCard(card)
    for i, slot in ipairs(self.slots) do
        if not slot.card then
            card.slotIndex = i
            card.owner = self
            card.statVariance = nil
            slot.card = card
            return true
        end
    end
    log("Hand full for Player " .. self.id)
    return false
end

function Player:removeCard(card)
    local oldSlot = card.slotIndex
    if oldSlot and self.slots[oldSlot] and self.slots[oldSlot].card == card then
        self.slots[oldSlot].card = nil
    end

    log("Removing card", card.name, "from slot", oldSlot, "Player", self.id)
    card.statVariance = nil
    card.owner = nil
    card.slotIndex = nil

    self:compactHand()
end

function Player:compactHand()
    local target = 1
    for i = 1, self.maxHandSize do
        local slot = self.slots[i]
        local card = slot.card
        if card then
            if i ~= target then
                self.slots[i].card = nil
                local targetSlot = self.slots[target]
                targetSlot.card = card
                card.slotIndex = target
                card.x, card.y = targetSlot.x, targetSlot.y
            end
            target = target + 1
        end
    end
end

function Player:compactHand(gs)
    print("[DEBUG] INSTANT compactHand called! This will override any animated positions")
    
    -- Remove gaps in hand slots and update card positions
    local newSlots = {}
    local idx = 1
    for i, slot in ipairs(self.slots) do
        if slot.card then
            slot.card.slotIndex = idx
            local x, y = gs:getHandSlotPosition(idx, self)
            print("[DEBUG] INSTANT compactHand setting card", slot.card.id or "unknown", "to position", x, y)
            slot.card.x = x
            slot.card.y = y
            newSlots[idx] = { card = slot.card }
            idx = idx + 1
        end
    end
    -- Fill remaining slots
    for i = idx, #self.slots do
        newSlots[i] = { card = nil }
    end
    self.slots = newSlots
end

-- Smooth animated hand compaction for better UX during card flight
function Player:animatedCompactHand(gs)
    if not gs then return end
    
    local activeLayout = gs:getLayout()
    local duration = activeLayout.handCompactDuration or 0.35
    local easingType = activeLayout.handCompactEasing or "easeOutCubic"
    
    print("[DEBUG] Layout values - handCompactDuration:", activeLayout.handCompactDuration, "handCompactEasing:", activeLayout.handCompactEasing)
    print("[DEBUG] Resolved values - duration:", duration, "easing:", easingType)
    
    -- First, capture current positions of all remaining cards before any slot changes
    local cardsToAnimate = {}
    local remainingCards = {}
    
    for i, slot in ipairs(self.slots) do
        if slot.card then
            table.insert(remainingCards, {
                card = slot.card,
                originalSlotIndex = slot.card.slotIndex,
                currentX = slot.card.x,
                currentY = slot.card.y
            })
        end
    end
    
    print("[DEBUG] Hand compaction - duration:", duration, "easing:", easingType, "remaining cards:", #remainingCards)
    
    -- Now calculate new slot layout and positions
    local newSlots = {}
    for idx, cardInfo in ipairs(remainingCards) do
        local card = cardInfo.card
        local newSlotIndex = idx
        local newX, newY = gs:getHandSlotPosition(newSlotIndex, self)
        
        print("[DEBUG] Card", card.id or "unknown", "- current pos:", cardInfo.currentX, cardInfo.currentY, "new pos:", newX, newY, "slot:", cardInfo.originalSlotIndex, "->", newSlotIndex)
        
        -- Check if card needs to animate (position or slot changed)
        if cardInfo.originalSlotIndex ~= newSlotIndex or math.abs(cardInfo.currentX - newX) > 1 or math.abs(cardInfo.currentY - newY) > 1 then
            print("[DEBUG] Card needs animation - position or slot changed")
            table.insert(cardsToAnimate, {
                card = card,
                oldSlotIndex = cardInfo.originalSlotIndex,
                newSlotIndex = newSlotIndex,
                startX = cardInfo.currentX,
                startY = cardInfo.currentY,
                targetX = newX,
                targetY = newY
            })
        else
            print("[DEBUG] Card", card.id or "unknown", "doesn't need animation - position unchanged")
        end
        
        -- Update card slot index and create new slot
        card.slotIndex = newSlotIndex
        newSlots[newSlotIndex] = { card = card }
    end
    
    -- Fill remaining slots with empty slots
    for i = #remainingCards + 1, #self.slots do
        newSlots[i] = { card = nil }
    end
    self.slots = newSlots
    
    -- If no cards need animation, we're done
    if #cardsToAnimate == 0 then 
        print("[DEBUG] No cards need animation")
        return 
    end

    print("[DEBUG] Starting animation for", #cardsToAnimate, "cards")
    
    -- Use the gamestate's animation timer to ensure updates
    local timer = gs.animations and gs.animations.timer
    if not timer then
        -- Fallback: instant snap if no timer available
        print("[DEBUG] No animation timer available - using instant positioning")
        for _, animData in ipairs(cardsToAnimate) do
            animData.card.x = animData.targetX
            animData.card.y = animData.targetY
        end
        return
    end
    
    print("[DEBUG] Using timer instance:", timer, "type:", type(timer))
    
    print("[DEBUG] Hand compaction - duration:", duration, "easing:", easingType, "cards to animate:", #cardsToAnimate)
    print("[DEBUG] Animation start time:", love.timer.getTime())
    
    -- Convert easing type to HUMP Timer format
    local humpEasing = easingType
    if easingType == "easeOutCubic" then humpEasing = "in-out-cubic"
    elseif easingType == "easeOutQuad" then humpEasing = "in-out-quad"
    elseif easingType == "easeOutQuart" then humpEasing = "in-out-quart"
    elseif easingType == "linear" then humpEasing = "linear"
    else humpEasing = "in-out-cubic" -- Default fallback
    end
    
    for _, animData in ipairs(cardsToAnimate) do
        local card = animData.card
        local startX, startY = animData.startX, animData.startY
        local targetX, targetY = animData.targetX, animData.targetY
        
        -- Initialize animX/animY from current positions to start animation
        card.animX = startX
        card.animY = startY
        
        print("[DEBUG] Starting timer animation for card", card.id or "unknown", "from", startX, startY, "to", targetX, targetY, "easing:", humpEasing)
        print("[DEBUG] Set initial animX =", card.animX, "animY =", card.animY)
        
        local startTime = love.timer.getTime()
        print("[DEBUG] About to call timer:tween with duration:", duration, "easing:", humpEasing)
        print("[DEBUG] Timer object methods:", timer.tween and "has tween" or "NO tween method")
        
        local tweenResult = timer:tween(duration, card, {animX = targetX, animY = targetY}, humpEasing, function()
            local endTime = love.timer.getTime()
            local actualDuration = endTime - startTime
            print("[DEBUG] Hand compaction animation completed for card", card.id or "unknown", "- actual duration:", string.format("%.2f", actualDuration), "expected:", duration)
            
            -- Clear animX/animY when animation completes and update base positions
            card.animX = nil
            card.animY = nil
            card.x = targetX
            card.y = targetY
            print("[DEBUG] Cleared animX/animY and set final x =", card.x, "y =", card.y)
        end)
        
        print("[DEBUG] timer:tween call completed, result:", tweenResult, "animation should be running")
    end
end

function Player:snapCard(card, gs)
    if not card.slotIndex then
        return
    end

    -- Check if there's an ongoing hand compaction animation
    -- If so, don't override the animated positions
    if self.handCompactionInProgress then
        if Config and Config.debug then
            print("[DEBUG] snapCard: Skipping position override due to ongoing hand compaction animation")
        end
        -- Still set the slot assignment and clear variance
        card.statVariance = nil
        self.slots[card.slotIndex].card = card
        return
    end

    local x, y = gs:getHandSlotPosition(card.slotIndex, self)
    card.x = x
    card.y = y
    card.statVariance = nil
    self.slots[card.slotIndex].card = card
end

function Player:drawCard()
    if not self.deck or #self.deck == 0 then
        log("No cards left in deck")
        return nil
    end

    log("Drawing card for player " .. self.id)

    local card = table.remove(self.deck)
    if not self:addCard(card) then
        log("Hand full, cannot draw")
        table.insert(self.deck, card)
        return nil
    end

    return card
end

function Player:drawHand(isCurrent, gs)
    if not isCurrent then
        return
    end

    local baseLayout = gs and gs:getLayout() or {}
    local cardW = baseLayout.cardW or 100
    local cardH = baseLayout.cardH or 150
    local bottomMargin = baseLayout.handBottomMargin or 20

    local startX, spacing, handY, activeLayout = 150, (baseLayout.slotSpacing or 110), 0, baseLayout
    if gs then
        startX, _, activeLayout, _, spacing = gs:getHandMetrics(self)
        spacing = spacing or activeLayout.slotSpacing or cardW
        handY = gs:getHandY()
        cardW = activeLayout.cardW or cardW
        cardH = activeLayout.cardH or cardH
        bottomMargin = activeLayout.handBottomMargin or bottomMargin
    else
        handY = Viewport.getHeight() - cardH - bottomMargin
    end

    local liftAmount = activeLayout.handHoverLift or math.floor(cardH * 0.15)
    local mx, my
    if gs then
        local rawX, rawY = love.mouse.getPosition()
        mx, my = Viewport.toVirtual(rawX, rawY)
    end

    for i, slot in ipairs(self.slots) do
        local x = startX + (i - 1) * spacing
        local y = handY
        slot.x, slot.y = x, y

        local card = slot.card
        if card then
            if gs and card == gs.draggingCard then
                -- Dragging: keep hover state active (for glow/scale) but push card downward (pressed) instead of lifting
                card.handHoverTarget = 1
                local tension = card.dragTension or 0
                -- Base press: 40% of lift range plus up to 60% more with tension
                local press = math.floor((liftAmount * 0.4) + tension * (liftAmount * 0.6))
                card.x = x
                card.y = y + press
                card.w = cardW
                card.h = cardH
            else
                local lift = liftAmount * (card.handHoverAmount or 0)
                card.x = x
                card.y = y - lift
                card.w = cardW
                card.h = cardH
            end
    end
    end -- end for each hand slot

    local hoveredCard
    -- Suppress hover highlight while a card is being dragged for clearer focus
    if gs and mx and my and not gs.draggingCard then
        local useScaled = activeLayout.handHoverHitScaled == true
        local hoverScale = (activeLayout.handHoverScale or 0.06)
        for idx = #self.slots, 1, -1 do
            local card = self.slots[idx].card
            -- Exclude dragging cards AND cards that are currently animating from hover detection
            -- This prevents hover highlights from persisting on cards during flight animations
            if card and not card.dragging and not card._unifiedAnimationActive then
                if useScaled then
                    local amt = card.handHoverAmount or 0
                    if HoverUtils.hitScaled(mx, my, card.x, card.y, cardW, cardH, amt, hoverScale) then
                        hoveredCard = card
                        break
                    end
                else
                    if card:isHovered(mx, my) then
                        hoveredCard = card
                        break
                    end
                end
            end
        end
    end

    for _, slot in ipairs(self.slots) do
        local card = slot.card
        if card and card ~= gs.draggingCard then
            if gs and card == hoveredCard and not card.dragging then
                card.handHoverTarget = 1
            else
                card.handHoverTarget = 0
            end

            -- Draw non-hovered cards (topmost hovered is drawn later)
            if card ~= hoveredCard then
                local CardRenderer = require "src.card_renderer"
                local amount = card.handHoverAmount or 0
                local hoverScale = (activeLayout.handHoverScale or 0.06)
                
                -- Preserve original animated position
                local originalX, originalY, originalW, originalH = card.x, card.y, card.w, card.h
                
                local dx, dy, dw, dh = HoverUtils.scaledRect(card.x, card.y, cardW, cardH, amount, hoverScale)
                card.w, card.h = dw, dh
                card.x, card.y = dx, dy
                CardRenderer.draw(card)
                
                -- Restore original animated position
                card.x, card.y, card.w, card.h = originalX, originalY, originalW, originalH
            end
        end
    end

    -- Draw the dragging card (preserving hover scale) above the rest but below hoveredCard (if different)
    if gs and gs.draggingCard and gs.draggingCard.owner == self then
        local dragCard = gs.draggingCard
        local CardRenderer = require "src.card_renderer"
        local amount = dragCard.handHoverAmount or 0
        local hoverScale = (activeLayout.handHoverScale or 0.06)
        local dx, dy, dw, dh = HoverUtils.scaledRect(dragCard.x, dragCard.y, cardW, cardH, amount, hoverScale)
        -- Highlight backdrop before scaling outline
        love.graphics.setColor(1, 1, 0.3, 0.20 + 0.35 * amount)
        love.graphics.rectangle("fill", dx - 8, dy - 8, dw + 16, dh + 16, 14, 14)
        love.graphics.setColor(1, 1, 0.4, 0.85)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", dx - 8, dy - 8, dw + 16, dh + 16, 14, 14)
        love.graphics.setLineWidth(1)
        
        -- Preserve original position
        local originalX, originalY, originalW, originalH = dragCard.x, dragCard.y, dragCard.w, dragCard.h
        
        dragCard.w, dragCard.h = dw, dh
        dragCard.x, dragCard.y = dx, dy
        love.graphics.setColor(1,1,1,1)
        CardRenderer.draw(dragCard)
        
        -- Restore original position
        dragCard.x, dragCard.y, dragCard.w, dragCard.h = originalX, originalY, originalW, originalH
    end

    if hoveredCard and (not gs or (hoveredCard ~= gs.draggingCard)) then
        -- Ensure fully visible when hand is peeked off-screen: add extra lift if needed
        local vh = Viewport.getHeight()
        local baseLayout = gs and gs:getLayout() or {}
        local cardW = baseLayout.cardW or 100
        local cardH = baseLayout.cardH or 150
        local margin = 4
        local hoverScale = (baseLayout.handHoverScale or 0.06)
        local amount = hoveredCard.handHoverAmount or 0
        local drawX, drawY, newW, newH = HoverUtils.scaledRect(hoveredCard.x, hoveredCard.y, cardW, cardH, amount, hoverScale)
        local bottomEdge = drawY + newH
        local hidden = math.max(0, bottomEdge - (vh - margin))
        if hidden > 0 then
            drawY = drawY - hidden
        end
        
        -- Preserve original animated position
        local originalX, originalY, originalW, originalH = hoveredCard.x, hoveredCard.y, hoveredCard.w, hoveredCard.h
        
        hoveredCard.x = drawX
        hoveredCard.y = drawY
        hoveredCard.w = newW
        hoveredCard.h = newH

        -- Soft shadow behind hovered card (drawn before the card)
        HoverUtils.drawShadow(drawX, drawY, newW, newH, amount)

        local CardRenderer = require "src.card_renderer"
        CardRenderer.draw(hoveredCard)
        
        -- Restore original animated position
        hoveredCard.x, hoveredCard.y, hoveredCard.w, hoveredCard.h = originalX, originalY, originalW, originalH
    end

    -- Animation overlay moved to src/renderers/animation_overlay.lua and is drawn globally
    -- from GameState:draw() to avoid duplication and ensure consistent ordering.

    love.graphics.setColor(1, 1, 1, 1)
end

-- Check if a card is currently in hand slots
function Player:isCardInHand(card)
    if not self.slots or not card then return false end
    for _, slot in ipairs(self.slots) do
        if slot.card == card then
            return true
        end
    end
    return false
end

-- Smoothly tween hand hover amount toward target for each card
function Player:updateHandHover(gs, dt, isCurrentPlayer)
    if not gs or not self.slots then return end
    local layout = gs:getLayout() or {}
    
    -- In animation lab, always update combo states (not just for current player)
    -- This allows proper combo detection when cards are played by different players
    local isAnimLab = gs and gs.isAnimationLab
    if isCurrentPlayer or isAnimLab then
        self:updateComboStates(gs)
    end
    
    -- Use highlight utils for consistent hover animation
    local HighlightUtils = require 'src.ui.hover_utils'
    local inSpeed = layout.handHoverInSpeed or layout.handHoverSpeed or 12
    local outSpeed = layout.handHoverOutSpeed or layout.handHoverSpeed or 12
    if (inSpeed <= 0 and outSpeed <= 0) then return end
    for _, slot in ipairs(self.slots) do
        local card = slot.card
        -- Don't update hover animations for cards that are currently flying
        if card and not card._unifiedAnimationActive then
            local target = card.handHoverTarget or 0
            HighlightUtils.updateHoverAmount(card, target, dt)
        end
    end
end

return Player
