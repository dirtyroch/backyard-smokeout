--!strict
-- Feedback: toasts, announcements, rare-reveal cinematic, flip popups, floating coins.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local HudLayout = require(Shared.Logic.HudLayout)
local T = UI.Theme

local Fx = {}
local gui: GuiObject = nil :: any
local toastHolder: Frame = nil :: any
local announceHolder: Frame = nil :: any

local KIND_COLOR = {
	good = T.green,
	bad = T.red,
	warn = Color3.fromHex("#E0A030"),
	ready = T.gold,
	info = Color3.fromHex("#2C4A6E"),
}

local function placeNotice(guiObject: GuiObject, b: HudLayout.Box)
	local w = math.max(1, UI.viewport.X)
	local h = math.max(1, UI.viewport.Y)
	guiObject.AnchorPoint = Vector2.new(0, 0)
	if b.w <= 0 or b.h <= 0 then
		guiObject.Visible = false
		return
	end
	guiObject.Visible = true
	guiObject.Position = UDim2.fromScale(b.x / w, b.y / h)
	guiObject.Size = UDim2.fromScale(b.w / w, b.h / h)
end

-- Follows the HUD. The Turkey Day note and the potluck call-out sit under the
-- guide and the goals bar instead of on top of them.
function Fx.applyLayout()
	if not toastHolder or not announceHolder then
		return
	end
	local Hud = require(script.Parent.Hud)
	local n = HudLayout.notices(UI.viewport.X, UI.viewport.Y, UI.insets, Hud.layoutOptions())
	placeNotice(announceHolder, n.announce)
	placeNotice(toastHolder, n.toast)
end

function Fx.mount(screen: GuiObject)
	gui = screen
	toastHolder = UI.frame({ Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(420, 72), Parent = screen, ZIndex = 50 })
	UI.list(toastHolder, nil, 6, Enum.HorizontalAlignment.Center)
	announceHolder = UI.frame({ Name = "Announce", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(520, 34), Parent = screen, ZIndex = 50 })
	UI.list(announceHolder, nil, 4, Enum.HorizontalAlignment.Center)
	UI.onLayout = Fx.applyLayout
	Fx.applyLayout()
end

