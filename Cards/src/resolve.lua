-- resolve.lua: Handles all resolution logic for the game
local Config = require "src.config"

local Resolve = {}

function Resolve.startResolve(self)
    -- ...moved from GameState:startResolve...
end

function Resolve.resolveBlockStep(self, slotIndex)
    for idx, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot then
            local def = slot.card and slot.card.definition or nil
            local add = Resolve.getEffectiveStat(self, idx, slotIndex, def, "block")
            if add and add > 0 then
                if slot.block == nil then slot.block = 0 end
                slot.block = slot.block + add
                if self.sumSlotBlock then
                    player.block = self.sumSlotBlock(player)
                end
                local source = slot.card and slot.card.name or "passive"
                self:addLog(string.format("Slot %d [Block]: P%d +%d block (%s) -> slot %d, total %d", slotIndex, player.id or 0, add, source, slot.block or 0, player.block or 0))
            end
        end
    end
end

function Resolve.resolveAttackStep(self, slotIndex)
    -- ...moved from GameState:resolveAttackStep...
end

function Resolve.resolveHealStep(self, slotIndex)
    for idx, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot and slot.card and slot.card.definition then
            local def = slot.card.definition
            local heal = Resolve.getEffectiveStat(self, idx, slotIndex, def, "heal")
                        if heal and heal > 0 then
                local maxHealth = player.maxHealth or 20
                local before = player.health or maxHealth
                player.health = math.min(before + heal, maxHealth)
                local gained = player.health - before
                if gained > 0 then
                    self:addLog(string.format("Slot %d [Heal]: P%d +%d HP (%s) -> %d/%d", slotIndex, player.id or 0, gained, slot.card.name or "", player.health, maxHealth))
                end
                if def and def.effect == "restore_energy" then
                    local rules = Config.rules or {}
                    local bonus = rules.energyIncrementPerRound or 1
                    if bonus < 1 then
                        bonus = 1
                    end
                    player.energy = (player.energy or 0) + bonus
                    if rules.energyMax then
                        player.energy = math.min(player.energy, rules.energyMax)
                    end
                    self:addLog(string.format("Slot %d [Energy]: P%d +%d energy (%s)", slotIndex, player.id or 0, bonus, slot.card.name or ""))
                end
            end
        end
    end
end

function Resolve.resolveCleanupStep(self, slotIndex)
    for _, player in ipairs(self.players or {}) do
        local slot = player.boardSlots and player.boardSlots[slotIndex]
        if slot and slot.card then
            self:addLog(string.format("Slot %d: P%d discards %s", slotIndex, player.id or 0, slot.card.name or "card"))
            if self.logger then
                self.logger:log_event("card_discarded", {
                    player = player.id or 0,
                    card = slot.card.name or "card",
                    slot = slotIndex
                })
            end
            self:discardCard(slot.card)
            slot.card = nil
        end
        if slot then
            slot.block = 0
        end
    end
end

function Resolve.performResolveStep(self, step)
    -- ...moved from GameState:performResolveStep...
end

function Resolve.computeActiveModifiers(gs)
    local function emptyMods()
        return { attack = 0, block = 0, heal = 0 }
    end

    local activeMods = {
        [1] = { global = emptyMods(), perSlot = {} },
        [2] = { global = emptyMods(), perSlot = {} },
    }

    local function addMods(dst, mod)
        if mod.attack then dst.attack = (dst.attack or 0) + mod.attack end
        if mod.block then dst.block = (dst.block or 0) + mod.block end
        if mod.heal then dst.heal = (dst.heal or 0) + mod.heal end
        if mod.retargetOffset then dst.retargetOffset = mod.retargetOffset end
    end

    for pi, p in ipairs(gs.players) do
        for s, slot in ipairs(p.boardSlots) do
            local c = slot.card
            local def = c and c.definition or nil
            local m = def and def.mod or nil
            if m then
                local targetSide = (m.target == "enemy") and (pi == 1 and 2 or 1) or pi
                local entry = activeMods[targetSide]
                if m.scope == "same_slot" then
                    entry.perSlot[s] = entry.perSlot[s] or emptyMods()
                    addMods(entry.perSlot[s], m)
                else -- default to global/all
                    addMods(entry.global, m)
                end
            end
        end
    end

    -- add targeted attachments (played onto an existing card during play)
    if gs.attachments then
        for pi = 1, #gs.players do
            local sideEntry = activeMods[pi]
            for s, mods in pairs(gs.attachments[pi] or {}) do
                for _, m in ipairs(mods) do
                    sideEntry.perSlot[s] = sideEntry.perSlot[s] or emptyMods()
                    addMods(sideEntry.perSlot[s], m)
                end
            end
        end
    end

    if gs.players then
        for pi, player in ipairs(gs.players) do
            local passive = player.getBoardPassiveMods and player:getBoardPassiveMods()
            if passive then
                local entry = activeMods[pi]
                local slotCount = gs.maxBoardCards or player.maxBoardCards or #player.boardSlots or 0
                for s = 1, slotCount do
                    entry.perSlot[s] = entry.perSlot[s] or emptyMods()
                    addMods(entry.perSlot[s], passive)
                end
            end
        end
    end
    return activeMods
