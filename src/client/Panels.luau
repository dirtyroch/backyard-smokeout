--!strict
-- All pop-up windows: Pit Shop, Sauce Shack, Index, Pitmaster Path, Upgrades, Daily, Settings,
-- the cook picker, NPC dialogs and the welcome card.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local UI = require(script.Parent.UI)
local Net = require(script.Parent.Net)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Monetization = require(Shared.Monetization)
local Rarity = require(Shared.Logic.Rarity)
local Restock = require(Shared.Logic.Restock)
local Economy = require(Shared.Logic.Economy)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Holiday = require(Shared.Logic.Holiday)
local Gifting = require(Shared.Logic.Gifting)
local Storefront = require(Shared.Logic.Storefront)
local Rookie = require(Shared.Logic.Rookie)
local T = UI.Theme

local player = Players.LocalPlayer
local Panels = {}
local screen: GuiObject = nil :: any
local window: Frame = nil :: any
local titleLabel: TextLabel = nil :: any
local body: Frame = nil :: any
local current: string? = nil
local currentArg: any = nil
local tabState: { [string]: string } = {}
local lastRender = 0
local sauceOdds: { [string]: number }? = nil
local freshOpen = false
local loggedTab: string? = nil

local EGGS = {
	{ id = "blessed", hint = "Sunday folks set a table by the hub. Look closely at what's on it." },
	{ id = "roof", hint = "The Sauce Shack roof has a sign-in sheet. Bounce your way up." },
	{ id = "creek", hint = "There's a gap in the hedge behind the ranches. Listen to the stones." },
	{ id = "apron", hint = "Somebody's Unc left an apron by the water." },
	{ id = "king", hint = "The King of the Pit has a gift for a pitmaster in a proper hat, after dark." },
	{ id = "temp", hint = "Temp gets nervous if you keep poking him." },
	{ id = "rex", hint = "Meet enough regulars and someone special visits. RAWR!" },
	{ id = "meteorite", hint = "Cook the rarest cut there is." },
	{ id = "cooked", hint = "Make Granny Pecan say you COOKED." },
	{ id = "sixseven", hint = "Some tips just hit different. Watch the last two digits." },
	{ id = "dinnerbell", hint = "Big Bertha's bell is loudest with a crowd. Bring two friends and ring it together." },
}

local function S(): any
	return Net.state
end

-- ===== window chrome =====
function Panels.mount(sg: GuiObject)
	screen = sg
	window = UI.frame({ Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 760, 0, 500), BackgroundColor3 = T.bg, Visible = false, ZIndex = 20, Parent = screen })
	UI.corner(window, 18)
	UI.stroke(window, T.accent, 3)
	titleLabel = UI.label("", { Position = UDim2.new(0, 20, 0, 10), Size = UDim2.new(1, -80, 0, 36), TextSize = 28, ZIndex = 21, Parent = window })
	UI.button("✕", T.red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.new(0, 40, 0, 40), TextSize = 22, ZIndex = 22, Parent = window }, function()
		Panels.close()
	end)
	body = UI.frame({ Name = "Body", BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 54), Size = UDim2.new(1, -32, 1, -68), ZIndex = 21, Parent = window })
	Net.changed.Event:Connect(function()
		if current and current ~= "dialog" and current ~= "welcome" and os.clock() - lastRender > 0.75 then
			Panels.render()
		end
	end)
end

function Panels.close()
	current = nil
	window.Visible = false
end

function Panels.open(name: string, arg: any?)
	if name == "invite" then
		Panels.invite()
		return
	end
	current = name
	currentArg = arg
	freshOpen = true
	window.Visible = true
	Panels.render()
end

function Panels.toggle(name: string)
	if current == name then
		Panels.close()
	else
		Panels.open(name)
	end
end

function Panels.goHome()
	local s = S()
	local char = player.Character
	local map = workspace:FindFirstChild("Map")
	if not s or not s.plot or not char or not map then
		return
	end
	local plot = map.Plots:FindFirstChild("Plot" .. s.plot)
	local pad = plot and plot:FindFirstChild("SpawnPad") :: BasePart?
	if pad then
		char:PivotTo(pad.CFrame + Vector3.new(0, 4, 0))
	end
end

function Panels.invite()
	local ok, can = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if ok and can then
		pcall(function()
			local opts = Instance.new("ExperienceInviteOptions")
			opts.PromptMessage = "Help me ring Big Bertha's dinner bell! 3 rings = bonus tips for the whole server 🔔"
			opts.LaunchData = "bertha"
			SocialService:PromptGameInvite(player, opts)
		end)
	else
		Net.notify("Invites aren't available here. Share the game link with your friends! (Friends in the same server give a crew bonus.)", "info")
	end
end

local function scroller(parent: Instance, grid: boolean?, cell: Vector2?): ScrollingFrame
	local sf = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 21,
		Parent = parent,
	})
	if grid then
		UI.new("UIGridLayout", { CellSize = UDim2.new(0, (cell or Vector2.new(170, 220)).X, 0, (cell or Vector2.new(170, 220)).Y), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf })
	else
		UI.list(sf, nil, 8)
	end
	UI.pad(sf, 4)
	return sf
end

local function tabs(parent: Instance, key: string, names: { string }, default: string): (string, Frame)
	local sel = tabState[key] or default
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 21, Parent = parent })
	UI.list(row, Enum.FillDirection.Horizontal, 6)
	for i, n in ipairs(names) do
		UI.button(n, n == sel and T.accent or T.card, { Size = UDim2.new(0, math.max(70, #n * 9 + 20), 0, 32), TextSize = 15, LayoutOrder = i, ZIndex = 22, Parent = row }, function()
			tabState[key] = n
			Panels.render()
		end)
	end
	local content = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 44), Size = UDim2.new(1, 0, 1, -44), ZIndex = 21, Parent = parent })
	return sel, content
end

local function card(parent: Instance, order: number, h: number?): Frame
	local f = UI.frame({ BackgroundColor3 = T.card, Size = UDim2.new(1, -8, 0, h or 70), LayoutOrder = order, ZIndex = 22, Parent = parent })
	UI.corner(f, 12)
	UI.pad(f, 10)
	return f
end

local function lbl(parent: Instance, text: string, props: any?): TextLabel
	local p = props or {}
	p.ZIndex = p.ZIndex or 23
	p.Parent = parent
	local l = UI.label(text, p)
	return l
end

local function btn(parent: Instance, text: string, color: Color3?, props: any?, fn: (() -> ())?): TextButton
	local p = props or {}
	p.ZIndex = p.ZIndex or 24
	p.Parent = parent
	return UI.button(text, color, p, fn)
end

-- ===== Pit Shop (Robux) =====
local function ownsAll(s: any, grants: { string }?): boolean
	if not grants then
		return false
	end
	for _, id in ipairs(grants) do
		if not s.owned[id] then
			return false
		end
	end
	return true
end

