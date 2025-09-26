-- board_manager.lua: Handles board slot positions, metrics, slot capacity, slot actions
local BoardManager = {}

function BoardManager.getBoardSlotPosition(self, playerIndex, slotIndex)
    local startX, _, layout = self:getBoardMetrics(playerIndex)
    local x = startX + (slotIndex - 1) * layout.slotSpacing
    local y = self:getBoardY(playerIndex)
    return x, y
end

function BoardManager.hasBoardCapacity(self, player)
    if not player then
        return false
    end
    local limit = self.maxBoardCards or player.maxBoardCards or #(player.boardSlots or {})
    local played = self.playedCount and self.playedCount[player.id] or 0
    return played < limit
end

function BoardManager.drawCardToPlayer(self, playerIndex)
    local player = self.players and self.players[playerIndex]
    if not player or not self.deck then return end
    local card = self.deck:draw()
    if card then
        card.owner = player
        table.insert(player.hand, card)
        self:addLog(string.format("P%d draws %s", player.id or 0, card.name or "card"))
        if self.logger then
            self.logger:log_event("draw", { player = player.id or 0, card = card.name or "card" })
        end
    end
end

return BoardManager
