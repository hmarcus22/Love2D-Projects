local Class = require "hump.class"
local Vector = require "hump.vector"

local Collision = Class{}

    function Collision:check(a, b)

        if a.shape == "rectangle" and b.shape == "rectangle" then
            return checkRectangleCollision(a, b)
        end
         if a.shape == "rectangle" and b.shape == "circle" then
        return checkRectangleCircleCollision(a, b)
        end
    
        if a.shape == "circle" and b.shape == "rectangle" then
            return checkRectangleCircleCollision(b, a)
        end
    
        if a.shape == "circle" and b.shape == "circle" then
            return checkCircleCollision(a, b)
        end
    
    -- If unknown shapes are detected
    return false
        
    end

    function checkRectangleCollision(a, b)
        
        local aMin = a.pos - a.size / 2
        local aMax = a.pos + a.size / 2
        local bMin = b.pos - b.size / 2
        local bMax = b.pos + b.size / 2

        return aMax.x > bMin.x and aMin.x < bMax.x and aMax.y > bMin.y and aMin.y < bMax.y
    end

    function checkRectangleCircleCollision(rect, circle)
        -- Find the closest point on the rectangle to the circle's center
        local closestPoint = Vector(
            math.max(rect.pos.x - rect.size.x / 2, math.min(circle.pos.x, rect.pos.x + rect.size.x / 2)),
            math.max(rect.pos.y - rect.size.y / 2, math.min(circle.pos.y, rect.pos.y + rect.size.y / 2))
        )

        -- Calculate the distance from the circle's center to this closest point
        local distance = (closestPoint - circle.pos):len()

        -- If the distance is less than the circle's radius, there's a collision
        return distance < circle.size.x / 2
    end

    function checkCircleCollision(a, b)
        local distance = (a.pos - b.pos):len()
        return distance < (a.size.x / 2 + b.size.x / 2)
    end

return Collision