bullets = {}
enemies = {}

function love.load()
    player = {x = 400, y = 300, speed = 200}
    
end

function love.keypressed(key)
    if key == "space" then
        table.insert(bullets, {x = player.x + 16, y = player.y})
    end
    if key == "e" then
        table.insert(enemies, {x = love.math.random(16 , 784), y = 0, speed = 120})
    end
    if key == "escape" then
        love.event.quit()
    end
end

function love.update(dt)
    --Check player input
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
    -- Update bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.y = b.y -300 * dt
        if b.y < 0 then
            table.remove(bullets, i)
        end
    end
    --Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e.y = e.y + e.speed * dt
        if e.y > 600 then
            table.remove(enemies, i)
        end
    end

end

function love.draw()
    --Playerr
    love.graphics.rectangle("fill", player.x, player.y, 32, 32)
    --Bullets
    for _, b in ipairs(bullets) do
        love.graphics.rectangle("fill", b.x, b.y, 4, 10)
    end
    --Enemies
    for _, e in ipairs(enemies) do
        love.graphics.rectangle("fill", e.x, e.y, 32, 32)
    end
end