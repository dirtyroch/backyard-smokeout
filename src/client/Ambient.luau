--!strict
--[[
	Ambient — purely cosmetic, client-side life for the map:
	  * fireflies (ParticleEmitters named "Fireflies") switch on at dusk and off at dawn
	  * a few decor critters in Map.Scenery.Critters wander around their home spot
	Nothing here replicates or touches gameplay. Critters far from the camera are skipped.
]]
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Ambient = {}

type Wanderer = {
	model: Model,
	home: Vector3,
	range: number,
	speed: number,
	pos: Vector3,
	target: Vector3,
	wait: number,
	y: number,
	t: number,
}

local rng = Random.new()

local function isNight(): boolean
	local h = Lighting.ClockTime
	return h >= 18.25 or h < 5.75
end

function Ambient.start()
	local map = workspace:WaitForChild("Map", 60)
	if not map then
		return
	end
	local scenery = map:WaitForChild("Scenery", 30)
	if not scenery then
		return
	end

	-- fireflies at dusk
	local emitters: { ParticleEmitter } = {}
	for _, d in ipairs(scenery:GetDescendants()) do
		if d:IsA("ParticleEmitter") and d.Name == "Fireflies" then
			table.insert(emitters, d)
		end
	end
	local lastNight: boolean? = nil
	local function updateNight()
		local n = isNight()
		if n ~= lastNight then
			lastNight = n
			for _, e in ipairs(emitters) do
				e.Enabled = n
			end
		end
	end
	updateNight()
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateNight)

	-- wandering critters
	local wanderers: { Wanderer } = {}
	local folder = scenery:FindFirstChild("Critters")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") then
				local pivot = m:GetPivot()
				table.insert(wanderers, {
					model = m,
					home = pivot.Position,
					range = (m:GetAttribute("Range") :: number?) or 14,
					speed = (m:GetAttribute("Speed") :: number?) or 4,
					pos = pivot.Position,
					target = pivot.Position,
					wait = rng:NextNumber(0, 3),
					y = pivot.Position.Y,
					t = 0,
				})
			end
		end
	end
	if #wanderers == 0 then
		return
	end
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		for _, w in ipairs(wanderers) do
			if (w.pos - camPos).Magnitude > 260 then
				continue
			end
			if w.wait > 0 then
				w.wait -= dt
				continue
			end
			local delta = w.target - w.pos
			local flat = Vector3.new(delta.X, 0, delta.Z)
			if flat.Magnitude < 0.5 then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(2, w.range)
				w.target = w.home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				w.wait = rng:NextNumber(1, 4)
				continue
			end
			local step = math.min(flat.Magnitude, w.speed * dt)
			w.pos += flat.Unit * step
			w.t += dt
			local hop = math.abs(math.sin(w.t * 9)) * 0.25
			local at = Vector3.new(w.pos.X, w.y + hop, w.pos.Z)
			w.model:PivotTo(CFrame.lookAt(at, at + flat.Unit))
		end
	end)
end

return Ambient
