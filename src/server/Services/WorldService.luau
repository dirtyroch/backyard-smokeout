--!strict
-- WorldService — the physical ranch: plots, smokers, meat visuals, critter customers, smoke signals.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local WorldBuilder = require(Shared.WorldBuilder)
local CookLogic = require(Shared.Logic.CookLogic)
local Rarity = require(Shared.Logic.Rarity)

local WorldService = {}
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
WorldService.ENV = ENV

local plotOwner: { [number]: Player } = {}
local playerPlot: { [Player]: number } = {}
local customerModels: { [Player]: { [number]: Model } } = {}
local map: any = nil

function WorldService.map(): any
	return map
end

function WorldService.plotModel(player: Player): any
	local i = playerPlot[player]
	if not i then
		return nil
	end
	return map.Plots:FindFirstChild("Plot" .. i) :: Model?
end

function WorldService.ownerOfPlot(i: number): Player?
	return plotOwner[i]
end

function WorldService.plotIndexOf(player: Player): number?
	return playerPlot[player]
end

local function setOwnerSign(i: number, player: Player?)
	local plot = map.Plots:FindFirstChild("Plot" .. i)
	if not plot then
		return
	end
	local label = plot.Sign.Board:FindFirstChild("SignGui") and plot.Sign.Board.SignGui:FindFirstChild("OwnerText")
	if label then
		label.Text = player and (player.DisplayName .. "'s Ranch") or "Open Ranch"
	end
	plot:SetAttribute("OwnerUserId", player and player.UserId or 0)
end

local function teleportHome(player: Player)
	local plot = WorldService.plotModel(player)
	local char = player.Character
	if not plot or not char then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local pad = plot:FindFirstChild("SpawnPad") :: BasePart?
	if hrp and pad then
		char:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
	end
end
WorldService.teleportHome = teleportHome

function WorldService.assignPlot(player: Player): number?
	for i = 1, Config.MAX_PLOTS do
		if not plotOwner[i] then
			plotOwner[i] = player
			playerPlot[player] = i
			customerModels[player] = {}
			setOwnerSign(i, player)
			player:SetAttribute("Plot", i)
			player.CharacterAdded:Connect(function()
				task.wait(0.2)
				teleportHome(player)
				ctx.Cosmetics.apply(player)
			end)
			if player.Character then
				task.defer(teleportHome, player)
			end
			return i
		end
	end
	return nil
end

function WorldService.releasePlot(player: Player)
	local i = playerPlot[player]
	if not i then
		return
	end
	for _, m in pairs(customerModels[player] or {}) do
		m:Destroy()
	end
	customerModels[player] = nil
	plotOwner[i] = nil
	playerPlot[player] = nil
	setOwnerSign(i, nil)
	-- clear visuals
	local plot = map.Plots:FindFirstChild("Plot" .. i)
	if plot then
		for _, s in ipairs(plot.Smokers:GetChildren()) do
			local spot = s:FindFirstChild("MeatSpot")
			if spot then
				spot:ClearAllChildren()
			end
			s.Chimney.Smoke.Enabled = false
			s.Barrel.SlotGui.Text.Text = ""
		end
		for _, g in ipairs(plot.Grill:GetChildren()) do
			if g:GetAttribute("Slot") then
				for _, c in ipairs(g:GetChildren()) do
					if c.Name == "Meat" then
						c:Destroy()
					end
				end
				g.SlotGui.Text.Text = ""
			end
		end
		plot.PassWindow.Plates:ClearAllChildren()
		plot.PassWindow.Counter.Prompt.Enabled = false
		for _, b in ipairs(plot.VIPLights:GetChildren()) do
			if b:IsA("BasePart") then
				b.Transparency = 1
			end
		end
	end
end

local function colorOf(h: string): Color3
	return Color3.fromHex(h)
end
local LOCKED_COLOR = Color3.fromHex("#1C1A1F")

