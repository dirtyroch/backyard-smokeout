--!strict
--[[
	Session locking for DataStore records shaped { lock = {jobId, time}?, data = {...} }.
	A server may only write a record it holds the lock for. Locks are refreshed on every autosave;
	a lock older than `staleAfter` seconds is treated as abandoned (crashed server) and can be taken.
	These are the pure transform helpers used inside DataStore:UpdateAsync.
]]
local SessionLock = {}

export type Record = { lock: { jobId: string, time: number }?, data: any? }

-- Returns (newRecord or nil to cancel, status)
function SessionLock.acquire(old: Record?, jobId: string, now: number, staleAfter: number): (Record?, string)
	local rec: Record = old or { data = nil }
	local lock = rec.lock
	if lock and lock.jobId ~= jobId and (now - lock.time) < staleAfter then
		return nil, "locked"
	end
	local stolen = lock ~= nil and lock.jobId ~= jobId
	rec.lock = { jobId = jobId, time = now }
	return rec, stolen and "stale-taken" or "acquired"
end

-- Only the server that holds the lock may write. A record with no lock was released (the
-- player left, or another server already loaded, played and released it), so a late write from
-- us would overwrite newer progress and leave a phantom lock behind: refuse it.
function SessionLock.canWrite(old: Record?, jobId: string): boolean
	if old == nil then
		return true
	end
	local lock = (old :: Record).lock
	return lock ~= nil and lock.jobId == jobId
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
