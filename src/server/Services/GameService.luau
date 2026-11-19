--!strict
--[[
	GameService — the server-authoritative game loop.
	The client only ever *asks* ("start a cook in slot s2 with ribs"); every rule, timer,
	price, roll and reward is decided here. All requests come through one RemoteFunction,
	are rate-limited per player and per action, and are type-checked before use.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BadgeService = game:GetService("BadgeService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Monetization = require(Shared.Monetization)
local CookLogic = require(Shared.Logic.CookLogic)
local Rarity = require(Shared.Logic.Rarity)
local Economy = require(Shared.Logic.Economy)
local Hype = require(Shared.Logic.Hype)
local Streak = require(Shared.Logic.Streak)
local PitmasterPath = require(Shared.Logic.PitmasterPath)
local Restock = require(Shared.Logic.Restock)
local CookOff = require(Shared.Logic.CookOff)
local RateLimiter = require(Shared.Logic.RateLimiter)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Holiday = require(Shared.Logic.Holiday)
local Rookie = require(Shared.Logic.Rookie)
local MusicPrefs = require(Shared.Logic.MusicPrefs)
local Jimothy = require(Shared.Logic.Jimothy)
local Staff = require(Shared.Logic.Staff)
local Income = require(Shared.Logic.Income)
local FreeGift = require(Shared.Logic.FreeGift)
local Guide = require(Shared.Logic.Guide)
local Crew = require(Shared.Logic.Crew)
local HiringLine = require(Shared.Logic.HiringLine)
local Offline = require(Shared.Logic.Offline)

local GameService = {}
local ctx: any = nil
local rng = Random.new()

type Runtime = {
	plot: number?,
	passes: { [string]: boolean },
	sessionStart: number,
	lastActive: number,
	nudged: boolean,
	dirty: boolean,
	today: number,
	crew: number,
	customers: { any },
	nextCustomerId: number,
	nextSpawn: number,
	lastAutoServe: number,
	snagLockUntil: number,
	snagCooldownUntil: number,
	peaceChangedAt: number,
	resting: boolean,
	cookoffReadyAt: number,
	announcedDone: { [string]: boolean },
	rush: any,
	earns: { any },
	staffNext: { [string]: number },
	staffJob: { [string]: string },
	eventNoteDue: boolean,
	crewBank: number,
	crewNext: { [string]: number },
	offlineCrew: number,
	offlineTipPaid: boolean,
}

GameService.runtime = {} :: { [Player]: Runtime }

local globalLimiter = RateLimiter.new(25, 12) -- any action: burst 25, 12/sec sustained
local actionLimiter = RateLimiter.new(6, 3) -- per (player, action)
local acting: { [Player]: boolean } = {} -- blocks a second remote while the first is yielding

local function T(): number
	return workspace:GetServerTimeNow()
end

local function today(): number
	return TimeUtil.dayNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

local function weekday(): number
	return TimeUtil.weekday(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

GameService.weekday = weekday

function GameService.currentSeason(): any
	return CookOff.seasonFor(Config.Seasons, TimeUtil.month(os.time(), Config.TIMEZONE_OFFSET_HOURS))
end

function GameService.isSaturday(): boolean
	return CookOff.isSaturday(weekday())
end

function GameService.isSudsWeekend(): boolean
	return CookOff.isSudsWeekend(weekday())
end

function GameService.isSunday(): boolean
	return weekday() == 1
end

-- Turkey Day Smokeout window (Thanksgiving week, Texas time). In Studio, the workspace attribute
-- ForceTurkeyDay = true turns it on any day so it can be tested.
function GameService.turkeyWeek(): Holiday.Week
	local w = Holiday.turkeyWeek(today(), Config.TurkeyDay.daysBefore, Config.TurkeyDay.daysAfter)
	if not w.active and RunService:IsStudio() and workspace:GetAttribute("ForceTurkeyDay") == true then
		w.active = true
	end
	return w
end

-- Holiday Smokeout window (Dec 19 - Jan 1, Texas time). In Studio, the workspace attribute
-- ForceHolidaySmokeout = true turns it on any day so it can be tested.
function GameService.holidayWeek(): Holiday.Week
	local H = Config.HolidaySmokeout
	local w = Holiday.dateWindow(today(), H.start, H.finish, H.peak)
	if not w.active and RunService:IsStudio() and workspace:GetAttribute("ForceHolidaySmokeout") == true then
		w.active = true
	end
	return w
end

-- Which date-gated event shops are open right now (Storefront.events).
function GameService.activeEvents(): { [string]: boolean }
	return { [Config.TurkeyDay.id] = GameService.turkeyWeek().active, [Config.HolidaySmokeout.id] = GameService.holidayWeek().active }
end

-- The potluck event that's on right now (config, copy, window), or nil. The dates never overlap;
-- if both are forced on in Studio, Turkey Day wins.
function GameService.potluckEvent(): (any?, any?, Holiday.Week?)
	local tw = GameService.turkeyWeek()
	if tw.active then
		return Config.TurkeyDay, Content.TurkeyDay, tw
	end
	local hw = GameService.holidayWeek()
	if hw.active then
		return Config.HolidaySmokeout, Content.HolidaySmokeout, hw
	end
	return nil, nil, nil
end

-- The potluck event opening within the next `Config.EventTeaserDays` days (config, copy, window),
-- or nil. Nothing is on yet; this only drives a "coming up" sign and a one-line login note.
function GameService.upcomingPotluck(): (any?, any?, Holiday.Week?)
	if GameService.potluckEvent() then
		return nil, nil, nil
	end
	local d = today()
	local tw = GameService.turkeyWeek()
	if Holiday.soon(d, tw, Config.EventTeaserDays) then
		return Config.TurkeyDay, Content.TurkeyDay, tw
	end
	local hw = GameService.holidayWeek()
	if Holiday.soon(d, hw, Config.EventTeaserDays) then
		return Config.HolidaySmokeout, Content.HolidaySmokeout, hw
	end
	return nil, nil, nil
end

local function profileOf(player: Player): any?
	local p = ctx.Data.get(player)
	return p and p.data or nil
end
GameService.dataOf = profileOf

local function rt(player: Player): Runtime?
	return GameService.runtime[player]
end

function GameService.markDirty(player: Player)
	local r = rt(player)
	if r then
		r.dirty = true
	end
end

function GameService.toast(player: Player, text: string, kind: string?)
	ctx.Remotes.Push:FireClient(player, "toast", { text = text, kind = kind or "info" })
end

function GameService.fx(player: Player, kind: string, payload: any?)
	ctx.Remotes.Push:FireClient(player, "fx", { kind = kind, data = payload })
end

function GameService.announce(text: string, color: string?)
	ctx.Remotes.Push:FireAllClients("announce", { text = text, color = color or "#FFC83C" })
end

local function awardBadge(player: Player, key: string)
	local id = (Monetization.Badges :: any)[key]
	if type(id) == "number" and id ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(player.UserId, id)
			end)
		end)
	end
end
GameService.awardBadge = awardBadge

-- Big Bertha's Dinner Bell: a free server-wide tip bonus (set by EggService).
-- The Turkey Day potluck table fills the same way (set by EggService). The two don't stack.
GameService.dinnerUntil = 0
GameService.potluckUntil = 0
GameService.potluckBonus = 0
GameService.potluckHud = ""
function GameService.dinnerBonus(): number
	local now = workspace:GetServerTimeNow()
	local bonus = 0
	if now < GameService.dinnerUntil then
		bonus = Config.DinnerBell.tipBonus
	end
	if now < GameService.potluckUntil then
		bonus = math.max(bonus, GameService.potluckBonus)
	end
	return bonus
end

function GameService.hasPass(player: Player, key: string): boolean
	local r = rt(player)
	return r ~= nil and r.passes[key] == true
end

local function rankMult(data: any): number
	return Economy.rankMult(data.rank, Config.RANK_STEP)
end

local function pit(data: any): any
	return Config.PitLevels[math.clamp(data.pitLevel, 1, #Config.PitLevels)]
end

function GameService.slotCount(player: Player, data: any, kind: string): number
	if kind == "smoker" then
		return Economy.totalSlots(Config.Slots.smoker.base, data.smokerSlotsBought, Config.Slots.smoker.passBonus, GameService.hasPass(player, "ExtraSmokers"), Config.MAX_SMOKERS)
	end
	return Economy.totalSlots(Config.Slots.grill.base, data.grillSlotsBought, Config.Slots.grill.passBonus, false, Config.MAX_GRILLS)
end

local function kindOfKey(key: string): string?
	local c = string.sub(key, 1, 1)
	if c == "s" then
		return "smoker"
	elseif c == "g" then
		return "grill"
	end
	return nil
end

local function validKey(player: Player, data: any, key: any): string?
	if type(key) ~= "string" or #key > 3 or not string.match(key, "^[sg]%d$") then
		return nil
	end
	local kind = kindOfKey(key)
	local idx = tonumber(string.sub(key, 2))
	if not kind or not idx or idx < 1 or idx > GameService.slotCount(player, data, kind) then
		return nil
	end
	return kind
end

function GameService.addCoins(player: Player, data: any, amount: number, earned: boolean, sku: string?)
	amount = math.floor(amount)
	data.coins += amount
	if ctx.Insights and amount ~= 0 then
		ctx.Insights.coins(player, amount, amount > 0 and "Gameplay" or "Shop", sku or (amount > 0 and "Earned" or "Spent"))
	end
	if earned and amount > 0 then
		data.runCoins += amount
		data.lifetimeCoins += amount
		local r = rt(player)
		if r then
			Income.record(r.earns, T(), amount, Income.WINDOW)
		end
	end
	GameService.markDirty(player)
end

local function useSauce(data: any, effect: string): number
	local s = data.sauces[effect]
	if s and s.charges > 0 then
		s.charges -= 1
		local amt = s.amount
		if s.charges <= 0 then
			s.amount = 0
			s.charges = 0
		end
		return amt
	end
	return 0
end

function GameService.addSauce(data: any, sauceId: string)
	local def = Config.Sauces[sauceId]
	if not def then
		return
	end
	local s = data.sauces[def.effect]
	s.amount = math.max(s.amount, def.amount)
	s.charges += def.charges
end

function GameService.grantCosmetic(player: Player, data: any, id: string): boolean
	if not Config.Cosmetics[id] then
		return false
	end
	local isNew = not data.owned[id]
	data.owned[id] = true
	if isNew then
		local def = Config.Cosmetics[id]
		if not data.equipped[def.slot] then
			data.equipped[def.slot] = id
			ctx.Cosmetics.apply(player)
		end
		GameService.markDirty(player)
	end
	return isNew
end

function GameService.addBoost(data: any, minutes: number, mult: number)
	local t = T()
	local b = data.boost
	if b.untilT > t then
		b.untilT += minutes * 60
		b.mult = math.max(b.mult, mult)
	else
		b.untilT = t + minutes * 60
		b.mult = mult
	end
end

-- Advance every cook to `t`. `online` enables burger burning (never happens offline).
local function advanceAll(player: Player, data: any, t: number, online: boolean)
	local speed = pit(data).speed
	local r = rt(player)
	for key, cook in pairs(data.stations) do
		if type(cook) == "table" then
			local wasDone = CookLogic.isDone(cook)
			CookLogic.advance(cook, t, CookLogic.rate(cook, speed), data.boost.mult, data.boost.untilT)
			if online and r then
				if not wasDone and CookLogic.isDone(cook) and not r.announcedDone[key] then
					r.announcedDone[key] = true
					local meat = Config.Meats[cook.meat]
					GameService.toast(player, string.format("%s %s is ready! Collect it.", meat.icon, meat.name), "ready")
					GameService.markDirty(player)
				end
				if kindOfKey(key) == "grill" and cook.meat == "burger" and CookLogic.shouldBurn(cook, t, Config.BURGER_BURN_GRACE) then
					cook.burnt = true
					data.stats.burnt += 1
					data.combo = 0
					GameService.toast(player, Content.Slang.burnt, "bad")
					ctx.World.effect(player, "smell", key)
					GameService.markDirty(player)
				end
			end
		end
	end
end
GameService.advanceAll = advanceAll

local function plateValue(player: Player, data: any, plate: any, critter: any?, orderMatch: boolean, consumeTip: boolean, tipExtra: number?): number
	local meat = Config.Meats[plate.m]
	local rar = Rarity.get(Config.Rarities, plate.r)
	local flipMult = 1
	if meat.station == "grill" and meat.id == "burger" then
		local F = Config.Flip
		flipMult = Economy.flipFactor(plate.f, Config.Chores.flipRequired, F.perfectMult, F.goodMult, F.missMult, F.unflippedMult)
	end
	local r = rt(player)
	return Economy.plateValue(meat.price, {
		rarityMult = rar.mult,
		rankMult = rankMult(data),
		crewMult = Economy.crewMult(r and r.crew or 0, Config.Crew.perFriend, Config.Crew.maxFriends),
		tipMult = (critter and critter.tip or 1) * (tipExtra or 1),
		sauceTip = (consumeTip and useSauce(data, "tip") or 0) + GameService.dinnerBonus(),
		flipMult = flipMult,
		comboMult = Economy.comboMult(data.combo or 0, Config.Flip.comboStep, Config.Flip.comboMax),
		orderBonus = orderMatch and Config.MATCH_ORDER_BONUS or 1,
		doubleTips = GameService.hasPass(player, "DoubleTips"),
		passTipMult = Hype.passTip(true, Config.FairPlay.passTipMult, Config.FairPlay.passTipCap),
	})
end

local function addPlate(data: any, plate: any): boolean
	if #data.cooler >= Config.COOLER_MAX then
		return false
	end
	table.insert(data.cooler, plate)
	return true
end
GameService.addPlate = addPlate

-- ===== Actions =====
local Actions: { [string]: (Player, any, any, any) -> (boolean, string?) } = {}
GameService.Actions = Actions -- other services (Membership) add their actions here in init()

local function meatAvailable(player: Player, data: any, meat: any): (boolean, string?)
	if meat.hidden then
		return false, "Not on the menu."
	end
	if not Holiday.meatOpen(meat, GameService.currentSeason().id, { [Config.TurkeyDay.meat] = GameService.turkeyWeek().active, [Config.HolidaySmokeout.meat] = GameService.holidayWeek().active }) then
		return false, "That's a seasonal cut. It's back next season!"
	end
	if data.pitLevel < meat.unlockPit then
		return false, string.format("Upgrade to %s to smoke that.", Config.PitLevels[meat.unlockPit].name)
	end
	if meat.premium then
		local pass = GameService.hasPass(player, "PremiumCuts")
		local tokens = data.cuts[meat.id] or 0
		local unlocked = meat.id == "tomahawk" and data.unlocks.tomahawk
		if not (pass or tokens > 0 or unlocked) then
			return false, "Premium cut: get it on the Pitmaster Path or in the Pit Shop."
		end
	end
	return true, nil
end

-- opts.quiet: a ranch hand is cooking. Don't spend the player's sauce charges.
-- opts.luckMult: that hand's quality, applied on top of the pit's luck.
function GameService.beginCook(player: Player, data: any, key: any, meatId: any, opts: any?): (boolean, string?)
	opts = opts or {}
	local kind = validKey(player, data, key)
	if not kind or type(meatId) ~= "string" then
		return false, "Bad request."
	end
	local meat = Config.Meats[meatId]
	if not meat or meat.station ~= kind or meat.hidden then
		return false, "That doesn't go there."
	end
	if data.stations[key] then
		return false, "That spot's busy."
	end
	local ok, why = meatAvailable(player, data, meat)
	if not ok then
		return false, why
	end
	local access = {
		pass = meat.premium and GameService.hasPass(player, "PremiumCuts") or false,
		tokens = data.cuts[meat.id] or 0,
		unlocked = meat.id == "tomahawk" and data.unlocks.tomahawk == true or false,
	}
	local bill = Economy.cookBill(meat, data.rank, Config.RANK_STEP, access)
	if not bill.allowed then
		return false, "Premium cut: get it on the Pitmaster Path or in the Pit Shop."
	end
	if data.coins < bill.coins then
		return false, string.format("You need %d coins for that.", bill.coins)
	end
	if bill.coins > 0 then
		GameService.addCoins(player, data, -bill.coins, false, "Meat")
	end
	if bill.usesToken then
		data.cuts[meat.id] = (data.cuts[meat.id] or 0) - 1
	end
	-- Pass and token cooks are a shown purchase, so the rarity is fixed.
	-- Luck cannot change it, and a luck sauce stays in the bottle.
	local paidFixed = Economy.paidCut(meat, access, bill.usesToken)
	local luck = pit(data).luck * (opts.luckMult or 1)
	local speedBonus = 0
	if not opts.quiet then
		if not paidFixed then
			luck *= 1 + useSauce(data, "luck")
		end
		speedBonus = useSauce(data, "speed")
	end
	local rolled = if paidFixed then "smokering" else Rarity.roll(Config.Rarities, luck, meat.maxRarity, rng:NextNumber())
	local rarity = Economy.cookRarity(meat, access, bill.usesToken, rolled)
	local cook = CookLogic.new(meat.id, rarity, meat.cookTime, T(), 1 + speedBonus)
	cook.spentToken = bill.usesToken
	if type(opts.hand) == "string" then
		cook.hand = opts.hand
	elseif opts.quiet then
		cook.hand = "crew"
	end
	data.stations[key] = cook
	data.stats.cooks += 1
	if kind == "smoker" then
		data.stats.smokerStarts += 1
	end
	local r = rt(player)
	if r then
		r.announcedDone[key] = nil
	end
	if not opts.quiet then
		ctx.World.refreshStations(player)
	end
	return true, nil
end

Actions.StartCook = function(player, data, key, meatId)
	return GameService.beginCook(player, data, key, meatId, nil)
end

-- One-button first cook: a 75-second brisket that always comes out Smoke Ring Gold.
Actions.FirstBrisket = function(player, data)
	if data.tutorial.firstBrisket then
		return false, "You already smoked your first brisket!"
	end
	for _, cook in pairs(data.stations) do
		if type(cook) == "table" and cook.meat == "firstbrisket" then
			return false, "It's already smoking!"
		end
	end
	local key = "s1"
	if data.stations[key] then
		return false, "Smoker 1 is busy."
	end
	data.stations[key] = CookLogic.new("firstbrisket", "smokering", Config.Meats.firstbrisket.cookTime, T(), 1)
	data.stats.cooks += 1
	ctx.World.refreshStations(player)
	return true, nil
end

local function collect(player: Player, data: any, key: string): (boolean, string?)
	local cook = data.stations[key]
	if type(cook) ~= "table" then
		return false, "Nothing there."
	end
	if not CookLogic.isDone(cook) then
		return false, "Not ready yet. Low and slow!"
	end
	if cook.burnt then
		data.stations[key] = nil
		ctx.World.refreshStations(player)
		GameService.toast(player, "Tossed the burnt patty. 🤿", "bad")
		return true, nil
	end
	if #data.cooler >= Config.COOLER_MAX then
		return false, "Your cooler's full! Serve some plates first."
	end
	local meatId = cook.meat == "firstbrisket" and "brisket" or cook.meat
	local plate = { m = cook.meat, r = cook.rarity, f = cook.flip }
	if type(cook.hand) == "string" then
		plate.by = "crew"
	end
	addPlate(data, plate)
	data.stations[key] = nil
	local meat = Config.Meats[cook.meat]
	if meat.station == "smoker" then
		data.stats.smoked += 1
	end
	local ri = Rarity.indexOf(Config.Rarities, cook.rarity)
	data.cutsIndex[meatId .. ":" .. cook.rarity] = true
	local rar = Config.Rarities[ri]
	if ri >= 3 then
		data.stats.rares += 1
		awardBadge(player, "FirstRare")
	end
	if rar.flex then
		local label = string.format("%s smoked a %s %s!", player.DisplayName, rar.name, Config.Meats[meatId].name)
		ctx.World.smokeSignal(player, rar.name, rar.color)
		GameService.announce("💨 " .. label, rar.color)
		GameService.fx(player, "reveal", { meat = meatId, rarity = cook.rarity, aura = ri >= 4 and 1000 or 0 })
		if ri >= 4 then
			data.aura += 1000
		end
	end
	if cook.meat == "firstbrisket" then
		data.tutorial.firstBrisket = true
		GameService.toast(player, "Your first brisket came out SMOKE RING GOLD! Serve it to a customer.", "good")
	end
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.Collect = function(player, data, key)
	if not validKey(player, data, key) then
		return false, "Bad request."
	end
	return collect(player, data, key)
end

Actions.CollectAll = function(player, data)
	local any = false
	for key, cook in pairs(data.stations) do
		if type(cook) == "table" and CookLogic.isDone(cook) then
			local ok = collect(player, data, key)
			any = any or ok
		end
	end
	return any, if any then nil else "Nothing's ready yet."
end

Actions.Flip = function(player, data, key)
	local kind = validKey(player, data, key)
	local cook = kind == "grill" and data.stations[key] or nil
	if type(cook) ~= "table" or cook.meat ~= "burger" then
		return false, "No burger there."
	end
	if cook.flip then
		return false, "Already flipped."
	end
	if CookLogic.isDone(cook) then
		return false, "Too late to flip!"
	end
	local F = Config.Flip
	local result = CookLogic.judgeFlip(CookLogic.fraction(cook), F.target, F.perfectWindow, F.goodWindow)
	cook.flip = result
	data.stats.flips += 1
	if result == "perfect" then
		data.combo = math.min((data.combo or 0) + 1, F.comboMax)
		data.stats.perfectFlips += 1
		data.aura += F.perfectAura
		GameService.fx(player, "flip", { result = result, combo = data.combo, lockedIn = data.combo >= F.lockedInAt })
	else
		data.combo = 0
		GameService.fx(player, "flip", { result = result, combo = 0 })
	end
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.Peek = function(player, data, key)
	local kind = validKey(player, data, key)
	local cook = data.stations[key]
	if kind ~= "smoker" or type(cook) ~= "table" or CookLogic.isDone(cook) then
		return false, "Nothing to peek at."
	end
	if cook.revealed then
		return false, "You already peeked."
	end
	local frac = if Config.Chores.peekPenalty then Config.PEEK_PENALTY_FRACTION else 0
	local minimum = if Config.Chores.peekPenalty then Config.PEEK_PENALTY_MIN else 0
	local penalty = CookLogic.peek(cook, frac, minimum)
	local rar = Rarity.get(Config.Rarities, cook.rarity)
	if not Config.Chores.peekPenalty then
		GameService.toast(player, string.format("It's looking %s.", rar.name), "info")
		return true, nil
	end
	GameService.toast(player, string.format("%s (+%s cook time) It's looking %s!", Content.PitmasterScold[rng:NextInteger(1, #Content.PitmasterScold)], TimeUtil.formatDuration(penalty), rar.name), "warn")
	return true, nil
end

-- The player-cooked event plate we leave in the cooler until they've shared today.
-- Crew and Jimothy sell around it. A hand-cooked plate is never the one we hold,
-- and it can't be shared (Holiday.pickPlate).
local function rarityIndex(id: string): number
	return Rarity.indexOf(Config.Rarities, id)
end

local function potluckHeld(data: any): any?
	local EV = GameService.potluckEvent()
	if not EV or type(data.daily) ~= "table" or type(data.cooler) ~= "table" then
		return nil
	end
	local i = Holiday.holdPlate(data.cooler, EV.meat, data.daily[EV.dailyKey] == today(), rarityIndex)
	return if i then data.cooler[i] else nil
end

-- Serving
local function bestPlateIndex(player: Player, data: any, order: string?, held: any?): (number?, boolean)
	local bestI = Holiday.autoPlate(data.cooler, held, function(plate)
		local isMatch = order ~= nil and order ~= "any" and (plate.m == order or (order == "brisket" and plate.m == "firstbrisket"))
		local v = plateValue(player, data, plate, nil, isMatch, false)
		-- prefer matching orders, then highest value
		return v + (if isMatch then 1e9 else 0)
	end)
	if not bestI then
		return nil, false
	end
	local plate = data.cooler[bestI]
	local matched = order ~= nil and order ~= "any" and (plate.m == order or (order == "brisket" and plate.m == "firstbrisket"))
	return bestI, matched
end

local function critterDef(id: string): any
	for _, c in ipairs(Config.Critters) do
		if c.id == id then
			return c
		end
	end
	return Config.Critters[1]
end
GameService.critterDef = critterDef

local function removeCustomer(player: Player, customer: any)
	local r = rt(player)
	if not r then
		return
	end
	for i, c in ipairs(r.customers) do
		if c.id == customer.id then
			table.remove(r.customers, i)
			break
		end
	end
	ctx.World.removeCustomer(player, customer)
	GameService.markDirty(player)
end

function GameService.serveCustomer(player: Player, customer: any, tipExtra: number?, auto: boolean?): (boolean, string?)
	local data = profileOf(player)
	if not data then
		return false, "Loading..."
	end
	-- Automatic servers (crew, Jimothy) leave today's potluck dish. The player's own Serve does not.
	local held = if auto then potluckHeld(data) else nil
	local i, matched = bestPlateIndex(player, data, customer.order, held)
	if not i then
		return false, "Your cooler's empty. Cook something first!"
	end
	local plate = table.remove(data.cooler, i)
	local critter = critterDef(customer.critter)
	local value = plateValue(player, data, plate, critter, matched, true, tipExtra)
	GameService.addCoins(player, data, value, true)
	data.stats.served += 1
	local isNew = (data.critters[critter.id] or 0) == 0
	data.critters[critter.id] = (data.critters[critter.id] or 0) + 1
	if isNew then
		local distinct = 0
		for _ in pairs(data.critters) do
			distinct += 1
		end
		data.stats.critters = distinct
		GameService.addCoins(player, data, Config.NEW_REGULAR_REWARD * rankMult(data), true)
		GameService.toast(player, string.format("New regular! %s joined your Regulars Index.", critter.name), "good")
	end
	if critter.rex then
		GameService.announce(string.format("🦖 Rex visited %s's ranch! RAWR means I love you ♥", player.DisplayName), "#6CC24A")
		ctx.World.smokeSignal(player, "RAWR!", "#6CC24A")
		awardBadge(player, "MetRex")
	end
	if critter.id == "clapcat" then
		ctx.World.effect(player, "clap", customer)
	end
	GameService.fx(player, "served", { value = value, matched = matched, critter = critter.id, aura = plate.f == "perfect" and Config.Flip.perfectAura or 0 })
	-- 6-7!
	if Hype.isSixSeven(value) then
		GameService.fx(player, "sixseven", { value = value })
		ctx.Egg.found(player, data, "sixseven")
	end
	-- Lunch Rush stays in the code for one release. The switch keeps the bonus off.
	local r = rt(player)
	if Config.Chores.lunchRush and r then
		local bonus
		r.rush, bonus = Hype.rushStep(r.rush, T(), Config.Rush.period, Config.Rush.need, Config.Rush.bonusFrac, value)
		if bonus > 0 then
			GameService.addCoins(player, data, bonus, true)
			GameService.fx(player, "rush", { bonus = bonus })
			GameService.toast(player, string.format("🍽️ Lunch Rush cleared! +%d coins", bonus), "good")
		end
	end
	if not data.tutorial.done then
		data.tutorial.done = true
		if not data.rookie.skipped and data.rookie.claimed == 0 then
			ctx.Remotes.Push:FireClient(player, "dialog", { npc = "Unc Hank", text = Content.Rookie.start, reward = 0 })
		end
	end
	GameService.checkRookie(player, data)
	removeCustomer(player, customer)
	return true, nil
end

Actions.Serve = function(player, _data, customerId)
	local r = rt(player)
	if not r or type(customerId) ~= "number" then
		return false, "Bad request."
	end
	for _, c in ipairs(r.customers) do
		if c.id == customerId then
			return GameService.serveCustomer(player, c)
		end
	end
	return false, "They already left."
end

Actions.ServeAll = function(player, data)
	local r = rt(player)
	if not r then
		return false, nil
	end
	if #r.customers == 0 then
		return false, "No customers yet. They'll show up soon!"
	end
	local served = 0
	local list = table.clone(r.customers)
	for _, c in ipairs(list) do
		if #data.cooler == 0 then
			break
		end
		local ok = GameService.serveCustomer(player, c)
		if ok then
			served += 1
		end
	end
	if served == 0 then
		return false, "Your cooler's empty. Cook something first!"
	end
	return true, nil
end

function GameService.bellyRub(player: Player, customer: any)
	local data = profileOf(player)
	if not data or customer.rubbed then
		return
	end
	customer.rubbed = true
	local tip = math.floor(25 * data.pitLevel * rankMult(data))
	GameService.addCoins(player, data, tip, true)
	data.aura += 50
	GameService.toast(player, string.format("%s +%d tip.", Content.YardNotes.pup, tip), "good")
	ctx.World.effect(player, "bellyrub", customer)
end

function GameService.washPup(player: Player, customer: any)
	local data = profileOf(player)
	if not data or not customer.muddy then
		return
	end
	customer.muddy = false
	local pick = Rarity.pickWeighted(Config.Bandanas, rng:NextNumber())
	local isNew = GameService.grantCosmetic(player, data, pick.id)
	local name = Config.Cosmetics[pick.id].name
	GameService.toast(player, isNew and ("Squeaky clean! The pup gave you a " .. name .. "!") or ("Squeaky clean! (" .. name .. " again, +100 coins)"), "good")
	if not isNew then
		GameService.addCoins(player, data, 100, true)
	end
	ctx.World.effect(player, "wash", customer)
	GameService.markDirty(player)
end

Actions.BuySauce = function(player, data, sauceId)
	if type(sauceId) ~= "string" then
		return false, "Bad request."
	end
	local def = Config.Sauces[sauceId]
	if not def or def.hidden then
		return false, "Not for sale."
	end
	local window = Restock.window(os.time(), Config.RESTOCK_SECONDS)
	if data.restock.window ~= window then
		data.restock.window = window
		data.restock.bought = {}
	end
	local shelf = Restock.shelf(window, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)
	local qty = 0
	for _, e in ipairs(shelf) do
		if e.id == sauceId then
			qty = e.qty
		end
	end
	local bought = data.restock.bought[sauceId] or 0
	if bought >= qty then
		return false, "Sold out! New sauce in " .. TimeUtil.formatDuration(Restock.nextIn(os.time(), Config.RESTOCK_SECONDS)) .. "."
	end
	local price = math.floor(def.price * (1 + (rankMult(data) - 1) * 0.5))
	if data.coins < price then
		return false, string.format("You need %d coins.", price)
	end
	GameService.addCoins(player, data, -price, false, "Sauce")
	data.restock.bought[sauceId] = bought + 1
	GameService.addSauce(data, sauceId)
	data.stats.sauces += 1
	GameService.toast(player, string.format("Got %s! (%d charges)", def.name, def.charges), "good")
	return true, nil
end

Actions.UpgradePit = function(player, data)
	local cost = Economy.nextPitCost(Config.PitLevels, data.pitLevel)
	if not cost then
		return false, "Your pit is maxed out. Time for Unc Status?"
	end
	if data.coins < cost then
		return false, string.format("You need %d coins.", cost)
	end
	GameService.addCoins(player, data, -cost, false, "PitUpgrade")
	data.pitLevel += 1
	data.stats.upgrades += 1
	GameService.toast(player, "Pit upgraded to " .. pit(data).name .. "!", "good")
	GameService.fx(player, "levelup", { text = "Pit upgraded to " .. pit(data).name .. "!" })
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.BuySlot = function(player, data, kind)
	if kind ~= "smoker" and kind ~= "grill" then
		return false, "Bad request."
	end
	local def = Config.Slots[kind]
	local boughtKey = kind == "smoker" and "smokerSlotsBought" or "grillSlotsBought"
	local cap = kind == "smoker" and Config.MAX_SMOKERS or Config.MAX_GRILLS
	if GameService.slotCount(player, data, kind) >= cap then
		return false, "No more room!"
	end
	local cost = Economy.nextSlotCost(def.costs, data[boughtKey])
	if not cost then
		return false, "No more slots to buy."
	end
	if data.coins < cost then
		return false, string.format("You need %d coins.", cost)
	end
	GameService.addCoins(player, data, -cost, false, "Slot")
	data[boughtKey] += 1
	data.stats.upgrades += 1
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.Rebirth = function(player, data)
	local ok, need = Economy.canRebirth(Config.Ranks, data.rank, data.runCoins)
	if not ok then
		return false, need and string.format("Earn %d coins this run to rebirth.", need) or "You're already OG."
	end
	-- Finished food goes to the cooler; unfinished cooks are refunded. Nothing is lost.
	local refund = 0
	for key, cook in pairs(data.stations) do
		if type(cook) == "table" then
			if CookLogic.isDone(cook) and not cook.burnt then
				addPlate(data, { m = cook.meat, r = cook.rarity, f = cook.flip })
			elseif not CookLogic.isDone(cook) then
				local m = Config.Meats[cook.meat]
				if m then
					-- Coin cost comes back for every cut, including premium. A token
					-- comes back only if this cook actually spent one.
					refund += Economy.rawCost(m, rankMult(data))
					if cook.spentToken and m.premium then
						data.cuts[m.id] = (data.cuts[m.id] or 0) + 1
					end
				end
			end
		end
		data.stations[key] = nil
	end
	data.rank += 1
	data.coins = Config.START_COINS + refund
	data.runCoins = 0
	data.pitLevel = 1
	data.smokerSlotsBought = 0
	data.grillSlotsBought = 0
	local rank = Config.Ranks[data.rank]
	data.titles[rank.name] = true
	data.title = rank.name
	if rank.unlock then
		GameService.grantCosmetic(player, data, rank.unlock)
		GameService.toast(player, Content.Slang.unclocked, "good")
	end
	GameService.announce(string.format("👴 %s reached Unc Status: %s!", player.DisplayName, rank.name), "#FFC83C")
	ctx.World.refreshStations(player)
	ctx.Cosmetics.apply(player)
	return true, nil
end

function GameService.applyReward(player: Player, data: any, reward: any)
	if reward.coins then
		GameService.addCoins(player, data, reward.coins * rankMult(data), true)
	end
	if reward.sauce then
		GameService.addSauce(data, reward.sauce)
	end
	if reward.cosmetic then
		GameService.grantCosmetic(player, data, reward.cosmetic)
	end
	if reward.boostMinutes then
		GameService.addBoost(data, reward.boostMinutes, 2)
	end
	if reward.wagyu then
		data.cuts.wagyu = (data.cuts.wagyu or 0) + reward.wagyu
	end
	if reward.title then
		data.titles[reward.title] = true
	end
	if reward.rex then
		data.forceCritter = "rex"
	end
	if reward.tomahawk then
		data.unlocks.tomahawk = true
	end
	GameService.markDirty(player)
end

Actions.ClaimDaily = function(player, data)
	local d = today()
	Streak.healClock(data.streak, d)
	if not Streak.canClaim(data.streak, d) then
		return false, "Already claimed today. See you tomorrow!"
	end
	local res = Streak.claim(data.streak, d)
	if not res.ok then
		return false, "Already claimed."
	end
	local reward = Config.DailyRewards[res.cycleDay]
	local scaled = table.clone(reward)
	scaled.coins = math.floor((reward.coins or 0) * Streak.rewardScale(res.count))
	local paid = Streak.payout(reward.coins or 0, res.count, rankMult(data))
	GameService.applyReward(player, data, scaled)
	local note = ""
	if res.usedFreeMiss then
		note = " (Your free miss for the week saved your streak!)"
	elseif res.softReset then
		note = " (Welcome back! You kept your week.)"
	end
	GameService.toast(player, string.format("Day %d streak! +%d coins%s", res.count, paid, note), "good")
	GameService.fx(player, "levelup", { text = string.format("Day %d! +%d", res.count, paid) })
	return true, nil
end

Actions.ClaimGift = function(player, data)
	Staff.normalize(data)
	local now = os.time()
	FreeGift.normalize(data.freeGift, now)
	if not FreeGift.claim(data.freeGift, now) then
		return false, "Your free gift isn't ready yet."
	end
	local amount = FreeGift.payout(rankMult(data))
	GameService.addCoins(player, data, amount, true, "FreeGift")
	GameService.toast(player, string.format("Free gift! +%d coins", amount), "good")
	GameService.fx(player, "freegift", { value = amount })
	return true, nil
end

Actions.HireStaff = function(player, data)
	if not Config.Chores.legacyStaff then
		return false, "Hire from the Hiring Line in the town square."
	end
	Staff.normalize(data)
	local outcome = Staff.tryHire(data.staff.roster, data.pitLevel, data.coins)
	if not outcome.ok or not outcome.employee or not outcome.cost then
		return false, Staff.hireMessage(outcome.reason, outcome.cost)
	end
	local hire = outcome.employee
	if Staff.find(data.staff.roster, hire.id) then
		return false, "They're already on the crew."
	end
	local before = data.coins
	GameService.addCoins(player, data, -outcome.cost, false, "Staff")
	if data.coins < 0 or data.coins ~= data.coins then
		data.coins = before
		return false, Staff.hireMessage("coins", outcome.cost)
	end
	table.insert(data.staff.roster, hire)
	local r = rt(player)
	if r then
		r.staffNext[hire.id] = T() + 2
		r.staffJob[hire.id] = "idle"
	end
	GameService.toast(player, hire.name .. " clocked in!", "good")
	local hand = Staff.hand(hire.id)
	GameService.fx(player, "hired", { name = hire.name, title = if hand then hand.title else "Crew" })
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.UpgradeStaff = function(player, data, id, stat)
	if not Config.Chores.legacyStaff then
		return false, "Level your crew from the Crew panel."
	end
	Staff.normalize(data)
	local outcome = Staff.tryUpgrade(data.staff.roster, id, stat, data.coins)
	if not outcome.ok or not outcome.stat or not outcome.cost or not outcome.level or outcome.from == nil then
		return false, Staff.upgradeMessage(outcome.reason, outcome.cost)
	end
	local e = Staff.find(data.staff.roster, id)
	if not e or e[outcome.stat] ~= outcome.from then
		return false, Staff.upgradeMessage("max", nil)
	end
	local before = data.coins
	GameService.addCoins(player, data, -outcome.cost, false, "Staff")
	if data.coins < 0 or data.coins ~= data.coins then
		data.coins = before
		return false, Staff.upgradeMessage("coins", outcome.cost)
	end
	e[outcome.stat] = outcome.level
	local label = if outcome.stat == "speed" then "Speed" elseif outcome.stat == "capacity" then "Carry" else "Quality"
	GameService.toast(player, string.format("%s's %s is now %d.", e.name, label, e[outcome.stat]), "good")
	GameService.fx(player, "levelup", { text = e.name .. " " .. label .. " " .. outcome.level })
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.GuideSkip = function(player, data)
	if type(data.guide) ~= "table" then
		data.guide = Guide.new()
	end
	if not Guide.skip(data.guide) then
		return false, "You're already all set."
	end
	GameService.toast(player, "Hints tucked away. Have fun at the ranch.", "info")
	return true, nil
end

Actions.ClaimPath = function(player, data)
	local ok, reward = PitmasterPath.claim(data.path, Config.PathSteps, data.stats)
	if not ok then
		return false, "Not done yet!"
	end
	GameService.applyReward(player, data, reward)
	GameService.toast(player, "Pitmaster Path step " .. data.path.claimed .. " complete!", "good")
	return true, nil
end

Actions.HearJoke = function(player, data)
	local d = today()
	local joke = Content.UncJokes[(d % #Content.UncJokes) + 1]
	local first = data.daily.jokeDay ~= d
	if first then
		data.daily.jokeDay = d
		GameService.addCoins(player, data, 50 * rankMult(data), true)
	end
	ctx.Remotes.Push:FireClient(player, "dialog", { npc = "Unc Hank", text = "Hi Hungry, I'm Unc! " .. joke, yap = Content.UncYap[rng:NextInteger(1, #Content.UncYap)], reward = first and math.floor(50 * rankMult(data)) or 0 })
	return true, nil
end

Actions.Equip = function(player, data, slot, cosmeticId)
	if type(slot) ~= "string" or not table.find(Config.CosmeticSlots, slot) then
		return false, "Bad request."
	end
	if cosmeticId == "" or cosmeticId == nil then
		data.equipped[slot] = nil
	else
		if type(cosmeticId) ~= "string" or not data.owned[cosmeticId] then
			return false, "You don't own that."
		end
		local def = Config.Cosmetics[cosmeticId]
		if not def or def.slot ~= slot then
			return false, "Wrong slot."
		end
		data.equipped[slot] = cosmeticId
	end
	ctx.Cosmetics.apply(player)
	ctx.World.refreshStations(player)
	return true, nil
end

Actions.SetTitle = function(player, data, title)
	if title == "" then
		data.title = ""
		ctx.Cosmetics.apply(player)
		return true, nil
	end
	if type(title) ~= "string" or not data.titles[title] then
		return false, "You haven't earned that title."
	end
	data.title = title
	ctx.Cosmetics.apply(player)
	return true, nil
end

-- Unc's Rookie List: skip it (the client asks first), or bring it back from Settings > Game.
Actions.RookieSkip = function(player, data)
	if not Rookie.skip(data.rookie, Config.RookieSteps) then
		return false, "Your Rookie List is already done or tucked away."
	end
	GameService.toast(player, Content.Rookie.skipped, "info")
	GameService.markDirty(player)
	return true, nil
end

Actions.RookieResume = function(player, data)
	if not Rookie.resume(data.rookie, Config.RookieSteps) then
		return false, "Your Rookie List is already showing (or done)."
	end
	GameService.toast(player, Content.Rookie.resumed, "good")
	GameService.checkRookie(player, data)
	GameService.markDirty(player)
	return true, nil
end

Actions.SetPeace = function(player, data, on)
	local r = rt(player)
	if type(on) ~= "boolean" or not r then
		return false, "Bad request."
	end
	local t = os.clock()
	if t - r.peaceChangedAt < 60 then
		return false, "You can switch Peace Mode once a minute."
	end
	if t < r.snagCooldownUntil - Config.Snag.cooldown + Config.Snag.catchWindow then
		return false, "Not while you're on the run!"
	end
	r.peaceChangedAt = t
	data.settings.peace = on
	GameService.toast(player, on and "Peace Mode on: nobody can snag your plates (and you can't snag theirs)." or "Peace Mode off. Watch your plates!", "info")
	return true, nil
end

Actions.SetSfx = function(_player, data, on)
	if type(on) ~= "boolean" then
		return false, "Bad request."
	end
	data.settings.sfx = on
	return true, nil
end

-- Music mute is saved on its own. It does not change the sound-effect switch.
Actions.SetMusic = function(_player, data, on)
	if type(on) ~= "boolean" then
		return false, "Bad request."
	end
	data.settings.music = on
	return true, nil
end

-- Volume is saved even while muted, so unmuting comes back to this level.
Actions.SetMusicVolume = function(_player, data, volume)
	if type(volume) ~= "number" then
		return false, "Bad request."
	end
	data.settings.musicVolume = MusicPrefs.clamp(volume)
	return true, nil
end

Actions.SetResting = function(player, _data, on)
	local r = rt(player)
	if type(on) ~= "boolean" or not r then
		return false, nil
	end
	r.resting = on
	ctx.Cosmetics.apply(player)
	return true, nil
end

Actions.Prompt = function(player, _data, kind, key)
	if (kind ~= "product" and kind ~= "pass") or type(key) ~= "string" then
		return false, "Bad request."
	end
	return ctx.Purchase.prompt(player, kind, key)
end

-- Analytics only: which shop tab was opened (nothing changes for the player).
Actions.ShopView = function(player, _data, tab)
	if type(tab) ~= "string" or #tab > 24 then
		return false, nil
	end
	if tab == "" then
		ctx.Insights.shopOpened(player)
	else
		ctx.Insights.shopTab(player, tab)
	end
	return true, nil
end

Actions.Gift = function(player, _data, key, recipientUserId)
	if type(key) ~= "string" or type(recipientUserId) ~= "number" then
		return false, "Bad request."
	end
	return ctx.Purchase.promptGift(player, key, recipientUserId)
end

Actions.Hello = function(player, _data)
	GameService.markDirty(player)
	return true, nil
end

-- ===== Snapshot sent to the client =====
local function snapshot(player: Player, data: any): any
	local r = rt(player) :: Runtime
	local t = T()
	local stations = {}
	for key, cook in pairs(data.stations) do
		if type(cook) == "table" then
			local done = CookLogic.isDone(cook)
			stations[key] = {
				meat = cook.meat,
				progress = cook.progress,
				duration = cook.duration,
				last = cook.last,
				rate = CookLogic.rate(cook, pit(data).speed),
				doneAt = cook.doneAt,
				flip = cook.flip,
				burnt = cook.burnt,
				rarity = (done or cook.revealed) and cook.rarity or nil,
			}
		end
	end
	local window = Restock.window(os.time(), Config.RESTOCK_SECONDS)
	local bought = data.restock.window == window and data.restock.bought or {}
	local customers = {}
	for _, c in ipairs(r.customers) do
		table.insert(customers, { id = c.id, critter = c.critter, order = c.order, muddy = c.muddy, leaveAt = c.leaveAt })
	end
	local week = TimeUtil.weekNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
	return {
		t = t,
		coins = data.coins,
		runCoins = data.runCoins,
		aura = data.aura,
		rank = data.rank,
		pitLevel = data.pitLevel,
		slots = { smoker = GameService.slotCount(player, data, "smoker"), grill = GameService.slotCount(player, data, "grill") },
		bought = { smoker = data.smokerSlotsBought, grill = data.grillSlotsBought },
		stations = stations,
		cooler = data.cooler,
		sauces = data.sauces,
		boost = data.boost,
		cuts = data.cuts,
		unlocks = data.unlocks,
		owned = data.owned,
		equipped = data.equipped,
		titles = data.titles,
		title = data.title,
		critters = data.critters,
		cutsIndex = data.cutsIndex,
		eggs = data.eggs,
		jimothy = {
			n = Jimothy.count(type(data.jimothy) == "table" and data.jimothy.seen or nil),
			total = Jimothy.total(),
		},
		stats = data.stats,
		streak = data.streak,
		canClaimDaily = Streak.canClaim(data.streak, today()),
		path = data.path,
		pathStatus = PitmasterPath.status(data.path, Config.PathSteps, data.stats),
		restock = { window = window, shelf = Restock.shelf(window, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS), bought = bought, nextIn = Restock.nextIn(os.time(), Config.RESTOCK_SECONDS) },
		cookoff = data.cookoff,
		settings = data.settings,
		tutorial = data.tutorial,
		rookie = Rookie.status(data.rookie, Config.RookieSteps, data.stats),
		passes = r.passes,
		customers = customers,
		combo = data.combo,
		income = Income.perSecond(r.earns, t, Income.WINDOW),
		earns = r.earns,
		today = today(),
		staff = {
			slots = Staff.slots(data.pitLevel),
			roster = data.staff.roster,
			waiter = r.passes.AutoServe == true,
		},
		freeGift = (function()
			local giftNow = os.time()
			FreeGift.normalize(data.freeGift, giftNow)
			return {
				ready = FreeGift.ready(data.freeGift.nextAt, giftNow),
				nextAt = data.freeGift.nextAt,
				coins = FreeGift.payout(rankMult(data)),
			}
		end)(),
		guide = if type(data.guide) == "table" then Guide.view(data.guide) else { active = false },
		crew = r.crew,
		rush = (function()
			local w = Hype.rushWindow(T(), Config.Rush.period)
			local cur = (r.rush and r.rush.w == w) and r.rush or nil
			return { n = cur and cur.n or 0, need = Config.Rush.need, done = cur ~= nil and cur.done, ends = Hype.rushEnds(w, Config.Rush.period) }
		end)(),
		dinnerUntil = GameService.dinnerUntil,
		potluckUntil = GameService.potluckUntil,
		potluckHud = GameService.potluckHud,
		turkey = (function()
			local w = GameService.turkeyWeek()
			return { active = w.active, isDay = w.isDay, ends = Holiday.label(w.endDay), shared = data.daily.turkeyDay == today() }
		end)(),
		holiday = (function()
			local w = GameService.holidayWeek()
			return { active = w.active, isDay = w.isDay, ends = Holiday.label(w.endDay), shared = data.daily.holidayDay == today() }
		end)(),
		season = GameService.currentSeason(),
		saturday = GameService.isSaturday(),
		suds = GameService.isSudsWeekend(),
		rotation = CookOff.rotation(Config.RotationPool, Config.ROTATION_FEATURED, week),
		memoryOnly = RunService:IsStudio() and ctx.Data.isStudioMemoryMode(player),
		degraded = (not RunService:IsStudio()) and ctx.Data.isStudioMemoryMode(player),
		studio = RunService:IsStudio(),
		productIds = ctx.Purchase.availability(),
		giftsHeld = data.giftsHeld,
		onceBought = data.purchases.once,
		boughtAny = data.purchases.count > 0,
		hiring = (function()
			local line = if ctx.Crew and ctx.Crew.line then ctx.Crew.line() else nil
			local rows = {}
			if type(line) == "table" and type(line.applicants) == "table" then
				for _, applicant in ipairs(line.applicants) do
					table.insert(rows, {
						index = applicant.index,
						name = applicant.name,
						rarityName = applicant.rarityName,
						color = applicant.color,
						roleName = applicant.roleName,
						trait = applicant.trait,
						traitName = applicant.traitName,
						rate = applicant.rate,
						price = applicant.price,
						line = applicant.line,
						taken = line.taken[applicant.index] ~= nil,
					})
				end
			end
			return {
				clock = HiringLine.clockLabel(os.time(), Config.Hiring.period, Config.TIMEZONE_OFFSET_HOURS),
				applicants = rows,
			}
		end)(),
		ranchCrew = Crew.view(data, GameService.crewMults(player, data)),
		seasonPass = ctx.Season.snapshot(data),
		member = ctx.Membership.snapshot(player, data),
		plot = r.plot,
	}
end

function GameService.push(player: Player)
	local data = profileOf(player)
	local r = rt(player)
	if not data or not r then
		return
	end
	r.dirty = false
	ctx.Remotes.Push:FireClient(player, "state", snapshot(player, data))
end

-- ===== Customers =====
local function spawnCustomer(player: Player, data: any, r: Runtime)
	local critter
	if data.forceCritter ~= "" then
		critter = critterDef(data.forceCritter)
		data.forceCritter = ""
	else
		critter = Rarity.pickWeighted(Config.Critters, rng:NextNumber())
	end
	local order = "any"
	if rng:NextNumber() < 0.4 then
		local options = {}
		for _, id in ipairs(Config.MeatOrder) do
			local m = Config.Meats[id]
			if not m.premium and (meatAvailable(player, data, m)) and m.cookTime <= 1800 then
				table.insert(options, id)
			end
		end
		if #options > 0 then
			order = options[rng:NextInteger(1, #options)]
		end
	end
	r.nextCustomerId += 1
	local customer = {
		id = r.nextCustomerId,
		critter = critter.id,
		order = order,
		muddy = critter.bellyRub and GameService.isSudsWeekend() and rng:NextNumber() < Config.SUDS_PUP_CHANCE or false,
		leaveAt = T() + Config.CUSTOMER_PATIENCE,
		spot = 0,
	}
	local used = {}
	for _, c in ipairs(r.customers) do
		used[c.spot] = true
	end
	for s = 1, Config.CUSTOMER_SPOTS do
		if not used[s] then
			customer.spot = s
			break
		end
	end
	table.insert(r.customers, customer)
	ctx.World.spawnCustomer(player, customer, critter)
	GameService.markDirty(player)
end

-- ===== Lifecycle =====
local function guard(label: string, fn: () -> ())
	-- Return a value so xpcall's type has a success flag and an error to unpack.
	local ok, err = xpcall(function(): string?
		fn()
		return nil
	end, debug.traceback)
	if not ok then
		warn("[GameService] " .. label .. " failed:\n" .. tostring(err))
	end
end

local function serverNow(): number
	local ok, t = pcall(function()
		return workspace:GetServerTimeNow()
	end)
	if ok and type(t) == "number" then
		return t
	end
	return os.clock()
end

local function onLoaded(player: Player, profile: any, isNew: boolean)
	-- Listeners run on their own threads. The player may already have left, and
	-- `profile` has to be the table DataService stored (a copied table must not pass).
	if not player.Parent or ctx.Data.get(player) ~= profile then
		return
	end
	local data = profile.data
	local lastSeen = data.lastSeen or 0
	local r: Runtime = {
		plot = nil,
		passes = {},
		sessionStart = os.clock(),
		lastActive = os.clock(),
		nudged = false,
		dirty = true,
		today = today(),
		crew = 0,
		customers = {},
		nextCustomerId = 0,
		nextSpawn = serverNow() + 3,
		lastAutoServe = 0,
		snagLockUntil = 0,
		snagCooldownUntil = 0,
		peaceChangedAt = -1e9,
		rush = nil,
		resting = false,
		cookoffReadyAt = 0,
		announcedDone = {},
		earns = {},
		staffNext = {},
		staffJob = {},
		eventNoteDue = false,
		crewBank = 0,
		crewNext = {},
		offlineCrew = 0,
		offlineTipPaid = false,
	}
	-- Runtime goes in before any yielding call. Until it exists, every action
	-- returns "Still loading your ranch..." and prompts no-op.
	GameService.runtime[player] = r

	-- The plot and the first snapshot happen before pass checks, season sync, or
	-- cosmetics. Those call Marketplace / friends / the map and must not be able
	-- to leave a joined player with no plot and no push.
	local plotOk, plotIndex = pcall(function()
		return ctx.World.assignPlot(player)
	end)
	if plotOk and type(plotIndex) == "number" then
		r.plot = plotIndex
	elseif not plotOk then
		warn("[GameService] assignPlot failed:\n" .. tostring(plotIndex))
	end
	guard("guide", function()
		if type(data.guide) ~= "table" then
			data.guide = Guide.new()
		end
		local rosterN = if type(data.staff) == "table" and type(data.staff.roster) == "table" then #data.staff.roster else 0
		Guide.prepare(data.guide, {
			served = data.stats and data.stats.served or 0,
			firstBrisket = data.tutorial and data.tutorial.firstBrisket == true,
			tutorialDone = data.tutorial and data.tutorial.done == true,
			playSeconds = data.playSeconds or 0,
			crew = rosterN,
		})
		Guide.sync(data.guide, Guide.signals(data))
		Streak.healClock(data.streak, today())
		if type(data.freeGift) == "table" then
			FreeGift.normalize(data.freeGift, os.time())
		end
	end)
	guard("push", function()
		GameService.push(player)
	end)
	if not player.Parent or GameService.runtime[player] ~= r then
		if GameService.runtime[player] == r then
			GameService.runtime[player] = nil
		end
		return
	end

	-- Pass ownership yields (UserOwnsGamePassAsync has no engine timeout). It used
	-- to run before assignPlot, so a hung web call left the ranch on the loading screen.
	task.spawn(function()
		if not player.Parent or GameService.runtime[player] ~= r then
			return
		end
		local ok, passes = pcall(function()
			return ctx.Purchase.loadPasses(player)
		end)
		if not player.Parent or GameService.runtime[player] ~= r then
			return
		end
		if ok and type(passes) == "table" then
			r.passes = passes
			if passes.DoubleTips == true and not r.offlineTipPaid and r.offlineCrew > 0 then
				r.offlineTipPaid = true
				local extra = math.floor(r.offlineCrew * (Crew.tipMult(true) - 1) + 1e-9)
				if extra > 0 then
					GameService.addCoins(player, data, extra, true, "CrewOffline")
					GameService.toast(player, string.format("Big Tipper added %d coins from while you were away.", extra), "good")
				end
			end
		else
			warn("[GameService] loadPasses failed: " .. tostring(passes))
		end
		guard("passes-refresh", function()
			ctx.World.refreshStations(player)
			ctx.Cosmetics.apply(player)
		end)
		GameService.markDirty(player)
	end)

	guard("rookie", function()
		if Rookie.shouldSkip(data.rookie, data.tutorial.done, data.stats, Config.ROOKIE_VETERAN_SERVES) then
			data.rookie.skipped = true
		end
	end)

	-- Offline progress: one jump from the saved `last` of each cook to now.
	local readyBefore = 0
	local readyAfter = 0
	local awayCrew = { seconds = 0, coins = 0 }
	guard("offline", function()
		for _, cook in pairs(data.stations) do
			if type(cook) == "table" and CookLogic.isDone(cook) then
				readyBefore += 1
			end
		end
		advanceAll(player, data, serverNow(), false)
		Crew.ensure(data)
		local rate = Crew.totalRate(data.crew.owned, data.crew.slots, { rank = data.rank, friends = 0, tipPass = false })
		local settled = Offline.settle(data.offline.lastTick, os.time(), Offline.cap(false), rate)
		data.offline.lastTick = settled.lastTick
		r.offlineCrew = settled.coins
		awayCrew = settled
		if settled.coins > 0 then
			GameService.addCoins(player, data, settled.coins, true, "CrewOffline")
		end
		for key, cook in pairs(data.stations) do
			if type(cook) == "table" and CookLogic.isDone(cook) then
				readyAfter += 1
				r.announcedDone[key] = true
			end
		end
	end)

	guard("season", function()
		PitmasterPath.registerPlayDay(data.path, r.today)
		ctx.Season.sync(player, data)
	end)
	guard("membership", function()
		ctx.Membership.onLoaded(player, data)
	end)
	guard("rank", function()
		local rank = Config.Ranks[data.rank]
		if rank and rank.unlock then
			data.owned[rank.unlock] = true
		end
	end)
	guard("social", function()
		ctx.Social.onJoin(player)
	end)
	guard("cosmetics", function()
		ctx.Cosmetics.apply(player)
	end)
	guard("stations", function()
		ctx.World.refreshStations(player)
	end)
	guard("push", function()
		GameService.push(player)
	end)

	if not player.Parent then
		return
	end
	guard("welcome", function()
		-- A failed live load has empty data, so it looks brand new. Don't play the first-visit
		-- script over a ranch we simply couldn't read. Studio memory mode is a real test session.
		local degraded = profile.memoryOnly and not RunService:IsStudio()
		if isNew and not degraded then
			ctx.Remotes.Push:FireClient(player, "welcome", { isNew = true })
		elseif lastSeen > 0 and (readyAfter > readyBefore or awayCrew.coins > 0) then
			local away = os.time() - lastSeen
			ctx.Remotes.Push:FireClient(player, "welcome", { isNew = false, away = away, ready = readyAfter - readyBefore, crewCoins = awayCrew.coins, crewAway = awayCrew.seconds })
		elseif not degraded then
			ctx.Remotes.Push:FireClient(player, "welcome", { isNew = false })
		end
		if profile.memoryOnly and RunService:IsStudio() then
			GameService.toast(player, "Studio test mode: saving is off. Turn on 'Enable Studio Access to API Services' to test saving.", "warn")
		elseif profile.memoryOnly then
			GameService.toast(player, "Roblox save servers didn't answer, so this visit won't be saved. Your real ranch is untouched. Try rejoining in a minute.", "warn")
		end
	end)
	-- Free Pip for a brand-new ranch. He walks over and is on the crew in under 10 seconds.
	task.delay(Config.Hiring.starterDelay, function()
		if not player.Parent or GameService.runtime[player] ~= r then
			return
		end
		local live = profileOf(player)
		if not live or not Crew.needsStarter(live) then
			return
		end
		if ctx.Crew and ctx.Crew.walkStarter then
			ctx.Crew.walkStarter(player)
		end
		task.delay(Config.Hiring.starterWalk, function()
			if not player.Parent or GameService.runtime[player] ~= r then
				return
			end
			local still = profileOf(player)
			if not still or not Crew.needsStarter(still) then
				if ctx.Crew and ctx.Crew.cancelStarter then
					ctx.Crew.cancelStarter(player)
				end
				return
			end
			local pip = Crew.grantStarter(still)
			if not pip then
				return
			end
			if ctx.Crew and ctx.Crew.cancelStarter then
				ctx.Crew.cancelStarter(player)
			end
			GameService.toast(player, "First hire's on the house! Pip is on the ranch.", "good")
			GameService.fx(player, "hired", { name = "Pip", title = "Pit hand" })
			if type(still.guide) == "table" then
				Guide.sync(still.guide, Guide.signals(still))
			end
			GameService.markDirty(player)
		end)
	end)
end

local function onRemoving(player: Player)
	local data = profileOf(player)
	if data then
		advanceAll(player, data, T(), false)
		if type(data.offline) == "table" then
			data.offline.lastTick = os.time()
		end
	end
	if ctx.Crew and ctx.Crew.onPlayerGone then
		ctx.Crew.onPlayerGone(player)
	end
	ctx.Social.onLeave(player)
	ctx.World.releasePlot(player)
	globalLimiter:forget(player)
	acting[player] = nil
	local uid = tostring(player.UserId)
	for name in pairs(Actions) do
		actionLimiter:forget(uid .. name)
	end
	GameService.runtime[player] = nil
	ctx.Data.release(player)
end

-- Unc Hank's Rookie List: claim any goal that's now met (rewards are free and flat).
function GameService.checkRookie(player: Player, data: any)
	if not data.tutorial.done or type(data.rookie) ~= "table" then
		return
	end
	local claimed = Rookie.advance(data.rookie, Config.RookieSteps, data.stats)
	for _, def in ipairs(claimed) do
		local rw = def.reward or {}
		local coins = rw.coins or 0
		if coins > 0 then
			GameService.addCoins(player, data, coins, false)
		end
		local last = data.rookie.claimed >= #Config.RookieSteps
		if last then
			-- the finish reward for all five goals (free; shown on the card from the start)
			local fin = Config.RookieFinish
			if fin.coins and fin.coins > 0 then
				GameService.addCoins(player, data, fin.coins, false)
			end
			if fin.cosmetic then
				GameService.grantCosmetic(player, data, fin.cosmetic)
			end
			if fin.title then
				data.titles[fin.title] = true
			end
			coins += fin.coins or 0
			ctx.Remotes.Push:FireClient(player, "dialog", { npc = "Unc Hank", text = string.format(Content.Rookie.done, coins), reward = 0 })
		else
			GameService.toast(player, string.format(Content.Rookie.stepDone, def.label, coins), "good")
		end
		GameService.fx(player, "rookie", { id = def.id, step = data.rookie.claimed, total = #Config.RookieSteps, coins = coins, last = last, cheer = Content.Rookie.cheers[(data.rookie.claimed - 1) % #Content.Rookie.cheers + 1] })
		GameService.markDirty(player)
	end
end

local function handle(player: Player, action: any, a: any, b: any, c: any): (boolean, string?)
	if type(action) ~= "string" or #action > 24 then
		return false, "Bad request."
	end
	local fn = Actions[action]
	if not fn then
		return false, "Unknown action."
	end
	local now = os.clock()
	if not globalLimiter:allow(player, now) or not actionLimiter:allow(tostring(player.UserId) .. action, now) then
		return false, "Slow down, partner!"
	end
	local data = profileOf(player)
	local r = rt(player)
	if not data or not r then
		return false, "Still loading your ranch..."
	end
	if acting[player] then
		return false, "Slow down, partner!"
	end
	r.lastActive = now
	advanceAll(player, data, T(), true)
	-- Set after advanceAll so an error there can never leave the player locked out.
	acting[player] = true
	local ok, res, msg = pcall(function()
		return (fn :: any)(player, data, a, b, c)
	end)
	acting[player] = nil
	if not ok then
		warn("[GameService] action " .. action .. " errored: " .. tostring(res))
		return false, "Something went wrong."
	end
	if res then
		GameService.checkRookie(player, data)
		if type(data.guide) == "table" then
			Guide.sync(data.guide, Guide.signals(data))
		end
	end
	GameService.markDirty(player)
	return res, msg
end

function GameService.act(player: Player, action: string, a: any, b: any, c: any): (boolean, string?)
	return handle(player, action, a, b, c)
end

function GameService.init(c: any)
	ctx = c
end

local function emptyTended(data: any, prefix: string, slots: number): string?
	for i = 2, slots do
		local key = prefix .. i
		if data.stations[key] == nil then
			return key
		end
	end
	return nil
end

local function doneKeys(data: any): { string }
	local keys = {}
	for key, cook in pairs(data.stations) do
		if type(cook) == "table" and CookLogic.isDone(cook) and not cook.burnt and cook.meat ~= "firstbrisket" then
			table.insert(keys, key)
		end
	end
	return keys
end

local function countOpen(data: any, prefix: string, slots: number): number
	local n = 0
	for i = 2, slots do
		if data.stations[prefix .. i] == nil then
			n += 1
		end
	end
	return n
end

-- Crew tick. The player's first grill and first smoker are never used here.
function GameService.crewMults(player: Player, data: any): Crew.Mults
	local r = rt(player)
	return {
		rank = data.rank,
		friends = if r then r.crew else 0,
		tipPass = r ~= nil and r.passes.DoubleTips == true,
	}
end

function GameService.hireApplicant(player: Player, index: any): (boolean, string?)
	local data = profileOf(player)
	local r = rt(player)
	if not data or not r then
		return false, "Still loading your ranch..."
	end
	if type(index) ~= "number" then
		local parsed = tonumber(index)
		if parsed == nil then
			return false, "Bad request."
		end
		index = parsed
	end
	local line = if ctx.Crew and ctx.Crew.line then ctx.Crew.line() else nil
	if type(line) ~= "table" or type(line.applicants) ~= "table" then
		return false, "The hiring line is still walking in."
	end
	if line.window ~= HiringLine.window(os.time(), Config.Hiring.period) then
		return false, "A new lineup just walked in."
	end
	local applicant = nil
	for _, row in ipairs(line.applicants) do
		if row.index == index then
			applicant = row
			break
		end
	end
	if not applicant then
		return false, "They're not on the line."
	end
	local outcome = Crew.tryHire(data, applicant)
	if not outcome.ok then
		return false, Crew.hireMessage(outcome.reason, outcome.cost)
	end
	if not HiringLine.tryTake(line.taken, index :: number, player.UserId) then
		return false, "Someone else hired them."
	end
	local member = Crew.applyHire(data, outcome)
	if not member then
		line.taken[index] = nil
		return false, "You can't hire right now."
	end
	local verb = if outcome.mergeUid then "picked up a new trick" else "is walking to your ranch"
	GameService.toast(player, member.name .. " " .. verb .. ".", "good")
	GameService.fx(player, "hired", { name = member.name, title = (Config.CrewRoles :: any)[member.role] and (Config.CrewRoles :: any)[member.role].name or "Crew" })
	if not outcome.mergeUid and ctx.Crew and ctx.Crew.walkHome then
		ctx.Crew.walkHome(player, index)
	end
	return true, nil
end

Actions.HireApplicant = function(player, _data, index)
	return GameService.hireApplicant(player, index)
end

Actions.LevelCrew = function(player, data, uid)
	local outcome = Crew.tryLevel(data, uid)
	if not Crew.applyLevel(data, outcome) then
		return false, Crew.levelMessage(outcome.reason, outcome.cost)
	end
	local member = Crew.findUid(data.crew.owned, outcome.uid :: number)
	local name = if member then member.name else "Your critter"
	GameService.toast(player, string.format("%s is now level %d.", name, outcome.level), "good")
	GameService.fx(player, "levelup", { text = name .. " " .. tostring(outcome.level) })
	return true, nil
end

Actions.BuyRanchTier = function(player, data)
	local outcome = Crew.tryTier(data)
	if not Crew.applyTier(data, outcome) then
		return false, Crew.tierMessage(outcome.reason, outcome.cost)
	end
	GameService.toast(player, string.format("Ranch tier %d: %s.", outcome.tier, outcome.name), "good")
	GameService.fx(player, "levelup", { text = outcome.name })
	return true, nil
end

local function payCrew(player: Player, data: any, r: Runtime)
	if type(data.crew) ~= "table" or type(data.crew.owned) ~= "table" then
		return
	end
	local rate = Crew.totalRate(data.crew.owned, data.crew.slots or 0, GameService.crewMults(player, data))
	local coins, bank = Crew.tickPay(rate, r.crewBank)
	r.crewBank = bank
	if type(data.offline) ~= "table" then
		data.offline = { lastTick = 0 }
	end
	data.offline.lastTick = os.time()
	if coins > 0 then
		GameService.addCoins(player, data, coins, true, "Crew")
	end
end

local function runCrewJobs(player: Player, data: any, r: Runtime, t: number)
	if type(data.crew) ~= "table" or type(data.crew.owned) ~= "table" then
		return
	end
	local slots = data.crew.slots or 0
	for i, member in ipairs(data.crew.owned) do
		if i > slots then
			break
		end
		local key = tostring(member.uid)
		if r.crewNext[key] == nil then
			r.crewNext[key] = t + i * 0.4
		end
		if t >= r.crewNext[key] then
			r.crewNext[key] = t + Config.Hiring.workSeconds
			local job = Crew.job(member.role)
			if job == "smoke" then
				local slot = emptyTended(data, "s", GameService.slotCount(player, data, "smoker"))
				if slot then
					GameService.beginCook(player, data, slot, "hotlink", { quiet = true, hand = "crew" })
				end
			elseif job == "grill" then
				local slot = emptyTended(data, "g", GameService.slotCount(player, data, "grill"))
				if slot then
					GameService.beginCook(player, data, slot, "burger", { quiet = true, hand = "crew" })
				end
			elseif job == "serve" and #r.customers > 0 then
				GameService.serveCustomer(player, r.customers[1], nil, true)
			end
		end
	end
end

local function runStaff(player: Player, data: any, r: any, t: number)
	if not Config.Chores.legacyStaff then
		return
	end
	if type(data.staff) ~= "table" then
		return
	end
	Staff.normalize(data)
	local slots = Staff.slots(data.pitLevel)
	local waiter = GameService.hasPass(player, "AutoServe")
	local grillSlots = GameService.slotCount(player, data, "grill")
	local smokerSlots = GameService.slotCount(player, data, "smoker")
	local rm = rankMult(data)
	for i, e in ipairs(data.staff.roster) do
		if i > slots then
			r.staffJob[e.id] = "wait"
			continue
		end
		if r.staffNext[e.id] == nil then
			r.staffNext[e.id] = t + 1.5 + i * 0.35
		end
		if t < r.staffNext[e.id] then
			continue
		end
		local finished = doneKeys(data)
		local held = potluckHeld(data)
		local world = {
			coins = data.coins,
			cooler = Holiday.servable(#data.cooler, held ~= nil),
			coolerMax = Config.COOLER_MAX,
			customers = #r.customers,
			openGrill = countOpen(data, "g", grillSlots),
			openSmoker = countOpen(data, "s", smokerSlots),
			done = #finished,
			burgerCost = Economy.rawCost(Config.Meats.burger, rm),
			linkCost = Economy.rawCost(Config.Meats.hotlink, rm),
		}
		local decision = Staff.decide(e, world)
		r.staffNext[e.id] = t + Staff.interval(e.speed, waiter)
		if not decision then
			r.staffJob[e.id] = "idle"
			continue
		end
		if decision.kind == "serve" then
			r.staffJob[e.id] = "serve"
			local tip = Staff.qualityTip(e.quality)
			for _ = 1, decision.count do
				if #r.customers == 0 or Holiday.servable(#data.cooler, potluckHeld(data) ~= nil) <= 0 then
					break
				end
				local served = GameService.serveCustomer(player, r.customers[1], tip, true)
				if not served then
					break
				end
			end
		elseif decision.kind == "collect" then
			r.staffJob[e.id] = "carry"
			local n = 0
			for _, key in ipairs(finished) do
				if n >= decision.count then
					break
				end
				if collect(player, data, key) then
					n += 1
				end
			end
		elseif decision.kind == "cook" and decision.meat then
			r.staffJob[e.id] = "cook"
			local prefix = if decision.meat == "burger" then "g" else "s"
			local slotN = if decision.meat == "burger" then grillSlots else smokerSlots
			for _ = 1, decision.count do
				local key = emptyTended(data, prefix, slotN)
				if not key then
					break
				end
				local cooked = GameService.beginCook(player, data, key, decision.meat, {
					quiet = true,
					luckMult = Staff.qualityLuck(e.quality),
					hand = e.id,
				})
				if not cooked then
					break
				end
			end
			ctx.World.refreshStations(player)
		end
	end
end

function GameService.start()
	ctx.Remotes.Action.OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
		local ok, msg = handle(player, action, a, b, c)
		return { ok = ok, msg = msg }
	end

	ctx.Data.onLoaded.Event:Connect(onLoaded)
	Players.PlayerAdded:Connect(function(player)
		ctx.Data.load(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(ctx.Data.load, player)
	end
	Players.PlayerRemoving:Connect(onRemoving)

	-- 1-second simulation tick
	task.spawn(function()
		while true do
			task.wait(1)
			local t = T()
			for player, r in pairs(GameService.runtime) do
				local data = profileOf(player)
				if data then
					advanceAll(player, data, t, true)
					data.playSeconds += 1
					GameService.checkRookie(player, data) -- catches goals met through world prompts too
					ctx.Season.check(player, data)
					ctx.Insights.onboarding(player, data)
					-- day rollover while playing
					local d = today()
					if Streak.healClock(data.streak, d) then
						r.dirty = true
					end
					if type(data.freeGift) == "table" then
						local giftAt = data.freeGift.nextAt
						FreeGift.normalize(data.freeGift, os.time())
						if data.freeGift.nextAt ~= giftAt then
							r.dirty = true
						end
					end
					if type(data.guide) == "table" and Guide.sync(data.guide, Guide.signals(data)) then
						r.dirty = true
					end
					if d ~= r.today then
						r.today = d
						PitmasterPath.registerPlayDay(data.path, d)
						ctx.Season.sync(player, data)
						ctx.Membership.onNewDay(player, data)
						GameService.toast(player, "A new day at the ranch! Daily reward and a new Path step are ready.", "good")
						r.eventNoteDue = true -- an event (or its teaser week) may start today
						r.dirty = true
					end
					if r.eventNoteDue and ctx.Event and ctx.Event.eventNote and ctx.Event.eventNote(player) then
						r.eventNoteDue = false
					end
					-- customers
					for i = #r.customers, 1, -1 do
						local cst = r.customers[i]
						if t > cst.leaveAt then
							removeCustomer(player, cst)
						end
					end
					if #r.customers < Config.CUSTOMER_SPOTS and t >= r.nextSpawn then
						local greeters = 0
						if type(data.crew) == "table" and type(data.crew.owned) == "table" then
							greeters = Crew.greeterCount(data.crew.owned, data.crew.slots or 0)
						end
						r.nextSpawn = t + Config.CUSTOMER_SPAWN_SECONDS * (0.7 + rng:NextNumber() * 0.6) * Crew.greeterDelay(greeters)
						spawnCustomer(player, data, r)
					end
					payCrew(player, data, r)
					runCrewJobs(player, data, r, t)
					runStaff(player, data, r, t)
					-- Jimothy the Waiter stays his own pass: he serves plates you already cooked.
					-- The crew cooks and serves too. Owning the pass also shortens their interval.
					local servable = Holiday.servable(#data.cooler, potluckHeld(data) ~= nil)
					if GameService.hasPass(player, "AutoServe") and t - r.lastAutoServe >= 4 and #r.customers > 0 and servable > 0 then
						r.lastAutoServe = t
						GameService.serveCustomer(player, r.customers[1], nil, true)
					end
					-- healthy-play nudge after an hour
					if not r.nudged and (os.clock() - r.sessionStart) > Config.PLAYTIME_NUDGE_MINUTES * 60 then
						r.nudged = true
						GameService.toast(player, "You've been smokin' for an hour! Take a stretch break. Your smokers keep cooking while you're away. 🌤️", "info")
					end
				end
			end
		end
	end)

	-- push loop (coalesces many changes into at most 4 snapshots/sec per player)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, r in pairs(GameService.runtime) do
				if r.dirty then
					local okPush, errPush = pcall(function(): nil
						GameService.push(player)
						return nil
					end)
					if not okPush then
						warn("[GameService] push failed: " .. tostring(errPush))
					end
				end
			end
		end
	end)

	-- refresh timers on clients every 5s even if nothing changed (restock countdown etc.)
	task.spawn(function()
		while true do
			task.wait(5)
			for player, _ in pairs(GameService.runtime) do
				GameService.markDirty(player)
			end
		end
	end)
end

return GameService
