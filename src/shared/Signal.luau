--!strict
-- Same-side signal that keeps the caller's arguments.
-- A BindableEvent is the wrong tool for this: Roblox deep-copies tables, drops
-- metatables and functions, and the copy is not the value the sender fired.
-- Listeners run on their own threads so one error cannot cancel the others.
local Signal = {}
Signal.__index = Signal

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

type Handler = (...any) -> ()

export type Signal = typeof(setmetatable(
	{} :: {
		Event: any,
		_next: number,
		_order: { number },
		_handlers: { [number]: Handler },
	},
	Signal
))

function Signal.new(): Signal
	local self = setmetatable({
		Event = nil :: any,
		_next = 0,
		_order = {},
		_handlers = {},
	}, Signal)
	-- BindableEvent callers use `.Event:Connect`. Event is this signal.
	self.Event = self
	return self
end

function Signal.Connect(self: Signal, fn: Handler): Connection
	self._next += 1
	local id = self._next
	self._handlers[id] = fn
	table.insert(self._order, id)
	local conn: Connection = {
		Connected = true,
		Disconnect = function(connSelf: Connection)
			if not connSelf.Connected then
				return
			end
			connSelf.Connected = false
			self._handlers[id] = nil
			local order = self._order
			for i, got in ipairs(order) do
				if got == id then
					table.remove(order, i)
					break
				end
			end
		end,
	}
	return conn
end

function Signal.Fire(self: Signal, ...: any)
	local packed = table.pack(...)
	-- Snapshot first so a listener can disconnect or connect during the fire.
	local fns: { Handler } = {}
	for _, id in ipairs(self._order) do
		local fn = self._handlers[id]
		if fn then
			table.insert(fns, fn)
		end
	end
	for _, fn in ipairs(fns) do
		local handler = fn
		task.spawn(function()
			handler(table.unpack(packed, 1, packed.n))
		end)
	end
end

return Signal
