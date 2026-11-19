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
local HudMenu = require(Shared.Logic.HudMenu)
local Onboard = require(Shared.Logic.Onboard)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Income = require(Shared.Logic.Income)
local Economy = require(Shared.Logic.Economy)
local Goals = require(Shared.Logic.Goals)
local HudLayout = require(Shared.Logic.HudLayout)
local T = UI.Theme

local Hud = {}
local Panels: any = nil
local root: Frame = nil :: any
local refs: any = {}
local cards: { [string]: any } = {}
local cardLayoutKey = ""
local menuButtons: { Frame } = {}
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

-- Art sits under a childless hit button. Labels used to cover the TextButton,
-- so the click landed on the icon or the caption and Activated never ran.
local function menuButton(parent: Instance, entry: HudMenu.Entry): Frame
	local holder = UI.frame({
		Name = entry.id,
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(0, 96, 0, 72),
		LayoutOrder = entry.order,
		ZIndex = 2,
		Parent = parent,
	})
	UI.corner(holder, 12)
	UI.stroke(holder, T.stroke, 1.5)
	UI.label(entry.icon, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 4), TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = holder })
	local caption = UI.label(entry.label, { Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -28), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Font = T.bold, ZIndex = 3, Parent = holder })
	UI.fitText(caption, 16, 12)
	local dot = UI.frame({ Name = "Dot", BackgroundColor3 = T.red, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -12, 0, -2), Visible = false, ZIndex = 4, Parent = holder })
	UI.corner(dot, 7)
	local hit = UI.button("", T.bg, {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		Text = "",
		ZIndex = HudMenu.HIT_Z,
		Parent = holder,
	}, function()
		Panels.toggle(entry.panel)
	end)
	local stroke = hit:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end
	HudMenu.releaseDecorations(holder)
	hit.MouseEnter:Connect(function()
		holder.BackgroundColor3 = T.cardHi
	end)
	hit.MouseLeave:Connect(function()
		holder.BackgroundColor3 = T.bg
	end)
	hit.MouseButton1Down:Connect(function()
		holder.BackgroundColor3 = T.accent
	end)
	hit.MouseButton1Up:Connect(function()
		holder.BackgroundColor3 = T.cardHi
	end)
	table.insert(menuButtons, holder)
	return holder
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
	local coinPill = UI.frame({ Name = "CoinPill", BackgroundColor3 = T.bg, BackgroundTransparency = 0.05, Size = UDim2.new(0, 220, 0, 48), LayoutOrder = 1, Parent = top })
	UI.corner(coinPill, 16)
	UI.stroke(coinPill, T.gold, 2)
	local coinIcon = UI.coin(coinPill, 28)
	coinIcon.Position = UDim2.new(0, 8, 0.5, -14)
	refs.income = UI.label("+0/s", { Name = "Rate", Size = UDim2.new(1, -48, 0, 26), Position = UDim2.new(0, 42, 0, 1), TextSize = 22, TextColor3 = T.green, Font = T.bold, Parent = coinPill })
	refs.coins = UI.label("0", { Name = "Value", Size = UDim2.new(1, -48, 0, 16), Position = UDim2.new(0, 42, 0, 28), TextSize = 14, TextColor3 = T.gold, Font = T.bold, Parent = coinPill })
	refs.rateScale = UI.new("UIScale", { Name = "Pulse", Scale = 1, Parent = refs.income })
	UI.fitText(refs.income, 26, 16)
	UI.fitText(refs.coins, 16, 12)
	refs.coinPill = coinPill
	refs.shownCoins = 0
	refs.aura = topPill(top, "✨", 2, Color3.fromHex("#D4C2FF"))
	refs.rank = topPill(top, "👴", 3, T.text, 210)
	refs.cooler = topPill(top, "🧊", 4, Color3.fromHex("#B9E6FF"))
	refs.boost = topPill(top, "⏩", 5, Color3.fromHex("#B6F0C8"))
	refs.boost.Parent.Visible = false

	refs.gift = UI.button("Gift", T.green, { Name = "Gift", Size = UDim2.new(0, 120, 0, 44), LayoutOrder = 6, Visible = false, TextSize = 16, Parent = top }, function()
		Net.act("ClaimGift")
	end)

	local goals = UI.frame({
		Name = "Goals",
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.new(0, 460, 0, 44),
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	UI.corner(goals, 12)
	UI.stroke(goals, T.stroke, 1.5)
	refs.goals = goals
	refs.goalTitle = UI.label("Next", { Position = UDim2.new(0, 12, 0, 2), Size = UDim2.new(1, -130, 0, 20), TextSize = 16, Font = T.bold, ZIndex = 4, Parent = goals })
	refs.goalDetail = UI.label("", { Position = UDim2.new(0, 12, 0, 22), Size = UDim2.new(1, -130, 0, 16), TextSize = 13, TextColor3 = T.dim, Font = T.body, ZIndex = 4, Parent = goals })
	local gBack, gFill = UI.bar(goals, T.accent, { Position = UDim2.new(0, 12, 1, -8), Size = UDim2.new(1, -140, 0, 6), ZIndex = 4 })
	refs.goalBack, refs.goalFill = gBack, gFill
	refs.goalBtn = UI.button("Go", T.accent, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 88, 0, 36), TextSize = 16, ZIndex = 5, Parent = goals }, function()
		local action = refs.goalAction
		if action == "gift" then
			Net.act("ClaimGift")
		elseif refs.goalId == "hire" then
			Panels.open("hire")
		elseif action == "crew" or action == "upgrades" then
			Panels.open(action)
		end
	end)

	local menu = UI.new("ScrollingFrame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = HudMenu.SCROLL_Z,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Position = UDim2.new(0, 10, 0, 68),
		Size = UDim2.new(0, 108, 0, 560),
		Parent = root,
	})
	refs.menu = menu
	refs.menuList = UI.list(menu, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	local byId: { [string]: Frame } = {}
	for _, entry in ipairs(HudMenu.entries) do
		byId[entry.id] = menuButton(menu, entry)
	end
	refs.btnShop = byId.shop
	refs.btnSeason = byId.season
	refs.btnSauce = byId.sauce
	refs.btnIndex = byId.index
	refs.btnPath = byId.path
	refs.btnUp = byId.upgrades
	refs.btnCrew = byId.crew
	refs.btnHire = byId.hire
	refs.btnRanch = byId.ranch
	refs.menuById = byId
	refs.btnDaily = byId.daily
	refs.btnSettings = byId.settings
	refs.btnInvite = byId.invite

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
	local pulse = UI.new("UIScale", { Name = "Pulse", Scale = 1, Parent = refs.first })
	task.spawn(function()
		while true do
			if refs.first.Visible then
				local tw = TweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Scale = 1.03 })
				tw:Play()
				tw.Completed:Wait()
			else
				pulse.Scale = 1
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

