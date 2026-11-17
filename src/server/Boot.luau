--!strict
-- Starts services so one failure cannot stop player loading.
-- Game.start is intentionally early: it is what connects Data.load and the action remote.
-- Later start() methods (chat, analytics, purchases, the map's heartbeat) are allowed to throw.
local Boot = {}

function Boot.step(label: string, fn: () -> ())
	-- Return a value so xpcall's type has a success flag and an error to unpack.
	local ok, err = xpcall(function(): string?
		fn()
		return nil
	end, debug.traceback)
	if not ok then
		warn("[Boot] " .. label .. " failed:\n" .. tostring(err))
	end
end

function Boot.run(ctx: any, initOrder: { string }, earlyStart: { string }, startOrder: { string })
	for _, name in ipairs(initOrder) do
		local svc = ctx[name]
		if type(svc) == "table" and type(svc.init) == "function" then
			Boot.step(name .. ".init", function()
				svc.init(ctx)
			end)
		end
	end
	local data = ctx.Data
	if type(data) == "table" and type(data.start) == "function" then
		Boot.step("Data.start", function()
			data.start()
		end)
	end
	local function startNamed(name: string)
		local svc = ctx[name]
		if type(svc) == "table" and type(svc.start) == "function" then
			Boot.step(name .. ".start", function()
				svc.start()
			end)
		end
	end
	for _, name in ipairs(earlyStart) do
		startNamed(name)
	end
	for _, name in ipairs(startOrder) do
		startNamed(name)
	end
end

return Boot
