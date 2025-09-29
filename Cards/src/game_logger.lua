-- GameLogger: records game actions for replay and analysis
local Class = require("libs.HUMP.class")

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
    local file = love.filesystem.newFile(filename, "w")
    file:open("w")
    file:write(require('dkjson').encode(self.log, { indent = true }))
    file:close()
end

function GameLogger:loadFromFile(filename)
    if not filename or type(filename) ~= "string" or filename == "" then return nil end
    if not love.filesystem.getInfo(filename) then return nil end
    local contents = love.filesystem.read(filename)
    local log = require('dkjson').decode(contents)
    self.log = log or {}
    return self.log
end

function GameLogger:log_event(action, params)
    self:record(action, params)
end

return GameLogger