local function place(gui: GuiObject, b: { x: number, y: number, w: number, h: number })
	local w = math.max(1, UI.viewport.X)
	local h = math.max(1, UI.viewport.Y)
	gui.AnchorPoint = Vector2.new(0, 0)
	if b.w <= 0 or b.h <= 0 then
		gui.Position = UDim2.fromOffset(0, 0)
		gui.Size = UDim2.fromOffset(0, 0)
		return
	end
	gui.Position = UDim2.fromScale(b.x / w, b.y / h)
	gui.Size = UDim2.fromScale(b.w / w, b.h / h)
end

function Hud.layoutOptions(): HudLayout.Options
	local s = Net.state
	local guideOn = s ~= nil and s.guide ~= nil and s.guide.active == true
	return {
		guide = guideOn,
		rookie = s ~= nil and s.rookie ~= nil and s.rookie.finished ~= true and s.tutorial ~= nil and s.tutorial.done == true,
		goals = not guideOn,
		hint = true,
		first = true,
	}
end

function Hud.applyLayout()
	if not refs.top then
		return
	end
	local v = UI.viewport
	local lay = HudLayout.compute(v.X, v.Y, UI.insets, Hud.layoutOptions())
	refs.layout = lay
	local compact = lay.compact
	UI.stationReserve = lay.stations.h + lay.actions.h + 16
	UI.topChrome = (lay.guide.h > 0 and (lay.guide.y + lay.guide.h) or (lay.goals.y + lay.goals.h)) - lay.safe.y
	if UI.topChrome < lay.menu.y then
		UI.topChrome = lay.menu.y + lay.menu.h
	end

	place(refs.top, lay.currencies)
	place(refs.menu, lay.menu)
	place(refs.goals, lay.goals)
	place(refs.bar, lay.stations)
	place(refs.first, lay.first)
	place(refs.hint, lay.hint)
	local pillH = math.max(40, math.min(48, lay.currencies.h))
	refs.coinPill.Size = UDim2.fromOffset(if compact then 176 else 228, pillH)
	for _, child in ipairs(refs.top:GetChildren()) do
		if child:IsA("GuiObject") and child ~= refs.coinPill and not child:IsA("UIListLayout") then
			local wide = child.Size.X.Offset
			if wide < 40 then
				wide = 120
			end
			child.Size = UDim2.fromOffset(wide, pillH)
		end
	end

	if compact then
		refs.menu.AutomaticCanvasSize = Enum.AutomaticSize.X
		refs.menu.ScrollingDirection = Enum.ScrollingDirection.X
		refs.menuList.FillDirection = Enum.FillDirection.Horizontal
		local bw = math.max(UI.TOUCH, math.floor((lay.actions.w - 16) / 3))
		place(refs.right, lay.actions)
		refs.serveAll.Size = UDim2.fromOffset(bw, math.max(44, lay.actions.h - 4))
		refs.collectAll.Size = UDim2.fromOffset(bw, math.max(44, lay.actions.h - 4))
		refs.homeBtn.Size = UDim2.fromOffset(bw, math.max(44, lay.actions.h - 4))
		refs.rightList.FillDirection = Enum.FillDirection.Horizontal
		refs.rightList.HorizontalAlignment = Enum.HorizontalAlignment.Left
		refs.rightList.VerticalAlignment = Enum.VerticalAlignment.Center
		refs.rush.Parent = refs.top
		refs.combo.Parent = refs.top
		refs.customers.Parent = refs.top
		for index, line in ipairs({ refs.rush, refs.combo, refs.customers }) do
			line.LayoutOrder = 20 + index
			line.Size = UDim2.fromOffset(180, math.max(36, pillH - 4))
			line.AutomaticSize = Enum.AutomaticSize.X
		end
		refs.status.Visible = false
	else
		refs.menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
		refs.menu.ScrollingDirection = Enum.ScrollingDirection.Y
		refs.menuList.FillDirection = Enum.FillDirection.Vertical
		place(refs.right, lay.right)
		refs.serveAll.Size = UDim2.fromOffset(math.max(44, lay.right.w), 52)
		refs.collectAll.Size = UDim2.fromOffset(math.max(44, lay.right.w), 48)
		refs.homeBtn.Size = UDim2.fromOffset(math.max(44, lay.right.w - 48), 44)
		refs.rightList.FillDirection = Enum.FillDirection.Vertical
		refs.rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		refs.rightList.VerticalAlignment = Enum.VerticalAlignment.Bottom
		refs.status.Visible = lay.status.h > 0
		refs.rush.Parent = refs.status
		refs.combo.Parent = refs.status
		refs.customers.Parent = refs.status
		for index, line in ipairs({ refs.rush, refs.combo, refs.customers }) do
			line.LayoutOrder = index
			line.AutomaticSize = Enum.AutomaticSize.None
			line.Size = UDim2.new(1, 0, 0, 32)
		end
		place(refs.status, lay.status)
	end
	for _, b in ipairs(menuButtons) do
		b.Size = UDim2.fromOffset(lay.menuButton.w, lay.menuButton.h)
	end
	for _, c in pairs(cards) do
		styleCard(c)
	end
	if UI.onLayout then
		UI.onLayout()
	end
