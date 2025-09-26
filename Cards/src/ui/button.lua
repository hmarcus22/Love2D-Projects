local Class = require "libs.hump.class"
local Config = require "src.config"

local Button = Class()

function Button:init(args)
    self.x = args.x or 0
    self.y = args.y or 0
    self.w = args.w or Config.ui.buttonW
    self.h = args.h or Config.ui.buttonH
    self.label = args.label or "Button"
    self.onClick = args.onClick or function() end
    self.enabled = args.enabled ~= false
    self.visible = args.visible ~= false
    self.color = args.color or Config.colors.button
    self.hoveredColor = args.hoveredColor or Config.colors.buttonHover
    self.textColor = args.textColor or {1, 1, 1, 1}
    self.id = args.id
end

function Button:draw()
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    local hovered = self:isHovered(mx, my)
    local color = hovered and self.hoveredColor or self.color
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)
    love.graphics.setColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4] or 1)
    local font = love.graphics.getFont()
    local textH = 16
    if font and type(font.getDimensions) == "function" then
        local _, h = font:getDimensions(self.label)
        textH = h or 16
    end
    local textY = self.y + (self.h - textH) / 2
    love.graphics.printf(self.label, self.x, textY, self.w, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function Button:isHovered(mx, my)
    return self.enabled and self.visible and mx >= self.x and mx <= self.x + self.w and my >= self.y and my <= self.y + self.h
end

function Button:click(mx, my)
    if self:isHovered(mx, my) then
        self.onClick(self)
        return true
    end
    return false
end

return Button
