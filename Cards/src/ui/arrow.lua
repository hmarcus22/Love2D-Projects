local Class = require "libs.hump.class"
local Vector = require "libs.hump.vector"
local Config = require "src.config"

local Arrow = Class()

function Arrow:init(startPos, endPos, opts)
    opts = opts or {}
    self.start = Vector(startPos.x or startPos[1], startPos.y or startPos[2])
    self.finish = Vector(endPos.x or endPos[1], endPos.y or endPos[2])
    self.color = opts.color or Config.colors.arrow
    self.thickness = opts.thickness or Config.ui.arrowThickness
    self.headSize = opts.headSize or Config.ui.arrowHeadSize
end

function Arrow:draw()
    love.graphics.setColor(self.color)
    love.graphics.setLineWidth(self.thickness)
    love.graphics.line(self.start.x, self.start.y, self.finish.x, self.finish.y)

    -- Draw arrowhead
    local dir = (self.finish - self.start):normalized()
    local perp = Vector(-dir.y, dir.x)
    local headBase = self.finish - dir * self.headSize
    local left = headBase + perp * (self.headSize * 0.5)
    local right = headBase - perp * (self.headSize * 0.5)
    love.graphics.polygon("fill",
        self.finish.x, self.finish.y,
        left.x, left.y,
        right.x, right.y
    )
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Arrow
