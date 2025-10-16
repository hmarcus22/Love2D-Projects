---
applyTo: '**'
---

# AI Collaboration Guidelines

## Code Changes Protocol
- **ALWAYS discuss approach before implementing changes**
- Explain the problem analysis first before proposing solutions
- Get explicit approval before modifying any files
- Break down complex changes into discussable steps
- Only proceed with implementation after user confirms the plan

## Communication Standards  
- Be explicit about what tools will be used and why
- Acknowledge when user corrects interaction patterns
- Ask permission before running tests or background processes
- Respect that user can test Love2D directly, AI cannot interact with running games

## Development Flow
- Analyze first, implement second
- Use read_file and grep_search to understand context before making changes
- Provide clear explanations of what each change accomplishes
- When debugging, explain the diagnostic approach before executing it

## File Modification Rules
- Always include sufficient context (3-5 lines) when using replace_string_in_file
- Never make assumptions about file contents - verify with read_file first
- Test tool usage patterns on request rather than assuming they work

## Project Context
This is a Love2D card game with unified animation systems, tunable configuration, and complex state management.

## Project-Specific Architecture (Love2D Card Game)
- **logic/** contains headless game rules with NO Love2D calls - returns data structures only
- **renderers/** do pure drawing with NO game rules - only visualize passed state  
- **states/** handle screens/flow/input - compose logic + renderers
- **animations/** provide visual enhancement without affecting game logic
- GameState acts as orchestrator wiring logic + renderers

## Project Code Organization Rules
- Logic systems go in logic/ if reused and not UI-related
- Use GameState:addLog for gameplay, gate console debug behind Config.debug
- GameState:getEffectiveCardCost is the hook for discounts/auras
- GameState:applyCardEffectsDuringAttack for one-off effects

## Project Animation System Context
- Unified 3D physics-based animation with 8-phase pipeline
- Three contexts: flight (hand to board), board_state (ongoing), resolve (combat)
- UnifiedAnimationAdapter maintains 100% legacy compatibility
- Card specs in unified_animation_specs.lua, not scattered files