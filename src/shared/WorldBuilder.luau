--!nocheck
--[[
	WorldBuilder — builds the whole map out of plain Parts (no uploaded assets needed).
	It only uses Instance.new + datatypes passed in through `env`, so it runs both:
	  * in Roblox (server builds the map at startup if Workspace.Map is missing), and
	  * in Lune (scripts/bake-map.luau bakes the map into BackyardSmokeout.rbxlx so it
	    shows up in Studio's edit mode and in your thumbnails).
	Every interactive thing is a ProximityPrompt with a "Kind" attribute that the server or
	client dispatches on.
]]
local WorldBuilder = {}

WorldBuilder.PLOT_RADIUS = 150
WorldBuilder.PLOT_SIZE = 64
WorldBuilder.SMOKER_X = { -24, -16, -8, 0, 8, 16, 24 }
WorldBuilder.GRILL_X = { -27, -22, -17, -12 }

local E -- env (Roblox globals: Instance, Vector3, CFrame, Color3, Enum, UDim2)

function WorldBuilder.setEnv(env)
	E = env
end

local function hex(h)
	return E.Color3.fromHex(h)
end

local function part(parent, name, size, cf, color, material, props)
	local p = E.Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = hex(color)
	p.Material = material or E.Enum.Material.SmoothPlastic
	p.TopSurface = E.Enum.SurfaceType.Smooth
	p.BottomSurface = E.Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end
WorldBuilder.part = part

local function model(parent, name)
	local m = E.Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function folder(parent, name)
	local f = E.Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function V(x, y, z)
	return E.Vector3.new(x, y, z)
end

local function lookAt(a, b)
	if E.CFrame.lookAt then
		return E.CFrame.lookAt(a, b)
	end
	return E.CFrame.new(a, b)
end

local function cyl(parent, name, length, diameter, cf, color, material, props)
	-- Roblox cylinders run along X. `cf` is the center.
	local p = part(parent, name, V(length, diameter, diameter), cf, color, material, props)
	p.Shape = E.Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, d, cf, color, material, props)
	local p = part(parent, name, V(d, d, d), cf, color, material, props)
	p.Shape = E.Enum.PartType.Ball
	return p
end

local function prompt(parent, kind, action, object, hold, dist, extra)
	local pp = E.Instance.new("ProximityPrompt")
	pp.Name = "Prompt"
	pp.ActionText = action
	pp.ObjectText = object or ""
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 10
	pp.RequiresLineOfSight = false
	pp:SetAttribute("Kind", kind)
	if extra then
		for k, v in pairs(extra) do
			pp[k] = v
		end
	end
	pp.Parent = parent
	return pp
end
WorldBuilder.prompt = prompt

local function surfaceText(p, face, text, textColor, bg, font)
	local sg = E.Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = face or E.Enum.NormalId.Front
	sg.SizingMode = E.Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = p
	local tl = E.Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = E.UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = bg and 0 or 1
	if bg then
		tl.BackgroundColor3 = hex(bg)
	end
	tl.TextColor3 = hex(textColor or "#FFFFFF")
	tl.Font = font or E.Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.Parent = sg
	return tl
end
WorldBuilder.surfaceText = surfaceText

local function billboard(adornee, name, text, offsetY, maxDist, color, w, h)
	local b = E.Instance.new("BillboardGui")
	b.Name = name
	b.Size = E.UDim2.new(0, w or 160, 0, h or 40)
	b.StudsOffset = V(0, offsetY or 3, 0)
	b.AlwaysOnTop = false
	b.MaxDistance = maxDist or 80
	b.LightInfluence = 0
	b.Parent = adornee
	local tl = E.Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = E.UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = hex(color or "#FFFFFF")
	tl.TextStrokeTransparency = 0.3
	tl.Font = E.Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.Parent = b
	return b
end
WorldBuilder.billboard = billboard

-- A blocky NPC person.
function WorldBuilder.npc(parent, name, cf, o)
	o = o or {}
	local m = model(parent, name)
	local skin = o.skin or "#E0AC69"
	local shirt = o.shirt or "#4A6FA5"
	local pants = o.pants or "#3B3B3B"
	local s = o.scale or 1
	local function at(x, y, z)
		return cf * E.CFrame.new(x * s, y * s, z * s)
	end
	part(m, "LeftLeg", V(1 * s, 2 * s, 1 * s), at(-0.5, 1, 0), pants)
	part(m, "RightLeg", V(1 * s, 2 * s, 1 * s), at(0.5, 1, 0), pants)
	local torso = part(m, "Torso", V(2 * s, 2 * s, 1 * s), at(0, 3, 0), shirt)
	part(m, "LeftArm", V(1 * s, 2 * s, 1 * s), at(-1.5, 3, 0), skin)
	part(m, "RightArm", V(1 * s, 2 * s, 1 * s), at(1.5, 3, 0), skin)
	local head = part(m, "Head", V(1.6 * s, 1.6 * s, 1.6 * s), at(0, 4.8, 0), skin)
	part(m, "EyeL", V(0.25 * s, 0.25 * s, 0.1 * s), at(-0.35, 5, -0.81), "#111111")
	part(m, "EyeR", V(0.25 * s, 0.25 * s, 0.1 * s), at(0.35, 5, -0.81), "#111111")
	part(m, "Smile", V(0.7 * s, 0.12 * s, 0.1 * s), at(0, 4.5, -0.81), "#5A2E1E")
	if o.hat == "cowboy" then
		cyl(m, "HatBrim", 0.2 * s, 3 * s, at(0, 5.7, 0) * E.CFrame.Angles(0, 0, math.pi / 2), o.hatColor or "#3B2A1A")
		part(m, "HatCrown", V(1.6 * s, 0.9 * s, 1.6 * s), at(0, 6.2, 0), o.hatColor or "#3B2A1A")
	elseif o.hat == "cap" then
		part(m, "Cap", V(1.7 * s, 0.5 * s, 1.7 * s), at(0, 5.75, 0), o.hatColor or "#B22222")
		part(m, "Bill", V(1.6 * s, 0.15 * s, 0.9 * s), at(0, 5.55, -1.1), o.hatColor or "#B22222")
	elseif o.hat == "bun" then
		ball(m, "Bun", 0.9 * s, at(0, 5.9, 0.3), o.hatColor or "#DDDDDD")
	end
	if o.apron then
		part(m, "Apron", V(1.8 * s, 2.2 * s, 0.1 * s), at(0, 2.9, -0.55), o.apron)
	end
	if o.glasses then
		part(m, "Glasses", V(1.3 * s, 0.25 * s, 0.1 * s), at(0, 5, -0.85), "#222222")
	end
	for _, c in ipairs(m:GetChildren()) do
		c.CanCollide = c.Name == "Torso" or c.Name == "LeftLeg" or c.Name == "RightLeg"
	end
	m.PrimaryPart = torso
	if o.label then
		billboard(head, "NameTag", o.label, 2.5, 60, o.labelColor or "#FFE9A8", 200, 36)
	end
	return m, head, torso
