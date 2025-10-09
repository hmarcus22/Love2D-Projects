# Working Context & Style Guide

## How You Like to Work
- **Direct & Practical**: You prefer concrete fixes over theoretical discussions
- **Visual Feedback**: You test changes immediately and report what you see
- **Incremental Progress**: Make one focused change at a time, test, then iterate
- **Debug-Driven**: You like comprehensive debug output to understand what's actually happening
- **Problem-Focused**: "X doesn't work" → find root cause → fix it → verify
- **No Over-Engineering**: Keep solutions simple and targeted

## Current Session Context

### **The Core Problem**
- Animation system calculates positions correctly (debug shows this works)
- Cards are NOT visually moving during flight animations
- Attack cards should show smooth flight from hand to board
- Modifier cards work fine (they fade and apply correctly)

### **What We Know Works** ✅
- Animation phases execute correctly: preparation → launch → flight → approach → impact → settle → board_state → game_resolve
- Position calculations are accurate: `[FLIGHT] Applied position - animX: 275.2 animY: 400.3`
- CardRenderer properly checks for animX/animY: `local x = (card.animX ~= nil) and card.animX or card.x`
- Animation timing is good (~0.93s total, feels responsive)

### **What We Know Doesn't Work** ❌
- Cards render at static position despite animX/animY being set
- Debug shows: `[CardRenderer] Drawing animated card at x=274 y=448 (animX=nil animY=nil)`
- Visual animation missing for attack cards specifically

### **Root Cause Analysis**
The animation system sets animX/animY correctly during flight, but by the time CardRenderer draws the card, these properties are nil. This suggests:
1. Something is clearing animX/animY between calculation and rendering
2. The rendering happens at the wrong time in the frame
3. There's a timing issue between animation updates and drawing

## Technical Architecture

### **Animation Flow**
```
User plays card → UnifiedAnimationManager.playCard() 
→ UnifiedAnimationEngine.startAnimation() 
→ Update loop: GameState:update() → UnifiedAdapter:update() → Manager:update() → Engine:update()
→ Rendering: anim_lab:draw() → player:drawHand() → CardRenderer.draw()
```

### **Key Files & Their Roles**
- `unified_animation_engine.lua`: Core animation logic, sets animX/animY
- `card_renderer.lua`: Checks animX/animY, falls back to x/y
- `player.lua`: Draws hand cards via CardRenderer.draw()
- `anim_lab.lua`: Test environment, calls player:drawHand()

### **Critical Properties**
- `card.animX`, `card.animY`: Current animated position (set by animation engine)
- `card.x`, `card.y`: Base/final position
- `card._unifiedAnimationActive`: Flag indicating animation in progress

## Debugging Strategy

### **What to Check When Animations Don't Work**
1. Are positions being calculated? Look for `[FLIGHT] Applied position`
2. Are properties being set? Look for `animX=` values in CardRenderer debug
3. Is timing correct? Check if clearing happens before or after rendering
4. Is the right render path being used? Check which CardRenderer method is called

### **Debug Commands to Add**
```lua
-- In animation engine when setting positions
print("[DEBUG] Setting animX=" .. x .. " animY=" .. y .. " for " .. card.id)

-- In card renderer when reading positions
print("[DEBUG] Reading animX=" .. (card.animX or "nil") .. " animY=" .. (card.animY or "nil"))

-- Check timing of clears
print("[DEBUG] Clearing animX/animY for " .. card.id .. " at " .. love.timer.getTime())
```

## Anti-Patterns to Avoid

### **Things That Waste Time**
- Long discussions about animation theory without testing
- Making multiple changes at once
- Assuming the problem is in one specific file
- Not checking if the basic case works first

### **Common Traps**
- Animation engine complexity makes us think the problem is in the engine
- Actually it's often a simple timing/rendering issue
- We debug the animation calculation instead of the rendering path
- We fix the wrong phase of the animation

## Next Action Protocol

### **When Stuck on Animation Issues**
1. **Verify the basics**: Does the simplest case work?
2. **Add minimal debug**: Where exactly does animX/animY go from set to nil?
3. **Check one render frame**: What happens in a single update→draw cycle?
4. **Find the gap**: Where in the chain does the data get lost?
5. **Make minimal fix**: Change only what's needed to bridge the gap

### **When You Report Issues**
- State exactly what you see vs. what you expect
- Include any error messages
- Mention if it's different from before
- Say which cards you tested (attack vs modifier)

## Current Investigation

### **Immediate Focus**
The animX/animY properties are being set correctly during flight phase but are nil when CardRenderer tries to use them. Need to find:
1. What clears these properties?
2. When does the clearing happen relative to rendering?
3. Is it a timing issue or a code flow issue?

### **Next Steps**
1. Add debug to show exactly when animX/animY are cleared
2. Add debug to show the exact timing of render calls
3. Find the gap and patch it with minimal changes