local fighters = {
    brute = {
        id = "brute",
        name = "The Brute",
        shortName = "Brute",
        color = { 0.85, 0.2, 0.2 },
        description = "Red corner favourite who shrugs off blows with raw muscle.",
        passives = {
            boardSlot = {
                block = 1,
            },
        },
        traits = { "red", "cage" },
        favoredTags = { "brute" },
    },
    tactician = {
        id = "tactician",
        name = "Cold Tactician",
        shortName = "Tactician",
        color = { 0.2, 0.4, 0.85 },
        description = "Ice-blue planner who reads the fight one step ahead.",
        passives = {
            -- Reserved for future mechanics, e.g. extra draft choices.
        },
        traits = { "blue", "control" },
        favoredTags = { "tactician" },
    },
    wildcard = {
        id = "wildcard",
        name = "Verdant Wildcard",
        shortName = "Wildcard",
        color = { 0.15, 0.6, 0.35 },
        description = "Green cage artist thriving on improvisation.",
        passives = {
            -- Reserved for future mechanics, e.g. extra energy on resolve.
        },
        traits = { "green", "tempo" },
        favoredTags = { "wildcard" },
    },
}

local order = {
    fighters.brute,
    fighters.tactician,
    fighters.wildcard,
}

return {
    list = order,
    byId = fighters,
}