end

function Hud.box(name: string): any
	return refs.layout and refs.layout[name]
end

function Hud.guideTarget(id: string): GuiObject?
	if id == "ranch" then
		return refs.first
	elseif id == "serve" then
		return refs.serveAll
	elseif id == "crew" then
		return refs.btnCrew
	elseif id == "hire" then
		return refs.btnHire
	elseif id == "ranchbuild" then
		return refs.btnRanch
	elseif id == "gift" then
		if refs.gift and refs.gift.Visible then
			return refs.gift
		end
		return refs.btnDaily
	end
	return nil
end

function Hud.reveal(id: string)
	local target = Hud.guideTarget(id)
	if not target or not target.Parent then
		return
	end
	local parent = target.Parent
	if not parent:IsA("ScrollingFrame") then
		return
	end
	local scroller = parent :: ScrollingFrame
	local relX = target.AbsolutePosition.X - scroller.AbsolutePosition.X + scroller.CanvasPosition.X
	local relY = target.AbsolutePosition.Y - scroller.AbsolutePosition.Y + scroller.CanvasPosition.Y
	if scroller.ScrollingDirection == Enum.ScrollingDirection.X then
		scroller.CanvasPosition = Vector2.new(math.max(0, relX - 8), 0)
	else
		scroller.CanvasPosition = Vector2.new(0, math.max(0, relY - 8))
	end
