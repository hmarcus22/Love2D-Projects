function lovr.conf(t)
  -- Desktop (non‑VR) setup
  t.modules.headset = false

  -- Window configuration for landscape 16:10 aspect ratio
  t.window.title = "LÖVR Tanks (2.5D)"
  t.window.resizable = true
  t.window.width = 1280   -- Landscape: width > height
  t.window.height = 800   -- 16:10 aspect ratio
  t.window.fullscreen = false

  -- Graphics
  t.graphics.antialias = true
  t.graphics.vsync = true
end