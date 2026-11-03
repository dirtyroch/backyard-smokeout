--!strict
--[[
	Gifting.luau — buy a look for someone else in your server.
	Pure logic (no Roblox services) so it can be unit-tested with Lune.

	How it works:
	  1. The giver taps "Gift" on a looks-only shop item and picks a player in the server.
	  2. The server checks it (Gifting.check) and remembers the intent for a short time
	     (Gifting.remember), then prompts the normal developer product.
	  3. When the receipt arrives, Gifting.claim hands back the recipient, once.
	  4. If the recipient left in the meantime, the gift is "held" on the giver's save and can
	     be sent to anyone later for free (Gifting.hold / Gifting.takeHeld). Robux is never lost.

	Rules: only looks (cosmetics and looks bundles) can be gifted. Nothing random, nothing
	that gives an advantage, no pressure copy. Boost time inside a bundle goes to the recipient.
]]
local Gifting = {}

export type Pending = { to: number, key: string, at: number }

-- Can this shop product be gifted? Looks only.
function Gifting.giftable(product: any): boolean
	if type(product) ~= "table" then
		return false
	end
	if product.kind ~= "cosmetic" and product.kind ~= "bundle" then
		return false
	end
	return type(product.grants) == "table" and #product.grants > 0
end

-- Validate a gift request. `recipient` is nil when that player isn't in the server.
function Gifting.check(senderId: number, recipientId: number?, product: any, recipientOwnsAll: boolean): (boolean, string?)
	if not Gifting.giftable(product) then
		return false, "Only looks can be gifted."
	end
	if recipientId == nil then
		return false, "That player isn't in this server anymore."
	end
	if recipientId == senderId then
		return false, "Pick someone else to gift. Buy it from the shop for yourself!"
	end
	if recipientOwnsAll then
		return false, "They already have this one."
	end
	return true, nil
end

-- Remember who the giver meant this purchase for. One pending gift per (giver, item).
function Gifting.remember(pending: { [string]: Pending }, key: string, recipientId: number, now: number)
	pending[key] = { to = recipientId, key = key, at = now }
end

-- Consume the pending gift for this item if it's still fresh. Returns the recipient's UserId.
function Gifting.claim(pending: { [string]: Pending }, key: string, now: number, ttl: number): number?
	local p = pending[key]
	pending[key] = nil
	if not p or now - p.at > ttl then
		return nil
	end
	return p.to
end

-- Held gifts live on the giver's save: { [productKey] = count }.
function Gifting.hold(held: { [string]: number }, key: string)
	held[key] = (held[key] or 0) + 1
end

function Gifting.takeHeld(held: { [string]: number }, key: string): boolean
	local n = held[key] or 0
	if n <= 0 then
		return false
	end
	if n == 1 then
		held[key] = nil
	else
		held[key] = n - 1
	end
	return true
end

return Gifting
