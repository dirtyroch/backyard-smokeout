--!strict
--[[
	ShopSync.luau — pure helpers for scripts/create-shop.luau (no network, no files), so the
	planning and the Monetization.luau rewrite are unit tested in tests/run.luau.

	The idea: every pass and product in src/shared/Monetization.luau is created on Roblox through
	Open Cloud in one run, matched by exact name so a second run never makes duplicates, and the
	new IDs are pasted over the `id = 0` placeholders.
]]

local ShopSync = {}

export type Item = {
	key: string,
	kind: string, -- "pass" | "product"
	id: number,
	name: string,
	price: number,
	desc: string,
}

export type Existing = { id: number, name: string }

export type Plan = {
	create: { Item }, -- not on Roblox yet: create it
	link: { { key: string, kind: string, id: number, name: string } }, -- already on Roblox under this exact name: reuse its ID
	done: { Item }, -- already has a real ID in Monetization
	problems: { string }, -- anything that would make Roblox refuse the item
}

ShopSync.NAME_MAX = 50 -- Roblox refuses longer pass and product names
ShopSync.DESC_MAX = 1000

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

-- Every pass, then every product, in a stable order (sorted by key).
function ShopSync.items(monetization: any): { Item }
	local out: { Item } = {}
	for _, key in ipairs(sortedKeys(monetization.Passes)) do
		local p = monetization.Passes[key]
		table.insert(out, { key = key, kind = "pass", id = p.id, name = p.name, price = p.price, desc = p.desc })
	end
	for _, key in ipairs(sortedKeys(monetization.Products)) do
		local p = monetization.Products[key]
		table.insert(out, { key = key, kind = "product", id = p.id, name = p.name, price = p.price, desc = p.desc })
	end
	return out
end

-- existing = what's already on Roblox for this game: { pass = {...}, product = {...} }.
function ShopSync.plan(items: { Item }, existing: { [string]: { Existing } }): Plan
	local plan: Plan = { create = {}, link = {}, done = {}, problems = {} }
	local byName: { [string]: { [string]: number } } = { pass = {}, product = {} }
	for kind, list in pairs(existing) do
		byName[kind] = byName[kind] or {}
		for _, e in ipairs(list) do
			-- Keep the oldest (lowest) ID if a name appears twice.
			local seen = byName[kind][e.name]
			if seen == nil or e.id < seen then
				byName[kind][e.name] = e.id
			end
		end
	end
	local names: { [string]: string } = {}
	for _, it in ipairs(items) do
		local tag = it.kind .. ":" .. it.name
		if names[tag] then
			table.insert(plan.problems, string.format("%s and %s share the name %q", names[tag], it.key, it.name))
		end
		names[tag] = it.key
		if utf8.len(it.name) == nil or (utf8.len(it.name) :: number) > ShopSync.NAME_MAX then
			table.insert(plan.problems, string.format("%s: name is longer than %d characters", it.key, ShopSync.NAME_MAX))
		end
		if type(it.price) ~= "number" or it.price < 1 or it.price ~= math.floor(it.price) then
			table.insert(plan.problems, string.format("%s: price must be a whole number of Robux", it.key))
		end
		if it.id ~= 0 then
			table.insert(plan.done, it)
		else
			local found = byName[it.kind] and byName[it.kind][it.name]
			if found then
				table.insert(plan.link, { key = it.key, kind = it.kind, id = found, name = it.name })
			else
				table.insert(plan.create, it)
			end
		end
	end
	return plan
end

function ShopSync.description(it: Item): string
	local d = it.desc or ""
	if #d > ShopSync.DESC_MAX then
		d = string.sub(d, 1, ShopSync.DESC_MAX - 3) .. "..."
	end
	return d
end

local function escapePattern(s: string): string
	return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Replaces `Key = { id = 0,` with `Key = { id = N,` for each key in ids. Only touches entries
-- still at 0, so real IDs are never overwritten. Returns the new source and the keys written.
function ShopSync.applyIds(source: string, ids: { [string]: number }): (string, { string })
	local written = {}
	for _, key in ipairs(sortedKeys(ids)) do
		local id = ids[key]
		assert(type(id) == "number" and id > 0 and id == math.floor(id), "bad id for " .. key)
		local pat = "(\n%s*" .. escapePattern(key) .. " = { id = )0,"
		local new, n = string.gsub(source, pat, "%1" .. string.format("%d", id) .. ",", 1)
		if n == 1 then
			source = new
			table.insert(written, key)
		end
	end
	return source, written
end

-- multipart/form-data body. fields: { {name, value} } for text, or {name, filename, bytes, type} for a file.
function ShopSync.multipart(fields: { any }, boundary: string): string
	local parts = {}
	for _, f in ipairs(fields) do
		if f.filename then
			table.insert(
				parts,
				string.format(
					'--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n%s\r\n',
					boundary,
					f.name,
					f.filename,
					f.type or "application/octet-stream",
					f.bytes
				)
			)
		else
			table.insert(parts, string.format('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n', boundary, f.name, tostring(f.value)))
		end
	end
	table.insert(parts, "--" .. boundary .. "--\r\n")
	return table.concat(parts)
end

-- The form Roblox expects for one item. iconBytes is optional (a PNG).
function ShopSync.formFields(it: Item, iconBytes: string?): { any }
	local fields: { any } = {
		{ name = "name", value = it.name },
		{ name = "description", value = ShopSync.description(it) },
		{ name = "price", value = string.format("%d", it.price) },
		{ name = "isForSale", value = "true" },
		-- Keep the exact prices the shop shows (Monetization prices are the source of truth).
		{ name = "isRegionalPricingEnabled", value = "false" },
	}
	if iconBytes then
		table.insert(fields, { name = "imageFile", filename = it.key .. ".png", bytes = iconBytes, type = "image/png" })
	end
	return fields
end

return ShopSync
