-- unified_height_scale.lua
-- Unified system for card height calculation and height-based scaling
-- Replaces scattered scaling logic throughout the codebase

local UnifiedHeightScale = {}

-- Import shadow renderer for height calculation (avoiding circular dependency)
local ShadowRenderer = require 'src.renderers.shadow_renderer'

-- Configuration for height-to-scale mapping
local DEFAULT_CONFIG = {
    -- Height scaling parameters
    baseScale = 1.0,           -- Base scale when at ground level
    maxHeightScale = 0.2,      -- Maximum additional scale (20% increase)
    heightScaleReference = 250, -- Height at which max scale is reached
    
    -- Scale curve parameters
    scaleRampPower = 1.0,      -- Power for scale ramp (1.0 = linear, 2.0 = quadratic)
    
    -- Compatibility with legacy systems
    legacyHoverScale = 0.2,    -- Legacy hover scale (20%)
    legacyHoverHeight = 50,    -- Height equivalent to full legacy hover
}

-- Get configuration from Config with fallbacks
local function getConfig()
    local Config = require 'src.config'
    local config = {}
    
    -- Use config values if available, otherwise use defaults
    for key, defaultValue in pairs(DEFAULT_CONFIG) do
        if Config.heightScale and Config.heightScale[key] ~= nil then
            config[key] = Config.heightScale[key]
        else
            config[key] = defaultValue
        end
    end
    
    return config
end

-- Calculate effective height for any card/element
-- Uses the same logic as ShadowRenderer to ensure consistency
function UnifiedHeightScale.calculateHeight(element)
    return ShadowRenderer.calculateEffectiveHeight(element)
end

-- Convert height to visual scale factor
function UnifiedHeightScale.heightToScale(height)
    local config = getConfig()
    
    if height <= 0 then
        return config.baseScale
    end
    
    -- Normalize height to 0-1 range
    local heightRatio = math.min(height / config.heightScaleReference, 1.0)
    
    -- Apply curve (power function for different ramp shapes)
    local curvedRatio = math.pow(heightRatio, config.scaleRampPower)
    
    -- Calculate final scale
    local scale = config.baseScale + (config.maxHeightScale * curvedRatio)
    
    return scale
end

-- Get unified scale for any card/element
function UnifiedHeightScale.getCardScale(element)
    local height = UnifiedHeightScale.calculateHeight(element)
    return UnifiedHeightScale.heightToScale(height)
end

-- Get scale factors for drawing (scaleX, scaleY)
function UnifiedHeightScale.getDrawScale(element, baseScaleX, baseScaleY)
    baseScaleX = baseScaleX or 1.0
    baseScaleY = baseScaleY or 1.0
    
    local heightScale = UnifiedHeightScale.getCardScale(element)
    
    return baseScaleX * heightScale, baseScaleY * heightScale
end

-- Get hover-equivalent scale (for backward compatibility)
-- This allows legacy systems to query "what hover amount would give this scale?"
function UnifiedHeightScale.getEquivalentHoverAmount(element)
    local config = getConfig()
    local scale = UnifiedHeightScale.getCardScale(element)
    local scaleIncrease = scale - config.baseScale
    
    -- Convert scale increase back to hover amount (0-1)
    local hoverAmount = scaleIncrease / config.legacyHoverScale
    return math.max(0, math.min(1, hoverAmount))
end

-- Validation function to check if height and scale are consistent
function UnifiedHeightScale.validateConsistency(element, expectedScale, tolerance)
    tolerance = tolerance or 0.01
    local actualScale = UnifiedHeightScale.getCardScale(element)
    local difference = math.abs(actualScale - expectedScale)
    
    return difference <= tolerance, actualScale, difference
end

-- Debug function to show height-scale relationship
function UnifiedHeightScale.debugInfo(element, label)
    local Config = require 'src.config'
    if not (Config and Config.debug and Config.debugCategories and Config.debugCategories.heightScale) then
        return
    end
    
    local height = UnifiedHeightScale.calculateHeight(element)
    local scale = UnifiedHeightScale.getCardScale(element)
    local hoverEquiv = UnifiedHeightScale.getEquivalentHoverAmount(element)
    local elementId = element.id or "unknown"
    local isDragging = element.dragging or false
    local hasHover = (element.handHoverAmount and element.handHoverAmount > 0) or false
    local hasAnimZ = (element.animZ and element.animZ > 0) or false
    
    print(string.format("[UNIFIED-SCALE] %s (%s): height=%.1f → scale=%.3f (hover equiv: %.2f) [drag=%s, hover=%.2f, animZ=%.1f]", 
          elementId, label or "card", height, scale, hoverEquiv, 
          tostring(isDragging), element.handHoverAmount or 0, element.animZ or 0))
end

-- Migration helpers for existing systems
UnifiedHeightScale.Migration = {
    -- Convert from legacy hover system
    fromHoverAmount = function(hoverAmount)
        local config = getConfig()
        local height = hoverAmount * config.legacyHoverHeight
        return UnifiedHeightScale.heightToScale(height)
    end,
    
    -- Convert to legacy hover system  
    toHoverAmount = function(height)
        local config = getConfig()
        return math.max(0, math.min(1, height / config.legacyHoverHeight))
    end
}

return UnifiedHeightScale