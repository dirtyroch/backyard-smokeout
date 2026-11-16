--!strict
-- The always-on HUD: currencies, menu buttons, the station bar, Serve All / Collect All,
-- and the one-button first cook for brand-new players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)
local Sfx = require(script.Parent.Sfx)
local Net = require(script.Parent.Net)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CookLogic = require(Shared.Logic.CookLogic)
local TimeUtil = require(Shared.Logic.TimeUtil)
local T = UI.Theme

local Hud = {}
local Panels: any = nil
local root: Frame = nil :: any
local refs: any = {}
local cards: { [string]: any } = {}
local cardLayoutKey = ""
local menuButtons: { TextButton } = {}
local styleCard: (any) -> ()

function Hud.view(st: any, boost: any): (number, number, boolean, number?)
	local now = workspace:GetServerTimeNow()
	local c: any = {
		meat = st.meat,
		rarity = "",
		progress = st.progress,
		duration = st.duration,
		last = st.last,
		startedAt = st.last,
		rateMult = 1,
		peeks = 0,
		revealed = false,
		doneAt = st.doneAt,
	}
	CookLogic.advance(c, now, st.rate, boost.mult, boost.untilT)
	local remaining = CookLogic.remaining(c, now, st.rate, boost.mult, boost.untilT)
	return CookLogic.fraction(c), remaining, CookLogic.isDone(c), c.doneAt
end

local function topPill(parent: Instance, icon: string, order: number, color: Color3, wide: number?): TextLabel
	local f = UI.frame({ BackgroundColor3 = T.bg, BackgroundTransparency = 0.05, Size = UDim2.new(0, wide or 156, 0, 48), LayoutOrder = order, Parent = parent })
	UI.corner(f, 16)
	UI.stroke(f, color, 2)
	UI.label(icon, { Size = UDim2.new(0, 36, 1, 0), Position = UDim2.new(0, 8, 0, 0), TextSize = 24, Parent = f })
	local value = UI.label("0", { Name = "Value", Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 44, 0, 0), TextSize = 22, TextColor3 = color, Parent = f })
	UI.fitText(value, 22, 15)
	return value
end

local function menuButton(parent: Instance, icon: string, text: string, order: number, panel: string): TextButton
	local b = UI.button("", T.bg, { Size = UDim2.new(0, 96, 0, 72), LayoutOrder = order, BackgroundTransparency = 0.05, Parent = parent }, function()
		Panels.toggle(panel)
	end)
	UI.label(icon, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 4), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	local caption = UI.label(text, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Font = T.bold, Parent = b })
	UI.fitText(caption, 16, 12)
	local dot = UI.frame({ Name = "Dot", BackgroundColor3 = T.red, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -12, 0, -2), Visible = false, Parent = b })
	UI.corner(dot, 7)
	table.insert(menuButtons, b)
	return b
end

