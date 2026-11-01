--!strict
-- The always-on HUD: currencies, menu buttons, the station bar, Serve All / Collect All,
-- and the one-button first cook for brand-new players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)
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

-- Client-side estimate of a cook (the server is the source of truth; this is just for display).
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

local function topPill(parent: Instance, icon: string, order: number, color: Color3): TextLabel
	local f = UI.frame({ BackgroundColor3 = T.bg, BackgroundTransparency = 0.1, Size = UDim2.new(0, 150, 0, 40), LayoutOrder = order, Parent = parent })
	UI.corner(f, 20)
	UI.stroke(f, color, 2)
	UI.label(icon, { Size = UDim2.new(0, 34, 1, 0), Position = UDim2.new(0, 8, 0, 0), TextSize = 22, Parent = f })
	return UI.label("0", { Name = "Value", Size = UDim2.new(1, -48, 1, 0), Position = UDim2.new(0, 42, 0, 0), TextSize = 20, TextColor3 = color, Parent = f })
end

local function menuButton(parent: Instance, icon: string, text: string, order: number, panel: string): TextButton
	local b = UI.button("", T.bg, { Size = UDim2.new(0, 64, 0, 64), LayoutOrder = order, BackgroundTransparency = 0.1, Parent = parent }, function()
		Panels.toggle(panel)
	end)
	UI.label(icon, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 4), TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	UI.label(text, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Parent = b })
	local dot = UI.frame({ Name = "Dot", BackgroundColor3 = T.red, Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -12, 0, -2), Visible = false, Parent = b })
	UI.corner(dot, 7)
	return b
end

function Hud.mount(screen: GuiObject, panels: any)
	Panels = panels
	root = UI.frame({ Name = "Hud", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = screen })

	-- top: currencies
	local top = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.new(0, 860, 0, 44), Parent = root })
	UI.list(top, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	refs.coins = topPill(top, "🪙", 1, T.gold)
	refs.aura = topPill(top, "✨", 2, Color3.fromHex("#B48CFF"))
	refs.rank = topPill(top, "👴", 3, T.text)
	refs.rank.Parent.Size = UDim2.new(0, 190, 0, 40)
	refs.cooler = topPill(top, "🧊", 4, Color3.fromHex("#8FD3FF"))
	refs.boost = topPill(top, "⏩", 5, T.green)
	refs.boost.Parent.Visible = false

	-- left: menu
	local menu = UI.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0.5, -270), Size = UDim2.new(0, 70, 0, 560), Parent = root })
	UI.list(menu, nil, 6)
	refs.btnShop = menuButton(menu, "🛒", "Pit Shop", 1, "shop")
	refs.btnSauce = menuButton(menu, "🥫", "Sauce", 2, "sauce")
	refs.btnIndex = menuButton(menu, "📖", "Index", 3, "index")
	refs.btnPath = menuButton(menu, "🗺️", "Path", 4, "path")
	refs.btnUp = menuButton(menu, "⬆️", "Upgrade", 5, "upgrades")
	refs.btnDaily = menuButton(menu, "🎁", "Daily", 6, "daily")
	refs.btnSettings = menuButton(menu, "⚙️", "Settings", 7, "settings")
	refs.btnInvite = menuButton(menu, "👋", "Invite", 8, "invite")

	-- right: big actions
	local right = UI.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -170), Size = UDim2.new(0, 170, 0, 150), Parent = root })
	UI.list(right, nil, 8, Enum.HorizontalAlignment.Right)
	refs.serveAll = UI.button("🍽️ Serve All", T.green, { Size = UDim2.new(0, 170, 0, 50), TextSize = 20, LayoutOrder = 1, Parent = right }, function()
		Net.act("ServeAll")
	end)
	refs.collectAll = UI.button("📥 Collect All", T.blue, { Size = UDim2.new(0, 170, 0, 44), LayoutOrder = 2, Parent = right }, function()
		Net.act("CollectAll")
	end)
	refs.homeBtn = UI.button("🏠 Home", T.card, { Size = UDim2.new(0, 120, 0, 36), LayoutOrder = 3, TextSize = 16, Parent = right }, function()
		Panels.goHome()
	end)
	refs.customers = UI.label("", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -322), Size = UDim2.new(0, 260, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, TextStrokeTransparency = 0.4, Parent = root })
	refs.rush = UI.label("", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -370), Size = UDim2.new(0, 300, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, TextColor3 = Color3.fromHex("#FFC83C"), TextStrokeTransparency = 0.4, Parent = root })
	refs.combo = UI.label("", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -346), Size = UDim2.new(0, 260, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 18, TextColor3 = Color3.fromHex("#6CC24A"), TextStrokeTransparency = 0.4, Parent = root })

	-- bottom: station bar
	local bar = UI.new("ScrollingFrame", {
		Name = "Stations",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -220, 0, 150),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		Parent = root,
	})
	local lay = UI.list(bar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
	refs.bar = bar

	-- first-cook CTA
	refs.first = UI.button("🔥 Smoke your first brisket!", T.accent, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -176), Size = UDim2.new(0, 380, 0, 64), TextSize = 26, Visible = false, Parent = root }, function()
		if Net.act("FirstBrisket") then
			refs.first.Visible = false
		end
	end)
	task.spawn(function()
		while true do
			if refs.first.Visible then
				local tw = TweenService:Create(refs.first, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Size = UDim2.new(0, 400, 0, 70) })
				tw:Play()
				tw.Completed:Wait()
			else
				task.wait(0.5)
			end
		end
	end)
	refs.hint = UI.label("", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -248), Size = UDim2.new(0, 520, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 20, TextColor3 = T.gold, TextStrokeTransparency = 0.2, Parent = root })