end

-- A critter customer. Built at `cf` (feet on the ground).
function WorldBuilder.critter(env, parent, def, cf)
	E = env
	local m = model(parent, def.id)
	local s = def.scale or 1
	local function at(x, y, z)
		return cf * E.CFrame.new(x * s, y * s, z * s)
	end
	local body, head
	if def.rex then
		body = part(m, "Body", V(2.2 * s, 2.4 * s, 2.6 * s), at(0, 2.2, 0.3), def.body)
		head = part(m, "Head", V(2 * s, 1.8 * s, 2.2 * s), at(0, 4.2, -0.6), def.head)
		part(m, "Belly", V(1.6 * s, 1.8 * s, 0.2 * s), at(0, 2.1, -1), "#E8F5C8")
		part(m, "ArmL", V(0.4 * s, 0.9 * s, 0.4 * s), at(-0.9, 2.8, -1.1), def.body)
		part(m, "ArmR", V(0.4 * s, 0.9 * s, 0.4 * s), at(0.9, 2.8, -1.1), def.body)
		part(m, "Tail", V(1 * s, 1 * s, 2.4 * s), at(0, 1.6, 2.6), def.body)
		part(m, "LegL", V(0.8 * s, 1 * s, 0.9 * s), at(-0.6, 0.5, 0.3), def.body)
		part(m, "LegR", V(0.8 * s, 1 * s, 0.9 * s), at(0.6, 0.5, 0.3), def.body)
		part(m, "Ribbon", V(2.4 * s, 0.35 * s, 0.4 * s), at(0, 3.45, -0.95), "#FF5C8A")
		billboard(head, "Ribbon", def.ribbon or "RAWR means I love you ♥", 2.6, 70, "#FF8FB1", 260, 34)
	else
		body = part(m, "Body", V(1.8 * s, 1.4 * s, 2.4 * s), at(0, 1.3, 0), def.body)
		head = part(m, "Head", V(1.4 * s, 1.3 * s, 1.3 * s), at(0, 2.3, -1.3), def.head)
		part(m, "LegFL", V(0.4 * s, 0.7 * s, 0.4 * s), at(-0.6, 0.35, -0.8), def.body)
		part(m, "LegFR", V(0.4 * s, 0.7 * s, 0.4 * s), at(0.6, 0.35, -0.8), def.body)
		part(m, "LegBL", V(0.4 * s, 0.7 * s, 0.4 * s), at(-0.6, 0.35, 0.8), def.body)
		part(m, "LegBR", V(0.4 * s, 0.7 * s, 0.4 * s), at(0.6, 0.35, 0.8), def.body)
		part(m, "Tail", V(0.3 * s, 0.3 * s, 1 * s), at(0, 1.6, 1.6), def.body)
		if def.ears then
			part(m, "EarL", V(0.35 * s, 0.6 * s, 0.2 * s), at(-0.45, 3.1, -1.3), def.head)
			part(m, "EarR", V(0.35 * s, 0.6 * s, 0.2 * s), at(0.45, 3.1, -1.3), def.head)
		end
		if def.horns then
			part(m, "Horns", V(3 * s, 0.25 * s, 0.25 * s), at(0, 2.9, -1.3), "#F5F0E1")
		end
		if def.id == "raccoon" then
			part(m, "Mask", V(1.42 * s, 0.35 * s, 0.1 * s), at(0, 2.45, -1.96), "#1A1A1A")
		end
		if def.bellyRub then
			-- pudgy original pup with a little underbite and a pink belly
			part(m, "Belly", V(1.4 * s, 0.2 * s, 1.6 * s), at(0, 0.62, 0), "#F7B7C3")
			part(m, "Snout", V(0.8 * s, 0.5 * s, 0.3 * s), at(0, 2.05, -2.05), "#C9AE8F")
		end
		if def.id == "clapcat" then
			part(m, "PawL", V(0.35 * s, 0.35 * s, 0.35 * s), at(-0.35, 1.9, -2.1), "#151515")
			part(m, "PawR", V(0.35 * s, 0.35 * s, 0.35 * s), at(0.35, 1.9, -2.1), "#151515")
		end
	end
	local eyeY = def.rex and 4.5 or 2.5
	local eyeZ = def.rex and -1.72 or -1.96
	part(m, "EyeL", V(0.25 * s, 0.3 * s, 0.1 * s), at(-0.35, eyeY, eyeZ), "#111111")
	part(m, "EyeR", V(0.25 * s, 0.3 * s, 0.1 * s), at(0.35, eyeY, eyeZ), "#111111")
	part(m, "ShineL", V(0.1 * s, 0.1 * s, 0.05 * s), at(-0.3, eyeY + 0.07, eyeZ - 0.06), "#FFFFFF")
	part(m, "ShineR", V(0.1 * s, 0.1 * s, 0.05 * s), at(0.4, eyeY + 0.07, eyeZ - 0.06), "#FFFFFF")
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") then
			c.CanCollide = false
			c.CanQuery = c.Name == "Body"
		end
	end
	m.PrimaryPart = body
	return m, head, body
