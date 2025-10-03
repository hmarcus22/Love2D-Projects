local basicCards = {
    {
        id = "punch",
        name = "Quick Jab",
        description = "Deal 2 damage with a fast straight punch.",
        cost = 1,
        attack = 2,
        tags = { "boxer", "brawler", "brute" },
        art = "assets/cards/punch.png",
    },
    {
        id = "kick",
        name = "Snap Kick",
        description = "Deal 3 damage with a sharp kick.",
        cost = 1,
        attack = 3,
        tags = { "karate", "ninja", "brawler" },
    },
    {
        id = "uppercut",
        name = "Uppercut",
        description = "Heavy upward strike for big damage.",
        cost = 2,
        attack = 5,
        tags = { "boxer", "brute" },
    },
    {
        id = "roundhouse",
        name = "Roundhouse",
        description = "Spin attack that hits every opposing slot for 2 damage.",
        cost = 2,
        attack = 2,
        effect = "aoe_attack",
        tags = { "karate", "brawler" },
    },
    {
        id = "counter",
        name = "Counter",
        description = "Gain 2 guard and strike back for 2 damage.",
        cost = 2,
        attack = 2,
        block = 2,
        tags = { "boxer", "tactician" },
    },
}

local supportCards = {
    {
        id = "block",
        name = "Guard Hands",
        description = "Gain 2 guard for the round.",
        cost = 1,
        block = 2,
        tags = { "boxer", "wrestler", "karate", "brute" },
    },
    {
        id = "guard",
        name = "Steel Guard",
        description = "Gain 4 guard and brace for impact.",
        cost = 2,
        block = 4,
        tags = { "wrestler", "brute" },
    },
    {
        id = "feint",
        name = "Feint",
        description = "Re-aim this card's attack to a neighbouring opposing slot.",
        cost = 1,
        mod = { target = "ally", scope = "target", retarget = true },
        tags = { "tactician", "ninja" },
    },
    {
        id = "rally",
        name = "Corner Rally",
        description = "+1 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 1, target = "ally", scope = "target" },
        tags = { "wildcard", "brawler" },
    },
    {
        id = "banner",
        name = "Corner Banner",
        description = "+1 block to a target allied card this round.",
        cost = 1,
        mod = { block = 1, target = "ally", scope = "target" },
        tags = { "wildcard", "coach" },
    },
    {
        id = "adrenaline_rush",
        name = "Adrenaline Rush",
        description = "+2 attack to a target allied card this round.",
        cost = 1,
        mod = { attack = 2, target = "ally", scope = "target" },
        tags = { "brawler", "coach" },
    },
    {
        id = "taunt",
        name = "Trash Talk",
        description = "Lower every opposing card's attack by 1 this round.",
        cost = 1,
        mod = { attack = -1, target = "enemy" },
        tags = { "brawler", "tactician" },
    },
    {
        id = "hex",
        name = "Cheap Shot",
        description = "-1 attack to a target enemy card this round.",
        cost = 1,
        mod = { attack = -1, target = "enemy", scope = "target" },
        tags = { "tactician", "ninja" },
    },
    -- removed duplicate of adrenaline_rush: duelist
}

local fighterCards = {
    -- Brute
    {
        id = "ground_pound",
        name = "Ground Pound",
        description = "Combo: Play after Guard Hands for +3 attack.",
        cost = 2,
        attack = 3,
        combo = { after = "block", bonus = { attack = 3 } },
        tags = { "brute", "combo" },
    },
    {
        id = "iron_guard",
        name = "Iron Guard",
        description = "Ultimate: Gain 5 guard and reflect damage this round.",
        cost = 3,
        block = 5,
        ultimate = true,
        tags = { "brute", "ultimate" },
    },
    -- Tactician
    {
        id = "counterplay",
        name = "Counterplay",
        description = "Combo: Play after Feint for +2 attack and +2 guard.",
        cost = 2,
        attack = 2,
        block = 2,
        combo = { after = "feint", bonus = { attack = 2, block = 2 } },
        tags = { "tactician", "combo" },
    },
    {
        id = "tactical_shift",
        name = "Tactical Shift",
        description = "Ultimate: Swap all enemy card positions.",
        cost = 3,
        ultimate = true,
        effect = "swap_enemies",
        tags = { "tactician", "ultimate" },
    },
    -- Wildcard
    {
        id = "wild_swing",
        name = "Wild Swing",
        description = "Combo: Play after Corner Rally for +2 attack (but -1 block next round).",
        cost = 2,
        attack = 2,
        combo = { after = "rally", bonus = { attack = 2 }, penalty = { block = -1, nextRound = true } },
        tags = { "wildcard", "combo" },
    },
    {
        id = "nature_fury",
        name = "Nature's Fury",
        description = "Ultimate: Deal 5 damage to all enemy cards.",
        cost = 3,
        attack = 5,
        ultimate = true,
        effect = "aoe_attack",
        tags = { "wildcard", "ultimate" },
    },
}

