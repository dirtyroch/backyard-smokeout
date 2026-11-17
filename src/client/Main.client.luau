--!strict
-- Client entry: builds the whole UI in code and connects server pushes to it.
-- A module that throws must not skip the "ask again for my snapshot" loop, or the
-- panel stays on "Your ranch is still loading" after a missed first push.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function tryRequire(mod: ModuleScript, name: string): any
	-- pcall(require, mod) instead of require(mod): a thrown module must not kill the
	-- snapshot retry that was already spawned, and the path is not a literal require().
	local ok, result = pcall(require, mod)
	if not ok then
		warn("[Client] " .. name .. " failed to load:\n" .. tostring(result))
		return nil
	end
	return result
end

-- Net is required directly so a later module can throw without taking the retry with it.
local Net = require(script.Parent.Net)

-- Keep asking until a snapshot arrives. The server also pushes on load; this covers
-- a push that landed before this client was listening, and a load that finished late.
-- Spawned before the other requires: if one of those throws, this loop is already running.
task.spawn(function()
	local pause = 1.5
	while not Net.state do
		task.wait(pause)
		if Net.state then
			break
		end
		pcall(function(): nil
			Net.pull()
			return nil
		end)
		pause = math.min(pause * 1.4, 8)
	end
end)

local UI = tryRequire(script.Parent.UI, "UI")
local Fx = tryRequire(script.Parent.Fx, "Fx")
local Hud = tryRequire(script.Parent.Hud, "Hud")
local Panels = tryRequire(script.Parent.Panels, "Panels")
local WorldClient = tryRequire(script.Parent.WorldClient, "WorldClient")
local Ambient = tryRequire(script.Parent.Ambient, "Ambient")
local Sfx = tryRequire(script.Parent.Sfx, "Sfx")
local Music = tryRequire(script.Parent.Music, "Music")
local RookieGuide = tryRequire(script.Parent.RookieGuide, "RookieGuide")
local GuideHint = tryRequire(script.Parent.GuideHint, "GuideHint")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = tryRequire(Shared:WaitForChild("Config") :: ModuleScript, "Config")
local Content = tryRequire(Shared:WaitForChild("Content") :: ModuleScript, "Content")
if not (UI and Fx and Hud and Panels and Sfx and Music and RookieGuide and GuideHint and Config and Content) then
	warn("[Client] UI did not finish loading. The snapshot retry is still running.")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = UI.new("ScreenGui", { Name = "BackyardSmokeout", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
do
	local applied = pcall(function()
		local insets = (Enum :: any).ScreenInsets
		if insets and insets.CoreUISafeInsets then
			(screen :: any).ScreenInsets = insets.CoreUISafeInsets
			local compat = (Enum :: any).SafeAreaCompatibility
			if compat and compat.None then
				(screen :: any).SafeAreaCompatibility = compat.None
			end
			screen.IgnoreGuiInset = true
			screen:SetAttribute("SafeInsets", true)
		end
	end)
	if not applied then
		screen:SetAttribute("SafeInsets", false)
	end
end
-- Text stays full size on phones. Layouts reflow (Hud.applyLayout, Panels.applyLayout)
-- instead of shrinking every letter with a UIScale. CoreUISafeInsets keeps the
-- notch and the home indicator outside this screen. If that enum is missing,
-- the leftover bottom and side insets are padded by hand.
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = screen })
local function safeInsets(): { left: number, top: number, right: number, bottom: number }
	if screen:GetAttribute("SafeInsets") == true then
		return { left = 0, top = 0, right = 0, bottom = 0 }
	end
	local topLeft = Vector2.zero
	local bottomRight = Vector2.zero
	pcall(function()
		local a, b = GuiService:GetGuiInset()
		if typeof(a) == "Vector2" then
			topLeft = a
		end
		if typeof(b) == "Vector2" then
			bottomRight = b
		end
	end)
	return {
		left = math.max(0, topLeft.X),
		top = 0,
		right = math.max(0, bottomRight.X),
		bottom = math.max(0, bottomRight.Y),
	}
end
local function rescale()
	local v = root.AbsoluteSize
	if v.X < 80 or v.Y < 80 then
		local cam = workspace.CurrentCamera
		v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	end
	UI.setViewport(v)
	UI.setInsets(safeInsets())
	Hud.applyLayout()
	Panels.applyLayout()
	RookieGuide.applyLayout()
	GuideHint.applyLayout()