end

function WorldBuilder.mosquito(env, parent, cf, queen)
	E = env
	local s = queen and 3 or 1
	local m = model(parent, queen and "QueenSkeeter" or "Mosquito")
	local body = part(m, "Body", V(0.8 * s, 0.8 * s, 2 * s), cf, "#3A3A3A", nil, { CanCollide = false })
	part(m, "Head", V(0.6 * s, 0.6 * s, 0.6 * s), cf * E.CFrame.new(0, 0, -1.2 * s), "#2A2A2A", nil, { CanCollide = false })
	part(m, "Nose", V(0.1 * s, 0.1 * s, 1.2 * s), cf * E.CFrame.new(0, -0.1 * s, -2 * s), "#111111", nil, { CanCollide = false })
	part(m, "WingL", V(1.8 * s, 0.05 * s, 0.8 * s), cf * E.CFrame.new(-1.1 * s, 0.4 * s, 0), "#CDEFFF", E.Enum.Material.Glass, { Transparency = 0.4, CanCollide = false })
	part(m, "WingR", V(1.8 * s, 0.05 * s, 0.8 * s), cf * E.CFrame.new(1.1 * s, 0.4 * s, 0), "#CDEFFF", E.Enum.Material.Glass, { Transparency = 0.4, CanCollide = false })
	ball(m, "EyeL", 0.3 * s, cf * E.CFrame.new(-0.25 * s, 0.15 * s, -1.4 * s), "#FF3B3B", E.Enum.Material.Neon, { CanCollide = false })
	ball(m, "EyeR", 0.3 * s, cf * E.CFrame.new(0.25 * s, 0.15 * s, -1.4 * s), "#FF3B3B", E.Enum.Material.Neon, { CanCollide = false })
	m.PrimaryPart = body
	return m, body
end

-- Visual for meat sitting on a smoker / grill / pass window.
function WorldBuilder.meat(env, parent, meatDef, rarityDef, cf, doneness)
	E = env
	local sz = meatDef.size or { 2, 0.6, 1.2 }
	local scale = 1
	if rarityDef and rarityDef.id == "texas" then
		scale = 1.9
	end
	local color = hex(meatDef.color)
	local raw = hex("#E8857A")
	local t = math.clamp(doneness or 1, 0, 1)
	local c = raw:Lerp(color, t)
	local p = E.Instance.new("Part")
	p.Name = "Meat"
	p.Anchored = true
	p.CanCollide = false
	p.Size = V(sz[1] * scale, sz[2] * scale, sz[3] * scale)
	p.CFrame = cf * E.CFrame.new(0, p.Size.Y / 2, 0)
	p.Color = c
	p.Material = E.Enum.Material.SmoothPlastic
	if rarityDef then
		if rarityDef.id == "meteorite" then
			p.Color = hex("#141414")
			p.Material = E.Enum.Material.Basalt
			local glow = E.Instance.new("PointLight")
			glow.Color = hex("#8A6CFF")
			glow.Range = 10
			glow.Brightness = 2
			glow.Parent = p
			local sp = E.Instance.new("Sparkles")
			sp.SparkleColor = hex("#8A6CFF")
			sp.Parent = p
		elseif rarityDef.id == "smokering" then
			local ring = E.Instance.new("SelectionBox")
			ring.Adornee = p
			ring.Color3 = hex("#FFC83C")
			ring.LineThickness = 0.06
			ring.Parent = p
			local sp = E.Instance.new("Sparkles")
			sp.SparkleColor = hex("#FFC83C")
			sp.Parent = p
		elseif rarityDef.id == "juicy" then
			p.Material = E.Enum.Material.Glass
			p.Transparency = 0.05
		end
	end
	p.Parent = parent
	return p
end

local function tree(parent, pos, s)
	s = s or 1
	part(parent, "Trunk", V(2 * s, 10 * s, 2 * s), E.CFrame.new(pos + V(0, 5 * s, 0)), "#6B4226", E.Enum.Material.Wood)
	ball(parent, "Leaves", 11 * s, E.CFrame.new(pos + V(0, 12 * s, 0)), "#3E8E41", E.Enum.Material.Grass)
	ball(parent, "Leaves2", 8 * s, E.CFrame.new(pos + V(3 * s, 10 * s, 2 * s)), "#4CA64C", E.Enum.Material.Grass)
end

local function fence(parent, cf, length)
	local m = model(parent, "Fence")
	local posts = math.floor(length / 8)
	for i = 0, posts do
		local x = -length / 2 + i * (length / posts)
		part(m, "Post", V(0.6, 4, 0.6), cf * E.CFrame.new(x, 2, 0), "#8B5A2B", E.Enum.Material.Wood)
	end
	part(m, "RailTop", V(length, 0.4, 0.3), cf * E.CFrame.new(0, 3.3, 0), "#A0522D", E.Enum.Material.Wood)
	part(m, "RailLow", V(length, 0.4, 0.3), cf * E.CFrame.new(0, 1.6, 0), "#A0522D", E.Enum.Material.Wood)
	return m
end

local function picnicTable(parent, name, cf)
	local m = model(parent, name)
	part(m, "Top", V(6, 0.4, 3), cf * E.CFrame.new(0, 2.6, 0), "#B5651D", E.Enum.Material.Wood)
	part(m, "LegA", V(0.4, 2.4, 2.6), cf * E.CFrame.new(-2.4, 1.2, 0), "#8B4513", E.Enum.Material.Wood)
	part(m, "LegB", V(0.4, 2.4, 2.6), cf * E.CFrame.new(2.4, 1.2, 0), "#8B4513", E.Enum.Material.Wood)
	part(m, "BenchA", V(6, 0.3, 1), cf * E.CFrame.new(0, 1.5, -2.2), "#B5651D", E.Enum.Material.Wood)
	part(m, "BenchB", V(6, 0.3, 1), cf * E.CFrame.new(0, 1.5, 2.2), "#B5651D", E.Enum.Material.Wood)
	part(m, "Cloth", V(6.05, 0.05, 3.05), cf * E.CFrame.new(0, 2.83, 0), "#D9534F", E.Enum.Material.Fabric)
	local seat = part(m, "Seat", V(1, 0.2, 1), cf * E.CFrame.new(0, 0.1, -3.6), "#000000", nil, { Transparency = 1, CanCollide = false })
	return m, seat
