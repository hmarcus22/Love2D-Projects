--[[
LEGACY FALLBACK — DEPRECATED
This module is part of the old animation system. It is kept only for reference/fallback during migration.
Do NOT require or call this at runtime. All new code must use the unified system.

Replacement (unified system):

Entry: gs.animations (src/unified_animation_adapter.lua)
Manager: src/unified_animation_manager.lua
Engine: src/unified_animation_engine.lua
Specs: src/unified_animation_specs.lua
Plan: UNIFIED_ANIMATION_PLAN.md
Migration cheatsheet:

was: local AM = require('src.animation_manager').new()

now: local Anim = gs.animations -- adapter instance created in GameState

was: am:add({ type='card_flight', card=c, fromX=..., fromY=..., toX=..., toY=..., onComplete=fn })

now: Anim:add({ type='unified_card_play', card=c, targetX=..., targetY=..., onComplete=fn })
-- or: Anim.unifiedManager:playCard(c, targetX, targetY, 'unified', fn)

was: am:isBusy()

now: Anim:hasActiveAnimations() -- adapter also exposes isBusy() for compatibility

Rendering contract:

During flight/resolve, render cards at card.animX/card.animY/card.animZ.
Ask adapter which cards are animating: gs.animations:getActiveAnimatingCards()
Placement occurs on flight completion; board draws from slot.card after that.
Engine/animators do not draw; renderers own all drawing.
Fallback (only if absolutely needed during migration):

gs.animations:enableMigration(false) -- routes back to legacy paths when present
This legacy file will be removed once the unified system is fully stable.
]]--

-- animation_manager.lua: simple queued animations (initial flight support)
local AnimationManager = {}
AnimationManager.__index = AnimationManager

local function easeOutQuad(t) return 1 - (1 - t) * (1 - t) end
local function easeOutBack(t, s)
    s = s or 1.70158
    t = t - 1
    return (t * t * ((s + 1) * t + s) + 1)