function Fx.toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = KIND_COLOR[kind or "info"] or KIND_COLOR.info
	local f = UI.frame({ BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 51, Parent = toastHolder })
	UI.corner(f, 10)
	UI.stroke(f)
	UI.pad(f, 8)
	local inkOn = UI.contrast(T.text, color) < 4.5
	UI.label(text, { TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextSize = 18, TextColor3 = if inkOn then T.ink else T.text, ZIndex = 52, Parent = f })
	local kids = 0
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			kids += 1
		end
	end
	if kids > 4 then
		for _, c in ipairs(toastHolder:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
				break
			end
		end
	end
	task.delay(4.5, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

function Fx.announce(text: string, color: string?)
	if not announceHolder then
		return
	end
	local f = UI.frame({ BackgroundColor3 = Color3.fromHex("#12263F"), BackgroundTransparency = 0.12, Size = UDim2.new(1, 0, 0, 34), ZIndex = 51, Parent = announceHolder })
	UI.corner(f, 17)
	UI.label(text, { TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromHex(color or "#FFC83C"), TextSize = 18, Size = UDim2.new(1, 0, 1, 0), ZIndex = 52, Parent = f })
	for i, c in ipairs(announceHolder:GetChildren()) do
		if c:IsA("Frame") and i < #announceHolder:GetChildren() - 2 then
			c:Destroy()
		end
	end
	task.delay(6, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

-- Big Bertha's bell swings (client-side only) whenever someone rings it.
local function bertha(): Model?
	local m = workspace:FindFirstChild("BigBertha", true)
	return if m and m:IsA("Model") then m else nil
end

function Fx.ringBell()
	Sfx.play("bell", 0.95 + math.random() * 0.1, 0.4)
	local m = bertha()
	local bell = m and m:FindFirstChild("DinnerBell")
	if not bell or not bell:IsA("Model") then
		return
	end
	local home = bell:GetPivot()
	task.spawn(function()
		for i = 1, 8 do
			bell:PivotTo(home * CFrame.Angles(0, 0, math.rad(22) * math.sin(i * 1.4) * (1 - i / 9)))
			task.wait(0.07)
		end
		bell:PivotTo(home)
	end)
end

-- Dinner Bell pile-on: the bell swings, Big Bertha's chimney blows a huge puff, confetti pops,
-- and a big banner shows. Built for clips, so the payoff lands inside 2 seconds.
function Fx.dinnerBell()
	Fx.pop(Content.Slang.dinnerBell, Color3.fromHex("#FFC83C"), 64)
	Fx.ringBell()
	task.delay(0.35, function()
		Sfx.play("fanfare")
	end)
	local m = bertha()
	if not m then
		return
	end
	local chimney = m:FindFirstChild("Chimney", true)
	if chimney and chimney:IsA("BasePart") then
		local puff = Instance.new("Smoke")
		puff.Color = Color3.fromRGB(235, 235, 235)
		puff.Size = 14
		puff.Opacity = 0.6
		puff.RiseVelocity = 14
		puff.Parent = chimney
		task.delay(4, function()
			puff:Destroy()
		end)
	end
	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
	burst.Transparency = 1
	burst.Size = Vector3.new(1, 1, 1)
	burst.CFrame = m:GetPivot() * CFrame.new(0, 14, 0)
	burst.Parent = workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#FFC83C")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#FF7A3D")), ColorSequenceKeypoint.new(1, Color3.fromHex("#5AD2FF")) })
	pe.Speed = NumberRange.new(18, 30)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Lifetime = NumberRange.new(1.5, 2.5)
	pe.Acceleration = Vector3.new(0, -25, 0)
	pe.Size = NumberSequence.new(0.6)
	pe.Rate = 0
	pe.Parent = burst
	pe:Emit(160)
	task.delay(3, function()
		burst:Destroy()
	end)
end

-- Big center-screen pop text.
function Fx.pop(text: string, color: Color3, size: number?)
	local l = UI.label(text, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0, 700, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = color,
		TextSize = size or 46,
		TextStrokeTransparency = 0,
		ZIndex = 60,
		Parent = gui,
	})
	local tw = TweenService:Create(l, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.32), TextTransparency = 1, TextStrokeTransparency = 1 })
	tw:Play()
	task.delay(1.5, function()
		l:Destroy()
	end)
end

function Fx.coins(amount: number)
	Sfx.play("register", 0.95 + math.random() * 0.1, 0.12)
	if not gui then
		return
	end
	local start = UDim2.new(0.5, 0, 0, 78)
	local finish = UDim2.new(0.5, 0, 0, 28)
	local pill = gui:FindFirstChild("CoinPill", true)
	if pill and pill:IsA("GuiObject") then
		local abs = pill.AbsolutePosition
		local size = pill.AbsoluteSize
		local origin = gui.AbsolutePosition
		local x = abs.X - origin.X + size.X * 0.5
		local y = abs.Y - origin.Y + size.Y
		start = UDim2.fromOffset(x, y)
		finish = UDim2.fromOffset(x, y - 46)
	end
	local row = UI.frame({
		Name = "CoinPop",
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = start,
		Size = UDim2.fromOffset(168, 40),
		ZIndex = 62,
		Parent = gui,
	})
	UI.corner(row, 20)
	UI.stroke(row, T.gold, 2)
	local list = UI.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local coin = UI.coin(row, 24)
	coin.ZIndex = 63
	UI.label("+" .. UI.fmt(amount), {
		Size = UDim2.fromOffset(96, 28),
		TextSize = 22,
		TextColor3 = T.gold,
		Font = T.bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 63,
		Parent = row,
	})
	local tw = TweenService:Create(row, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = finish,
		BackgroundTransparency = 1,
	})
	tw:Play()
	task.delay(0.95, function()
		if row.Parent then
			row:Destroy()
		end
	end)
end