end

local function slotName(key: string): string
	local n = string.sub(key, 2)
	return (string.sub(key, 1, 1) == "s" and "Smoker " or "Grill ") .. n
end

local function makeCard(key: string, order: number): any
	local c: any = {}
	local f = UI.frame({ Name = key, BackgroundColor3 = T.bg, BackgroundTransparency = 0.05, Size = UDim2.new(0, 150, 0, 136), LayoutOrder = order, Parent = refs.bar })
	UI.corner(f, 12)
	c.stroke = UI.stroke(f, T.card, 2)
	UI.pad(f, 6)
	c.frame = f
	c.title = UI.label(slotName(key), { Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = T.dim, Parent = f })
	c.name = UI.label("Empty", { Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 34), TextSize = 15, TextWrapped = true, Parent = f })
	local back, fill = UI.bar(f, T.accent, { Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 10) })
	c.barBack, c.fill = back, fill
	-- flip windows for burgers
	local F = Config.Flip
	c.good = UI.frame({ BackgroundColor3 = T.green, BackgroundTransparency = 0.6, Position = UDim2.fromScale(F.target - F.goodWindow, 0), Size = UDim2.fromScale(F.goodWindow * 2, 1), Visible = false, ZIndex = 2, Parent = back })
	c.perfect = UI.frame({ BackgroundColor3 = T.gold, BackgroundTransparency = 0.2, Position = UDim2.fromScale(F.target - F.perfectWindow, 0), Size = UDim2.fromScale(F.perfectWindow * 2, 1), Visible = false, ZIndex = 3, Parent = back })
	c.time = UI.label("", { Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = T.dim, Parent = f })
	c.btn = UI.button("Cook", T.accent, { Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 38), TextSize = 18, Parent = f }, function()
		Hud.cardAction(key)
	end)
	c.peek = UI.button("👀", T.card, { Position = UDim2.new(1, -38, 0, 14), Size = UDim2.new(0, 36, 0, 30), TextSize = 16, Visible = false, Parent = f }, function()
		Net.act("Peek", key)
	end)
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
		Net.act("Collect", key)
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
			break -- show one locked slot as a teaser
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
	refs.serveAll.Text = "🍽️ Serve All" .. (#s.customers > 0 and (" (" .. #s.customers .. ")") or "")
	refs.customers.Text = #s.customers > 0 and (#s.customers .. " hungry critter" .. (#s.customers == 1 and "" or "s") .. " waiting") or ""
	if s.rush then
		local ends, n, done = s.rush.ends, s.rush.n, s.rush.done
		if now >= ends then -- a new window started since the last snapshot
			local P = Config.Rush.period
			ends, n, done = (math.floor(now / P) + 1) * P, 0, false
		end
		local left = math.max(0, math.floor(ends - now))
		local zoom = (s.dinnerUntil or 0) > now and "  🔔 Dinner Bell +25% tips" or ""
		refs.rush.Text = (done and "🍽️ Rush cleared! Next in " or string.format("🍽️ Lunch Rush %d/%d · ", n, s.rush.need)) .. TimeUtil.formatDuration(left) .. zoom
	end
	refs.combo.Text = s.combo >= Config.Flip.lockedInAt and ("LOCKED IN 🔒 x" .. s.combo) or (s.combo > 0 and ("Flip combo x" .. s.combo) or "")

	-- first cook / tutorial hints
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
	if not s.tutorial.done then
		if firstCooking and not anyDone then
			refs.hint.Text = "Your brisket is smoking low and slow... grill a 🍔 burger while you wait!"
		elseif anyDone then
			refs.hint.Text = "⬇ It's ready! Tap Collect, then Serve a customer."
		elseif #s.cooler > 0 then
			refs.hint.Text = "➡ Tap Serve All (or walk up to a critter) to get paid!"
		else
			refs.hint.Text = ""
		end
	else
		refs.hint.Text = ""
	end

	for key, c in pairs(cards) do
		local kind = string.sub(key, 1, 1) == "s" and "smoker" or "grill"
		if c.locked then
			c.name.Text = "🔒 Locked"
			c.time.Text = "Unlock in Upgrades"
			c.fill.Size = UDim2.fromScale(0, 1)
			c.btn.Text = "Unlock"
			c.btn.BackgroundColor3 = T.card
			c.peek.Visible = false
			c.good.Visible = false
			c.perfect.Visible = false
		else
			local st = s.stations[key]
			if not st then
				c.name.Text = kind == "grill" and "Empty grill" or "Empty smoker"
				c.time.Text = kind == "grill" and "Burgers: 30s" or "Low & slow"
				c.fill.Size = UDim2.fromScale(0, 1)
				c.btn.Text = "Cook"
				c.btn.BackgroundColor3 = T.accent
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
					c.name.Text = "🖤 Burnt " .. meat.name
					c.time.Text = "Skill issue 🤿"
					c.btn.Text = "Toss"
					c.btn.BackgroundColor3 = T.red
				elseif done then
					if isBurger and doneAt then
						local burnIn = Config.BURGER_BURN_GRACE - (workspace:GetServerTimeNow() - doneAt)
						c.time.Text = burnIn > 0 and string.format("Grab it! Burns in %ds", math.ceil(burnIn)) or "Burning!"
					else
						c.time.Text = kind == "smoker" and "Resting in the cooler, ready" or "Ready!"
					end
					c.btn.Text = "Collect"
					c.btn.BackgroundColor3 = T.green
				else
					c.time.Text = TimeUtil.formatDuration(remaining) .. " left"
					if isBurger and not st.flip then
						c.btn.Text = "FLIP!"
						local F = Config.Flip
						local near = math.abs(frac - F.target) <= F.perfectWindow
						c.btn.BackgroundColor3 = near and T.gold or T.blue
					else
						c.btn.Text = st.flip and ("Flipped: " .. st.flip) or "Smoking..."
						c.btn.BackgroundColor3 = T.card
					end
				end
			end
		end
		-- keep the meat name clear of the 👀 peek button in the card's top-right corner
		c.name.Size = UDim2.new(1, c.peek.Visible and -40 or 0, 0, 34)
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
