local Class = require 'libs.HUMP.class'
local Actions = Class{}
local Config = require "src.config"

local function dprint(...)
    if Config and Config.debug then
        print(...)
    end
end

-- Shared prevalidation for playing a card from hand (no slot mutation)
function Actions.prevalidatePlayCard(self, card, slotIndex)
    local player = card and card.owner
    if not player or not slotIndex then
        dprint("[prevalidatePlayCard] Invalid player or slotIndex")
        return false, "invalid"
    end
    if self.phase ~= "play" then
        dprint("[prevalidatePlayCard] Not in play phase")
        return false, "wrong_phase"
    end
    local slot = player.boardSlots and player.boardSlots[slotIndex]
    if not slot or slot.card or slot._incoming then
        dprint("[prevalidatePlayCard] Invalid slot or occupied")
        return false, "slot_full"
    end
    local definition = card.definition or {}
    local effectId = definition.effect

    if effectId == "require_2_punches" then
        local punches = player.roundPunchCount or 0
        if punches < 2 then
            self:addLog("Haymaker requires two punches this round")
            player:snapCard(card, self)
            player:compactHand(self)
            return false, "requirement"
        end
    end
    if Config.rules.energyEnabled ~= false then
        local baseCost = definition.cost or 0
        local cost = self:getEffectiveCardCost(player, card)
        local energy = player.energy or 0
        if cost > energy then
            dprint(string.format("[prevalidatePlayCard] Not enough energy: cost=%d, energy=%d", cost, energy))
            self:addLog("Not enough energy")
            player:snapCard(card, self)
            player:compactHand(self)
            return false, "energy"
        end
        local discount = baseCost - cost
        if discount and discount > 0 then
            local HudRenderer = require "src.renderers.hud_renderer"
            HudRenderer.showToast(string.format("Favored: -%d energy", discount))
        end
        player.energy = energy - cost
        if effectId == "double_attack_one_round" then
            player.energy = 0
        end
    end
    -- Combo + variance
    local def = card.definition or {}
    local comboApplied = false
    if player and player.applyComboBonus then
        comboApplied = player:applyComboBonus(card, self)
    end
    local fighter = player and player.getFighter and player:getFighter() or nil
    local passives = fighter and fighter.passives or nil
    local varCfg = passives and passives.attackVariance or nil
    local amount = 0
    if type(varCfg) == 'table' then
        amount = varCfg.amount or varCfg.value or varCfg.delta or 0
    else
        amount = varCfg or 0
    end
    if (def.attack or 0) > 0 and amount and amount > 0 then
        local rng = (love and love.math and love.math.random) or math.random
        local sign = (rng(2) == 1) and 1 or -1
        card.statVariance = { attack = sign * amount }
    else
        card.statVariance = nil
    end
    if comboApplied and def and def.combo and def.combo.bonus then
        local HudRenderer = require "src.renderers.hud_renderer"
        local parts = {}
        if def.combo.bonus.attack and def.combo.bonus.attack ~= 0 then table.insert(parts, string.format("%+dA", def.combo.bonus.attack)) end
        if def.combo.bonus.block and def.combo.bonus.block ~= 0 then table.insert(parts, string.format("%+dB", def.combo.bonus.block)) end
        local label = (#parts > 0) and ("Combo: " .. table.concat(parts, ", ")) or "Combo bonus!"
        HudRenderer.showToast(label)
    end
    return true, nil
end

function Actions.playCardFromHand(self, card, slotIndex)
    local ok = select(1, self:prevalidatePlayCard(card, slotIndex))
    if not ok then return false end
    local player = card.owner
    local slot = player.boardSlots and player.boardSlots[slotIndex]
    if not slot then return false end
    slot._incoming = nil -- immediate path places instantly, remove reservation
    slot.card = card
    player.slots[card.slotIndex].card = nil
    player:compactHand(self)
    self:placeCardWithoutAdvancing(player, card, slotIndex)
    self.lastActionWasPass = false
    
    -- ANIMATION LAB: Suppress automatic player advancement for testing
    -- Flag set in anim_lab.lua enables playing card sequences without forced player switches
    -- Normal games advance players normally for proper turn-based gameplay
    if not self.suppressPlayerAdvance then
        self:nextPlayer()
    end
    
    self:maybeFinishPlayPhase()
    return true
end

function Actions.passTurn(self)
    if self.phase ~= "play" then return end
    -- Prevent pass while a card is mid-flight to avoid ordering exploits
    if self.animations and self.animations:isBusy() then
        return
    end
    if self.hasPendingRetarget and self:hasPendingRetarget() then return end

    local pid = self.currentPlayer

    self:addLog(string.format("P%d passes", pid))
    if self.logger then
        self.logger:log_event("pass", { player = pid })
    end

    local triggerResolve = false

    if self.lastActionWasPass and self.lastPassBy and self.lastPassBy ~= pid then
        triggerResolve = true
    end

    self.lastActionWasPass = true
    self.lastPassBy = pid

    if triggerResolve then
        self:addLog("Both players pass. Resolving.")
        if self.logger then
            self.logger:log_event("resolve_start", {})
        end
        self:startResolve()
    else
        self:nextPlayer()
    end
end

function Actions.playModifierOnSlot(self, card, targetPlayerIndex, slotIndex, retargetOffset)
    if self.phase ~= "play" then
        dprint("[playModifierOnSlot] Not in play phase")
        return false
    end
    if self:hasPendingRetarget() then
        dprint("[playModifierOnSlot] Pending retarget")
        return false
    end
    local owner = card.owner
    if not owner then
        dprint("[playModifierOnSlot] No owner")
        return false
    end

    local targetPlayer = self.players[targetPlayerIndex]
    if not targetPlayer then
        dprint("[playModifierOnSlot] No target player")
        return false
    end
    local slot = targetPlayer.boardSlots[slotIndex]
    if not slot or not slot.card then
        dprint("[playModifierOnSlot] Invalid slot or no card in slot")
        return false
    end

    local def = card.definition or {}
    local m = def.mod
    if not m then
        dprint("[playModifierOnSlot] No modifier definition")
        return false
    end

    -- enforce target allegiance
    local isEnemy = (targetPlayer ~= owner)
    local targetOk = (m.target == "enemy" and isEnemy) or (m.target == "ally" or m.target == nil) and (not isEnemy)
    if not targetOk then
        dprint("[playModifierOnSlot] Target not valid for modifier")
        owner:snapCard(card, self)
        return false
    end

    -- Restrict +block modifiers to block cards, +attack modifiers to attack cards
    if m.block and m.block > 0 then
        local baseBlock = (slot.card.definition and slot.card.definition.block) or 0
        if baseBlock <= 0 then
            dprint("[playModifierOnSlot] Block modifier can only target a card with block")
            if owner then owner:snapCard(card, self) end
            self:addLog("Block modifier can only target a card with block")
            return false
        end
    end
    if m.attack and m.attack > 0 then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        if baseAttack <= 0 then
            dprint("[playModifierOnSlot] Attack modifier can only target a card with attack")
            if owner then owner:snapCard(card, self) end
            self:addLog("Attack modifier can only target a card with attack")
            return false
        end
    end
    -- special rule: Feint (retarget) only applies to cards that attack
    if m.retarget then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        if baseAttack <= 0 then
            dprint("[playModifierOnSlot] Feint can only target a card with attack")
            if owner then owner:snapCard(card, self) end
            self:addLog("Feint can only target a card with attack")
            return false
        end
    end

    -- cost check
    if Config.rules.energyEnabled ~= false then
        local cost = self:getEffectiveCardCost(owner, card)
        local energy = owner.energy or 0
        if cost > energy then
            dprint(string.format("[playModifierOnSlot] Not enough energy: cost=%d, energy=%d", cost, energy))
            if owner then owner:snapCard(card, self) end
            self:addLog("Not enough energy")
            return false
        end
    end

    -- Get modifier definition
    local m = card.definition and card.definition.mod
    if not m then
        dprint("[playModifierOnSlot] No modifier definition")
        return false
    end

    -- Build and trigger flight animation for modifier cards
    local targetX, targetY = self:getBoardSlotPosition(targetPlayerIndex, slotIndex)
    if Config and Config.debug then
        print("[DEBUG] Building modifier animation. Target position:", targetX, targetY)
    end
    if targetX and targetY then
        local AnimationBuilder = require('src.logic.animation_builder')
        
        -- Create completion handler for modifier
        local function onModifierFlightComplete()
            if Config and Config.debug then
                print("[DEBUG] ANIMATION COMPLETED - calling completeModifierApplication")
            end
            -- Complete the modifier application after flight animation
            Actions.completeModifierApplication(self, card, targetPlayerIndex, slotIndex, retargetOffset, m)
        end
        
        -- Build flight animation using specialized modifier sequence
        if Config and Config.debug then
            print("[DEBUG] Building modifier play sequence...")
        end
        local animations = AnimationBuilder.buildModifierPlaySequence(self, card, targetX, targetY, onModifierFlightComplete)
        print("[DEBUG] Animation built. Animation count:", animations and #animations or "none")
        
        -- Start animation
        if self.animations and animations and #animations > 0 then
            print("[DEBUG] Adding animations to animation system...")
            for _, anim in ipairs(animations) do
                self.animations:add(anim)
                print("[DEBUG] Added animation type:", anim.type)
            end
            print("[DEBUG] All animations added. Returning true.")
        else
            -- Fallback if no animation system
            print("[DEBUG] No animation system available, calling completion immediately")
            onModifierFlightComplete()
        end
        
        return true
    end

    -- Fallback: complete immediately if no position found
    return Actions.completeModifierApplication(self, card, targetPlayerIndex, slotIndex, retargetOffset, m)
end

-- Complete modifier application (extracted from original playModifierOnSlot)
function Actions.completeModifierApplication(self, card, targetPlayerIndex, slotIndex, retargetOffset, m)
    local owner = card.owner
    print("[DEBUG] completeModifierApplication called for", card.name or "unknown")
    print("[DEBUG] targetPlayerIndex:", targetPlayerIndex, "slotIndex:", slotIndex)

    -- Re-validate target and modifier compatibility (since time has passed during animation)
    local targetPlayer = self.players[targetPlayerIndex]
    if not targetPlayer then
        print("[DEBUG] FAILED: Target player no longer exists")
        dprint("[completeModifierApplication] Target player no longer exists")
        if owner then owner:snapCard(card, self) end
        return false
    end

    local slot = targetPlayer.boardSlots[slotIndex]
    if not slot or not slot.card then
        print("[DEBUG] FAILED: Target slot no longer has card")
        dprint("[completeModifierApplication] Target slot no longer has card")
        if owner then owner:snapCard(card, self) end
        return false
    end

    print("[DEBUG] Target card:", slot.card.name or "unknown")

    -- enforce target allegiance
    local isEnemy = (targetPlayer ~= owner)
    local targetOk = (m.target == "enemy" and isEnemy) or (m.target == "ally" or m.target == nil) and (not isEnemy)
    if not targetOk then
        print("[DEBUG] FAILED: Target not valid for modifier. isEnemy:", isEnemy, "m.target:", m.target)
        dprint("[completeModifierApplication] Target not valid for modifier")
        if owner then owner:snapCard(card, self) end
        return false
    end

    print("[DEBUG] Target allegiance check passed")

    print("[DEBUG] Target allegiance check passed")

    -- Restrict +block modifiers to block cards, +attack modifiers to attack cards
    if m.block and m.block > 0 then
        local baseBlock = (slot.card.definition and slot.card.definition.block) or 0
        print("[DEBUG] Checking block modifier: m.block =", m.block, "baseBlock =", baseBlock)
        if baseBlock <= 0 then
            print("[DEBUG] FAILED: Block modifier can only target a card with block")
            dprint("[completeModifierApplication] Block modifier can only target a card with block")
            if owner then owner:snapCard(card, self) end
            self:addLog("Block modifier can only target a card with block")
            return false
        end
    end
    if m.attack and m.attack > 0 then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        print("[DEBUG] Checking attack modifier: m.attack =", m.attack, "baseAttack =", baseAttack)
        if baseAttack <= 0 then
            print("[DEBUG] FAILED: Attack modifier can only target a card with attack")
            dprint("[completeModifierApplication] Attack modifier can only target a card with attack")
            if owner then owner:snapCard(card, self) end
            self:addLog("Attack modifier can only target a card with attack")
            return false
        end
    end
    if m.feint then
        local baseAttack = (slot.card.definition and slot.card.definition.attack) or 0
        print("[DEBUG] Checking feint modifier: m.feint =", m.feint, "baseAttack =", baseAttack)
        if baseAttack <= 0 then
            print("[DEBUG] FAILED: Feint can only target a card with attack")
            dprint("[completeModifierApplication] Feint can only target a card with attack")
            if owner then owner:snapCard(card, self) end
            return false
        end
    end

    print("[DEBUG] Card compatibility checks passed")

    print("[DEBUG] Card compatibility checks passed")

    -- cost check (re-check in case energy changed during animation)
    if Config.rules.energyEnabled ~= false then
        local cost = self:getEffectiveCardCost(owner, card)
        local energy = owner.energy or 0
        print("[DEBUG] Energy check: cost =", cost, "energy =", energy)
        if cost > energy then
            print("[DEBUG] FAILED: Not enough energy")
            dprint(string.format("[completeModifierApplication] Not enough energy: cost=%d, energy=%d", cost, energy))
            if owner then owner:snapCard(card, self) end
            self:addLog("Not enough energy")
            return false
        end
        owner.energy = energy - cost
        print("[DEBUG] Energy deducted. New energy:", owner.energy)
    end

    print("[DEBUG] Starting modifier application process...")

    -- record attachment to the target slot for this round
    self.attachments[targetPlayerIndex][slotIndex] = self.attachments[targetPlayerIndex][slotIndex] or {}
    local stored = {}
    for k, v in pairs(m) do stored[k] = v end
    local cardName = card.name or "modifier"
    local directionLabel
    local selectionPending = false

    print("[DEBUG] Modifier stored:", cardName, "with properties:", stored.attack or "no attack", stored.block or "no block")

    if m.retarget then
        if retargetOffset ~= nil then
            stored.retargetOffset = retargetOffset
            if retargetOffset == 0 then
                directionLabel = "straight"
            else
                directionLabel = retargetOffset < 0 and "left" or "right"
            end
        else
            selectionPending = true
        end
    end

    table.insert(self.attachments[targetPlayerIndex][slotIndex], stored)
    print("[DEBUG] Modifier attached to slot")

    -- discard the modifier card (modifiers do not occupy board slots)
    print("[DEBUG] Discarding modifier card:", card.name)
    self:discardCard(card)
    print("[DEBUG] Modifier card discarded")

    if selectionPending then
        print("[DEBUG] Selection pending, initiating retarget")
        self:initiateRetargetSelection(owner, targetPlayerIndex, slotIndex, stored, cardName)
        return true
    end

    if directionLabel then
        self:addLog(string.format("P%d plays %s (%s) on P%d slot %d", owner.id or 0, cardName, directionLabel, targetPlayerIndex, slotIndex))
    else
        self:addLog(string.format("P%d plays %s on P%d slot %d", owner.id or 0, cardName, targetPlayerIndex, slotIndex))
    end
    print("[DEBUG] Log added")

    self:registerTurnAction()
    self.lastActionWasPass = false
    print("[DEBUG] Turn action registered")

    -- ANIMATION LAB: Suppress automatic player advancement for testing
    if not self.suppressPlayerAdvance then
        self:nextPlayer()
        print("[DEBUG] Player advanced")
    else
        print("[DEBUG] Player advance suppressed (animation lab)")
    end

    self:maybeFinishPlayPhase()
    print("[DEBUG] completeModifierApplication finished successfully")

    return true
end

function Actions.advanceTurn(self)
    if self.phase ~= "play" then return end
    if self:hasPendingRetarget() then return end

    self.lastActionWasPass = false

    -- ANIMATION LAB: Suppress automatic player advancement for testing
    if not self.suppressPlayerAdvance then
        self:nextPlayer()
    end
end

function Actions.discardCard(self, card)
    local player = card.owner
    if not player then return false end
    
    -- UNIFIED: Remove card from board state animation system
    if self.animations and self.animations.removeCardFromBoard then
        self.animations:removeCardFromBoard(card)
    end
    
    -- Remove card from hand
    if card.slotIndex and player.slots[card.slotIndex] and player.slots[card.slotIndex].card == card then
        player.slots[card.slotIndex].card = nil
        player:compactHand(self)
    end
    -- Add card to discard pile
    self.discardPile = self.discardPile or {}
    table.insert(self.discardPile, card)
    card.zone = "discard"
    card.faceUp = true
    return true
end


return Actions
