--!strict
-- Client networking: one RemoteFunction for requests, one RemoteEvent for server pushes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action = Remotes:WaitForChild("Action") :: RemoteFunction
local Push = Remotes:WaitForChild("Push") :: RemoteEvent

local Net = {}
Net.state = nil :: any
Net.changed = Instance.new("BindableEvent")
Net.notify = function(_text: string, _kind: string?) end
local handlers: { [string]: { (any) -> () } } = {}

function Net.on(kind: string, fn: (any) -> ())
	handlers[kind] = handlers[kind] or {}
	table.insert(handlers[kind], fn)
end

-- Ask the server to do something. Shows the server's message as a toast.
function Net.act(action: string, a: any?, b: any?, c: any?): (boolean, string?)
	local ok, res = pcall(function()
		return Action:InvokeServer(action, a, b, c)
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

Push.OnClientEvent:Connect(function(kind: string, payload: any)
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
end)

return Net
