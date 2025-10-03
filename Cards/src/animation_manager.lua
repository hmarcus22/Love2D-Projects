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
            local overshoot = a.overshootFactor or 0
            local baseEase
            if c.definition and c.definition.flightProfile == 'slam_body' then
                -- slam_body profile: accelerate quickly to cover ~70% horizontal distance fast,
                -- then slow approach (anticipation) before vertical drop handled by slamStyle logic.
                -- Custom profile: fast accel (easeOutQuad first half) then ease in (slow) before drop
                if p < 0.55 then
                    local halfP = p / 0.55
                    baseEase = 1 - (1 - halfP)*(1 - halfP) -- outQuad portion
                    baseEase = baseEase * 0.70 -- compress to 70% distance early
                else
                    local tailP = (p - 0.55) / 0.45
                    -- easeInSine like (1 - cos(pi * t))/2, but reversed to slow into position
                    local k = (math.sin((tailP) * math.pi * 0.5)) -- gentle
                    baseEase = 0.70 + k * 0.30
                end
            else
                baseEase = overshoot > 0 and easeOutBack(p, 1.70158 * overshoot) or (a.easing or easeOutQuad)(p)
            end
            local eased = baseEase
            -- Slam style: hang high for first 70%, then fast vertical drop last 30%
            if a.slamStyle then
                -- Body Slam variant: card races horizontally, hangs high, then plunges hard.
                local dropStart = 0.7 -- last 30% is the slam/drop window
                local verticalP
                if p < dropStart then
                    -- Keep vertical progress very shallow: only ~15% of the way down before drop
                    verticalP = (p / dropStart) * 0.15
                else
                    local t = (p - dropStart) / (1 - dropStart)
                    -- Accelerated quadratic descent from 15% -> 100%
                    verticalP = 0.15 + (1 - 0.15) * (t * t)
                end
                local x = a.fromX + (a.toX - a.fromX) * eased
                local y = a.fromY + (a.toY - a.fromY) * verticalP
                c.animX = x
                c.animY = y
                if a.arcHeight and a.arcHeight > 0 then
                    -- Maintain a plateau near max height, then drop sharply
                                local baseEase = (a.easing or easeOutQuad)(p)
                                local profileName = (c.definition and c.definition.flightProfile) or 'default'
                                local Profiles = require 'src.flight_profiles'
                                local profileFn = Profiles[profileName] or Profiles.default
                                -- Horizontal progress shaped by profile AFTER base easing (profile expects linear-ish input)
                                local eased = profileFn(baseEase)
                    local arcP = p
                    local lift = math.sin(math.pi * arcP) * a.arcHeight
                    c.animZ = lift
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
            -- Temporarily override card position for draw
            local c = a.card
            local ox, oy = c.x, c.y
            c.animX = a.card.animX -- already set in update; CardRenderer uses animX/animY
            c.animY = a.card.animY
            CardRenderer.draw(c)
            -- Keep animX/animY for next frame until completion clears them
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
