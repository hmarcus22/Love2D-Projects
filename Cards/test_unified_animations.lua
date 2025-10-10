-- test_unified_animations.lua
-- Test file to demonstrate the unified animation system capabilities
-- Run this from within Love2D by calling: require('test_unified_animations').runTests()

local TestUnifiedAnimations = {}

function TestUnifiedAnimations.runTests()
    print("=== UNIFIED ANIMATION SYSTEM TESTS ===")

    -- Create test manager
    local UnifiedAnimationManager = require('src.unified_animation_manager')
    local manager = UnifiedAnimationManager()
    manager:setDebugMode(true)

    print("\n1. Testing Animation Manager Initialization")
    local status = manager:getStatus()
    print("   Status: " .. (status.enabled and "ENABLED" or "DISABLED"))

    print("\n2. Testing Animation Specifications")
    TestUnifiedAnimations.testAnimationSpecs()

    print("\n3. Testing Phase System")
    TestUnifiedAnimations.testPhaseSystem()

    print("\n4. Testing Card-Specific Overrides")
    TestUnifiedAnimations.testCardOverrides()

    print("\n5. Testing Board State Animations")
    TestUnifiedAnimations.testBoardStateAnimations()

    print("\n=== TESTS COMPLETE ===")
end

function TestUnifiedAnimations.testAnimationSpecs()
    local specs = require('src.unified_animation_specs')

    print("   - Loaded unified specifications")
    local phaseCount = 0
    if specs.unified then
        for _ in pairs(specs.unified) do phaseCount = phaseCount + 1 end
    end
    print("   - Found " .. phaseCount .. " animation phases")

    if specs.styles then
        local styleCount = 0
        for _ in pairs(specs.styles) do styleCount = styleCount + 1 end
        print("   - Found " .. styleCount .. " style presets")
    end

    if specs.cards then
        local cardCount = 0
        for _ in pairs(specs.cards) do cardCount = cardCount + 1 end
        print("   - Found " .. cardCount .. " card-specific overrides")
    end
end

function TestUnifiedAnimations.testPhaseSystem()
    local UnifiedAnimationEngine = require('src.unified_animation_engine')
    local engine = UnifiedAnimationEngine()

    -- Create mock card
    local mockCard = {
        id = "test_card",
        x = 100,
        y = 200,
        scale = 1.0,
        definition = { id = "punch" }
    }

    print("   - Created mock card: " .. mockCard.id)

    -- Test animation specification retrieval
    local spec = engine:getAnimationSpec(mockCard, "test_flight")
    if spec then
        print("   - Retrieved animation specification")
        print("   - Flight duration: " .. tostring(spec.flight and spec.flight.duration or "N/A"))
        print("   - Impact effects: " .. ((spec.impact and spec.impact.effects) and "YES" or "NO"))
    else
        print("   - Failed to retrieve animation specification")
    end
end

function TestUnifiedAnimations.testCardOverrides()
    local specs = require('src.unified_animation_specs')

    print("   Testing specific card overrides:")

    local testCards = {"wild_swing", "punch", "rally", "guard", "adrenaline_rush"}

    for _, cardId in ipairs(testCards) do
        if specs.cards[cardId] then
            print("   - " .. cardId .. " - has custom animation spec")

            local cardSpec = specs.cards[cardId]
            if cardSpec.baseStyle then
                print("     -> Uses base style: " .. tostring(cardSpec.baseStyle))
            end

            if cardSpec.flight then
                print("     -> Custom flight parameters")
            end

            if cardSpec.board_state then
                print("     -> Custom board state animations")
            end
        else
            print("   - " .. cardId .. " - uses default spec")
        end
    end
end

function TestUnifiedAnimations.testBoardStateAnimations()
    local BoardStateAnimator = require('src.board_state_animator')
    local boardAnimator = BoardStateAnimator()

    -- Create mock cards with different states
    local mockCards = {
        {
            id = "threatening_card",
            x = 100, y = 100,
            definition = { id = "wild_swing" }
        },
        {
            id = "defensive_card", 
            x = 200, y = 100,
            definition = { id = "guard" }
        },
        {
            id = "charging_card",
            x = 300, y = 100,
            definition = { id = "adrenaline_rush" }
        }
    }

    print("   Adding cards to board state system:")
    for _, card in ipairs(mockCards) do
        boardAnimator:addCard(card)
        print("   - Added " .. tostring(card.definition.id))
    end

    print("   Testing interaction states:")
    boardAnimator:setCardInteraction(mockCards[1], "hover", true)
    print("   - Set hover state on " .. tostring(mockCards[1].definition.id))

    boardAnimator:setCardInteraction(mockCards[2], "selected", true)
    print("   - Set selected state on " .. tostring(mockCards[2].definition.id))

    print("   - Board state animation system functional")
end

-- Integration test with real game components
function TestUnifiedAnimations.testGameIntegration()
    print("\n=== GAME INTEGRATION TEST ===")

    -- Test adapter compatibility
    local UnifiedAnimationAdapter = require('src.unified_animation_adapter')
    local adapter = UnifiedAnimationAdapter()
    adapter:enableMigration(true)

    print("- Unified adapter initialized")

    -- Test legacy interface compatibility
    local mockLegacyAnim = {
        type = "card_flight",
        card = {
            id = "test_card",
            x = 100, y = 200,
            definition = { id = "punch" }
        },
        fromX = 100, fromY = 200,
        toX = 300, toY = 150,
        duration = 0.8,
        onComplete = function()
            print("- Legacy animation callback executed")
        end
    }

    adapter:add(mockLegacyAnim)
    print("- Legacy animation interface working")

    -- Test unified features
    adapter:addCardToBoard(mockLegacyAnim.card)
    print("- Card added to board state system")

    adapter:setCardHover(mockLegacyAnim.card, true)
    print("- Card interaction state updated")

    adapter:printStatus()
end

-- Performance and stress testing
function TestUnifiedAnimations.performanceTest()
    print("\n=== PERFORMANCE TEST ===")

    local UnifiedAnimationManager = require('src.unified_animation_manager')
    local manager = UnifiedAnimationManager()

    -- Create many mock cards
    local cards = {}
    for i = 1, 20 do -- Reduced count for initial testing
        local card = {
            id = "perf_test_" .. i,
            x = math.random(0, 800),
            y = math.random(0, 600),
            scale = 1.0,
            definition = { id = i % 2 == 0 and "punch" or "wild_swing" }
        }
        table.insert(cards, card)

        -- Add to board state
        manager:addCardToBoard(card)

        -- Start some flight animations
        if i <= 5 then
            manager:playCard(card, math.random(200, 600), math.random(100, 500))
        end
    end

    print("- Created and animated 20 cards successfully")

    -- Test update performance
    for i = 1, 10 do
        manager:update(0.016) -- Simulate 60 FPS
    end

    print("- 10 update cycles completed successfully")

    local status = manager:getStatus()
    print("- Final status: " .. status.flightAnimations .. " flight, " .. status.boardStateCards .. " board, " .. status.resolveAnimations .. " resolve")
end

return TestUnifiedAnimations

