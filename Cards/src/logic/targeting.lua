-- src/logic/targeting.lua
-- Pure logic for computing attack targets (no rendering side-effects)

local Targeting = {}

local function getRetargetOffset(state, playerIndex, slotIndex)
    local perPlayer = state.attachments and state.attachments[playerIndex]
    local attachments = perPlayer and perPlayer[slotIndex]
    if attachments then
        for _, mod in ipairs(attachments) do
            if mod.retargetOffset ~= nil then
                return mod.retargetOffset
            end
        end
    end
    return 0
end

function Targeting.collectAttackTargets(state, playerIndex, slotIndex)
    local targets = {}
    local players = state.players or {}
    local player = players[playerIndex]
    local slot = player and player.boardSlots and player.boardSlots[slotIndex]
    if not slot or not slot.card then
        return targets
    end

    local def = slot.card.definition or {}
    local baseAttack = def.attack or 0
    if baseAttack <= 0 then
        return targets
    end

    local opponentIndex = (playerIndex == 1) and 2 or 1
    local opponent = players[opponentIndex]
    local opponentSlots = opponent and opponent.boardSlots or {}
    local maxSlots = state.maxBoardCards or #opponentSlots
    if maxSlots == 0 then
        maxSlots = #opponentSlots
    end

    -- AOE: target every opposing slot once
    if def.effect == "aoe_attack" then
        for i = 1, maxSlots do
            table.insert(targets, { player = opponentIndex, slot = i })
        end
        return targets
    end

    local offset = getRetargetOffset(state, playerIndex, slotIndex)
    local targetSlot = slotIndex + offset
    if maxSlots > 0 then
        if targetSlot < 1 then targetSlot = 1 end
        if targetSlot > maxSlots then targetSlot = maxSlots end
    else
        targetSlot = slotIndex
    end

    table.insert(targets, { player = opponentIndex, slot = targetSlot })
    return targets
end

return Targeting