local function shopCard(parent: Instance, order: number, kind: string, key: string, item: any, s: any)
	local available = kind == "pass" and s.productIds.passes[key] or s.productIds.products[key]
	if not available then
		return false
	end
	local f = UI.frame({ BackgroundColor3 = T.card, LayoutOrder = order, ZIndex = 22, Parent = parent })
	UI.corner(f, 14)
	UI.pad(f, 8)
	lbl(f, item.icon, { Size = UDim2.new(1, 0, 0, 44), TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center })
	lbl(f, item.name, { Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 0, 40), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	lbl(f, item.desc, { Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(1, 0, 0, 64), TextSize = 12, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
	if item.valueNote then
		lbl(f, item.valueNote, { Position = UDim2.new(0, 0, 0, 150), Size = UDim2.new(1, 0, 0, 28), TextSize = 11, Font = T.body, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local owned = false
	if kind == "pass" then
		owned = s.passes[key] == true
	elseif item.kind == "cosmetic" or item.kind == "bundle" then
		owned = ownsAll(s, item.grants)
		local have = Storefront.ownedCount(s.owned, item.grants)
		if item.kind == "bundle" and not owned and have > 0 then
			-- honest heads-up: the bundle price doesn't change if you already own some of it
			lbl(f, string.format("Own %d/%d", have, #(item.grants :: any)), { Size = UDim2.new(0.5, 0, 0, 18), TextSize = 11, Font = T.body, TextColor3 = T.dim })
		end
	elseif item.once then
		owned = s.onceBought ~= nil and s.onceBought[key] == true
	end
	local idIsZero = item.id == 0
	local text = owned and "Owned ✓" or (idIsZero and "Studio test (free)" or ("Buy for R$ " .. item.price))
	local canGift = kind == "product" and Gifting.giftable(item)
	if canGift then
		-- Gift it to someone in the server (looks only). Shows held gifts that can go out free.
		local held = s.giftsHeld and s.giftsHeld[key] or 0
		btn(f, held > 0 and ("🎁" .. held) or "🎁", T.gift, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.new(0, 44, 0, 36), TextSize = held > 0 and 15 or 20 }, function()
			Panels.open("gift", key)
		end)
	end
	btn(f, text, owned and T.cardHi or T.green, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, canGift and -50 or 0, 0, 36), TextSize = 15, AutoButtonColor = not owned }, function()
		if not owned then
			Net.act("Prompt", kind, key)
		end
	end)
	if not idIsZero and not owned then
		lbl(f, "R$ " .. item.price, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 0, 18), TextSize = 13, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right })
	end
	return true
end

local function infoCard(parent: Instance, order: number, icon: string, name: string, desc: string, note: string?, label: string, color: Color3, fn: (() -> ())?)
	local f = UI.frame({ BackgroundColor3 = T.card, LayoutOrder = order, ZIndex = 22, Parent = parent })
	UI.corner(f, 14)
	UI.pad(f, 8)
	lbl(f, icon, { Size = UDim2.new(1, 0, 0, 44), TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center })
	lbl(f, name, { Position = UDim2.new(0, 0, 0, 46), Size = UDim2.new(1, 0, 0, 40), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
	lbl(f, desc, { Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(1, 0, 0, 64), TextSize = 12, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
	if note then
		lbl(f, note, { Position = UDim2.new(0, 0, 0, 150), Size = UDim2.new(1, 0, 0, 40), TextSize = 11, Font = T.body, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
	end
	btn(f, label, color, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 36), TextSize = 15, AutoButtonColor = fn ~= nil }, fn)
	return f
end

local function byPrice(keys: { string })
	table.sort(keys, function(a, b)
		local pa, pb = Monetization.Products[a], Monetization.Products[b]
		if (pa.once == true) ~= (pb.once == true) then
			return pa.once == true -- the one-time pack goes first
		end
		return pa.price < pb.price
	end)
end

local function renderShop(s: any)
	titleLabel.Text = "🛒 Pitmaster Outfitters"
	local sel, content = tabs(body, "shop", Monetization.ShopTabs, "This Week")
	-- analytics only (Roblox funnel: opened shop -> opened a tab -> tapped buy -> bought)
	if freshOpen then
		loggedTab = nil
		task.spawn(Net.act, "ShopView", "")
	end
	if loggedTab ~= sel then
		loggedTab = sel
		task.spawn(Net.act, "ShopView", sel)
	end
	local sf = scroller(content, true, Vector2.new(166, 236))
	local n = 0
	local event = s.turkey and s.turkey.active
	if sel == "Passes" then
		local keys = {}
		for k in pairs(Monetization.Passes) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return Monetization.Passes[a].price < Monetization.Passes[b].price
		end)
		for i, k in ipairs(keys) do
			if shopCard(sf, i, "pass", k, Monetization.Passes[k], s) then
				n += 1
			end
		end
		local m = s.member or {}
		local club = Monetization.Subscriptions.PitCrewClub
		if m.club or m.clubOffer then
			n += 1
			infoCard(sf, 100, club.icon, club.name, "A new look every month (yours to keep), a Pit Crew tag, a daily Smoke Shower for your server and 1 free Season tier a month. No coins.", club.id == "" and "Studio test" or "$4.99 a month. Cancel any time.", m.club and "Member ✓" or (club.id == "" and "Studio test (free)" or "Join the Club"), m.club and T.cardHi or T.green, (not m.club) and function()
				Net.act("Subscribe")
			end or nil)
		end
		n += 1
		local prem = Monetization.Premium
		infoCard(sf, 101, prem.icon, prem.name, prem.desc, nil, m.premium and "Premium ✓" or "Learn about Premium", m.premium and T.cardHi or T.blue, (not m.premium) and function()
			Net.act("PremiumInfo")
		end or nil)
		n += 1
		infoCard(sf, 102, "🏠", "Private Ranch Server", Monetization.PrivateServer.desc, m.host and "You're hosting this server!" or nil, m.host and "Host ✓" or "How to get one", m.host and T.cardHi or T.card, function()
			Net.notify("On the game's page, open Servers and tap Create Private Server. A grown-up can help with the purchase.", "info")
		end)
	else
		local keys = {}
		if sel == "This Week" then
			if event then
				for k, p in pairs(Monetization.Products) do
					if p.event == "turkeyday" then
						table.insert(keys, k)
					end
				end
				byPrice(keys)
			end
			for _, k in ipairs(s.rotation) do
				table.insert(keys, k)
			end
		else
			for k, p in pairs(Monetization.Products) do
				if p.category == sel and not (p.once and s.onceBought and s.onceBought[k]) then
					table.insert(keys, k)
				end
			end
			byPrice(keys)
		end
		if sel == "This Week" and s.seasonPass and s.seasonPass.active then
			local sp = s.seasonPass
			n += 1
			infoCard(sf, 0, sp.icon, "Smokehouse Pass", string.format("Season %d: %s. Free and pass tracks of looks and titles. You're on tier %d of %d.", sp.number, sp.name, sp.tier, sp.max), sp.starts .. " to " .. sp.ends, "See the season", T.accent, function()
				Panels.open("season")
			end)
		end
		for i, k in ipairs(keys) do
			if shopCard(sf, i, "product", k, Monetization.Products[k], s) then
				n += 1
			end
		end
	end
	if n == 0 then
		lbl(sf, "Nothing here yet. Check back soon!", { Size = UDim2.new(0, 400, 0, 30) })
	end
	local foot = "Every purchase shows exactly what you get. No random items, ever. Tap 🎁 to gift a look to someone in your server."
	if sel == "This Week" then
		foot = event and ("Turkey Day looks are here through " .. s.turkey.ends .. " and return next year. The potluck apron stays free.") or "This week's looks rotate every Monday and come back in a later week. Looks only, no stats."
	elseif sel == "Passes" then
		foot = "Passes are yours forever. The Pit Crew Club and Premium are monthly and give looks and friendly perks, never coins."
	end
	lbl(body, foot, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 14), Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = T.body, TextColor3 = T.dim })
end

-- ===== Smokehouse Pass (season) =====
local SLOT_ICON = { hat = "🤠", apron = "🦺", tool = "🥄", neck = "🧣", trail = "✨", skin = "🔥", smoke = "💨", feet = "🧦", patio = "💡" }

local function seasonCell(parent: Instance, y: number, reward: any?, reached: boolean, locked: boolean, paidRow: boolean)
	local f = UI.frame({ BackgroundColor3 = reward and (reached and (locked and T.panel or T.cardHi) or T.card) or T.panel, BackgroundTransparency = reward and 0 or 0.6, Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, 96), ZIndex = 23, Parent = parent })
	UI.corner(f, 10)
	if paidRow and reward then
		UI.stroke(f, T.gold, reached and not locked and 2 or 1)
	end
	if not reward then
		return
	end
	local icon, name = "🏷️", ""
	if reward.cosmetic then
		local def = Config.Cosmetics[reward.cosmetic]
		icon = def and SLOT_ICON[def.slot] or "🎁"
		name = def and def.name or reward.cosmetic
	else
		name = '"' .. tostring(reward.title) .. '"'
	end
	lbl(f, icon, { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, ZIndex = 24, TextXAlignment = Enum.TextXAlignment.Center })
	lbl(f, name, { Position = UDim2.new(0, 4, 0, 40), Size = UDim2.new(1, -8, 0, 36), TextSize = 12, Font = T.body, ZIndex = 24, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top })
	local status = reached and (locked and "🔒 pass" or "✓ yours") or ""
	if status ~= "" then
		lbl(f, status, { Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 16), TextSize = 11, ZIndex = 24, TextColor3 = locked and T.dim or T.green, TextXAlignment = Enum.TextXAlignment.Center })
	end
end

local function renderSeason(s: any)
	local sp = s.seasonPass
	titleLabel.Text = "🎟️ Smokehouse Pass"
	if not sp or not sp.active then
		lbl(body, "The next season starts " .. ((sp and sp.nextLabel) or "soon") .. ". The Pitmaster Path and the weekly looks keep going in the meantime.", { Size = UDim2.new(1, 0, 0, 60), TextSize = 18 })
		return
	end
	local def
	for _, d in ipairs(Config.SeasonPass.seasons) do
		if d.id == sp.id then
			def = d
		end
	end
	if not def then
		return
	end
	lbl(body, string.format("%s Season %d: %s", sp.icon, sp.number, sp.name), { Size = UDim2.new(1, -240, 0, 28), TextSize = 22, TextColor3 = T.gold })
	local sub = sp.need > 0 and string.format("%s to %s  •  Tier %d of %d  •  %d / %d XP to the next tier", sp.starts, sp.ends, sp.tier, sp.max, sp.into, sp.need) or string.format("%s to %s  •  Top tier reached! Nice smokin'.", sp.starts, sp.ends)
	lbl(body, sub, { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -240, 0, 20), TextSize = 13, Font = T.body, TextColor3 = T.dim })
	local _, fill = UI.bar(body, T.gold, { Position = UDim2.new(0, 0, 0, 50), Size = UDim2.new(1, -240, 0, 10), ZIndex = 22 })
	fill.ZIndex = 23
	fill.Size = UDim2.fromScale(sp.need > 0 and math.clamp(sp.into / sp.need, 0, 1) or 1, 1)
	local pass = Monetization.Products.SeasonPass
	local avail = s.productIds.products.SeasonPass
	if sp.paid then
		btn(body, "🎟️ Pass ✓", T.cardHi, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0, 226, 0, 52), TextSize = 18, AutoButtonColor = false })
	elseif avail then
		btn(body, pass.id == 0 and "🎟️ Get the pass (Studio test)" or ("🎟️ Get the pass  R$ " .. pass.price), T.green, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0, 226, 0, 52), TextSize = 16 }, function()
			Net.act("Prompt", "product", "SeasonPass")
		end)
	end
	-- the two tracks
	local rows = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 70), Size = UDim2.new(0, 58, 0, 230), ZIndex = 22, Parent = body })
	lbl(rows, "FREE", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 96), TextSize = 15, TextColor3 = T.text })
	lbl(rows, "PASS", { Position = UDim2.new(0, 0, 0, 126), Size = UDim2.new(1, 0, 0, 96), TextSize = 15, TextColor3 = T.gold })
	local track = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 60, 0, 70), Size = UDim2.new(1, -60, 0, 236), AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 6, ZIndex = 22, Parent = body })
	UI.list(track, Enum.FillDirection.Horizontal, 6)
	for i = 1, sp.max do
		local reached = i <= sp.tier
		local col = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(0, 104, 0, 224), LayoutOrder = i, ZIndex = 22, Parent = track })
		lbl(col, tostring(i), { Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = reached and T.gold or T.dim, TextXAlignment = Enum.TextXAlignment.Center })
		seasonCell(col, 24, def.free[i], reached, false, false)
		seasonCell(col, 126, def.paid[i], reached, not sp.paid, true)
	end
	if freshOpen then
		task.defer(function()
			track.CanvasPosition = Vector2.new(math.max(0, (sp.tier - 2) * 110), 0)
		end)
	end
	-- tier skips (looks and titles only)
	local skipRow = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 316), Size = UDim2.new(1, 0, 0, 44), ZIndex = 22, Parent = body })
	UI.list(skipRow, Enum.FillDirection.Horizontal, 8)
	for i, key in ipairs({ "TierSkip1", "TierSkip5" }) do
		local p = Monetization.Products[key]
		if s.productIds.products[key] and sp.tier + (p.count or 1) <= sp.max then
			local text = p.id == 0 and (p.icon .. " " .. p.name .. " (Studio test)") or string.format("%s %s  R$ %d", p.icon, p.name, p.price)
			btn(skipRow, text, T.blue, { Size = UDim2.new(0, 250, 0, 40), TextSize = 15, LayoutOrder = i }, function()
				Net.act("Prompt", "product", key)
			end)
		end
	end
	local skip5 = Monetization.Products.TierSkip5
	if skip5.valueNote then
		lbl(skipRow, skip5.valueNote, { Size = UDim2.new(0, 200, 0, 40), TextSize = 12, Font = T.body, TextColor3 = T.gold, LayoutOrder = 3 })
	end
	lbl(body, "Looks and titles only. Season XP comes from things you already do: serving, cooking, perfect flips, Cook-Offs, the dinner bell and a daily visit. Tiers you reach are yours to keep.", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 14), Size = UDim2.new(1, 0, 0, 34), TextSize = 12, Font = T.body, TextColor3 = T.dim, TextWrapped = true })