local function statusLine(parent: Instance, order: number, color: Color3): TextLabel
	local l = UI.label("", {
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 18,
		TextColor3 = color,
		Font = T.bold,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	UI.corner(l, 8)
	UI.pad(l, 6)
	return l
end

function Hud.mount(screen: GuiObject, panels: any)
	Panels = panels
	root = UI.frame({ Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })

	local top = UI.new("ScrollingFrame", {
		Name = "Currencies",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 900, 0, 52),
		Parent = root,
	})
	local topList = UI.list(top, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	topList.VerticalAlignment = Enum.VerticalAlignment.Center
	refs.top = top
	refs.coins = topPill(top, "🪙", 1, T.gold)
	refs.aura = topPill(top, "✨", 2, Color3.fromHex("#D4C2FF"))
	refs.rank = topPill(top, "👴", 3, T.text, 210)
	refs.cooler = topPill(top, "🧊", 4, Color3.fromHex("#B9E6FF"))
	refs.boost = topPill(top, "⏩", 5, Color3.fromHex("#B6F0C8"))
	refs.boost.Parent.Visible = false

	local menu = UI.new("ScrollingFrame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Position = UDim2.new(0, 10, 0, 68),
		Size = UDim2.new(0, 108, 0, 560),
		Parent = root,
	})
	refs.menu = menu
	refs.menuList = UI.list(menu, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	refs.btnShop = menuButton(menu, "🛒", "Pit Shop", 1, "shop")
	refs.btnSeason = menuButton(menu, "🎟️", "Season", 2, "season")
	refs.btnSauce = menuButton(menu, "🥫", "Sauce", 3, "sauce")
	refs.btnIndex = menuButton(menu, "📖", "Index", 4, "index")
	refs.btnPath = menuButton(menu, "🗺️", "Path", 5, "path")
	refs.btnUp = menuButton(menu, "⬆️", "Upgrade", 6, "upgrades")
	refs.btnDaily = menuButton(menu, "🎁", "Daily", 7, "daily")
	refs.btnSettings = menuButton(menu, "⚙️", "Settings", 8, "settings")
	refs.btnInvite = menuButton(menu, "👋", "Invite", 9, "invite")

	local right = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -196), Size = UDim2.new(0, 188, 0, 164), Parent = root })
	local rightList = UI.list(right, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
	rightList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.right = right
	refs.rightList = rightList
	refs.serveAll = UI.button("🍽️ Serve All", T.green, { Size = UDim2.new(0, 188, 0, 52), TextSize = 20, LayoutOrder = 1, Parent = right }, function()
		Net.act("ServeAll")
	end)
	refs.collectAll = UI.button("📥 Collect All", T.blue, { Size = UDim2.new(0, 188, 0, 48), LayoutOrder = 2, Parent = right }, function()
		Net.act("CollectAll")
	end)
	refs.homeBtn = UI.button("🏠 Home", T.card, { Size = UDim2.new(0, 140, 0, 44), LayoutOrder = 3, TextSize = 18, Parent = right }, function()
		Panels.goHome()
	end)

	local status = UI.frame({ Name = "Status", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -210, 1, -196), Size = UDim2.new(0, 320, 0, 100), Parent = root })
	UI.list(status, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Right)
	refs.status = status
	refs.rush = statusLine(status, 1, T.gold)
	refs.combo = statusLine(status, 2, Color3.fromHex("#C8F0A8"))
	refs.customers = statusLine(status, 3, T.text)

	local bar = UI.new("ScrollingFrame", {
		Name = "Stations",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 120, 1, -8),
		Size = UDim2.new(1, -330, 0, 176),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 8,
		Parent = root,
	})
	local lay = UI.list(bar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.bar = bar

	refs.first = UI.button("🔥 Smoke your first brisket!", T.accent, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -196), Size = UDim2.new(0, 460, 0, 64), TextSize = 26, Visible = false, Parent = root }, function()
		if Net.act("FirstBrisket") then
			refs.first.Visible = false
		end
	end)
	task.spawn(function()
		while true do
			if refs.first.Visible then
				local base = refs.first:GetAttribute("BaseW") or 460
				local tw = TweenService:Create(refs.first, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Size = UDim2.new(0, base + 16, 0, 68) })
				tw:Play()
				tw.Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)
	refs.hint = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -268),
		Size = UDim2.new(0, 560, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		Font = T.bold,
		TextColor3 = T.ink,
		BackgroundColor3 = T.gold,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = root,
	})
	UI.corner(refs.hint, 10)
	UI.pad(refs.hint, 6)

	Hud.applyLayout()
end

