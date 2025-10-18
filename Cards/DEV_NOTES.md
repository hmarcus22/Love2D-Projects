Project Structure and Conventions

Overview

- states/ — High‑level screens and flow control (no core rules):
  - src/states/menu.lua, fighter_select.lua, draft.lua, game.lua, pause.lua
- logic/ — Headless game rules and orchestration (no Love2D calls):
  - src/logic/actions.lua — play/pass/advance; energy checks; combo/variance prep
  - src/logic/resolve.lua — resolution queue + step handlers (block/attack/heal/cleanup)
  - src/logic/round_manager.lua — end‑of‑resolve KO/round/match handling
  - src/logic/player_manager.lua — player init/turn order/round state
  - src/logic/game_initialiser.lua — UI stacks, resolve state, initial energy/hands
  - src/logic/targeting.lua — targeting math (retarget, AOE)
- renderers/ — Pure drawing and HUD helpers (no rules):
  - src/renderers/board_renderer.lua, hud_renderer.lua, resolve_renderer.lua
- animations/ — Unified 3D animation system (NEWLY IMPLEMENTED):
  - src/unified_animation_engine.lua — Physics-based animation with 8 phases
  - src/unified_animation_specs.lua — Centralized animation configuration
  - src/board_state_animator.lua — Ongoing card animations while on board
  - src/resolve_animator.lua — Combat animation effects
  - src/unified_animation_manager.lua — Coordinates all animation systems
  - src/unified_animation_adapter.lua — Migration compatibility layer
- core/objects — Cards, players, decks, layout:
  - src/card.lua, card_factory.lua, card_definitions.lua
  - src/player.lua, deck.lua, game_layout.lua, viewport.lua
- orchestrator
  - src/gamestate.lua — Thin facade that wires logic + renderers and holds runtime state

Key Boundaries

- logic/ may not require renderers or use Love2D APIs; pass data back to GameState.
- renderers/ do not implement rules — only visualize state passed in.
- animations/ provide pure visual enhancement without affecting game logic.
- states/ compose screens, route inputs, and transition between phases.

## Rendering Architecture Principles (CRITICAL)

**The Problem**: Mixing game logic with rendering decisions leads to complex handover issues, z-order problems, and maintenance overhead.

**Core Principle**: **Separate what owns an object from how it gets rendered**

### Unified Rendering Rules

1. **One Renderer Per Visual Element Type**
   - All cards use CardRenderer.draw() regardless of game state (hand/board/flight)
   - All shadows use ShadowRenderer regardless of card location
   - No exceptions based on animation state or ownership

2. **Renderers Never Make Game Logic Decisions**
   - No `isOnBoard()`, `isAnimating()`, or phase checks in renderers
   - No ownership logic like "which system should render this card"
   - Renderers only use visual properties: position, scale, rotation, alpha

3. **Game Logic Collects, Renderers Draw**
   - GameState:draw() determines what's visible (game logic)
   - Renderers receive complete lists and draw everything (visual logic)
   - Clear separation: collection vs rendering

4. **Consistent Position Logic Everywhere**
   - All systems use identical position calculation: `(card.animX ~= nil) and card.animX or card.x`
   - No special cases or different position logic per renderer
   - Visual position is the single source of truth

### Positioning Conventions (Cards)

- Layout owners write `card.x`/`card.y` every frame
  - Hand/board placement (Player:positionHand, BoardRenderer) own the logical position and will update `x,y` each frame.

- Animations must write to `card.animX`/`card.animY`
  - Any time-based motion during animations (flight, resolve strike/push, offsets) should set `animX/animY`.
  - Renderers resolve position as: `local x = (card.animX ~= nil) and card.animX or card.x` (same for Y).
  - This ensures layout does not fight animations (BoardRenderer intentionally resets `x,y` each frame).

- Clear animation channels on completion
  - When an animation finishes, set `card.animX = nil; card.animY = nil` so layout regains full control.
  - For height and alpha, use `card.animZ` and `card.animAlpha` similarly; clear these on completion as well.

- Do not write to `card.x`/`card.y` inside animation phase updates
  - Use `x/y` only to set a final stable logical position (e.g., when a flight lands), or when reading the original position for deltas.

