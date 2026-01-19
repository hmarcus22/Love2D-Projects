local screenSizeW, screenSizeH = love.window.getDesktopDimensions( 1 )

local config = {
    window = {
        width = screenSizeW,
        height = screenSizeH,
        title = "Solitair",
        resizable = true,
        fullscreen = false,
    },
    card = {
        width = 100,
        height = 145,
    },
    colors = {
        background = {34, 139, 34}, -- Dark green
        cardBack = {0, 0, 255}, -- Blue
        cardFront = {255, 255, 255}, -- White
        text = {0, 0, 0}, -- Black
    },
    positions = {
        deckX = 50,
        deckY = 50,
        tableauStartX = 200,
        tableauStartY = 50,
        tableauSpacingX = 120,
        tableauSpacingY = 30,
    },
    layout = {
        spacingXRatio = 0.1,
        spacingYRatio = 0.3,
        gapTopMin = 16,
        topRowYOffsetRatio = 0.1,
    },
}
return config
