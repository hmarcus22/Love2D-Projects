-- effects.lua: One-off card effects applied during an attack

local Effects = {}

-- Apply effects tied to the attacking card. May mutate context:
--   context.skipDamage = true to prevent normal damage application
--   context.ignoreBlock = true to ignore defender block for this hit
function Effects.apply(gs, attackerIdx, defenderIdx, originSlotIdx, targetSlotIdx, card, context)
    if not card or not card.definition then
        return
    end
    context = context or {}
    local effect = card.definition.effect
    if not effect then
        return
    end
    card.effectsTriggered = card.effectsTriggered or {}

    if effect == "double_attack_one_round" then
        return
    end

    if effect == "avoid_all_attacks" then
        if not (gs.isPlayerInvulnerable and gs:isPlayerInvulnerable(attackerIdx)) then
            gs.invulnerablePlayers = gs.invulnerablePlayers or {}
            gs.invulnerablePlayers[attackerIdx] = true
            if gs.addLog then
                gs:addLog(string.format("Ultimate: P%d cannot be targeted for the rest of the round!", attackerIdx))
            end
        end
        card.effectsTriggered[effect] = true
        return
    end

    if card.effectsTriggered[effect] then
        return
    end

    if effect == "swap_enemies" then
        if gs.swapEnemyBoard then
            gs:swapEnemyBoard(defenderIdx)
        end
    elseif effect == "aoe_attack" then
        -- Ultimate-style AOE: apply once and skip normal per-target damage
        if card.definition and card.definition.ultimate and gs.performAoeAttack then
            local value = context.attack or card.definition.attack or 0
            gs:performAoeAttack(attackerIdx, value)
            context.skipDamage = true
        end
    elseif effect == "ko_below_half_hp" then
        if gs.attemptAssassinate and gs:attemptAssassinate(attackerIdx, defenderIdx) then
            context.skipDamage = true
        end
    elseif effect == "knock_off_board" then
        if gs.knockOffBoard and gs:knockOffBoard(defenderIdx, targetSlotIdx, attackerIdx) then
            context.ignoreBlock = true
        end
    elseif effect == "stun_next_round" then
        if gs.queueStun then
            gs:queueStun(defenderIdx, attackerIdx)
        end
    end

    card.effectsTriggered[effect] = true
end

return Effects

