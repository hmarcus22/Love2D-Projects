-- shadow_renderer.lua
-- Unified shadow system for all game elements (cards, UI, effects, etc.)
-- Replaces both HoverUtils.drawShadow and CardRenderer.drawCardShadow with height-responsive shadows

local ShadowRenderer = {}

-- Get shadow configuration from config with fallbacks
local function getShadowConfig(type, key, fallback)
    local Config = require 'src.config'
    local shadows = Config.ui and Config.ui.shadows
    if shadows and shadows[type] and shadows[type][key] ~= nil then
        return shadows[type][key]
    end
    -- Legacy config fallbacks for cards
    if type == "card" then
        local ui = Config.ui or {}
        if key == "minScale" then return ui.cardShadowMinScale or fallback end
        if key == "maxScale" then return ui.cardShadowMaxScale or fallback end
        if key == "minAlpha" then return ui.cardShadowMinAlpha or fallback end
        if key == "maxAlpha" then return ui.cardShadowMaxAlpha or fallback end
        if key == "arcHeight" then return ui.cardFlightArcHeight or fallback end
    end
    -- Legacy config fallbacks for hover shadows
    if type == "hover" then
        local highlights = Config.layout and Config.layout.highlights
        if highlights and highlights.shadow and highlights.shadow[key] ~= nil then
            return highlights.shadow[key]
        end
    end
    return fallback
end

-- Calculate effective height from multiple sources
function ShadowRenderer.calculateEffectiveHeight(element, heightSources)
    local height = 0
    
    -- Priority order: dragging > animation > hover (avoid double-counting)
    if element.dragging then
        -- Dragging cards use fixed height regardless of other states
        height = height + 50  -- Same as max hover since visual scale is identical
    elseif element.animZ and element.animZ > 0 then
        -- Animation height takes priority over hover
        height = height + element.animZ
    elseif element.handHoverAmount then
        -- Hover only applies if not dragging or animating
        height = height + (element.handHoverAmount * 50) -- Hover lift
    end
    
    -- Standard elevation (always applies)
    height = height + (element.elevation or 0)       -- Explicit elevation
    
    -- Custom height sources for specific element types
    if heightSources then
        for _, source in ipairs(heightSources) do
            if type(source) == "function" then
                height = height + source(element)
            elseif type(source) == "string" and element[source] then
                height = height + element[source]
            end
        end
    end
    
    return math.max(0, height)
end

-- Auto-detect appropriate shadow style based on element state and context
function ShadowRenderer.autoDetectStyle(element, context)
    if context then
        if context == "hand" or context == "draft" then return "hover" end
        if context == "flight" or context == "board" or context == "animation" then return "card" end
        if context == "ui" then return "ui" end
        if context == "effect" then return "effect" end
    end
    
    -- Auto-detect based on element properties
    if element.handHoverAmount and (element.handHoverAmount > 0.01) then
        return "hover"
    end
    
    if element._unifiedAnimationActive or element.animX or element.animY then
        return "card"
    end
    
    -- Default to card style for backward compatibility
    return "card"
end

-- Determine shadow lifecycle (when to show shadow)
function ShadowRenderer.shouldShowShadow(element, height, options)
    options = options or {}
    
    -- Always show if explicitly enabled
    if options.forceShow then return true end
    
    -- Never show if explicitly disabled
    if options.forceHide or element._suppressShadow then return false end
    
    -- Show shadow for any elevation, interaction, or animation
    local isLifted = height > 0
    local isInteracting = element.dragging or (element.handHoverAmount and element.handHoverAmount > 0.02)
    local inAnimation = element._unifiedAnimationActive or element.animX or element.animY
    local hasAnimationPhase = element.animX or element.animY or element._unifiedAnimationActive
    
    return isLifted or isInteracting or inAnimation or hasAnimationPhase
end

