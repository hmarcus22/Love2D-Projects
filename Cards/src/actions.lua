local Class = require 'libs.HUMP.class'
local Actions = Class{}
local Config = require "src.config"

local function dprint(...)
    if Config and Config.debug then
        print(...)
    end
end

function Actions.playCardFromHand(self, card, slotIndex)
    local player = card.owner
    if not player or not slotIndex then
        dprint("[playCardFromHand] Invalid player or slotIndex")
        return false
    end
    if self.phase ~= "play" then
        dprint("[playCardFromHand] Not in play phase")
        return false
    end
    local slot = player.boardSlots and player.boardSlots[slotIndex]
    if not slot or slot.card then
        dprint("[playCardFromHand] Invalid slot or slot already occupied")
        return false
    end

    local definition = card.definition or {}
    local effectId = definition.effect

    if effectId == "require_2_punches" then
        local punches = player.roundPunchCount or 0
        if punches < 2 then
            self:addLog("Haymaker requires two punches this round")
            player:snapCard(card, self)
            player:compactHand(self)
            return false
        end
    end

    -- Energy cost check
    if Config.rules.energyEnabled ~= false then
        local cost = self:getEffectiveCardCost(player, card)
        local energy = player.energy or 0
        if cost > energy then
            dprint(string.format("[playCardFromHand] Not enough energy: cost=%d, energy=%d", cost, energy))
            player:snapCard(card, self)
            player:compactHand(self)
            self:addLog("Not enough energy")
            return false
        end
        player.energy = energy - cost
        if effectId == "double_attack_one_round" then
            player.energy = 0
        end
    end

    -- Place card on board
    slot.card = card
    card.zone = "board"
    card.faceUp = true
    player.slots[card.slotIndex].card = nil
    player:compactHand(self)
    self:onCardPlaced(player, card, slotIndex)
    return true
end

function Actions.passTurn(self)
    if self.phase ~= "play" then return end
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
        owner.energy = energy - cost
    end

    -- record attachment to the target slot for this round
    self.attachments[targetPlayerIndex][slotIndex] = self.attachments[targetPlayerIndex][slotIndex] or {}
    local stored = {}
    for k, v in pairs(m) do stored[k] = v end
    local cardName = card.name or "modifier"
    local directionLabel
    local selectionPending = false

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

    -- discard the modifier card (modifiers do not occupy board slots)
    self:discardCard(card)

    if selectionPending then
        self:initiateRetargetSelection(owner, targetPlayerIndex, slotIndex, stored, cardName)
        return true
    end

    if directionLabel then
        self:addLog(string.format("P%d plays %s (%s) on P%d slot %d", owner.id or 0, cardName, directionLabel, targetPlayerIndex, slotIndex))
    else
        self:addLog(string.format("P%d plays %s on P%d slot %d", owner.id or 0, cardName, targetPlayerIndex, slotIndex))
    end

    self:registerTurnAction()
    self.lastActionWasPass = false

    self:nextPlayer()

    self:maybeFinishPlayPhase()

    return true
end

function Actions.advanceTurn(self)
    if self.phase ~= "play" then return end
    if self:hasPendingRetarget() then return end

    self.lastActionWasPass = false

    self:nextPlayer()
end

function Actions.discardCard(self, card)
    local player = card.owner
    if not player then return false end
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