- Example
  - During phase update: `card.animX = state.originalX + vx * t; card.animY = state.originalY + vy * t`
  - On completion: `card.animX, card.animY = nil, nil`

- Temporary draw overrides must restore state
  - If a draw helper temporarily changes `card.x/y` (e.g., `CardRenderer.drawAt`), it must restore them before returning.

### Anti-Patterns to Avoid

❌ **Multiple renderers for same element type**: BoardRenderer vs AnimationOverlay both drawing cards
❌ **Game state checks in renderers**: `if phase == 'flight' then render()`  
❌ **Scattered position logic**: Different renderers calculating position differently
❌ **Handover complexity**: "Who should render this card right now?"

### The Clean Architecture

```lua
function GameState:draw()
    -- 1. Game logic: collect all visible elements
    local allCards = self:getAllVisibleCards()  -- One collection function
    
    -- 2. Rendering: draw in proper z-order
    ShadowRenderer.drawAllShadows(allCards)     -- All shadows first
    for _, card in ipairs(allCards) do
        CardRenderer.draw(card)                 -- All cards second, same renderer
    end
end
```

Entry Points

- Turn flow: GameState delegates to logic/actions.lua (passTurn, advanceTurn, play handlers)
- Resolve flow: GameState calls logic/resolve.lua (startResolve, performResolveStep)
- Round end: logic/round_manager.lua (finishResolve) decides KO, scoring, next round/match end
- Targeting: logic/targeting.lua is the single source of truth (used by board renderer and resolve)

Conventions

- No Love2D calls or renderer requires in logic/.
- If a system is reused in multiple places and is not UI, prefer placing it in logic/.
- Logging: use GameState:addLog for gameplay; gate console debug behind Config.debug.
- Costs: GameState:getEffectiveCardCost is the hook for discounts/auras (keep non‑negative).
- Effects: GameState:applyCardEffectsDuringAttack is the single place for one‑off effects; consider extracting to logic/effects.lua if it grows.

Adding Features

- New modifiers/auras: extend logic/resolve.computeActiveModifiers and GameState:getEffectiveCardCost if they affect costs.
- New targeting patterns: add to logic/targeting.lua and consume in both resolver and renderers.
- New states: place under src/states/ and keep transitions in the current state or via Gamestate.

## Animation Lab & Combo Testing Framework

### Purpose
The Animation Lab (`src/states/anim_lab.lua`) serves as a controlled testing environment for card sequences, combos, and animations while maintaining game rule integrity.

### Key Features & Implementation

**Combo Detection Across Players:**
- `Player:canPlayCombo(card, gs)` checks all players' `prevCardId` in animation lab mode
- Normal games enforce per-player combo rules (no cross-player combos)
- Enables testing sequences like "Quick Jab → Corner Rally → Wild Swing" where cards are played by different players

**Player Advancement Control:**
- Flag: `gs.suppressPlayerAdvance = true` prevents automatic `nextPlayer()` calls
- Modified in `logic/actions.lua`: `playCardFromHand()`, `playModifierOnSlot()`, `advanceTurn()`
- Animation lab manually controls `currentPlayer` for testing scenarios
- Normal games continue standard turn progression

**Special Flags:**
- `gs.isAnimationLab = true` — Enables cross-player combo detection
- `gs.suppressPlayerAdvance = true` — Prevents automatic player switching
- Both flags are false/undefined in normal games

### Testing Workflow
1. Add test cards to hand via animation lab UI
2. Play sequence without forced player switches
3. Combo highlighting works across all players' previous cards

## Unified Animation System (IMPLEMENTED)

### Architecture Overview
Complete overhaul of fragmented animation system into unified 3D physics-based approach:
- **Previous (legacy — removed)**: Scattered parameters across `animation_specs_defaults.lua`, `flight_profiles.lua`, `animation_manager.lua` (replaced by the unified system)
- **Current**: Unified system with clear physics simulation and phase structure

### Core Components

**UnifiedAnimationEngine** (`src/unified_animation_engine.lua`)
- 8-phase animation pipeline: preparation → launch → flight → approach → impact → settle → board_state → game_resolve
- Real-world physics: gravity (980 px/s²), air resistance (0.02), mass-based calculations
- Easing functions: easeOutQuad, easeOutBack, easeOutElastic, etc.