end

local function smoker(parent, name, cf)
	local m = model(parent, name)
	part(m, "LegL", V(0.4, 2.5, 0.4), cf * E.CFrame.new(-2, 1.25, 0), "#222222", E.Enum.Material.Metal)
	part(m, "LegR", V(0.4, 2.5, 0.4), cf * E.CFrame.new(2, 1.25, 0), "#222222", E.Enum.Material.Metal)
	local barrel = cyl(m, "Barrel", 5, 3, cf * E.CFrame.new(0, 3.6, 0), "#6E4B3A", E.Enum.Material.Metal)
	part(m, "Firebox", V(1.8, 1.8, 1.8), cf * E.CFrame.new(-3.3, 3, 0), "#3A3A3A", E.Enum.Material.Metal)
	local chimney = cyl(m, "Chimney", 3, 0.7, cf * E.CFrame.new(2, 6.3, 0) * E.CFrame.Angles(0, 0, math.pi / 2), "#2A2A2A", E.Enum.Material.Metal)
	local smoke = E.Instance.new("Smoke")
	smoke.Name = "Smoke"
	smoke.Enabled = false
	smoke.Size = 2
	smoke.RiseVelocity = 4
	smoke.Opacity = 0.15
	smoke.Color = hex("#DDDDDD")
	smoke.Parent = chimney
	part(m, "Handle", V(2, 0.3, 0.3), cf * E.CFrame.new(0, 4, -1.7), "#C0C0C0", E.Enum.Material.Metal)
	local spot = part(m, "MeatSpot", V(1, 0.2, 1), cf * E.CFrame.new(0, 5.15, 0), "#000000", nil, { Transparency = 1, CanCollide = false })
	local gui = billboard(barrel, "SlotGui", "", 4.2, 70, "#FFFFFF", 180, 44)
	gui.Name = "SlotGui"
	m:SetAttribute("Slot", name)
	return m, barrel, spot
end

local function stall(parent, name, cf, title, awningA, awningB, promptKind, promptText)
	local m = model(parent, name)
	part(m, "Counter", V(14, 3.5, 3), cf * E.CFrame.new(0, 1.75, 0), "#8B5A2B", E.Enum.Material.WoodPlanks)
	part(m, "Back", V(14, 9, 0.6), cf * E.CFrame.new(0, 4.5, 4), "#A0522D", E.Enum.Material.WoodPlanks)
	part(m, "PostL", V(0.6, 9, 0.6), cf * E.CFrame.new(-6.7, 4.5, -1.3), "#6B4226", E.Enum.Material.Wood)
	part(m, "PostR", V(0.6, 9, 0.6), cf * E.CFrame.new(6.7, 4.5, -1.3), "#6B4226", E.Enum.Material.Wood)
	for i = 0, 6 do
		part(m, "Awning" .. i, V(2, 0.4, 7), cf * E.CFrame.new(-6 + i * 2, 9.2, 1) * E.CFrame.Angles(math.rad(-12), 0, 0), i % 2 == 0 and awningA or awningB, E.Enum.Material.Fabric)
	end
	local roof = part(m, "Roof", V(14.5, 0.6, 8), cf * E.CFrame.new(0, 10.2, 1.5), "#5A3A1E", E.Enum.Material.WoodPlanks)
	local sign = part(m, "Sign", V(12, 2.2, 0.3), cf * E.CFrame.new(0, 7.6, -1.5), "#F4E1C1", E.Enum.Material.Wood)
	surfaceText(sign, E.Enum.NormalId.Front, title, "#5A2E1E", nil)
	-- bottles on the counter
	local colors = { "#D2462E", "#FF5A00", "#E8B923", "#FFA07A", "#5B3A1E" }
	for i, c in ipairs(colors) do
		cyl(m, "Bottle" .. i, 1.2, 0.6, cf * E.CFrame.new(-4 + i * 1.4, 4.1, 0) * E.CFrame.Angles(0, 0, math.pi / 2), c, E.Enum.Material.Glass)
	end
	prompt(m.Counter, promptKind, promptText, title, 0, 12)
	return m, roof
end

