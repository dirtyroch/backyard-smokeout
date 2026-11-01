--!strict
-- Remembers recent PurchaseIds inside the player's saved data so ProcessReceipt is idempotent:
-- if Roblox calls us again for the same purchase, we don't grant twice.
local ReceiptLedger = {}

function ReceiptLedger.has(list: { string }, purchaseId: string): boolean
	for _, id in ipairs(list) do
		if id == purchaseId then
			return true
		end
	end
	return false
end

function ReceiptLedger.add(list: { string }, purchaseId: string, max: number)
	if ReceiptLedger.has(list, purchaseId) then
		return
	end
	table.insert(list, purchaseId)
	while #list > max do
		table.remove(list, 1)
	end
end

return ReceiptLedger
