--!strict
-- Unc Hank's Rookie List on the client: a small goal card under the coin bar and a gold arrow
-- in the world that points at where the current goal happens (your grill, your picnic tables,
-- your smoker, the Sauce Shack, or Big Bertha's bell). The server decides when a goal is met.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local T = UI.Theme

local RookieGuide = {}
local refs: any = {}
local marker: Part? = nil
local beam: Beam? = nil
local a0: Attachment? = nil
local lastStep = -1
local GOLD = Color3.fromHex("#FFC83C")

local NEAR = 14 -- studs: close enough that the floor line hides and only the bobbing arrow stays

function RookieGuide.mount(root: GuiObject)
	local card = UI.frame({ Name = "RookieList", BackgroundColor3 = T.bg, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 62), Size = UDim2.new(0, 300, 0, 104), Visible = false, Parent = root })
	UI.corner(card, 14)
	UI.stroke(card, GOLD, 2)
	UI.pad(card, 8)
	refs.card = card
	refs.head = UI.label(Content.Rookie.title, { Size = UDim2.new(1, -60, 0, 20), TextSize = 16, TextColor3 = GOLD, Parent = card })
	refs.count = UI.label("1/5", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 0, 20), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.dim, Parent = card })
	refs.goal = UI.label("", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -64, 0, 24), TextSize = 18, Parent = card })
	refs.reward = UI.label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 22), Size = UDim2.new(0, 64, 0, 24), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GOLD, Parent = card })
	local back, fill = UI.bar(card, T.green, { Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, -44, 0, 10) })
	refs.fill = fill
	refs.prog = UI.label("", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 45), Size = UDim2.new(0, 40, 0, 20), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.dim, Parent = card })
	refs.tip = UI.label("", { Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 28), TextYAlignment = Enum.TextYAlignment.Top, TextSize = 12, Font = T.body, TextColor3 = T.dim, Parent = card })
	local _ = back
end

local function plotModel(s: any): Model?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local m = plots and s.plot and plots:FindFirstChild("Plot" .. s.plot)
	return if m and m:IsA("Model") then m else nil
end

local function firstPart(inst: Instance?): BasePart?
	if not inst then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") then
		local p = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		return p
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

-- Where the arrow goes for a goal.
local function targetPart(s: any, target: string): BasePart?
	local plot = plotModel(s)
	if target == "grill" then
		return plot and firstPart(plot:FindFirstChild("Grill") and (plot :: any).Grill:FindFirstChild("g1"))
	elseif target == "tables" then
		-- the picnic table closest to you (critters sit at all of them)
		local tables = plot and plot:FindFirstChild("Tables")
		if not tables then
			return nil
		end
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local best: BasePart? = nil
		local bestD = math.huge
		for _, t in ipairs(tables:GetChildren()) do
			local tp = firstPart(t)
			if tp then
				local d = if hrp then (tp.Position - hrp.Position).Magnitude else 0
				if d < bestD then
					best, bestD = tp, d
				end
			end
		end
		return best
	elseif target == "smoker" then
		local smokers = plot and plot:FindFirstChild("Smokers")
		if not smokers then
			return nil
		end
		for i = 1, s.slots.smoker do
			local key = "s" .. i
			if s.stations[key] == nil then
				local sm = smokers:FindFirstChild(key)
				return firstPart(sm and sm:FindFirstChild("Barrel"))
			end
		end
		return firstPart(smokers:FindFirstChild("s1") and (smokers :: any).s1:FindFirstChild("Barrel"))
	elseif target == "sauce" then
		local shack = workspace:FindFirstChild("SauceShack", true)
		return firstPart(shack and shack:FindFirstChild("Counter"))
	elseif target == "bell" then
		local bertha = workspace:FindFirstChild("BigBertha", true)
		local bell = bertha and bertha:FindFirstChild("DinnerBell")
		return firstPart(bell and bell:FindFirstChild("Bell"))
	end
	return nil
end

local function ensureMarker(): Part
	if marker and marker.Parent then
		return marker
	end
	local p = Instance.new("Part")
	p.Name = "RookieArrow"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Name = "Arrow"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 120, 0, 96)
	bb.StudsOffset = Vector3.new(0, 2.4, 0) -- tag on top, arrow tip just above the target
	bb.LightInfluence = 0
	bb.Parent = p
	local arrow = UI.label("▼", { Name = "Glyph", Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 64), TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = GOLD, TextStrokeTransparency = 0, Parent = bb })
	UI.label("", { Name = "Tag", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 30), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0, Parent = bb })
	-- bob the arrow up and down
	TweenService:Create(arrow, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0, 0, 0, 20) }):Play()
	local a1 = Instance.new("Attachment")
	a1.Name = "To"
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = p
	local b = Instance.new("Beam")
	b.Name = "Trail"
	b.Color = ColorSequence.new(GOLD)
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.2) })
	b.Width0, b.Width1 = 0.35, 0.9
	b.FaceCamera = true
	b.LightEmission = 0.6
	b.Segments = 12
	b.Attachment1 = a1
	b.Parent = p
	marker = p
	beam = b
	return p
end

local function hide()
	if marker then
		marker.Parent = nil
	end
	if refs.card then
		refs.card.Visible = false
	end
end

local TAGS = { grill = "Flip here!", tables = "Hungry critters!", smoker = "Smoke here!", sauce = "Sauce Shack", bell = "Ring me!" }

function RookieGuide.update(s: any)
	if not refs.card then
		return
	end
	local st = s and s.rookie
	if not st or st.finished or not s.tutorial or not s.tutorial.done then
		hide()
		return
	end
	local def = Config.RookieSteps[st.step]
	refs.card.Visible = true
	refs.count.Text = string.format("%d/%d", st.step, st.total)
	refs.goal.Text = (def and def.icon or "") .. " " .. (st.label or "")
	local rw = st.reward or {}
	refs.reward.Text = (rw.coins and ("+" .. rw.coins .. " 🪙") or "") .. (rw.cosmetic and " 🎁" or "")
	refs.fill.Size = UDim2.fromScale(st.amount > 0 and st.progress / st.amount or 0, 1)
	refs.prog.Text = string.format("%d/%d", st.progress, st.amount)
	refs.tip.Text = def and def.tip or ""
	if st.step ~= lastStep then
		lastStep = st.step
		refs.card.Size = UDim2.new(0, 318, 0, 110)
		TweenService:Create(refs.card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(0, 300, 0, 104) }):Play()
	end

	local part = st.target and targetPart(s, st.target)
	if not part then
		if marker then
			marker.Parent = nil
		end
		return
	end
	local m = ensureMarker()
	if m.Parent ~= workspace then
		m.Parent = workspace
	end
	m.CFrame = CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 1.5, 0))
	local tag = (m :: any).Arrow.Tag :: TextLabel
	tag.Text = TAGS[st.target] or ""
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and beam then
		if not a0 or a0.Parent ~= hrp then
			local att = Instance.new("Attachment")
			att.Name = "RookieFrom"
			att.Position = Vector3.new(0, -2.6, 0)
			att.Parent = hrp
			a0 = att
		end
		beam.Attachment0 = a0
		beam.Enabled = ((hrp :: BasePart).Position - part.Position).Magnitude > NEAR
	elseif beam then
		beam.Enabled = false
	end
end

return RookieGuide
