local fighters = {
    brute = {
        enabled = false,
        id = "brute",
        name = "The Brute",
        shortName = "Brute",
        color = { 0.85, 0.2, 0.2 },
        description = "Red-corner slugger who shrugs off blows with raw muscle.",
        passives = {
            boardSlot = {
                block = 1,
            },
        },
        traits = { "red", "cage" },
        favoredTags = { "brute" },
        starterCards = { "punch", "kick", "block" },
        signatureCards = { "ground_pound", "iron_guard" },
        ultimate = "iron_guard",
        comboCards = { "ground_pound" },
    },
    tactician = {
        enabled = false,
        id = "tactician",
        name = "Cold Tactician",
        shortName = "Tactician",
        color = { 0.2, 0.4, 0.85 },
        description = "Ice-blue planner who reads the fight one step ahead.",
        passives = {
            draw = {
                roundStart = 2,
            },
        },
        traits = { "blue", "control" },
        favoredTags = { "tactician" },
        starterCards = { "feint", "block", "hex" },
        signatureCards = { "counterplay", "tactical_shift" },
        ultimate = "tactical_shift",
        comboCards = { "counterplay" },
    },
    wildcard = {
        enabled = false,
        id = "wildcard",
        name = "Verdant Wildcard",
        shortName = "Wildcard",
        color = { 0.15, 0.6, 0.35 },
        description = "Green cage artist whose attacks fluctuate +/-1.",
        passives = {
            attackVariance = { amount = 1 },
        },
        traits = { "green", "tempo" },
        favoredTags = { "wildcard" },
        starterCards = { "kick", "rally", "banner" },
        signatureCards = { "wild_swing", "nature_fury" },
        ultimate = "nature_fury",
        comboCards = { "wild_swing" },
    },
    ninja = {
        enabled = true,
        id = "ninja",
        name = "Shadow Ninja",
        shortName = "Ninja",
        portrait = "assets/fighters/Shadow_Ninja.png",
        color = { 0.2, 0.2, 0.2 },
        description = "Master of stealth footwork and devastating combos.",
        starterCards = { "feint", "block", "kick" },
        signatureCards = { "shadow_step", "smoke_bomb" },
        ultimate = "assassinate",
        comboCards = { "shadow_step" },
        favoredTags = { "ninja" },
        traits = { "stealth", "combo" },
    },
    boxer = {
        enabled = true,
        id = "boxer",
        name = "Iron Boxer",
        shortName = "Boxer",
        portrait = "assets/fighters/Iron_boxer.png",
        color = { 0.9, 0.7, 0.3 },
        description = "Punches hard and builds toward the haymaker.",
        starterCards = { "punch", "block", "kick" },
        signatureCards = { "jab_cross", "counterpunch" },
        ultimate = "haymaker",
        comboCards = { "jab_cross" },
        favoredTags = { "boxer" },
        traits = { "power", "combo" },
    },
    wrestler = {
        enabled = true,
        id = "wrestler",
        name = "Steel Wrestler",
        shortName = "Wrestler",
        portrait = "assets/fighters/Street_Wrestler.png",
        color = { 0.7, 0.5, 0.2 },
        description = "Throws and grapples for big crowd-pleasing slams.",
        starterCards = { "block", "kick", "punch" },
        signatureCards = { "suplex", "body_slam" },
        ultimate = "powerbomb",
        comboCards = { "suplex" },
        favoredTags = { "wrestler" },
        traits = { "grapple", "combo" },
    },
    karate_master = {
        enabled = true,
        id = "karate_master",
        name = "Karate Master",
        shortName = "Karate",
        portrait = "assets/fighters/Karate_Master.png",
        color = { 0.9, 0.9, 0.9 },
        description = "Channels focus into devastating kicks and calm recovery.",
        starterCards = { "block", "kick", "block" },
        signatureCards = { "focus_strike", "meditate" },
        ultimate = "dragon_kick",
        comboCards = { "focus_strike" },
        favoredTags = { "karate" },
        traits = { "focus", "combo" },
    },
    street_brawler = {
        enabled = true,
        id = "street_brawler",
        name = "Street Brawler",
        shortName = "Brawler",
        portrait = "assets/fighters/Steel_Brawler.png",
        color = { 0.7, 0.3, 0.1 },
        description = "Unpredictable and tough, fights dirty when needed.",
        starterCards = { "punch", "kick", "block" },
        signatureCards = { "bottle_smash", "taunt" },
        ultimate = "rage_unleashed",
        comboCards = { "bottle_smash" },
        favoredTags = { "brawler" },
        traits = { "wild", "combo" },
    },
}

-- Remove unused fighters from catalog
fighters.brute = nil
fighters.tactician = nil
fighters.wildcard = nil

local order = {}
for _, f in pairs(fighters) do
    if f.enabled then
        table.insert(order, f)
    end
end

return {
    list = order,
    byId = fighters,
}

