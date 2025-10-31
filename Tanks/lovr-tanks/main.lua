-- Adjust Lua module paths for local libs/src
package.path = table.concat({
  package.path,
  'lib/?.lua',
  'lib/?/init.lua',
  'lib/hump/?.lua',
  'src/?.lua',
  'src/?/init.lua',
  'src/core/?.lua',
  'src/game/?.lua'
}, ';')

-- Explicitly require the Game module from src/game.lua
local Game = require 'game'
local game

function lovr.load()
  game = Game()
end

function lovr.update(dt)
  if game then game:update(dt) end
end

function lovr.draw(pass)
  if game then 
    game:draw(pass)  -- 3D world rendering
  end
  if lovr.graphics and lovr.graphics.submit then
    lovr.graphics.submit(pass)
  end
end

-- Backup the original mirror function
local originalMirror = lovr.mirror

function lovr.mirror(pass)
  if originalMirror then
    originalMirror(pass)  -- Show the 3D scene first
  end
  if game then
    game:drawHUD(pass)  -- Then overlay the 2D HUD
  end
end

function lovr.keypressed(key, scancode, repeating)
  if game and game.keypressed then game:keypressed(key) end
end

function lovr.keyreleased(key, scancode)
  if game and game.keyreleased then game:keyreleased(key) end
end