end

-- ===== Gift picker (looks only, to someone in this server) =====
local function renderGift(s: any)
	local key = currentArg
	local item = Monetization.Products[key]
	if not item then
		Panels.close()
		return
	end
	titleLabel.Text = "🎁 Gift " .. item.name
	local sf = scroller(body)
	local held = s.giftsHeld and s.giftsHeld[key] or 0
	local head = card(sf, 0, 44)
	head.BackgroundTransparency = 1
	lbl(head, held > 0 and string.format("You have %d of these saved to send. Gifting one is free.", held) or ("Pick who gets it. Looks only, no stats. R$ " .. item.price .. ", same as buying it for yourself."), { Size = UDim2.new(1, 0, 1, 0), TextSize = 16, TextColor3 = T.gold })
	local n = 0
	local others = Players:GetPlayers()
	table.sort(others, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	for _, other in ipairs(others) do
		if other ~= player then
			n += 1
			local f = card(sf, n, 64)
			lbl(f, other.DisplayName, { Size = UDim2.new(1, -200, 0, 26), TextSize = 20 })
			lbl(f, "@" .. other.Name, { Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -200, 0, 20), TextSize = 13, Font = T.body, TextColor3 = T.dim })
			local label = held > 0 and "Send free 🎁" or (item.id == 0 and "Studio gift (free)" or ("Gift for R$ " .. item.price))
			btn(f, label, T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 180, 0, 44), TextSize = 16 }, function()
				local ok = Net.act("Gift", key, other.UserId)
				if ok then
					Panels.open("shop")
				end
			end)
		end
	end
	if n == 0 then
		local f = card(sf, 1, 64)
		lbl(f, "Nobody else is in this server yet.", { Size = UDim2.new(1, -200, 1, 0), TextSize = 18 })
		btn(f, "Invite a friend", T.accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 180, 0, 44), TextSize = 16 }, function()
			Panels.invite()
		end)
	end
	btn(body, "← Back to shop", T.card, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 14), Size = UDim2.new(0, 160, 0, 30), TextSize = 14 }, function()
		Panels.open("shop")
	end)
