--!strict
-- Crew and Hiring Line critters are posed on each client. The server only stores
-- where they are going (CrewAnim attributes) and pays the coins.
local RunService = game:GetService("RunService")

local CrewAnim = {}

type Mover = {
	model: Model,
	points: { Vector3 },
	length: number,
}

local movers: { Mover } = {}
local seen: { [Model]: boolean } = {}

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

local function along(points: { Vector3 }, distance: number): (Vector3, Vector3)
	local remain = distance
	for i = 1, #points - 1 do
		local span = (points[i + 1] - points[i]).Magnitude
		if remain <= span or i == #points - 1 then
			local alpha = if span > 0.05 then math.clamp(remain / span, 0, 1) else 0
			local pos = points[i]:Lerp(points[i + 1], alpha)
			local face = points[i + 1] - points[i]
			return pos, face
		end
		remain -= span
	end
	local last = points[#points]
	return last, Vector3.new(0, 0, -1)
end

local function track(model: Model)
	if seen[model] or not model:IsA("Model") then
		return
	end
	if model:GetAttribute("CrewAnim") == nil then
		return
	end
	local points = decode(model:GetAttribute("AnimPoints"))
	if #points < 2 then
		return
	end
	seen[model] = true
	table.insert(movers, { model = model, points = points, length = math.max(lengthOf(points), 0.05) })
end

local function step(mover: Mover, now: number)
	local model = mover.model
	if not model.Parent then
		return
	end
	local speed = model:GetAttribute("AnimSpeed")
	local pace = if type(speed) == "number" and speed > 0 then speed else 4
	local phase = model:GetAttribute("AnimPhase")
	local shift = if type(phase) == "number" then phase else 0
	local kind = model:GetAttribute("CrewAnim")
	local distance
	if kind == "once" then
		local start = model:GetAttribute("AnimStart")
		local began = if type(start) == "number" then start else now
		distance = math.clamp((now - began) * pace, 0, mover.length)
	else
		distance = (now * pace + shift * 1.7) % mover.length
	end
	local pos, face = along(mover.points, distance)
	local flat = Vector3.new(face.X, 0, face.Z)
	local look = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
	local bob = math.abs(math.sin(now * 8 + shift)) * 0.22
	local at = pos + Vector3.new(0, bob, 0)
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
