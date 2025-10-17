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
    
    return isLifted or isInteracting or inAnimation
end

-- Draw hover-style shadow (for UI elements)
function ShadowRenderer.drawHoverStyle(x, y, w, h, height, options)
    options = options or {}
    local alpha = math.min(1, height / 50) * 0.4
    local offset = math.min(height * 0.1, 8)
    
    -- Check for rotation from element if provided in options
    local element = options.element
    local hasRotation = element and element.rotation and element.rotation ~= 0
    
    -- Calculate shadow position
    local shadowX = x + offset
    local shadowY = y + offset
    
    if hasRotation then
        love.graphics.push()
        -- Rotate around shadow center for proper lighting model
        local shadowCenterX = shadowX + w/2
        local shadowCenterY = shadowY + h/2
        love.graphics.translate(shadowCenterX, shadowCenterY)
        love.graphics.rotate(element.rotation)
        love.graphics.translate(-shadowCenterX, -shadowCenterY)
    end
    
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", shadowX, shadowY, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    
    if hasRotation then
        love.graphics.pop()
    end
end

-- Draw card-style shadow (main shadow type)
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
    local heightMultiplier = 0.15  -- How much extra offset per unit of height (increased for better visibility)
    
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
    
    -- Position shadow with dynamic offset
    local sx = x + (w - shadowW) / 2 + dynamicOffsetX
    local sy = y + (h - shadowH) / 2 + dynamicOffsetY
    
    -- Check for transformations (scale and rotation)
    local hasScale = (scaleX ~= 1 or scaleY ~= 1)
    local element = options.element
    local hasRotation = element and element.rotation and element.rotation ~= 0
    local hasTransforms = hasScale or hasRotation
    
    -- Apply transformations if needed
    if hasTransforms then
        love.graphics.push()
        
        -- For shadows: rotate around shadow center, not card center
        -- This maintains proper light source relationship
        local shadowCenterX = sx + shadowW/2
        local shadowCenterY = sy + shadowH/2
        love.graphics.translate(shadowCenterX, shadowCenterY)
        
        -- Apply scale transformation
        if hasScale then
            love.graphics.scale(scaleX, scaleY)
        end
        
        -- Apply rotation transformation (shadow rotates around its own center)
        if hasRotation then
            love.graphics.rotate(element.rotation)
        end
        
        -- Move back to shadow corner for drawing
        love.graphics.translate(-shadowCenterX, -shadowCenterY)
    end
    
    -- Apply proper shadow color and alpha
    love.graphics.setColor(0, 0, 0, enhancedAlpha)
    love.graphics.rectangle("fill", sx, sy, shadowW, shadowH, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    
    if hasTransforms then
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
    
    -- Auto-detect style or use provided style
    local style = options.style or ShadowRenderer.autoDetectStyle(element, options.context)
    
    -- Add element reference for debug output
    options.element = element
    
    -- Draw shadow based on style
    if style == "hover" then
        ShadowRenderer.drawHoverStyle(x, y, w, h, height, options)
    elseif style == "ui" then
        ShadowRenderer.drawUIStyle(x, y, w, h, height, options)
    elseif style == "effect" then
        ShadowRenderer.drawEffectStyle(x, y, w, h, height, options)
    else
        -- Default to card style
        ShadowRenderer.drawCardStyle(x, y, w, h, height, options.scaleX, options.scaleY, options)
    end
end

-- Backwards compatibility functions (now just delegate to drawElementShadow)
function ShadowRenderer.drawCardShadow(card, x, y, w, h, scaleX, scaleY, context)
    ShadowRenderer.drawElementShadow(card, x, y, w, h, {
        context = context or "card",
        style = "card",
        scaleX = scaleX,
        scaleY = scaleY
    })
end

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
    
    -- Debug: Show collection results but only for body_slam to reduce spam
    if Config and Config.debug and Config.debugCategories and Config.debugCategories.shadows then
        local bodySlamCount = 0
        for _, cardInfo in ipairs(allCards) do
            if cardInfo.card.id == "body_slam" then
                bodySlamCount = bodySlamCount + 1
                print(string.format("[SHADOW DEBUG] Body Slam #%d: at (%.0f,%.0f) context=%s", 
                    bodySlamCount, cardInfo.x or 0, cardInfo.y or 0, cardInfo.context))
            end
        end
        if bodySlamCount > 1 then
            print(string.format("[SHADOW DEBUG] WARNING: Found %d body_slam shadows!", bodySlamCount))
        end
    end
    
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
    local processedCards = {}  -- Track cards we've already processed to prevent duplicates
    
    -- Collect hand cards
    if gameState.players then
        for _, player in ipairs(gameState.players) do
            if player.slots then
                for _, slot in ipairs(player.slots) do
                    if slot.card and slot.card ~= gameState.draggingCard then
                        local card = slot.card
                        if not processedCards[card] then
                            processedCards[card] = true
                            -- Use unified scaling for position/size
                            local UnifiedHeightScale = require 'src.unified_height_scale'
                            local layout = gameState:getLayout()
                            local baseW, baseH = layout.cardW or 100, layout.cardH or 150
                            local scaleX, scaleY = UnifiedHeightScale.getDrawScale(card)
                            
                            -- SIMPLE APPROACH: Use same position logic as CardRenderer
                            local x = (card.animX ~= nil) and card.animX or card.x
                            local y = (card.animY ~= nil) and card.animY or card.y
                            
                            table.insert(allCards, {
                                card = card,
                                x = x,
                                y = y, 
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
    end
    
    -- Collect board cards
    if gameState.players then
        for _, player in ipairs(gameState.players) do
            if player.boardSlots then
                for _, slot in ipairs(player.boardSlots) do
                    if slot.card and not processedCards[slot.card] then
                        local card = slot.card
                        processedCards[card] = true
                        
                        -- SIMPLE APPROACH: Use same position logic as CardRenderer
                        local x = (card.animX ~= nil) and card.animX or card.x
                        local y = (card.animY ~= nil) and card.animY or card.y
                        
                        table.insert(allCards, {
                            card = card,
                            x = x,
                            y = y,
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
    
    -- FLIGHT CARDS: Cards that are only in animation system (not in hand/board collections during flight)
    if gameState.animations and gameState.animations.getActiveAnimatingCards then
        local animating = gameState.animations:getActiveAnimatingCards() or {}
        for _, card in ipairs(animating) do
            if card and not processedCards[card] then
                processedCards[card] = true
                
                -- SIMPLE APPROACH: Use same position logic as CardRenderer
                local x = (card.animX ~= nil) and card.animX or card.x
                local y = (card.animY ~= nil) and card.animY or card.y
                
                table.insert(allCards, {
                    card = card,
                    x = x,
                    y = y,
                    w = card.w or 100,
                    h = card.h or 150,
                    scaleX = 1,  -- Animation engine handles scaling via unified system
                    scaleY = 1,
                    context = "flight"
                })
            end
        end
    end
    
    -- Note: Draft cards can be added here if needed
end

-- Keep drawDragShadow for now (handles special drag overlay)
function ShadowRenderer.drawDragShadow(gameState, layout)
    if not gameState.draggingCard then return end
    
    local dragCard = gameState.draggingCard
    local cardW = layout.cardW or 100
    local cardH = layout.cardH or 150
    
    -- Use unified height-scale system for dragged card shadows
    local UnifiedHeightScale = require 'src.unified_height_scale'
    local scaleX, scaleY = UnifiedHeightScale.getDrawScale(dragCard)
    
    ShadowRenderer.drawElementShadow(dragCard, dragCard.x, dragCard.y, cardW, cardH, {
        context = "drag",
        style = "card",
        scaleX = scaleX,
        scaleY = scaleY
    })
end

return ShadowRenderer