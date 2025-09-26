-- Example: Logging game events
local GameLogger = require("src.game_logger")
local logger = GameLogger()

-- Log a card play
logger:log_event("card_played", { player = 1, card = "Punch", slot = 2, cost = 1 })

-- Log a pass
logger:log_event("pass", { player = 2 })

-- Log resolve start
logger:log_event("resolve_start", {})

-- Log card placed
logger:log_event("card_placed", { player = 1, card = "Kick", slot = 1 })

-- Log card discarded
logger:log_event("card_discarded", { player = 2, card = "Block", slot = 3 })

-- Log defeat
logger:log_event("defeat", { player = 2 })

-- Save log to file
logger:save("match_log.json")

-- Load log from file
local loaded = logger:load("match_log.json")
for i, event in ipairs(loaded) do
    print(event.event, event.data and event.data.card or "")
end
