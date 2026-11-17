--!nocheck
-- Lune's Instance has no BindableEvent:Fire. This mock follows the live engine:
-- tables are deep-copied, metatables are dropped, functions and threads become
-- nil, and everything else (including Instances) is passed through.
-- A mock that forwarded references hid the ranch-load bug, because
-- `ctx.Data.get(player) ~= profile` is false only when the profile was copied.

local installed = false

local function copyValue(value, seen)
	local kind = type(value)
	if kind == "table" then
		local existing = seen[value]
		if existing then
			return existing
		end
		local out = {}
		seen[value] = out
		local key, child = next(value)
		while key ~= nil do
			local copiedKey = copyValue(key, seen)
			if copiedKey ~= nil then
				rawset(out, copiedKey, copyValue(child, seen))
			end
			key, child = next(value, key)
		end
		return out
	end
	if kind == "function" or kind == "thread" then
		return nil
	end
	return value
end

local function resumeNow(fn)
	-- A listener error stays on that listener. Roblox prints it; the suite
	-- asserts the other listeners still run, so the message is not repeated here.
	local co = coroutine.create(fn)
	coroutine.resume(co)
end

local function install(roblox)
	if installed then
		return
	end
	installed = true
	local states = {}

	local function stateFor(inst)
		local state = states[inst]
		if state then
			return state
		end
		state = { list = {} }
		local event = {}
		function event:Connect(fn)
			local entry = { fn = fn }
			table.insert(state.list, entry)
			local conn = { Connected = true }
			function conn:Disconnect()
				if not self.Connected then
					return
				end
				self.Connected = false
				entry.fn = nil
			end
			return conn
		end
		state.event = event
		states[inst] = state
		return state
	end

	roblox.implementProperty("BindableEvent", "Event", function(inst)
		return stateFor(inst).event
	end)

	roblox.implementMethod("BindableEvent", "Fire", function(inst, ...)
		local state = states[inst]
		if not state then
			return
		end
		local n = select("#", ...)
		local copied = {}
		for i = 1, n do
			-- Each argument is copied on its own, the way Fire copies its tuple.
			copied[i] = copyValue(select(i, ...), {})
		end
		local fns = {}
		for _, entry in ipairs(state.list) do
			if entry.fn then
				table.insert(fns, entry.fn)
			end
		end
		for _, fn in ipairs(fns) do
			local handler = fn
			resumeNow(function()
				handler(table.unpack(copied, 1, n))
			end)
		end
	end)
end

return {
	install = install,
}
