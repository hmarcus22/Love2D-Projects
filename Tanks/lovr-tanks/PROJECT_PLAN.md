# LÖVR Tanks (2.5D) — Project Plan

## Overview
- Non‑VR LÖVR project: 3D rendering with 2.5D gameplay (XY plane with shallow Z for visuals).
- Hot‑seat artillery game for two players: take turns to aim and fire across a randomly generated terrain.
- Initial goal (v0.1): Minimal, fun loop with clean structure; ready for future polish (wind, FX, AI).

## Gameplay & Controls (v0.1)
- Perspective: Side view. Tanks constrained to X; Y from terrain; Z fixed at 0.
- Camera: Dynamic camera system using LÖVR's lookAt matrix for proper 3D perspective:
  - **Coordinate System (FIXED)**: Standard 3D coordinates where negative X = left, positive X = right
  - **Player 1 (Green tank)**: Negative X coordinate, appears on LEFT side of screen
  - **Player 2 (Red tank)**: Positive X coordinate, appears on RIGHT side of screen
  - **Camera follows**: Dynamic midpoint between tanks with automatic zoom based on separation
- Terrain: 1D height profile extruded along Z into a thin strip; seedable randomness.
- Movement: Left/Right arrows move the active tank along X (slope limited).
  - **Left arrow**: moves toward negative X (left on screen) - INTUITIVE
  - **Right arrow**: moves toward positive X (right on screen) - INTUITIVE
- Aim: Up/Down adjust barrel elevation (clamped, e.g., 5°–85° toward opponent).
- Fire: Space down starts charging power; release to shoot. Power scales with hold time.
- Turn flow: Aim → Charge (hold Space) → Fire/Simulate → Resolve (damage/win) → Switch player.
- **HUD System**: 3D UI elements positioned above tanks showing health bars, player indicators, and charge bar.

## Technical Decisions
- Engine: LÖVR desktop (no headset). Simple forward rendering with one pass.
- Math: LÖVR `lovr.math` for 3D transforms; HUMP vector for 2D helpers where useful.
- Structure: HUMP `class` for types; HUMP `timer` for sequencing and small tweens.
- Physics: Manual integration for projectile; terrain/tank hits via analytic checks (no `lovr.physics` in v0.1).
- Terrain gen: 1D FBM noise, 128–256 samples, linear interpolation for heightAt(x).

## Project Structure
- Overall: Mirrors a typical LÖVE2D layout—`main.lua` is the entry point and the engine looks for `lovr.*` callbacks just like `love.*`.
- Entry: `lovr-tanks/main.lua` wires up the game modules and manages `lovr.load/update/draw`.
- Config: `lovr-tanks/lovr.conf` (equivalent to `conf.lua`) tweaks window/device defaults for desktop play.
- Modules: `src/` keeps gameplay code organized; `src/core/` holds shared helpers (camera, math), `src/game/` hosts stateful gameplay objects (game loop, terrain, tanks, projectile).
- Libraries: `lovr-tanks/lib/hump/{class.lua,timer.lua,vector.lua}` vendored to avoid external dependencies.
- Optional HUMP extras: consider `gamestate` for menu/round flows, `signal` for loose event dispatch (impacts → FX), `vector-light` when projectile math needs fewer allocations, and `camera` for any 2D HUD pass.

## Parameters (initial defaults)
- World width: 200 m; depth (visual): 6 m; gravity: 9.81 m/s².
- Terrain: samples=128, max height=30 m, seed=42.
- Tank: radius ≈1.2 m; move speed 10 m/s; slope limit ≈35°; health 100.
- Aim rate: 45°/s. Angle clamp: 5°–85° toward opponent.
- Power: min 15 m/s, max 80 m/s; full charge time 1.2 s.
- Damage: simple hit = 50 dmg (v0.1); blast radius and falloff later.

## Milestones
1) Setup and libs (LÖVR desktop, HUMP) — ✅ done
2) Side‑view camera + HUD skeleton — ✅ done
3) Procedural terrain (1D, extruded) — ✅ done
4) Tanks + movement + aim — ✅ done
5) Turn system + charge‑to‑fire — ✅ done
6) Projectile sim + basic collision — ✅ done
7) Damage/health/win loop — ✅ done
8) **Dynamic camera system** — ✅ **COMPLETED**: Camera follows midpoint between tanks with automatic zoom
9) **HUD system** — ✅ **COMPLETED**: Health bars, player indicators, charge bar with 3D UI elements
10) **Coordinate system fix** — ✅ **COMPLETED**: Intuitive left/right movement controls
11) Polish (enhanced FX, audio, terrain destruction) — next
12) Packaging + docs (README, controls, seeds) — next

## Verification (v0.1)
- Run: `cd lovr-tanks && lovr .`
- Check: movement, aim clamping, charge bar increases, projectile flight, collision with terrain/tank, damage and win message, turn switching.

## Next Steps (v0.2+)
- Camera: smooth follow on projectile; shake on impact.
- Terrain: single indexed mesh with normals for nicer shading; optional LOD.
- Effects: muzzle flash, tracer, impact sparks/dust; simple audio cues.
- Gameplay: wind force, radial blast damage/falloff, limited fuel per turn.
- UX: pause/reset, seed chooser, basic menu and round settings.
- AI: basic angle/power solver for single‑player.

## Risks / Considerations
- Fairness across random seeds; add min separation and max slope near spawns.
- Performance if terrain resolution increases; keep strip narrow, cull debug.
- Future deformable terrain would require mesh updates and different collision logic.