function Hud.applyLayout()
	if not refs.top then
		return
	end
	local v = UI.viewport
	local compact = UI.compact
	local stationH = if compact then 128 else 180
	local actionH = if compact then 48 else 0
	UI.stationReserve = stationH + actionH + (if compact then 12 else 16)
	UI.topChrome = if compact then 108 else 68
	local menuW = if compact then 0 else 112
	local rightW = if compact then 0 else 204

	if compact then
		refs.top.AnchorPoint = Vector2.new(0, 0)
		refs.top.Position = UDim2.new(0, 8, 0, 2)
		refs.top.Size = UDim2.new(1, -16, 0, 46)
		refs.menu.Position = UDim2.new(0, 8, 0, 50)
		refs.menu.Size = UDim2.new(1, -16, 0, 60)
		refs.menu.AutomaticCanvasSize = Enum.AutomaticSize.X
		refs.menu.ScrollingDirection = Enum.ScrollingDirection.X
		refs.menuList.FillDirection = Enum.FillDirection.Horizontal
		for _, b in ipairs(menuButtons) do
			b.Size = UDim2.new(0, 96, 0, 56)
		end
		refs.bar.Position = UDim2.new(0, 8, 1, -6)
		refs.bar.Size = UDim2.new(1, -16, 0, stationH)
		local bw = math.max(UI.TOUCH, math.floor((v.X - 40) / 3))
		refs.right.AnchorPoint = Vector2.new(0, 1)
		refs.right.Position = UDim2.new(0, 8, 1, -(stationH + 10))
		refs.right.Size = UDim2.new(1, -16, 0, 48)
		refs.serveAll.Size = UDim2.fromOffset(bw, 44)
		refs.collectAll.Size = UDim2.fromOffset(bw, 44)
		refs.homeBtn.Size = UDim2.fromOffset(bw, 44)
		refs.rightList.FillDirection = Enum.FillDirection.Horizontal
		refs.rightList.HorizontalAlignment = Enum.HorizontalAlignment.Left
		refs.rightList.VerticalAlignment = Enum.VerticalAlignment.Center
		refs.rush.Parent = refs.top
		refs.combo.Parent = refs.top
		refs.customers.Parent = refs.top
		for index, line in ipairs({ refs.rush, refs.combo, refs.customers }) do
			line.LayoutOrder = 20 + index
			line.Size = UDim2.fromOffset(220, 40)
			line.AutomaticSize = Enum.AutomaticSize.X
		end
		refs.status.Visible = false
	else
		refs.top.AnchorPoint = Vector2.new(0.5, 0)
		refs.top.Position = UDim2.new(0.5, 0, 0, 8)
		refs.top.Size = UDim2.new(0, math.min(980, v.X - 40), 0, 52)
		refs.menu.Position = UDim2.new(0, 10, 0, 68)
		refs.menu.Size = UDim2.new(0, 108, 1, -68 - stationH - 16)
		refs.menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
		refs.menu.ScrollingDirection = Enum.ScrollingDirection.Y
		refs.menuList.FillDirection = Enum.FillDirection.Vertical
		for _, b in ipairs(menuButtons) do
			b.Size = UDim2.new(0, 96, 0, 72)
		end
		refs.bar.Position = UDim2.new(0, menuW + 8, 1, -8)
		refs.bar.Size = UDim2.new(1, -(menuW + rightW + 24), 0, stationH)
		refs.right.AnchorPoint = Vector2.new(1, 1)
		refs.right.Position = UDim2.new(1, -12, 1, -(stationH + 16))
		refs.right.Size = UDim2.new(0, 188, 0, 164)
		refs.serveAll.Size = UDim2.new(0, 188, 0, 52)
		refs.collectAll.Size = UDim2.new(0, 188, 0, 48)
		refs.homeBtn.Size = UDim2.new(0, 140, 0, 44)
		refs.rightList.FillDirection = Enum.FillDirection.Vertical
		refs.rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		refs.rightList.VerticalAlignment = Enum.VerticalAlignment.Bottom
		refs.status.Visible = true
		refs.rush.Parent = refs.status
		refs.combo.Parent = refs.status
		refs.customers.Parent = refs.status
		for index, line in ipairs({ refs.rush, refs.combo, refs.customers }) do
			line.LayoutOrder = index
			line.AutomaticSize = Enum.AutomaticSize.None
			line.Size = UDim2.new(1, 0, 0, 32)
		end
		refs.status.AnchorPoint = Vector2.new(1, 1)
		refs.status.Position = UDim2.new(1, -210, 1, -(stationH + 16))
		refs.status.Size = UDim2.new(0, math.min(360, math.max(160, v.X - 460)), 0, 110)
	end

	local firstW = math.clamp(v.X - 48, 260, 480)
	refs.first:SetAttribute("BaseW", firstW)
	refs.first.Size = UDim2.new(0, firstW, 0, 64)
	refs.first.Position = UDim2.new(0.5, 0, 1, -(stationH + actionH + 78))
	refs.hint.Size = UDim2.new(0, math.clamp(v.X - 48, 240, 640), 0, 44)
	refs.hint.Position = UDim2.new(0.5, 0, 1, -(stationH + actionH + 128))
	for _, c in pairs(cards) do
		styleCard(c)
	end
end

local function slotName(key: string): string
	local n = string.sub(key, 2)
	return (string.sub(key, 1, 1) == "s" and "Smoker " or "Grill ") .. n
end

