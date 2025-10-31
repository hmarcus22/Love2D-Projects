-- resolve.lua: Handles all resolution logic for the game
local Config = require "src.config"

local Resolve = {}

function Resolve.startResolve(self)
    self.phase = "resolve"
    self.resolveQueue = {}
    self.resolveIndex = 0
    self.resolveTimer = 0
    self.resolveCurrentStep = nil

    if self.addLog then
        self:addLog("Resolve phase begins")
    end

    local maxSlots = self.maxBoardCards or 0
    for _, player in ipairs(self.players or {}) do
        local count = player.boardSlots and #player.boardSlots or 0
        if count > maxSlots then
            maxSlots = count
        end
    end

    if maxSlots <= 0 then
        if self.finishResolvePhase then
            self:finishResolvePhase()
        end
        return
    end

    local function slotHasCard(slotIndex)
        for _, player in ipairs(self.players or {}) do
            local slot = player.boardSlots and player.boardSlots[slotIndex]
            if slot and slot.card then
                return true
            end
        end
        return false
    end

    for slotIndex = 1, maxSlots do
        if slotHasCard(slotIndex) then
            table.insert(self.resolveQueue, { kind = "block", slot = slotIndex })
            table.insert(self.resolveQueue, { kind = "attack", slot = slotIndex })
            table.insert(self.resolveQueue, { kind = "heal", slot = slotIndex })
            table.insert(self.resolveQueue, { kind = "cleanup", slot = slotIndex })
        end
    end

    if #self.resolveQueue == 0 then
        if self.finishResolvePhase then
            self:finishResolvePhase()
        end
        return
    end

    if self.computeActiveModifiers then
        self:computeActiveModifiers()
    end
    self.resolveCurrentStep = self.resolveQueue[1]
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
    if not self.players then
        return
    end

    local Targeting = require "src.logic.targeting"

    for attackerIndex, attacker in ipairs(self.players) do
        local srcSlot = attacker.boardSlots and attacker.boardSlots[slotIndex]
        if srcSlot and srcSlot.card then
            local def = srcSlot.card.definition or {}
            local baseAttack = Resolve.getEffectiveStat(self, attackerIndex, slotIndex, def, "attack") or 0

            -- Apply any special multipliers (e.g., double_attack_one_round)
            local mult = 1
            if self.specialAttackMultipliers then
                local perPlayer = self.specialAttackMultipliers[attacker.id or attackerIndex]
                if perPlayer and perPlayer[slotIndex] then
                    mult = perPlayer[slotIndex]
                end
            end
            local attack = math.floor(baseAttack * mult)

            if attack > 0 then
                -- ATTACK ANIMATION: Card strikes forward toward target
                Resolve.triggerAttackAnimation(self, srcSlot.card, attackerIndex, slotIndex)
                
                local targets = Targeting.collectAttackTargets(self, attackerIndex, slotIndex)
                for _, target in ipairs(targets) do
                    local defenderIndex = target.player
                    local defender = self.players and self.players[defenderIndex]
                    if defender then
                        local context = { attack = attack }
                        local Effects = require "src.logic.effects"
                        Effects.apply(self, attackerIndex, defenderIndex, slotIndex, target.slot, srcSlot.card, context)

                        if not context.skipDamage then
                            -- Invulnerability check
                            if self.isPlayerInvulnerable and self:isPlayerInvulnerable(defenderIndex) then
                                if self.addLog then
                                    self:addLog(string.format(
                                        "Slot %d [Attack]: P%d %s attacks P%d slot %d but target is invulnerable",
                                        slotIndex,
                                        attacker.id or attackerIndex,
                                        srcSlot.card.name or "attack",
                                        defender.id or defenderIndex,
                                        target.slot or 0
                                    ))
                                end
                            else
                                -- Consume block then deal damage
                                local defenderSlot = defender.boardSlots and defender.boardSlots[target.slot]
                                local absorbed = 0
                                if not context.ignoreBlock and defenderSlot then
                                    local before = defenderSlot.block or 0
                                    absorbed = math.min(before, attack)
                                    if absorbed > 0 then
                                        defenderSlot.block = before - absorbed
                                    end
                                end
                                local damage = math.max(0, attack - absorbed)
                                if damage > 0 then
                                    defender.health = math.max(0, (defender.health or defender.maxHealth or 20) - damage)
                                end
                                
                                -- DEFENSIVE ANIMATION: Push back when taking damage, intensity based on block absorbed
                                if defenderSlot and defenderSlot.card then
                                    Resolve.triggerDefensiveAnimation(self, defenderSlot.card, defenderIndex, target.slot, absorbed, damage)
                                end

                                if self.addLog then
                                    local retargetSuffix = (target.slot ~= slotIndex) and string.format(" -> slot %d", target.slot) or ""
                                    self:addLog(string.format(
                                        "Slot %d [Attack]: P%d %s hits P%d slot %d for %d (block %d, dmg %d)%s",
                                        slotIndex,
                                        attacker.id or attackerIndex,
                                        srcSlot.card.name or "attack",
                                        defender.id or defenderIndex,
                                        target.slot or 0,
                                        attack,
                                        absorbed,
                                        damage,
                                        retargetSuffix
                                    ))
                                end
                                
                                -- CHECK FOR COUNTER RETALIATION: If defender has counter effect, deal damage back
                                if defenderSlot and defenderSlot.card and defenderSlot.card.definition then
                                    local defCard = defenderSlot.card
                                    local defDef = defCard.definition
                                    if defDef.effect == "counter_retaliate" and defDef.counterDamage then
                                        local counterDamage = defDef.counterDamage
                                        local beforeCounter = attacker.health or attacker.maxHealth or 20
                                        attacker.health = math.max(0, beforeCounter - counterDamage)
                                        
                                        if self.addLog then
                                            self:addLog(string.format(
                                                "Counter: P%d %s retaliates against P%d for %d damage!",
                                                defender.id or defenderIndex,
                                                defCard.name or "counter",
                                                attacker.id or attackerIndex,
                                                counterDamage
                                            ))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
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
    if not step or not step.kind then
        return
    end

    local handlers = {
        block = Resolve.resolveBlockStep,
        attack = Resolve.resolveAttackStep,
        heal = Resolve.resolveHealStep,
        cleanup = Resolve.resolveCleanupStep,
    }

    local handler = handlers[step.kind]
    if handler then
        handler(self, step.slot)
    elseif self.addLog then
        self:addLog(string.format("Unknown resolve step: %s", tostring(step.kind)))
    end
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
        local Targeting = require "src.logic.targeting"
        if opponent and opponent.boardSlots then
            for slotIdx, slot in ipairs(opponent.boardSlots) do
                if slot.card and slot.card.definition then
                    local attack = Resolve.getEffectiveStat(gs, opponentIndex, slotIdx, slot.card.definition, "attack")
                    -- Use collectAttackTargets to find the actual target slot
                    local targets = Targeting.collectAttackTargets(gs, opponentIndex, slotIdx)
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