-- Repaint smokers & meat for one player's plot.
function WorldService.refreshStations(player: Player)
	local plot = WorldService.plotModel(player)
	local data = ctx.Game.dataOf(player)
	if not plot or not data then
		return
	end
	local t = workspace:GetServerTimeNow()
	local smokerCount = ctx.Game.slotCount(player, data, "smoker")
	local grillCount = ctx.Game.slotCount(player, data, "grill")
	local pitDef = Config.PitLevels[data.pitLevel]
	local skinId = data.equipped.skin
	local skin = skinId and Config.Cosmetics[skinId] or nil
	local smokeId = data.equipped.smoke
	local smokeDef = smokeId and Config.Cosmetics[smokeId] or nil
	local bodyColor = skin and colorOf(skin.color) or colorOf(pitDef.color)
	local material = (skin and skin.neon) and Enum.Material.Neon or ((skin and skin.gold) and Enum.Material.Foil or Enum.Material.Metal)

	for i = 1, #WorldBuilder.SMOKER_X do
		local key = "s" .. i
		local s = plot.Smokers:FindFirstChild(key) :: Model?
		if s then
			local unlocked = i <= smokerCount
			local barrel = s:FindFirstChild("Barrel") :: BasePart
			local spot = s:FindFirstChild("MeatSpot") :: BasePart
			local chimney = s:FindFirstChild("Chimney") :: BasePart
			local smoke = chimney:FindFirstChild("Smoke") :: Smoke
			local label = (barrel:FindFirstChild("SlotGui") :: BillboardGui):FindFirstChild("Text") :: TextLabel
			-- Locked smokers read as a dark silhouette with a padlock sign (no see-through ghosts).
			for _, p in ipairs(s:GetChildren()) do
				if p:IsA("BasePart") and p.Name ~= "MeatSpot" and p.Name ~= "LockSign" then
					p.Transparency = 0
					local base = p:GetAttribute("BaseColor")
					p.Color = unlocked and (typeof(base) == "string" and colorOf(base) or p.Color) or LOCKED_COLOR
				end
			end
			local lockSign = s:FindFirstChild("LockSign") :: BasePart?
			if lockSign then
				lockSign.Transparency = unlocked and 1 or 0
				for _, lg in ipairs(lockSign:GetChildren()) do
					if lg:IsA("SurfaceGui") then
						lg.Enabled = not unlocked
					end
				end
			end
			barrel.Color = unlocked and bodyColor or LOCKED_COLOR
			barrel.Material = unlocked and material or Enum.Material.SmoothPlastic
			spot:ClearAllChildren()
			local cook = data.stations[key]
			if unlocked and type(cook) == "table" then
				local meat = Config.Meats[cook.meat]
				local done = CookLogic.isDone(cook)
				local rar = done and Rarity.get(Config.Rarities, cook.rarity) or nil
				WorldBuilder.meat(ENV, spot, meat, rar, spot.CFrame, CookLogic.fraction(cook))
				smoke.Enabled = not done
				smoke.Color = smokeDef and colorOf(smokeDef.color) or Color3.fromRGB(221, 221, 221)
				label.Text = meat.icon .. " " .. meat.name .. (done and " ✅" or "")
			else
				smoke.Enabled = false
				label.Text = unlocked and "Empty smoker" or "🔒 Locked"
			end
			s:SetAttribute("Unlocked", unlocked)
		end
	end

	local grill = plot.Grill
	local anyGrill = false
	for i = 1, #WorldBuilder.GRILL_X do
		local key = "g" .. i
		local g = grill:FindFirstChild(key) :: BasePart?
		if g then
			local unlocked = i <= grillCount
			g.Transparency = 0
			g.Color = unlocked and colorOf("#333333") or LOCKED_COLOR
			for _, c in ipairs(g:GetChildren()) do
				if c.Name == "Meat" then
					c:Destroy()
				end
			end
			local cook = data.stations[key]
			local label = (g:FindFirstChild("SlotGui") :: BillboardGui):FindFirstChild("Text") :: TextLabel
			if unlocked and type(cook) == "table" then
				anyGrill = true
				local meat = Config.Meats[cook.meat]
				local mp = WorldBuilder.meat(ENV, g, meat, nil, g.CFrame * CFrame.new(0, 0.1, 0), CookLogic.fraction(cook))
				if cook.burnt then
					mp.Color = Color3.fromRGB(20, 20, 20)
				end
				label.Text = meat.icon .. (cook.burnt and " burnt" or (CookLogic.isDone(cook) and " ✅" or ""))
			else
				label.Text = unlocked and "" or "🔒"
			end
		end
	end
	local gs = (grill:FindFirstChild("Top") :: BasePart):FindFirstChild("Smoke") :: Smoke
	gs.Enabled = anyGrill

	-- pass window plates (shows up to 4)
	local plates = plot.PassWindow.Plates
	plates:ClearAllChildren()
	local counter = plot.PassWindow.Counter :: BasePart
	for pi = 1, math.min(4, #data.cooler) do
		local plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Shape = Enum.PartType.Cylinder
		plate.Size = Vector3.new(0.2, 1.6, 1.6)
		plate.Anchored = true
		plate.CanCollide = false
		plate.Color = Color3.fromRGB(245, 245, 245)
		plate.CFrame = counter.CFrame * CFrame.new(-3 + (pi - 1) * 2, 1.95, 0) * CFrame.Angles(0, 0, math.pi / 2)
		plate.Parent = plates
		local meat = Config.Meats[data.cooler[pi].m]
		if meat then
			local m = WorldBuilder.meat(ENV, plates, meat, nil, counter.CFrame * CFrame.new(-3 + (pi - 1) * 2, 2.05, 0), 1)
			m.Size = m.Size * 0.45
		end
	end

	-- VIP Patio
	local vip = ctx.Game.hasPass(player, "VIPPatio") or data.equipped.patio == "vip_lights"
	for _, b in ipairs(plot.VIPLights:GetChildren()) do
		if b:IsA("BasePart") then
			b.Transparency = vip and 0 or 1
			local sg = b:FindFirstChild("SignGui")
			if sg then
				(sg :: any).Text.TextTransparency = vip and 0 or 1
			end
		end
	end
	ctx.Social.refreshPassWindow(player)
	local _ = t
end

-- ===== critter customers =====
local function moveModel(m: Model, from: CFrame, to: CFrame, seconds: number)
	task.spawn(function()
		local t0 = os.clock()
		while m.Parent and os.clock() - t0 < seconds do
			local a = (os.clock() - t0) / seconds
			local cf = from:Lerp(to, a)
			m:PivotTo(cf * CFrame.new(0, math.abs(math.sin(a * math.pi * 6)) * 0.4, 0))
			RunService.Heartbeat:Wait()
		end
		if m.Parent then
			m:PivotTo(to)
		end
	end)
end

function WorldService.spawnCustomer(player: Player, customer: any, critter: any)
	local plot = WorldService.plotModel(player)
	if not plot then
		return
	end
	local tbl = plot.Tables:FindFirstChild("t" .. customer.spot)
	if not tbl then
		return
	end
	local seat = tbl.Seat :: BasePart
	local entrance = (plot.SpawnPad :: BasePart).CFrame * CFrame.new(0, -1, -14)
	local folder = plot:FindFirstChild("Customers") or Instance.new("Folder")
	folder.Name = "Customers"
	folder.Parent = plot
	local m, head, body = WorldBuilder.critter(ENV, folder, critter, CFrame.new())
	m.Name = "Customer" .. customer.id
	m:SetAttribute("CustomerId", customer.id)
	m:SetAttribute("OwnerUserId", player.UserId)
	local seatCf = CFrame.lookAt(seat.Position, seat.Position + (seat.CFrame.LookVector)) * CFrame.Angles(0, math.pi, 0)
	m:PivotTo(entrance)
	moveModel(m, entrance, seatCf, 2.2)

	local orderText
	if customer.order == "any" then
		orderText = critter.name .. ": Anything's fine!"
	else
		local meat = Config.Meats[customer.order]
		orderText = critter.name .. ": " .. meat.icon .. " " .. meat.name .. " please!"
	end
	WorldBuilder.billboard(head, "Order", orderText, 2.4, 70, "#FFFFFF", 260, 34, { 10, 1.5 })
	local serve = WorldBuilder.prompt(body, "serve", "Serve", critter.name, 0, 10)
	serve:SetAttribute("CustomerId", customer.id)
	serve:SetAttribute("OwnerUserId", player.UserId)
	if critter.bellyRub then
		local rub = WorldBuilder.prompt(head, "bellyrub", "Rub belly", "Belly Rub Pup", 0.6, 8)
		rub:SetAttribute("CustomerId", customer.id)
		rub:SetAttribute("OwnerUserId", player.UserId)
		rub.UIOffset = Vector2.new(0, 60)
	end
	if customer.muddy then
		for k = 1, 4 do
			local spotPart = Instance.new("Part")
			spotPart.Name = "Mud"
			spotPart.Anchored = true
			spotPart.CanCollide = false
			spotPart.Size = Vector3.new(0.6, 0.15, 0.6)
			spotPart.Color = Color3.fromRGB(92, 64, 40)
			spotPart.CFrame = body.CFrame * CFrame.new(-0.5 + (k % 2), 0.72, -0.8 + k * 0.4)
			spotPart.Parent = m
		end
		local wash = WorldBuilder.prompt(head, "wash", "Wash the pup", "Suds Saturday", 1, 8)
		wash:SetAttribute("CustomerId", customer.id)
		wash:SetAttribute("OwnerUserId", player.UserId)
		wash.UIOffset = Vector2.new(0, 120)
	end
	-- re-anchor parts after pivot (WorldBuilder parts are anchored already)
	customerModels[player][customer.id] = m
end

function WorldService.removeCustomer(player: Player, customer: any)
	local list = customerModels[player]
	local m = list and list[customer.id]
	if m then
		list[customer.id] = nil
		local plot = WorldService.plotModel(player)
		if plot then
			local from = m:GetPivot()
			local to = (plot.SpawnPad :: BasePart).CFrame * CFrame.new(0, -1, -16)
			moveModel(m, from, to, 1.6)
			task.delay(1.7, function()
				m:Destroy()
			end)
		else
			m:Destroy()
		end
	end
end

function WorldService.findCustomer(player: Player, id: number): any?
	local r = ctx.Game.runtime[player]
	if not r then
		return nil
	end
	for _, c in ipairs(r.customers) do
		if c.id == id then
			return c
		end
	end
	return nil
end

function WorldService.smokeSignal(player: Player, text: string, color: string)
	local plot = WorldService.plotModel(player)
	if not plot then
		return
	end
	local sig = plot.SmokeSignal :: BasePart
	local smoke = sig:FindFirstChild("Signal") :: Smoke
	local gui = sig:FindFirstChild("SignalGui") :: BillboardGui
	local data = ctx.Game.dataOf(player)
	local smokeDef = data and data.equipped.smoke and Config.Cosmetics[data.equipped.smoke]
	smoke.Color = smokeDef and colorOf(smokeDef.color) or colorOf(color)
	smoke.Enabled = true
	gui.Enabled = true
	local label = gui:FindFirstChild("Text") :: TextLabel
	-- Display names are already moderated by Roblox; everything else here is fixed game text.
	label.Text = "💨 " .. player.DisplayName .. ": " .. string.upper(text) .. "!"
	label.TextColor3 = colorOf(color)
	task.delay(10, function()
		if sig.Parent then
			smoke.Enabled = false
			gui.Enabled = false
		end
	end)
end

function WorldService.effect(player: Player, kind: string, payload: any)
	local plot = WorldService.plotModel(player)
	if not plot then
		return
	end
	if kind == "smell" then
		local top = plot.Grill.Top :: BasePart
		local puff = Instance.new("Smoke")
		puff.Color = Color3.fromRGB(40, 40, 40)
		puff.Size = 6
		puff.Opacity = 0.5
		puff.RiseVelocity = 6
		puff.Parent = top
		task.delay(4, function()
			puff:Destroy()
		end)
		-- every critter does the scuba wave
		for _, m in pairs(customerModels[player] or {}) do
			local head = m:FindFirstChild("Head")
			if head then
				local b = WorldBuilder.billboard(head, "Scuba", "🤿👋", 4.5, 60, "#FFFFFF", 80, 40)
				task.delay(3, function()
					b:Destroy()
				end)
			end
		end
	elseif kind == "bellyrub" or kind == "wash" or kind == "clap" then
		local m = customerModels[player] and customerModels[player][payload.id]
		if not m then
			return
		end
		local head = m:FindFirstChild("Head")
		if kind == "bellyrub" then
			local base = m:GetPivot()
			m:PivotTo(base * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi))
			task.delay(2, function()
				if m.Parent then
					m:PivotTo(base)
				end
			end)
		elseif kind == "wash" then
			for _, c in ipairs(m:GetChildren()) do
				if c.Name == "Mud" then
					c:Destroy()
				end
			end
			local body = m:FindFirstChild("Body")
			if body then
				local sp = Instance.new("Sparkles")
				sp.SparkleColor = Color3.fromRGB(180, 230, 255)
				sp.Parent = body
				task.delay(3, function()
					sp:Destroy()
				end)
			end
		end
		if head then
			local text = kind == "bellyrub" and "♥ ♥ ♥" or (kind == "wash" and "✨ squeaky clean ✨" or "👏👏👏")
			local b = WorldBuilder.billboard(head, "Fx", text, 5, 60, "#FF8FB1", 200, 40)
			task.delay(2.5, function()
				b:Destroy()
			end)
		end
	end
end

-- Slowly darken meat as it cooks (cheap: every 5 seconds).
local function doneLoop()
	while true do
		task.wait(5)
		for player in pairs(playerPlot) do
			WorldService.refreshStations(player)
		end
	end
end

function WorldService.init(c: any)
	ctx = c
	WorldBuilder.setEnv(ENV)
	local existing = workspace:FindFirstChild("Map")
	if existing then
		map = existing :: Model
	else
		map = WorldBuilder.build(ENV, workspace, Config, Content)
	end
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
end

function WorldService.start()
	task.spawn(doneLoop)
	Players.PlayerRemoving:Connect(function(player)
		customerModels[player] = customerModels[player]
	end)
end

return WorldService