end

Sfx.mount()
Music.mount()
UI.onClick = function()
	Sfx.play("click", nil, 0.05)
end
Fx.mount(root)
Panels.mount(root)
Hud.mount(root, Panels)
RookieGuide.mount(root)
GuideHint.mount(root)
rescale()
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end
Net.notify = Fx.toast
if WorldClient then
	local okWorld, errWorld = xpcall(function()
		WorldClient.start(Panels)
	end, debug.traceback)
	if not okWorld then
		warn("[Client] WorldClient.start failed:\n" .. tostring(errWorld))
	end
end
if Ambient then
	task.spawn(function()
		local okAmbient, errAmbient = xpcall(Ambient.start, debug.traceback)
		if not okAmbient then
			warn("[Client] Ambient.start failed:\n" .. tostring(errAmbient))
		end
	end)
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

Net.on("toast", function(p)
	Fx.toast(p.text, p.kind)
end)
Net.on("announce", function(p)
	Fx.announce(p.text, p.color)
end)
Net.on("dialog", function(p)
	Panels.dialog(p)
end)
Net.on("welcome", function(p)
	task.wait(1)
	Panels.welcome(p)
end)
Net.on("fx", function(p)
	local d = p.data or {}
	if p.kind == "reveal" then
		Fx.reveal(d.meat, d.rarity, d.aura or 0, Hud.smokerPosition("s1"))
	elseif p.kind == "flip" then
		Fx.flip(d.result, d.combo or 0, d.lockedIn)
	elseif p.kind == "served" then
		Fx.coins(d.value or 0)
		if (d.aura or 0) > 0 then
			task.delay(0.4, function()
				Fx.pop("+" .. d.aura .. " AURA", Color3.fromHex("#B48CFF"), 30)
			end)
		end
	elseif p.kind == "snagged" then
		Fx.pop(Content.Slang.snagged .. " Tag " .. tostring(d.by) .. " back!", UI.Theme.red, 34)
	elseif p.kind == "bell" then
		Fx.pop("🔔 CLANG!", Color3.fromHex("#FFC83C"), 40)
		Fx.ringBell()
	elseif p.kind == "dinnerbell" then
		Fx.dinnerBell()
	elseif p.kind == "sixseven" then
		task.delay(0.5, function()
			Fx.pop(Content.Slang.sixSeven, Color3.fromHex("#FFC83C"), 54)
		end)
	elseif p.kind == "rush" then
		Sfx.play("coins")
		Fx.pop(Content.Slang.rush .. " +" .. tostring(d.bonus or 0), Color3.fromHex("#6CC24A"), 40)
	elseif p.kind == "swat" then
		Sfx.play("swat", d.queen and 0.8 or 0.9 + math.random() * 0.2, 0.08)
		Fx.pop(d.queen and "👑 QUEEN DOWN!" or "SWAT!", UI.Theme.gold, d.queen and 44 or 26)
	elseif p.kind == "rookie" then
		Fx.rookie(d)
	elseif p.kind == "gift" then
		Sfx.play("fanfare")
		Fx.pop("🎁 A gift from " .. tostring(d.from) .. "!", Color3.fromHex("#FF8FAB"), 40)
	elseif p.kind == "champ" then
		Sfx.play("fanfare")
		Fx.pop(tostring(d.medal) .. " Cook-Off Champ!", UI.Theme.gold, 40)
	elseif p.kind == "howdy" then
		Fx.howdy(d)
	elseif p.kind == "freegift" then
		Sfx.play("coins")
		Sfx.play("ding", 1.15)
		Fx.coins(d.value or 0)
	elseif p.kind == "hired" then
		Sfx.play("fanfare", 1.05)
		Fx.pop((d.name or "Crew") .. " clocked in!", UI.Theme.gold, 36)
	elseif p.kind == "levelup" then
		Sfx.play("fanfare")
		Fx.pop(tostring(d.text or "Level up!"), UI.Theme.gold, 36)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(function(): any
			Hud.update()
			RookieGuide.update(Net.state)
			GuideHint.update(Net.state)
			if Net.state and Net.state.settings then
				local want = Net.state.settings.sfx ~= false
				if want ~= Sfx.isEnabled() then
					Sfx.setEnabled(want)
				end
				Music.apply(Net.state.settings)
			end
			return nil
		end)
		if not ok then
			warn("[Hud] " .. tostring(err))
		end
	end
end)
