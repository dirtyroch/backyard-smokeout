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

-- `studs` (optional {w, h}) sizes the label in world studs instead of pixels, so labels on
-- closely spaced things (smoker row, grill spots, customer tables) shrink with distance
-- instead of piling on top of each other.
local function billboard(adornee, name, text, offsetY, maxDist, color, w, h, studs: { number }?)
	local b = E.Instance.new("BillboardGui")
	b.Name = name
	if studs then
		b.Size = E.UDim2.new(studs[1], 0, studs[2], 0)
	else
		b.Size = E.UDim2.new(0, w or 160, 0, h or 40)
	end
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
			glow.Color = hex("#9B5CFF")
			glow.Range = 10
			glow.Brightness = 2
			glow.Parent = p
			local sp = E.Instance.new("Sparkles")
			sp.SparkleColor = hex("#9B5CFF")
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
	local gui = billboard(barrel, "SlotGui", "", 4.2, 70, "#FFFFFF", 180, 44, { 7.5, 2 })
	gui.Name = "SlotGui"
	-- padlock sign shown (by WorldService) while this slot is locked; parts remember their base
	-- color so the dark locked silhouette can be undone.
	local lock = part(m, "LockSign", V(3.2, 1.5, 0.2), cf * E.CFrame.new(0, 3.5, 1.85), "#FFC83C", E.Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CastShadow = false })
	for _, face in ipairs({ E.Enum.NormalId.Front, E.Enum.NormalId.Back }) do
		surfaceText(lock, face, "🔒 LOCKED", "#1C1A1F", nil).Parent.Enabled = false
	end
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("BasePart") and c.Name ~= "MeatSpot" and c.Name ~= "LockSign" then
			c:SetAttribute("BaseColor", "#" .. c.Color:ToHex())
		end
	end
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
	local sign = part(m, "Sign", V(12, 2.2, 0.3), cf * E.CFrame.new(0, 7.25, -1.5), "#F4E1C1", E.Enum.Material.Wood)
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
	part(m, "Patio", V(56, 0.3, 16), cf * E.CFrame.new(0, 0.7, 18), "#C9B79C", E.Enum.Material.Slate)
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
		billboard(spot, "SlotGui", "", 3, 60, "#FFFFFF", 150, 40, { 4.6, 1.5 })
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

-- ===================================================================================
-- Scenery: purely decorative set dressing so the world feels lived-in and Texas-y.
-- Rules: everything is Anchored; decor has CanCollide/CanQuery/CanTouch off and small
-- pieces don't cast shadows; it is grouped into Models by area (Horizon, Neighborhood,
-- HubDecor, CreekDecor, per-plot Decor) so StreamingEnabled can stream it by area, with the
-- far skyline marked Persistent. Shapes are simple blocks/balls/cylinders (cheap on phones).
-- Gameplay paths (roads, plot paths, patios, tables, pass windows) are left clear.
-- ===================================================================================
local PAL = {
	grass = "#79C84F",
	grassFar = "#8CC35E",
	berm = { "#86C25A", "#7AB852", "#93CB66" },
	oak = { "#3F8F3A", "#4FA346", "#468F3E" },
	mesquite = { "#8DB85A", "#7EA84E", "#9CC466" },
	trunk = "#6B4226",
	bluebonnet = "#3D6FE0",
	bonnetTip = "#F4F7FF",
	paintbrush = "#FF5A3C",
	susan = "#FFC72C",
	susanEye = "#4A2B12",
	hay = "#E2BE62",
	mesa = { "#D9A07A", "#CF9470", "#E2B08A" },
	mesaCap = "#B97A58",
	wood = "#A86B3C",
	fenceWood = "#8B5A2B",
	barnRed = "#C8433A",
	cream = "#FFF2D9",
	roof = "#5A4A44",
	metal = "#C7D0D8",
	water = "#3FB6E8",
	bronze = "#B8793A",
	bronzeHi = "#E6B25A",
	bulbs = { "#FFE9A8", "#FFB347", "#FF8FB1", "#8FD3FF" },
}
WorldBuilder.PALETTE = PAL

local seed = 20261101
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function rr(a, b)
	return a + (b - a) * rnd()
