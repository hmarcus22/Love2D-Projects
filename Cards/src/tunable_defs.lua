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
  { path = 'draft.deckWrap',          label = 'Deck Wrap',          type = 'boolean',                                context = 'draft', category = 'Draft' },
  { path = 'draft.deckWrapRowGap',    label = 'Wrap Row Gap',       type = 'number', min = 0,   max = 80,  step = 1,    context = 'draft', category = 'Draft' },
  { path = 'draft.hoverScale',        label = 'Choice Hover Scale', type = 'number', min = 0,   max = 0.6, step = 0.01, context = 'draft', category = 'Draft' },
  { path = 'draft.hoverInSpeed',      label = 'Hover In Speed',     type = 'number', min = 0,   max = 40,  step = 0.5,  context = 'draft', category = 'Draft' },
  { path = 'draft.hoverOutSpeed',     label = 'Hover Out Speed',    type = 'number', min = 0,   max = 40,  step = 0.5,  context = 'draft', category = 'Draft' },
  { path = 'draft.background.blurAmount', label = 'BG Blur Amount', type = 'number', min = 0,   max = 8,   step = 1,    context = 'draft', category = 'Draft BG' },
  { path = 'draft.background.blurPasses', label = 'BG Blur Passes', type = 'number', min = 1,   max = 4,   step = 1,    context = 'draft', category = 'Draft BG' },
  { path = 'draft.background.overlayAlpha', label='BG Overlay Alpha', type='number', min=0,max=1,step=0.01, context='draft', category='Draft BG' },

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
}

return defs

