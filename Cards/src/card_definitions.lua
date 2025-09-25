local defs = {
    {
        id = "counter",
        name = "Counter",
        description = "Block and retaliate if attacked this round.",
        cost = 2,
        block = 2,
        effect = "retaliate_if_attacked",
        tags = { "boxer", "brawler" },
    },
    {
        id = "jab",
        name = "Jab",
        description = "Low damage, enables combos.",
        cost = 1,
        attack = 1,
        tags = { "boxer" },
    },
    {
        id = "uppercut",
        name = "Uppercut",
        description = "High damage, costs more energy. Can stun.",
        cost = 2,
        attack = 5,
        effect = "stun",
        tags = { "brute", "brawler" },
    },
    {
        id = "guard",
        name = "Guard",
        description = "Gain 3 armor. Costs more energy.",
        cost = 2,
        block = 3,
        tags = { "brute", "brawler" },
    },
    {
        id = "roundhouse",
        name = "Roundhouse",
        description = "Hits all enemy slots for 2 damage.",
        cost = 2,
        attack = 2,
        effect = "aoe_attack",
        tags = { "karate", "brawler" },
    },
    {
        id = "taunt",
        name = "Taunt",
        description = "Force opponent to attack you.",
        cost = 1,
        effect = "force_attack",
        tags = { "brawler" },
    },
    {
        id = "punch",
        name = "Punch",
        description = "Deal 2 damage.",
        cost = 1,
        attack = 2,
        tags = { "brute" },
        art = "assets/cards/punch.png"
    },
    {
        id = "kick",
        name = "Kick",
        description = "Deal 3 damage.",
        cost = 1,
        attack = 3,
        tags = { "brute" },
        art = "assets/cards/punch.png"
    },
    -- Removed Heal (not thematic)
    {
        id = "block",
        name = "Block",
        description = "Gain 2 armor.",
        cost = 1,
        block = 2,
        tags = { "brute" },
    },
    -- Removed Fireball (not thematic)
    -- New thematic cards
    {
        id = "uppercut",
        name = "Uppercut",
        description = "High damage, costs more energy. Can stun.",
        cost = 2,
        attack = 5,
        effect = "stun",
        tags = { "brute", "brawler" },
    },
    {
        id = "guard",
        name = "Guard",
        description = "Gain 3 armor. Costs more energy.",
        cost = 2,
        block = 3,
        tags = { "brute", "brawler" },
    },
    {
        id = "jab",
        name = "Jab",
        description = "Low damage, enables combos.",
        cost = 1,
        attack = 1,
        tags = { "boxer" },
    },
    {
        id = "roundhouse",
        name = "Roundhouse",
        description = "Hits all enemy slots for 2 damage.",
        cost = 2,
        attack = 2,
        effect = "aoe_attack",
        tags = { "karate", "brawler" },
    },
    -- Modifier cards: adjust stats of other cards for this round
    {
        id = "feint",
        name = "Feint",
        description = "Re-aim this card's attack to a neighboring opposing slot; drop left/center/right to choose.",
        cost = 1,
        mod = { target = "ally", scope = "target", retarget = true },
        tags = { "tactician" },
    },
    {
        id = "adrenaline_rush",
        name = "Adrenaline Rush",
        description = "+1 attack to a target allied card this round. Get pumped!",
        cost = 1,
        mod = { attack = 1, target = "ally", scope = "target" },
        tags = { "wildcard" },
    },
    {
        id = "guard_up",
        name = "Guard Up",
        description = "+1 block to a target allied card this round. Brace yourself!",
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

-- Fighter-specific cards, combos, and ultimates
local fighterCards = {
    -- Brute
    {
        id = "ground_pound",
        name = "Ground Pound",
        description = "Combo: Play after Block for +3 attack.",
        cost = 2,
        attack = 3,
        combo = { after = "block", bonus = { attack = 3 } },
        tags = { "brute", "combo" },
    },
    {
        id = "iron_guard",
        name = "Iron Guard",
        description = "Ultimate: Gain 5 block and reflect damage this round.",
        cost = 3,
        block = 5,
        ultimate = true,
        tags = { "brute", "ultimate" },
    },
    -- Tactician
    {
        id = "counterplay",
        name = "Counterplay",
        description = "Combo: Play after Feint for +2 attack and block.",
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
        description = "Combo: Play after Rally for +2 attack, but -1 block next round.",
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


-- Add missing fighter-specific cards
local extraFighterCards = {
    -- Ninja
    {
        id = "shadow_step",
        name = "Shadow Step",
        description = "Combo: Play after Dodge for free attack.",
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
        tags = { "ninja", "ultimate" },
    },
    {
        id = "assassinate",
        name = "Assassinate",
        description = "Ultimate: KO if opponent below half HP.",
        cost = 3,
        ultimate = true,
        effect = "ko_below_half_hp",
        tags = { "ninja", "ultimate" },
    },
    -- Boxer
    {
        id = "jab_cross",
        name = "Jab-Cross",
        description = "Combo: Play after Jab for bonus damage.",
        cost = 2,
        attack = 4,
        combo = { after = "punch", bonus = { attack = 2 } },
        tags = { "boxer", "combo" },
    },
    {
        id = "counterpunch",
        name = "Counterpunch",
        description = "Block and retaliate if attacked this round.",
        cost = 2,
        block = 2,
        effect = "retaliate_if_attacked",
        tags = { "boxer", "signature" },
    },
    {
        id = "haymaker",
        name = "Haymaker",
        description = "Ultimate: High damage, can only be played after landing 2 punches in a round.",
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
        description = "Combo: Play after Grapple for extra block and damage.",
        cost = 2,
        attack = 3,
        block = 2,
        combo = { after = "block", bonus = { attack = 2, block = 2 } },
        tags = { "wrestler", "combo" },
    },
    {
        id = "body_slam",
        name = "Body Slam",
        description = "Knock opponent’s card off the board.",
        cost = 2,
        attack = 2,
        effect = "knock_off_board",
        tags = { "wrestler", "signature" },
    },
    {
        id = "powerbomb",
        name = "Powerbomb",
        description = "Ultimate: Massive damage, stuns opponent next round.",
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
        description = "Combo: Play after Block for bonus energy.",
        cost = 2,
        attack = 3,
        combo = { after = "block", bonus = { attack = 2 } },
        tags = { "karate", "combo" },
    },
    {
        id = "meditate",
        name = "Meditate",
        description = "Restore health and energy.",
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
        description = "Deal 4 damage. If played after Rally, gain +2 attack.",
        cost = 2,
        attack = 4,
        combo = { after = "rally", bonus = { attack = 2 } },
        tags = { "brawler", "combo" },
    },
    {
        id = "taunt",
        name = "Taunt",
        description = "Force opponent to attack you.",
        cost = 1,
        effect = "force_attack",
        tags = { "brawler", "signature" },
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

for _, card in ipairs(extraFighterCards) do
    table.insert(defs, card)
end

for _, card in ipairs(fighterCards) do
    table.insert(defs, card)
end

-- Update draft pool in config.lua (manual step required):
-- pool = {
--   { id = "punch", count = 10 },
--   { id = "kick", count = 8 },
--   { id = "block", count = 10 },
--   { id = "guard", count = 6 },
--   { id = "uppercut", count = 4 },
--   { id = "feint", count = 4 },
--   { id = "taunt", count = 3 },
--   { id = "guard_up", count = 3 },
--   { id = "adrenaline_rush", count = 3 },
--   { id = "counter", count = 3 },
--   { id = "roundhouse", count = 2 },
-- }

return defs
