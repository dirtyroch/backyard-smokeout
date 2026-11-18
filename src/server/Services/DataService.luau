--!strict
--[[
	DataService — DataStore persistence with session locking, retries and safe shutdown.

	Record format in the DataStore: { lock = { jobId, time }?, data = <player data> }
	  * Load: UpdateAsync acquires the lock. If another live server holds it (player hopped
	    servers and the old one is still saving), we wait and retry; a lock older than
	    STALE_LOCK seconds, or a lock with a missing / future timestamp from a previous
	    server version, is taken. Each request has a timeout. If Roblox never answers,
	    the ranch opens in memory so the player is not stuck on the loading screen.
	    Memory sessions are not written back.
	  * Autosave every Config.AUTOSAVE_SECONDS refreshes the lock.
	  * Leave / shutdown: final save releases the lock.
	  * If we ever lose the lock, we stop saving for that player (never overwrite newer data).
	  * In Studio without "Enable Studio Access to API Services", we run in memory-only mode.
]]
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local DefaultData = require(Shared.DefaultData)
local SessionLock = require(Shared.Logic.SessionLock)
local Reconcile = require(Shared.Logic.Reconcile)
local Migrate = require(Shared.Logic.Migrate)
local Jimothy = require(Shared.Logic.Jimothy)
local Staff = require(Shared.Logic.Staff)
local Signal = require(Shared.Signal)

local STORE_NAME = "BackyardSmokeout_Players_v1"
local STALE_LOCK = 300 -- seconds
local LOAD_ATTEMPTS = 6
local LOCK_WAIT_BEFORE_STEAL = 3 -- fresh locks from a dead server are taken after this many tries
local ATTEMPT_TIMEOUT = 8 -- seconds; UpdateAsync must not yield forever
local SAVE_ATTEMPTS = 4

export type Profile = {
	player: Player,
	key: string,
	data: any,
	memoryOnly: boolean,
	lostLock: boolean,
	saving: boolean,
	released: boolean,
	loadedAt: number,
}

local DataService = {}
DataService.profiles = {} :: { [Player]: Profile }
-- Listeners must see the stored profile. A BindableEvent would deep-copy it, the
-- copy would fail GameService's identity check, and the ranch would never start.
DataService.onLoaded = Signal.new()

local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))
local store: DataStore? = nil
local _storeError: string? = nil

do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		local why = tostring(result)
		_storeError = why
		warn("[DataService] DataStore unavailable: " .. why)
	end
end

local function keyFor(userId: number): string
	return "u_" .. tostring(userId)
end

local function waitForBudget(requestType: Enum.DataStoreRequestType)
	local tries = 0
	while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 and tries < 20 do
		tries += 1
		task.wait(0.5)
	end
end

local function isApiAccessError(err: string): boolean
	return string.find(err, "403", 1, true) ~= nil
		or string.find(string.lower(err), "studio", 1, true) ~= nil
		or string.find(string.lower(err), "api services", 1, true) ~= nil
end

local function freshData(): any
	return Reconcile.deepCopy(DefaultData)
end

