--!strict
-- The Hiring Line and the ranch crew, in the world.
-- Applicants walk the boardwalk with their price showing. A hire walks home and works a station.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldBuilder = require(Shared.WorldBuilder)
local HiringLine = require(Shared.Logic.HiringLine)
local Crew = require(Shared.Logic.Crew)
local CrewMotion = require(Shared.Logic.CrewMotion)
local Weather = require(Shared.Logic.Weather)
local Income = require(Shared.Logic.Income)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Onboard = require(Shared.Logic.Onboard)

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

local lineState = {
	seed = 1,
	window = -1,
	tier = 1,
	applicants = {} :: { any },
	taken = {} :: { [number]: number },
}
local lineSig = ""
local crewSig: { [Player]: string } = {}
local tierSig: { [Player]: number } = {}
local starters: { [Player]: Model } = {}

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

-- Clients read these attributes and move the model themselves. The server leaves it put,
-- so a full ranch of critters does not replicate a new pose every frame.
local function tagAnim(model: Model, ground: { Vector3 }, kind: string, speed: number, phase: number)
	if #ground < 2 then
		return
	end
	local lift = model:GetPivot().Position.Y
	local bits = {}
	for _, p in ipairs(ground) do
		local at = p + Vector3.new(0, lift, 0)
		table.insert(bits, string.format("%.2f,%.2f,%.2f", at.X, at.Y, at.Z))
	end
	model:SetAttribute("CrewAnim", kind)
	model:SetAttribute("AnimSpeed", speed)
	model:SetAttribute("AnimPhase", phase)
	model:SetAttribute("AnimPoints", table.concat(bits, "|"))
	if kind == "once" then
		model:SetAttribute("AnimStart", workspace:GetServerTimeNow())
	end
	local first = ground[1] + Vector3.new(0, lift, 0)
	local nextPoint = ground[math.min(2, #ground)] + Vector3.new(0, lift, 0)
	if (nextPoint - first).Magnitude < 0.05 then
		nextPoint = first + Vector3.new(0, 0, -1)
	end
	model:PivotTo(CFrame.lookAt(first, nextPoint))
end

-- `points` are already where the client should draw the pivot, bob not included.
local function tagPath(model: Model, points: { Vector3 }, speed: number)
	if #points < 2 then
		return
	end
	local vecs = {}
	for _, p in ipairs(points) do
		table.insert(vecs, { p.X, p.Y, p.Z })
	end
	model:SetAttribute("CrewAnim", "once")
	model:SetAttribute("AnimSpeed", speed)
	model:SetAttribute("AnimPhase", 0)
	model:SetAttribute("AnimPoints", CrewMotion.encode(vecs))
	model:SetAttribute("AnimStart", workspace:GetServerTimeNow())
	local nextPoint = points[2]
	if (nextPoint - points[1]).Magnitude < 0.05 then
		nextPoint = points[1] + Vector3.new(0, 0, -1)
	end
	model:PivotTo(CFrame.lookAt(points[1], nextPoint))
end

local function toWorld(path: { { number } }): { Vector3 }
	local out = {}
	for _, p in ipairs(path) do
		table.insert(out, Vector3.new(p[1], p[2], p[3]))
	end
	return out
end

local function plotCenter(plot: any): Vector3
	local pad = plot and plot:FindFirstChild("Pad")
	if pad and pad:IsA("BasePart") then
		return pad.Position
	end
	return Vector3.zero
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
			tagAnim(model, points, "loop", 5.5, applicant.index)
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
		local show = Weather.smokeShow(os.time(), TimeUtil.centralOffset(os.time()))
		lineState.applicants = HiringLine.stock(lineState.seed, window, tier)
		if show then
			HiringLine.raiseFloor(lineState.applicants)
		end
		lineState.taken = {}
		if ctx.Game and ctx.Game.autoHire then
			for _, player in ipairs(Players:GetPlayers()) do
				ctx.Game.autoHire(player)
			end
		end
		for _, applicant in ipairs(lineState.applicants) do
			if applicant.rarity == "legendary" or applicant.rarity == "mythic" or applicant.rarity == "secret" then
				if ctx.Game and ctx.Game.announce then
					ctx.Game.announce(string.format("%s the %s is on the Hiring Line.", applicant.name, applicant.rarityName), applicant.color)
				end
				break
			end
		end
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

local function traitFx(model: Model, traitId: string?)
	if traitId == nil or traitId == "" or traitId == "none" then
		return
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local p = Instance.new("ParticleEmitter")
	p.Name = "Trait"
	p.Rate = 4
	p.Lifetime = NumberRange.new(0.6, 1.1)
	p.Speed = NumberRange.new(0.3, 1)
	p.LightEmission = if traitId == "golden" or traitId == "glazed" then 0.7 else 0.25
	local color = if traitId == "smoky"
		then Color3.fromRGB(170, 170, 170)
		elseif traitId == "glazed" then Color3.fromRGB(255, 220, 150)
		elseif traitId == "golden" then Color3.fromRGB(255, 196, 60)
		else Color3.fromRGB(255, 96, 48)
	p.Color = ColorSequence.new(color)
	p.Parent = body
end

local function crewOutfit(model: Model, outfitId: string?)
	if type(outfitId) ~= "string" or outfitId == "" then
		return
	end
	local look = Config.Cosmetics[outfitId]
	if type(look) ~= "table" or type(look.color) ~= "string" then
		return
	end
	local body = model:FindFirstChild("Body")
	if not body or not body:IsA("BasePart") then
		return
	end
	local mark = Instance.new("Highlight")
	mark.Name = "Outfit"
	mark.FillColor = Color3.fromHex(look.color)
	mark.FillTransparency = 0.55
	mark.OutlineTransparency = 0.4
	mark.Parent = model
	mark.Adornee = body
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

-- Unclaimed yards show the finished ranch, faded, so the build-out is visible before anyone claims it.
local function showGhost(plot: any)
	showTiers(plot, #Config.RanchTiers)
	local root = plot:FindFirstChild("RanchTiers")
	if not root then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			d.Transparency = 0.72
			d.CanCollide = false
		end
	end
end

local function clearCrew(player: Player)
	local plot = ctx.World.plotModel(player)
	local folder = plot and plot:FindFirstChild("RanchCrew")
	if folder then
		folder:ClearAllChildren()
	end
	crewSig[player] = nil
end

local function refreshCrew(player: Player)
	local data = ctx.Game.dataOf(player)
	local plot = ctx.World.plotModel(player)
	if type(data) ~= "table" or not plot then
		return
	end
	Crew.ensure(data)
	local hostData = nil
	if ctx.Game.familyHost then
		local _, saved = ctx.Game.familyHost()
		hostData = saved
	end
	local tier = math.floor(if hostData then hostData.ranch.tier or 1 else data.ranch.tier or 1)
	if tierSig[player] ~= tier then
		showTiers(plot, tier)
		tierSig[player] = tier
	end
	local mults = ctx.Game.crewMults(player, data)
	local view = Crew.view(data, mults)
	if ctx.Game.crewSlots then
		view.slots = ctx.Game.crewSlots(data)
	end
	local parts = {}
	for i, member in ipairs(view.owned) do
		if i > view.slots then
			break
		end
		table.insert(parts, string.format("%d:%d:%s:%.2f", member.uid, member.level, member.trait, member.earn))
	end
	local sig = table.concat(parts, "|")
	local existing = plot:FindFirstChild("RanchCrew")
	if crewSig[player] == sig and existing and #existing:GetChildren() > 0 then
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
			local body = model:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				local cheer = WorldBuilder.prompt(body, "cheer", "Cheer", member.name, 0, 10)
				cheer:SetAttribute("OwnerUserId", player.UserId)
				cheer:SetAttribute("CrewUid", member.uid)
			end
			local points = stationPoints(plot, member.role)
			local side = ((n - 1) % 3 - 1) * 1.5
			local row = math.floor((n - 1) / 3) * 1.2
			for p = 1, #points do
				points[p] = points[p] + Vector3.new(side, 0, row)
			end
			tagAnim(model, points, "loop", 3.2, n)
			traitFx(model, member.trait)
			crewOutfit(model, if type(data.crew) == "table" then data.crew.outfit else nil)
		end
	end
	local oldBeam = plot:FindFirstChild("WelcomeBeam")
	if oldBeam and ((data.playSeconds or 0) >= 20 or Onboard.skip(data)) then
		oldBeam:Destroy()
	end
	if (data.playSeconds or 0) < 20 and not Onboard.skip(data) and not plot:FindFirstChild("WelcomeBeam") then
		local pad = plot:FindFirstChild("Pad")
		if pad and pad:IsA("BasePart") then
			local beam = Instance.new("Part")
			beam.Name = "WelcomeBeam"
			beam.Anchored = true
			beam.CanCollide = false
			beam.Material = Enum.Material.Neon
			beam.Color = Color3.fromRGB(255, 200, 80)
			beam.Size = Vector3.new(1.2, 18, 1.2)
			beam.CFrame = pad.CFrame * CFrame.new(0, 10, 0)
			beam.Parent = plot
		end
	end
end

function CrewService.walkHome(player: Player, index: number)
	local folder = hiringFolder()
	local model: Model? = nil
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("Applicant") == index then
				model = child
				break
			end
		end
	end
	if not model then
		return
	end
	local plot = ctx.World.plotModel(player)
	local greet = plot and plot:FindFirstChild("CrewStations")
	local pad = greet and greet:FindFirstChild("Greet")
	if not pad or not pad:IsA("BasePart") then
		model:Destroy()
		return
	end
	local home = Instance.new("Folder")
	home.Name = "WalkingHome"
	home.Parent = mapModel() or workspace
	model.Parent = home
	local now = workspace:GetServerTimeNow()
	local saved = CrewMotion.decode(model:GetAttribute("AnimPoints"))
	local speedAttr = model:GetAttribute("AnimSpeed")
	local phaseAttr = model:GetAttribute("AnimPhase")
	local kindAttr = model:GetAttribute("CrewAnim")
	local startAttr = model:GetAttribute("AnimStart")
	local x, y, z = CrewMotion.pose(
		saved,
		now,
		if type(speedAttr) == "number" then speedAttr else 5.5,
		if type(phaseAttr) == "number" then phaseAttr else 0,
		if kindAttr == "once" then "once" else "loop",
		if type(startAttr) == "number" then startAttr else nil
	)
	local center = plotCenter(plot)
	local path = CrewMotion.homePath(x, y, z, center.X, center.Z, pad.Position.X, pad.Position.Z)
	local world = toWorld(path)
	tagPath(model, world, Config.Hiring.walkSpeed)
	local seconds = CrewMotion.walkSeconds(path, Config.Hiring.walkSpeed)
	task.delay(seconds + 1.5, function()
		if model then
			model:Destroy()
		end
	end)
end

function CrewService.cancelStarter(player: Player)
	local model = starters[player]
	if model then
		model:Destroy()
		starters[player] = nil
	end
end

function CrewService.walkStarter(player: Player): number?
	CrewService.cancelStarter(player)
	local folder = hiringFolder()
	local points = padPoints()
	if not folder or #points < 1 then
		return nil
	end
	local species = Crew.byId("armadillo")
	if not species then
		return nil
	end
	local model = WorldBuilder.critter(ENV, folder, appearance(species, true), CFrame.new())
	model.Name = "StarterPip"
	quiet(model)
	addProp(model, species.role)
	local head = model:FindFirstChild("Head")
	local adornee = if head and head:IsA("BasePart") then head else model.PrimaryPart
	if adornee then
		WorldBuilder.billboard(adornee, "NameTag", "Pip", 2.2, 90, "#FFF6E0", 160, 28, { 4.5, 0.7, 80, 16 })
		WorldBuilder.billboard(adornee, "Offer", "First hire's on the house!", 3.2, 90, "#7DCE6A", 260, 32, { 7, 0.8, 110, 16 })
	end
	local start = points[1]
	local plot = ctx.World.plotModel(player)
	local greet = plot and plot:FindFirstChild("CrewStations")
	local pad = greet and greet:FindFirstChild("Greet")
	local lift = model:GetPivot().Position.Y
	local center = plotCenter(plot)
	local greetPos = if pad and pad:IsA("BasePart") then pad.Position else center
	local path = CrewMotion.homePath(start.X, start.Y + lift, start.Z, center.X, center.Z, greetPos.X, greetPos.Z)
	local speed = Config.Hiring.walkSpeed
	local seconds = CrewMotion.walkSeconds(path, speed)
	-- The opening walk stays on the path, and Pip is on the pit by the time the tracker asks for a second hire.
	if seconds > Config.Onboarding.pipAt then
		speed = CrewMotion.length(path) / Config.Onboarding.pipAt
		seconds = Config.Onboarding.pipAt
	end
	tagPath(model, toWorld(path), speed)
	starters[player] = model
	task.delay(seconds + 1.5, function()
		if starters[player] == model then
			model:Destroy()
			starters[player] = nil
		end
	end)
	return seconds
end

function CrewService.onPlayerGone(player: Player)
	local plot = ctx.World and ctx.World.plotModel and ctx.World.plotModel(player)
	clearCrew(player)
	CrewService.cancelStarter(player)
	tierSig[player] = nil
	if plot then
		local beam = plot:FindFirstChild("WelcomeBeam")
		if beam then
			beam:Destroy()
		end
		showGhost(plot)
	end
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
				showGhost(plot)
			end
		end
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt:GetAttribute("Kind") ~= "hire" and prompt:GetAttribute("Kind") ~= "cheer" then
			return
		end
		if prompt:GetAttribute("Kind") == "cheer" then
			local ok, msg = ctx.Game.act(player, "Cheer", prompt:GetAttribute("OwnerUserId"), prompt:GetAttribute("CrewUid"))
			if not ok and type(msg) == "string" and msg ~= "" then
				ctx.Game.toast(player, msg, "warn")
			end
			return
		end
		local index = prompt:GetAttribute("Applicant")
		if type(index) ~= "number" then
			return
		end
		-- Same pipeline as the Hire panel: rate limit, guide update, and a save.
		local ok, msg = ctx.Game.act(player, "HireApplicant", index)
		if not ok and type(msg) == "string" and msg ~= "" then
			ctx.Game.toast(player, msg, "warn")
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
