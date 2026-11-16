--!strict
-- What a shop stand shows, separate from whether Roblox will take the payment.
-- A missing or zero product id used to drop the card entirely, so a live server
-- with unpublished ids opened an empty Outfitters. The card always stays. The
-- button is the only thing that changes.
local ShopCatalog = {}

export type State = "owned" | "buy" | "studio" | "soon"

function ShopCatalog.saleState(id: any, studio: boolean, owned: boolean): (State, boolean)
	if owned then
		return "owned", false
	end
	if type(id) == "number" and id > 0 and id == math.floor(id) then
		return "buy", true
	end
	if studio then
		return "studio", true
	end
	return "soon", false
end

function ShopCatalog.robuxLabel(state: string, price: number): string
	if state == "owned" then
		return "Owned"
	elseif state == "buy" then
		return "Buy  R$ " .. tostring(price)
	elseif state == "studio" then
		return "Studio test (free)"
	end
	return "Coming soon"
end

-- Every pass and every developer product. An id of 0 does not remove the row.
function ShopCatalog.robuxKeys(monetization: any): { { key: string, kind: string } }
	local out = {}
	for key in pairs(monetization.Passes) do
		table.insert(out, { key = key, kind = "pass" })
	end
	for key in pairs(monetization.Products) do
		table.insert(out, { key = key, kind = "product" })
	end
	table.sort(out, function(a, b)
		if a.kind ~= b.kind then
			return a.kind < b.kind
		end
		return a.key < b.key
	end)
	return out
end

export type SauceRow = { id: string, qty: number }

-- The restock shelf when it has bottles. If the shelf is missing or empty,
-- list every sauce so the shack cannot open blank.
function ShopCatalog.sauceRows(shelf: { SauceRow }?, order: { string }): { SauceRow }
	if shelf and #shelf > 0 then
		return shelf
	end
	local rows = {}
	for _, id in ipairs(order) do
		table.insert(rows, { id = id, qty = 1 })
	end
	return rows
end

return ShopCatalog
