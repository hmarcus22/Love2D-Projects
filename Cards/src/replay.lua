-- Replay implementation using GameLogger
local GameLogger = require("src.game_logger")
local GameState = require("src.gamestate")

local function replay_match(log_path)
    local logger = GameLogger()
    local events = logger:loadFromFile(log_path)
    if not events then
        print("No log found at " .. log_path)
        return
    end

    local gs = GameState:new() -- or GameState:newFromDraft(...) for drafted games
    for i, event in ipairs(events) do
        local e = event.event
        local d = event.data or {}
        if e == "card_played" then
            -- Simulate card play
            local player = gs.players[d.player]
            local card = nil
            for _, c in ipairs(player.hand) do
                if c.name == d.card then card = c break end
            end
            if card then
                gs:playCardFromHand(card, d.slot)
            end
        elseif e == "pass" then
            gs:passTurn()
        elseif e == "card_placed" then
            -- Already handled by playCardFromHand
        elseif e == "card_discarded" then
            -- Discard logic handled in resolve
        elseif e == "resolve_start" then
            -- Start resolve phase
            gs:startResolve()
        elseif e == "defeat" then
            print("Player " .. d.player .. " defeated!")
        end
        -- Add delay or rendering here for step-by-step replay
    end
    print("Replay finished.")
end

-- Example usage:
-- replay_match("match_log.json")

return replay_match
