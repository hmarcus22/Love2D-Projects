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
- core/objects — Cards, players, decks, layout:
  - src/card.lua, card_factory.lua, card_definitions.lua
  - src/player.lua, deck.lua, game_layout.lua, viewport.lua
- orchestrator
  - src/gamestate.lua — Thin facade that wires logic + renderers and holds runtime state

Key Boundaries

- logic/ may not require renderers or use Love2D APIs; pass data back to GameState.
- renderers/ do not implement rules — only visualize state passed in.
- states/ compose screens, route inputs, and transition between phases.

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
4. Manual player control allows testing complex scenarios

### Maintaining Game Rules
- Animation lab preserves individual player `prevCardId` tracking
- Cross-player combos are only allowed in testing environment
- Real games maintain strict per-player combo enforcement

