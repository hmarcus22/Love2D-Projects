local BoardEffects = {}

-- Active knockback animations
local activeKnockbacks = {}

function BoardEffects.triggerKnockback(sourceCard, impactX, impactY, board, knockbackSpec, shouldFadeOut, gameState)
  if not knockbackSpec.enabled then return end
  
  local affectedCards = {}
  
  -- Find cards within knockback radius
  for i, slot in ipairs(board or {}) do
    if slot.card and slot.card ~= sourceCard then
      -- CORE LOGIC: Calculate card center position for distance check
      local cardCenterX = slot.card.x + (slot.card.w or 0)/2
      local cardCenterY = slot.card.y + (slot.card.h or 0)/2
      
      if cardCenterX and cardCenterY then
        -- CORE LOGIC: Distance calculation from impact point
        local dx = cardCenterX - impactX
        local dy = cardCenterY - impactY
        local distance = math.sqrt(dx * dx + dy * dy)
        
        -- CORE LOGIC: Radius check
        if distance <= knockbackSpec.radius then
          -- CORE LOGIC: Force calculation begins here
          local forceFactor = 1.0
          if knockbackSpec.falloff == "linear" then
            forceFactor = 1.0 - (distance / knockbackSpec.radius)
          elseif knockbackSpec.falloff == "quadratic" then
            local t = distance / knockbackSpec.radius
            forceFactor = 1.0 - (t * t)
          end
          
          -- Calculate knockback direction
          local knockX, knockY = 0, 0
          if knockbackSpec.direction == "radial" then
            if distance > 0 then
              knockX = (dx / distance) * knockbackSpec.force * forceFactor
              knockY = (dy / distance) * knockbackSpec.force * forceFactor
            end
          elseif knockbackSpec.direction == "directional" then
            local angle = math.rad(knockbackSpec.angle or 0)
            knockX = math.cos(angle) * knockbackSpec.force * forceFactor
            knockY = math.sin(angle) * knockbackSpec.force * forceFactor
          end
          
          -- Start knockback animation for this card
          table.insert(affectedCards, {
            card = slot.card,
            startX = slot.card.x,
            startY = slot.card.y,
            knockX = knockX,
            knockY = knockY,
            duration = knockbackSpec.duration,
            timer = 0,
            fadeOut = shouldFadeOut or false,
            originalAlpha = slot.card.alpha or 1.0,
            gameState = gameState, -- Store for card removal when animation completes
            -- Random rotation for each bounce - varied but not too extreme
            rotationDirection = (math.random() > 0.5) and 1 or -1, -- Random clockwise/counterclockwise
            rotationIntensity = math.random() * 0.5 + 0.1, -- Moderate rotation variation (0.1 to 0.6 radians)
            
            -- First bounce: Strong impact reaction with varied spin
            bounce1Rotation = (math.random() - 0.5) * 0.6, -- Moderate rotation (-0.3 to +0.3 radians, ~17 degrees max)
            bounce1SpinSpeed = math.random() * 2.0 + 0.8, -- How fast the card spins during first bounce (0.8-2.8x speed)
            
            -- Second bounce: Less energy, different spin characteristics  
            bounce2Rotation = (math.random() - 0.5) * 0.6, -- Weaker rotation for second bounce
            bounce2SpinSpeed = math.random() * 1.5 + 0.5, -- Slower spin on second bounce
            
            -- Impact distance affects bounce intensity
            distanceMultiplier = 1.0 - (distance / knockbackSpec.radius), -- Cards closer to impact bounce more
          })
        end
      end
    end
  end
  
  -- Add to active animations
  for _, knockback in ipairs(affectedCards) do
    table.insert(activeKnockbacks, knockback)
  end
end

