--!strict
-- The Hiring Line and the ranch crew, in the world.
-- Applicants walk the boardwalk with their price showing. A hire walks home and works a station.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldBuilder = require(Shared.WorldBuilder)
local HiringLine = require(Shared.Logic.HiringLine)
local Crew = require(Shared.Logic.Crew)
local Income = require(Shared.Logic.Income)

local CrewService = {}
local ctx: any = nil

local ENV = {
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	Enum = Enum,
	UDim2 = UDim2,
	NumberSequence = NumberSequence,
	NumberRange = NumberRange,
	ColorSequence = ColorSequence,
	Vector2 = Vector2,
}

type Walker = {
	model: Model,
	points: { Vector3 },
	index: number,
	from: Vector3,
	to: Vector3,
	dist: number,
	walked: number,
	bob: number,
}

local lineState = {
	seed = 1,
	window = -1,
	tier = 1,
	applicants = {} :: { any },
	taken = {} :: { [number]: number },
}
local lineSig = ""
local applicantWalkers: { Walker } = {}
local homeWalkers: { Walker } = {}
local crewWalkers: { [Player]: { Walker } } = {}
local crewSig: { [Player]: string } = {}
local tierSig: { [Player]: number } = {}
local CREW_STEP = 1 / 15
local crewAcc = 0

local function mapModel(): any
	return workspace:FindFirstChild("Map")
end

function CrewService.line(): any
	return lineState
end

function CrewService.init(c: any)
	ctx = c
	WorldBuilder.setEnv(ENV)
end

local function hexColor(h: string): Color3
	local ok, color = pcall(function()
		return Color3.fromHex(h)
	end)
	if ok and typeof(color) == "Color3" then
		return color
	end
	return Color3.fromRGB(255, 220, 160)
end

local function offerText(applicant: any): string
	local trait = if applicant.trait ~= nil and applicant.trait ~= "none" then (" · " .. applicant.traitName) else ""
	return string.format("%s%s · %s · %d coins", applicant.rarityName, trait, Income.format(applicant.rate), applicant.price)
end

local function appearance(applicant: any, staff: boolean): any
	return {
		id = applicant.model,
		body = applicant.body,
		head = applicant.head,
		scale = applicant.scale or 0.92,
		style = applicant.style,
		staff = staff,
		rex = applicant.model == "rex" or applicant.secret == true,
	}
end

local function addProp(model: Model, role: string)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local cf = root.CFrame * CFrame.new(0.7, 0.2, -0.8)
	if role == "pit" then
		local handle = Instance.new("Part")
		handle.Name = "Mop"
		handle.Anchored = true
		handle.CanCollide = false
		handle.Size = Vector3.new(0.12, 1.4, 0.12)
		handle.CFrame = cf
		handle.Color = Color3.fromHex("#C9852A")
		handle.Parent = model
		local head = Instance.new("Part")
		head.Name = "MopHead"
		head.Anchored = true
		head.CanCollide = false
		head.Size = Vector3.new(0.45, 0.28, 0.45)
		head.CFrame = cf * CFrame.new(0, -0.7, 0)
		head.Color = Color3.fromHex("#F4E1C1")
		head.Parent = model
	elseif role == "grill" then
		local tongs = Instance.new("Part")
		tongs.Name = "Tongs"
		tongs.Anchored = true
		tongs.CanCollide = false
		tongs.Size = Vector3.new(0.12, 0.9, 0.28)
		tongs.CFrame = cf
		tongs.Color = Color3.fromHex("#C0C0C0")
		tongs.Material = Enum.Material.Metal
		tongs.Parent = model
	elseif role == "server" then
		local tray = Instance.new("Part")
		tray.Name = "Tray"
		tray.Anchored = true
		tray.CanCollide = false
		tray.Size = Vector3.new(0.9, 0.08, 0.6)
		tray.CFrame = cf * CFrame.new(0, 0.4, 0)
		tray.Color = Color3.fromHex("#F4E1C1")
		tray.Parent = model
	else
		local flag = Instance.new("Part")
		flag.Name = "Flag"
		flag.Anchored = true
		flag.CanCollide = false
		flag.Size = Vector3.new(0.08, 1.1, 0.08)
		flag.CFrame = cf
		flag.Color = Color3.fromHex("#6B4226")
		flag.Parent = model
		local cloth = Instance.new("Part")
		cloth.Name = "FlagCloth"
		cloth.Anchored = true
		cloth.CanCollide = false
		cloth.Size = Vector3.new(0.55, 0.35, 0.05)
		cloth.CFrame = cf * CFrame.new(0.3, 0.35, 0)
		cloth.Color = Color3.fromHex("#E07A3D")
		cloth.Parent = model
	end
end

