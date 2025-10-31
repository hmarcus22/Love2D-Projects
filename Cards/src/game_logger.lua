-- GameLogger: records game actions for replay and analysis
local Class = require("libs.HUMP.class")

-- Optional JSON dependency (guarded)
local JSON = nil
do
    local ok, mod = pcall(require, 'dkjson')
    if ok and type(mod) == 'table' then
        JSON = mod
    end
end

local GameLogger = Class{
    init = function(self)
        self.log = {}
        self.enabled = true
    end
}

function GameLogger:init()
    self.log = {}
    self.enabled = true
end

function GameLogger:record(action, params)
    if not self.enabled then return end
    table.insert(self.log, {
        time = love.timer.getTime(),
        action = action,
        params = params or {}
    })
end

function GameLogger:getLog()
    return self.log
end

function GameLogger:clear()
    self.log = {}
end

function GameLogger:saveToFile(filename)
    if not filename or type(filename) ~= "string" or filename == "" then return false end
    if not JSON or not JSON.encode then
        print("[GameLogger] dkjson not available; cannot save log.")
        return false
    end
    local okEncode, encoded = pcall(JSON.encode, self.log, { indent = true })
    if not okEncode then
        print("[GameLogger] JSON encode failed:", encoded)
        return false
    end
    local okWrite, err = love.filesystem.write(filename, encoded)
    if not okWrite then
        print("[GameLogger] Failed to write log:", err)
        return false
    end
    return true
end

function GameLogger:loadFromFile(filename)
    if not filename or type(filename) ~= "string" or filename == "" then return nil end
    if not love.filesystem.getInfo(filename) then return nil end
    if not JSON or not JSON.decode then
        print("[GameLogger] dkjson not available; cannot load log.")
        return nil
    end
    local contents = love.filesystem.read(filename)
    if not contents then return nil end
    local okDecode, log = pcall(JSON.decode, contents)
    if not okDecode then
        print("[GameLogger] JSON decode failed:", log)
        return nil
    end
    self.log = log or {}
    return self.log
end

function GameLogger:log_event(action, params)
    self:record(action, params)
end

return GameLogger
