local defs = {
    {
        id = "strike",
        name = "Strike",
        description = "Deal 2 damage.",
        cost = 1,
        attack = 2
    },
    {
        id = "heal",
        name = "Heal",
        description = "Restore 3 health.",
        cost = 1,
        heal = 3
    },
    {
        id = "block",
        name = "Block",
        description = "Gain 2 armor.",
        cost = 1,
        block = 2
    },
    {
        id = "fireball",
        name = "Fireball",
        description = "Deal 4 damage but costs 2 energy.",
        cost = 2,
        attack = 4
    },
    -- Modifier cards: adjust stats of other cards for this round
    {
        id = "feint",
        name = "Feint",
        description = "Retarget this card's attack to adjacent opposing slot (drop left/right to pick).",
        cost = 1,
        mod = { target = "ally", scope = "target", retarget = true }
    },
    {
        id = "banner",
        name = "War Banner",
        description = "+1 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 1, target = "ally", scope = "target" }
    },
    {
        id = "rally",
        name = "Rally",
        description = "+1 block to a target allied card this round.",
        cost = 1,
        mod = { block = 1, target = "ally", scope = "target" }
    },
    {
        id = "hex",
        name = "Hex",
        description = "-1 attack to a target enemy card this round.",
        cost = 1,
        mod = { attack = -1, target = "enemy", scope = "target" }
    },
    {
        id = "duelist",
        name = "Duelist",
        description = "+2 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 2, target = "ally", scope = "target" }
    }
}

return defs
