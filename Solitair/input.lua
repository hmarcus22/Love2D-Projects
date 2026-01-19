local Input = {}

function Input.bind(target)
    love.keypressed = function(key)
        if key == "escape" then
            love.event.quit()
        elseif key == "r" and target and target.reset then
            target:reset()
        end
    end

    love.mousepressed = function(x, y, button)
        if target and target.mousePressed then
            target:mousePressed(x, y, button)
        elseif button == 1 and target and target.startDrag then
            target:startDrag(x, y)
        end
    end

    love.mousereleased = function(x, y, button)
        if target and target.mouseReleased then
            target:mouseReleased(x, y, button)
        elseif button == 1 and target and target.endDrag then
            target:endDrag(x, y)
        end
    end

    love.mousemoved = function(x, y)
        if target and target.mouseMoved then
            target:mouseMoved(x, y)
        elseif target and target.dragTo then
            target:dragTo(x, y)
        end
    end
end

return Input