-- Draw hover-style shadow (two-layer, fixed offsets)
function ShadowRenderer.drawHoverStyle(x, y, w, h, height, options)
    options = options or {}
    local hoverAmount = options.hoverAmount or math.min(1, height / 50) -- Convert height back to hover amount
    
    if hoverAmount <= 0.01 then return end
    
    local minAlpha = getShadowConfig('hover', 'minAlpha', 0.25)
    local maxAlpha = getShadowConfig('hover', 'maxAlpha', 0.55)
    local alpha = minAlpha + (maxAlpha - minAlpha) * hoverAmount
    
    -- Outer shadow layer
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", x + 2, y + 2, w + 12, h + 12, 10, 10)
    
    -- Inner shadow layer  
    love.graphics.setColor(0, 0, 0, alpha * 0.3)
    love.graphics.rectangle("fill", x + 1, y + 1, w + 6, h + 6, 8, 8)
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw card-style shadow (single rectangle, height-responsive)
function ShadowRenderer.drawCardStyle(x, y, w, h, height, scaleX, scaleY, options)
    options = options or {}
    scaleX = scaleX or 1
    scaleY = scaleY or 1
    
    local shadowScaleMin = getShadowConfig('card', 'minScale', 0.95)  -- Small shadow at ground level
    local shadowScaleMax = getShadowConfig('card', 'maxScale', 1.2)   -- Large shadow at max height
    local shadowAlphaMin = getShadowConfig('card', 'minAlpha', 0.25)
    local shadowAlphaMax = getShadowConfig('card', 'maxAlpha', 0.55)
    local arcRef = getShadowConfig('card', 'arcHeight', 140)
    
    -- Height-responsive scaling and alpha
    local norm = 0
    if arcRef > 0 then norm = math.min(1, height / arcRef) end
    local sScale = shadowScaleMin + (shadowScaleMax - shadowScaleMin) * norm  -- Larger shadows with height
    local sAlpha = shadowAlphaMax - (shadowAlphaMax - shadowAlphaMin) * norm
    
    -- Dynamic shadow offset based on height - higher cards cast longer shadows
    local baseOffsetX = 3  -- Minimum shadow offset
    local baseOffsetY = 4
    local heightMultiplier = 0.15  -- Increased from 0.05 - more dramatic shadows
    
    local dynamicOffsetX = baseOffsetX + (height * heightMultiplier)
    local dynamicOffsetY = baseOffsetY + (height * heightMultiplier)
    
    -- Debug: Show height-responsive calculations for specific cases
    local Config = require 'src.config'
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        if (options.element and options.element.dragging) or (options.element and options.element.id == "body_slam") then
            local cardId = options.element.id or "unknown"
            local isDragging = options.element.dragging or false
            print(string.format("[ShadowRenderer-DRAG] %s dragging=%s: Height=%.1f, norm=%.2f, scale=%.2f, alpha=%.2f", 
                  cardId, tostring(isDragging), height, norm, sScale, sAlpha))
            print(string.format("[ShadowRenderer-DRAG] Shadow size: %.1fx%.1f (card: %.1fx%.1f)", 
                  w * sScale, h * sScale, w, h))
        end
    end
    
    -- Apply custom shadow data if available (for flight animations)
    if options.shadowData then
        sAlpha = options.shadowData.opacity or sAlpha
        sScale = sScale * (options.shadowData.scale or 1.0)
    end
    
    -- Enhanced shadow visibility for better gameplay feedback
    local enhancedAlpha = math.max(sAlpha * 1.5, 0.6)
    
    local shadowW = w * sScale
    local shadowH = h * sScale * 0.98
    
    -- Dynamic shadow offset based on height - higher cards cast longer shadows
    local baseOffsetX = 3  -- Minimum shadow offset
    local baseOffsetY = 4
    local heightMultiplier = 0.15  -- How much extra offset per unit of height (increased for better visibility)
    
    local dynamicOffsetX = baseOffsetX + (height * heightMultiplier)
    local dynamicOffsetY = baseOffsetY + (height * heightMultiplier)
    
    local sx = x + (w - shadowW) / 2 + dynamicOffsetX
    local sy = y + (h - shadowH) / 2 + dynamicOffsetY
    
    -- Apply shadow offset if available
    if options.shadowData then
        sx = sx + (options.shadowData.offsetX or 0)
        sy = sy + (options.shadowData.offsetY or 0)
    end
    
    -- Handle scaling context
    if scaleX ~= 1 or scaleY ~= 1 then
        love.graphics.push()
        local cx, cy = x + w/2, y + h/2
        love.graphics.translate(cx, cy)
        love.graphics.scale(scaleX, scaleY)
        love.graphics.translate(-cx, -cy)
    end
    
    -- Apply proper shadow color and alpha
    love.graphics.setColor(0, 0, 0, enhancedAlpha)
    love.graphics.rectangle("fill", sx, sy, shadowW, shadowH, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    
    if scaleX ~= 1 or scaleY ~= 1 then
        love.graphics.pop()
    end
end

-- Draw UI-style shadow (future expansion)
function ShadowRenderer.drawUIStyle(x, y, w, h, height, options)
    -- Placeholder for future UI element shadows
    ShadowRenderer.drawHoverStyle(x, y, w, h, height, options)
end

-- Draw effect-style shadow (future expansion)  
function ShadowRenderer.drawEffectStyle(x, y, w, h, height, options)
    -- Placeholder for future effect shadows with color support
    options = options or {}
    local color = options.color or {0, 0, 0}
    local alpha = math.min(1, height / 100) * 0.5
    
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.rectangle("fill", x + 4, y + 4, w + 8, h + 8, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Track previous values for change detection
local debugTracker = {}
local debugFrameCounter = 0

-- Main shadow rendering function for any game element
function ShadowRenderer.drawElementShadow(element, x, y, w, h, options)
    options = options or {}
    
    -- Calculate effective height from element state
    local height = ShadowRenderer.calculateEffectiveHeight(element, options.heightSources)
    
    -- Debug: Show shadow calculations only when values change or every 60 frames
    local Config = require 'src.config'
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        local cardId = element.id or "unknown"
        local key = cardId .. "_" .. (options.context or "none")
        local prev = debugTracker[key] or {}
        
        debugFrameCounter = debugFrameCounter + 1
        local forceShow = (debugFrameCounter % 60 == 0) -- Show every 60 frames
        
        -- Check if important values changed
        local heightChanged = math.abs((prev.height or 0) - height) > 0.5
        local contextChanged = (prev.context or "") ~= (options.context or "")
        local positionChanged = math.abs((prev.x or 0) - x) > 2 or math.abs((prev.y or 0) - y) > 2
        
        if heightChanged or contextChanged or positionChanged or forceShow then
            print(string.format("[SHADOW-CHANGE] %s: height=%.1f (was %.1f), context=%s, pos=(%.0f,%.0f)", 
                  cardId, height, prev.height or 0, options.context or "none", x, y))
            
            -- Store new values
            debugTracker[key] = {
                height = height,
                context = options.context,
                x = x,
                y = y
            }
        end
    end
    
    -- Check if shadow should be shown
    if not ShadowRenderer.shouldShowShadow(element, height, options) then
        return
    end
    
    -- Determine shadow style
    local style = options.style or ShadowRenderer.autoDetectStyle(element, options.context)
    
    -- Apply appropriate shadow style
    if style == "hover" then
        ShadowRenderer.drawHoverStyle(x, y, w, h, height, options)
    elseif style == "card" then
        options.element = element  -- Pass element for debugging
        ShadowRenderer.drawCardStyle(x, y, w, h, height, options.scaleX, options.scaleY, options)
    elseif style == "ui" then
        ShadowRenderer.drawUIStyle(x, y, w, h, height, options)
    elseif style == "effect" then
        ShadowRenderer.drawEffectStyle(x, y, w, h, height, options)
    end
end

-- Convenience function for card shadows (backward compatibility)
function ShadowRenderer.drawCardShadow(card, x, y, w, h, scaleX, scaleY, context)
    -- Debug: Confirm unified system is being called
    if Config and Config.debug and card.id == "body_slam" then
        print("[UNIFIED SHADOW] ShadowRenderer.drawCardShadow called for " .. (card.id or "unknown"))
    end
    
    ShadowRenderer.drawElementShadow(card, x, y, w, h, {
        context = context or "auto",
        style = "card",
        scaleX = scaleX,
        scaleY = scaleY,
        shadowData = card.shadowData
    })
end

-- Convenience function for hover shadows (backward compatibility)
function ShadowRenderer.drawHoverShadow(element, x, y, w, h, hoverAmount)
    ShadowRenderer.drawElementShadow(element, x, y, w, h, {
        context = "hover",
        style = "hover", 
        hoverAmount = hoverAmount
    })
end

-- TRULY UNIFIED SHADOW SYSTEM 
-- Single function that draws shadows for ALL cards using unified height calculation
function ShadowRenderer.drawAllShadows(gameState)
    local Config = require 'src.config'
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        print("[SHADOW DEBUG] drawAllShadows called - UNIFIED VERSION")
    end
    
    if not gameState then return end
    
    local allCards = {}
    
    -- Collect ALL cards from all sources
    ShadowRenderer.collectAllCards(gameState, allCards)
    
    -- Draw shadows for all collected cards using unified height calculation
    for _, cardInfo in ipairs(allCards) do
        local card = cardInfo.card
        local x, y, w, h = cardInfo.x, cardInfo.y, cardInfo.w, cardInfo.h
        
        if card and x and y and w and h then
            -- Use unified height calculation - this is the ONLY shadow calculation needed
            local height = ShadowRenderer.calculateEffectiveHeight(card)
            
            -- Only draw shadow if card has meaningful height or is in a shadow-worthy state
            if ShadowRenderer.shouldShowShadow(card, height) then
                ShadowRenderer.drawElementShadow(card, x, y, w, h, {
                    context = cardInfo.context,
                    style = "card",  -- Always use card style with unified height
                    scaleX = cardInfo.scaleX,
                    scaleY = cardInfo.scaleY,
                    heightSources = cardInfo.heightSources
                })
            end
        end
    end
end

-- Collect all cards from all game locations into a single list
function ShadowRenderer.collectAllCards(gameState, allCards)
    -- Collect hand cards
    if gameState.players then
        for _, player in ipairs(gameState.players) do
            if player.slots then
                for _, slot in ipairs(player.slots) do
                    if slot.card and slot.card ~= gameState.draggingCard then
                        local card = slot.card
                        -- Use unified scaling for position/size
                        local UnifiedHeightScale = require 'src.unified_height_scale'
                        local layout = gameState:getLayout()
                        local baseW, baseH = layout.cardW or 100, layout.cardH or 150
                        local scaleX, scaleY = UnifiedHeightScale.getDrawScale(card)
                        
                        table.insert(allCards, {
                            card = card,
                            x = card.x,
                            y = card.y, 
                            w = baseW,
                            h = baseH,
                            scaleX = scaleX,
                            scaleY = scaleY,
                            context = "hand"
                        })
                    end
                end
            end
        end
    end
    
    -- Collect board cards  
    if gameState.players then
        for _, player in ipairs(gameState.players) do
            if player.boardSlots then
                for _, slot in ipairs(player.boardSlots) do
                    if slot.card then
                        local card = slot.card
                        table.insert(allCards, {
                            card = card,
                            x = (card.animX ~= nil) and card.animX or card.x,
                            y = (card.animY ~= nil) and card.animY or card.y,
                            w = card.w,
                            h = card.h,
                            scaleX = card.impactScaleX or card.scale or 1,
                            scaleY = card.impactScaleY or card.scale or 1,
                            context = "board"
                        })
                    end
                end
            end
        end
    end
    
    -- Collect flight cards
    if gameState.animations and gameState.animations.getActiveAnimatingCards then
        local animating = gameState.animations:getActiveAnimatingCards() or {}
        for _, card in ipairs(animating) do
            if card and card.animX and card.animY then
                table.insert(allCards, {
                    card = card,
                    x = card.animX,
                    y = card.animY,
                    w = card.w or 100,
                    h = card.h or 150,
                    scaleX = 1,  -- Animation engine will handle scaling via unified system
                    scaleY = 1,
                    context = "flight"
                })
            end
        end
    end
    
    -- Note: Draft cards can be added here if needed
end
    if not gameState.players then return end
    
    for index, player in ipairs(gameState.players) do
        if player.slots then
            for _, slot in ipairs(player.slots) do
                if slot.card then
                    local card = slot.card
                    -- Skip if card is being dragged (will be handled separately)
                    -- Skip if card is currently animating (will be handled by flight shadows)
                    if card ~= gameState.draggingCard and not card._unifiedAnimationActive then
                        local amount = card.handHoverAmount or 0
                        if amount > 0.01 then
                            -- Use card's current position (already calculated by Player:drawHand)
                            local x, y, w, h = card.x, card.y, card.w, card.h
                            if x and y and w and h then
                                -- Apply hover scaling
                                local HoverUtils = require 'src.ui.hover_utils'
                                local hoverScale = layout.handHoverScale or 0.06
                                local dx, dy, dw, dh = HoverUtils.scaledRect(x, y, w, h, amount, hoverScale)
                                
                                ShadowRenderer.drawElementShadow(card, dx, dy, dw, dh, {
                                    context = "hand",
                                    style = "hover",
                                    hoverAmount = amount
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Draw shadows for cards on the board
function ShadowRenderer.drawBoardShadows(gameState, layout)
    if not gameState.players then return end
    
    for _, player in ipairs(gameState.players) do
        if player.boardSlots then
            for _, slot in ipairs(player.boardSlots) do
                if slot.card then
                    local card = slot.card
                    -- Skip if card is currently animating (will be handled by flight shadows)
                    if not card._unifiedAnimationActive then
                        -- Use card's current position (may include animation offsets)
                        local x = (card.animX ~= nil) and card.animX or card.x
                        local y = (card.animY ~= nil) and card.animY or card.y
                        local w, h = card.w, card.h
                    
                    if x and y and w and h then
                        ShadowRenderer.drawElementShadow(card, x, y, w, h, {
                            context = "board",
                            style = "card",
                            scaleX = card.impactScaleX or card.scale or 1,
                            scaleY = card.impactScaleY or card.scale or 1,
                            shadowData = card.shadowData
                        })
                    end
                    end  -- Close the animation check
                end
            end
        end
    end
end

function ShadowRenderer.drawFlightShadows(gameState, layout)
    local Config = require 'src.config'
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        print("[SHADOW DEBUG] Starting drawFlightShadows")
    end
    
    if not gameState.animations then 
        if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
            print("[SHADOW DEBUG] No animations object")
        end
        return 
    end
    
    if not gameState.animations.getActiveAnimatingCards then 
        if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
            print("[SHADOW DEBUG] No getActiveAnimatingCards method")
        end
        return 
    end
    
    local animating = gameState.animations:getActiveAnimatingCards() or {}
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        print("[SHADOW DEBUG] Found", #animating, "animating entries")
        
        -- Debug: Look for bodyslam specifically in the animation system
        local hasBodySlam = false
        for i, card in ipairs(animating) do
            if card and card.id == "body_slam" then
                hasBodySlam = true
                print(string.format("[SHADOW DEBUG] FOUND body_slam in slot %d: animX=%.1f, animY=%.1f, animZ=%.1f", 
                      i, card.animX or 0, card.animY or 0, card.animZ or 0))
            end
        end
        
        if not hasBodySlam and #animating > 0 then
            print("[SHADOW DEBUG] Cards in animation but no body_slam found")
        end
    end
    
    local defaultW = layout.cardW or 100
    local defaultH = layout.cardH or 150
    
    for _, card in ipairs(animating) do
        if card.id == "body_slam" then
            print("[SHADOW DEBUG] body_slam - animX=" .. tostring(card.animX) .. " animY=" .. tostring(card.animY))
        end
        -- Only draw shadow if card is actually in flight (has animation position)
        if card.animX and card.animY then
            local x = card.animX
            local y = card.animY
            local w = card.w or defaultW
            local h = card.h or defaultH
            
            if card.id == "body_slam" then
                print("[SHADOW DEBUG] Drawing RED shadow for body_slam at " .. x .. "," .. y)
            end
            
            ShadowRenderer.drawElementShadow(card, x, y, w, h, {
                context = "flight",
                style = "card",
                scaleX = card.impactScaleX or card.scale or 1,
                scaleY = card.impactScaleY or card.scale or 1,
                shadowData = card.shadowData
            })
        end
    end
end

-- Draw shadows for draft cards (if in draft state)
function ShadowRenderer.drawDraftShadows(gameState, layout)
    -- This will be called but won't do anything unless we're in draft mode
    -- Draft shadows are handled by the draft state itself during its draw phase
end

-- Draw shadow for dragged card
function ShadowRenderer.drawDragShadow(gameState, layout)
    if gameState.draggingCard then
        local card = gameState.draggingCard
        
        -- Debug: Check drag card properties
        local Config = require 'src.config'
        if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
            print(string.format("[SHADOW-DRAG] Drag card %s: dragging=%s, animZ=%.1f, hover=%.3f, pos=(%.0f,%.0f)", 
                  card.id or "unknown", tostring(card.dragging), card.animZ or 0, card.handHoverAmount or 0, 
                  card.x or 0, card.y or 0))
        end
        
        if card.x and card.y and card.w and card.h then
            ShadowRenderer.drawElementShadow(card, card.x, card.y, card.w, card.h, {
                context = "drag",
                style = "card",
                shadowData = card.shadowData
            })
        end
    end
end

return ShadowRenderer