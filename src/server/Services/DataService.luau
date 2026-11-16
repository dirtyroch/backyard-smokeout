--!strict
--[[
	DataService — DataStore persistence with session locking, retries and safe shutdown.

	Record format in the DataStore: { lock = { jobId, time }?, data = <player data> }
	  * Load: UpdateAsync acquires the lock. If another live server holds it (player hopped
	    servers and the old one is still saving), we wait and retry; a lock older than
	    STALE_LOCK seconds is treated as abandoned.
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

local STORE_NAME = "BackyardSmokeout_Players_v1"
local STALE_LOCK = 300 -- seconds
local LOAD_ATTEMPTS = 8
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
DataService.onLoaded = Instance.new("BindableEvent")

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

function DataService.load(player: Player): Profile?
	local key = keyFor(player.UserId)
	local memoryOnly = false
	local data = nil

	if store == nil then
		memoryOnly = true
	else
		local s = store :: DataStore
		for attempt = 1, LOAD_ATTEMPTS do
			if not player.Parent then
				return nil
			end
			waitForBudget(Enum.DataStoreRequestType.UpdateAsync)
			local status = "error"
			local loaded = nil
			local ok, err = pcall(function()
				s:UpdateAsync(key, function(old)
					local rec, st = SessionLock.acquire(old, jobId, os.time(), STALE_LOCK)
					status = st
					if rec then
						loaded = rec.data
					end
					return rec
				end)
			end)
			if ok and (status == "acquired" or status == "stale-taken") then
				data = loaded
				break
			elseif ok and status == "locked" then
				-- Another server is still finishing this player's save. Wait for it.
				task.wait(math.min(2 * attempt, 8))
			else
				local msg = tostring(err)
				warn(string.format("[DataService] load attempt %d failed for %s: %s", attempt, player.Name, msg))
				if RunService:IsStudio() and isApiAccessError(msg) then
					memoryOnly = true
					break
				end
				task.wait(math.min(2 ^ attempt, 16))
			end
			if attempt == LOAD_ATTEMPTS then
				player:Kick("We couldn't load your ranch safely (Roblox servers are busy). Please rejoin in a minute. Your progress is safe.")
				return nil
			end
		end
	end

	if not player.Parent then
		-- Left while loading: release the lock we just took.
		if not memoryOnly and store then
			pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old)
					if old and old.lock and old.lock.jobId == jobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return nil
	end

	local isNew = data == nil
	data = Reconcile.fill(data or freshData(), DefaultData)
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
