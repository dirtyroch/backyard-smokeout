--!strict
-- Trailing coins-per-second from real earn events. Nothing here is a scripted rate.
local Numbers = if script ~= nil and script.Parent ~= nil then require(script.Parent.Numbers) else require("./Numbers")

local Income = {}

Income.WINDOW = 30

local function trimDecimal(text: string): string
	return (text:gsub("%.0$", ""))
end

export type Event = { t: number, n: number }

function Income.record(events: { Event }, now: number, amount: number, window: number?)
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return
	end
	local span = window or Income.WINDOW
	table.insert(events, { t = now, n = math.floor(amount) })
	local cutoff = now - span
	local keep: { Event } = {}
	for _, e in ipairs(events) do
		if e.t >= cutoff then
			table.insert(keep, e)
		end
	end
	while #keep > 80 do
		table.remove(keep, 1)
	end
	table.clear(events)
	for _, e in ipairs(keep) do
		table.insert(events, e)
	end
end

function Income.perSecond(events: { Event }, now: number, window: number?): number
	local span = window or Income.WINDOW
	if span <= 0 then
		return 0
	end
	local cutoff = now - span
	local sum = 0
	for _, e in ipairs(events) do
		if e.t > cutoff and e.t <= now then
			sum += e.n
		end
	end
	return sum / span
end

function Income.format(perSecond: number): string
	if type(perSecond) ~= "number" or perSecond ~= perSecond or perSecond <= 0 then
		return "+0/s"
	end
	if perSecond < 10 then
		local rounded = math.floor(perSecond * 10 + 0.5) / 10
		local text = string.format("%.1f", rounded)
		text = trimDecimal(text)
		return "+" .. text .. "/s"
	end
	return "+" .. Numbers.abbrev(math.floor(perSecond + 0.5)) .. "/s"
end

return Income
