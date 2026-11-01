--!strict
-- Feedback: toasts, announcements, rare-reveal cinematic, flip popups, floating coins.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UI = require(script.Parent.UI)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
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
	info = Color3.fromHex("#5A4030"),
}

function Fx.mount(screen: GuiObject)
	gui = screen
	toastHolder = UI.frame({ Name = "Toasts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(0, 460, 0, 300), Parent = screen, ZIndex = 50 })
	UI.list(toastHolder, nil, 6, Enum.HorizontalAlignment.Center)
	announceHolder = UI.frame({ Name = "Announce", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.new(0, 640, 0, 50), Parent = screen, ZIndex = 50 })
	UI.list(announceHolder, nil, 4, Enum.HorizontalAlignment.Center)
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
	UI.label(text, { TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), TextSize = 17, ZIndex = 52, Parent = f })
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
	local f = UI.frame({ BackgroundColor3 = Color3.fromHex("#1A0F0A"), BackgroundTransparency = 0.25, Size = UDim2.new(1, 0, 0, 34), ZIndex = 51, Parent = announceHolder })
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
	Fx.pop("+" .. UI.fmt(amount) .. " 🪙", T.gold, 34)
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
	local card = UI.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 520, 0, 220), BackgroundColor3 = Color3.fromHex("#1A0F0A"), ZIndex = 56, Parent = overlay })
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

function Fx.flip(result: string, combo: number, lockedIn: boolean?)
	if result == "perfect" then
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

local _ = Players
return Fx