end

-- ===== Sauce Shack (coins) =====
local EFFECT_TEXT = { luck = "luck (better rarity odds)", speed = "cook speed", tip = "tips" }

local function renderSauce(s: any)
	titleLabel.Text = "🥫 Roch & Roll Sauce Shack"
	local sf = scroller(body)
	local head = card(sf, 0, 40)
	head.BackgroundTransparency = 1
	lbl(head, string.format("New sauce in %s  •  restocks every 5 minutes  •  bought with coins only", TimeUtil.formatDuration(s.restock.nextIn)), { Size = UDim2.new(1, 0, 1, 0), TextSize = 16, TextColor3 = T.gold })
	local rm = Economy.rankMult(s.rank, Config.RANK_STEP)
	for i, e in ipairs(s.restock.shelf) do
		local def = Config.Sauces[e.id]
		local left = e.qty - (s.restock.bought[e.id] or 0)
		local price = math.floor(def.price * (1 + (rm - 1) * 0.5))
		local f = card(sf, i, 76)
		local sw = UI.frame({ BackgroundColor3 = Color3.fromHex(def.color), Size = UDim2.new(0, 40, 0, 56), ZIndex = 23, Parent = f })
		UI.corner(sw, 8)
		lbl(f, def.name, { Position = UDim2.new(0, 52, 0, 0), Size = UDim2.new(1, -220, 0, 26), TextSize = 20 })
		lbl(f, string.format("+%d%% %s for %d cooks  •  %d left in stock", math.floor(def.amount * 100), EFFECT_TEXT[def.effect], def.charges, math.max(0, left)), { Position = UDim2.new(0, 52, 0, 28), Size = UDim2.new(1, -220, 0, 24), TextSize = 14, Font = T.body, TextColor3 = T.dim })
		btn(f, left > 0 and ("🪙 " .. UI.fmt(price)) or "Sold out", left > 0 and T.green or T.cardHi, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 44) }, function()
			if left > 0 then
				Net.act("BuySauce", e.id)
			end
		end)
	end
	local mine = card(sf, 10, 60)
	local parts = {}
	for effect, v in pairs(s.sauces) do
		if v.charges > 0 then
			table.insert(parts, string.format("%s +%d%% (%d left)", EFFECT_TEXT[effect], math.floor(v.amount * 100), v.charges))
		end
	end
	lbl(mine, "Your sauces: " .. (#parts > 0 and table.concat(parts, "  •  ") or "none yet"), { Size = UDim2.new(1, 0, 1, 0), TextSize = 15 })
	if not sauceOdds then
		sauceOdds = Restock.appearOdds(Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS, 1500)
	end
	local odds = card(sf, 11, 90)
	local lines = {}
	for _, id in ipairs(Config.SauceOrder) do
		table.insert(lines, string.format("%s %.0f%%", Config.Sauces[id].name, (sauceOdds :: any)[id]))
	end
	lbl(odds, "Chance each sauce is on the shelf in a restock:\n" .. table.concat(lines, "  •  "), { Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Font = T.body, TextColor3 = T.dim })
end

-- ===== Cook picker =====
local function meatLocked(s: any, meat: any): string?
	if meat.hidden then
		return "hidden"
	end
	if not Holiday.meatInSeason(meat, s.season.id, s.turkey ~= nil and s.turkey.active, Config.TurkeyDay.meat) then
		return "Seasonal: back next " .. meat.season
	end
	if s.pitLevel < meat.unlockPit then
		return "Needs " .. Config.PitLevels[meat.unlockPit].name
	end
	if meat.premium then
		local has = s.passes.PremiumCuts or (s.cuts[meat.id] or 0) > 0 or (meat.id == "tomahawk" and s.unlocks.tomahawk)
		if not has then
			return "Premium cut (Path reward or Pit Shop)"
		end
	end
	return nil
end

local function renderCook(s: any)
	local key = currentArg :: string
	local kind = string.sub(key, 1, 1) == "s" and "smoker" or "grill"
	titleLabel.Text = (kind == "smoker" and "🔥 Smoker " or "🍔 Grill ") .. string.sub(key, 2) .. ": what are we cooking?"
	local sf = scroller(body)
	local rm = Economy.rankMult(s.rank, Config.RANK_STEP)
	local pit = Config.PitLevels[s.pitLevel]
	local luck = pit.luck * (1 + (s.sauces.luck.charges > 0 and s.sauces.luck.amount or 0))
	local order = 0
	for _, id in ipairs(Config.MeatOrder) do
		local meat = Config.Meats[id]
		if meat.station == kind and Holiday.meatInSeason(meat, s.season.id, s.turkey ~= nil and s.turkey.active, Config.TurkeyDay.meat) then
			order += 1
			local why = meatLocked(s, meat)
			local f = card(sf, order, 74)
			lbl(f, meat.icon, { Size = UDim2.new(0, 50, 1, 0), TextSize = 36 })
			local secs = meat.cookTime / pit.speed
			local tokens = meat.premium and not s.passes.PremiumCuts and (s.cuts[id] or 0) > 0 and string.format("  •  you have %d", s.cuts[id]) or ""
			lbl(f, meat.name, { Position = UDim2.new(0, 56, 0, 0), Size = UDim2.new(1, -230, 0, 26), TextSize = 20 })
			lbl(f, string.format("%s  •  sells ~%s 🪙%s", TimeUtil.formatDuration(secs), UI.fmt(meat.price * rm), tokens), { Position = UDim2.new(0, 56, 0, 28), Size = UDim2.new(1, -230, 0, 22), TextSize = 14, Font = T.body, TextColor3 = T.dim })
			local cost = Economy.rawCost(meat, rm)
			btn(f, why and "🔒" or (cost > 0 and ("Cook 🪙" .. UI.fmt(cost)) or "Cook (free)"), why and T.cardHi or T.accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
				if why then
					Net.notify(why, "info")
					return
				end
				if Net.act("StartCook", key, id) then
					Panels.close()
				end
			end)
			if why then
				lbl(f, why, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -170, 1, 4), Size = UDim2.new(0, 260, 0, 18), TextSize = 12, Font = T.body, TextColor3 = T.gold, TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
	end
	local odds = Rarity.odds(Config.Rarities, luck, nil)
	local parts = {}
	for _, o in ipairs(odds) do
		table.insert(parts, string.format("%s %.1f%%", o.name, o.pct))
	end
	local f = card(sf, 99, 64)
	lbl(f, "Rarity odds right now (set when you start the cook):\n" .. table.concat(parts, "  •  ") .. (kind == "grill" and "\nBurgers top out at Smoke Ring Gold." or ""), { Size = UDim2.new(1, 0, 1, 0), TextSize = 13, Font = T.body, TextColor3 = T.dim })
end

-- ===== Index =====
local function renderIndex(s: any)
	titleLabel.Text = "📖 Index"
	local sel, content = tabs(body, "index", { "Regulars", "Cuts", "Secrets" }, "Regulars")
	if sel == "Regulars" then
		local sf = scroller(content, true, Vector2.new(166, 120))
		local odds = Rarity.weightedOdds(Config.Critters)
		for i, c in ipairs(Config.Critters) do
			local met = (s.critters[c.id] or 0) > 0
			local f = UI.frame({ BackgroundColor3 = met and T.card or T.panel, LayoutOrder = i, ZIndex = 22, Parent = sf })
			UI.corner(f, 12)
			UI.pad(f, 8)
			local sw = UI.frame({ BackgroundColor3 = met and Color3.fromHex(c.body) or Color3.fromHex("#222222"), Size = UDim2.new(0, 30, 0, 30), ZIndex = 23, Parent = f })
			UI.corner(sw, 15)
			lbl(f, met and c.name or "???", { Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -38, 0, 34), TextSize = 15 })
			lbl(f, string.format("%s\nAppears %.1f%%  •  tips x%.1f", met and ("Served " .. s.critters[c.id] .. "x") or "Not met yet", odds[c.id] or 0, c.tip), { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 50), TextSize = 12, Font = T.body, TextColor3 = T.dim })
		end
	elseif sel == "Cuts" then
		local sf = scroller(content)
		local rarOdds = Rarity.odds(Config.Rarities, Config.PitLevels[s.pitLevel].luck, nil)
		for i, id in ipairs(Config.MeatOrder) do
			local meat = Config.Meats[id]
			local f = card(sf, i, 44)
			lbl(f, meat.icon .. " " .. meat.name, { Size = UDim2.new(0, 220, 1, 0), TextSize = 16 })
			local row = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 230, 0, 0), Size = UDim2.new(1, -230, 1, 0), ZIndex = 23, Parent = f })
			UI.list(row, Enum.FillDirection.Horizontal, 6)
			for ri, r in ipairs(Config.Rarities) do
				if ri <= meat.maxRarity then
					local got = s.cutsIndex[id .. ":" .. r.id]
					local chip = UI.label(got and r.name or "?", { Size = UDim2.new(0, 84, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = got and 0 or 0.7, BackgroundColor3 = Color3.fromHex(r.color), TextColor3 = got and Color3.fromHex("#1A0F0A") or T.dim, LayoutOrder = ri, ZIndex = 24, Parent = row })
					UI.corner(chip, 8)
				end
			end
		end
		local parts = {}
		for _, o in ipairs(rarOdds) do
			table.insert(parts, string.format("%s %.1f%%", o.name, o.pct))
		end
		local f = card(sf, 100, 50)
		lbl(f, "Odds at your pit level: " .. table.concat(parts, "  •  "), { Size = UDim2.new(1, 0, 1, 0), TextSize = 13, Font = T.body, TextColor3 = T.dim })
	else
		local sf = scroller(content)
		local n = 0
		for i, e in ipairs(EGGS) do
			local found = s.eggs[e.id] == true
			if found then
				n += 1
			end
			local f = card(sf, i + 1, 44)
			lbl(f, (found and "✅ " or "❔ ") .. (found and string.upper(e.id) .. ": found!" or e.hint), { Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Font = T.body })
		end
		local h = card(sf, 0, 36)
		h.BackgroundTransparency = 1
		lbl(h, string.format("Secrets found: %d / %d", n, #EGGS), { Size = UDim2.new(1, 0, 1, 0), TextSize = 18, TextColor3 = T.gold })
	end
end

-- ===== Pitmaster Path =====
local function rewardText(r: any): string
	local parts = {}
	if r.coins then
		table.insert(parts, UI.fmt(r.coins) .. " coins")
	end
	if r.sauce then
		table.insert(parts, Config.Sauces[r.sauce].name)
	end
	if r.cosmetic then
		table.insert(parts, Config.Cosmetics[r.cosmetic].name)
	end
	if r.boostMinutes then
		table.insert(parts, r.boostMinutes .. " min x2 speed")
	end
	if r.wagyu then
		table.insert(parts, r.wagyu .. " Wagyu Brisket")
	end
	if r.title then
		table.insert(parts, "Title: " .. r.title)
	end
	if r.rex then
		table.insert(parts, "a very special visitor 🦖")
	end
	if r.tomahawk then
		table.insert(parts, "Tomahawk Steaks forever")
	end
	return table.concat(parts, " + ")
end

local function renderPath(s: any)
	titleLabel.Text = "🗺️ Pitmaster Path (28 days)"
	local sf = scroller(body)
	local st = s.pathStatus
	local head = card(sf, 0, 44)
	head.BackgroundTransparency = 1
	lbl(head, string.format("Play days: %d  •  Steps claimed: %d / %d  •  a new step unlocks each day you play", s.path.playDays, s.path.claimed, #Config.PathSteps), { Size = UDim2.new(1, 0, 1, 0), TextSize = 15, TextColor3 = T.gold })
	for i, step in ipairs(Config.PathSteps) do
		local f = card(sf, i, 58)
		local claimed = i <= s.path.claimed
		local isCur = i == st.step
		f.BackgroundColor3 = claimed and T.cardHi or (isCur and T.card or T.panel)
		lbl(f, string.format("Day %d: %s", i, step.label), { Size = UDim2.new(1, -170, 0, 22), TextSize = 16 })
		lbl(f, "Reward: " .. rewardText(step.reward), { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -170, 0, 18), TextSize = 12, Font = T.body, TextColor3 = T.dim })
		if claimed then
			lbl(f, "✅ Done", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.green })
		elseif isCur then
			if st.complete then
				btn(f, "Claim!", T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 38) }, function()
					Net.act("ClaimPath")
				end)
			elseif not st.unlocked then
				lbl(f, "Unlocks on play day " .. i, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 30), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.dim })
			else
				lbl(f, string.format("%d / %d", st.progress, st.amount), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = T.gold })
			end
		else
			lbl(f, "🔒", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 60, 0, 30), TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
	if freshOpen then
		task.defer(function()
			sf.CanvasPosition = Vector2.new(0, math.max(0, (st.step - 3) * 66))
		end)
	end
