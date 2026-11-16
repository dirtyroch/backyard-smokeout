--!strict
--[[
	Ambient — purely cosmetic, client-side life for the map:
	  * fireflies (ParticleEmitters named "Fireflies") switch on at dusk and off at dawn
	  * a few decor critters in Map.Scenery.Critters wander around their home spot
	Nothing here replicates or touches gameplay. Critters far from the camera are skipped.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Jimothy = require(Shared.Logic.Jimothy)

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

type Parade = {
	model: Model,
	points: { Vector3 },
	index: number,
	pos: Vector3,
	t: number,
	nextLine: number,
	showUntil: number,
	line: number,
	gui: BillboardGui?,
	label: TextLabel?,
}

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
	-- Hub Jimothy: a fixed loop, a fast waddle, and a short speech bubble up close
	-- (or a brief one every few seconds when nobody's next to him).
	local parade: Parade? = nil
	local hub = map:FindFirstChild("Hub")
	local npc = hub and hub:FindFirstChild("JimothyWander")
	local path = hub and hub:FindFirstChild("JimothyPath")
	if npc and npc:IsA("Model") and path then
		local pts: { Vector3 } = {}
		local marks: { BasePart } = {}
		for _, p in ipairs(path:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(marks, p)
			end
		end
		table.sort(marks, function(a, b)
			return a.Name < b.Name
		end)
		for _, p in ipairs(marks) do
			table.insert(pts, p.Position)
		end
		if #pts >= 2 then
			local guiInst = npc:FindFirstChild("Speech", true)
			local gui = if guiInst and guiInst:IsA("BillboardGui") then guiInst else nil
			local textInst = gui and gui:FindFirstChild("Text")
			local label = if textInst and textInst:IsA("TextLabel") then textInst else nil
			parade = {
				model = npc,
				points = pts,
				index = 2,
				pos = pts[1],
				t = 0,
				nextLine = os.clock() + 2.4,
				showUntil = 0,
				line = 1,
				gui = gui,
				label = label,
			}
			npc:PivotTo(CFrame.lookAt(pts[1], pts[2]))
		end
	end

	if #wanderers == 0 and parade == nil then
		return
	end
	local player = Players.LocalPlayer
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position or Vector3.zero
		if parade then
			local w = parade
			local target = w.points[w.index]
			local delta = target - w.pos
			local flat = Vector3.new(delta.X, 0, delta.Z)
			w.t += dt
			if flat.Magnitude < 0.45 then
				w.index = w.index % #w.points + 1
				target = w.points[w.index]
				delta = target - w.pos
				flat = Vector3.new(delta.X, 0, delta.Z)
			end
			if flat.Magnitude > 0.05 then
				local step = math.min(flat.Magnitude, 11 * dt)
				w.pos += flat.Unit * step
				local hop = math.abs(math.sin(w.t * 16)) * 0.42
				local at = Vector3.new(w.pos.X, target.Y + hop, w.pos.Z)
				w.model:PivotTo(CFrame.lookAt(at, at + flat.Unit) * CFrame.Angles(0, 0, math.sin(w.t * 16) * 0.26))
			end
			local now = os.clock()
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local near = hrp ~= nil and (hrp.Position - w.pos).Magnitude < 18
			if w.label and now >= w.nextLine then
				w.line = w.line % #Jimothy.LINES + 1
				w.label.Text = Jimothy.LINES[w.line]
				w.nextLine = now + (if near then 2.6 else 8)
				if not near then
					w.showUntil = now + 2.2
				end
			end
			if w.gui then
				w.gui.Enabled = near or now < w.showUntil
			end
		end
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
