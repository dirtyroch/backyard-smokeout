--!strict
-- Launch codes. Coins, sauce charges, or a look. Never a crew critter.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")

local Codes = {}

local function clean(raw: any): string
	if type(raw) ~= "string" then
		return ""
	end
	return string.upper((string.gsub(raw, "%s+", "")))
end

function Codes.find(raw: any): any
	local key = clean(raw)
	if key == "" then
		return nil
	end
	for _, row in ipairs(Config.Codes) do
		if row.code == key then
			return row
		end
	end
	return nil
end

export type Result = { ok: boolean, message: string }

function Codes.redeem(data: any, raw: any, now: number, likesLive: boolean): Result
	local row = Codes.find(raw)
	if not row then
		return { ok = false, message = "That code isn't one we know." }
	end
	if type(data.codes) ~= "table" then
		data.codes = {}
	end
	if data.codes[row.code] == true then
		return { ok = false, message = "You already used that code." }
	end
	if type(row.expires) == "number" and now >= row.expires then
		return { ok = false, message = "That code has expired." }
	end
	if row.likes == true and likesLive ~= true then
		return { ok = false, message = "That code isn't turned on yet." }
	end
	data.codes[row.code] = true
	if type(row.coins) == "number" and row.coins > 0 then
		data.coins = (data.coins or 0) + row.coins
	end
	if type(row.sauces) == "table" and type(data.sauces) == "table" then
		for id, n in pairs(row.sauces) do
			local jar = data.sauces[id]
			if type(jar) == "table" and type(n) == "number" then
				jar.charges = (jar.charges or 0) + n
			end
		end
	end
	if type(row.cosmetic) == "string" and row.cosmetic ~= "" then
		if type(data.owned) ~= "table" then
			data.owned = {}
		end
		data.owned[row.cosmetic] = true
	end
	local note = if type(row.note) == "string" then row.note else "Code redeemed."
	return { ok = true, message = note }
end

return Codes
