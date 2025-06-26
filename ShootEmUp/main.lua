bullets = {}

function love.load()
    player = {x = 400, y = 300, speed = 200}
end

function love.keypressed(key)
    if key == "space" then
        table.insert(bullets, {x = player.x + 16, y = player.y})
    end
end

function love.update(dt)
    if love.keyboard.isDown("up") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("down") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("left") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("right") then
        player.x = player.x + player.speed * dt
    end

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.y = b.y -300 * dt
        if b.y < 0 then
            table.remove(bullets, i)
        end
    end

end

function love.draw()
    love.graphics.rectangle("fill", player.x, player.y, 32, 32)
    for _, b in ipairs(bullets) do
        love.graphics.rectangle("fill", b.x, b.y, 4, 10)
    end
end