function styleCard(c)
	local compact = UI.compact
	c.frame.Size = UDim2.new(0, if compact then 158 else 176, 0, if compact then 120 else 168)
	c.title.Size = UDim2.new(1, 0, 0, if compact then 16 else 18)
	c.name.Position = UDim2.new(0, 0, 0, if compact then 16 else 22)
	c.name.Size = UDim2.new(1, c.peek.Visible and -48 or 0, 0, if compact then 20 else 40)
	if c.barBack then
		c.barBack.Position = UDim2.new(0, 0, 0, if compact then 38 else 66)
		c.barBack.Size = UDim2.new(1, 0, 0, if compact then 8 else 12)
	end
	c.time.TextWrapped = not compact
	c.time.Position = UDim2.new(0, 0, 0, if compact then 48 else 82)
	c.time.Size = UDim2.new(1, 0, 0, if compact then 16 else 28)
	c.peek.Position = UDim2.new(1, -44, 0, if compact then 0 else 16)
	c.btn.Position = UDim2.new(0, 0, 1, -44)
	c.btn.Size = UDim2.new(1, 0, 0, 44)
end

local function makeCard(key: string, order: number): any
	local c: any = {}
	local f = UI.frame({ Name = key, BackgroundColor3 = T.bg, BackgroundTransparency = 0.04, Size = UDim2.new(0, 176, 0, 168), LayoutOrder = order, Parent = refs.bar })
	UI.corner(f, 12)
	c.stroke = UI.stroke(f, T.card, 2)
	UI.pad(f, 6)
	c.frame = f
	c.title = UI.label(slotName(key), { Size = UDim2.new(1, 0, 0, 18), TextSize = 16, TextColor3 = T.dim, Font = T.bold, Parent = f })
	c.name = UI.label("Empty", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 40), TextSize = 18, TextWrapped = true, Parent = f })
	local back, fill = UI.bar(f, T.accent, { Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, 0, 0, 12) })
	c.barBack, c.fill = back, fill
	local F = Config.Flip
	c.good = UI.frame({ BackgroundColor3 = T.green, BackgroundTransparency = 0.45, Position = UDim2.fromScale(F.target - F.goodWindow, 0), Size = UDim2.fromScale(F.goodWindow * 2, 1), Visible = false, ZIndex = 2, Parent = back })
	c.perfect = UI.frame({ BackgroundColor3 = T.gold, BackgroundTransparency = 0.15, Position = UDim2.fromScale(F.target - F.perfectWindow, 0), Size = UDim2.fromScale(F.perfectWindow * 2, 1), Visible = false, ZIndex = 3, Parent = back })
	c.time = UI.label("", { Position = UDim2.new(0, 0, 0, 82), Size = UDim2.new(1, 0, 0, 28), TextSize = 16, TextColor3 = T.dim, Font = T.body, Parent = f })
	c.btn = UI.button("Cook", T.accent, { Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 44), TextSize = 18, Parent = f }, function()
		Hud.cardAction(key)
	end)
	c.peek = UI.button("👀", T.card, { Position = UDim2.new(1, -44, 0, 16), Size = UDim2.new(0, 44, 0, 44), TextSize = 18, Visible = false, Parent = f }, function()
		Net.act("Peek", key)
	end)
	styleCard(c)
	return c
end

function Hud.cardAction(key: string)
	local s = Net.state
	if not s then
		return
	end
	local kind = string.sub(key, 1, 1) == "s" and "smoker" or "grill"
	local idx = tonumber(string.sub(key, 2)) or 1
	if idx > s.slots[kind] then
		Panels.open("upgrades")
		return
	end
	local st = s.stations[key]
	if not st then
		Panels.open("cook", key)
		return
	end
	local _, _, done = Hud.view(st, s.boost)
	if done then
		if Net.act("Collect", key) then
			Sfx.play("popAiry", 0.95 + math.random() * 0.15)
		end
	elseif st.meat == "burger" and not st.flip then
		Net.act("Flip", key)
	end
end

local function layoutKey(s: any): string
	return s.slots.smoker .. ":" .. s.slots.grill
end

local function rebuildCards(s: any)
	UI.clear(refs.bar)
	cards = {}
	local order = 0
	for i = 1, Config.MAX_GRILLS do
		order += 1
		local key = "g" .. i
		cards[key] = makeCard(key, order)
		if i > s.slots.grill then
			cards[key].locked = true
		end
		if i > s.slots.grill then
			break
		end
	end
	for i = 1, Config.MAX_SMOKERS do
		order += 1
		local key = "s" .. i
		cards[key] = makeCard(key, order)
		if i > s.slots.smoker then
			cards[key].locked = true
			break
		end
	end
	cardLayoutKey = layoutKey(s)
