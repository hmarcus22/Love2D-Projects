# Unified Animation System — Living Plan

Purpose: Single source of truth for intent, scope, phases, and progress. Updated as we implement.

## 1) Goals
- Cleaner code with one animation system (unified).
- No confusion with legacy: keep legacy marked as deprecated.
- Preserve intended behavior; visual polish only where specified.

## 2) Principles
- Single API surface: `gs.animations` (unified adapter).
- Engine/animators never draw; rendering uses `animX/animY`.
- Specs layering: default (`specs.unified`), modifier preset (`specs.styles.modifier`), custom per-card (`specs.cards.<id>`).

## 3) Scope
- Unified system is authoritative.
- Legacy code remains for reference only; no runtime calls.

## 4) Status
- Phase 1: Completed
- Phase 2: In progress
- Phase 3: In progress

## 5) Phases & Tasks

### Phase 1 — Clarify & Stabilize (safe; no behavior changes)
- [x] Adapter passthroughs (no-op plumbing)
  - File: `src/unified_animation_adapter.lua`
  - Add: `addCardToBoard(card)`, `removeCardFromBoard(card)`, `setCardHover(card,bool)`, `setCardSelected(card,bool)`, `setCardDragging(card,bool)`, `enableMigration(bool)`, `setDebugMode(bool)`, `printStatus()`
- [x] Manager busy-state (pass logic correctness)
  - File: `src/unified_animation_manager.lua`
  - Add: `hasActiveAnimations()` → true if flight OR resolve active; exclude board-idle
- [x] Quiet by default
  - File: `src/unified_animation_engine.lua`
  - Change: `self.debugMode = false` in `init()`
- [x] Contract comments (docs only)
  - Brief headers in manager/adapter/renderer describing roles and render contract

### Phase 2 — Behavior Alignment (minimal visible, intended)
- [x] Style forwarding
  - Adapter forwards `anim.animationStyle` to manager; manager includes in config to engine
  - Files: `src/unified_animation_adapter.lua`, `src/unified_animation_manager.lua:93`
- [x] Specs hygiene (no change in feel; remove ambiguity)
  - Keep a single `styles.modifier` (remove duplicate)
  - File: `src/unified_animation_specs.lua`
- [x] Naming consistency (docs)
  - Confirm preset naming: “dramatic” vs “aggressive”; keep docs consistent
- [x] Placement clarity (choose one)
  - Preferred: place on flight completion (`AnimationBuilder` supports)
  - If early placement: ensure board draw ignores card while `_unifiedAnimationActive`
  - Verified: placement occurs on flight completion; animating cards render via `animX/animY` during flight; board renders from `slot.card` after completion

### Phase 3 — Refactor & Deprecate
- [x] Extract `src/animation_util.lua`
  - Easing map/getEasing, mergeSpecs, getByPath, clampDt, normalizeTrajectoryType, makeDebugPrinter
  - Adopt in: `unified_animation_engine.lua`, `resolve_animator.lua`, `unified_animation_adapter.lua`
- [x] Legacy boundary
  - Add top-level “legacy fallback” header in `src/animation_manager.lua`
  - Ensure no runtime references to legacy manager
- [x] Docs
  - Update `UNIFIED_ANIMATION_IMPLEMENTATION.md` with final adapter API and render contract
  - Add verification steps to `TESTING_GUIDE.md`

## 6) Verification
- Busy-state: `gs.animations:isBusy()` is true during flight; false after completion.
- Style: modifier plays fade (`animAlpha` changes) during approach/impact.
- Rendering: played cards remain visible during flight; rendered at `animX/animY`.
- No console spam by default (debug opt-in).

## 7) Decision Log
- Spec layering: keep default/modifier/custom.
- Legacy manager: deprecated; adapter is the only entry surface.
- Physics use is opt-in per style/card (kept as-is unless specified).

## 8) Progress Log
- Initialized plan.
- Implemented Phase 1: adapter passthroughs, manager busy-state, engine debug default.
- Implemented Phase 2: style forwarding and duplicated modifier style resolved.
 - Completed Phase 1 contract comments (adapter/manager/player renderer headers).
 - Phase 2: Placement chosen (on flight completion) and implemented; naming/docs aligned to "dramatic".
 - Phase 3: Extracted and adopted `animation_util.lua`; legacy manager labeled DEPRECATED; implementation/testing docs updated.