end
local function easeInOutSine(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

function AnimationManager.new()
    return setmetatable({ queue = {} }, AnimationManager)
end

function AnimationManager:add(anim)
    anim.t = 0
    anim.duration = anim.duration or 0.35
    self.queue[#self.queue + 1] = anim
end

function AnimationManager:update(dt)
    if #self.queue == 0 then return end
    for i = #self.queue, 1, -1 do
        local a = self.queue[i]
    local first = (a.t == 0)
    a.t = a.t + dt
    if first and a.onStart then pcall(a.onStart) end
        local p = math.min(1, a.t / a.duration)
        if a.type == "card_flight" and a.card then
            local c = a.card
            -- 1. Raw timeline progress p (0..1)
            -- 2. Flight profile shapes horizontal progress BEFORE easing/overshoot
            local Profiles = require 'src.flight_profiles'
            local profileName = (c.definition and c.definition.flightProfile) or 'default'
            local prof = Profiles.get(profileName)
            local profileFn = prof.horizontal or Profiles.default
            local profP = profileFn(p)
            if profP < 0 then profP = 0 elseif profP > 1 then profP = 1 end
            -- 3. Apply easing / optional overshoot to profP
            local overshoot = a.overshootFactor or 0
            local eased = overshoot > 0 and easeOutBack(profP, 1.70158 * overshoot) or (a.easing or easeOutQuad)(profP)

            if a.slamStyle then
                local verticalMode = a.verticalMode or 'hang_drop'
                local verticalP
                if verticalMode == 'hang_drop' then
                    local dropStart = 0.7
                    if p < dropStart then
                        verticalP = (p / dropStart) * 0.15
                    else
                        local t2 = (p - dropStart) / (1 - dropStart)
                        verticalP = 0.15 + (1 - 0.15) * (t2 * t2)
                    end
                    c.animX = a.fromX + (a.toX - a.fromX) * eased
                    c.animY = a.fromY + (a.toY - a.fromY) * verticalP
                    if a.arcHeight and a.arcHeight > 0 then
                        local dropStartH = 0.7
                        local lift
                        if p < dropStartH then
                            local rise = math.sin((p / dropStartH) * math.pi * 0.5)
                            lift = a.arcHeight * (0.85 + 0.15 * rise)
                        else
                            local t3 = (p - dropStartH) / (1 - dropStartH)
                            lift = a.arcHeight * (1 - (t3 ^ 1.6))
                        end
                        c.animZ = math.max(0, lift)
                    else c.animZ = 0 end
                elseif verticalMode == 'plateau_drop' then
                    -- Maintain mid plateau then sharp fall
                    local plateauEnd = 0.6
                    if p < plateauEnd then
                        verticalP = p * 0.05 -- almost stationary vertically
                    else
                        local t2 = (p - plateauEnd) / (1 - plateauEnd)
                        verticalP = 0.05 + (t2 ^ 1.4) * 0.95
                    end
                    c.animX = a.fromX + (a.toX - a.fromX) * eased
                    c.animY = a.fromY + (a.toY - a.fromY) * verticalP
                    if a.arcHeight and a.arcHeight > 0 then
                        local lift = a.arcHeight * (1 - (math.max(0, (p - plateauEnd)) ^ 1.2))
                        c.animZ = lift
                    else c.animZ = 0 end
                else -- fallback
                    c.animX = a.fromX + (a.toX - a.fromX) * eased
                    c.animY = a.fromY + (a.toY - a.fromY) * eased
                    if a.arcHeight and a.arcHeight > 0 then
                        c.animZ = math.sin(math.pi * profP) * a.arcHeight
                    else c.animZ = 0 end
                end
            else
                -- Standard flight: same easing for X/Y, arc uses pre-eased profP so profile affects arc timing too.
                c.animX = a.fromX + (a.toX - a.fromX) * eased
                c.animY = a.fromY + (a.toY - a.fromY) * eased
                if a.arcHeight and a.arcHeight > 0 then
                    c.animZ = math.sin(math.pi * profP) * a.arcHeight
                else
                    c.animZ = 0
                end
            end
        elseif a.type == "card_impact" and a.card then
            -- If this is the first update tick for impact, resolve any deferred on-play effects
            if a.t == dt and a.card._deferPlayEffects then
                local info = a.card._deferPlayEffects
                a.card._deferPlayEffects = nil
                -- Safely invoke GameState handler (lazy require to avoid cycles)
                local gs = a.gameState
                if gs and gs.handleCardPlayed then
                    local player = gs.players and gs.players[info.playerId]
                    if player then
                        gs:handleCardPlayed(player, a.card, info.slotIndex)
                    end
                end
            end
            local c = a.card
            -- Impact: overshoot squash then settle. Use two phases (0..0.5 squash, 0.5..1 recover)
            local phase = p
            local squashMin = a.squashScale or 0.85
            local sx, sy
            if phase < 0.5 then
                local t = phase / 0.5
                local k = 1 - (1 - t) * (1 - t)
                sy = 1 - (1 - squashMin) * k
                sx = 1 + (1 - sy) * 0.55
            else
                local t = (phase - 0.5) / 0.5
                local k = t * t
                sy = squashMin + (1 - squashMin) * k
                sx = 1 + (1 - sy) * 0.55
            end
            c.impactScaleX = sx
            c.impactScaleY = sy
            c.impactFlash = (a.flashAlpha or 0.5) * (1 - p)
        elseif a.type == "slot_glow" then
            -- p used directly; on draw we compute fade
        elseif a.type == "delay" then
            -- passive wait animation; nothing to update besides time
        end
        if p >= 1 then
            if a.onComplete then pcall(a.onComplete) end
            if a.type == "card_impact" and a.card then
                a.card.impactScaleX = nil
                a.card.impactScaleY = nil
                a.card.impactFlash = nil
            elseif a.type == "card_flight" and a.card then
                a.card.animZ = 0
            end
            table.remove(self.queue, i)
        end
    end
end

function AnimationManager:isBusy()
    return #self.queue > 0
end

function AnimationManager:draw()
    for _, a in ipairs(self.queue) do
        if a.type == "card_flight" and a.card then
            local CardRenderer = require "src.card_renderer"
            local c = a.card
            CardRenderer.draw(c)
            -- Optional debug: hold F3 to sample the horizontal flight profile path.
            if c.definition and c.definition.flightProfile and love.keyboard and love.keyboard.isDown('f3') then
                local Profiles = require 'src.flight_profiles'
                local profileFn = Profiles[c.definition.flightProfile] or Profiles.default
                love.graphics.setColor(1,0.25,0.25,0.55)
                local samples = 28
                for si=0,samples do
                    local sp = si / samples
                    local profP = profileFn(sp)
                    local overshoot = a.overshootFactor or 0
                    local eased = overshoot > 0 and easeOutBack(profP, 1.70158 * overshoot) or (a.easing or easeOutQuad)(profP)
                    local px = a.fromX + (a.toX - a.fromX) * eased + (c.w or 0)/2
                    local py = a.fromY + (a.toY - a.fromY) * eased + (c.h or 0)/2
                    love.graphics.circle('fill', px, py, 2)
                end
                love.graphics.setColor(1,1,1,1)
            end
        elseif a.type == "slot_glow" and a.slot then
            local alpha = (a.maxAlpha or 0.5) * (1 - (a.t / a.duration))
            if alpha > 0.01 then
                love.graphics.setColor(1, 1, 0.4, alpha)
                love.graphics.setLineWidth(4)
                love.graphics.rectangle("line", a.slot.x - 4, a.slot.y - 4, a.slot.w + 8, a.slot.h + 8, 12, 12)
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1,1,1,1)
            end
        end
    end
end

return AnimationManager
