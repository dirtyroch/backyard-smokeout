--!strict
-- CosmeticService — puts hats, aprons, tools, bandanas, socks & sandals, trails and title tags on
-- characters. Everything is built from Parts (no uploaded meshes) and welded to the character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)

local CosmeticService = {}
local ctx: any = nil

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function weldPart(parent: Instance, attachTo: BasePart, name: string, size: Vector3, offset: CFrame, color: string, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = hex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = attachTo.CFrame * offset
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0 = attachTo
	w.Part1 = p
	w.Parent = p
	return p
end

local function find(char: Model, ...: string): BasePart?
	for _, n in ipairs({ ... }) do
		local p = char:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function buildHat(folder: Folder, head: BasePart, id: string)
	local def = Config.Cosmetics[id]
	local top = head.Size.Y / 2
	if id == "hat_turkey" then
		weldPart(folder, head, "HatBody", Vector3.new(1.4, 0.9, 1.6), CFrame.new(0, top + 0.4, 0), def.color)
		weldPart(folder, head, "HatHead", Vector3.new(0.5, 0.6, 0.5), CFrame.new(0, top + 0.9, -0.7), "#C0392B")
		for k = -2, 2 do
			weldPart(folder, head, "Feather", Vector3.new(0.35, 1.2, 0.15), CFrame.new(k * 0.3, top + 1, 0.7) * CFrame.Angles(0, 0, math.rad(k * 14)), k % 2 == 0 and "#E67E22" or "#8B4513")
		end
		return
	end
	local brim = weldPart(folder, head, "HatBrim", Vector3.new(0.15, 2.6, 2.6), CFrame.new(0, top + 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), def.color)
	brim.Shape = Enum.PartType.Cylinder
	weldPart(folder, head, "HatCrown", Vector3.new(1.3, 0.8, 1.4), CFrame.new(0, top + 0.55, 0), def.color)
	weldPart(folder, head, "HatBand", Vector3.new(1.32, 0.18, 1.42), CFrame.new(0, top + 0.25, 0), id == "hat_pitmaster" and "#C9A227" or "#7B3F00")
	if def.twinkle then
		-- a ring of little glowing bulbs around the band (Twinkle Lights Cowboy Hat)
		local BULBS = { "#FF3B3B", "#FFD54A", "#3BD16F", "#4FA3FF" }
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local bulb = weldPart(folder, head, "Bulb", Vector3.new(0.2, 0.2, 0.2), CFrame.new(math.cos(a) * 0.72, top + 0.27, math.sin(a) * 0.76), BULBS[k % #BULBS + 1], Enum.Material.Neon)
			bulb.Shape = Enum.PartType.Ball
		end
	end
end

local function buildApron(folder: Folder, torso: BasePart, id: string)
	local def = Config.Cosmetics[id]
	local front = -torso.Size.Z / 2 - 0.06
	local apron = weldPart(folder, torso, "Apron", Vector3.new(torso.Size.X * 0.8, torso.Size.Y * 1.05, 0.1), CFrame.new(0, -0.15, front), def.color, Enum.Material.Fabric)
	if def.text then
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.PixelsPerStud = 60
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.LightInfluence = 0.6
		sg.Parent = apron
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(0.9, 0.5)
		tl.Position = UDim2.fromScale(0.05, 0.15)
		tl.BackgroundTransparency = 1
		tl.TextScaled = true
		tl.Font = Enum.Font.FredokaOne
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.Text = def.text
		tl.Parent = sg
	end
	weldPart(folder, torso, "ApronPocket", Vector3.new(0.8, 0.4, 0.05), CFrame.new(0, -0.6, front - 0.06), "#FFFFFF", Enum.Material.Fabric).Transparency = 0.6
end

local function buildTool(folder: Folder, hand: BasePart, id: string)
	local def = Config.Cosmetics[id]
	local mat = def.neon and Enum.Material.Neon or Enum.Material.Foil
	local handle = weldPart(folder, hand, "ToolHandle", Vector3.new(0.2, 0.2, 1.4), CFrame.new(0, -hand.Size.Y / 2 - 0.1, -0.6), def.color, mat)
	if id == "tool_goldtongs" then
		weldPart(folder, hand, "TongA", Vector3.new(0.12, 0.12, 1.2), CFrame.new(-0.12, -hand.Size.Y / 2 - 0.1, -1.6) * CFrame.Angles(0, math.rad(6), 0), def.color, mat)
		weldPart(folder, hand, "TongB", Vector3.new(0.12, 0.12, 1.2), CFrame.new(0.12, -hand.Size.Y / 2 - 0.1, -1.6) * CFrame.Angles(0, math.rad(-6), 0), def.color, mat)
	else
		weldPart(folder, hand, "SpatulaHead", Vector3.new(0.8, 0.06, 0.9), CFrame.new(0, -hand.Size.Y / 2 - 0.1, -1.7), def.color, mat)
	end
	local sp = Instance.new("Sparkles")
	sp.SparkleColor = hex(def.color)
	sp.Parent = handle
end

local function buildNeck(folder: Folder, torso: BasePart, id: string)
	local def = Config.Cosmetics[id]
	weldPart(folder, torso, "Bandana", Vector3.new(torso.Size.X * 0.7, 0.35, torso.Size.Z + 0.2), CFrame.new(0, torso.Size.Y / 2 - 0.1, 0), def.color, Enum.Material.Fabric)
	local tri = Instance.new("WedgePart")
	tri.Name = "BandanaTip"
	tri.Size = Vector3.new(0.1, 0.6, 0.6)
	tri.Color = hex(def.color)
	tri.Material = Enum.Material.Fabric
	tri.CanCollide = false
	tri.Massless = true
	tri.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y / 2 - 0.5, -torso.Size.Z / 2 - 0.1) * CFrame.Angles(0, math.pi / 2, math.pi)
	tri.Parent = folder
	local w = Instance.new("WeldConstraint")
	w.Part0 = torso
	w.Part1 = tri
	w.Parent = tri
end

local function buildFeet(folder: Folder, char: Model)
	for _, side in ipairs({ "Left", "Right" }) do
		local foot = find(char, side .. "Foot", side .. " Leg")
		if foot then
			local bottom = -foot.Size.Y / 2
			weldPart(folder, foot, side .. "Sock", Vector3.new(foot.Size.X + 0.06, 0.5, foot.Size.Z + 0.06), CFrame.new(0, bottom + 0.4, 0), "#FFFFFF", Enum.Material.Fabric)
			weldPart(folder, foot, side .. "Sandal", Vector3.new(foot.Size.X + 0.15, 0.12, foot.Size.Z + 0.3), CFrame.new(0, bottom + 0.02, -0.05), "#6B4226", Enum.Material.Leather)
			weldPart(folder, foot, side .. "Strap", Vector3.new(foot.Size.X + 0.12, 0.1, 0.2), CFrame.new(0, bottom + 0.25, -0.2), "#3B2A1A", Enum.Material.Leather)
		end
	end
end

local function buildTrail(folder: Folder, hrp: BasePart, id: string)
	local def = Config.Cosmetics[id]
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA"
	a0.Position = Vector3.new(0, 0.8, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailB"
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = hrp
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.7
	tr.LightEmission = id == "trail_sauce" and 0 or 0.6
	tr.Color = ColorSequence.new(hex(def.color), def.color2 and hex(def.color2) or (id == "trail_firework" and hex("#FFD700") or hex(def.color)))
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.WidthScale = NumberSequence.new(1, 0.2)
	tr.Parent = folder
	-- attachments live on the HRP, tag them so we can clean up
	a0:SetAttribute("BSCosmetic", true)
	a1:SetAttribute("BSCosmetic", true)
end

local function buildTag(folder: Folder, head: BasePart, player: Player, data: any, resting: boolean, vip: boolean)
	local bb = Instance.new("BillboardGui")
	bb.Name = "TitleTag"
	bb.Size = UDim2.new(0, 220, 0, 56)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 90
	bb.Adornee = head
	bb.LightInfluence = 0
	bb.Parent = folder
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextStrokeTransparency = 0.4
	title.TextColor3 = vip and hex("#FFD700") or hex("#FFE9A8")
	local rankName = Config.Ranks[data.rank] and Config.Ranks[data.rank].name or ""
	local t = data.title ~= "" and data.title or rankName
	local prefix = vip and "✨ " or ""
	if ctx.Membership and ctx.Membership.isMember(player) then
		prefix = "🔧 " .. Config.Club.title .. " · "
		title.TextColor3 = hex("#7CD1C1")
	elseif ctx.Membership and ctx.Membership.isHost(player) then
		prefix = "🏠 "
	end
	title.Text = prefix .. t
	title.Parent = bb
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.Size = UDim2.fromScale(1, 0.45)
	sub.Position = UDim2.fromScale(0, 0.52)
	sub.BackgroundTransparency = 1
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamMedium
	sub.TextStrokeTransparency = 0.5
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Text = resting and Content.Slang.resting or ""
	sub.Parent = bb
end

function CosmeticService.apply(player: Player)
	local char = player.Character
	local data = ctx.Game.dataOf(player)
	if not char or not data then
		return
	end
	local old = char:FindFirstChild("BSCosmetics")
	if old then
		old:Destroy()
	end
	local hrp = find(char, "HumanoidRootPart")
	if hrp then
		for _, a in ipairs(hrp:GetChildren()) do
			if a:GetAttribute("BSCosmetic") then
				a:Destroy()
			end
		end
	end
	local head = find(char, "Head")
	local torso = find(char, "UpperTorso", "Torso")
	local hand = find(char, "RightHand", "Right Arm")
	if not head or not torso then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BSCosmetics"
	local eq = data.equipped
	local r = ctx.Game.runtime[player]
	local ok, err = pcall(function()
		if eq.hat and data.owned[eq.hat] then
			buildHat(folder, head, eq.hat)
		end
		if eq.apron and data.owned[eq.apron] then
			buildApron(folder, torso, eq.apron)
		end
		if eq.tool and data.owned[eq.tool] and hand then
			buildTool(folder, hand, eq.tool)
		end
		if eq.neck and data.owned[eq.neck] then
			buildNeck(folder, torso, eq.neck)
		end
		if eq.feet and data.owned[eq.feet] then
			buildFeet(folder, char)
		end
		if eq.trail and data.owned[eq.trail] and hrp then
			buildTrail(folder, hrp, eq.trail)
		end
		buildTag(folder, head, player, data, r ~= nil and r.resting, ctx.Game.hasPass(player, "VIPPatio"))
	end)
	if not ok then
		warn("[CosmeticService] " .. tostring(err))
	end
	folder.Parent = char
end

function CosmeticService.init(c: any)
	ctx = c
end

function CosmeticService.start()
	-- Rainbow Sherbet smoke cycles colors on the owner's smokers.
	task.spawn(function()
		local hue = 0
		while true do
			task.wait(0.4)
			hue = (hue + 0.03) % 1
			for _, player in ipairs(Players:GetPlayers()) do
				local data = ctx.Game.dataOf(player)
				if data and data.equipped.smoke == "smoke_sherbet" then
					local plot = ctx.World.plotModel(player)
					if plot then
						for _, s in ipairs(plot.Smokers:GetChildren()) do
							local ch = s:FindFirstChild("Chimney")
							local sm = ch and ch:FindFirstChild("Smoke") :: Smoke?
							if sm then
								sm.Color = Color3.fromHSV(hue, 0.45, 1)
							end
						end
					end
				end
			end
		end
	end)
end

return CosmeticService
