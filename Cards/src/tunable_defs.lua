-- Registry of tunable config fields with UI metadata
-- path: dotted path into Config
-- type: 'number' | 'boolean'
-- min/max/step for numbers
-- context: 'game' | 'draft' | 'all'
-- category: grouping label

local defs = {
  -- Layout (affects both phases)
  { path = 'layout.cardW',            label = 'Card Width',         type = 'number', min = 80,  max = 240, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.cardH',            label = 'Card Height',        type = 'number', min = 100, max = 320, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.slotSpacing',      label = 'Slot Spacing',       type = 'number', min = 80,  max = 200, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.sideGap',          label = 'Side Gap',           type = 'number', min = 0,   max = 100, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.boardTopMargin',   label = 'Board Top Margin',   type = 'number', min = 0,   max = 200, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.boardHandGap',     label = 'Board-Hand Gap',     type = 'number', min = 0,   max = 120, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.handBottomMargin', label = 'Hand Bottom Margin', type = 'number', min = -120,max = 120, step = 1,    context = 'all',  category = 'Layout' },
  { path = 'layout.handMinSpacingFactor', label='Hand Min Spacing xW', type='number', min=0, max=1, step=0.01, context='all', category='Layout' },
  { path = 'layout.handHoverScale',   label = 'Hover Scale',        type = 'number', min = 0,   max = 0.6, step = 0.01, context = 'all',  category = 'Layout' },
  { path = 'layout.handHoverSpeed',   label = 'Hover Speed',        type = 'number', min = 0,   max = 40,  step = 0.5,  context = 'all',  category = 'Layout' },

  -- Draft
  { path = 'draft.topMargin',         label = 'Draft Top Margin',   type = 'number', min = 0,   max = 240, step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.cardGap',           label = 'Choice Card Gap',    type = 'number', min = 0,   max = 80,  step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.deckTopOffset',     label = 'Deck Top Offset',    type = 'number', min = 0,   max = 400, step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.deckRowGap',        label = 'Deck Row Gap',       type = 'number', min = 0,   max = 80,  step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.deckOverlap',       label = 'Deck Overlap',       type = 'number', min = 0,   max = 0.95,step = 0.01, context = 'draft', category = 'Draft' },
  { path = 'draft.deckHoverScale',    label = 'Deck Hover Scale',   type = 'number', min = 0,   max = 0.6, step = 0.01, context = 'draft', category = 'Draft Hover' },
  { path = 'draft.deckWrap',          label = 'Deck Wrap',          type = 'boolean',                                context = 'draft', category = 'Draft' },
  { path = 'draft.deckWrapRowGap',    label = 'Wrap Row Gap',       type = 'number', min = 0,   max = 80,  step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.hoverScale',        label = 'Choice Hover Scale', type = 'number', min = 0,   max = 0.6, step = 0.01, context = 'draft', category = 'Draft' },
  { path = 'draft.hoverInSpeed',      label = 'Hover In Speed',     type = 'number', min = 0,   max = 40,  step = 0.5,  context = 'draft', category = 'Draft' },
  { path = 'draft.hoverOutSpeed',     label = 'Hover Out Speed',    type = 'number', min = 0,   max = 40,  step = 0.5,  context = 'draft', category = 'Draft' },
  { path = 'draft.hoverHitScaled',    label = 'Hover Hit Uses Scale', type = 'boolean',                          context = 'draft', category = 'Draft Hover' },
  { path = 'draft.background.blurAmount', label = 'BG Blur Amount', type = 'number', min = 0,   max = 8,   step = 1,    context = 'draft', category = 'Draft BG' },
  { path = 'draft.background.blurPasses', label = 'BG Blur Passes', type = 'number', min = 1,   max = 4,   step = 1,    context = 'draft', category = 'Draft BG' },
  { path = 'draft.background.overlayAlpha', label='BG Overlay Alpha', type='number', min=0,max=1,step=0.01, context='draft', category='Draft BG' },
  { path = 'draft.background.tint',   label = 'BG Tint',            type = 'color',                                 context = 'draft', category = 'Draft BG' },
  { path = 'draft.background.overlayColor', label = 'BG Overlay RGB', type = 'color',                              context = 'draft', category = 'Draft BG' },

  -- Rules (mostly for game)
  { path = 'rules.maxHandSize',       label = 'Max Hand Size',      type = 'number', min = 1,   max = 10,  step = 1,    context = 'game', category = 'Rules' },
  { path = 'rules.maxBoardCards',     label = 'Max Board Cards',    type = 'number', min = 1,   max = 6,   step = 1,    context = 'game', category = 'Rules' },
  { path = 'rules.energyEnabled',     label = 'Energy Enabled',     type = 'boolean',                                context = 'game', category = 'Rules' },
  { path = 'rules.energyStart',       label = 'Energy Start',       type = 'number', min = 0,   max = 10,  step = 1,    context = 'game', category = 'Rules' },
  { path = 'rules.energyIncrementPerRound', label='Energy Increment', type='number', min=0, max=5, step=1, context='game', category='Rules' },
  { path = 'rules.energyMax',         label = 'Energy Max',         type = 'number', min = 1,   max = 12,  step = 1,    context = 'game', category = 'Rules' },
  { path = 'rules.allowManualDraw',   label = 'Allow Manual Draw',  type = 'boolean',                                context = 'game', category = 'Rules' },
  { path = 'rules.allowManualDiscard',label = 'Allow Manual Discard', type = 'boolean',                             context = 'game', category = 'Rules' },
  { path = 'rules.showDiscardPile',   label = 'Show Discard Pile',  type = 'boolean',                                context = 'game', category = 'Rules' },
  { path = 'rules.autoDrawPerRound',  label = 'Auto Draw per Round', type = 'number', min = 0, max = 5, step = 1,   context = 'game', category = 'Rules' },
  { path = 'rules.autoDrawOnTurnStart', label = 'Auto Draw on Turn', type = 'number', min=0, max=5, step=1,         context = 'game', category = 'Rules' },

  -- UI / Animation
  { path = 'ui.cardFlightEnabled',      label = 'Card Flight Enabled',    type = 'boolean',                          context = 'game', category = 'Animation' },
  { path = 'ui.cardFlightDuration',     label = 'Flight Duration',        type = 'number', min = 0.05, max = 1.5, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardImpactEnabled',      label = 'Impact Enabled',         type = 'boolean',                          context = 'game', category = 'Animation' },
  { path = 'ui.cardImpactDuration',     label = 'Impact Duration',        type = 'number', min = 0.05, max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardImpactSquashScale',  label = 'Impact Squash Scale',    type = 'number', min = 0.5,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardImpactFlashAlpha',   label = 'Impact Flash Alpha',     type = 'number', min = 0.0,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardImpactHoldExtra',    label = 'Impact Hold Extra',      type = 'number', min = 0.0,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardFlightCurve',        label = 'Flight Curve',           type = 'enum',  options = { 'arc', 'linear' },       context = 'game', category = 'Animation' },
  { path = 'ui.cardFlightArcHeight',    label = 'Flight Arc Height',      type = 'number', min = 0,    max = 400, step = 1,    context = 'game', category = 'Animation' },
  { path = 'ui.cardFlightOvershoot',    label = 'Flight Overshoot',       type = 'number', min = 0,    max = 0.4, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.useAnimationOverrides',  label = 'Use Anim Overrides',     type = 'boolean',                                context = 'game', category = 'Animation' },
  { path = 'ui.cardHoverBaseLift',      label = 'Hover Base Lift',        type = 'number', min = 0,    max = 120, step = 1,    context = 'game', category = 'Animation' },
  { path = 'ui.cardDragExtraLift',      label = 'Drag Extra Lift',        type = 'number', min = 0,    max = 160, step = 1,    context = 'game', category = 'Animation' },
  { path = 'ui.cardShadowMinScale',     label = 'Shadow Min Scale',       type = 'number', min = 0.2,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardShadowMaxScale',     label = 'Shadow Max Scale',       type = 'number', min = 0.6,  max = 2.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardShadowMinAlpha',     label = 'Shadow Min Alpha',       type = 'number', min = 0.0,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardShadowMaxAlpha',     label = 'Shadow Max Alpha',       type = 'number', min = 0.0,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardSlotGlowDuration',   label = 'Slot Glow Duration',     type = 'number', min = 0.05, max = 1.5, step = 0.01, context = 'game', category = 'Animation' },
  { path = 'ui.cardSlotGlowAlpha',      label = 'Slot Glow Alpha',        type = 'number', min = 0.0,  max = 1.0, step = 0.01, context = 'game', category = 'Animation' },
  
  -- Card Rendering
  { path = 'ui.useCardTextureCache',    label = 'Use Card Texture Cache', type = 'boolean',                                context = 'all',  category = 'Card Rendering' },
  { path = 'ui.cardTextureDebugInfo',   label = 'Show Cache Debug Info',  type = 'boolean',                                context = 'all',  category = 'Card Rendering' },
  { path = 'ui.cardNameFontSize',       label = 'Card Name Font Size',    type = 'number', min = 6,    max = 20,  step = 1, context = 'all',  category = 'Card Text' },
  { path = 'ui.cardCostFontSize',       label = 'Cost Font Size',         type = 'number', min = 6,    max = 16,  step = 1, context = 'all',  category = 'Card Text' },
  { path = 'ui.cardStatFontSize',       label = 'Stat Font Size',         type = 'number', min = 6,    max = 16,  step = 1, context = 'all',  category = 'Card Text' },
  { path = 'ui.cardDescFontSize',       label = 'Description Font Size',  type = 'number', min = 6,    max = 16,  step = 1, context = 'all',  category = 'Card Text' },
  { path = 'ui.cardBackFontSize',       label = 'Card Back Font Size',    type = 'number', min = 6,    max = 20,  step = 1, context = 'all',  category = 'Card Text' },

  -- Layout hand and hover behavior
  { path = 'layout.handAreaWidth',    label = 'Hand Area Width',    type = 'number', min = 300, max = 900, step = 1,  context = 'all',  category = 'Layout Hand' },
  { path = 'layout.handReferenceCount', label = 'Hand Ref Count',   type = 'number', min = 1,   max = 10,  step = 1,  context = 'all',  category = 'Layout Hand' },
  { path = 'layout.handHoverInSpeed', label = 'Hand Hover In Speed', type='number', min=0, max=40, step=0.5,        context='all', category='Layout Hover' },
  { path = 'layout.handHoverOutSpeed', label = 'Hand Hover Out Speed', type='number', min=0, max=40, step=0.5,      context='all', category='Layout Hover' },
  { path = 'layout.handHoverLift',    label = 'Hand Hover Lift',    type = 'number', min = 0, max = 120, step = 1,   context = 'all', category = 'Layout Hover' },
  { path = 'layout.handHoverHitScaled', label='Hand Hover Hit Scaled', type='boolean',                              context='all', category='Layout Hover' },

  -- Layout glow and panels
  { path = 'layout.hoverGlow.width',     label='Glow Width',        type='number', min=0, max=10, step=0.5,         context='all', category='Layout Glow' },
  { path = 'layout.hoverGlow.extraWidth',label='Glow Extra Width',  type='number', min=0, max=10, step=0.5,         context='all', category='Layout Glow' },
  { path = 'layout.cardNamePanelAlpha',  label='Name Panel Alpha',  type='number', min=0, max=1, step=0.01,         context='all', category='Layout Panels' },
  { path = 'layout.cardStatsPanelAlpha', label='Stats Panel Alpha', type='number', min=0, max=1, step=0.01,         context='all', category='Layout Panels' },
  { path = 'layout.cardDescPanelAlpha',  label='Desc Panel Alpha',  type='number', min=0, max=1, step=0.01,         context='all', category='Layout Panels' },

  -- Colors
  { path = 'colors.button',           label = 'Button',             type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.buttonHover',      label = 'Button Hover',       type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.passButton',       label = 'Pass Button',        type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.passButtonHover',  label = 'Pass Hover',         type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.arrow',            label = 'Arrow',              type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.attackArrow',      label = 'Attack Arrow',       type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.deckPopupBg',      label = 'Deck Popup BG',      type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'colors.deckPopupBorder',  label = 'Deck Popup Border',  type = 'color',                                 context = 'all',  category = 'Colors' },
  { path = 'layout.hoverGlow.color',  label = 'Hover Glow',         type = 'color',                                 context = 'all',  category = 'Colors' },
}

return defs
