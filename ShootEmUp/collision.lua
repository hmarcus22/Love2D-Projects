local Class = require "hump.class"
local Vector = require "hump.vector"

local Collision = Class{}

function Collision:check(a, b)
    if a.shape == "rectangle" and b.shape == "rectangle" then
        return self:checkRectRect(a, b)
    elseif a.shape == "rectangle" and b.shape == "circle" then
        return self:checkRectCircle(a, b)
    elseif a.shape == "circle" and b.shape == "rectangle" then
        return self:checkRectCircle(b, a)
    elseif a.shape == "circle" and b.shape == "circle" then
        return self:checkCircleCircle(a, b)
    end
    return false
end

function Collision:checkAll(sourceList, targetList, callback)
    for i = #sourceList, 1, -1 do
        local a = sourceList[i]
        for j = #targetList, 1, -1 do
            local b = targetList[j]
            if self:check(a, b) then
                callback(a, b, i, j)
            end
        end
    end
end

function Collision:checkRectRect(a, b)
    local aMin = a.pos - a.size / 2
    local aMax = a.pos + a.size / 2
    local bMin = b.pos - b.size / 2
    local bMax = b.pos + b.size / 2

    return aMax.x > bMin.x and aMin.x < bMax.x and aMax.y > bMin.y and aMin.y < bMax.y
end

function Collision:checkRectCircle(rect, circle)
    local closestPoint = Vector(
        math.max(rect.pos.x - rect.size.x / 2, math.min(circle.pos.x, rect.pos.x + rect.size.x / 2)),
        math.max(rect.pos.y - rect.size.y / 2, math.min(circle.pos.y, rect.pos.y + rect.size.y / 2))
    )
    return (closestPoint - circle.pos):len() < circle.size.x
end

function Collision:checkCircleCircle(a, b)
    return (a.pos - b.pos):len() < (a.size.x / 2 + b.size.x / 2)
end

function Collision:debugDraw(entity)
    if entity.shape == "rectangle" then
        love.graphics.setColor(1, 1, 0, 0.4)
        love.graphics.rectangle("line", entity.pos.x, entity.pos.y, entity.size.x, entity.size.y)
    elseif entity.shape == "circle" then
        love.graphics.setColor(1, 1, 0, 0.4)
        love.graphics.circle("line", entity.pos.x, entity.pos.y, entity.size.x)
    end
end

return Collision