local function shake(seconds: number, power: number)
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = os.clock() - t0
		if a > seconds then
			conn:Disconnect()
			return
		end
		local p = power * (1 - a / seconds)
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, 0)
	end)
end
Fx.shake = shake

-- Rare reveal: a short orbit around your smoker, then a big title card.
function Fx.reveal(meatId: string, rarityId: string, aura: number, smokerPos: Vector3?)
	local meat = Config.Meats[meatId]
	local rar
	for _, r in ipairs(Config.Rarities) do
		if r.id == rarityId then
			rar = r
		end
	end
	if not meat or not rar then
		return
	end
	local color = Color3.fromHex(rar.color)
	Sfx.play("fanfare", rarityId == "meteorite" and 0.85 or 1)
	local cam = workspace.CurrentCamera
	if smokerPos then
		local oldType = cam.CameraType
		cam.CameraType = Enum.CameraType.Scriptable
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = os.clock() - t0
			if a > 2.2 then
				conn:Disconnect()
				cam.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
				return
			end
			local ang = a * 1.4
			local pos = smokerPos + Vector3.new(math.cos(ang) * 14, 7 - a, math.sin(ang) * 14)
			cam.CFrame = CFrame.lookAt(pos, smokerPos + Vector3.new(0, 4, 0))
		end)
	end
	local overlay = UI.frame({ BackgroundColor3 = color, BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 55, Parent = gui })
	local card = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 220), BackgroundColor3 = Color3.fromHex("#12263F"), ZIndex = 56, Parent = overlay })
	UI.corner(card, 20)
	UI.stroke(card, color, 4)
	UI.label(string.upper(rar.name) .. "!", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 60), TextSize = 50, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57, Parent = card })
	UI.label(meat.icon .. " " .. meat.name, { Position = UDim2.new(0, 0, 0, 96), Size = UDim2.new(1, 0, 0, 36), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57, Parent = card })
	local sub = string.format("Worth x%s. Your smoke signal is up for the whole server!", tostring(rar.mult))
	if aura > 0 then
		sub = (string.gsub(Content.Slang.perfectFlip, "1000", tostring(aura))) .. "  •  " .. sub
	end
	UI.label(sub, { Position = UDim2.new(0, 20, 0, 146), Size = UDim2.new(1, -40, 0, 50), TextSize = 18, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 57, Parent = card })
	card.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 520, 0, 220) }):Play()
	if rarityId == "texas" then
		-- Texas-size: the cut is so big it crushes the picnic table (camera shake + crunch text)
		task.delay(0.4, function()
			shake(0.8, 1.2)
			Sfx.play("crunch")
			Fx.pop("CRUNCH! It broke the table!", Color3.fromHex("#FF5A36"), 38)
		end)
	elseif rarityId == "meteorite" then
		task.delay(0.3, function()
			shake(1.2, 2)
		end)
	end
	task.delay(3.2, function()
		TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.4)
		overlay:Destroy()
	end)
end

-- Spatula flip: the clank always plays; a perfect flip adds a big sear that climbs in pitch
-- with your combo, so a hot streak sounds hotter.
function Fx.flip(result: string, combo: number, lockedIn: boolean?)
	Sfx.play("spatula", result == "miss" and 0.85 or 1)
	if result == "perfect" then
		Sfx.play("sear", 1 + math.min(combo, 10) * 0.04)
		if lockedIn then
			task.delay(0.5, function()
				Sfx.play("ding", 1 + math.min(combo, 10) * 0.03)
			end)
		end
		Fx.pop(Content.Slang.perfectFlip, T.gold)
		if lockedIn then
			task.delay(0.5, function()
				Fx.pop(Content.Slang.lockedIn .. "  x" .. combo, Color3.fromHex("#6CC24A"), 40)
			end)
		end
	elseif result == "good" then
		Fx.pop("Nice flip!", T.green, 36)
	else
		Fx.pop("Flipped too early/late", T.dim, 30)
	end
end