function BoardEffects.update(dt)
  -- Update all active knockback animations
  for i = #activeKnockbacks, 1, -1 do
    local kb = activeKnockbacks[i]
    kb.timer = kb.timer + dt

    if kb.timer >= kb.duration then
      -- Animation complete
      if kb.fadeOut then
        -- Fade out complete - actually remove card from board
        kb.card.alpha = 0
        kb.card.animX = nil
        kb.card.animY = nil
        kb.card.rotation = nil
        
        -- Remove from board slot (find and clear the slot)
        if kb.gameState then
          for _, player in ipairs(kb.gameState.players or {}) do
            for _, slot in ipairs(player.boardSlots or {}) do
              if slot.card == kb.card then
                slot.card = nil
                break
              end
            end
          end
        end
      else
        -- Return to original position
        kb.card.animX = kb.startX
        kb.card.animY = kb.startY
        kb.card.alpha = kb.originalAlpha
        kb.card.rotation = nil
      end
      table.remove(activeKnockbacks, i)
    else
      -- Update card with scale-based bounce effect
      local t = kb.timer / kb.duration
      
      -- Phase breakdown for IMPACT SHOCK WAVE effect (1 second total):
      -- 0.0-0.25s: Initial impact reaction (faster, snappier bounce)
      -- 0.2-0.45s: Quick secondary bounce (overlaps with first, starts before first completes)
      -- 0.45-1.0s: Final settle and fade
      
      local bounceX, bounceY = 0, 0
      local scaleX, scaleY = 1.0, 1.0
      local rotation = 0
      
      if t < 0.25 then
        -- FIRST BOUNCE (0-0.25s) - Faster, snappier impact bounce
        local bounce1 = t / 0.25  -- Faster first bounce
        local bounceHeight1 = math.sin(bounce1 * math.pi) -- Natural arc
        
        -- ACCUMULATING PUSH: Cards get pushed away and stay there
        local pushProgress = bounce1 -- 0 to 1 - how far we've pushed the card
        bounceX = kb.knockX * pushProgress * 0.25  -- Build up to final pushed position
        
        -- Main vertical bounce - PUSH UP more dramatically
        local firstBounceY = (kb.knockY * pushProgress * 0.25) - (bounceHeight1 * 50 * kb.distanceMultiplier)  -- Much more dramatic movement
        
        -- Scale effect for first bounce
        local heightScale1 = 1.0 + (bounceHeight1 * 0.15 * kb.distanceMultiplier)  -- Stronger scale effect
        
        -- First bounce rotation
        local spinAmount1 = kb.bounce1Rotation * (bounce1 * kb.bounce1SpinSpeed)
        local rotation1 = spinAmount1 * kb.rotationDirection
        
        -- SECOND BOUNCE OVERLAP: Starts at t=0.2, overlaps with first bounce
        local secondBounceY = 0
        local heightScale2 = 1.0
        local rotation2 = 0
        
        if t >= 0.2 then
          local bounce2 = (t - 0.2) / 0.25  -- Second bounce from 0.2 to 0.45
          local bounceHeight2 = math.sin(bounce2 * math.pi) -- Quick secondary arc
          
          -- MAINTAIN PUSH: Don't add movement, just add bounce effect to existing push
          secondBounceY = -(bounceHeight2 * 25 * kb.distanceMultiplier) -- Dramatic second bounce push
          
          -- Second bounce scale adds to first
          heightScale2 = 1.0 + (bounceHeight2 * 0.06 * kb.distanceMultiplier)  -- Stronger second bounce scale
          
          -- Second bounce rotation
          local spinAmount2 = kb.bounce2Rotation * (bounce2 * kb.bounce2SpinSpeed * 1.5)
          rotation2 = spinAmount2 * kb.rotationDirection
        end
        
        -- COMBINE BOTH BOUNCES: Additive effects
        bounceY = firstBounceY + secondBounceY
        scaleX = heightScale1 + (heightScale2 - 1.0) -- Add scale effects
        scaleY = scaleX
        rotation = rotation1 + rotation2 -- Add rotations
        
      elseif t < 0.45 then
        -- SECOND BOUNCE COMPLETION (0.25-0.45s) - Only second bounce active
        local bounce2 = (t - 0.2) / 0.25
        local bounceHeight2 = math.sin(bounce2 * math.pi)
        
        -- MAINTAIN FINAL PUSH POSITION: Cards stay at their pushed location
        bounceX = kb.knockX * 0.25 * kb.distanceMultiplier  -- Stay at full pushed position
        bounceY = (kb.knockY * 0.25 * kb.distanceMultiplier) - (bounceHeight2 * 25 * kb.distanceMultiplier)  -- Dramatic push back
        
        -- Second bounce scale
        scaleX = 1.0 + (bounceHeight2 * 0.06 * kb.distanceMultiplier)  -- Stronger scale
        scaleY = scaleX
        
        -- Combined rotation from both bounces
        local firstSpin = kb.bounce1Rotation * kb.bounce1SpinSpeed
        local secondSpin = kb.bounce2Rotation * (bounce2 * kb.bounce2SpinSpeed * 1.5)
        rotation = (firstSpin + secondSpin) * kb.rotationDirection
        
      else
        -- FINAL SETTLE (0.45-1.0s) - Cards settle where they landed
        local settle = (t - 0.45) / 0.55
        
        -- STAY AT PUSHED POSITION: Cards remain where they were knocked to
        bounceX = kb.knockX * 0.25 * kb.distanceMultiplier  -- Stay at final pushed position
        bounceY = kb.knockY * 0.25 * kb.distanceMultiplier  -- Stay at final pushed position
        scaleX = 1.0
        scaleY = 1.0
        
        -- Final combined rotation
        local totalSpin = (kb.bounce1Rotation * kb.bounce1SpinSpeed) + (kb.bounce2Rotation * kb.bounce2SpinSpeed * 1.5)
        rotation = totalSpin * kb.rotationDirection
      end
      
      -- Apply effects to card
      kb.card.animX = kb.startX + bounceX
      kb.card.animY = kb.startY + bounceY
      kb.card.rotation = rotation
      kb.card.impactScaleX = scaleX
      kb.card.impactScaleY = scaleY
      
      -- Apply position and rotation
      kb.card.animX = kb.startX + bounceX
      kb.card.animY = kb.startY + bounceY
      kb.card.rotation = rotation
      
      -- Handle fade out during final phase
      if kb.fadeOut and t > 0.7 then
        local fadeProgress = (t - 0.7) / 0.3 -- fade over final 30%
        kb.card.alpha = kb.originalAlpha * (1 - fadeProgress)
      else
        kb.card.alpha = kb.originalAlpha
      end
    end
  end
end

function BoardEffects.reset()
  -- Clear all active effects and reset card positions
  for _, kb in ipairs(activeKnockbacks) do
    kb.card.animX = kb.startX
    kb.card.animY = kb.startY
  end
  activeKnockbacks = {}
end

function BoardEffects.isActive()
  return #activeKnockbacks > 0
end

return BoardEffects