--!strict
-- Client entry: builds the whole UI in code and connects server pushes to it.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Fx = require(script.Parent.Fx)
local Hud = require(script.Parent.Hud)
local Panels = require(script.Parent.Panels)
local WorldClient = require(script.Parent.WorldClient)
local Ambient = require(script.Parent.Ambient)
local Sfx = require(script.Parent.Sfx)
local Music = require(script.Parent.Music)
local RookieGuide = require(script.Parent.RookieGuide)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = UI.new("ScreenGui", { Name = "BackyardSmokeout", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })
-- Text stays full size on phones. Layouts reflow (Hud.applyLayout, Panels.applyLayout)
-- instead of shrinking every letter with a UIScale.
local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = screen })
local function rescale()
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
	UI.setViewport(v)
	Hud.applyLayout()
	Panels.applyLayout()
	RookieGuide.applyLayout()
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
rescale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end
Net.notify = Fx.toast
WorldClient.start(Panels)
task.spawn(Ambient.start)

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
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(function(): any
			Hud.update()
			RookieGuide.update(Net.state)
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

-- Ask for a first snapshot (the server also pushes one when your data loads).
task.delay(2, function()
	if not Net.state then
		Net.act("Hello")
	end
end)

local _ = Config