local extraFighterCards = {
    -- Ninja
    {
        id = "shadow_step",
        name = "Shadow Step",
        description = "Combo: Play after Feint for a free attack.",
        cost = 2,
        attack = 3,
        combo = { after = "feint", bonus = { attack = 2 } },
        tags = { "ninja", "combo" },
    },
    {
        id = "smoke_bomb",
        name = "Smoke Bomb",
        description = "Ultimate: Avoid all attacks this round.",
        cost = 3,
        ultimate = true,
        effect = "avoid_all_attacks",
        effectTiming = 'on_landing', -- trigger immediately on landing (placement)
        tags = { "ninja", "ultimate" },
    },
    {
        id = "assassinate",
        name = "Assassinate",
        description = "Ultimate: KO if the opponent is below half HP.",
        cost = 3,
        ultimate = true,
        effect = "ko_below_half_hp",
        tags = { "ninja", "ultimate" },
    },
    -- Boxer
    {
        id = "jab_cross",
        name = "Jab-Cross",
        description = "Combo: Play after Quick Jab for +2 damage.",
        cost = 2,
        attack = 4,
        combo = { after = "punch", bonus = { attack = 2 } },
        tags = { "boxer", "combo" },
    },
    {
        id = "counterpunch",
        name = "Counterpunch",
        description = "Block 2 and retaliate with 2 damage.",
        cost = 2,
        attack = 2,
        block = 2,
        tags = { "boxer", "signature" },
    },
    {
        id = "haymaker",
        name = "Haymaker",
        description = "Ultimate: Huge swing that requires setting up punches.",
        cost = 3,
        attack = 7,
        ultimate = true,
        effect = "require_2_punches",
        tags = { "boxer", "ultimate" },
    },
    -- Wrestler
    {
        id = "suplex",
        name = "Suplex",
        description = "Combo: Play after Guard Hands for extra damage and guard.",
        cost = 2,
        attack = 3,
        block = 2,
        combo = { after = "block", bonus = { attack = 2, block = 2 } },
        tags = { "wrestler", "combo" },
    },
    {
        id = "body_slam",
        name = "Body Slam",
        description = "Knock the opposing card off the board.",
        cost = 2,
        attack = 2,
        effect = "knock_off_board",
        effectTiming = 'on_impact', -- defer effect until impact squash for visual sync
        flightProfile = 'slam_body', -- custom horizontal timing (fast start, slow mid, drop)
        tags = { "wrestler", "signature" },
    },
    {
        id = "powerbomb",
        name = "Powerbomb",
        description = "Ultimate: Massive damage and stun next round.",
        cost = 3,
        attack = 6,
        ultimate = true,
        effect = "stun_next_round",
        tags = { "wrestler", "ultimate" },
    },
    -- Karate Master
    {
        id = "focus_strike",
        name = "Focus Strike",
        description = "Combo: Play after Guard Hands for +2 attack.",
        cost = 2,
        attack = 3,
        combo = { after = "block", bonus = { attack = 2 } },
        tags = { "karate", "combo" },
    },
    {
        id = "meditate",
        name = "Meditate",
        description = "Restore 3 health and recover energy.",
        cost = 1,
        heal = 3,
        effect = "restore_energy",
        tags = { "karate", "signature" },
    },
    {
        id = "dragon_kick",
        name = "Dragon Kick",
        description = "Ultimate: Hits all enemy cards.",
        cost = 3,
        attack = 5,
        ultimate = true,
        effect = "aoe_attack",
        tags = { "karate", "ultimate" },
    },
    -- Street Brawler
    {
        id = "bottle_smash",
        name = "Bottle Smash",
        description = "Deal 4 damage. If played after Corner Rally, gain +2 attack.",
        cost = 2,
        attack = 4,
        combo = { after = "rally", bonus = { attack = 2 } },
        tags = { "brawler", "combo" },
    },
    {
        id = "rage_unleashed",
        name = "Rage Unleashed",
        description = "Ultimate: Double attack for one round, costs all energy.",
        cost = 3,
        attack = 6,
        ultimate = true,
        effect = "double_attack_one_round",
        tags = { "brawler", "ultimate" },
    },
}

local defs = {}

local function append(cards)
    for _, card in ipairs(cards) do
        defs[#defs + 1] = card
    end
end

append(basicCards)
append(supportCards)
append(fighterCards)
append(extraFighterCards)

return defs