end

local function slotName(key: string): string
	local n = string.sub(key, 2)
	return (string.sub(key, 1, 1) == "s" and "Smoker " or "Grill ") .. n
end

function styleCard(c)
	local compact = UI.compact
	local card = if refs.layout then refs.layout.stationCard else { w = if compact then 158 else 176, h = if compact then 120 else 168 }
	c.frame.Size = UDim2.fromOffset(card.w, card.h)
	if c.ratio then
		c.ratio.AspectRatio = card.w / math.max(1, card.h)
	end
	local nameH = if compact then 20 else 36
	c.title.Size = UDim2.new(1, 0, 0, if compact then 16 else 18)
	c.name.Position = UDim2.new(0, 0, 0, if compact then 16 else 22)
	c.name.Size = UDim2.new(1, c.peek.Visible and -48 or 0, 0, nameH)
	local barY = if compact then 36 else 62
	if c.barBack then
		c.barBack.Position = UDim2.fromOffset(0, barY)
		c.barBack.Size = UDim2.new(1, 0, 0, if compact then 8 else 12)
	end
	c.time.TextWrapped = not compact
	local timeY = barY + (if compact then 10 else 16)
	local btnTop = card.h - 44
	if timeY + 16 > btnTop then
		timeY = math.max(barY + 10, btnTop - 16)
	end
	c.time.Position = UDim2.fromOffset(0, timeY)
	c.time.Size = UDim2.new(1, 0, 0, 16)
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
	c.ratio = UI.new("UIAspectRatioConstraint", { Name = "CardRatio", AspectRatio = 176 / 168, DominantAxis = Enum.DominantAxis.Width, Parent = f })
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
	local targetCoins = s.coins or 0
	if refs.shownCoins == nil then
		refs.shownCoins = targetCoins
	end
	local diff = targetCoins - refs.shownCoins
	if math.abs(diff) < 1 then
		refs.shownCoins = targetCoins
	else
		refs.shownCoins += diff * 0.35
	end
	local shownNow = math.floor(refs.shownCoins + 0.5)
	local coinPop = refs.lastCoin ~= nil and shownNow > refs.lastCoin
	refs.lastCoin = shownNow
	refs.coins.Text = UI.fmt(shownNow)
	local trailing = s.income or 0
	if type(s.earns) == "table" then
		trailing = Income.perSecond(s.earns, workspace:GetServerTimeNow(), Income.WINDOW)
	end
	local crewRate = s.ranchCrew and s.ranchCrew.rate or 0
	local rate = if crewRate > 0 then crewRate else trailing
	refs.income.TextSize = if refs.layout and refs.layout.compact then 20 else 32
	refs.income.Text = "+" .. Income.format(rate) .. "/s"
	if crewRate > 0 and not refs.pulsing and refs.rateScale then
		refs.pulsing = true
		refs.rateTween = TweenService:Create(refs.rateScale, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.22 })
		refs.rateTween:Play()
	elseif crewRate <= 0 and refs.pulsing and refs.rateScale then
		refs.pulsing = false
		if refs.rateTween then
			refs.rateTween:Cancel()
		end
		refs.rateScale.Scale = 1
	end
	if coinPop and refs.rateScale then
		refs.rateScale.Scale = 1.2
	end
	refs.aura.Text = UI.fmt(s.aura)
	local gift = s.freeGift
	refs.gift.Visible = gift ~= nil and gift.ready == true
	if gift and gift.ready then
		refs.gift.Text = "Gift " .. UI.fmt(gift.coins or 0)
	end
	local ranch = s.ranchCrew or {}
	local hireCost, hireName = nil, nil
	local hiring = s.hiring
	if hiring and type(hiring.applicants) == "table" and (ranch.used or 0) < (ranch.slots or 0) then
		for _, applicant in ipairs(hiring.applicants) do
			if not applicant.taken and applicant.price and (hireCost == nil or applicant.price < hireCost) then
				hireCost = applicant.price
				hireName = applicant.name
			end
		end
	end
	local pitCost = Economy.nextPitCost(Config.PitLevels, s.pitLevel)
	local nextPit = pitCost and Config.PitLevels[s.pitLevel + 1] or nil
	local rookieActive = s.rookie ~= nil and s.rookie.finished ~= true
	local guideOn = s.guide ~= nil and s.guide.active == true
	local goal = Goals.next({
		rookieActive = rookieActive,
		giftReady = gift ~= nil and gift.ready == true,
		coins = s.coins or 0,
		hireCost = hireCost,
		hireName = hireName,
		pitCost = pitCost,
		pitName = nextPit and nextPit.name or nil,
		crew = ranch.used or 0,
		crewSlots = ranch.slots or 3,
	})
	refs.goals.Visible = goal ~= nil and not guideOn
	local opts = Hud.layoutOptions()
	local layoutKey = (if opts.guide then "g" else "") .. (if opts.rookie then "r" else "") .. (if opts.goals then "o" else "")
	if refs.layoutKey ~= layoutKey then
		refs.layoutKey = layoutKey
		Hud.applyLayout()
	end
	if goal then
		refs.goalId = goal.id
		refs.goalAction = goal.action
		refs.goalTitle.Text = goal.title
		refs.goalDetail.Text = goal.detail
		refs.goalFill.Size = UDim2.fromScale(if goal.goal > 0 then math.clamp(goal.current / goal.goal, 0, 1) else 0, 1)
		refs.goalBtn.Text = if goal.action == "gift" then "Claim" elseif goal.id == "hire" then "Hire" elseif goal.action == "crew" then "Crew" else "Upgrade"
	end
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
	if s.storm and s.storm.active and type(s.storm.banner) == "string" and s.storm.banner ~= "" then
		showStatus(refs.rush, s.storm.banner)
	elseif Config.Chores.lunchRush and s.rush then
		local ends, n, done = s.rush.ends, s.rush.n, s.rush.done
		if now >= ends then
			local P = Config.Rush.period
			ends, n, done = (math.floor(now / P) + 1) * P, 0, false
		end
		local left = math.max(0, math.floor(ends - now))
		local zoom = (s.dinnerUntil or 0) > now and "  🔔 Dinner Bell +25% tips" or ((s.potluckUntil or 0) > now and ("  " .. (s.potluckHud ~= nil and s.potluckHud ~= "" and s.potluckHud or "🦃 Potluck's full: +25% tips")) or "")
		showStatus(refs.rush, (done and "🍽️ Rush cleared! Next in " or string.format("🍽️ Lunch Rush %d/%d · ", n, s.rush.need)) .. TimeUtil.formatDuration(left) .. zoom)
	else
		local nowBell = workspace:GetServerTimeNow()
		local bell = (s.dinnerUntil or 0) > nowBell and "🔔 Dinner Bell +25% tips" or ((s.potluckUntil or 0) > nowBell and (s.potluckHud ~= nil and s.potluckHud ~= "" and s.potluckHud or "🦃 Potluck's full: +25% tips") or "")
		showStatus(refs.rush, bell)
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
	refs.first.Visible = s.onboard == nil and not s.tutorial.firstBrisket and not firstCooking and s.stations.s1 == nil
	if refs.menuById then
		for id, button in pairs(refs.menuById) do
			button.Visible = Onboard.buttonOn(id, s.playSeconds or 0, s.menuAll == true)
		end
	end
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
				c.peek.Visible = Config.Chores.peekPenalty and kind == "smoker" and not done and st.rarity == nil
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