end

local function showStatus(label: TextLabel, text: string)
	label.Text = text
	label.Visible = text ~= ""
end

function Hud.update()
	local s = Net.state
	if not s or not root then
		return
	end
	if layoutKey(s) ~= cardLayoutKey then
		rebuildCards(s)
	end
	refs.coins.Text = UI.fmt(s.coins)
	refs.aura.Text = UI.fmt(s.aura)
	local rank = Config.Ranks[s.rank]
	refs.rank.Text = (s.title ~= "" and s.title or (rank and rank.name or ""))
	refs.cooler.Text = #s.cooler .. "/" .. Config.COOLER_MAX
	local now = workspace:GetServerTimeNow()
	local boostLeft = s.boost.untilT - now
	refs.boost.Parent.Visible = boostLeft > 0 and s.boost.mult > 1
	if boostLeft > 0 then
		refs.boost.Text = "x" .. s.boost.mult .. " " .. TimeUtil.formatDuration(boostLeft)
	end
	refs.btnDaily.Dot.Visible = s.canClaimDaily
	refs.btnPath.Dot.Visible = s.pathStatus.complete
	local rookieDone = s.rookie == nil or s.rookie.finished
	refs.btnShop.Dot.Visible = rookieDone and not s.boughtAny and s.onceBought ~= nil and not s.onceBought.StarterPitPack and s.productIds.products.StarterPitPack == true
	refs.serveAll.Text = "🍽️ Serve All" .. (#s.customers > 0 and (" (" .. #s.customers .. ")") or "")
	showStatus(refs.customers, #s.customers > 0 and (#s.customers .. " hungry critter" .. (#s.customers == 1 and "" or "s") .. " waiting") or "")
	if s.rush then
		local ends, n, done = s.rush.ends, s.rush.n, s.rush.done
		if now >= ends then
			local P = Config.Rush.period
			ends, n, done = (math.floor(now / P) + 1) * P, 0, false
		end
		local left = math.max(0, math.floor(ends - now))
		local zoom = (s.dinnerUntil or 0) > now and "  🔔 Dinner Bell +25% tips" or ((s.potluckUntil or 0) > now and ("  " .. (s.potluckHud ~= nil and s.potluckHud ~= "" and s.potluckHud or "🦃 Potluck's full: +25% tips")) or "")
		showStatus(refs.rush, (done and "🍽️ Rush cleared! Next in " or string.format("🍽️ Lunch Rush %d/%d · ", n, s.rush.need)) .. TimeUtil.formatDuration(left) .. zoom)
	end
	showStatus(refs.combo, s.combo >= Config.Flip.lockedInAt and ("LOCKED IN 🔒 x" .. s.combo) or (s.combo > 0 and ("Flip combo x" .. s.combo) or ""))

	local firstCooking = false
	local anyDone = false
	for _, st in pairs(s.stations) do
		if st.meat == "firstbrisket" then
			firstCooking = true
		end
		local _, _, done = Hud.view(st, s.boost)
		anyDone = anyDone or done
	end
	refs.first.Visible = not s.tutorial.firstBrisket and not firstCooking and s.stations.s1 == nil
	local hint = ""
	if not s.tutorial.done then
		if firstCooking and not anyDone then
			hint = "Your brisket is smoking low and slow. Grill a burger while you wait."
		elseif anyDone then
			hint = "It's ready. Tap Collect, then serve a critter."
		elseif #s.cooler > 0 then
			hint = "Tap Serve All, or walk up to a critter, to get paid."
		end
	end
	refs.hint.Text = hint
	refs.hint.Visible = hint ~= ""

	local grilling = false
	for key, st in pairs(s.stations) do
		if string.sub(key, 1, 1) == "g" and not st.burnt then
			local _, _, gdone = Hud.view(st, s.boost)
			grilling = grilling or not gdone
		end
	end
	local gtop: BasePart? = nil
	local map = workspace:FindFirstChild("Map")
	local plot = map and s.plot and map:FindFirstChild("Plots") and map.Plots:FindFirstChild("Plot" .. s.plot)
	local grill = plot and plot:FindFirstChild("Grill")
	local top = grill and grill:FindFirstChild("Top")
	if top and top:IsA("BasePart") then
		gtop = top
	end
	Sfx.setSizzle(grilling, gtop)

	for key, c in pairs(cards) do
		local kind = string.sub(key, 1, 1) == "s" and "smoker" or "grill"
		if c.locked then
			c.name.Text = "Locked"
			c.time.Text = "Unlock in Upgrades"
			c.fill.Size = UDim2.fromScale(0, 1)
			c.btn.Text = "Unlock"
			c.btn.BackgroundColor3 = T.card
			c.btn.TextColor3 = UI.labelOn(T.card)
			c.peek.Visible = false
			c.good.Visible = false
			c.perfect.Visible = false
		else
			local st = s.stations[key]
			if not st then
				c.name.Text = kind == "grill" and "Empty grill" or "Empty smoker"
				c.time.Text = kind == "grill" and "Burgers: 30s" or "Low and slow"
				c.fill.Size = UDim2.fromScale(0, 1)
				c.btn.Text = "Cook"
				c.btn.BackgroundColor3 = T.accent
				c.btn.TextColor3 = UI.labelOn(T.accent)
				c.peek.Visible = false
				c.good.Visible = false
				c.perfect.Visible = false
				c.stroke.Color = T.card
			else
				local meat = Config.Meats[st.meat]
				local frac, remaining, done, doneAt = Hud.view(st, s.boost)
				local rarName = ""
				if st.rarity then
					for _, r in ipairs(Config.Rarities) do
						if r.id == st.rarity then
							rarName = r.name .. " "
							c.stroke.Color = Color3.fromHex(r.color)
						end
					end
				else
					c.stroke.Color = T.card
				end
				c.name.Text = meat.icon .. " " .. rarName .. meat.name
				c.fill.Size = UDim2.fromScale(frac, 1)
				c.fill.BackgroundColor3 = done and T.green or T.accent
				local isBurger = st.meat == "burger"
				c.good.Visible = isBurger and not st.flip and not done
				c.perfect.Visible = isBurger and not st.flip and not done
				c.peek.Visible = kind == "smoker" and not done and st.rarity == nil
				if st.burnt then
					c.name.Text = "Burnt " .. meat.name
					c.time.Text = "Skill issue"
					c.btn.Text = "Toss"
					c.btn.BackgroundColor3 = T.red
					c.btn.TextColor3 = UI.labelOn(T.red)
				elseif done then
					if isBurger and doneAt then
						local burnIn = Config.BURGER_BURN_GRACE - (workspace:GetServerTimeNow() - doneAt)
						c.time.Text = burnIn > 0 and string.format("Grab it. Burns in %ds", math.ceil(burnIn)) or "Burning"
					else
						c.time.Text = "Ready to collect"
					end
					c.btn.Text = "Collect"
					c.btn.BackgroundColor3 = T.green
					c.btn.TextColor3 = UI.labelOn(T.green)
				else
					c.time.Text = TimeUtil.formatDuration(remaining) .. " left"
					if isBurger and not st.flip then
						c.btn.Text = "FLIP!"
						local F = Config.Flip
						local near = math.abs(frac - F.target) <= F.perfectWindow
						local fillColor = near and T.gold or T.blue
						c.btn.BackgroundColor3 = fillColor
						c.btn.TextColor3 = UI.labelOn(fillColor)
					else
						c.btn.Text = st.flip and ("Flipped: " .. st.flip) or "Smoking..."
						c.btn.BackgroundColor3 = T.card
						c.btn.TextColor3 = UI.labelOn(T.card)
					end
				end
			end
		end
		c.name.Size = UDim2.new(1, c.peek.Visible and -48 or 0, 0, 40)
	end
end

function Hud.smokerPosition(key: string): Vector3?
	local s = Net.state
	if not s or not s.plot then
		return nil
	end
	local map = workspace:FindFirstChild("Map")
	local plot = map and map:FindFirstChild("Plots") and map.Plots:FindFirstChild("Plot" .. s.plot)
	local sm = plot and plot.Smokers:FindFirstChild(key)
	local barrel = sm and sm:FindFirstChild("Barrel") :: BasePart?
	return barrel and barrel.Position or nil
end

return Hud
