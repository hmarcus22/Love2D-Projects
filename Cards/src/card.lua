local Class = require "libs.hump.class"

local Card = Class{}

function Card:init(id, name, x, y)
    self.id = id
    self.name = name
    self.x, self.y = x or 0, y or 0
    self.w, self.h = 100, 150
    self.faceUp = true
    self.dragging = false
    self.offsetX, self.offsetY = 0, 0
end

function Card:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)

    local text = self.faceUp and self.name or "Deck"
    love.graphics.printf(text, self.x, self.y + self.h/2 - 6, self.w, "center")
end

function Card:isHovered(mx, my)
    return mx > self.x and mx < self.x + self.w and my > self.y and my < self.y + self.h
end

return Card