-- Rookie List goal done: a ding, a coin jingle and Unc's cheer. The last goal gets the kazoo
-- fanfare and a confetti pop around you.
function Fx.rookie(d: any)
	if d.last then
		Sfx.play("fanfare")
		Fx.pop("🎉 ROOKIE OF THE RANCH!", T.gold, 52)
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local burst = Instance.new("Part")
			burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
			burst.Transparency = 1
			burst.Size = Vector3.new(1, 1, 1)
			burst.CFrame = hrp.CFrame * CFrame.new(0, 3, 0)
			burst.Parent = workspace
			local pe = Instance.new("ParticleEmitter")
			pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("#FFC83C")), ColorSequenceKeypoint.new(0.5, Color3.fromHex("#E8590C")), ColorSequenceKeypoint.new(1, Color3.fromHex("#5AD2FF")) })
			pe.Speed = NumberRange.new(10, 18)
			pe.SpreadAngle = Vector2.new(80, 80)
			pe.Lifetime = NumberRange.new(1, 1.8)
			pe.Acceleration = Vector3.new(0, -20, 0)
			pe.Size = NumberSequence.new(0.4)
			pe.Rate = 0
			pe.Parent = burst
			pe:Emit(90)
			task.delay(2.5, function()
				burst:Destroy()
			end)
		end
	else
		Sfx.play("ding", 1 + (d.step or 1) * 0.05)
		task.delay(0.15, function()
			Sfx.play("coins")
		end)
		Fx.pop(string.format("✅ Rookie List %d/%d", d.step or 1, d.total or 5), T.green, 40)
		if d.cheer then
			task.delay(0.6, function()
				Fx.announce(d.cheer, "#FFF6E6")
			end)
		end
	end
end

local function speechBubble(part: BasePart, text: string, color: Color3)
	local bb = Instance.new("BillboardGui")
	bb.Name = "HowdyBubble"
	bb.Size = UDim2.fromOffset(220, 64)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromHex("#12263F")
	label.BackgroundTransparency = 0.1
	label.TextColor3 = color
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.Size = UDim2.fromScale(1, 1)
	label.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	task.delay(4, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

-- A howdy is said out loud. The speaker waves, a bubble sits on their head,
-- and the yard answers even when nobody else is in the server.
function Fx.howdy(d: any)
	local speaker = Players:GetPlayerByUserId(d.userId or 0)
	local char = speaker and speaker.Character
	local head = char and (char:FindFirstChild("Head") :: BasePart?)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if head then
		speechBubble(head, "Howdy!", Color3.fromHex("#FFD15A"))
	end
	if hum then
		pcall(function()
			(hum :: any):PlayEmote("wave")
		end)
	end
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	if hub then
		for _, name in ipairs({ "KingOfThePit", "UncHank", "Temp" }) do
			local npc = hub:FindFirstChild(name)
			local npcHead = npc and npc:FindFirstChild("Head", true)
			if npcHead and npcHead:IsA("BasePart") then
				speechBubble(npcHead, name == "KingOfThePit" and "Howdy, partner." or "Howdy!", Color3.fromHex("#FFF8F0"))
			end
		end
		local stage = hub:FindFirstChild("CookOff")
		if stage then
			for _, name in ipairs({ "Granny", "JudgeBob" }) do
				local npc = stage:FindFirstChild(name)
				local npcHead = npc and npc:FindFirstChild("Head", true)
				if npcHead and npcHead:IsA("BasePart") then
					speechBubble(npcHead, "Howdy!", Color3.fromHex("#FFF8F0"))
				end
			end
		end
	end
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plots = map and map:FindFirstChild("Plots")
	if hrp and plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local tables = plot:FindFirstChild("Tables")
			if tables then
				for _, guest in ipairs(tables:GetDescendants()) do
					if guest:IsA("BasePart") and guest.Name == "Head" and (guest.Position - hrp.Position).Magnitude < 40 then
						speechBubble(guest, "Howdy!", Color3.fromHex("#C8F0A8"))
					end
				end
			end
		end
	end
	if d.rewarded then
		Fx.pop("Howdy! The King tipped his hat.", T.gold, 32)
	end
end

local _ = Players
return Fx
