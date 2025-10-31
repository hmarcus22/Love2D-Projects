# Pull Request Template

## Summary
- What change is being made and why?

## Related Issues
- Closes #

## Analysis
- Goal and current behavior:
- Constraints and assumptions:
- Alternatives considered (and why not chosen):

## Plan
- Files to touch and intended changes:
  - `path:file:line` → change summary
- Architecture alignment (logic/renderers/animations/states separation):

## Validation
- Steps to verify (commands, steps, screenshots/GIFs):
- Expected vs actual behavior after change:

## Impact / Risks
- User-facing impact:
- Technical risks / migrations:

## Checklist
- [ ] Analysis included and approved before implementation
- [ ] Scope is minimal and focused on the task
- [ ] Follows DEV_NOTES boundaries:
  - [ ] No Love2D calls in `logic/`
  - [ ] No game rules in `renderers/`
  - [ ] `animations/` are visual-only; do not affect rules
  - [ ] `states/` compose screens and route inputs only
- [ ] Unified rendering respected:
  - [ ] `CardRenderer.draw()` renders all cards
  - [ ] `ShadowRenderer.drawAllShadows()` renders shadows
  - [ ] Position logic uses `(card.animX ~= nil) and card.animX or card.x`
- [ ] Tests or manual validation plan provided
- [ ] Docs/config updated if needed (e.g., DEV_NOTES/AGENTS.md/config)
- [ ] No destructive or networked operations without prior approval