end

-- ===== Upgrades & Unc Status =====
local function renderUpgrades(s: any)
	titleLabel.Text = "⬆️ Upgrades & Unc Status"
	local sf = scroller(body)
	local pit = Config.PitLevels[s.pitLevel]
	local nextPit = Config.PitLevels[s.pitLevel + 1]
	local f1 = card(sf, 1, 80)
	lbl(f1, "Pit: " .. pit.name, { Size = UDim2.new(1, -180, 0, 26), TextSize = 20 })
	lbl(f1, nextPit and string.format("Next: %s  •  speed x%.2f -> x%.2f  •  luck x%.2f -> x%.2f  •  unlocks new meats", nextPit.name, pit.speed, nextPit.speed, pit.luck, nextPit.luck) or "Maxed out! Time for Unc Status.", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -180, 0, 34), TextSize = 13, Font = T.body, TextColor3 = T.dim })
	if nextPit then
		btn(f1, "🪙 " .. UI.fmt(nextPit.cost), s.coins >= nextPit.cost and T.green or T.cardHi, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
			Net.act("UpgradePit")
		end)
	end
	for i, kind in ipairs({ "smoker", "grill" }) do
		local def = Config.Slots[kind]
		local cap = kind == "smoker" and Config.MAX_SMOKERS or Config.MAX_GRILLS
		local cost = Economy.nextSlotCost(def.costs, s.bought[kind])
		local f = card(sf, 1 + i, 64)
		lbl(f, string.format("%s slots: %d / %d", kind == "smoker" and "Smoker" or "Grill", s.slots[kind], cap), { Size = UDim2.new(1, -180, 0, 26), TextSize = 18 })
		lbl(f, kind == "smoker" and "More smokers = more meat smoking while you're away." or "More grill spots = more burgers at once.", { Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, -180, 0, 20), TextSize = 13, Font = T.body, TextColor3 = T.dim })
		if cost and s.slots[kind] < cap then
			btn(f, "🪙 " .. UI.fmt(cost), s.coins >= cost and T.green or T.cardHi, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 40) }, function()
				Net.act("BuySlot", kind)
			end)
		end
	end
	local nextRank = Config.Ranks[s.rank + 1]
	local f4 = card(sf, 5, 120)
	f4.BackgroundColor3 = Color3.fromHex("#4A3A1A")
	lbl(f4, "👴 Unc Status: " .. Config.Ranks[s.rank].name, { Size = UDim2.new(1, -180, 0, 28), TextSize = 22, TextColor3 = T.gold })
	if nextRank then
		lbl(f4, string.format("Rebirth into %s: +%d%% coins forever. Resets coins, pit and slots. Keeps cosmetics, Index, sauces, titles, passes and your cooler. Unfinished cooks are refunded.", nextRank.name, math.floor(Config.RANK_STEP * 100)), { Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, -180, 0, 50), TextSize = 13, Font = T.body, TextColor3 = T.dim })
		local back, fill = UI.bar(f4, T.gold, { Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(1, -180, 0, 12), ZIndex = 23 })
		fill.ZIndex = 24
		fill.Size = UDim2.fromScale(math.clamp(s.runCoins / nextRank.need, 0, 1), 1)
		lbl(f4, UI.fmt(s.runCoins) .. " / " .. UI.fmt(nextRank.need) .. " earned this run", { Position = UDim2.new(0, 0, 0, 98), Size = UDim2.new(1, -180, 0, 16), TextSize = 12, Font = T.body })
		local _ = back
		btn(f4, "Rebirth", s.runCoins >= nextRank.need and T.gold or T.cardHi, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 50), TextColor3 = Color3.fromHex("#1A0F0A") }, function()
			Net.act("Rebirth")
		end)
	else
		lbl(f4, "You're OG Pitmaster. Nothing left but respect.", { Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, -20, 0, 30), TextSize = 15 })
	end
