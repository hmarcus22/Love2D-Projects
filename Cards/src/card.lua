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
    self.slotIndex = nil
    self.owner = nil
    self.definition = nil -- will be attached by factory
end

function Card:draw()
    -- card background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)

    -- border
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", self.x, self.y, self.w, self.h, 8, 8)

    -- face down card
    if not self.faceUp then
        love.graphics.setColor(0.2, 0.2, 0.6)
        love.graphics.printf("Deck", self.x, self.y + self.h/2 - 6, self.w, "center")
        return
    end

    -- card name
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(self.name, self.x, self.y + 8, self.w, "center")

    if self.definition then
        -- COST (yellow circle top-left)
        if self.definition.cost then
            love.graphics.setColor(0.9, 0.9, 0.3)
            love.graphics.circle("fill", self.x + 15, self.y + 15, 12)
            love.graphics.setColor(0, 0, 0)
            love.graphics.printf(tostring(self.definition.cost),
                self.x, self.y + 9, 30, "center")
        end

        local statY = self.y + 40

        -- ATTACK (red box + label)
        if self.definition.attack and self.definition.attack > 0 then
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.rectangle("fill", self.x + 10, statY, 14, 14)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", self.x + 10, statY, 14, 14)
            love.graphics.printf("Attack: " .. self.definition.attack,
                self.x + 30, statY - 2, self.w - 40, "left")
            statY = statY + 18
        end

        -- BLOCK (blue box + label)
        if self.definition.block and self.definition.block > 0 then
            love.graphics.setColor(0.2, 0.4, 0.8)
            love.graphics.rectangle("fill", self.x + 10, statY, 14, 14)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", self.x + 10, statY, 14, 14)
            love.graphics.printf("Block: " .. self.definition.block,
                self.x + 30, statY - 2, self.w - 40, "left")
            statY = statY + 18
        end

        -- HEAL (green box + label)
        if self.definition.heal and self.definition.heal > 0 then
            love.graphics.setColor(0.2, 0.8, 0.2)
            love.graphics.rectangle("fill", self.x + 10, statY, 14, 14)
            love.graphics.setColor(0, 0, 0)
            love.graphics.rectangle("line", self.x + 10, statY, 14, 14)
            love.graphics.printf("Heal: " .. self.definition.heal,
                self.x + 30, statY - 2, self.w - 40, "left")
            statY = statY + 18
        end

        -- description at the bottom
        if self.definition.description then
            love.graphics.setColor(0.1, 0.1, 0.1)
            -- description area (inside card)
            local descW = self.w - 10
            local descX = self.x + 5
            local descY = self.y + self.h - 60  -- start a bit higher
            local descH = 50                    -- reserve ~50px space

            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.printf(self.definition.description,
                descX, descY, descW, "center")
        end
    end
end

function Card:isHovered(mx, my)
    return mx > self.x and mx < self.x + self.w and my > self.y and my < self.y + self.h
end

return Card