-- Animation functions for resolve combat
function Resolve.triggerAttackAnimation(gameState, card, attackerIndex, slotIndex)
    if not card then return end
    
    -- Custom AOE sweep for Roundhouse: leap + half-spin, then three quick stabs across enemy row
    do
        local def = card.definition or {}
        if (card.id == 'roundhouse' or (def and def.id == 'roundhouse')) and def.effect == 'aoe_attack' then
            if gameState.animations then
                -- Start prep resolve animation (leap + half spin)
                if gameState.animations.startResolveAnimation then
                    gameState.animations:startResolveAnimation(card, 'roundhouse_prep', nil)
                end

                -- Determine opponent row positions and compute facing angles per slot
                local opponentIndex = (attackerIndex == 1) and 2 or 1
                local maxSlots = gameState.maxBoardCards or 3
                local cx = (card.x or 0) + (card.w or 100)/2
                local cy = (card.y or 0) + (card.h or 150)/2
                local cardW, cardH = gameState:getCardDimensions()
                local spinRange = math.rad(270)
                local windupDur = 0.08
                local strikeDur = 1.10
                local freezeDur = 0.20 -- per-kick freeze window
                local Config = require 'src.config'

                -- Build kick table; include target center X and spin-aligned base delay
                local function normAngle(a)
                    local twoPi = math.pi * 2
                    a = a % twoPi
                    if a < 0 then a = a + twoPi end
                    return a
                end
                -- First pass: collect targets with their angles and centers
                local temp = {}
                for i = 1, maxSlots do
                    local sx, sy = gameState:getBoardSlotPosition(opponentIndex, i)
                    local tx = sx + (cardW or (card.w or 100))/2
                    local ty = sy + (cardH or (card.h or 150))/2
                    local dx = tx - cx
                    local dy = ty - cy
                    local angle = (math.atan2 and math.atan2(dx, dy)) or math.atan(dx, dy)
                    temp[#temp+1] = { slot = i, angle = angle, tx = tx }
                end
                -- Determine true spin start orientation: card rotation + windup rotation (-12deg)
                local startAngle = normAngle((card.rotation or 0) + math.rad(-12))
                -- Second pass: compute spin-aligned baseDelay per target
                local kicks = {}
                for i = 1, #temp do
                    local t = temp[i]
                    local delta = normAngle(t.angle - startAngle)
                    if delta > spinRange then delta = spinRange end
                    local baseDelay = windupDur + (delta / spinRange) * strikeDur
                    kicks[#kicks+1] = { slot = t.slot, angle = t.angle, tx = t.tx, baseDelay = baseDelay }
                end

                -- Map spin-perfect times to left->center->right order
                -- 1) spinOrder by baseDelay (natural spin timing)
                local spinOrder = {}
                for i = 1, #kicks do spinOrder[i] = kicks[i] end
                table.sort(spinOrder, function(a, b)
                    if a.baseDelay == b.baseDelay then return a.slot < b.slot end
                    return a.baseDelay < b.baseDelay
                end)
                -- 2) lrOrder by screen X (left->right)
                local lrOrder = {}
                for i = 1, #kicks do lrOrder[i] = kicks[i] end
                table.sort(lrOrder, function(a, b)
                    if a.tx == b.tx then return a.slot < b.slot end
                    return a.tx < b.tx
                end)
                -- 3) Assign earliest spin times to leftmost slots; schedule without extra padding
                for idx = 1, #lrOrder do
                    local k = lrOrder[idx]
                    local assignedTime = spinOrder[idx] and spinOrder[idx].baseDelay or windupDur
                    local kAngle = k.angle
                    local delay = assignedTime
                    if Config and Config.debug then
                        print(string.format("[Roundhouse] Kick slot %d (order %d): tx=%.1f, assignedDelay %.3fs", k.slot, idx, k.tx or 0, delay))
                    end
                    if gameState.animations.after then
                        gameState.animations:after(delay, function()
                            -- Fixed-length local-Y stab: compute forward from facing angle and stab a constant distance
                            local dirX = math.sin(kAngle)
                            local dirY = math.cos(kAngle)
                            local stabDist = 140 -- exaggerated for clearer analysis
                            local targetX = (card.x or 0) + dirX * stabDist
                            local targetY = (card.y or 0) + dirY * stabDist
                            if gameState.animations.startAttackAnimation then
                                gameState.animations:startAttackAnimation(card, { x = targetX, y = targetY })
                            end
                            -- Brief freeze of rotation to analyze kick moment (record start and end)
                            local now = love.timer.getTime()
                            card._roundhouseFreezeStartTime = now
                            card._roundhouseFreezeEndTime = now + freezeDur
                            gameState.animations:after(freezeDur, function()
                                card._roundhouseFreezeStartTime = nil
                                card._roundhouseFreezeEndTime = nil
                            end)
                        end)
                    end
                end

                return -- Skip default single-lane strike
            end
        end
    end

    -- UNIFIED: Trigger unified attack animation if available
    if gameState.animations and gameState.animations.startAttackAnimation then
        -- Find target card for enhanced visual effects
        local targetCard = nil
        if gameState.players and gameState.players[3 - attackerIndex] then
            local enemyPlayer = gameState.players[3 - attackerIndex]
            if enemyPlayer.boardSlots and enemyPlayer.boardSlots[slotIndex] then
                targetCard = enemyPlayer.boardSlots[slotIndex].card
            end
        end
        
        gameState.animations:startAttackAnimation(card, targetCard)
    end
    
    -- ATTACK STRIKE: Card moves forward toward enemy, then snaps back (LEGACY)
    local animationData = {
        type = "attack_strike",
        duration = 0.3,  -- Quicker, snappier timing
        startTime = love.timer.getTime(),
        attackerIndex = attackerIndex,
        slotIndex = slotIndex,
        currentPlayerIndex = gameState.currentPlayer or 1
    }
    
    -- Add to card for rendering
    card.resolveAnimation = animationData
    
    if gameState.addLog then
        gameState:addLog(string.format(">> %s strikes!", card.name or "Card"))
    end
