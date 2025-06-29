local Input = {}

Input.pressedKeys = {}

function Input:load()
    self.pressedKeys = {}
end

function Input:keypressed(key)
    self.pressedKeys[key] = true
end

function Input:update(dt, player, fireCallback, spawnEnemyCallback)
    local velocity = { x = 0, y = 0 }

    if love.keyboard.isDown("up") then    velocity.y = -1 end
    if love.keyboard.isDown("down") then  velocity.y = 1 end
    if love.keyboard.isDown("left") then  velocity.x = -1 end
    if love.keyboard.isDown("right") then velocity.x = 1 end

    player:move(velocity.x, velocity.y, dt)

    if self.pressedKeys["space"] then
        fireCallback()
    end

    if self.pressedKeys["e"] then
        spawnEnemyCallback()
    end

    if self.pressedKeys["escape"] then
        love.event.quit()
    end

    self.pressedKeys = {} -- Reset after handling
end

return Input