local function addAura(model: Model, color: string)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "Aura"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Size = Vector3.new(0.12, 2.4, 2.4)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, root.Size.Y * 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = hexColor(color)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Parent = model
end

local function quiet(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function walkerFrom(model: Model, points: { Vector3 }, startAt: number): Walker?
	if #points < 2 then
		return nil
	end
	local lift = model:GetPivot().Position.Y
	local lifted = {}
	for _, p in ipairs(points) do
		table.insert(lifted, p + Vector3.new(0, lift, 0))
	end
	local a = ((startAt - 1) % #lifted) + 1
	local b = a % #lifted + 1
	model:PivotTo(CFrame.lookAt(lifted[a], lifted[b]))
	return {
		model = model,
		points = lifted,
		index = b,
		from = lifted[a],
		to = lifted[b],
		dist = (lifted[b] - lifted[a]).Magnitude,
		walked = 0,
		bob = startAt,
	}
end

local function stepWalker(w: Walker, dt: number, speed: number)
	if not w.model.Parent then
		return
	end
	w.walked += speed * dt
	local span = math.max(w.dist, 0.05)
	local a = math.clamp(w.walked / span, 0, 1)
	local pos = w.from:Lerp(w.to, a)
	local bob = math.abs(math.sin(os.clock() * 8 + w.bob)) * 0.28
	local flat = Vector3.new(w.to.X - w.from.X, 0, w.to.Z - w.from.Z)
	local face = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)
	local at = pos + Vector3.new(0, bob, 0)
	w.model:PivotTo(CFrame.lookAt(at, at + face))
	if a >= 1 then
		w.index = w.index % #w.points + 1
		w.from = w.to
		w.to = w.points[w.index]
		w.dist = (w.to - w.from).Magnitude
		w.walked = 0
	end
end

local function hiringFolder(): Folder?
	local map = mapModel()
	local hub = map and map:FindFirstChild("Hub")
	local line = hub and hub:FindFirstChild("HiringLine")
	if not line then
		return nil
	end
	local folder = line:FindFirstChild("Applicants")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Applicants"
		folder.Parent = line
	end
	return folder :: Folder
end

local function padPoints(): { Vector3 }
	local map = mapModel()
	local hub = map and map:FindFirstChild("Hub")
	local line = hub and hub:FindFirstChild("HiringLine")
	local pads = line and line:FindFirstChild("Pads")
	local points = {}
	if not pads then
		return points
	end
	for i = 1, Config.Hiring.count do
		local pad = pads:FindFirstChild("Pad" .. i)
		if pad and pad:IsA("BasePart") then
			table.insert(points, pad.Position + Vector3.new(0, 0.2, 0))
		end
	end
	return points
end

local function spawnApplicants()
	local folder = hiringFolder()
	if not folder then
		return
	end
	folder:ClearAllChildren()
	table.clear(applicantWalkers)
	local points = padPoints()
	if #points < 2 then
		return
	end
	for _, applicant in ipairs(lineState.applicants) do
		if lineState.taken[applicant.index] == nil then
			local model = WorldBuilder.critter(ENV, folder, appearance(applicant, false), CFrame.new())
			model.Name = "Applicant" .. applicant.index
			model:SetAttribute("Applicant", applicant.index)
			quiet(model)
			addAura(model, applicant.color)
			local head = model:FindFirstChild("Head")
			local adornee = if head and head:IsA("BasePart") then head else model.PrimaryPart
			if adornee then
				WorldBuilder.billboard(adornee, "NameTag", applicant.name, 2.2, 90, "#FFF6E0", 180, 28, { 5.2, 0.7, 90, 16 })
				WorldBuilder.billboard(adornee, "Offer", offerText(applicant), 3.2, 90, applicant.color, 260, 36, { 7.5, 0.9, 120, 16 })
			end
			local body = model:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				local prompt = WorldBuilder.prompt(body, "hire", "Hire", applicant.name, 0, 12)
				prompt:SetAttribute("Applicant", applicant.index)
			end
			local walker = walkerFrom(model, points, applicant.index)
			if walker then
				table.insert(applicantWalkers, walker)
			end
		end
	end
end

local function lineSignature(): string
	local parts = { tostring(lineState.window), tostring(lineState.tier) }
	for i = 1, Config.Hiring.count do
		table.insert(parts, tostring(lineState.taken[i] or 0))
	end
	return table.concat(parts, ":")
end

local function maxTier(): number
	local best = 1
	for _, player in ipairs(Players:GetPlayers()) do
		local data = ctx.Game.dataOf(player)
		if type(data) == "table" and type(data.ranch) == "table" and type(data.ranch.tier) == "number" then
			best = math.max(best, data.ranch.tier)
		end
	end
	return math.clamp(best, 1, #Config.RanchTiers)
end

local function restock()
	local now = os.time()
	local window = HiringLine.window(now, Config.Hiring.period)
	local tier = if lineState.window == window then lineState.tier else maxTier()
	if lineState.window ~= window then
		lineState.window = window
		lineState.tier = tier
		lineState.applicants = HiringLine.stock(lineState.seed, window, tier)
		lineState.taken = {}
	end
	local sig = lineSignature()
	if sig ~= lineSig then
		lineSig = sig
		spawnApplicants()
	end
	local map = mapModel()
	local hub = map and map:FindFirstChild("Hub")
	local line = hub and hub:FindFirstChild("HiringLine")
	local board = line and line:FindFirstChild("RestockBoard")
	if board then
		for _, d in ipairs(board:GetDescendants()) do
			if d.Name == "Clock" and d:IsA("TextLabel") then
				d.Text = HiringLine.clockLabel(now, Config.Hiring.period, Config.TIMEZONE_OFFSET_HOURS)
			end
		end
	end
end

local function stationPoints(plot: any, role: string): { Vector3 }
	local points = {}
	local stations = plot:FindFirstChild("CrewStations")
	local name = if role == "pit" then "Pit" elseif role == "grill" then "Grill" elseif role == "server" then "Serve" else "Greet"
	local pad = stations and stations:FindFirstChild(name)
	if pad and pad:IsA("BasePart") then
		table.insert(points, pad.Position)
		local ahead = pad.CFrame.LookVector
		table.insert(points, pad.Position + Vector3.new(ahead.X, 0, ahead.Z).Unit * 3.5)
		return points
	end
	local spawn = plot:FindFirstChild("SpawnPad")
	if spawn and spawn:IsA("BasePart") then
		table.insert(points, spawn.Position)
		table.insert(points, spawn.Position + Vector3.new(3, 0, 0))
	end
	return points
end

local function showTiers(plot: any, tier: number)
	local root = plot:FindFirstChild("RanchTiers")
	if not root then
		return
	end
	for _, piece in ipairs(root:GetChildren()) do
		local minTier = piece:GetAttribute("MinTier")
		local need = if type(minTier) == "number" then minTier else 99
		local on = tier >= need
		for _, d in ipairs(piece:GetDescendants()) do
			if d:IsA("BasePart") then
				local shown = d:GetAttribute("ShownTransparency")
				local vis = if type(shown) == "number" then shown else 0
				d.Transparency = if on then vis else 1
				d.CanCollide = on and d:GetAttribute("Solid") == true
			elseif d:IsA("TextLabel") then
				d.TextTransparency = if on then 0 else 1
			end
		end
	end
end

local function clearCrew(player: Player)
	local list = crewWalkers[player]
	if list then
		for _, w in ipairs(list) do
			if w.model then
				w.model:Destroy()
			end
		end
	end
	crewWalkers[player] = nil
	crewSig[player] = nil
end

local function refreshCrew(player: Player)
	local data = ctx.Game.dataOf(player)
	local plot = ctx.World.plotModel(player)
	if type(data) ~= "table" or not plot then
		return
	end
	Crew.ensure(data)
	local tier = math.floor(data.ranch.tier or 1)
	if tierSig[player] ~= tier then
		showTiers(plot, tier)
		tierSig[player] = tier
	end
	local mults = ctx.Game.crewMults(player, data)
	local view = Crew.view(data, mults)
	local parts = {}
	for i, member in ipairs(view.owned) do
		if i > view.slots then
			break
		end
		table.insert(parts, string.format("%d:%d:%s:%.2f", member.uid, member.level, member.trait, member.earn))
	end
	local sig = table.concat(parts, "|")
	if crewSig[player] == sig and crewWalkers[player] then
		return
	end
	clearCrew(player)
	crewSig[player] = sig
	local folder = plot:FindFirstChild("RanchCrew")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RanchCrew"
		folder.Parent = plot
	else
		folder:ClearAllChildren()
	end
	local list: { Walker } = {}
	local n = 0
	for i, member in ipairs(view.owned) do
		if i > view.slots then
			break
		end
		local species = Crew.byId(member.species)
		if species then
			n += 1
			local model = WorldBuilder.critter(ENV, folder, appearance(species, true), CFrame.new())
			model.Name = "Crew" .. member.uid
			model:SetAttribute("CrewUid", member.uid)
			quiet(model)
			addProp(model, member.role)
			addAura(model, member.color)
			if member.badge == "Founder" then
				local root = model.PrimaryPart
				if root then
					local ribbon = Instance.new("Part")
					ribbon.Name = "FounderRibbon"
					ribbon.Anchored = true
					ribbon.CanCollide = false
					ribbon.Size = Vector3.new(0.7, 0.16, 0.08)
					ribbon.Color = Color3.fromHex("#E07A3D")
					ribbon.CFrame = root.CFrame * CFrame.new(0, 0.2, -root.Size.Z * 0.4)
					ribbon.Parent = model
				end
			end
			local head = model:FindFirstChild("Head")
			local adornee = if head and head:IsA("BasePart") then head else model.PrimaryPart
			if adornee then
				local tag = member.name
				if member.badge == "Founder" then
					tag ..= " · Founder"
				end
				WorldBuilder.billboard(adornee, "NameTag", tag, 2.2, 70, "#FFF6E0", 180, 28, { 5, 0.7, 80, 14 })
				WorldBuilder.billboard(adornee, "Rate", Income.format(member.earn), 3.15, 70, "#7DCE6A", 140, 28, { 4.2, 0.7, 70, 16 })
			end
			local points = stationPoints(plot, member.role)
			local side = ((n - 1) % 3 - 1) * 1.5
			local row = math.floor((n - 1) / 3) * 1.2
			for p = 1, #points do
				points[p] = points[p] + Vector3.new(side, 0, row)
			end
			local walker = walkerFrom(model, points, n)
			if walker then
				table.insert(list, walker)
			end
		end
	end
	crewWalkers[player] = list
end

function CrewService.walkHome(player: Player, index: number)
	local walker: Walker? = nil
	for i, w in ipairs(applicantWalkers) do
		local at = w.model:GetAttribute("Applicant")
		if at == index then
			walker = w
			table.remove(applicantWalkers, i)
			break
		end
	end
	if not walker then
		return
	end
	local plot = ctx.World.plotModel(player)
	local greet = plot and plot:FindFirstChild("CrewStations")
	local pad = greet and greet:FindFirstChild("Greet")
	if not pad or not pad:IsA("BasePart") then
		walker.model:Destroy()
		return
	end
	local home = Instance.new("Folder")
	home.Name = "WalkingHome"
	home.Parent = mapModel() or workspace
	walker.model.Parent = home
	local from = walker.model:GetPivot().Position
	local goal = Vector3.new(pad.Position.X, from.Y, pad.Position.Z)
	walker.from = from
	walker.to = goal
	walker.points = { from, goal }
	walker.index = 2
	walker.dist = (goal - from).Magnitude
	walker.walked = 0
	table.insert(homeWalkers, walker)
	task.delay(7, function()
		if walker.model then
			walker.model:Destroy()
		end
	end)
end

function CrewService.onPlayerGone(player: Player)
	clearCrew(player)
	tierSig[player] = nil
end

function CrewService.start()
	lineState.seed = Random.new():NextInteger(1, 2000000000)
	local map = mapModel()
	local hub = map and map:FindFirstChild("Hub")
	if hub and not hub:FindFirstChild("HiringLine") then
		WorldBuilder.hiringLine(hub)
	end
	if map then
		local plots = map:FindFirstChild("Plots")
		if plots then
			for _, plot in ipairs(plots:GetChildren()) do
				if not plot:FindFirstChild("RanchTiers") then
					local pad = plot:FindFirstChild("Pad")
					if pad and pad:IsA("BasePart") then
						WorldBuilder.ranchBuild(plot, pad.CFrame)
					end
				end
				showTiers(plot, 1)
			end
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt:GetAttribute("Kind") ~= "hire" then
			return
		end
		local index = prompt:GetAttribute("Applicant")
		if type(index) ~= "number" then
			return
		end
		ctx.Game.hireApplicant(player, index)
	end)
	RunService.Heartbeat:Connect(function(dt)
		for _, w in ipairs(applicantWalkers) do
			stepWalker(w, dt, 5.5)
		end
		local stillHome = {}
		for _, w in ipairs(homeWalkers) do
			if w.model.Parent then
				stepWalker(w, dt, 14)
				table.insert(stillHome, w)
			end
		end
		homeWalkers = stillHome
		-- Ranch crew can reach 10 players x 19 critters (about 5,000 parts). Moving them every
		-- frame on the server costs ~9 ms of CPU and replicates every part each frame, so they
		-- step at 15 Hz. They stroll slowly, so the steps stay small.
		crewAcc += dt
		if crewAcc >= CREW_STEP then
			local step = math.min(crewAcc, 0.5)
			crewAcc = 0
			for _, list in pairs(crewWalkers) do
				for _, w in ipairs(list) do
					stepWalker(w, step, 3.2)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				restock()
				for _, player in ipairs(Players:GetPlayers()) do
					if ctx.Game.runtime[player] then
						refreshCrew(player)
					end
				end
			end)
			if not ok then
				warn("[CrewService] " .. tostring(err))
			end
			task.wait(1)
		end
	end)
end

return CrewService
