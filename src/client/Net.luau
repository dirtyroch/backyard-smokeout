--!strict
-- Client networking: one RemoteFunction for requests, one RemoteEvent for server pushes.
-- Remotes are created by the server script. Waiting forever here used to freeze the client
-- before any UI existed if that script was still starting (or had died before creating them).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)

local Net = {}
Net.state = nil :: any
-- Not a BindableEvent: those copy the snapshot, so listeners would not see Net.state.
Net.changed = Signal.new()
Net.notify = function(_text: string, _kind: string?) end
local handlers: { [string]: { (any) -> () } } = {}
local action: RemoteFunction? = nil
local push: RemoteEvent? = nil
local listening = false

local function onPush(kind: string, payload: any)
	if kind == "state" then
		Net.state = payload
		Net.changed:Fire(payload)
	end
	local list = handlers[kind]
	if list then
		for _, fn in ipairs(list) do
			task.spawn(fn, payload)
		end
	end
end

local function ensure(): boolean
	if action and push then
		return true
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		return false
	end
	local a = folder:FindFirstChild("Action")
	local p = folder:FindFirstChild("Push")
	if not a or not a:IsA("RemoteFunction") or not p or not p:IsA("RemoteEvent") then
		return false
	end
	local remote = p :: RemoteEvent
	action = a :: RemoteFunction
	push = remote
	if not listening then
		listening = true
		remote.OnClientEvent:Connect(onPush)
	end
	return true
end

function Net.ready(): boolean
	return ensure()
end

function Net.on(kind: string, fn: (any) -> ())
	handlers[kind] = handlers[kind] or {}
	table.insert(handlers[kind], fn)
end

-- Ask the server to do something. Shows the server's message as a toast.
function Net.act(name: string, a: any?, b: any?, c: any?): (boolean, string?)
	if not ensure() or not action then
		Net.notify("Connection hiccup. Try again!", "bad")
		return false, nil
	end
	local fn = action :: RemoteFunction
	local ok, res = pcall(function()
		return fn:InvokeServer(name, a, b, c)
	end)
	if not ok or type(res) ~= "table" then
		Net.notify("Connection hiccup. Try again!", "bad")
		return false, nil
	end
	if res.msg then
		Net.notify(res.msg, res.ok and "good" or "info")
	end
	return res.ok == true, res.msg
end

-- Quiet "please send my snapshot" used when the first push was missed.
-- Does not toast. Returns true only when the server accepted it.
function Net.pull(): boolean
	if not ensure() or not action then
		return false
	end
	local fn = action :: RemoteFunction
	local ok, res = pcall(function()
		return fn:InvokeServer("Hello")
	end)
	return ok and type(res) == "table" and res.ok == true
end

ensure()
ReplicatedStorage.ChildAdded:Connect(function(child)
	if child.Name == "Remotes" then
		ensure()
	end
end)

return Net
