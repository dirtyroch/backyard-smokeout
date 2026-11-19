--!strict
-- Smoke Storm. Free, server-wide, and the odds do not read passes, products, or purchases.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local TimeUtil = if script ~= nil and script.Parent ~= nil then require(script.Parent.TimeUtil) else require("./TimeUtil")

local Weather = {}

local TRAIT_ORDER = { none = 0, smoky = 1, glazed = 2, golden = 3, meteorite = 4 }

function Weather.order(traitId: string?): number
	return TRAIT_ORDER[traitId or "none"] or 0
end

-- A better trait replaces a worse one. A miss, or a weaker roll, leaves the critter as it is.
function Weather.upgrade(current: string?, rolled: string?): string
	local have = if type(current) == "string" and current ~= "" then current else "none"
	local nextTrait = if type(rolled) == "string" and rolled ~= "" then rolled else "none"
	if Weather.order(nextTrait) > Weather.order(have) then
		return nextTrait
	end
	return have
end

function Weather.weight(id: string, triple: boolean): number
	for _, row in ipairs(Config.Storm.odds) do
		if row.id == id then
			if triple and id ~= "none" then
				return row.weight * Config.Storm.triple
			end
			return row.weight
		end
	end
	return 0
end

export type Odd = { id: string, name: string, pct: number }

-- Shown odds, including "No trait", always sum to 100. `triple` is the Saturday window only.
function Weather.shownOdds(triple: boolean?): { Odd }
	local rows = {}
	local total = 0
	for _, row in ipairs(Config.Storm.odds) do
		local w = Weather.weight(row.id, triple == true)
		total += w
		table.insert(rows, { id = row.id, name = row.name, weight = w })
	end
	local out = {}
	if total <= 0 then
		return out
	end
	for _, row in ipairs(rows) do
		table.insert(out, { id = row.id, name = row.name, pct = row.weight / total * 100 })
	end
	return out
end

-- `u` is 0..1. The same u and the same triple flag always return the same trait.
function Weather.roll(u: number, triple: boolean?): string
	local odds = Weather.shownOdds(triple == true)
	local x = math.clamp(u, 0, 0.999999) * 100
	local acc = 0
	for _, row in ipairs(odds) do
		acc += row.pct
		if x < acc then
			return row.id
		end
	end
	return "none"
end

local function gapFor(seed: number, index: number): number
	local x = (math.floor(seed) * 10007 + index * 9176) % 2147483647
	if x < 0 then
		x += 2147483646
	end
	local u = (x % 10000) / 10000
	return Config.Storm.gapMin + u * (Config.Storm.gapMax - Config.Storm.gapMin)
end

export type Storm = { active: boolean, start: number, finish: number, nextStart: number, index: number }

-- The storm timeline is fixed for a server seed, so every client can be told the same window.
function Weather.stormAt(seed: number, now: number): Storm
	local duration = Config.Storm.duration
	local t = 0
	local i = 0
	local avg = (Config.Storm.gapMin + Config.Storm.gapMax) / 2 + duration
	if now > avg * 4 then
		i = math.max(0, math.floor(now / avg) - 4)
		for n = 0, i - 1 do
			t += gapFor(seed, n) + duration
		end
		while i > 0 and t > now do
			i -= 1
			t -= gapFor(seed, i) + duration
		end
	end
	while i < 1000000 do
		local start = t + gapFor(seed, i)
		local finish = start + duration
		if now < start then
			return { active = false, start = start, finish = finish, nextStart = start, index = i }
		elseif now < finish then
			return { active = true, start = start, finish = finish, nextStart = finish + gapFor(seed, i + 1), index = i }
		end
		t = finish
		i += 1
	end
	return { active = false, start = now, finish = now, nextStart = now + Config.Storm.gapMin, index = i }
end

-- Saturday 2:00–2:30 PM Central. A real window, not a countdown.
function Weather.smokeShow(now: number, offsetHours: number): boolean
	if TimeUtil.weekday(now, offsetHours) ~= 7 then
		return false
	end
	local localSec = now + offsetHours * 3600
	local sod = localSec % 86400
	if sod < 0 then
		sod += 86400
	end
	local beginAt = Config.Storm.showHour * 3600
	return sod >= beginAt and sod < beginAt + Config.Storm.showLength
end

function Weather.banner(triple: boolean?): string
	local bits = {}
	for _, row in ipairs(Weather.shownOdds(triple == true)) do
		if row.id ~= "none" then
			table.insert(bits, string.format("%s %.2g%%", row.name, row.pct))
		end
	end
	local head = if triple then "SATURDAY SMOKE SHOW" else "SMOKE STORM"
	return head .. ": crew can catch traits. " .. table.concat(bits, " · ")
end

return Weather
