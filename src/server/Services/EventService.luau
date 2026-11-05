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

local function refreshBoard()
	local map = ctx.World.map()
	local lb = map.Hub.CookOff:FindFirstChild("Leaderboard") :: BasePart
	local label = (lb:FindFirstChild("SignGui") :: SurfaceGui):FindFirstChild("BoardText") :: TextLabel
	local season = ctx.Game.currentSeason()
	local lines = { season.name .. " - this week", "(Saturdays, Texas time)", "" }
	if boardStore then
		local ok, pages = pcall(function()
			return boardStore:GetSortedAsync(false, 10)
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			for rank, entry in ipairs(page) do
				table.insert(lines, string.format("%d. %s - %d", rank, nameOf(tonumber(entry.key) or 0), entry.value))
			end
		end
	end
	if #lines == 3 then
		table.insert(lines, ctx.Game.isSaturday() and "No entries yet. Be first!" or "Opens Saturday.\nPractice any day!")
	end
	label.Text = table.concat(lines, "\n")
	-- banner reskin by season
	local banner = map.Hub.CookOff:FindFirstChild("Banner") :: BasePart
	banner.Color = Color3.fromHex(season.color)
	local bt = (banner:FindFirstChild("SignGui") :: SurfaceGui):FindFirstChild("BannerText") :: TextLabel
	bt.Text = "🏆 " .. string.upper(season.name) .. (ctx.Game.isSaturday() and " - TODAY! 3x PRIZES" or " - SATURDAY") .. " 🏆"
end

-- ===== Potluck events: Turkey Day Smokeout and Holiday Smokeout =====
-- The hub potluck table dresses up for whichever event is on (decor is built at runtime and
-- destroyed after), and the sign changes with it.
local potluckOn: string? = nil -- "turkeyday" | "holiday" | "" (none); nil = not set up yet

local function refreshTurkey()
	local EV = ctx.Game.potluckEvent()
	local id = EV and EV.id or ""
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
	local text = Content.Signs.potluck
	if id == "turkeyday" then
		WorldBuilder.turkeyDay(pot, Content)
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
	ctx.Data.onLoaded.Event:Connect(function(player: Player)
		task.delay(4, function()
			if not player.Parent then
				return
			end
			if ctx.Game.isSudsWeekend() then
				ctx.Game.toast(player, "🫧 Suds Saturday & Sunday! Muddy pups need a bath. Wash one for a free bandana.", "good")
			end
			local _, EC = ctx.Game.potluckEvent()
			if EC then
				ctx.Game.toast(player, EC.login, "good")
			end
			if ctx.Game.isSaturday() then
				ctx.Game.toast(player, "🏆 It's Cook-Off Saturday! Bring your best plate to Granny Pecan for 3x prizes.", "good")
			end
		end)
	end)
end

return EventService