local function buildPlot(root, i, cfg)
	local n = cfg.MAX_PLOTS
	local angle = (i - 1) / n * math.pi * 2
	local center = V(math.cos(angle) * WorldBuilder.PLOT_RADIUS, 0, math.sin(angle) * WorldBuilder.PLOT_RADIUS)
	local cf = lookAt(center, V(0, 0, 0))
	local S = WorldBuilder.PLOT_SIZE
	local m = model(root, "Plot" .. i)
	m:SetAttribute("PlotIndex", i)
	part(m, "Pad", V(S, 1, S), cf * E.CFrame.new(0, 0.1, 0), "#6FBF4B", E.Enum.Material.Grass)
	part(m, "Patio", V(30, 0.3, 16), cf * E.CFrame.new(-10, 0.7, 18), "#C9B79C", E.Enum.Material.Slate)
	part(m, "Path", V(8, 0.25, 26), cf * E.CFrame.new(0, 0.68, -19), "#C2A878", E.Enum.Material.Sand)
	-- fences (front has a gap for the path)
	fence(m, cf * E.CFrame.new(0, 0.6, S / 2), S)
	fence(m, cf * E.CFrame.new(-S / 2, 0.6, 0) * E.CFrame.Angles(0, math.pi / 2, 0), S)
	fence(m, cf * E.CFrame.new(S / 2, 0.6, 0) * E.CFrame.Angles(0, math.pi / 2, 0), S)
	fence(m, cf * E.CFrame.new(-18, 0.6, -S / 2), 28)
	fence(m, cf * E.CFrame.new(18, 0.6, -S / 2), 28)

	-- sign
	local sign = model(m, "Sign")
	part(sign, "PostL", V(0.6, 7, 0.6), cf * E.CFrame.new(-6, 3.5, -S / 2 - 1), "#6B4226", E.Enum.Material.Wood)
	part(sign, "PostR", V(0.6, 7, 0.6), cf * E.CFrame.new(6, 3.5, -S / 2 - 1), "#6B4226", E.Enum.Material.Wood)
	local board = part(sign, "Board", V(12.5, 2.6, 0.4), cf * E.CFrame.new(0, 6.2, -S / 2 - 1) * E.CFrame.Angles(0, math.pi, 0), "#F4E1C1", E.Enum.Material.Wood)
	surfaceText(board, E.Enum.NormalId.Front, "Open Ranch", "#5A2E1E", nil).Name = "OwnerText"

	-- smokers
	local smokers = folder(m, "Smokers")
	for si, x in ipairs(WorldBuilder.SMOKER_X) do
		smoker(smokers, "s" .. si, cf * E.CFrame.new(x, 0.6, 20) * E.CFrame.Angles(0, math.pi, 0))
	end
	-- grill (flat-top with 4 spots)
	local grill = model(m, "Grill")
	part(grill, "Base", V(22, 3, 4), cf * E.CFrame.new(-19.5, 2.1, 4), "#2E2E2E", E.Enum.Material.Metal)
	local top = part(grill, "Top", V(22, 0.4, 4), cf * E.CFrame.new(-19.5, 3.8, 4), "#555555", E.Enum.Material.DiamondPlate)
	local gsmoke = E.Instance.new("Smoke")
	gsmoke.Name = "Smoke"
	gsmoke.Enabled = false
	gsmoke.Size = 1.5
	gsmoke.Opacity = 0.1
	gsmoke.RiseVelocity = 3
	gsmoke.Parent = top
	for gi, x in ipairs(WorldBuilder.GRILL_X) do
		local spot = part(grill, "g" .. gi, V(4, 0.2, 3), cf * E.CFrame.new(x, 4.05, 4), "#333333", E.Enum.Material.Metal)
		spot:SetAttribute("Slot", "g" .. gi)
		billboard(spot, "SlotGui", "", 3, 60, "#FFFFFF", 150, 40)
	end
	-- customer tables
	local tables = folder(m, "Tables")
	for ti = 1, cfg.CUSTOMER_SPOTS do
		picnicTable(tables, "t" .. ti, cf * E.CFrame.new(6 + (ti - 1) * 9, 0.6, -4))
	end
	-- pass window (where other players can snag a plate while you're online)
	local pw = model(m, "PassWindow")
	local counter = part(pw, "Counter", V(8, 3.4, 2.5), cf * E.CFrame.new(10, 2.3, -22), "#8B5A2B", E.Enum.Material.WoodPlanks)
	part(pw, "Top", V(8.4, 0.3, 2.9), cf * E.CFrame.new(10, 4.1, -22), "#DEB887", E.Enum.Material.Wood)
	local pwSign = part(pw, "Sign", V(6, 1.2, 0.2), cf * E.CFrame.new(10, 5.8, -21.8) * E.CFrame.Angles(0, math.pi, 0), "#F4E1C1", E.Enum.Material.Wood)
	surfaceText(pwSign, E.Enum.NormalId.Front, "PASS WINDOW", "#5A2E1E", nil)
	folder(pw, "Plates")
	prompt(counter, "snag", "Snag a plate", "Pass Window", 1.2, 9, { Enabled = false })
	billboard(counter, "LockGui", "", 5, 50, "#FFB3B3", 200, 30)

	local spawnPad = part(m, "SpawnPad", V(4, 0.2, 4), cf * E.CFrame.new(0, 1, -12), "#000000", nil, { Transparency = 1, CanCollide = false })
	spawnPad:SetAttribute("Facing", 0)
	-- smoke signal column (enabled on rare cuts)
	local sig = part(m, "SmokeSignal", V(2, 2, 2), cf * E.CFrame.new(0, 14, 20), "#000000", nil, { Transparency = 1, CanCollide = false })
	local ss = E.Instance.new("Smoke")
	ss.Name = "Signal"
	ss.Enabled = false
	ss.Size = 30
	ss.RiseVelocity = 25
	ss.Opacity = 0.6
	ss.Parent = sig
	local sigGui = billboard(sig, "SignalGui", "", 30, 1000, "#FFC83C", 420, 70)
	sigGui.Enabled = false
	sigGui.AlwaysOnTop = true
	-- VIP lights (hidden until VIP Patio pass)
	local vip = folder(m, "VIPLights")
	for li = 0, 12 do
		local x = -S / 2 + 2 + li * ((S - 4) / 12)
		ball(vip, "Bulb", 0.6, cf * E.CFrame.new(x, 7 + math.sin(li / 12 * math.pi) * -1.2, 27), li % 2 == 0 and "#FFE9A8" or "#FFB347", E.Enum.Material.Neon, { Transparency = 1, CanCollide = false })
	end
	part(vip, "Wire", V(S - 2, 0.1, 0.1), cf * E.CFrame.new(0, 7.2, 27), "#222222", nil, { Transparency = 1, CanCollide = false })
	local vipSign = part(vip, "VIPSign", V(6, 2, 0.2), cf * E.CFrame.new(-26, 5, 26.5) * E.CFrame.Angles(0, math.pi, 0), "#1A1A1A", nil, { Transparency = 1 })
	surfaceText(vipSign, E.Enum.NormalId.Front, "VIP PATIO", "#FFD700", nil).TextTransparency = 1
	-- cooler (decor)
	part(m, "Cooler", V(4, 2.4, 2.4), cf * E.CFrame.new(-26, 1.8, 10), "#2E86C1", E.Enum.Material.SmoothPlastic)
	part(m, "CoolerLid", V(4.1, 0.4, 2.5), cf * E.CFrame.new(-26, 3.2, 10), "#FFFFFF", E.Enum.Material.SmoothPlastic)
	-- lawn chair (Unc energy)
	part(m, "ChairSeat", V(2.2, 0.3, 2), cf * E.CFrame.new(26, 1.6, 10), "#2E8B57", E.Enum.Material.Fabric)
	part(m, "ChairBack", V(2.2, 2.4, 0.3), cf * E.CFrame.new(26, 2.8, 11) * E.CFrame.Angles(math.rad(-15), 0, 0), "#2E8B57", E.Enum.Material.Fabric)
	tree(m, (cf * E.CFrame.new(-27, 0.6, 27)).Position, 0.8)
	tree(m, (cf * E.CFrame.new(27, 0.6, 27)).Position, 0.9)
	return m
end

local function buildHub(root, cfg, content)
	local hub = model(root, "Hub")
	local disc = cyl(hub, "Square", 0.4, 110, E.CFrame.new(0, 0.2, 0) * E.CFrame.Angles(0, 0, math.pi / 2), "#C2A878", E.Enum.Material.Sand)
	disc.CanCollide = true
	-- paths to each plot
	for i = 1, cfg.MAX_PLOTS do
		local a = (i - 1) / cfg.MAX_PLOTS * math.pi * 2
		local mid = V(math.cos(a) * 85, 0.25, math.sin(a) * 85)
		part(hub, "Road" .. i, V(8, 0.3, 66), lookAt(mid, V(0, 0.25, 0)), "#C2A878", E.Enum.Material.Sand)
	end
	local spawn = E.Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.4, 8)
	spawn.CFrame = E.CFrame.new(0, 0.5, -36)
	spawn.Color = hex("#C2A878")
	spawn.Material = E.Enum.Material.Sand
	spawn.Parent = hub

	-- Welcome arch
	local arch = model(hub, "WelcomeArch")
	part(arch, "PostL", V(1.5, 16, 1.5), E.CFrame.new(-12, 8, -50), "#6B4226", E.Enum.Material.Wood)
	part(arch, "PostR", V(1.5, 16, 1.5), E.CFrame.new(12, 8, -50), "#6B4226", E.Enum.Material.Wood)
	local beam = part(arch, "Beam", V(28, 4, 1), E.CFrame.new(0, 16, -50) * E.CFrame.Angles(0, math.pi, 0), "#8B4513", E.Enum.Material.WoodPlanks)
	surfaceText(beam, E.Enum.NormalId.Front, "🔥 " .. content.Signs.welcome .. " 🔥", "#FFE9A8", nil)
	local beamBack = part(arch, "BeamBack", V(28, 4, 0.1), E.CFrame.new(0, 16, -50.55), "#8B4513", E.Enum.Material.WoodPlanks)
	surfaceText(beamBack, E.Enum.NormalId.Front, content.Signs.hub, "#FFE9A8", nil)

	-- Sauce shack (coins) and Pitmaster Outfitters (Robux shop)
	local _, shackRoof = stall(hub, "SauceShack", E.CFrame.new(-30, 0.4, -18) * E.CFrame.Angles(0, math.rad(200), 0), content.Signs.shop, "#D9534F", "#FFFFFF", "ui:sauce", "Open Sauce Shack")
	stall(hub, "Outfitters", E.CFrame.new(30, 0.4, -18) * E.CFrame.Angles(0, math.rad(160), 0), "PITMASTER OUTFITTERS", "#2E86C1", "#FFFFFF", "ui:pitshop", "Open Pit Shop")
	-- secret on the shack roof (reach it with the trampoline)
	local roofSecret = part(hub, "RoofSecret", V(2, 0.6, 2), shackRoof.CFrame * E.CFrame.new(0, 0.6, 0), "#FFD700", E.Enum.Material.Neon, { Transparency = 0.2 })
	prompt(roofSecret, "egg:roof", "Sign the roof", "Roof Club", 0.5, 8)

	-- Cook-off stage
	local stage = model(hub, "CookOff")
	part(stage, "Stage", V(34, 1.6, 14), E.CFrame.new(0, 1, 34), "#8B5A2B", E.Enum.Material.WoodPlanks)
	local judges = part(stage, "JudgesTable", V(18, 3.2, 3), E.CFrame.new(0, 3.4, 37), "#FFFFFF", E.Enum.Material.Fabric)
	prompt(judges, "cookoff", "Enter the Cook-Off", "Judges' Table", 0.8, 14)
	local banner = part(stage, "Banner", V(30, 5, 0.4), E.CFrame.new(0, 12, 41) * E.CFrame.Angles(0, math.pi, 0), "#C0392B", E.Enum.Material.Fabric)
	surfaceText(banner, E.Enum.NormalId.Front, "🏆 " .. content.Signs.cookoff .. " 🏆", "#FFFFFF", nil).Name = "BannerText"
	part(stage, "BannerPoleL", V(0.6, 14, 0.6), E.CFrame.new(-15.5, 7, 41.2), "#6B4226", E.Enum.Material.Wood)
	part(stage, "BannerPoleR", V(0.6, 14, 0.6), E.CFrame.new(15.5, 7, 41.2), "#6B4226", E.Enum.Material.Wood)
	WorldBuilder.npc(stage, "Granny", E.CFrame.new(-4, 1.8, 39.5) * E.CFrame.Angles(0, math.pi, 0), { skin = "#C68642", shirt = "#9B59B6", pants = "#5B2C6F", hat = "bun", hatColor = "#DDDDDD", glasses = true, label = "Granny Pecan (Head Judge)", labelColor = "#F5B7B1" })
	WorldBuilder.npc(stage, "JudgeBob", E.CFrame.new(4, 1.8, 39.5) * E.CFrame.Angles(0, math.pi, 0), { skin = "#8D5524", shirt = "#27AE60", hat = "cap", hatColor = "#1E8449", label = "Judge Big Earl" })
	local catDef = { id = "clapcat", body = "#151515", head = "#1E1E1E", scale = 0.9, ears = true }
	local cat = WorldBuilder.critter(E, stage, catDef, E.CFrame.new(0, 5, 37.5) * E.CFrame.Angles(0, math.pi, 0))
	cat.Name = "ClapCatJudge"
	-- leaderboard
	local lb = part(stage, "Leaderboard", V(14, 16, 0.6), E.CFrame.new(26, 9, 36) * E.CFrame.Angles(0, math.rad(200), 0), "#1A1A1A", E.Enum.Material.SmoothPlastic)
	surfaceText(lb, E.Enum.NormalId.Front, "This week's Cook-Off\n(Saturday)\n\nNo entries yet", "#FFE9A8", nil).Name = "BoardText"
	part(stage, "LBLegL", V(0.6, 2, 0.6), E.CFrame.new(21, 1, 36.5), "#333333", E.Enum.Material.Metal)

	-- Unc Hank: dad jokes
	local unc = WorldBuilder.npc(hub, "UncHank", E.CFrame.new(-18, 0.4, 10) * E.CFrame.Angles(0, math.rad(130), 0), { skin = "#D1A27A", shirt = "#F39C12", pants = "#2C3E50", hat = "cap", hatColor = "#2C3E50", label = "Unc Hank", apron = "#B22222" })
	prompt(unc.Torso, "npc:unc", "Hear today's joke", "Unc Hank", 0, 10)
	part(hub, "UncSocks", V(2.1, 0.4, 1.1), E.CFrame.new(-18, 0.8, 10) * E.CFrame.Angles(0, math.rad(130), 0), "#FFFFFF")
	part(hub, "UncGrill", V(3, 3, 3), E.CFrame.new(-22, 1.9, 13), "#1A1A1A", E.Enum.Material.Metal)

	-- The King of the Pit (cowboy hat pitmaster, hums original tunes)
	local king = WorldBuilder.npc(hub, "KingOfThePit", E.CFrame.new(18, 0.4, 10) * E.CFrame.Angles(0, math.rad(230), 0), { skin = "#E0AC69", shirt = "#ECF0F1", pants = "#1F3A93", hat = "cowboy", hatColor = "#F5F0E1", label = "The King of the Pit", labelColor = "#F5D76E" })
	prompt(king.Torso, "npc:king", "Say howdy", "The King of the Pit", 0, 10)
	smoker(hub, "KingSmoker", E.CFrame.new(23, 0.4, 14) * E.CFrame.Angles(0, math.rad(230), 0))

	-- Temp the talking thermometer
	local temp = model(hub, "Temp")
	local stem = cyl(temp, "Stem", 9, 1.2, E.CFrame.new(0, 5.4, -6) * E.CFrame.Angles(0, 0, math.pi / 2), "#ECF0F1", E.Enum.Material.Glass)
	cyl(temp, "Mercury", 6, 0.6, E.CFrame.new(0, 4.4, -6) * E.CFrame.Angles(0, 0, math.pi / 2), "#E74C3C", E.Enum.Material.Neon)
	ball(temp, "Bulb", 2.4, E.CFrame.new(0, 1.6, -6), "#E74C3C", E.Enum.Material.Neon)
	local face = part(temp, "Face", V(2.2, 2.2, 0.2), E.CFrame.new(0, 8, -6.7), "#ECF0F1", E.Enum.Material.SmoothPlastic)
	surfaceText(face, E.Enum.NormalId.Front, "◕‿◕", "#111111", nil).Name = "FaceText"
	local faceBack = part(temp, "FaceBack", V(2.2, 2.2, 0.2), E.CFrame.new(0, 8, -5.3) * E.CFrame.Angles(0, math.pi, 0), "#ECF0F1", E.Enum.Material.SmoothPlastic)
	surfaceText(faceBack, E.Enum.NormalId.Front, "◕‿◕", "#111111", nil).Name = "FaceText"
	billboard(stem, "NameTag", "Temp", 6, 60, "#FFFFFF", 120, 30)
	prompt(stem, "npc:temp", "Talk to Temp", "Temp", 0, 10)

	-- Sunday potluck table with the tiny "Jesus loves you" figure (Mike's egg)
	local pot = model(hub, "Potluck")
	local potCf = E.CFrame.new(-38, 0.4, 24) * E.CFrame.Angles(0, math.rad(60), 0)
	part(pot, "Table", V(14, 0.5, 4), potCf * E.CFrame.new(0, 3, 0), "#F5F5DC", E.Enum.Material.Fabric)
	part(pot, "LegL", V(0.5, 3, 3.5), potCf * E.CFrame.new(-6, 1.5, 0), "#8B5A2B", E.Enum.Material.Wood)
	part(pot, "LegR", V(0.5, 3, 3.5), potCf * E.CFrame.new(6, 1.5, 0), "#8B5A2B", E.Enum.Material.Wood)
	local dishes = { "#F4D03F", "#E67E22", "#27AE60", "#C0392B", "#8E44AD" }
	for di, c in ipairs(dishes) do
		cyl(pot, "Dish" .. di, 0.4, 1.8, potCf * E.CFrame.new(-6 + di * 2, 3.45, -0.6) * E.CFrame.Angles(0, 0, math.pi / 2), c, E.Enum.Material.SmoothPlastic)
	end
	local psign = part(pot, "Sign", V(5, 1.2, 0.2), potCf * E.CFrame.new(-4, 4.4, 1.6), "#FFFFFF", E.Enum.Material.SmoothPlastic)
	surfaceText(psign, E.Enum.NormalId.Back, content.Signs.potluck, "#5A2E1E", nil)
	local fig = model(pot, "BlessedFigure")
	local figBase = potCf * E.CFrame.new(5.4, 3.25, 1.2)
	local figBody = part(fig, "Body", V(0.35, 0.45, 0.25), figBase * E.CFrame.new(0, 0.22, 0), "#FFFFFF", E.Enum.Material.SmoothPlastic)
	part(fig, "Sash", V(0.36, 0.45, 0.1), figBase * E.CFrame.new(0.05, 0.22, -0.1), "#C0392B", E.Enum.Material.Fabric)
	ball(fig, "Head", 0.38, figBase * E.CFrame.new(0, 0.62, 0), "#E0AC69", E.Enum.Material.SmoothPlastic)
	part(fig, "Hair", V(0.4, 0.15, 0.4), figBase * E.CFrame.new(0, 0.8, 0.02), "#6B4226", E.Enum.Material.SmoothPlastic)
	local rib = billboard(figBody, "Ribbon", "Jesus loves you ♥", 1.2, 14, "#FFD1DC", 140, 22)
	rib.Name = "Ribbon"
	prompt(figBody, "egg:blessed", "Look closer", "Tiny figure", 0.5, 6, { RequiresLineOfSight = false })

	-- Trampoline (super bounce up to the shack roof)
	local tramp = model(hub, "Trampoline")
	cyl(tramp, "Rim", 1, 12, E.CFrame.new(-44, 1.4, -2) * E.CFrame.Angles(0, 0, math.pi / 2), "#2E86C1", E.Enum.Material.SmoothPlastic)
	local mat = cyl(tramp, "Mat", 0.3, 10.5, E.CFrame.new(-44, 2, -2) * E.CFrame.Angles(0, 0, math.pi / 2), "#111111", E.Enum.Material.Fabric)
	mat.Name = "Bounce"
	mat:SetAttribute("Bounce", 140)

	-- Mosquito zone marker
	local mz = part(hub, "MosquitoZone", V(4, 4, 4), E.CFrame.new(0, 14, 0), "#000000", nil, { Transparency = 1, CanCollide = false })
	mz:SetAttribute("Radius", 40)

	-- lamp posts & trees
	for li = 0, 7 do
		local a = li / 8 * math.pi * 2 + math.pi / 8
		local p = V(math.cos(a) * 52, 0.4, math.sin(a) * 52)
		part(hub, "Lamp" .. li, V(0.6, 10, 0.6), E.CFrame.new(p + V(0, 5, 0)), "#2C3E50", E.Enum.Material.Metal)
		local bulb = ball(hub, "LampBulb" .. li, 1.4, E.CFrame.new(p + V(0, 10.4, 0)), "#FFE9A8", E.Enum.Material.Neon)
		local light = E.Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 1.4
		light.Color = hex("#FFD9A0")
		light.Parent = bulb
	end
	return hub
end

local function buildCreek(root, content)
	-- Secret creek "behind" the map, through a gap in the hedge north of plot 7.
	local creek = model(root, "Creek")
	local z = -260
	for i = -8, 8 do
		if i ~= 0 then
			part(creek, "Hedge" .. i, V(12, 8, 6), E.CFrame.new(i * 12, 4, z + 30), "#2E7D32", E.Enum.Material.Grass)
		end
	end
	part(creek, "Water", V(200, 1, 18), E.CFrame.new(0, -0.1, z), "#3FA7D6", E.Enum.Material.Glass, { Transparency = 0.35, CanCollide = false })
	part(creek, "Bed", V(200, 1, 18), E.CFrame.new(0, -1.2, z), "#6B5B45", E.Enum.Material.Sand)
	for i = 1, 9 do
		ball(creek, "Rock" .. i, 2 + (i % 3), E.CFrame.new(-40 + i * 9, 0.4, z + ((i % 2 == 0) and 9 or -9)), "#8C8C8C", E.Enum.Material.Slate)
	end
	local stone = part(creek, "WhisperStone", V(4, 3, 3), E.CFrame.new(6, 1.5, z + 12), "#7F8C8D", E.Enum.Material.Slate)
	prompt(stone, "egg:creek", "Listen closely", content.Slang.quietCreek, 1, 8)
	local sign = part(creek, "Sign", V(5, 2, 0.3), E.CFrame.new(0, 3, z + 26), "#F4E1C1", E.Enum.Material.Wood)
	surfaceText(sign, E.Enum.NormalId.Back, content.Signs.creek, "#5A2E1E", nil)
	-- the World's Okayest Unc apron hanging on a branch
	part(creek, "Branch", V(0.6, 7, 0.6), E.CFrame.new(-14, 3.5, z + 14), "#6B4226", E.Enum.Material.Wood)
	local apron = part(creek, "OkayestApron", V(1.8, 2.2, 0.15), E.CFrame.new(-14, 5, z + 13.5), "#4A6FA5", E.Enum.Material.Fabric)
	surfaceText(apron, E.Enum.NormalId.Front, "WORLD'S OKAYEST UNC", "#FFFFFF", nil)
	prompt(apron, "egg:apron", "Take the apron", "Mystery apron", 0.5, 8)
	tree(creek, V(20, 0, z + 16), 1.1)
	tree(creek, V(-30, 0, z + 16), 1)
	return creek
end

-- Build everything under `parent` (Workspace). Returns the Map model.
function WorldBuilder.build(env, parent, cfg, content)
	E = env
	local map = model(parent, "Map")
	part(map, "Ground", V(900, 2, 900), E.CFrame.new(0, -1, 0), "#7CC35A", E.Enum.Material.Grass)
	local plots = folder(map, "Plots")
	for i = 1, cfg.MAX_PLOTS do
		buildPlot(plots, i, cfg)
	end
	buildHub(map, cfg, content)
	buildCreek(map, content)
	-- scatter trees around the edge
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local r = 215 + (i % 3) * 12
		if not (a > math.rad(255) and a < math.rad(285)) then
			tree(map, V(math.cos(a) * r, 0, math.sin(a) * r), 1 + (i % 2) * 0.3)
		end
	end
	return map
end

return WorldBuilder