end

function Resolve.triggerDefensiveAnimation(gameState, card, defenderIndex, slotIndex, blockAbsorbed, damageDealt)
    if not card then return end
    
    -- UNIFIED: Trigger unified defensive animation if available
    if gameState.animations and gameState.animations.startDefenseAnimation then
        -- Find attacking card for enhanced visual effects
        local attackCard = nil
        if gameState.players and gameState.players[3 - defenderIndex] then
            local enemyPlayer = gameState.players[3 - defenderIndex]
            if enemyPlayer.boardSlots and enemyPlayer.boardSlots[slotIndex] then
                attackCard = enemyPlayer.boardSlots[slotIndex].card
            end
        end
        
        gameState.animations:startDefenseAnimation(card, attackCard)
    end
    
    -- Don't override attack animations that are still playing (LEGACY)
    if card.resolveAnimation and card.resolveAnimation.type == "attack_strike" then
        local elapsed = love.timer.getTime() - card.resolveAnimation.startTime
        local attackProgress = elapsed / card.resolveAnimation.duration
        
        -- Only override if attack animation is nearly complete (>90%)
        if attackProgress < 0.9 then
            if gameState.addLog then
                gameState:addLog(string.format(">> %s strikes and takes damage!", card.name or "Card"))
            end
            return  -- Don't override the attack animation
        end
    end
    
    -- DEFENSIVE PUSH: Card gets pushed back based on damage taken
    -- More block absorbed = less push back, more damage = more push back
    local pushIntensity = 0.3 + (damageDealt * 0.1)  -- Base 0.3, +0.1 per damage
    if blockAbsorbed > 0 then
        pushIntensity = pushIntensity * 0.7  -- Reduce push if block absorbed some damage
    end
    
    local animationData = {
        type = "defensive_push",
        duration = 0.35,  -- Slightly longer to accommodate reaction delay
        startTime = love.timer.getTime(),
        defenderIndex = defenderIndex,
        slotIndex = slotIndex,
        pushIntensity = math.min(pushIntensity, 1.0),  -- Cap at 1.0
        currentPlayerIndex = gameState.currentPlayer or 1
    }
    
    -- Add to card for rendering
    card.resolveAnimation = animationData
    
    if gameState.addLog then
        if blockAbsorbed > 0 then
            gameState:addLog(string.format(">> %s blocks and staggers!", card.name or "Card"))
        else
            gameState:addLog(string.format(">> %s is pushed back!", card.name or "Card"))
        end
    end
end

return Resolve