end

function Resolve.getEffectiveStat(gs, playerIndex, slotIndex, def, key)
    local base = def and def[key] or 0
    local mods = gs.activeMods or {}
    local side = mods[playerIndex]
    local total = base
    if side then
        total = total + (side.global[key] or 0)
        local perSlot = side.perSlot
        if perSlot then
            local sm = perSlot[slotIndex]
            if sm then
                total = total + (sm[key] or 0)
            end
        end
    end

    local player = gs.players and gs.players[playerIndex] or nil
    local slot = player and player.boardSlots and player.boardSlots[slotIndex] or nil
    local card = slot and slot.card or nil

    if card and card.comboVariance and card.comboVariance[key] then
        total = total + card.comboVariance[key]
    end

    if key == "attack" and total > 0 then
        local variance = card and card.statVariance or nil
        local roll = variance and variance.attack or 0
        if roll ~= 0 then
            total = total + roll
        end
    end
    if total < 0 then total = 0 end
    return total
end


    function Resolve.previewIncomingDamage(gs, playerIndex)
        -- Sum expected incoming attack for playerIndex
            -- ...existing code...
        local opponentIndex = (playerIndex == 1) and 2 or 1
        local player = gs.players and gs.players[playerIndex]
        local damage = 0
        local opponent = gs.players and gs.players[opponentIndex]
        local BoardRenderer = require "src.renderers.board_renderer"
        if opponent and opponent.boardSlots then
            for slotIdx, slot in ipairs(opponent.boardSlots) do
                if slot.card and slot.card.definition then
                    local attack = Resolve.getEffectiveStat(gs, opponentIndex, slotIdx, slot.card.definition, "attack")
                    -- Use collectAttackTargets to find the actual target slot
                    local targets = BoardRenderer.collectAttackTargets(gs, opponentIndex, slotIdx)
                    for _, target in ipairs(targets) do
                        if target.player == playerIndex and player and player.boardSlots and player.boardSlots[target.slot] then
                            -- Use getEffectiveStat to preview block value
                            local blockDef = player.boardSlots[target.slot].card and player.boardSlots[target.slot].card.definition or nil
                            local block = Resolve.getEffectiveStat(gs, playerIndex, target.slot, blockDef, "block")
                            local absorbed = math.min(block, attack)
                            damage = damage + math.max(0, attack - absorbed)
                        end
                    end
                end
            end
        end
            -- ...existing code...
            return damage
    end

    function Resolve.previewIncomingHeal(gs, playerIndex)
        -- Sum expected incoming healing for playerIndex
        local opponentIndex = (playerIndex == 1) and 2 or 1
        local total = 0
        local opponent = gs.players and gs.players[opponentIndex]
        if opponent and opponent.boardSlots then
            for slotIdx, slot in ipairs(opponent.boardSlots) do
                if slot.card and slot.card.definition then
                    local heal = Resolve.getEffectiveStat(gs, opponentIndex, slotIdx, slot.card.definition, "heal")
                    total = total + (heal or 0)
                end
            end
        end
        return total
    end

    return Resolve