end
local function pick(t)
	return t[1 + math.floor(rnd() * #t) % #t]
end

local function deco(parent, name, size, cf, color, material, shadow)
	return part(parent, name, size, cf, color, material, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = shadow == true })
end
local function dball(parent, name, d, cf, color, material, shadow)
	local p = deco(parent, name, V(d, d, d), cf, color, material, shadow)
	p.Shape = E.Enum.PartType.Ball
	return p
end
local function dcyl(parent, name, length, diameter, cf, color, material, shadow)
	local p = deco(parent, name, V(length, diameter, diameter), cf, color, material, shadow)
	p.Shape = E.Enum.PartType.Cylinder
	return p
end
local function at(pos)
	return E.CFrame.new(pos)
end
local function yaw(r)
	return E.CFrame.Angles(0, r, 0)
end
local function polar(deg, r, y)
	local a = math.rad(deg)
	return V(math.cos(a) * r, y or 0, math.sin(a) * r)
end
local function streaming(m, mode)
	pcall(function()
		m.ModelStreamingMode = E.Enum.ModelStreamingMode[mode]
	end)
end
local function upright()
	return E.CFrame.Angles(0, 0, math.pi / 2) -- turns an X-axis cylinder upright
end

-- ---------- reusable props ----------
local function liveOak(parent, pos, s, opts)
	opts = opts or {}
	local m = model(parent, "LiveOak")
	local sh = opts.shadow == true
	deco(m, "Trunk", V(2.2 * s, 8 * s, 2.2 * s), at(pos + V(0, 4 * s, 0)), PAL.trunk, E.Enum.Material.Wood, sh)
	if not opts.far then
		deco(m, "Limb", V(8 * s, 1.1 * s, 1.1 * s), at(pos + V(2.5 * s, 7.6 * s, 0)) * E.CFrame.Angles(0, 0, math.rad(18)), PAL.trunk, E.Enum.Material.Wood, false)
	end
	local c = pick(PAL.oak)
	dball(m, "Canopy", 12 * s, at(pos + V(0, 11 * s, 0)), c, E.Enum.Material.Grass, sh)
	dball(m, "Canopy2", 9.5 * s, at(pos + V(6 * s, 9.6 * s, 1.2 * s)), pick(PAL.oak), E.Enum.Material.Grass, false)
	if not opts.far then
		dball(m, "Canopy3", 9 * s, at(pos + V(-5.5 * s, 9.4 * s, -1.5 * s)), pick(PAL.oak), E.Enum.Material.Grass, false)
	end
	return m
end

local function mesquite(parent, pos, s)
	local m = model(parent, "Mesquite")
	local lean = rr(-0.25, 0.25)
	deco(m, "Trunk", V(1 * s, 7 * s, 1 * s), at(pos + V(0, 3.4 * s, 0)) * E.CFrame.Angles(lean, 0, lean * 0.6), "#5A3A22", E.Enum.Material.Wood, false)
	dball(m, "Leaves", 6.5 * s, at(pos + V(lean * 3 * s, 7.6 * s, 0)), pick(PAL.mesquite), E.Enum.Material.Grass, false)
	dball(m, "Leaves2", 5 * s, at(pos + V(2.6 * s, 6.6 * s, 1.6 * s)), pick(PAL.mesquite), E.Enum.Material.Grass, false)
	return m
end

local function grassClump(parent, pos, s)
	s = s or 1
	for k = 1, 3 do
		local a = k * 2.1 + rr(0, 0.5)
		deco(parent, "Grass", V(0.25 * s, 2.6 * s, 0.7 * s), at(pos + V(math.cos(a) * 0.4, 1.2 * s, math.sin(a) * 0.4)) * yaw(a) * E.CFrame.Angles(0, 0, rr(-0.35, 0.35)), "#9CC25A", E.Enum.Material.Grass, false)
	end
end

-- kind: "bluebonnet" | "paintbrush" | "susan" | "mix"
local function flowerPatch(parent, pos, radius, n, kind)
	local m = model(parent, "Wildflowers")
	for k = 1, n do
		local a, r = rr(0, math.pi * 2), math.sqrt(rnd()) * radius
		local p = pos + V(math.cos(a) * r, 0, math.sin(a) * r)
		local kd = kind == "mix" and pick({ "bluebonnet", "bluebonnet", "paintbrush", "susan" }) or kind
		if kd == "bluebonnet" then
			deco(m, "Bonnet", V(0.5, 1.2, 0.5), at(p + V(0, 0.6, 0)), PAL.bluebonnet, E.Enum.Material.SmoothPlastic, false)
			if k % 2 == 0 then
				dball(m, "Tip", 0.4, at(p + V(0, 1.3, 0)), PAL.bonnetTip, E.Enum.Material.SmoothPlastic, false)
			end
		elseif kd == "paintbrush" then
			deco(m, "Brush", V(0.45, 1.1, 0.45), at(p + V(0, 0.55, 0)), PAL.paintbrush, E.Enum.Material.SmoothPlastic, false)
		else
			dball(m, "Susan", 0.8, at(p + V(0, 0.9, 0)), PAL.susan, E.Enum.Material.SmoothPlastic, false)
		end
	end
	return m
end

local function hayBale(parent, pos, rot)
	return dcyl(parent, "HayBale", 4, 4.4, at(pos + V(0, 2.2, 0)) * yaw(rot or 0), PAL.hay, E.Enum.Material.Grass, true)
end

local function cooler(parent, cf, color)
	deco(parent, "Cooler", V(3.4, 2, 2), cf * E.CFrame.new(0, 1, 0), color or "#2F7BD8", E.Enum.Material.SmoothPlastic, true)
	deco(parent, "CoolerLid", V(3.5, 0.35, 2.1), cf * E.CFrame.new(0, 2.15, 0), "#FFFFFF", E.Enum.Material.SmoothPlastic, false)
end

local function lawnChair(parent, cf, color)
	deco(parent, "ChairSeat", V(2.2, 0.3, 2), cf * E.CFrame.new(0, 1.1, 0), color, E.Enum.Material.Fabric, true)
	deco(parent, "ChairBack", V(2.2, 2.4, 0.3), cf * E.CFrame.new(0, 2.2, 1) * E.CFrame.Angles(math.rad(-15), 0, 0), color, E.Enum.Material.Fabric, false)
	deco(parent, "ChairFrame", V(2.4, 1, 0.2), cf * E.CFrame.new(0, 0.5, -0.9), "#C7D0D8", E.Enum.Material.Metal, false)
end

local function cornhole(parent, cf, color)
	deco(parent, "Cornhole", V(2.4, 0.25, 4.4), cf * E.CFrame.new(0, 0.75, 0) * E.CFrame.Angles(math.rad(12), 0, 0), color, E.Enum.Material.WoodPlanks, true)
	dcyl(parent, "Hole", 0.08, 0.9, cf * E.CFrame.new(0, 1.12, 1.2) * E.CFrame.Angles(math.rad(12), 0, 0) * upright(), "#1C1A1F", E.Enum.Material.SmoothPlastic, false)
	deco(parent, "Bag", V(0.7, 0.25, 0.7), cf * E.CFrame.new(0.5, 0.9, -0.6) * yaw(0.4), "#D93636", E.Enum.Material.Fabric, false)
end

local function kiddiePool(parent, cf)
	dcyl(parent, "Pool", 1.3, 8, cf * E.CFrame.new(0, 0.65, 0) * upright(), "#5AD2FF", E.Enum.Material.SmoothPlastic, false)
	dcyl(parent, "PoolWater", 0.1, 7.2, cf * E.CFrame.new(0, 1.2, 0) * upright(), "#BFF0FF", E.Enum.Material.Glass, false).Transparency = 0.15
	dball(parent, "Ducky", 0.9, cf * E.CFrame.new(1.4, 1.5, 0.6), "#FFD23C", E.Enum.Material.SmoothPlastic, false)
	dball(parent, "DuckyHead", 0.55, cf * E.CFrame.new(1.4, 2.05, 0.3), "#FFD23C", E.Enum.Material.SmoothPlastic, false)
	deco(parent, "DuckyBeak", V(0.25, 0.12, 0.3), cf * E.CFrame.new(1.4, 2.0, 0.0), "#FF8A1E", E.Enum.Material.SmoothPlastic, false)
end

local function picnicBlanket(parent, cf)
	deco(parent, "Blanket", V(6, 0.12, 6), cf * E.CFrame.new(0, 0.08, 0), "#D93636", E.Enum.Material.Fabric, false)
	for _, o in ipairs({ { -1.5, -1.5 }, { 1.5, 1.5 } }) do
		deco(parent, "Check", V(3, 0.13, 3), cf * E.CFrame.new(o[1], 0.09, o[2]), "#FFF6E6", E.Enum.Material.Fabric, false)
	end
	deco(parent, "Basket", V(1.8, 1.1, 1.2), cf * E.CFrame.new(1.4, 0.65, -1.4), "#C9954C", E.Enum.Material.WoodPlanks, false)
	dball(parent, "Watermelon", 1.4, cf * E.CFrame.new(-1.4, 0.75, 1.2), "#3E9B4F", E.Enum.Material.SmoothPlastic, false)
end

local function lantern(parent, cf)
	deco(parent, "LanternPost", V(0.4, 6, 0.4), cf * E.CFrame.new(0, 3, 0), "#2C2420", E.Enum.Material.Metal, false)
	deco(parent, "LanternArm", V(1.6, 0.25, 0.25), cf * E.CFrame.new(0.7, 6, 0), "#2C2420", E.Enum.Material.Metal, false)
	deco(parent, "Lantern", V(0.8, 1, 0.8), cf * E.CFrame.new(1.3, 5.3, 0), "#FFD38A", E.Enum.Material.Neon, false)
end

-- Sagging string of bulbs between two points (wire + bulbs, no lights: cheap).
local function stringLights(parent, a, b, n, sag)
	local m = model(parent, "StringLights")
	local mid = (a + b) / 2 - V(0, sag * 0.6, 0)
	local len = (b - a).Magnitude
	deco(m, "Wire", V(0.08, 0.08, len), lookAt(mid, b - V(0, sag * 0.6, 0)), "#2C2420", E.Enum.Material.SmoothPlastic, false)
	for k = 1, n do
		local t = k / (n + 1)
		local p = a:Lerp(b, t) - V(0, math.sin(t * math.pi) * sag, 0)
		dball(m, "Bulb", 0.55, at(p - V(0, 0.3, 0)), PAL.bulbs[(k % #PAL.bulbs) + 1], E.Enum.Material.Neon, false)
	end
	return m
end

local function railFence(parent, a, b, spacing)
	local m = model(parent, "RailFence")
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local posts = math.max(1, math.floor(len / spacing))
	for k = 0, posts do
		local p = a + dir * (k * len / posts)
		deco(m, "Post", V(0.7, 4.2, 0.7), at(p + V(0, 2.1, 0)), PAL.fenceWood, E.Enum.Material.Wood, false)
	end
	local mid = (a + b) / 2
	for _, h in ipairs({ 1.6, 3.2 }) do
		deco(m, "Rail", V(0.3, 0.45, len), lookAt(mid + V(0, h, 0), b + V(0, h, 0)), "#9C6B3E", E.Enum.Material.Wood, false)
	end
	return m
end

local function pickupTruck(parent, cf, color)
	local m = model(parent, "PickupTruck")
	local function p(name, size, off, c, mat)
		return deco(m, name, size, cf * off, c, mat or E.Enum.Material.SmoothPlastic, name == "Body")
	end
	p("Body", V(6.4, 2.2, 15), E.CFrame.new(0, 2.5, 0), color, E.Enum.Material.Metal)
	p("Cab", V(6.2, 2.6, 5), E.CFrame.new(0, 4.9, -1.2), color, E.Enum.Material.Metal)
	p("Windshield", V(5.6, 2, 0.15), E.CFrame.new(0, 5, -3.75), "#9FD4F0", E.Enum.Material.Glass)
	p("RearWindow", V(5.4, 1.6, 0.15), E.CFrame.new(0, 5.2, 1.35), "#9FD4F0", E.Enum.Material.Glass)
	p("BedFloor", V(5.6, 0.2, 6.8), E.CFrame.new(0, 3.65, 4.6), "#3A3A3A", E.Enum.Material.DiamondPlate)
	p("Tailgate", V(6.2, 0.25, 2.2), E.CFrame.new(0, 3.1, 8.6), color, E.Enum.Material.Metal)
	p("Bumper", V(6.6, 0.7, 0.6), E.CFrame.new(0, 1.6, -7.6), "#C7D0D8", E.Enum.Material.Metal)
	p("Grille", V(4.4, 1.2, 0.2), E.CFrame.new(0, 2.6, -7.55), "#2C2420")
	p("LightL", V(0.9, 0.6, 0.15), E.CFrame.new(-2.5, 3, -7.55), "#FFF6E6", E.Enum.Material.Neon)
	p("LightR", V(0.9, 0.6, 0.15), E.CFrame.new(2.5, 3, -7.55), "#FFF6E6", E.Enum.Material.Neon)
	for _, w in ipairs({ { -3.2, -4.6 }, { 3.2, -4.6 }, { -3.2, 4.6 }, { 3.2, 4.6 } }) do
		dcyl(m, "Wheel", 1.1, 3, cf * E.CFrame.new(w[1], 1.5, w[2]), "#1C1A1F", E.Enum.Material.SmoothPlastic, false)
	end
	cooler(m, cf * E.CFrame.new(-1.2, 3.75, 5.2), "#D93636")
	return m
end

local function houseBack(parent, cf, wall, trim)
	-- cf faces the hub (back of the house toward the players)
	local m = model(parent, "HouseBack")
	local function p(name, size, off, c, mat, sh)
		return deco(m, name, size, cf * off, c, mat or E.Enum.Material.SmoothPlastic, sh)
	end
	p("Walls", V(34, 13, 20), E.CFrame.new(0, 6.5, 10), wall, E.Enum.Material.WoodPlanks, true)
	p("RoofL", V(36, 1.2, 12.6), E.CFrame.new(0, 15.4, 4.6) * E.CFrame.Angles(math.rad(-32), 0, 0), PAL.roof, E.Enum.Material.Slate, true)
	p("RoofR", V(36, 1.2, 12.6), E.CFrame.new(0, 15.4, 15.4) * E.CFrame.Angles(math.rad(32), 0, 0), PAL.roof, E.Enum.Material.Slate, false)
	p("Chimney", V(2.6, 6, 2.6), E.CFrame.new(10, 17, 12), "#A0523D", E.Enum.Material.Brick, false)
	p("BackDoor", V(4, 7, 0.3), E.CFrame.new(-6, 3.5, -0.1), trim)
	p("WindowL", V(5, 3.6, 0.3), E.CFrame.new(4, 7.5, -0.1), "#BFE6FF", E.Enum.Material.Glass)
	p("WindowR", V(5, 3.6, 0.3), E.CFrame.new(12, 7.5, -0.1), "#BFE6FF", E.Enum.Material.Glass)
	p("Porch", V(14, 0.6, 6), E.CFrame.new(-6, 0.3, -3), PAL.wood, E.Enum.Material.WoodPlanks)
	p("ACUnit", V(3, 3, 3), E.CFrame.new(14, 1.5, -2), "#C7D0D8", E.Enum.Material.Metal)
	-- privacy fence around the backyard
	local fy, fh = 3, 6
	p("FenceBack", V(44, fh, 0.5), E.CFrame.new(0, fy, -22), "#B07A48", E.Enum.Material.WoodPlanks)
	p("FenceL", V(0.5, fh, 22), E.CFrame.new(-22, fy, -11), "#B07A48", E.Enum.Material.WoodPlanks)
	p("FenceR", V(0.5, fh, 22), E.CFrame.new(22, fy, -11), "#B07A48", E.Enum.Material.WoodPlanks)
	return m
end

local function waterTower(parent, pos, label)
	local m = model(parent, "WaterTower")
	local legH, tankY = 34, 42
	for _, o in ipairs({ { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } }) do
		deco(m, "Leg", V(1, legH, 1), at(pos + V(o[1] * 0.8, legH / 2, o[2] * 0.8)) * E.CFrame.Angles(math.rad(o[2] * 0.6), 0, math.rad(-o[1] * 0.6)), PAL.metal, E.Enum.Material.Metal, true)
	end
	deco(m, "Brace", V(10, 0.5, 0.5), at(pos + V(0, 16, -4.4)), PAL.metal, E.Enum.Material.Metal, false)
	deco(m, "Brace2", V(0.5, 0.5, 10), at(pos + V(4.4, 16, 0)), PAL.metal, E.Enum.Material.Metal, false)
	deco(m, "Catwalk", V(15, 0.5, 15), at(pos + V(0, legH + 0.5, 0)), "#8E9AA6", E.Enum.Material.DiamondPlate, false)
	dcyl(m, "Tank", 14, 16, at(pos + V(0, tankY, 0)) * upright(), "#F2F5F7", E.Enum.Material.Metal, true)
	dball(m, "Cap", 16.4, at(pos + V(0, tankY + 4, 0)), "#E1E7EC", E.Enum.Material.Metal, false)
	deco(m, "Spire", V(0.6, 4, 0.6), at(pos + V(0, tankY + 13.6, 0)), PAL.barnRed, E.Enum.Material.Metal, false)
	-- the label sits on a band facing the hub, and again on the far side
	local face = lookAt(pos + V(0, tankY, 0), V(0, tankY, 0))
	local band = deco(m, "LabelBand", V(12, 5.5, 0.4), face * E.CFrame.new(0, 0, -7.9), "#F2F5F7", E.Enum.Material.Metal, false)
	surfaceText(band, E.Enum.NormalId.Front, label, PAL.barnRed, nil)
	local back = deco(m, "LabelBandBack", V(12, 5.5, 0.4), face * E.CFrame.new(0, 0, 7.9) * yaw(math.pi), "#F2F5F7", E.Enum.Material.Metal, false)
	surfaceText(back, E.Enum.NormalId.Front, label, PAL.barnRed, nil)
	return m
end

local function windmill(parent, pos, facing)
	local m = model(parent, "Windmill")
	for _, o in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		deco(m, "Leg", V(0.6, 32, 0.6), at(pos + V(o[1] * 0.55, 16, o[2] * 0.55)) * E.CFrame.Angles(math.rad(o[2] * 1.4), 0, math.rad(-o[1] * 1.4)), PAL.metal, E.Enum.Material.Metal, true)
	end
	local hubCf = at(pos + V(0, 32.5, 0)) * yaw(facing)
	deco(m, "Head", V(1.6, 1.6, 3.4), hubCf, "#8E9AA6", E.Enum.Material.Metal, false)
	deco(m, "TailBoom", V(0.4, 0.4, 7), hubCf * E.CFrame.new(0, 0, 4.5), "#8E9AA6", E.Enum.Material.Metal, false)
	local vane = deco(m, "TailVane", V(0.2, 4, 4.5), hubCf * E.CFrame.new(0, 0.5, 8.4), PAL.barnRed, E.Enum.Material.Metal, false)
	surfaceText(vane, E.Enum.NormalId.Right, "ROCH", "#FFF2D9", nil)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		deco(m, "Blade", V(0.15, 5.5, 1.1), hubCf * E.CFrame.new(0, 0, -1.9) * E.CFrame.Angles(0, 0, a) * E.CFrame.new(0, 3.6, 0) * E.CFrame.Angles(0, 0.35, 0), "#E1E7EC", E.Enum.Material.Metal, false)
	end
	dcyl(m, "Tank", 3, 9, at(pos + V(7, 1.5, 4)) * upright(), "#9AA5AE", E.Enum.Material.Metal, false)
	return m
end

local function mesa(parent, pos, w, h, d, rot)
	-- stepped butte: wide talus skirt, sloped shoulders, sheer body, darker caprock
	local m = model(parent, "Mesa")
	local cf = at(pos) * yaw(rot)
	local c = pick(PAL.mesa)
	deco(m, "Talus", V(w * 1.3, h * 0.3, d * 1.25), cf * E.CFrame.new(0, h * 0.15 - 4, 0), PAL.mesa[3], E.Enum.Material.Sandstone, false)
	deco(m, "ShoulderL", V(w * 0.35, h * 0.55, d * 1.05), cf * E.CFrame.new(-w * 0.5, h * 0.15, 0) * E.CFrame.Angles(0, 0, math.rad(-38)), c, E.Enum.Material.Sandstone, false)
	deco(m, "ShoulderR", V(w * 0.35, h * 0.55, d * 1.05), cf * E.CFrame.new(w * 0.5, h * 0.15, 0) * E.CFrame.Angles(0, 0, math.rad(38)), c, E.Enum.Material.Sandstone, false)
	deco(m, "Body", V(w, h, d), cf * E.CFrame.new(0, h / 2 - 4, 0), c, E.Enum.Material.Sandstone, false)
	deco(m, "Cap", V(w * 1.04, 5, d * 1.04), cf * E.CFrame.new(0, h - 4, 0), PAL.mesaCap, E.Enum.Material.Sandstone, false)
	return m
end

local function fireflies(parent, cf, size)
	local box = deco(parent, "FireflyZone", size, cf, "#000000", nil, false)
	box.Transparency = 1
	if E.NumberSequence and E.NumberRange and E.ColorSequence then
		local pe = E.Instance.new("ParticleEmitter")
		pe.Name = "Fireflies"
		pe.Enabled = false -- Ambient (client) turns these on at dusk
		pe.Rate = 5
		pe.Lifetime = E.NumberRange.new(4, 7)
		pe.Speed = E.NumberRange.new(0.3, 1.2)
		pe.SpreadAngle = E.Vector2 and E.Vector2.new(180, 180) or pe.SpreadAngle
		pe.LightEmission = 1
		pe.LightInfluence = 0
		pe.Size = E.NumberSequence.new(0.22)
		pe.Color = E.ColorSequence.new(hex("#FFF27A"))
		pe.Transparency = E.NumberSequence.new(0.1)
		pe.Parent = box
		pcall(function()
			pe.Shape = E.Enum.ParticleEmitterShape.Box
			pe.ShapeStyle = E.Enum.ParticleEmitterShapeStyle.Volume
		end)
	end
	return box
end

local function leaves(parentPart)
	if not (E.NumberSequence and E.NumberRange and E.ColorSequence) then
		return
	end
	local pe = E.Instance.new("ParticleEmitter")
	pe.Name = "DriftingLeaves"
	pe.Rate = 0.5
	pe.Lifetime = E.NumberRange.new(6, 9)
	pe.Speed = E.NumberRange.new(0.5, 1.5)
	pe.Acceleration = V(0.6, -1.2, 0.4)
	pe.RotSpeed = E.NumberRange.new(-90, 90)
	pe.Rotation = E.NumberRange.new(0, 360)
	pe.Size = E.NumberSequence.new(0.35)
	pe.Color = E.ColorSequence.new(hex("#D9A441"), hex("#7FB24A"))
	pe.LightInfluence = 1
	pe.Parent = parentPart
end

local function smokeWisp(parentPart)
	local s = E.Instance.new("Smoke")
	s.Name = "Wisp"
	s.Size = 1.2
	s.Opacity = 0.08
	s.RiseVelocity = 2.5
	s.Color = hex("#E8E2D8")
	s.Parent = parentPart
end

-- ---------- the pibble landmark ----------
-- "Big Biscuit": an original belly-up pibble statue. Blue-gray coat, white blaze and paws,
-- a big pink belly in the air, a wide round head with a cheek-to-cheek grin. Built from
-- SpecialMesh spheres (ellipsoids) so the curves stay smooth with few parts. The head is at
-- -X, the belly faces up, the face is turned toward the spawn (-Z). Prompt kind
-- "landmark:pibble".
local function ell(parent, name, size, cf, color, material)
	local p = deco(parent, name, size, cf, color, material or E.Enum.Material.SmoothPlastic, false)
	local mesh = E.Instance.new("SpecialMesh")
	mesh.MeshType = E.Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
WorldBuilder.ellipsoid = ell

function WorldBuilder.pibble(parent, base, content)
	local m = model(parent, "BigBiscuit")
	local S = 1.3
	local COAT, COAT_D, MUZ = "#7C8590", "#5E6772", "#8D96A1"
	local WHITE, PINK, NOSE = "#F4F1EC", "#F59BB0", "#2A2B30"
	local MOUTH, TONGUE = "#5A1F2E", "#FF6F8E"
	local top = base * E.CFrame.new(1.6, 2.6, 0) -- plinth top, nudged so the head sits on it
	local function T(x, y, z, rx, ry, rz)
		return top * E.CFrame.new(x * S, y * S, z * S) * E.CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local function e(name, sx, sy, sz, cf, c, mat)
		return ell(m, name, V(sx * S, sy * S, sz * S), cf, c, mat)
	end
	-- plinth (solid)
	cyl(m, "Plinth", 2, 25, base * E.CFrame.new(0, 1.0, 0) * upright(), "#D9CDB8", E.Enum.Material.Slate)
	cyl(m, "PlinthTrim", 0.6, 25.8, base * E.CFrame.new(0, 2.2, 0) * upright(), "#BFAF95", E.Enum.Material.Slate)
	local plaque = part(m, "Plaque", V(9, 1.9, 0.3), base * E.CFrame.new(0, 1.1, -12.55), "#C9A04A", E.Enum.Material.Metal)
	surfaceText(plaque, E.Enum.NormalId.Front, content and content.Signs and content.Signs.pibble or "BIG BISCUIT\nCertified Good Boy · Bites: 0 · Belly rubs: ∞", "#3A2414", nil)
	-- a cushion so he lies on something soft
	e("Cushion", 17, 1.4, 9.5, T(-0.5, 0.5, 0.3), "#D93636", E.Enum.Material.Fabric)

	-- body: a stocky barrel lying on its back
	e("Torso", 11, 6.4, 7.2, T(0.4, 3.4, 0), COAT)
	local belly = e("Belly", 8.2, 3.2, 5.4, T(0.9, 5.7, -0.4), PINK)
	e("ChestBlaze", 4.2, 3.6, 5.2, T(-3.6, 5.0, -0.4), WHITE)
	e("Neck", 4.2, 5.6, 6.2, T(-5.2, 3.9, -0.2), COAT)
	local collar = cyl(m, "Collar", 1.0 * S, 6.9 * S, T(-5.3, 4.0, -0.2, 0, 0, 0), "#F2C14E", E.Enum.Material.Foil)
	collar.CanCollide = false
	dball(m, "Tag", 1.1 * S, T(-5.8, 3.4, -3.4), "#FFD86B", E.Enum.Material.Foil, false)

	-- legs in the air: short, sturdy, a little bent, white socks
	for _, side in { -1, 1 } do
		local z = side * 2.2 - 0.3
		e("FrontLeg" .. side, 2.2, 4.2, 2.2, T(-3.0, 7.0, z, 0, 0, 28), COAT)
		e("FrontPaw" .. side, 2.6, 1.8, 2.5, T(-4.1, 8.9, z, 0, 0, 40), WHITE)
		e("Haunch" .. side, 4.4, 4.0, 3.2, T(3.9, 4.8, side * 2.6 - 0.3), COAT)
		e("BackLeg" .. side, 2.1, 4.0, 2.1, T(4.8, 7.3, side * 2.6 - 0.3, 0, 0, -22), COAT)
		e("BackPaw" .. side, 2.6, 1.8, 2.5, T(5.6, 9.1, side * 2.6 - 0.3, 0, 0, -30), WHITE)
	end
	e("Tail", 4, 1.1, 1.1, T(7.4, 2.6, 0.2, 0, 0, 25), COAT)

	-- head: wide and round, rolled toward the viewer with a cheek-to-cheek grin
	local H = top * E.CFrame.new(-7.6 * S, 4.4 * S, -0.9 * S) * E.CFrame.Angles(math.rad(-8), math.rad(-10), math.rad(-10))
	local function h(x, y, z, rx, ry, rz)
		return H * E.CFrame.new(x * S, y * S, z * S) * E.CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
	end
	local head = e("Skull", 8.4, 5.2, 5.8, h(0, 0.6, 0), COAT)
	e("CheekL", 4.0, 3.6, 3.8, h(-2.6, -0.8, -1.25), COAT)
	e("CheekR", 4.0, 3.6, 3.8, h(2.6, -0.8, -1.25), COAT)
	e("Muzzle", 4.6, 2.6, 3.0, h(0, -0.5, -2.5), MUZ)
	e("Blaze", 0.9, 3.4, 0.6, h(0, 1.15, -2.85, -28, 0, 0), WHITE)
	e("Nose", 2.0, 1.2, 1.1, h(0, 0.3, -3.85), NOSE)
	dball(m, "NoseShine", 0.4 * S, h(-0.45, 0.6, -4.3), "#FFFFFF", E.Enum.Material.SmoothPlastic, false)
	e("Mouth", 5.0, 1.9, 1.2, h(0, -1.5, -3.15), MOUTH)
	e("SmileL", 1.2, 0.55, 0.6, h(-2.55, -0.95, -2.85, 0, 0, 35), MOUTH)
	e("SmileR", 1.2, 0.55, 0.6, h(2.55, -0.95, -2.85, 0, 0, -35), MOUTH)
	e("Chin", 3.0, 1.0, 2.2, h(0, -2.45, -2.4), MUZ)
	e("Tongue", 1.8, 0.7, 2.0, h(0.3, -2.0, -3.55, 25, 0, 0), TONGUE)
	-- happy squinty eyes (^ ^), set wide
	for _, side in { -1, 1 } do
		local x = side * 1.95
		e("EyeA" .. side, 0.95, 0.38, 0.4, h(x - 0.35, 1.25, -2.62, 0, 0, 32), NOSE)
		e("EyeB" .. side, 0.95, 0.38, 0.4, h(x + 0.35, 1.25, -2.62, 0, 0, -32), NOSE)
		-- folded rose ears, low on the sides
		e("Ear" .. side, 2.5, 1.15, 0.7, h(side * 4.15, 0.7, -1.0, 0, side * -30, side * -78), COAT_D)
	end

	-- a bone by his head
	local bone = T(-1.0, 1.4, -5.0) * yaw(0.4)
	dcyl(m, "Bone", 2.8 * S, 0.7 * S, bone, WHITE, E.Enum.Material.SmoothPlastic, false)
	for _, bx in { -1.4, 1.4 } do
		for _, bz in { -0.35, 0.35 } do
			dball(m, "BoneKnob", 0.85 * S, bone * E.CFrame.new(bx * S, 0, bz * S), WHITE, E.Enum.Material.SmoothPlastic, false)
		end
	end
	-- lights & label
	local glow = E.Instance.new("PointLight")
	glow.Range = 16
	glow.Brightness = 0.8
	glow.Color = hex("#FFD9E2")
	glow.Parent = belly
	billboard(head, "Label", "Big Biscuit 🐶", 8, 160, "#FFC83C", 260, 40)
	prompt(belly, "landmark:pibble", "Rub the belly", "Big Biscuit", 0.6, 16)
	-- "Say Brisket!" photo spot: a camera on a tripod facing his face (opens the share sheet)
	local cam = base * E.CFrame.new(-6, 0, -17) * E.CFrame.Angles(0, math.rad(200), 0)
	for i = 0, 2 do
		local a2 = i / 3 * math.pi * 2
		local foot = cam * E.CFrame.new(math.cos(a2) * 0.9, 0, math.sin(a2) * 0.9)
		local topP = cam * E.CFrame.new(0, 3.6, 0)
		local mid = foot.Position:Lerp(topP.Position, 0.5)
		local len = (topP.Position - foot.Position).Magnitude
		part(m, "TripodLeg", V(0.25, len, 0.25), E.CFrame.lookAt(mid, topP.Position) * E.CFrame.Angles(math.rad(90), 0, 0), "#3A2414", E.Enum.Material.Wood)
	end
	local body = part(m, "PhotoCamera", V(1.8, 1.2, 1.0), cam * E.CFrame.new(0, 4.2, 0), "#2A2B30", E.Enum.Material.SmoothPlastic)
	cyl(m, "Lens", 0.7, 0.8, cam * E.CFrame.new(0, 4.2, -0.75) * E.CFrame.Angles(0, math.rad(90), 0), "#111111", E.Enum.Material.Glass)
	local board = part(m, "PhotoSign", V(3.4, 1.2, 0.2), cam * E.CFrame.new(0, 2.2, 0.5), "#FFC83C", E.Enum.Material.SmoothPlastic)
	surfaceText(board, E.Enum.NormalId.Back, "📸 SAY BRISKET!", "#3A2414", nil)
	surfaceText(board, E.Enum.NormalId.Front, "📸 SAY BRISKET!", "#3A2414", nil)
	prompt(body, "ui:photo", "Snap & share", "Say Brisket! photo spot", 0, 10)
	-- bluebonnet bed around the plinth
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		if i == 5 or i == 6 then
			continue -- keep the plaque side clear
		end
		flowerPatch(m, (base * E.CFrame.new(math.cos(a) * 14.2, 0.4, math.sin(a) * 14.2)).Position, 1.4, 5, i % 2 == 0 and "bluebonnet" or "mix")
	end
	return m
end

-- ---------- per-plot dressing (outside every gameplay footprint) ----------
local function plotDecor(plotModel, cf, i)
	local m = model(plotModel, "Decor")
	streaming(m, "Atomic")
	local y = 0.6
	local function L(x, z)
		return cf * E.CFrame.new(x, y, z)
	end
	lantern(m, L(-30, 14))
	lantern(m, L(30, 14) * yaw(math.pi))
	local v = i % 3
	if v == 0 then
		kiddiePool(m, L(-18, -18))
	elseif v == 1 then
		cornhole(m, L(-18, -26), "#2F7BD8")
		cornhole(m, L(-18, -10) * yaw(math.pi), "#D93636")
	else
		picnicBlanket(m, L(-18, -17) * yaw(0.3))
	end
	flowerPatch(m, L(-26, -27).Position, 2.6, 9, i % 2 == 0 and "bluebonnet" or "mix")
	flowerPatch(m, L(25, -27).Position, 2.4, 8, "mix")
	hayBale(m, L(26, -17).Position - V(0, 0, 0), 0.4 + i)
	grassClump(m, L(29, -9).Position)
	grassClump(m, L(-29, -4).Position)
end
WorldBuilder.plotDecor = plotDecor

-- ---------- the big picture ----------
local function buildScenery(map, cfg, content)
	local scenery = model(map, "Scenery")
	local plots = map:FindFirstChild("Plots")
	for i = 1, cfg.MAX_PLOTS do
		local plot = plots and plots:FindFirstChild("Plot" .. i)
		if plot then
			local angle = (i - 1) / cfg.MAX_PLOTS * math.pi * 2
			local center = V(math.cos(angle) * WorldBuilder.PLOT_RADIUS, 0, math.sin(angle) * WorldBuilder.PLOT_RADIUS)
			plotDecor(plot, lookAt(center, V(0, 0, 0)), i)
		end
	end

	-- Horizon: a wide outer field, berms that hide the ground edge, a tree line beyond them
	-- and a mesa skyline. Persistent so the skyline never pops when streaming.
	local horizon = model(scenery, "Horizon")
	streaming(horizon, "Persistent")
	part(horizon, "OuterField", V(2600, 1, 2600), E.CFrame.new(0, -0.8, 0), PAL.grassFar, E.Enum.Material.Grass, { CastShadow = false })
	for side = 0, 3 do
		local rot = side * math.pi / 2
		local frame = yaw(rot)
		local t = -500
		while t <= 500 do
			local d = rr(105, 150)
			local p = frame * E.CFrame.new(t, -d * 0.33, -(455 + rr(0, 25)))
			part(horizon, "Berm", V(d, d, d), p, pick(PAL.berm), E.Enum.Material.Grass, { Shape = E.Enum.PartType.Ball, CastShadow = false })
			t += rr(50, 62)
		end
		-- tree line just past the berms
		t = -560
		while t <= 560 do
			local p = (frame * E.CFrame.new(t, 0, -(540 + rr(0, 70)))).Position
			if rnd() < 0.62 then
				liveOak(horizon, p, rr(1.7, 2.5), { far = true })
			else
				mesquite(horizon, p, rr(2.2, 3))
			end
			t += rr(36, 50)
		end
	end
	local mesas = { { 20, 1050 }, { 62, 1180 }, { 105, 980 }, { 150, 1120 }, { 196, 1040 }, { 238, 1200 }, { 300, 1000 }, { 335, 1150 } }
	for _, ms in ipairs(mesas) do
		mesa(horizon, polar(ms[1], ms[2]), rr(240, 360), rr(55, 90), rr(120, 170), math.rad(-ms[1] + 90))
	end

	-- Landmarks inside the map: ROCH water tower and a windmill, both visible from the hub.
	local landmarks = model(scenery, "Landmarks")
	streaming(landmarks, "Persistent")
	waterTower(landmarks, polar(122, 318), "ROCH")
	windmill(landmarks, polar(58, 300), math.rad(-30))

	-- Ranch fences around the property line (inside the berms)
	local fences = model(scenery, "PropertyFence")
	streaming(fences, "Atomic")
	local F = 405
	railFence(fences, V(-F, 0, F), V(F, 0, F), 30)
	railFence(fences, V(F, 0, -F), V(F, 0, F), 30)
	railFence(fences, V(-F, 0, -F), V(-F, 0, F), 30)
	railFence(fences, V(-F, 0, -F), V(-60, 0, -F), 30)
	railFence(fences, V(60, 0, -F), V(F, 0, -F), 30)

	-- Mid-ground trees between the plot ring and the edge
	local grove = model(scenery, "Grove")
	for k = 0, 17 do
		local a = k / 18 * 360 + 10
		if not (a > 250 and a < 290) then
			local p = polar(a, rr(262, 300))
			if k % 3 == 0 then
				mesquite(grove, p, rr(1.2, 1.6))
			else
				liveOak(grove, p, rr(1.1, 1.5))
			end
		end
	end
	for k = 0, 23 do
		local a = k / 24 * 360 + 7
		if not (a > 255 and a < 285) then
			local p = polar(a, rr(200, 340))
			flowerPatch(grove, p, rr(3, 6), 10, pick({ "bluebonnet", "bluebonnet", "mix", "susan" }))
			grassClump(grove, p + V(rr(-8, 8), 0, rr(-8, 8)), 1.3)
		end
	end

	-- Meadow: flat color patches (1 part each) break up the big lawn; some are bluebonnet
	-- carpets with a few flowers on top.
	local meadow = model(scenery, "Meadow")
	for k = 0, 39 do
		local a = rr(0, 360)
		local p = polar(a, rr(195, 430))
		local inCreek = p.Z < -215 and p.Z > -300 and math.abs(p.X) < 115
		if not inCreek and math.abs(p.X) < 440 and math.abs(p.Z) < 440 then
			if k % 4 == 0 then
				local d = rr(8, 14)
				dcyl(meadow, "BonnetCarpet", 0.1, d, at(p + V(0, 0.06, 0)) * upright(), "#5C7FE0", E.Enum.Material.Grass, false)
				flowerPatch(meadow, p, d * 0.4, 6, "bluebonnet")
			else
				dcyl(meadow, "MeadowPatch", 0.1, rr(18, 40), at(p + V(0, 0.05, 0)) * upright(), pick({ "#6DB843", "#8CCB55", "#A8C960", "#6DB843" }), E.Enum.Material.Grass, false)
				if k % 3 == 0 then
					grassClump(meadow, p + V(rr(-5, 5), 0, rr(-5, 5)), 1.4)
				end
			end
		end
	end

	-- Neighborhood: house backs with privacy fences beyond the tree ring, plus little scenes
	-- in the gaps between ranches.
	local hood = model(scenery, "Neighborhood")
	streaming(hood, "Atomic")
	local walls = { "#F2E6CF", "#D7E8F0", "#F6D7C3", "#E3EED2" }
	for k, a in ipairs({ 22.5, 112.5, 202.5, 337.5 }) do
		local pos = polar(a, 290)
		houseBack(hood, lookAt(pos, V(0, 0, 0)), walls[k], k % 2 == 0 and "#2F7BD8" or PAL.barnRed)
	end
	local function gap(a, r)
		local pos = polar(a, r)
		return lookAt(pos, V(0, 0, 0))
	end
	-- 67.5: tailgate party
	do
		local g = model(hood, "Tailgate")
		local cf = gap(67.5, 176)
		pickupTruck(g, cf * yaw(math.rad(100)), "#C8433A")
		lawnChair(g, cf * E.CFrame.new(-6, 0, -6) * yaw(0.5), "#1E9E4A")
		lawnChair(g, cf * E.CFrame.new(-2, 0, -8) * yaw(-0.2), "#E8590C")
		cooler(g, cf * E.CFrame.new(-4, 0, -4.5), "#2F7BD8")
		cornhole(g, cf * E.CFrame.new(6, 0, -12), "#2F7BD8")
		cornhole(g, cf * E.CFrame.new(6, 0, 2) * yaw(math.pi), "#D93636")
	end
	-- 112.5: the big oak with a tire swing and a picnic
	do
		local g = model(hood, "TireSwingOak")
		local cf = gap(112.5, 182)
		local oak = liveOak(g, cf.Position, 1.7, { shadow = true })
		leaves(oak:FindFirstChild("Canopy"))
		local branch = cf * E.CFrame.new(7, 0, 0)
		deco(g, "Rope", V(0.2, 7.5, 0.2), branch * E.CFrame.new(0, 9.6, 0), "#D9C4A8", E.Enum.Material.Fabric, false)
		dcyl(g, "Tire", 1.1, 3.6, branch * E.CFrame.new(0, 5, 0) * yaw(math.pi / 2), "#1C1A1F", E.Enum.Material.SmoothPlastic, false)
		picnicBlanket(g, cf * E.CFrame.new(-6, 0, -8) * yaw(-0.3))
	end
	-- haybales & wildflowers in the other gaps
	for _, a in ipairs({ 22.5, 157.5, 202.5, 247.5, 292.5, 337.5 }) do
		local g = model(hood, "Pasture")
		local cf = gap(a, 170)
		hayBale(g, (cf * E.CFrame.new(-4, 0, 3)).Position, a)
		hayBale(g, (cf * E.CFrame.new(1, 0, 6)).Position, a + 1)
		if a ~= 247.5 and a ~= 292.5 then
			hayBale(g, (cf * E.CFrame.new(-1.5, 4.4, 4.5)).Position, a + 2)
		end
		flowerPatch(g, (cf * E.CFrame.new(6, 0, -4)).Position, 4, 12, a % 45 == 22.5 and "bluebonnet" or "mix")
		grassClump(g, (cf * E.CFrame.new(-8, 0, -6)).Position, 1.2)
		grassClump(g, (cf * E.CFrame.new(9, 0, 8)).Position, 1.1)
	end
	do -- backyard kiddie pool + lawn chairs at 337.5 house
		local cf = lookAt(polar(337.5, 290), V(0, 0, 0))
		kiddiePool(hood, cf * E.CFrame.new(-10, 0, -12))
		lawnChair(hood, cf * E.CFrame.new(-2, 0, -12) * yaw(1.2), "#FFC83C")
		local cf2 = lookAt(polar(112.5, 290), V(0, 0, 0))
		cooler(hood, cf2 * E.CFrame.new(8, 0, -10), "#1E9E4A")
		lawnChair(hood, cf2 * E.CFrame.new(4, 0, -12) * yaw(0.4), "#2F7BD8")
	end

	-- Hub dressing: string lights between the lamp posts, hay-bale seats by the stage,
	-- smoke wisps from the pits, fireflies at dusk.
	local hubDecor = model(scenery, "HubDecor")
	for li = 0, 7 do
		local a0 = li / 8 * math.pi * 2 + math.pi / 8
		local a1 = (li + 1) / 8 * math.pi * 2 + math.pi / 8
		local p0 = V(math.cos(a0) * 52, 10.1, math.sin(a0) * 52)
		local p1 = V(math.cos(a1) * 52, 10.1, math.sin(a1) * 52)
		stringLights(hubDecor, p0, p1, 7, 1.6)
	end
	for _, o in ipairs({ { -24, 30 }, { -28, 36 }, { 32, 27 } }) do
		hayBale(hubDecor, V(o[1], 0.4, o[2]), o[1] * 0.1)
	end
	local hubMap = map:FindFirstChild("Hub")
	if hubMap then
		local ks = hubMap:FindFirstChild("KingSmoker")
		local ch = ks and ks:FindFirstChild("Chimney")
		if ch then
			smokeWisp(ch)
		end
		local ug = hubMap:FindFirstChild("UncGrill")
		if ug then
			smokeWisp(ug)
		end
	end
	fireflies(hubDecor, E.CFrame.new(0, 5, 0), V(100, 8, 100))
	fireflies(hubDecor, E.CFrame.new(0, 4, -262), V(160, 6, 30))
	fireflies(hubDecor, E.CFrame.new(0, 5, 230), V(200, 8, 60))
	-- The landmark itself lives in the hub so it's on the spawn sightline.
	WorldBuilder.pibble(hubDecor, E.CFrame.new(0, 0.4, 14), content)

	-- Creek dressing: a footbridge, cattails, more rocks, lily pads.
	local creekDecor = model(scenery, "CreekDecor")
	streaming(creekDecor, "Atomic")
	local z = -260
	local bx = 42
	part(creekDecor, "BridgeDeck", V(9, 0.6, 26), E.CFrame.new(bx, 1.2, z), PAL.wood, E.Enum.Material.WoodPlanks)
	part(creekDecor, "BridgeRampN", V(9, 0.6, 6), E.CFrame.new(bx, 0.6, z + 15.5) * E.CFrame.Angles(math.rad(-10), 0, 0), PAL.wood, E.Enum.Material.WoodPlanks)
	part(creekDecor, "BridgeRampS", V(9, 0.6, 6), E.CFrame.new(bx, 0.6, z - 15.5) * E.CFrame.Angles(math.rad(10), 0, 0), PAL.wood, E.Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -4.3, 4.3 }) do
		deco(creekDecor, "Rail", V(0.4, 0.4, 26), E.CFrame.new(bx + sx, 4.2, z), "#8B5A2B", E.Enum.Material.Wood, false)
		for _, pz in ipairs({ -12, 0, 12 }) do
			deco(creekDecor, "RailPost", V(0.5, 3, 0.5), E.CFrame.new(bx + sx, 2.8, z + pz), "#8B5A2B", E.Enum.Material.Wood, false)
		end
	end
	for k = 1, 16 do
		local x = -90 + k * 11 + rr(-3, 3)
		local zz = z + ((k % 2 == 0) and 9.8 or -9.8) + rr(-0.6, 0.6)
		if math.abs(x - bx) > 7 then
			deco(creekDecor, "CattailStem", V(0.2, 4.2, 0.2), E.CFrame.new(x, 2.1, zz) * E.CFrame.Angles(rr(-0.15, 0.15), 0, rr(-0.15, 0.15)), "#6E8F3A", E.Enum.Material.Grass, false)
			deco(creekDecor, "Cattail", V(0.5, 1.3, 0.5), E.CFrame.new(x, 3.9, zz), "#6B4226", E.Enum.Material.Fabric, false)
			deco(creekDecor, "CattailLeaf", V(0.15, 3.2, 0.5), E.CFrame.new(x + 0.4, 1.6, zz) * E.CFrame.Angles(0, 0.6, 0.3), "#7FA650", E.Enum.Material.Grass, false)
		end
	end
	for k = 1, 8 do
		dball(creekDecor, "Rock", rr(1.8, 3.6), E.CFrame.new(-95 + k * 23, 0.3, z + rr(-8, 8)), pick({ "#8C8C8C", "#9C9284", "#7F8C8D" }), E.Enum.Material.Slate, false)
	end
	for k = 1, 5 do
		dcyl(creekDecor, "LilyPad", 0.1, rr(1.6, 2.4), E.CFrame.new(-60 + k * 22, 0.45, z + rr(-5, 5)) * upright(), "#4FA346", E.Enum.Material.Grass, false)
	end
	mesquite(creekDecor, V(-62, 0, z - 16), 1.3)
	liveOak(creekDecor, V(70, 0, z - 18), 1.3)

	-- Ambient critters (moved around by the Ambient client script; purely cosmetic).
	local critters = folder(scenery, "Critters")
	local spots = {
		{ "armadillo", polar(45, 186), 16, 3 },
		{ "roadrunner", polar(200, 192), 24, 9 },
		{ "hornedtoad", V(30, 0, -244), 10, 2 },
		{ "possum", polar(150, 200), 14, 3 },
		{ "armadillo", polar(318, 195), 14, 3 },
	}
	local defs = {}
	for _, d in ipairs(cfg.Critters or {}) do
		defs[d.id] = d
	end
	for _, sp in ipairs(spots) do
		local def = defs[sp[1]]
		if def then
			local cm = WorldBuilder.critter(E, critters, def, E.CFrame.new(sp[2] + V(0, 0.9 * (def.scale or 1), 0)))
			for _, d in ipairs(cm:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
					d:Destroy()
				end
			end
			cm.Name = "Wild_" .. def.id
			cm:SetAttribute("Range", sp[3])
			cm:SetAttribute("Speed", sp[4])
		end
	end

	-- Clouds (Terrain child) when building inside a real place.
	pcall(function()
		local terrain = map.Parent and map.Parent:FindFirstChildOfClass("Terrain")
		if terrain and not terrain:FindFirstChildOfClass("Clouds") then
			local clouds = E.Instance.new("Clouds")
			clouds.Cover = 0.55
			clouds.Density = 0.55
			clouds.Color = hex("#FFF6EC")
			clouds.Parent = terrain
		end
	end)
	return scenery
end
WorldBuilder.buildScenery = buildScenery

-- Build everything under `parent` (Workspace). Returns the Map model.
function WorldBuilder.build(env, parent, cfg, content)
	E = env
	local map = model(parent, "Map")
	part(map, "Ground", V(900, 2, 900), E.CFrame.new(0, -1, 0), "#79C84F", E.Enum.Material.Grass)
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
	buildScenery(map, cfg, content)
	return map
end

return WorldBuilder
