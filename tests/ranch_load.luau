--!nocheck
-- Loads the real DataService and GameService under a Roblox-shaped environment.
-- BindableEvent arguments are copied, matching a live server. The ranch signal
-- must not be one of those, or the profile identity check drops the join.

local function resumeNow(fn, ...)
	local args = table.pack(...)
	local co = coroutine.create(function()
		fn(table.unpack(args, 1, args.n))
	end)
	local ok, err = coroutine.resume(co)
	if not ok then
		return false, debug.traceback(co, tostring(err))
	end
	return true, nil
end

local function serverTask()
	local lib = { errors = {} }
	function lib.spawn(fn, ...)
		local ok, err = resumeNow(fn, ...)
		if not ok then
			table.insert(lib.errors, err)
			warn(err)
		end
	end
	function lib.wait(_seconds)
		coroutine.yield()
		return 0
	end
	function lib.delay(_seconds, fn, ...)
		local args = table.pack(...)
		lib.spawn(function()
			lib.wait()
			fn(table.unpack(args, 1, args.n))
		end)
	end
	function lib.defer(fn, ...)
		lib.spawn(fn, ...)
	end
	return lib
end

local function RandomLib()
	local Random = {}
	Random.__index = Random
	function Random.new(seed)
		return setmetatable({ seed = seed or 123456789 }, Random)
	end
	function Random:NextNumber(a, b)
		self.seed = (self.seed * 1103515245 + 12345) % 2147483648
		local unit = self.seed / 2147483648
		if a and b then
			return a + (b - a) * unit
		elseif a then
			return unit * a
		end
		return unit
	end
	function Random:NextInteger(a, b)
		return a + math.floor(self:NextNumber() * (b - a + 1))
	end
	return Random
end

local function playerSignal()
	local sig = {}
	function sig:Connect(_fn)
		return { Connected = true, Disconnect = function() end }
	end
	return sig
end

local function mountShared(roblox, parent, dir, paths)
	local fs = require("@lune/fs")
	for _, name in ipairs(fs.readDir(dir)) do
		local full = dir .. "/" .. name
		if fs.isFile(full) and string.sub(name, -5) == ".luau" then
			local mod = roblox.Instance.new("ModuleScript")
			mod.Name = string.sub(name, 1, -6)
			mod.Parent = parent
			paths[mod] = full
		elseif fs.isDir(full) then
			local folder = roblox.Instance.new("Folder")
			folder.Name = name
			folder.Parent = parent
			mountShared(roblox, folder, full, paths)
		end
	end
end

local function openServer()
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	local roblox = require("@lune/roblox")
	require("./bindable_mock").install(roblox)

	roblox.implementMethod("Instance", "WaitForChild", function(inst, name)
		local child = inst:FindFirstChild(name)
		if child then
			return child
		end
		error("WaitForChild gave up on " .. tostring(name))
	end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return os.clock()
	end)
	roblox.implementMethod("RunService", "IsStudio", function()
		return false
	end)
	roblox.implementMethod("DataStoreService", "GetDataStore", function()
		error("DataStoreService is not available", 0)
	end)
	roblox.implementMethod("Players", "GetPlayers", function(players)
		local list = {}
		for _, child in ipairs(players:GetChildren()) do
			if child:IsA("Player") then
				table.insert(list, child)
			end
		end
		return list
	end)
	local added = playerSignal()
	local removing = playerSignal()
	roblox.implementProperty("Players", "PlayerAdded", function()
		return added
	end)
	roblox.implementProperty("Players", "PlayerRemoving", function()
		return removing
	end)

	local game = roblox.Instance.new("DataModel")
	game.JobId = "live-test-job"
	-- Lune's DataModel has no default for these. A public server reads as 0.
	game.PrivateServerId = ""
	game.PrivateServerOwnerId = 0
	local workspace = game:GetService("Workspace")
	local replicated = game:GetService("ReplicatedStorage")
	local shared = roblox.Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = replicated
	local paths = {}
	mountShared(roblox, shared, "src/shared", paths)

	local services = roblox.Instance.new("Folder")
	services.Name = "Services"
	for _, name in ipairs({ "DataService", "GameService" }) do
		local mod = roblox.Instance.new("ModuleScript")
		mod.Name = name
		mod.Parent = services
		paths[mod] = "src/server/Services/" .. name .. ".luau"
	end

	local taskLib = serverTask()
	local env = {
		game = game,
		workspace = workspace,
		Instance = roblox.Instance,
		Enum = roblox.Enum,
		Random = RandomLib(),
		task = taskLib,
		script = nil,
	}
	local cache = {}
	local loaded = {}
	local loading = {}

	local function requireModule(mod)
		local path = paths[mod]
		if not path then
			error("require expected a game module, got " .. tostring(mod))
		end
		if loaded[mod] then
			return cache[mod]
		end
		if loading[mod] then
			error("cyclic require: " .. path)
		end
		loading[mod] = true
		env.script = mod
		local fn = luau.load(fs.readFile(path), { environment = env, debugName = path })
		local ok, result = xpcall(fn, function(err)
			return tostring(err) .. "\n" .. debug.traceback()
		end)
		loading[mod] = nil
		if not ok then
			error("failed to load " .. path .. "\n" .. tostring(result), 0)
		end
		loaded[mod] = true
		cache[mod] = result
		return result
	end
	env.require = requireModule

	local Data = requireModule(services.DataService)
	local Game = requireModule(services.GameService)
	return {
		roblox = roblox,
		game = game,
		Data = Data,
		Game = Game,
		taskLib = taskLib,
	}
