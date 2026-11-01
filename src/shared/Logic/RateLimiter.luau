--!strict
-- Token bucket per key. `now` is passed in (server uses os.clock()) so it's testable.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limiter = typeof(setmetatable({} :: { capacity: number, refill: number, buckets: { [any]: { tokens: number, t: number } } }, RateLimiter))

function RateLimiter.new(capacity: number, refillPerSecond: number): Limiter
	return setmetatable({ capacity = capacity, refill = refillPerSecond, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: Limiter, key: any, now: number, cost: number?): boolean
	local c = cost or 1
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, t = now }
		self.buckets[key] = b
	end
	b.tokens = math.min(self.capacity, b.tokens + (now - b.t) * self.refill)
	b.t = now
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

function RateLimiter.forget(self: Limiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
