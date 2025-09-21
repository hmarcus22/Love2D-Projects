local defs = {
    {
        id = "strike",
        name = "Strike",
        description = "Deal 2 damage.",
        cost = 1,
        attack = 2,
        tags = { "brute" },
    },
    {
        id = "heal",
        name = "Heal",
        description = "Restore 3 health.",
        cost = 1,
        heal = 3,
        tags = { "wildcard" },
    },
    {
        id = "block",
        name = "Block",
        description = "Gain 2 armor.",
        cost = 1,
        block = 2,
        tags = { "brute" },
    },
    {
        id = "fireball",
        name = "Fireball",
        description = "Deal 4 damage but costs 2 energy.",
        cost = 2,
        attack = 4,
        tags = { "brute", "wildcard" },
    },
    -- Modifier cards: adjust stats of other cards for this round
    {
        id = "feint",
        name = "Feint",
        description = "Retarget this card's attack to adjacent opposing slot (drop left/right to pick).",
        cost = 1,
        mod = { target = "ally", scope = "target", retarget = true },
        tags = { "tactician" },
    },
    {
        id = "banner",
        name = "War Banner",
        description = "+1 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 1, target = "ally", scope = "target" },
        tags = { "wildcard" },
    },
    {
        id = "rally",
        name = "Rally",
        description = "+1 block to a target allied card this round.",
        cost = 1,
        mod = { block = 1, target = "ally", scope = "target" },
        tags = { "wildcard" },
    },
    {
        id = "hex",
        name = "Hex",
        description = "-1 attack to a target enemy card this round.",
        cost = 1,
        mod = { attack = -1, target = "enemy", scope = "target" },
        tags = { "tactician" },
    },
    {
        id = "duelist",
        name = "Duelist",
        description = "+2 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 2, target = "ally", scope = "target" },
        tags = { "brute" },
    }
}

return defs
