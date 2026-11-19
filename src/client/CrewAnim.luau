--!strict
-- Crew and Hiring Line critters are posed on each client. The server only stores
-- where they are going (CrewAnim attributes) and pays the coins.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CrewMotion = require(Shared.Logic.CrewMotion)

local CrewAnim = {}

type Mover = {
	model: Model,
	points: { Vector3 },
	length: number,
	raw: string,
	cheapAt: number,
	vecs: { { number } },
}

local movers: { Mover } = {}
local seen: { [Model]: boolean } = {}
local watching: { [Model]: RBXScriptConnection } = {}

local function decode(text: any): { Vector3 }
	local points = {}
	if type(text) ~= "string" then
		return points
	end
	for chunk in string.gmatch(text, "[^|]+") do
		local x, y, z = string.match(chunk, "([^,]+),([^,]+),([^,]+)")
		local nx, ny, nz = tonumber(x), tonumber(y), tonumber(z)
		if nx and ny and nz then
			table.insert(points, Vector3.new(nx, ny, nz))
		end
	end
	return points
end

local function lengthOf(points: { Vector3 }): number
	local total = 0
	for i = 1, #points - 1 do
		total += (points[i + 1] - points[i]).Magnitude
	end
	return total
end

local function toVecs(points: { Vector3 }): { { number } }
	local vecs = {}
	for _, p in ipairs(points) do
		table.insert(vecs, { p.X, p.Y, p.Z })
	end
	return vecs
end

local track: (Model) -> ()
track = function(model: Model)
	if seen[model] or not model:IsA("Model") then
		return
	end
	-- A streamed/replicated Model can arrive before its animation attributes. Watch
	-- for readiness rather than dropping it forever after DescendantAdded.
	if not watching[model] then
		watching[model] = model.AttributeChanged:Connect(function()
			track(model)
		end)
	end
	if model:GetAttribute("CrewAnim") == nil then
		return
	end
	local points = decode(model:GetAttribute("AnimPoints"))
	if #points < 2 then
		return
	end
	seen[model] = true
	if watching[model] then
		watching[model]:Disconnect()
		watching[model] = nil
	end
	table.insert(movers, { model = model, points = points, length = math.max(lengthOf(points), 0.05), raw = model:GetAttribute("AnimPoints") :: string, cheapAt = 0, vecs = toVecs(points) })
end

local function step(mover: Mover, now: number)
	local model = mover.model
	if not model.Parent then
		return
	end
	-- The server re-tags a model when its path changes (a hire walking home), so pick up new points.
	local raw = model:GetAttribute("AnimPoints")
	if type(raw) == "string" and raw ~= mover.raw then
		local points = decode(raw)
		if #points >= 2 then
			mover.points = points
			mover.length = math.max(lengthOf(points), 0.05)
			mover.vecs = toVecs(points)
		end
		mover.raw = raw
	end
	local speed = model:GetAttribute("AnimSpeed")
	local pace = if type(speed) == "number" and speed > 0 then speed else 4
	local phase = model:GetAttribute("AnimPhase")
	local shift = if type(phase) == "number" then phase else 0
	local kind = if model:GetAttribute("CrewAnim") == "once" then "once" else "loop"
	local startAttr = model:GetAttribute("AnimStart")
	local began = if type(startAttr) == "number" then startAttr else nil
	local x, y, z = CrewMotion.pose(mover.vecs, now, pace, shift, kind, began)
	-- Cull by where the critter should be, not where it was last drawn. A late joiner's copy
	-- still sits at the server's first point, which can be far from its real path.
	local cam = workspace.CurrentCamera
	if cam then
		local dist = (cam.CFrame.Position - Vector3.new(x, y, z)).Magnitude
		local detail = CrewMotion.detail(dist, Config.CrewLod.near, Config.CrewLod.far)
		if detail == "freeze" then
			return
		elseif detail == "cheap" and now - mover.cheapAt < Config.CrewLod.cheapStep then
			return
		end
		if detail == "cheap" then
			mover.cheapAt = now
		end
	end
	local x2, _, z2 = CrewMotion.pose(mover.vecs, now + 0.08, pace, shift, kind, began)
	local flat = Vector3.new(x2 - x, 0, z2 - z)
	local look = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
	local at = Vector3.new(x, y, z)
	model:PivotTo(CFrame.lookAt(at, at + look))
end

function CrewAnim.start()
	local function scan(root: Instance)
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") then
				track(d)
			end
		end
	end
	scan(workspace)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			track(d)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for model, connection in pairs(watching) do
			if not model:IsDescendantOf(workspace) then
				connection:Disconnect()
				watching[model] = nil
			end
		end
		local keep = {}
		for _, mover in ipairs(movers) do
			if mover.model.Parent then
				step(mover, now)
				table.insert(keep, mover)
			else
				seen[mover.model] = nil
			end
		end
		movers = keep
	end)
end

return CrewAnim