end

return function(test, eq, truthy)
	local luau = require("@lune/luau")
	local fs = require("@lune/fs")
	local roblox = require("@lune/roblox")
	require("./bindable_mock").install(roblox)

	test("signal delivers the same table, and a throwing listener does not block the next", function()
		local errors = 0
		local env = {
			task = {
				spawn = function(fn)
					local co = coroutine.create(fn)
					local ok = coroutine.resume(co)
					if not ok then
						errors += 1
					end
				end,
			},
		}
		local Signal = luau.load(fs.readFile("src/shared/Signal.luau"), { environment = env, debugName = "Signal" })()
		local sig = Signal.new()
		sig.Event:Connect(function()
			error("listener failed")
		end)
		local seen
		sig.Event:Connect(function(profile)
			seen = profile
		end)
		local profile = { coins = 3 }
		sig:Fire(profile)
		eq(errors, 1)
		eq(seen, profile)
		local conn = sig.Event:Connect(function() end)
		conn:Disconnect()
		truthy(conn.Connected == false)
	end)

	test("BindableEvent mock deep-copies tables and strips metatables and functions", function()
		local event = roblox.Instance.new("BindableEvent")
		local part = roblox.Instance.new("Part")
		local fn = function()
			return "nope"
		end
		local inner = setmetatable({ n = 1 }, { __index = { secret = true } })
		local original = { inner = inner, fn = fn, part = part, list = { fn, 2 } }
		original.self = original
		local got
		event.Event:Connect(function(value)
			got = value
		end)
		local laterRan = false
		event.Event:Connect(function()
			error("copy listener failed")
		end)
		event:Fire(original)
		truthy(got ~= original, "table was copied")
		truthy(got.self == got, "cycles copy as cycles")
		eq(got.inner.n, 1)
		truthy(got.inner ~= inner)
		eq(getmetatable(got.inner), nil)
		eq(got.inner.secret, nil)
		eq(got.fn, nil)
		eq(got.list[1], nil)
		eq(got.list[2], 2)
		eq(got.part, part)
		-- A later listener still receives the copy after an earlier one throws.
		local second
		event.Event:Connect(function(value)
			second = value
			laterRan = true
		end)
		event:Fire({ ok = true, fn = fn })
		truthy(laterRan)
		eq(second.ok, true)
		eq(second.fn, nil)
		truthy(second ~= nil)
	end)

	test("after Data.load the runtime has a plot, a snapshot was pushed, and onLoaded saw the stored profile", function()
		local server = openServer()
		local Data = server.Data
		local Game = server.Game
		local player = roblox.Instance.new("Player")
		player.Name = "Casey"
		player.UserId = 42
		player.Parent = server.game:GetService("Players")

		local seenPlayer, seenProfile, seenNew
		Data.onLoaded.Event:Connect(function(who, profile, isNew)
			seenPlayer = who
			seenProfile = profile
			seenNew = isNew
		end)

		local pushes = {}
		local ctx = {
			Data = Data,
			World = {
				assignPlot = function(who)
					eq(who, player)
					return 3
				end,
				refreshStations = function() end,
				releasePlot = function() end,
				effect = function() end,
				spawnCustomer = function() end,
				removeCustomer = function() end,
				smokeSignal = function() end,
			},
			Purchase = {
				loadPasses = function()
					return {}
				end,
				availability = function()
					return {}
				end,
			},
			Season = {
				sync = function() end,
				check = function() end,
				snapshot = function()
					return {}
				end,
			},
			Membership = {
				onLoaded = function() end,
				onNewDay = function() end,
				snapshot = function()
					return {}
				end,
			},
			Social = {
				onJoin = function() end,
				onLeave = function() end,
			},
			Cosmetics = { apply = function() end },
			Insights = {
				onboarding = function() end,
				coins = function() end,
			},
			Remotes = {
				Action = {},
				Push = {
					FireClient = function(_self, who, kind, payload)
						table.insert(pushes, { player = who, kind = kind, payload = payload })
					end,
					FireAllClients = function() end,
				},
			},
		}
		Game.init(ctx)
		Game.start()

		local runtime = Game.runtime[player]
		if not runtime then
			error("runtime was not created\n" .. table.concat(server.taskLib.errors, "\n"))
		end
		eq(seenPlayer, player)
		eq(seenNew, true)
		eq(seenProfile, Data.get(player), "onLoaded profile is the stored profile")
		eq(seenProfile, Data.profiles[player])
		eq(runtime.plot, 3)
		local pushed = false
		for _, push in ipairs(pushes) do
			if push.kind == "state" and push.player == player then
				pushed = true
				eq(push.payload.plot, 3, "snapshot includes the plot")
			end
		end
		truthy(pushed, "a state snapshot was pushed")
	end)
end