-- UpdateAsync has no engine timeout. A request that never resumes used to sit on the
-- PlayerAdded thread forever, so profiles[player] stayed nil and every action said
-- "Still loading your ranch...". `fn` may yield. A late transform must cancel itself
-- via `alive` once the caller has moved on.
local function callWithTimeout(seconds: number, fn: () -> ()): (boolean, string?)
	local done = false
	local ok = true
	local err: any = nil
	task.spawn(function()
		ok, err = pcall(function(): nil
			fn()
			return nil
		end)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do
		task.wait(0.05)
	end
	if not done then
		return false, "timeout"
	end
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

function DataService.get(player: Player): Profile?
	return DataService.profiles[player]
end

function DataService.waitFor(player: Player, timeout: number): Profile?
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < timeout do
		local p = DataService.profiles[player]
		if p then
			return p
		end
		task.wait(0.2)
	end
	return DataService.profiles[player]
end

local function publish(player: Player, key: string, data: any, memoryOnly: boolean): Profile?
	if not player.Parent then
		return nil
	end
	local isNew = data == nil
	-- Reconcile keeps an existing schema and fills a missing one from the template.
	-- A save with no schema is still a v1 ranch, so remember that before the fill.
	local priorSchema = 2
	if not isNew then
		priorSchema = if type(data) == "table" and type(data.schema) == "number" then data.schema else 1
	end
	data = Reconcile.fill(data or freshData(), DefaultData)
	if priorSchema < 2 then
		data.schema = priorSchema
	end
	local migrated, migrateErr = pcall(function()
		Jimothy.migrate(data)
		Staff.normalize(data)
		Migrate.apply(data, os.time())
	end)
	if not migrated then
		warn("[DataService] Jimothy migrate failed for " .. player.Name .. ": " .. tostring(migrateErr))
	end
	local profile: Profile = {
		player = player,
		key = key,
		data = data,
		memoryOnly = memoryOnly,
		lostLock = false,
		saving = false,
		released = false,
		loadedAt = os.time(),
	}
	DataService.profiles[player] = profile
	DataService.onLoaded:Fire(player, profile, isNew)
	return profile
end

local function loadInner(player: Player): Profile?
	local key = keyFor(player.UserId)
	local memoryOnly = false
	local data = nil
	local got = false

	if store == nil then
		memoryOnly = true
	else
		local s = store :: DataStore
		local current: any = nil
		local lockedWaits = 0
		for attempt = 1, LOAD_ATTEMPTS do
			if not player.Parent then
				return nil
			end
			local status = "error"
			local loaded = nil
			local gen = {}
			current = gen
			local force = lockedWaits >= LOCK_WAIT_BEFORE_STEAL
			-- Budget check is inside the pcall. It used to sit outside, so a throw there
			-- killed the join thread with no profile and no fallback.
			local okCall, why = callWithTimeout(ATTEMPT_TIMEOUT, function()
				waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
				s:UpdateAsync(key, function(old)
					if gen ~= current then
						return nil
					end
					local rec, st = SessionLock.acquire(old, jobId, os.time(), STALE_LOCK, force)
					status = st
					if rec then
						loaded = rec.data
					end
					return rec
				end)
			end)
			if not okCall then
				current = nil
				local msg = why or "error"
				warn(string.format("[DataService] load attempt %d failed for %s: %s", attempt, player.Name, msg))
				if msg == "timeout" then
					-- A stuck request will not answer a second one queued behind it.
					break
				end
				if RunService:IsStudio() and isApiAccessError(msg) then
					memoryOnly = true
					break
				end
				task.wait(math.min(2 ^ attempt, 8))
			elseif status == "acquired" or status == "stale-taken" then
				data = loaded
				got = true
				break
			elseif status == "locked" then
				lockedWaits += 1
				if force then
					warn("[DataService] lock for " .. player.Name .. " was still held after the wait; steal failed")
				end
				task.wait(math.min(2 * attempt, 6))
			else
				warn(string.format("[DataService] load attempt %d for %s returned %s", attempt, player.Name, status))
				task.wait(math.min(2 ^ attempt, 8))
			end
		end
		if not got and not memoryOnly then
			-- Do not kick. Kicking (or hanging) is what left players on the loading screen.
			-- This session will not write, so it cannot overwrite the real save.
			warn("[DataService] opening " .. player.Name .. " in memory; Roblox save servers did not answer")
			memoryOnly = true
			data = nil
		end
	end

	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if got and not memoryOnly and store then
			pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old)
					if type(old) == "table" and old.lock and old.lock.jobId == jobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return nil
	end

	return publish(player, key, data, memoryOnly)
end

function DataService.load(player: Player): Profile?
	local ok, result = xpcall(function()
		return loadInner(player)
	end, debug.traceback)
	if ok then
		return result
	end
	warn("[DataService] load crashed for " .. player.Name .. ":\n" .. tostring(result))
	if not player.Parent then
		return nil
	end
	if DataService.profiles[player] then
		return DataService.profiles[player]
	end
	return publish(player, keyFor(player.UserId), nil, true)
end

-- Returns true if the data is safely in the DataStore.
function DataService.save(profile: Profile, release: boolean): boolean
	if profile.memoryOnly then
		return true
	end
	if profile.lostLock or store == nil then
		return false
	end
	-- Don't run two saves for the same player at once.
	local waited = 0
	while profile.saving and waited < 30 do
		task.wait(0.25)
		waited += 0.25
	end
	if profile.released then
		-- The final save already ran and dropped our lock (e.g. an autosave that queued up behind
		-- the leave save). Writing now would re-lock the record and block the player's next join.
		return false
	end
	profile.saving = true
	profile.data.lastSeen = os.time()
	local s = store :: DataStore
	local saved = false
	for attempt = 1, SAVE_ATTEMPTS do
		waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
		local status = "error"
		local ok, err = pcall(function()
			s:UpdateAsync(profile.key, function(old)
				local rec, st = SessionLock.save(old, jobId, os.time(), profile.data, release)
				status = st
				return rec
			end)
		end)
		if ok and status == "saved" then
			saved = true
			break
		elseif ok and status == "lost-lock" then
			warn("[DataService] lost session lock for " .. profile.key .. "; not overwriting newer data")
			profile.lostLock = true
			break
		else
			warn(string.format("[DataService] save attempt %d failed for %s: %s", attempt, profile.key, tostring(err)))
			task.wait(math.min(2 ^ attempt, 8))
		end
	end
	profile.saving = false
	if release and saved then
		profile.released = true
	end
	return saved
end

function DataService.release(player: Player)
	local profile = DataService.profiles[player]
	if not profile then
		return
	end
	DataService.save(profile, true)
	-- Whatever happened, this server is done with the profile: no more writes after this.
	profile.released = true
	if DataService.profiles[player] == profile then
		DataService.profiles[player] = nil
	end
end

function DataService.isStudioMemoryMode(player: Player): boolean
	local p = DataService.profiles[player]
	return p ~= nil and p.memoryOnly
end

function DataService.start()
	-- Autosave loop (also refreshes our session locks).
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			for _, profile in pairs(DataService.profiles) do
				task.spawn(DataService.save, profile, false)
				task.wait(0.5) -- spread requests out
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and store == nil then
			return
		end
		local pending = 0
		for player, _ in pairs(DataService.profiles) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

-- NOTE: GameService handles PlayerRemoving (settles cooks first) and then calls DataService.release.

return DataService
