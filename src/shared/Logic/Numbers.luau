--!strict
-- Short coin labels: 999, 1.2K, 3.4M. Shared so the HUD and the tests use one rule.
local Numbers = {}

local SUFFIXES = {
	{ div = 1e12, suf = "T" },
	{ div = 1e9, suf = "B" },
	{ div = 1e6, suf = "M" },
	{ div = 1e3, suf = "K" },
}

local function trim(text: string): string
	return (text:gsub("%.0$", ""))
end

function Numbers.abbrev(n: number): string
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local value = math.abs(n)
	if value < 1000 then
		return sign .. tostring(math.floor(value + 1e-6))
	end
	for i, step in ipairs(SUFFIXES) do
		if value >= step.div then
			local scaled = value / step.div
			local text = string.format("%.1f", scaled)
			local rounded = tonumber(text) or scaled
			-- 999,950 formats as 1000.0K. Step up a suffix instead of printing 1000K.
			if rounded >= 1000 and i > 1 then
				local up = SUFFIXES[i - 1]
				return sign .. trim(string.format("%.1f", value / up.div)) .. up.suf
			end
			return sign .. trim(text) .. step.suf
		end
	end
	return sign .. tostring(math.floor(value + 1e-6))
end

return Numbers
