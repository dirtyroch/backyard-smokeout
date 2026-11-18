--!strict
--[[
	EventService — things that happen to the whole server:
	  * day/night cycle (a full day every 20 minutes),
	  * the co-op Mosquito Swarm at dusk with a Queen Skeeter boss,
	  * the Cook-Off (practice any day, 3x payouts + weekly leaderboard on Saturdays, Texas time),
	  * the monthly season theme on the Cook-Off banner,
	  * Suds Saturday & Sunday announcements,
	  * the Turkey Day Smokeout (Thanksgiving week) and Holiday Smokeout (Dec 19 - Jan 1): potluck
	    table decor + sign, login toast.
]]
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Rarity = require(Shared.Logic.Rarity)
local Economy = require(Shared.Logic.Economy)
local CookOff = require(Shared.Logic.CookOff)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Holiday = require(Shared.Logic.Holiday)
local Guide = require(Shared.Logic.Guide)
local WorldBuilder = require(Shared.WorldBuilder)

local EventService = {}
local ctx: any = nil
local rng = Random.new()

-- ===== Day / night =====
local DAY_SECONDS = Config.DAY_LENGTH_MINUTES * 60
local DUSK = 18.6

function EventService.isNight(): boolean
	local h = Lighting.ClockTime
	return h >= 19 or h < 6
end

local function dayNightLoop()
	local last = Lighting.ClockTime
	while true do
		local dt = task.wait(0.5)
		local h = (Lighting.ClockTime + dt * 24 / DAY_SECONDS) % 24
		Lighting.ClockTime = h
		if last < DUSK and h >= DUSK then
			task.spawn(EventService.startSwarm)
		end
		last = h
	end
end

-- ===== Mosquito swarm =====
local swarm: any = nil

local function rewardSwarm(won: boolean)
	if not swarm then
		return
	end
	for player, hits in pairs(swarm.hits) do
		local data = ctx.Game.dataOf(player)
		if data and player.Parent then
			data.stats.mosquitoes += swarm.kills[player] or 0
			if won and hits > 0 then
				local coins = Config.Mosquito.rewardPerPit * data.pitLevel * Economy.rankMult(data.rank, Config.RANK_STEP)
				ctx.Game.addCoins(player, data, coins, true)
				data.aura += Config.Mosquito.aura
				ctx.Game.toast(player, string.format("Swarm cleared! +%d coins, +%d aura. 🦟💥", math.floor(coins), Config.Mosquito.aura), "good")
			end
			ctx.Game.markDirty(player)
		end
	end
end