end

-- ===== Daily =====
local function renderDaily(s: any)
	titleLabel.Text = "🎁 Daily Smoke"
	local wrap = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 21, Parent = body })
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 130), ZIndex = 21, Parent = wrap })
	UI.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	local count = s.streak.count
	local nextDay = s.canClaimDaily and ((count % 7) + 1) or (((count - 1) % 7) + 1)
	for i, r in ipairs(Config.DailyRewards) do
		local isNext = i == nextDay and s.canClaimDaily
		local done = (not s.canClaimDaily and i <= nextDay) or (s.canClaimDaily and i < nextDay)
		local f = UI.frame({ BackgroundColor3 = isNext and T.accent or (done and T.cardHi or T.card), Size = UDim2.new(0, 92, 0, 124), LayoutOrder = i, ZIndex = 22, Parent = row })
		UI.corner(f, 12)
		UI.pad(f, 6)
		lbl(f, "Day " .. i, { Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center })
		lbl(f, i == 7 and "🎁" or "🪙", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 40), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center })
		local txt = UI.fmt(r.coins)
		if r.sauce then
			txt ..= "\n+ " .. Config.Sauces[r.sauce].name
		end
		if r.boostMinutes then
			txt ..= "\n+ " .. r.boostMinutes .. "m x2"
		end
		lbl(f, txt, { Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 50), TextSize = 11, Font = T.body, TextXAlignment = Enum.TextXAlignment.Center })
		if done then
			lbl(f, "✓", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 20, 0, 20), TextColor3 = T.green })
		end
	end
	lbl(wrap, string.format("🔥 Streak: %d days (best %d). Miss a day? Your free miss each week keeps it going. Miss more and you only go back to the start of this week, never zero.", count, s.streak.best), { Position = UDim2.new(0, 0, 0, 140), Size = UDim2.new(1, 0, 0, 44), TextSize = 14, Font = T.body, TextColor3 = T.dim, ZIndex = 22 })
	btn(wrap, s.canClaimDaily and "Claim today's reward!" or "Come back tomorrow (Texas time)", s.canClaimDaily and T.green or T.cardHi, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.new(0, 340, 0, 54), TextSize = 22 }, function()
		if s.canClaimDaily then
			Net.act("ClaimDaily")
		end
	end)
	btn(wrap, "👴 Hear Unc Hank's joke of the day", T.blue, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 262), Size = UDim2.new(0, 340, 0, 44), TextSize = 17 }, function()
		Net.act("HearJoke")
	end)
	local m = s.member or {}
	if m.club or m.host then
		local perks = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 366), Size = UDim2.new(1, 0, 0, 40), ZIndex = 22, Parent = wrap })
		UI.list(perks, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
		if m.club then
			btn(perks, m.clubShowerReady and "🔧 Share today's Pit Crew Smoke Shower" or "🔧 Smoke Shower shared today ✓", m.clubShowerReady and T.green or T.cardHi, { Size = UDim2.new(0, 330, 0, 40), TextSize = 15, LayoutOrder = 1 }, function()
				Net.act("ClubShower")
			end)
		end
		if m.host then
			btn(perks, m.hostShowerReady and "🏠 Host's Smoke Shower" or "🏠 Smoker warming up", m.hostShowerReady and T.green or T.cardHi, { Size = UDim2.new(0, 250, 0, 40), TextSize = 15, LayoutOrder = 2 }, function()
				Net.act("HostShower")
			end)
		end
	end
	lbl(wrap, "Also today: 🧪 sauce restocks every 5 min  •  🏆 Saturday Cook-Off  •  🫧 Suds weekend pups  •  🦟 mosquitoes at dusk", { Position = UDim2.new(0, 0, 0, 320), Size = UDim2.new(1, 0, 0, 40), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22 })
end

-- ===== Settings / Fits / Titles =====
local SLOT_LABEL = { hat = "Hat", apron = "Apron", tool = "Tool", neck = "Bandana", feet = "Feet", trail = "Trail", skin = "Smoker skin", smoke = "Smoke color", patio = "Patio" }

local function renderSettings(s: any)
	titleLabel.Text = "⚙️ Settings & Fits"
	local sel, content = tabs(body, "settings", { "Fits", "Titles", "Game" }, "Fits")
	local sf = scroller(content)
	if sel == "Fits" then
		local order = 0
		for _, slot in ipairs(Config.CosmeticSlots) do
			local owned = {}
			for id, def in pairs(Config.Cosmetics) do
				if def.slot == slot and s.owned[id] then
					table.insert(owned, id)
				end
			end
			table.sort(owned)
			order += 1
			local f = card(sf, order, 70)
			lbl(f, SLOT_LABEL[slot] or slot, { Size = UDim2.new(0, 120, 0, 24), TextSize = 16 })
			local row = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 120, 0, 0), Size = UDim2.new(1, -120, 1, 0), AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, ScrollBarThickness = 4, ZIndex = 23, Parent = f })
			UI.list(row, Enum.FillDirection.Horizontal, 6)
			if #owned == 0 then
				lbl(row, "None yet. Earn them on the Path, at events, or in the Pit Shop.", { Size = UDim2.new(0, 420, 1, 0), TextSize = 13, Font = T.body, TextColor3 = T.dim })
			else
				btn(row, "None", s.equipped[slot] == nil and T.accent or T.cardHi, { Size = UDim2.new(0, 70, 0, 40), TextSize = 13, LayoutOrder = 0 }, function()
					Net.act("Equip", slot, "")
				end)
				for i, id in ipairs(owned) do
					local def = Config.Cosmetics[id]
					local b = btn(row, def.name, s.equipped[slot] == id and T.accent or T.cardHi, { Size = UDim2.new(0, 150, 0, 40), TextSize = 13, LayoutOrder = i }, function()
						Net.act("Equip", slot, id)
					end)
					local sw = UI.frame({ BackgroundColor3 = Color3.fromHex(def.color), Size = UDim2.new(0, 10, 1, -10), Position = UDim2.new(0, 4, 0, 5), ZIndex = 25, Parent = b })
					UI.corner(sw, 4)
				end
			end
		end
	elseif sel == "Titles" then
		local list = {}
		for t in pairs(s.titles) do
			table.insert(list, t)
		end
		table.sort(list)
		local f0 = card(sf, 0, 44)
		btn(f0, "Show rank (" .. Config.Ranks[s.rank].name .. ")", s.title == "" and T.accent or T.cardHi, { Size = UDim2.new(0, 300, 1, 0), TextSize = 15 }, function()
			Net.act("SetTitle", "")
		end)
		for i, t in ipairs(list) do
			local f = card(sf, i, 44)
			btn(f, t, s.title == t and T.accent or T.cardHi, { Size = UDim2.new(0, 300, 1, 0), TextSize = 15 }, function()
				Net.act("SetTitle", t)
			end)
		end
		if #list == 0 then
			local f = card(sf, 1, 40)
			lbl(f, "Earn titles from the Path, secrets and Unc Status.", { Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Font = T.body })
		end
	else
		local f = card(sf, 1, 90)
		lbl(f, "🕊️ Peace Mode: " .. (s.settings.peace and "ON" or "OFF"), { Size = UDim2.new(1, -180, 0, 26), TextSize = 20 })
		lbl(f, "When on, nobody can snag plates from your pass window, and you can't snag theirs. You can switch once a minute.", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -180, 0, 40), TextSize = 13, Font = T.body, TextColor3 = T.dim })
		btn(f, s.settings.peace and "Turn off" or "Turn on", s.settings.peace and T.cardHi or T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
			Net.act("SetPeace", not s.settings.peace)
		end)
		local fs = card(sf, 3, 70) -- sound effects toggle (saved)
		local sfxOn = s.settings.sfx ~= false
		lbl(fs, "🔊 Sound effects: " .. (sfxOn and "ON" or "OFF"), { Size = UDim2.new(1, -180, 0, 26), TextSize = 20 })
		lbl(fs, "Sizzles, spatula clanks, the cash register and Big Bertha's bell.", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -180, 0, 20), TextSize = 13, Font = T.body, TextColor3 = T.dim })
		btn(fs, sfxOn and "Turn off" or "Turn on", sfxOn and T.cardHi or T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
			Net.act("SetSfx", not sfxOn)
		end)
		local f2 = card(sf, 2, 70)
		lbl(f2, string.format("🤝 Crew bonus: +%d%% (%d friend%s here)", math.floor(s.crew * Config.Crew.perFriend * 100 + 0.5), s.crew, s.crew == 1 and "" or "s"), { Size = UDim2.new(1, -180, 0, 26), TextSize = 18 })
		lbl(f2, "Each friend in your server gives +10% coins (up to 3).", { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -180, 0, 20), TextSize = 13, Font = T.body, TextColor3 = T.dim })
		btn(f2, "👋 Invite friends", T.blue, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
			Panels.invite()
		end)
		-- Unc's Rookie List: bring it back after a skip (and still earn the finish reward)
		local rk = s.rookie
		if rk and s.tutorial and s.tutorial.done then
			local fin = Config.RookieFinish
			local cdef = fin.cosmetic and Config.Cosmetics[fin.cosmetic]
			local finText = Rookie.rewardText(fin, cdef and cdef.name or nil)
			local fr = card(sf, 0, 84)
			local head, desc
			if rk.done then
				head, desc = "📋 Unc's Rookie List: done ✓", "You earned " .. finText .. "."
			elseif rk.skipped then
				head, desc = "📋 Unc's Rookie List: skipped", "Bring it back to finish it. Goals you already did count right away. Finish all 5 to earn " .. finText .. "."
			else
				head, desc = "📋 Unc's Rookie List: on", "It's on your screen (top right). Finish all 5 to earn " .. finText .. "."
			end
			lbl(fr, head, { Size = UDim2.new(1, -180, 0, 26), TextSize = 20 })
			lbl(fr, desc, { Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(1, -180, 0, 52), TextSize = 13, Font = T.body, TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top })
			if rk.skipped then
				btn(fr, "Bring it back", T.green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 160, 0, 44) }, function()
					Net.act("RookieResume")
				end)
			end
		end
		local f3 = card(sf, 4, 60)
		lbl(f3, s.memoryOnly and "⚠️ Studio test mode: progress is NOT saved." or "💾 Your ranch saves automatically. Smokers keep cooking while you're away.", { Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Font = T.body })
	end
