--!strict
-- Deep-fills missing keys from a template so old saves gain new fields after an update.
local Reconcile = {}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deepCopy(x)
	end
	return out
end
Reconcile.deepCopy = deepCopy

function Reconcile.fill(target: any, template: any): any
	if type(target) ~= "table" then
		return deepCopy(template)
	end
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			Reconcile.fill(target[k], v)
		end
	end
	return target
end

return Reconcile