**UnifiedAnimationSpecs** (`src/unified_animation_specs.lua`)
- Centralized configuration replacing scattered spec files
- Three style presets: aggressive (attacks), defensive (blocks), modifier (buffs)
- Card-specific overrides: wild_swing, quick_jab, corner_rally, guard, adrenaline_rush

Legacy Modules (Removed)
- `animation_specs_defaults.lua`
- `flight_profiles.lua`
- `animation_manager.lua`

**BoardStateAnimator** (`src/board_state_animator.lua`)
- Ongoing animations for cards while on board
- Idle animations: subtle breathing (0.02 amplitude), gentle hover (3px variation)
- Conditional signals: impending doom shake, energy charging pulse, protective stance
- Interaction feedback: hover scale (1.05x), selection glow, dragging tilt

**ResolveAnimator** (`src/resolve_animator.lua`)
- Combat animation effects during resolve phase
- Attack strikes: forward motion toward target with snap-back
- Defensive pushes: damage-proportional pushback with block consideration

**UnifiedAnimationManager** (`src/unified_animation_manager.lua`)
- Coordinates all three animation contexts (flight, board state, resolve)
- Provides unified API: `playCard()`, `addCardToBoard()`, `startAttackAnimation()`
- Status monitoring and debug capabilities

**UnifiedAnimationAdapter** (`src/unified_animation_adapter.lua`)
- Migration compatibility layer maintaining 100% legacy interface compatibility
- `gs.animations:add()`, `gs.animations:isBusy()`, `gs.animations:draw()` work unchanged
- Transparent integration with existing `AnimationBuilder` and game logic

### Three Animation Contexts

1. **Flight Phase** - Card throwing from hand to board
   - Physics simulation with ballistic trajectories
   - Card-specific flight profiles (aggressive low-arc vs defensive high-arc)
   - Visual effects: trails, tumbling, breathing scale variation

2. **Board State Phase** - Ongoing animations while cards are on board
   - Idle: breathing and hover for life-like presence
   - Conditional: threatening cards shake, charging cards pulse, defensive cards glow
   - Interactive: hover/select/drag state with smooth transitions

3. **Resolve Phase** - Combat animation effects
   - Attack strikes with forward motion and recoil
   - Defensive reactions with damage-proportional pushback
   - Integration with existing resolve system timing

### Integration Points

**Automatic Integration:**
- `src/gamestate.lua`: Uses `UnifiedAnimationAdapter` transparently
- Card placement: Automatically adds cards to board state system via `placeCardWithoutAdvancing()`
- Card removal: Removes from board state via `Actions.discardCard()`
- Combat resolution: Triggers attack/defense animations in `logic/resolve.lua`

**Configuration:**
- Enable/disable migration: `gs.animations:enableMigration(true/false)`
- Debug mode: `gs.animations:setDebugMode(true)` for console output
- Card customization: Edit `unified_animation_specs.lua` for new cards

### Benefits Achieved

**Visual Coherence:**
- All animations follow consistent physics principles
- Card behavior predictable and intuitive (gravity, air resistance, momentum)
- Unified timing and easing across all animation types

**Technical Improvement:**
- Single source of truth for animation configuration
- Clear separation of concerns: physics, state management, visual effects
- Extensible architecture for future animation types

**Gameplay Enhancement:**
- Cards feel alive on board with subtle idle animations
- Combat feels impactful with physics-based strike animations
- Visual feedback for card states (threatening, charging, defensive)

### Testing and Verification

**Test Suite:** `test_unified_animations.lua`
- Specification loading and validation
- Phase system functionality  
- Card-specific override application
- Board state animation behavior
- Performance testing with 50+ simultaneous animations

**Animation Lab Integration:**
- All existing combo testing functionality preserved
- Enhanced with unified animation visual feedback
- Debug mode shows physics simulation in real-time

**Legacy Compatibility:**
- Zero breaking changes to existing code
- All `AnimationBuilder` sequences work unchanged
- Existing card specs automatically converted to unified format

The unified animation system represents a complete architectural overhaul providing visual coherence, technical maintainability, and extensible foundation for future animation features.
4. Manual player control allows testing complex scenarios

### Maintaining Game Rules
- Animation lab preserves individual player `prevCardId` tracking
- Cross-player combos are only allowed in testing environment
- Real games maintain strict per-player combo enforcement