function EventService.startSwarm()
	if swarm or #Players:GetPlayers() == 0 then
		return
	end
	local map = ctx.World.map()
	local zone = map.Hub:FindFirstChild("MosquitoZone") :: BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Swarm"
	folder.Parent = workspace
	local count = Config.Mosquito.baseCount + Config.Mosquito.perPlayer * #Players:GetPlayers()
	swarm = { folder = folder, bugs = {}, hits = {}, kills = {}, alive = 0, clicks = {} }
	ctx.Game.announce("🦟 Mosquito swarm at the hub! Swat 'em together (click / tap them)!", "#FF6B6B")
	local center = zone.Position
	local function addBug(queen: boolean)
		local angle = rng:NextNumber() * math.pi * 2
		local radius = queen and 18 or rng:NextNumber(10, 34)
		local height = queen and 16 or rng:NextNumber(6, 16)
		local m, body = WorldBuilder.mosquito(ctx.World.ENV, folder, CFrame.new(center), queen)
		local bug = { model = m, body = body, hp = queen and Config.Mosquito.queenHp + #Players:GetPlayers() * 5 or Config.Mosquito.hp, queen = queen, angle = angle, radius = radius, height = height, speed = (queen and 0.4 or 1) * rng:NextNumber(0.6, 1.2) }
		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 80
		cd.Parent = body
		if queen then
			WorldBuilder.billboard(body, "HP", "👑 Queen Skeeter", 4, 200, "#FF6B6B", 220, 36)
		end
		cd.MouseClick:Connect(function(player)
			-- simple per-player click limiter (max ~8 swats/sec)
			local nowc = os.clock()
			local lastc = swarm and swarm.clicks[player] or 0
			if not swarm or nowc - lastc < 0.12 or bug.hp <= 0 then
				return
			end
			swarm.clicks[player] = nowc
			bug.hp -= 1
			swarm.hits[player] = (swarm.hits[player] or 0) + 1
			if queen then
				local hp = body:FindFirstChild("HP") :: BillboardGui?
				if hp then
					(hp:FindFirstChild("Text") :: TextLabel).Text = "👑 Queen Skeeter " .. string.rep("❤", math.max(0, math.ceil(bug.hp / 5)))
				end
			end
			if bug.hp <= 0 then
				swarm.kills[player] = (swarm.kills[player] or 0) + 1
				swarm.alive -= 1
				m:Destroy()
				ctx.Game.fx(player, "swat", { queen = queen })
				if queen then
					ctx.Game.announce(player.DisplayName .. " landed the final swat on the Queen Skeeter! 👑🦟", "#FF6B6B")
				end
				if swarm.alive <= 0 then
					EventService.endSwarm(true)
				end
			end
		end)
		table.insert(swarm.bugs, bug)
		swarm.alive += 1
	end
	for _ = 1, count do
		addBug(false)
	end
	addBug(true)
	local started = os.clock()
	local s = swarm
	task.spawn(function()
		while swarm == s and os.clock() - started < Config.Mosquito.duration do
			local dt = RunService.Heartbeat:Wait()
			for _, bug in ipairs(s.bugs) do
				if bug.model.Parent then
					bug.angle += dt * bug.speed
					local p = center + Vector3.new(math.cos(bug.angle) * bug.radius, bug.height + math.sin(os.clock() * 3 + bug.angle) * 1.5, math.sin(bug.angle) * bug.radius)
					local look = center + Vector3.new(math.cos(bug.angle + 0.2) * bug.radius, bug.height, math.sin(bug.angle + 0.2) * bug.radius)
					bug.model:PivotTo(CFrame.lookAt(p, look))
				end
			end
		end
		if swarm == s then
			EventService.endSwarm(false)
		end
	end)
end

function EventService.endSwarm(won: boolean)
	if not swarm then
		return
	end
	rewardSwarm(won)
	if not won then
		ctx.Game.announce("The mosquitoes flew off to bother the neighbors. They'll be back at dusk!", "#AAAAAA")
	end
	swarm.folder:Destroy()
	swarm = nil
end

-- ===== Cook-Off =====
local boardStore: any = nil
local nameCache: { [number]: string } = {}

local function weekKey(): string
	return "CookOff_W" .. TimeUtil.weekNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

local function judgedPrice(meatId: string): number
	local meat = Config.Meats[meatId]
	if meat.premium or meatId == "firstbrisket" then
		return Config.Meats.brisket.price -- paid cuts never beat a regular brisket at the judges' table
	end
	return meat.price
end

local function bestEntry(data: any): (number?, number)
	local bestI, bestS = nil, -1
	for i, plate in ipairs(data.cooler) do
		local s = CookOff.score(Rarity.indexOf(Config.Rarities, plate.r), judgedPrice(plate.m), plate.f == "perfect")
		if s > bestS then
			bestI, bestS = i, s
		end
	end
	return bestI, bestS
end
EventService.bestEntry = bestEntry

function EventService.enterCookOff(player: Player)
	local data = ctx.Game.dataOf(player)
	local r = ctx.Game.runtime[player]
	if not data or not r then
		return
	end
	if os.clock() < r.cookoffReadyAt then
		ctx.Game.toast(player, string.format("The judges are still chewing. Try again in %ds.", math.ceil(r.cookoffReadyAt - os.clock())), "info")
		return
	end
	local i, score = bestEntry(data)
	if not i then
		ctx.Game.toast(player, "Bring a plate! Your best plate from the cooler gets judged.", "info")
		return
	end
	r.cookoffReadyAt = os.clock() + Config.CookOff.cooldown
	local plate = table.remove(data.cooler, i)
	local rating = CookOff.rating(Config.CookOff.ratings, score)
	local saturday = ctx.Game.isSaturday()
	local mult = (saturday and Config.CookOff.saturdayMult or 1) * Economy.rankMult(data.rank, Config.RANK_STEP)
	local coins = math.floor(rating.coins * mult)
	ctx.Game.addCoins(player, data, coins, true)
	data.aura += rating.aura
	data.stats.cookoffs += 1
	local lines = Content.GrannyLines[rating.id]
	local meat = Config.Meats[plate.m]
	ctx.Remotes.Push:FireClient(player, "dialog", {
		npc = "Granny Pecan",
		text = string.format("%s\n\nYour %s %s scored %d. Rating: %s!", lines[rng:NextInteger(1, #lines)], Rarity.get(Config.Rarities, plate.r).name, meat.name, score, rating.id),
		reward = coins,
		rating = rating.id,
	})
	if rating.id == "Cooked" then
		ctx.Game.awardBadge(player, "Cooked")
		ctx.Egg.found(player, data, "cooked")
		ctx.Game.announce(string.format("👏 %s COOKED at the Cook-Off! The cat is clapping.", player.DisplayName), "#FFC83C")
		EventService.clapCat()
	end
	if saturday then
		local wk = TimeUtil.weekNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
		if data.cookoff.week ~= wk then
			data.cookoff.week = wk
			data.cookoff.best = 0
		end
		if score > data.cookoff.best then
			data.cookoff.best = score
			if boardStore then
				task.spawn(function()
					pcall(function()
						boardStore:SetAsync(tostring(player.UserId), score)
					end)
				end)
			end
		end
	end
	ctx.World.refreshStations(player)
	ctx.Game.markDirty(player)
end

function EventService.clapCat()
	local cat = ctx.World.map().Hub.CookOff:FindFirstChild("ClapCatJudge") :: Model?
	if not cat then
		return
	end
	local base = cat:GetPivot()
	task.spawn(function()
		for k = 1, 10 do
			cat:PivotTo(base * CFrame.new(0, (k % 2) * 0.5, 0))
			task.wait(0.15)
		end
		cat:PivotTo(base)
	end)
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and n or ("Pitmaster " .. userId)
	return nameCache[userId]
end

-- Final results of a finished week (Sunday: this week, Monday-Friday: last week), cached per week:
-- a finished board never changes, so it's read once (and retried every few minutes if that failed).
local finalCache: { week: number, placings: { CookOff.Placing }?, at: number } = { week = -1, placings = nil, at = -math.huge }

local function readBoard(store: any, count: number): { CookOff.Placing }?
	if not store then
		return nil
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not ok or not pages then
		return nil
	end
	local okP, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	return okP and CookOff.placings(page) or nil
end

local function finalPlacings(): ({ CookOff.Placing }?, number?)
	local offset = CookOff.finalWeekOffset(ctx.Game.weekday())
	if not offset then
		return nil, nil
	end
	local wk = TimeUtil.weekNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS) + offset
	local stale = finalCache.week ~= wk or (finalCache.placings == nil and os.clock() - finalCache.at > 300)
	if stale then
		local store = nil
		local ok, st = pcall(function()
			return DataStoreService:GetOrderedDataStore("CookOff_W" .. wk)
		end)
		if ok then
			store = st
		end
		finalCache = { week = wk, placings = readBoard(store, 10), at = os.clock() }
	end
	return finalCache.placings, wk
end

-- Top 3 of a finished Cook-Off (ties included) earn the free Cook-Off Champ title. Told once per
-- week, when they join or are already in the server once the results are final.
function EventService.champCheck(player: Player)
	local data = ctx.Game.dataOf(player)
	if not data or not player.Parent then
		return
	end
	local placings, wk = finalPlacings()
	if not placings or not wk or data.cookoff.champWeek == wk then
		return
	end
	local place = CookOff.podiumPlace(placings, player.UserId)
	if not place then
		return
	end
	data.cookoff.champWeek = wk
	local B = Content.CookOffBoard
	local had = data.titles[B.title] == true
	data.titles[B.title] = true
	ctx.Game.toast(player, string.format(had and B.champAgain or B.champNote, CookOff.medal(place)), "good")
	ctx.Game.fx(player, "champ", { medal = CookOff.medal(place) })
	ctx.Game.markDirty(player)
end

local function refreshBoard()
	local map = ctx.World.map()
	local lb = map.Hub.CookOff:FindFirstChild("Leaderboard") :: BasePart
	local label = (lb:FindFirstChild("SignGui") :: SurfaceGui):FindFirstChild("BoardText") :: TextLabel
	local season = ctx.Game.currentSeason()
	local B = Content.CookOffBoard
	local mode = CookOff.boardMode(ctx.Game.weekday())
	local placings: { CookOff.Placing }
	if mode == "live" then
		placings = readBoard(boardStore, B.liveRows) or {}
	else
		placings = finalPlacings() or {}
	end
	local nextSat = CookOff.nextSaturday(TimeUtil.dayNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS))
	label.Text = CookOff.boardText(mode, season.name, placings, nameOf, Holiday.longLabel(nextSat), B)
	-- banner reskin by season
	local banner = map.Hub.CookOff:FindFirstChild("Banner") :: BasePart
	banner.Color = Color3.fromHex(season.color)
	local bt = (banner:FindFirstChild("SignGui") :: SurfaceGui):FindFirstChild("BannerText") :: TextLabel
	bt.Text = "🏆 " .. string.upper(season.name) .. (ctx.Game.isSaturday() and " - TODAY! 3x PRIZES" or " - SATURDAY") .. " 🏆"
	if mode ~= "live" then
		for _, player in ipairs(Players:GetPlayers()) do
			EventService.champCheck(player)
		end
	end
end

-- ===== Potluck events: Turkey Day Smokeout and Holiday Smokeout =====
-- The hub potluck table dresses up for whichever event is on (decor is built at runtime and
-- destroyed after), and the sign changes with it.
local potluckOn: string? = nil -- "turkeyday" | "holiday" | "" (none); nil = not set up yet

local function refreshTurkey()
	local EV = ctx.Game.potluckEvent()
	local id = EV and EV.id or ""
	local SOON, _, sw = ctx.Game.upcomingPotluck()
	local soonText: string? = nil
	if not EV and SOON and sw then
		local fmt = SOON.id == "turkeyday" and Content.Signs.turkeySoon or Content.Signs.holidaySoon
		local st = string.format(fmt, string.upper(Holiday.label(sw.startDay)))
		soonText = st
		id = "soon:" .. st
	end
	if id == potluckOn then
		return
	end
	local pot = ctx.World.map().Hub:FindFirstChild("Potluck")
	if not pot then
		return
	end
	potluckOn = id
	local sign = pot:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("Text") :: TextLabel?
	for _, name in ipairs({ "TurkeyDay", "HolidaySmokeout" }) do
		local decor = pot:FindFirstChild(name)
		if decor then
			decor:Destroy()
		end
	end
	local hub = pot.Parent
	local autumn = hub and hub:FindFirstChild("AutumnRanch")
	if autumn then
		autumn:Destroy()
	end
	local text = soonText or Content.Signs.potluck
	if id == "turkeyday" then
		WorldBuilder.turkeyDay(pot, Content)
		if hub then
			WorldBuilder.autumnRanch(hub)
		end
		text = Content.Signs.turkeyPotluck
	elseif id == "holiday" then
		WorldBuilder.holidaySmokeout(pot, Content)
		text = Content.Signs.holidayPotluck
	end
	if label then
		label.Text = text
	end
end
EventService.refreshTurkey = refreshTurkey

-- The banner's second line shows how full the table is, live, for the whole server:
-- "Bring a dish!" -> "Dishes on the table: 2/3" -> "Table's full! +25% tips for everyone".
local function refreshTable()
	local EV, EC = ctx.Game.potluckEvent()
	if not EV or not EC then
		return
	end
	local pot = ctx.World.map().Hub:FindFirstChild("Potluck")
	local decor = pot and pot:FindFirstChild(EV.id == "holiday" and "HolidaySmokeout" or "TurkeyDay")
	local banner = decor and decor:FindFirstChild("Banner")
	local gui = banner and banner:FindFirstChild("SignGui")
	local label = gui and gui:FindFirstChild("BannerText") :: TextLabel?
	if not label then
		return
	end
	local now = workspace:GetServerTimeNow()
	local n = ctx.Egg.potluckCount(now, EV.window)
	local line = Holiday.tableLine(n, EV.need, now < ctx.Game.potluckUntil, math.floor(EV.tipBonus * 100 + 0.5), {
		idle = EC.bannerIdle,
		count = Content.PotluckTable.count,
		full = Content.PotluckTable.full,
	})
	local text = EC.bannerTop .. "\n" .. line
	if label.Text ~= text then
		label.Text = text
	end
end
EventService.refreshTable = refreshTable

-- The event's one-line note: "It's Turkey Day Cookout week!" while it's on, or the calm
-- "Coming up: ... opens Mon, Nov 23" the week before. Sent when a player joins and again at
-- Texas midnight to players already in the server (so nobody misses the day it opens).
-- Returns false while the first-visit guide is on screen, so the note waits until that
-- card is done instead of covering it. Returns true once the note was shown, or when
-- there is nothing to say.
function EventService.eventNote(player: Player): boolean
	local data = ctx.Game.dataOf(player)
	if data and type(data.guide) == "table" and Guide.view(data.guide).active then
		return false
	end
	local _, EC = ctx.Game.potluckEvent()
	if EC then
		ctx.Game.toast(player, EC.login, "good")
		return true
	end
	local _, SC, sw = ctx.Game.upcomingPotluck()
	if SC and sw then
		ctx.Game.toast(player, string.format(SC.soon, Holiday.longLabel(sw.startDay)), "info")
	end
	return true
end

function EventService.init(c: any)
	ctx = c
end

function EventService.start()
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(weekKey())
	end)
	boardStore = ok and store or nil
	task.spawn(dayNightLoop)
	task.spawn(function()
		while true do
			local okT, errT = pcall(function(): any
				refreshTurkey()
				return nil
			end)
			if not okT then
				warn("[EventService] turkey day: " .. tostring(errT))
			end
			local okL, errL = pcall(function(): any
				refreshTable()
				return nil
			end)
			if not okL then
				warn("[EventService] potluck banner: " .. tostring(errL))
			end
			local okB, err = pcall(function(): any
				refreshBoard()
				return nil
			end)
			if not okB then
				warn("[EventService] board: " .. tostring(err))
			end
			task.wait(60)
			-- new week -> new board
			local ok2, st2 = pcall(function()
				return DataStoreService:GetOrderedDataStore(weekKey())
			end)
			if ok2 then
				boardStore = st2
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			pcall(refreshTable)
		end
	end)
	ctx.Data.onLoaded.Event:Connect(function(player: Player)
		task.delay(4, function()
			if not player.Parent then
				return
			end
			if ctx.Game.isSudsWeekend() then
				ctx.Game.toast(player, "🫧 Suds Saturday & Sunday! Muddy pups need a bath. Wash one for a free bandana.", "good")
			end
			if not EventService.eventNote(player) then
				local r = ctx.Game.runtime[player]
				if r then
					r.eventNoteDue = true
				end
			end
			task.spawn(EventService.champCheck, player)
			if ctx.Game.isSaturday() then
				ctx.Game.toast(player, "🏆 It's Cook-Off Saturday! Bring your best plate to Granny Pecan for 3x prizes.", "good")
			end
		end)
	end)
end

return EventService
