Cleanup Plan — Unused Helpers and Deprecated Files

Goal
- Remove unused modules and stale references with minimal diffs, without changing gameplay or breaking placeholder rendering.

Decisions
- Card art fallback remains in CardRenderer: when a card has no art image, it renders a readable basic card (white rounded rect + text/stats). This behavior is unchanged.
- CardFactory: for explicit art paths (`def.art`), use `src.asset_cache` only (consistent filtering/mipmaps). Keep `src.card_art` module for card backs (used by `src/card.lua`).

Actions
1) src/states/game.lua: remove dead require `local replay_match = require "src.replay"`.
2) Delete unused files:
   - src/replay.lua (not wired; only imported by the dead require)
   - src/game_logger_example.lua (example; API drift vs. `GameLogger`)
   - src/board.lua (not referenced; board rendering uses `renderers/board_renderer.lua`)
3) src/card_factory.lua:
   - Remove `local CardArt = require "src.card_art"`
   - Change explicit art load to `image = Assets.image(artPath)` (drop `or CardArt.load(artPath)`).
   - Keep everything else, including the candidate search under `assets/cards` and recording `def.art` path when missing.

Risks/Assumptions
- Card definitions use asset-relative paths under `assets/`; no reliance on absolute OS paths for art. If such paths exist, we will revisit.
- `src.card_art` stays because `src/card.lua` uses it to load the optional back art image.
- `GameLogger` stays intact; replay helper removed does not affect in-game logging.

Validation
- Static: search for remaining references after changes
  - `rg -n "src\.replay" -S src` → expect no matches
  - `rg -n "src\.board" -S src` → expect no matches
  - `rg -n "src\.game_logger_example" -S` → expect no matches
  - If CardFactory change: `rg -n "src\.card_art" -S src | Select-String -NotMatch src/card.lua` → expect only `src/card.lua`
- Runtime (manual):
  - Launch game → Menu → Fighter Select → Draft → Game.
  - Cards with art (e.g., punch) show images; others render basic cards.
  - No module not found errors; gameplay (draw/play/resolve) unchanged.
  - Open Animation Lab to verify rendering/animations still function.

Rollback
- Revert this patch or restore files if needed. The changes are surgical and isolated.

