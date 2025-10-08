-- Quick test command for testing unified animations from console
-- Usage: Call this from Love2D console or add temporary button in animation lab

local function testUnifiedAnimations()
    print("=== QUICK UNIFIED ANIMATION TEST ===")
    
    -- Test basic loading
    local success, err = pcall(function()
        local specs = require('src.unified_animation_specs')
        print("✓ Animation specs loaded successfully")
        
        local engine = require('src.unified_animation_engine')()
        print("✓ Animation engine created successfully")
        
        local manager = require('src.unified_animation_manager')()
        print("✓ Animation manager created successfully")
        
        local adapter = require('src.unified_animation_adapter')()
        print("✓ Animation adapter created successfully")
        
        -- Test a simple animation setup
        local testCard = {
            id = "test_card",
            x = 100, y = 100,
            scale = 1.0,
            definition = { id = "punch" }
        }
        
        manager:addCardToBoard(testCard)
        print("✓ Card added to board state")
        
        manager:setCardHover(testCard, true)
        print("✓ Card hover state set")
        
        local status = manager:getStatus()
        print("✓ System status: " .. status.boardStateCards .. " board cards")
        
        return true
    end)
    
    if success then
        print("✓ ALL TESTS PASSED - Unified animation system is working!")
    else
        print("✗ TEST FAILED: " .. tostring(err))
    end
    
    print("=== TEST COMPLETE ===")
end

return testUnifiedAnimations