end

-- ===== Dialog (NPCs) =====
local dialogFrame: Frame? = nil

function Panels.dialog(payload: any)
	if dialogFrame then
		dialogFrame:Destroy()
	end
	local f = UI.frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -180), Size = UDim2.new(0, 620, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.bg, ZIndex = 30, Parent = screen })
	dialogFrame = f
	UI.corner(f, 16)
	UI.stroke(f, T.gold, 3)
	UI.pad(f, 14)
	UI.list(f, nil, 8)
	UI.label(payload.npc or "", { TextSize = 22, TextColor3 = T.gold, ZIndex = 31, LayoutOrder = 1, Parent = f })
	local text = UI.label(payload.text or "", { TextSize = 17, Font = T.body, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), ZIndex = 31, LayoutOrder = 2, Parent = f })
	local yap: TextLabel? = nil
	if payload.yap then
		yap = UI.label("", { TextSize = 14, Font = T.body, TextColor3 = T.dim, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), ZIndex = 31, LayoutOrder = 3, Parent = f })
	end
	if (payload.reward or 0) > 0 then
		UI.label("+" .. UI.fmt(payload.reward) .. " 🪙", { TextSize = 20, TextColor3 = T.gold, ZIndex = 31, LayoutOrder = 4, Parent = f })
	end
	local row = UI.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 31, LayoutOrder = 5, Parent = f })
	UI.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	local skipped = false
	if yap then
		local yl = yap :: TextLabel
		local skip = UI.button(Content.Slang.skipYap .. " ⏭", T.cardHi, { Size = UDim2.new(0, 160, 0, 40), ZIndex = 32, LayoutOrder = 1, Parent = row })
		skip.Activated:Connect(function()
			skipped = true
			yl.Text = "(Yap skipped. Unc is a little hurt.)"
			skip:Destroy()
		end)
		task.spawn(function()
			local full = "Unc keeps going: " .. payload.yap
			for i = 1, #full do
				if skipped or not yl.Parent then
					return
				end
				yl.Text = string.sub(full, 1, i)
				task.wait(0.025)
			end
		end)
	end
	UI.button("OK", T.green, { Size = UDim2.new(0, 100, 0, 40), ZIndex = 32, LayoutOrder = 2, Parent = row }, function()
		f:Destroy()
		if dialogFrame == f then
			dialogFrame = nil
		end
	end)
	local _ = text
	task.delay(20, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

function Panels.welcome(payload: any)
	if payload.isNew then
		Panels.dialog({ npc = "Unc Hank", text = "Hi Hungry, I'm Unc! Welcome to Backyard Smokeout.\n\nHere's how it works: brisket and ribs smoke for real hours (even while you're offline), burgers take 30 seconds on the grill. Serve the critters, upgrade your pit, find the secrets.\n\nHit the big orange button to smoke your first brisket. It only takes a minute this time. 😉" })
	elseif payload.away and payload.ready and payload.ready > 0 then
		Panels.dialog({ npc = "Unc Hank", text = string.format("Welcome back! You were gone %s and %d meat%s finished smoking. They're resting in the smoker, ready to collect.", TimeUtil.formatDuration(payload.away), payload.ready, payload.ready == 1 and "" or "s") })
	end
end

function Panels.render()
	if not current or not window.Visible then
		return
	end
	local s = S()
	if not s then
		return
	end
	lastRender = os.clock()
	-- keep scroll position across live refreshes
	local oldScroll: Vector2? = nil
	for _, d in ipairs(body:GetDescendants()) do
		if d:IsA("ScrollingFrame") and d.ScrollingDirection == Enum.ScrollingDirection.Y then
			oldScroll = d.CanvasPosition
			break
		end
	end
	UI.clear(body)
	local ok, err = pcall(function()
		if current == "shop" then
			renderShop(s)
		elseif current == "gift" then
			renderGift(s)
		elseif current == "season" then
			renderSeason(s)
		elseif current == "sauce" then
			renderSauce(s)
		elseif current == "cook" then
			renderCook(s)
		elseif current == "index" then
			renderIndex(s)
		elseif current == "path" then
			if freshOpen then
				oldScroll = nil
			end
			renderPath(s)
		elseif current == "upgrades" then
			renderUpgrades(s)
		elseif current == "daily" then
			renderDaily(s)
		elseif current == "settings" then
			renderSettings(s)
		end
	end)
	if not ok then
		warn("[Panels] " .. tostring(err))
	end
	local wasFresh = freshOpen
	freshOpen = false
	if oldScroll and not wasFresh then
		for _, d in ipairs(body:GetDescendants()) do
			if d:IsA("ScrollingFrame") and d.ScrollingDirection == Enum.ScrollingDirection.Y then
				d.CanvasPosition = oldScroll
				break
			end
		end
	end
end

return Panels
