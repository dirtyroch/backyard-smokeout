--!strict
--[[
	Session locking for DataStore records shaped { lock = {jobId, time}?, data = {...} }.
	A server may only write a record it holds the lock for. Locks are refreshed on every autosave;
	a lock older than `staleAfter` seconds is treated as abandoned (crashed server) and can be taken.
	These are the pure transform helpers used inside DataStore:UpdateAsync.
]]
local SessionLock = {}

export type Record = { lock: { jobId: string, time: number }?, data: any? }

-- A different server's lock is still live. Missing, non-numeric, NaN, or far-future
-- timestamps are not live: a previous build (or a crashed server) must not block joins forever.
-- `now - lock.time` used to throw when `time` wasn't a number, which aborted the DataStore
-- transform and left the player with no profile.
function SessionLock.heldByOther(lock: any, jobId: string, now: number, staleAfter: number): boolean
	if type(lock) ~= "table" then
		return false
	end
	local owner = lock.jobId
	if type(owner) ~= "string" or owner == jobId then
		return false
	end
	local t = lock.time
	if type(t) ~= "number" or t ~= t then
		return false
	end
	if t > now + 120 then
		return false
	end
	return (now - t) < staleAfter
end

-- Returns (newRecord or nil to cancel, status).
-- `force` takes a lock another server still holds. DataService does this after a short wait
-- so a dead server from the previous version can't keep the ranch closed.
function SessionLock.acquire(old: any, jobId: string, now: number, staleAfter: number, force: boolean?): (Record?, string)
	local rec: Record = if type(old) == "table" then old else { data = nil }
	local lock = rec.lock
	if not force and SessionLock.heldByOther(lock, jobId, now, staleAfter) then
		return nil, "locked"
	end
	local stolen = type(lock) == "table" and lock.jobId ~= jobId
	rec.lock = { jobId = jobId, time = now }
	return rec, if stolen then "stale-taken" else "acquired"
end

-- Only the server that holds the lock may write. A record with no lock was released (the
-- player left, or another server already loaded, played and released it), so a late write from
-- us would overwrite newer progress and leave a phantom lock behind: refuse it.
function SessionLock.canWrite(old: any, jobId: string): boolean
	if old == nil then
		return true
	end
	if type(old) ~= "table" then
		return false
	end
	local lock = old.lock
	return type(lock) == "table" and lock.jobId == jobId
end

-- Transform for saves. `release` clears the lock (player left / server closing).
function SessionLock.save(old: Record?, jobId: string, now: number, data: any, release: boolean): (Record?, string)
	if not SessionLock.canWrite(old, jobId) then
		return nil, "lost-lock"
	end
	local rec: Record = { data = data, lock = nil }
	if not release then
		rec.lock = { jobId = jobId, time = now }
	end
	return rec, "saved"
end

return SessionLock
