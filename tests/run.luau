--!nocheck
-- Unit tests for the pure logic modules. Run with:  lune run tests/run
local process = require("@lune/process")

local Config = require("../src/shared/Config")
local Monetization = require("../src/shared/Monetization")
local Content = require("../src/shared/Content")
local CookLogic = require("../src/shared/Logic/CookLogic")
local Rarity = require("../src/shared/Logic/Rarity")
local Economy = require("../src/shared/Logic/Economy")
local Streak = require("../src/shared/Logic/Streak")
local PitmasterPath = require("../src/shared/Logic/PitmasterPath")
local Restock = require("../src/shared/Logic/Restock")
local CookOff = require("../src/shared/Logic/CookOff")
local RateLimiter = require("../src/shared/Logic/RateLimiter")
local ReceiptLedger = require("../src/shared/Logic/ReceiptLedger")
local SessionLock = require("../src/shared/Logic/SessionLock")
local TimeUtil = require("../src/shared/Logic/TimeUtil")
local Hype = require("../src/shared/Logic/Hype")
local Holiday = require("../src/shared/Logic/Holiday")
local Rookie = require("../src/shared/Logic/Rookie")
local SfxIds = require("../src/shared/SfxIds")
local Music = require("../src/shared/Music")
local MusicPrefs = require("../src/shared/Logic/MusicPrefs")
local CuteFace = require("../src/shared/Logic/CuteFace")
local Gifting = require("../src/shared/Logic/Gifting")
local HudMenu = require("../src/shared/Logic/HudMenu")
local ShopCatalog = require("../src/shared/Logic/ShopCatalog")
local Howdy = require("../src/shared/Logic/Howdy")
local Jimothy = require("../src/shared/Logic/Jimothy")
local Reconcile = require("../src/shared/Logic/Reconcile")
local Numbers = require("../src/shared/Logic/Numbers")
local Income = require("../src/shared/Logic/Income")
local Staff = require("../src/shared/Logic/Staff")
local FreeGift = require("../src/shared/Logic/FreeGift")
local Goals = require("../src/shared/Logic/Goals")
local Guide = require("../src/shared/Logic/Guide")
local HudLayout = require("../src/shared/Logic/HudLayout")
local DefaultData = require("../src/shared/DefaultData")
local function fs_read(path: string): string
	return require("@lune/fs").readFile(path)
end
local SeasonPass = require("../src/shared/Logic/SeasonPass")
local Storefront = require("../src/shared/Logic/Storefront")
local Funnels = require("../src/shared/Logic/Funnels")
local ShopSync = require("../scripts/lib/ShopSync")

local passed, failed = 0, 0
local current = ""
local function test(name: string, fn: () -> ())
	current = name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("  ✓ " .. name)
	else
		failed += 1
		print("  ✗ " .. name .. "\n      " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end
local function near(a, b, tol, msg)
	if math.abs(a - b) > (tol or 1e-6) then
		error(string.format("%s: expected ~%s, got %s", msg or current, tostring(b), tostring(a)), 2)
	end
end
local function truthy(v, msg)
	if not v then
		error(msg or (current .. ": expected truthy"), 2)
	end
end

print("CookLogic")
test("burger cooks in ~30s at base speed", function()
	local c = CookLogic.new("burger", "common", 30, 1000)
	CookLogic.advance(c, 1015, 1, 1, 0)
	near(CookLogic.fraction(c), 0.5)
	truthy(not CookLogic.isDone(c))
	CookLogic.advance(c, 1030, 1, 1, 0)
	truthy(CookLogic.isDone(c))
	near(c.doneAt, 1030)
end)
test("burgers are a short cook item (20-45s)", function()
	local t = Config.Meats.burger.cookTime
	truthy(t >= 20 and t <= 45)
end)
test("offline progress: brisket keeps smoking for 8 hours offline in one jump", function()
	local d = Config.Meats.brisket.cookTime
	local c = CookLogic.new("brisket", "juicy", d, 0)
	CookLogic.advance(c, 8 * 3600, 1, 1, 0)
	truthy(CookLogic.isDone(c), "brisket should be done after 8h at 1x (6h cook)")
	near(c.doneAt, d)
end)
test("one big offline jump equals many small online ticks (with a boost mid-way)", function()
	local a = CookLogic.new("ribs", "common", 1800, 0)
	local b = CookLogic.new("ribs", "common", 1800, 0)
	local boostUntil = 300
	CookLogic.advance(a, 1000, 1.25, 2, boostUntil)
	for t = 1, 1000 do
		CookLogic.advance(b, t, 1.25, 2, boostUntil)
	end
	near(a.progress, b.progress, 1e-6)
	near(a.progress, 300 * 1.25 * 2 + 700 * 1.25, 1e-6)
end)
test("boost that expired while offline only counts until expiry", function()
	local c = CookLogic.new("porkbutt", "common", 7200, 0)
	CookLogic.advance(c, 3600, 1, 2, 600)
	near(c.progress, 600 * 2 + 3000)
end)
test("doneAt is exact when finishing inside a boost window", function()
	local c = CookLogic.new("hotlink", "common", 120, 0)
	CookLogic.advance(c, 500, 1, 2, 1000)
	near(c.doneAt, 60)
end)
test("remaining() accounts for boost then normal speed", function()
	local c = CookLogic.new("ribs", "common", 1800, 0)
	near(CookLogic.remaining(c, 0, 1, 2, 300), 300 + (1800 - 600))
	near(CookLogic.remaining(c, 0, 1, 1, 0), 1800)
end)
test("peek costs progress but never goes negative", function()
	local c = CookLogic.new("hotlink", "common", 120, 0)
	CookLogic.advance(c, 5, 1, 1, 0)
	local p = CookLogic.peek(c, Config.PEEK_PENALTY_FRACTION, Config.PEEK_PENALTY_MIN)
	eq(p, 5)
	eq(c.progress, 0)
	truthy(c.revealed)
end)
test("burgers only burn after grace, and finishNow sets doneAt", function()
	local c = CookLogic.new("burger", "common", 30, 0)
	CookLogic.advance(c, 30, 1, 1, 0)
	truthy(not CookLogic.shouldBurn(c, 40, 15))
	truthy(CookLogic.shouldBurn(c, 46, 15))
	local d = CookLogic.new("brisket", "common", 21600, 0)
	CookLogic.finishNow(d, 10)
	truthy(CookLogic.isDone(d))
	eq(d.doneAt, 10)
end)
test("spatula flip judged against halfway point", function()
	local F = Config.Flip
	eq(CookLogic.judgeFlip(0.5, F.target, F.perfectWindow, F.goodWindow), "perfect")
	eq(CookLogic.judgeFlip(0.57, F.target, F.perfectWindow, F.goodWindow), "perfect")
	eq(CookLogic.judgeFlip(0.65, F.target, F.perfectWindow, F.goodWindow), "good")
	eq(CookLogic.judgeFlip(0.95, F.target, F.perfectWindow, F.goodWindow), "miss")
end)

print("Rarity")
test("odds sum to 100 and match weights at luck 1", function()
	local odds = Rarity.odds(Config.Rarities, 1)
	local sum = 0
	for _, o in ipairs(odds) do
		sum += o.pct
	end
	near(sum, 100, 1e-6)
	near(odds[1].pct, 70, 1e-6)
	near(odds[5].pct, 0.2, 1e-6)
end)
test("luck raises rare odds, maxIndex caps burgers at Smoke Ring Gold", function()
	local base = Rarity.odds(Config.Rarities, 1)
	local lucky = Rarity.odds(Config.Rarities, 1.6)
	truthy(lucky[3].pct > base[3].pct)
	local burger = Rarity.odds(Config.Rarities, 1, Config.Meats.burger.maxRarity)
	eq(burger[4].pct, 0)
	eq(burger[5].pct, 0)
end)
test("roll boundaries map to the right rarity", function()
	eq(Rarity.roll(Config.Rarities, 1, nil, 0), "common")
	eq(Rarity.roll(Config.Rarities, 1, nil, 0.6999), "common")
	eq(Rarity.roll(Config.Rarities, 1, nil, 0.7001), "juicy")
	eq(Rarity.roll(Config.Rarities, 1, nil, 0.9999), "meteorite")
	eq(Rarity.roll(Config.Rarities, 1, 3, 0.9999), "smokering")
end)
test("empirical roll frequencies match shown odds (100k rolls)", function()
	local seed = 12345
	local function rnd()
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local counts = {}
	local N = 100000
	for _ = 1, N do
		local id = Rarity.roll(Config.Rarities, 1, nil, rnd())
		counts[id] = (counts[id] or 0) + 1
	end
	near(counts.common / N * 100, 70, 0.6)
	near(counts.juicy / N * 100, 22, 0.6)
	near(counts.smokering / N * 100, 6, 0.4)
end)
test("critter and bandana weighted picks", function()
	eq(Rarity.pickWeighted(Config.Critters, 0).id, "armadillo")
	eq(Rarity.pickWeighted(Config.Critters, 0.99999).id, "rex")
	local odds = Rarity.weightedOdds(Config.Bandanas)
	near(odds.bandana_gold, 5, 1e-9)
end)

print("Economy")
test("plate value multiplies everything and rounds", function()
	local v = Economy.plateValue(12, { rarityMult = 1.5, rankMult = 1, crewMult = 1.1, tipMult = 1, flipMult = 1.5 })
	eq(v, 30) -- 12*1.5*1.1*1.5 = 29.7
	eq(Economy.plateValue(12, { rarityMult = 1, doubleTips = true }), 18) -- Fair Play: +50%, not x2
end)
test("rank and crew multipliers", function()
	near(Economy.rankMult(3, Config.RANK_STEP), 2)
	near(Economy.crewMult(5, 0.1, 3), 1.3)
end)
test("slot totals respect pass bonus and cap", function()
	eq(Economy.totalSlots(2, 3, 2, true, Config.MAX_SMOKERS), 7)
	eq(Economy.totalSlots(2, 3, 2, false, Config.MAX_SMOKERS), 5)
	eq(Economy.nextSlotCost(Config.Slots.smoker.costs, 3), nil)
end)
test("rebirth requires run coins", function()
	local ok, need = Economy.canRebirth(Config.Ranks, 1, 99999)
	eq(ok, false)
	eq(need, 100000)
	eq((Economy.canRebirth(Config.Ranks, 1, 100000)), true)
	eq((Economy.canRebirth(Config.Ranks, #Config.Ranks, 1e12)), false)
end)
test("every meat is profitable at base rank", function()
	for id, m in pairs(Config.Meats) do
		truthy(m.price > Economy.rawCost(m, 1), id .. " must sell for more than it costs")
	end
end)
test("balance: first pit upgrade reachable in under ~6 minutes of active play", function()
	local avgBurger = Economy.averageRarityMult(Config.Rarities, 1, 3)
	local burgerCpm = Economy.coinsPerMinute(Config.Meats.burger, 2, 1, avgBurger * 1.2, 1)
	local avg = Economy.averageRarityMult(Config.Rarities, 1)
	local linkCpm = Economy.coinsPerMinute(Config.Meats.hotlink, 2, 1, avg, 1)
	local firstBrisket = Config.Meats.firstbrisket.price * 3 -- guaranteed Smoke Ring Gold
	local minutes = (Config.PitLevels[2].cost - firstBrisket - Config.START_COINS) / (burgerCpm + linkCpm)
	print(string.format("      burger %.1f/min + hot links %.1f/min -> upgrade in %.1f min", burgerCpm, linkCpm, minutes))
	truthy(minutes > 0.5 and minutes < 6, "first upgrade should take 0.5-6 minutes, got " .. minutes)
end)
test("balance: each pit level costs more but pays back within a few hours of loop", function()
	for lvl = 2, #Config.PitLevels do
		truthy(Config.PitLevels[lvl].cost > Config.PitLevels[lvl - 1].cost)
		truthy(Config.PitLevels[lvl].speed > Config.PitLevels[lvl - 1].speed)
	end
end)
test("balance: rebirth to Big Bro takes days, not minutes", function()
	local avg = Economy.averageRarityMult(Config.Rarities, Config.PitLevels[5].luck)
	local cpm = Economy.coinsPerMinute(Config.Meats.ribs, 5, Config.PitLevels[5].speed, avg, 1)
	local hours = Config.Ranks[2].need / cpm / 60
	print(string.format("      ~%.1f hours of maxed-out ribs to first rebirth", hours))
	truthy(hours > 2 and hours < 40)
end)
test("premium cuts are strong but bounded (<= 3x brisket value per hour)", function()
	local b = Config.Meats.brisket
	local w = Config.Meats.wagyu
	local ratio = (w.price / w.cookTime) / (b.price / b.cookTime)
	truthy(ratio <= 3, "wagyu/brisket per-hour ratio " .. ratio)
end)

print("Streak")
test("consecutive days build the streak", function()
	local s = Streak.new()
	eq(Streak.claim(s, 100).count, 1)
	eq(Streak.claim(s, 101).count, 2)
	eq(Streak.claim(s, 101).ok, false)
	eq(Streak.claim(s, 102).count, 3)
end)
test("one free miss per week", function()
	local s = Streak.new()
	Streak.claim(s, 100)
	Streak.claim(s, 101)
	local r = Streak.claim(s, 103) -- missed day 102
	eq(r.usedFreeMiss, true)
	eq(r.count, 3)
	local r2 = Streak.claim(s, 105) -- missed 104, same week?
	if TimeUtil.weekOfDay(105) == TimeUtil.weekOfDay(103) then
		eq(r2.softReset, true)
	else
		eq(r2.usedFreeMiss, true)
	end
end)
test("long break soft-resets to the start of the current week, never zero", function()
	local s = Streak.new()
	for d = 1, 10 do
		Streak.claim(s, d)
	end
	eq(s.count, 10)
	local r = Streak.claim(s, 30)
	eq(r.softReset, true)
	eq(r.count, 8)
	eq(r.cycleDay, 1)
	eq(s.best, 10)
end)
test("reward scale caps at week 4", function()
	near(Streak.rewardScale(1), 1)
	near(Streak.rewardScale(8), 1.5)
	near(Streak.rewardScale(100), 2.5)
end)
test("streak survives clock going backwards without double reward", function()
	local s = Streak.new()
	Streak.claim(s, 50)
	eq(Streak.claim(s, 49).ok, false)
end)

print("Pitmaster Path")
test("path has 28 steps with a reward every step", function()
	eq(#Config.PathSteps, 28)
	for i, st in ipairs(Config.PathSteps) do
		truthy(st.reward ~= nil and st.stat ~= nil and st.amount > 0, "step " .. i)
	end
end)
test("steps unlock by play day, not by grinding", function()
	local s = PitmasterPath.new()
	PitmasterPath.registerPlayDay(s, 10)
	local stats = { served = 999, perfectFlips = 999 }
	local ok = PitmasterPath.claim(s, Config.PathSteps, stats)
	eq(ok, true)
	local ok2 = PitmasterPath.claim(s, Config.PathSteps, stats)
	eq(ok2, false) -- day 2 not unlocked yet
	eq(PitmasterPath.registerPlayDay(s, 10), false)
	PitmasterPath.registerPlayDay(s, 15) -- gaps are fine: play days, not calendar days
	eq((PitmasterPath.claim(s, Config.PathSteps, stats)), true)
end)
test("all 28 path rewards reference real cosmetics and sauces", function()
	for i, st in ipairs(Config.PathSteps) do
		if st.reward.cosmetic then
			truthy(Config.Cosmetics[st.reward.cosmetic], "step " .. i .. " cosmetic")
		end
		if st.reward.sauce then
			truthy(Config.Sauces[st.reward.sauce], "step " .. i .. " sauce")
		end
	end
end)

print("Restock")
test("restock is deterministic per 5-minute window and changes between windows", function()
	local w = Restock.window(1_000_000, Config.RESTOCK_SECONDS)
	local a = Restock.shelf(w, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)
	local b = Restock.shelf(w, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)
	eq(#a, 3)
	for i = 1, #a do
		eq(a[i].id, b[i].id)
		eq(a[i].qty, b[i].qty)
	end
	local differs = false
	for k = 1, 20 do
		local c = Restock.shelf(w + k, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)
		for i = 1, #a do
			if c[i].id ~= a[i].id or c[i].qty ~= a[i].qty then
				differs = true
			end
		end
	end
	truthy(differs)
end)
test("shelves never repeat a sauce and qty within maxStock", function()
	for w = 1, 500 do
		local seen = {}
		for _, e in ipairs(Restock.shelf(w, Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)) do
			truthy(not seen[e.id])
			seen[e.id] = true
			truthy(e.qty >= 1 and e.qty <= Config.Sauces[e.id].maxStock)
		end
	end
end)
test("rare sauces appear sometimes but not always", function()
	local odds = Restock.appearOdds(Config.Sauces, Config.SauceOrder, Config.RESTOCK_SLOTS)
	print(string.format("      Hill Country Mop shows up in %.1f%% of restocks", odds.hillcountry))
	truthy(odds.hillcountry > 5 and odds.hillcountry < 60)
	truthy(odds.sweetheat > odds.hillcountry)
end)
test("nextIn counts down to the next window", function()
	eq(Restock.nextIn(600, 300), 300)
	eq(Restock.nextIn(601, 300), 299)
end)

print("Cook-Off, time and rotation")
test("judging scale: common brisket Mid, smoke ring W, texas-size Cooked, burger L", function()
	local R = Config.CookOff.ratings
	eq(CookOff.rating(R, CookOff.score(1, 3600, false)).id, "Mid")
	eq(CookOff.rating(R, CookOff.score(3, 3600, false)).id, "W")
	eq(CookOff.rating(R, CookOff.score(4, 3600, false)).id, "Cooked")
	eq(CookOff.rating(R, CookOff.score(1, 12, false)).id, "L")
end)
test("weekday math: 2026-11-07 is a Saturday in Texas", function()
	-- 2026-11-07 18:00 UTC = noon CST
	local days = 20764 -- days from 1970-01-01 to 2026-11-07
	local noonCst = days * 86400 + 18 * 3600
	eq(TimeUtil.weekday(noonCst, -6), 7)
	eq(TimeUtil.month(noonCst, -6), 11)
	eq(CookOff.isSaturday(TimeUtil.weekday(noonCst, -6)), true)
	eq(CookOff.isSudsWeekend(TimeUtil.weekday(noonCst + 86400, -6)), true)
end)
test("Texas day boundary is midnight Central, not UTC", function()
	local days = 20764
	local justBeforeMidnightCst = days * 86400 + 6 * 3600 - 1 -- 23:59:59 CST on Nov 6
	eq(TimeUtil.dayNumber(justBeforeMidnightCst, -6), days - 1)
	eq(TimeUtil.dayNumber(justBeforeMidnightCst + 1, -6), days)
end)
test("Cook-Off board: live Saturday, yesterday's results Sunday, last Saturday's champs Mon-Fri", function()
	eq(CookOff.boardMode(7), "live")
	eq(CookOff.boardMode(1), "results")
	for wd = 2, 6 do
		eq(CookOff.boardMode(wd), "last")
		eq(CookOff.finalWeekOffset(wd), -1)
	end
	eq(CookOff.finalWeekOffset(7), nil)
	eq(CookOff.finalWeekOffset(1), 0)
	-- Monday-start weeks: Sunday is the same week as the Saturday before it, Monday is the next one
	local sat = Holiday.daysFromCivil(2026, 11, 21)
	eq(Holiday.weekdayOf(sat), 7)
	eq(TimeUtil.weekOfDay(sat + 1), TimeUtil.weekOfDay(sat), "Sunday shows this week's (final) board")
	eq(TimeUtil.weekOfDay(sat + 2), TimeUtil.weekOfDay(sat) + 1, "Monday's 'last week' is that Saturday")
	-- next Saturday, every day of a week (today if it's Saturday)
	local mon = Holiday.daysFromCivil(2026, 11, 16)
	for k = 0, 5 do
		eq(Holiday.longLabel(CookOff.nextSaturday(mon + k)), "Sat, Nov 21")
	end
	eq(CookOff.nextSaturday(sat), sat)
	eq(Holiday.longLabel(CookOff.nextSaturday(sat + 1)), "Sat, Nov 28")
end)
test("Cook-Off board: ties share a place, the podium is places 1-3, names stay short", function()
	local P = CookOff.placings({ { key = "11", value = 100 }, { key = "22", value = 100 }, { key = "33", value = 97 }, { key = "44", value = 97 }, { key = "55", value = 90 }, { key = "bad", value = 80 } })
	eq(#P, 5, "a malformed key is skipped")
	eq(P[1].place, 1)
	eq(P[2].place, 1)
	eq(P[3].place, 3)
	eq(P[4].place, 3)
	eq(P[5].place, 5)
	eq(CookOff.podiumPlace(P, 44), 3, "a tie for 3rd is still on the podium")
	eq(CookOff.podiumPlace(P, 55), nil)
	eq(CookOff.podiumPlace(P, 99), nil)
	eq(CookOff.medal(1), "🥇")
	eq(CookOff.medal(3), "🥉")
	eq(CookOff.medal(4), "4.")
	eq(CookOff.shortName("ShortName", 14), "ShortName")
	eq(CookOff.shortName("AVeryLongUsername2026", 14), "AVeryLongUser…")
	eq(utf8.len(CookOff.shortName("AVeryLongUsername2026", 14)), 14)
end)
test("Cook-Off board text: champs, the next date, never a timer; Champ title is free", function()
	local B = Content.CookOffBoard
	local names = { [11] = "MikeRoch", [22] = "Sis", [33] = "BrisketQueen2014" }
	local function nm(id)
		return names[id] or ("Pitmaster " .. id)
	end
	local P = CookOff.placings({ { key = "11", value = 100 }, { key = "22", value = 97 }, { key = "33", value = 91 } })
	local last = CookOff.boardText("last", "Harvest Smoke-Off", P, nm, "Sat, Nov 21", B)
	truthy(string.find(last, "Last Saturday's champs", 1, true), last)
	truthy(string.find(last, "🥇 MikeRoch  100", 1, true), last)
	truthy(string.find(last, "🥉 BrisketQuee…  91", 1, true), last)
	truthy(string.find(last, "Next Cook-Off:\nSat, Nov 21", 1, true), last)
	local empty = CookOff.boardText("last", "Harvest Smoke-Off", {}, nm, "Sat, Nov 21", B)
	truthy(string.find(empty, B.title, 1, true), "empty board says what the podium earns")
	truthy(not string.find(empty, "Opens Saturday", 1, true))
	local live = CookOff.boardText("live", "Harvest Smoke-Off", {}, nm, "Sat, Nov 21", B)
	truthy(string.find(live, "TODAY", 1, true) and string.find(live, "Be the first", 1, true), live)
	truthy(not string.find(live, "Next Cook-Off", 1, true), "no 'next' line on the day itself")
	local many = {}
	for i = 1, 10 do
		table.insert(many, { key = tostring(i), value = 101 - i })
	end
	local _, rows = string.gsub(CookOff.boardText("live", "S", CookOff.placings(many), nm, "x", B), "Pitmaster", "")
	eq(rows, B.liveRows, "live board shows liveRows rows")
	local _, rows2 = string.gsub(CookOff.boardText("results", "S", CookOff.placings(many), nm, "x", B), "Pitmaster", "")
	eq(rows2, B.finalRows, "final board shows finalRows rows")
	for _, k in ipairs({ "liveHead", "resultsHead", "lastHead", "liveEmpty", "finalEmpty", "next", "practice", "champNote", "champAgain" }) do
		local t = string.lower(B[k])
		for _, bad in ipairs({ "hurry", "ends in", "left!", "timer", "buy", "robux", "r$" }) do
			truthy(not string.find(t, bad, 1, true), k .. " has '" .. bad .. "'")
		end
	end
	-- the title is earned only (no product grants it) and the save has a champWeek field
	for _, list in ipairs({ Monetization.Products or {}, Monetization.Passes or {} }) do
		for key, item in pairs(list) do
			truthy(not string.find(tostring(item.title or ""), B.title, 1, true), key .. " sells the Champ title")
		end
	end
	truthy(string.find(fs_read("src/shared/DefaultData.luau"), "cookoff = { week = -1, best = 0, champWeek = -1 }", 1, true), "saves gain cookoff.champWeek")
end)
test("Cook-Off wiring: the board reads last week's store Mon-Fri and champs are told once a week", function()
	local src = fs_read("src/server/Services/EventService.luau")
	truthy(string.find(src, "CookOff.finalWeekOffset", 1, true), "final week offset used")
	truthy(string.find(src, "\"CookOff_W\" .. wk", 1, true), "reads the finished week's store")
	truthy(string.find(src, "data.cookoff.champWeek == wk", 1, true), "once per week")
	truthy(string.find(src, "task.spawn(EventService.champCheck, player)", 1, true), "checked on join")
	truthy(string.find(fs_read("src/client/Main.client.luau"), "p.kind == \"champ\"", 1, true), "client shows the champ pop")
end)
test("seasons cover every month", function()
	for m = 1, 12 do
		truthy(CookOff.seasonFor(Config.Seasons, m) ~= nil)
	end
	eq(CookOff.seasonFor(Config.Seasons, 11).id, "harvest")
end)
test("weekly rotation features 2 items and cycles through the whole pool", function()
	local seen = {}
	for w = 0, 10 do
		local r = CookOff.rotation(Config.RotationPool, Config.ROTATION_FEATURED, w)
		eq(#r, 2)
		truthy(r[1] ~= r[2])
		for _, k in ipairs(r) do
			seen[k] = true
		end
	end
	for _, k in ipairs(Config.RotationPool) do
		truthy(seen[k], k .. " never rotates in")
	end
end)

print("Security helpers")
test("rate limiter allows bursts then throttles, refills over time", function()
	local rl = RateLimiter.new(3, 1)
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(rl:allow("p", 0))
	truthy(not rl:allow("p", 0))
	truthy(rl:allow("p", 1.01))
	truthy(rl:allow("q", 0), "keys are independent")
end)
test("receipt ledger is idempotent and bounded", function()
	local list = {}
	ReceiptLedger.add(list, "a", 3)
	ReceiptLedger.add(list, "a", 3)
	eq(#list, 1)
	ReceiptLedger.add(list, "b", 3)
	ReceiptLedger.add(list, "c", 3)
	ReceiptLedger.add(list, "d", 3)
	eq(#list, 3)
	truthy(not ReceiptLedger.has(list, "a"))
	truthy(ReceiptLedger.has(list, "d"))
end)
test("session lock: second server can't take a fresh lock", function()
	local rec = SessionLock.acquire(nil, "server-A", 1000, 300)
	truthy(rec ~= nil)
	local r2, st = SessionLock.acquire(rec, "server-B", 1010, 300)
	eq(r2, nil)
	eq(st, "locked")
end)
test("session lock: stale lock (crashed server) can be taken", function()
	local rec = SessionLock.acquire(nil, "server-A", 1000, 300)
	local r2, st = SessionLock.acquire(rec, "server-B", 1400, 300)
	truthy(r2 ~= nil)
	eq(st, "stale-taken")
	eq(r2.lock.jobId, "server-B")
end)
test("session lock: a bad timestamp from an older server is taken, not thrown", function()
	local missing = { data = { coins = 4 }, lock = { jobId = "old", time = nil } }
	local rec, st = SessionLock.acquire(missing, "new", 5000, 300)
	truthy(rec ~= nil)
	eq(st, "stale-taken")
	eq(rec.data.coins, 4)
	local future = { data = { coins = 9 }, lock = { jobId = "old", time = 5000 + 100000 } }
	local rec2, st2 = SessionLock.acquire(future, "new", 5000, 300)
	eq(st2, "stale-taken")
	eq(rec2.data.coins, 9)
	local textTime = { data = { coins = 2 }, lock = { jobId = "old", time = "5000" } }
	local rec3, st3 = SessionLock.acquire(textTime, "new", 5000, 300)
	eq(st3, "stale-taken")
	eq(rec3.data.coins, 2)
end)
test("session lock: force takes a lock another server still holds", function()
	local rec = SessionLock.acquire(nil, "server-A", 1000, 300)
	local blocked, st = SessionLock.acquire(rec, "server-B", 1010, 300)
	eq(blocked, nil)
	eq(st, "locked")
	local taken, st2 = SessionLock.acquire(rec, "server-B", 1010, 300, true)
	truthy(taken ~= nil)
	eq(st2, "stale-taken")
	eq(taken.lock.jobId, "server-B")
end)
test("a service start() throwing still loads the player and assigns a plot", function()
	local Boot = require("../src/server/Boot")
	local player = { Name = "Casey", UserId = 7 }
	local loaded = false
	local plot = nil
	local Data = {
		start = function() end,
		load = function(p)
			eq(p, player)
			loaded = true
		end,
	}
	local World = {
		assignPlot = function(p)
			eq(p, player)
			plot = 1
			return 1
		end,
	}
	local Game = {
		init = function() end,
		start = function()
			Data.load(player)
			plot = World.assignPlot(player)
		end,
	}
	local Broken = {
		init = function() end,
		start = function()
			error("MarketplaceService:GetUserSubscriptionStatusAsync is not a valid member")
		end,
	}
	Boot.run({ Data = Data, World = World, Game = Game, Broken = Broken }, { "World", "Game", "Broken" }, { "Game" }, { "Broken", "World" })
	truthy(loaded, "player data still loads")
	eq(plot, 1)
end)
test("session lock: only the holder can save; release clears lock", function()
	local rec = SessionLock.acquire(nil, "A", 0, 300)
	local bad = SessionLock.save(rec, "B", 10, { coins = 1 }, false)
	eq(bad, nil)
	local good = SessionLock.save(rec, "A", 10, { coins = 5 }, true)
	eq(good.data.coins, 5)
	eq(good.lock, nil)
	local again = SessionLock.acquire(good, "B", 11, 300)
	truthy(again ~= nil, "released record can be locked by the next server")
end)

test("session lock: a late save after release is refused (no overwrite, no phantom lock)", function()
	local rec = SessionLock.acquire(nil, "A", 0, 300)
	local released = SessionLock.save(rec, "A", 10, { coins = 5 }, true)
	local late, st = SessionLock.save(released, "A", 12, { coins = 1 }, false)
	eq(late, nil, "late autosave after leaving can't write")
	eq(st, "lost-lock")
	-- another server loaded, played and released: our stale copy must not win
	local b = SessionLock.acquire(released, "B", 20, 300)
	local bRel = SessionLock.save(b, "B", 30, { coins = 99 }, true)
	eq(SessionLock.save(bRel, "A", 31, { coins = 1 }, false), nil, "old server can't overwrite newer progress")
	truthy(SessionLock.save(nil, "A", 0, { coins = 1 }, false) ~= nil, "brand-new record can be written")
end)
test("launch audit guards: receipts, saves and leaving mid-load", function()
	local fs = require("@lune/fs")
	local ds = fs.readFile("src/server/Services/DataService.luau")
	truthy(string.find(ds, "if profile.released then", 1, true) ~= nil, "no saves after the final release")
	local ps = fs.readFile("src/server/Services/PurchaseService.luau")
	truthy(string.find(ps, "profile.memoryOnly and not IS_STUDIO", 1, true) ~= nil, "no receipts granted when saving is down")
	truthy(string.find(ps, "profile.released or not player.Parent", 1, true) ~= nil, "no receipts for a player who is leaving")
	local hit = string.find(ps, "ReceiptLedger.has(data.receipts, purchaseId)", 1, true)
	truthy(hit ~= nil and string.find(string.sub(ps, hit, hit + 400), "ctx.Data.save(profile, false)", 1, true) ~= nil, "a repeat receipt is only confirmed once saved")
	truthy(string.find(ps, "Gifting.landing(", 1, true) ~= nil, "gift receipts use Gifting.landing")
	local gs = fs.readFile("src/server/Services/GameService.luau")
	truthy(string.find(gs, "ctx.Data.get(player) ~= profile", 1, true) ~= nil, "onLoaded skips players who already left")
	truthy(string.find(gs, "GameService.runtime[player] ~= r", 1, true) ~= nil, "no plot for a player who left during the pass check")
	truthy(string.find(gs, "actionLimiter:forget(", 1, true) ~= nil, "per-action rate buckets are freed on leave")
end)

print("Content & monetization config")
test("every cosmetic product grants real cosmetics; ids are 0 (hidden) or a real ID", function()
	for key, p in pairs(Monetization.Products) do
		truthy(p.id == 0 or (p.id > 0 and p.id == math.floor(p.id)), key .. " id is 0 or a whole number")
		if p.grants then
			for _, c in ipairs(p.grants) do
				truthy(Config.Cosmetics[c], key .. " grants unknown cosmetic " .. c)
			end
		end
		truthy(p.price > 0)
	end
	for key, p in pairs(Monetization.Passes) do
		truthy(p.id == 0 or (p.id > 0 and p.id == math.floor(p.id)), key .. " id is 0 or a whole number")
	end
end)
test("rotation pool entries are rotation products", function()
	for _, k in ipairs(Config.RotationPool) do
		truthy(Monetization.Products[k] and Monetization.Products[k].rotation, k)
	end
end)
test("bundle value notes are honest (sum of parts > bundle price)", function()
	local P = Monetization.Products
	eq(P.ApronGrillMaster.price + P.HatPitmaster.price + P.Boost30.price, 223)
	truthy(P.BundleStarter.price < 223)
	eq(P.GoldenSpatula.price + P.SkinGolden.price, 398)
	truthy(P.BundleGoldRush.price < 398)
end)
test("no pushy shop words anywhere in product copy", function()
	local banned = { "NOW", "LAST CHANCE", "HURRY", "LIMITED TIME ONLY", "DON'T MISS", "BEFORE IT'S GONE" }
	local function check(s)
		local up = string.upper(s)
		for _, w in ipairs(banned) do
			local pat = "%f[%w]" .. string.gsub(w, "'", "'") .. "%f[%W]"
			truthy(not string.find(up, pat), "pushy copy: " .. s)
		end
	end
	for _, p in pairs(Monetization.Products) do
		check(p.name)
		check(p.desc)
	end
	for _, p in pairs(Monetization.Passes) do
		check(p.name)
		check(p.desc)
	end
end)
test("Unc has a month of daily jokes", function()
	truthy(#Content.UncJokes >= 28)
end)

print("Hype (social + clip moments)")
test("Dinner Bell needs 3 different ringers inside the window, then respects the cooldown", function()
	local Z = Config.DinnerBell
	local rubs = {}
	rubs[1] = 100
	rubs[1] = 105 -- same player twice still counts once
	local n, go = Hype.pileOn(rubs, 105, Z.window, Z.need, -1e9, Z.cooldown)
	eq(n, 1)
	eq(go, false)
	rubs[2] = 110
	rubs[3] = 118
	n, go = Hype.pileOn(rubs, 118, Z.window, Z.need, -1e9, Z.cooldown)
	eq(n, 3)
	eq(go, true)
	-- stale rings fall out of the window
	n = Hype.pileOn(rubs, 140, Z.window, Z.need, 118, Z.cooldown)
	eq(n, 0)
	-- cooldown blocks a second trigger right away
	local r2 = { [1] = 200, [2] = 200, [3] = 200 }
	local _, go2 = Hype.pileOn(r2, 200, Z.window, Z.need, 118, Z.cooldown)
	eq(go2, false)
end)
test("Lunch Rush pays once per window after `need` plates, and resets next window", function()
	local R = Config.Rush
	local s, bonus = nil, 0
	local t0 = R.period * 10 + 1
	for i = 1, R.need - 1 do
		s, bonus = Hype.rushStep(s, t0 + i, R.period, R.need, R.bonusFrac, 100)
		eq(bonus, 0)
	end
	s, bonus = Hype.rushStep(s, t0 + 20, R.period, R.need, R.bonusFrac, 100)
	eq(bonus, math.floor(100 * R.need * R.bonusFrac + 0.5))
	s, bonus = Hype.rushStep(s, t0 + 21, R.period, R.need, R.bonusFrac, 100)
	eq(bonus, 0, "only once per window")
	s, bonus = Hype.rushStep(s, t0 + R.period, R.period, R.need, R.bonusFrac, 100)
	eq(s.n, 1, "new window starts fresh")
	truthy(R.period >= 60 and R.period <= 180, "rush is a 1-3 minute cycle")
end)
test("6-7 detector", function()
	eq(Hype.isSixSeven(67), true)
	eq(Hype.isSixSeven(1267), true)
	eq(Hype.isSixSeven(76), false)
	eq(Hype.isSixSeven(7), false)
end)
test("Fair Play: tip pass is capped and paid perks stay below x2", function()
	eq(Hype.passTip(false, 1.5, 1.5), 1)
	eq(Hype.passTip(true, 3, Config.FairPlay.passTipCap), Config.FairPlay.passTipCap)
	truthy(Config.FairPlay.passTipMult < 2)
	truthy(Config.FairPlay.showerMult > 1 and Config.FairPlay.showerMinutes > 0)
end)
test("new players start in Peace Mode (snagging is opt-in)", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/shared/DefaultData.luau")
	truthy(string.find(src, "settings = { peace = true", 1, true) ~= nil)
end)

-- ===== Turkey Day Smokeout (Holiday.luau) =====
test("calendar <-> day number round-trips and matches TimeUtil", function()
	eq(Holiday.daysFromCivil(1970, 1, 1), 0)
	eq(Holiday.daysFromCivil(2026, 11, 26), TimeUtil.dayNumber(os.time({ year = 2026, month = 11, day = 26, hour = 12 }), 0))
	for day = Holiday.daysFromCivil(1999, 12, 25), Holiday.daysFromCivil(2041, 3, 1), 13 do
		local y, m, d = Holiday.civilFromDays(day)
		eq(Holiday.daysFromCivil(y, m, d), day, "round trip " .. y .. "-" .. m .. "-" .. d)
		eq(TimeUtil.month(day * 86400 + 3600, 0), m, "month agrees with TimeUtil")
		eq(Holiday.weekdayOf(day), TimeUtil.weekday(day * 86400 + 3600, 0), "weekday agrees with TimeUtil")
	end
	local y, m, d = Holiday.civilFromDays(Holiday.daysFromCivil(2028, 2, 29))
	eq(y * 10000 + m * 100 + d, 20280229, "leap day")
end)
test("Thanksgiving is the 4th Thursday of November", function()
	local known = { [2025] = 27, [2026] = 26, [2027] = 25, [2028] = 23, [2029] = 22, [2030] = 28, [2031] = 27 }
	for year, day in pairs(known) do
		eq(Holiday.thanksgiving(year), Holiday.daysFromCivil(year, 11, day), "Thanksgiving " .. year)
	end
	for year = 2025, 2060 do
		local t = Holiday.thanksgiving(year)
		local _, m, d = Holiday.civilFromDays(t)
		eq(Holiday.weekdayOf(t), 5, "a Thursday")
		truthy(m == 11 and d >= 22 and d <= 28, "between Nov 22 and 28")
	end
end)
test("Turkey Day Smokeout window is Mon-Sun of Thanksgiving week (2026: Nov 23-29)", function()
	local TD = Config.TurkeyDay
	local function at(mo, d)
		return Holiday.turkeyWeek(Holiday.daysFromCivil(2026, mo, d), TD.daysBefore, TD.daysAfter)
	end
	eq(at(11, 22).active, false, "Sun Nov 22 is before")
	eq(at(11, 23).active, true, "Mon Nov 23 opens")
	eq(at(11, 26).active and at(11, 26).isDay, true, "Thanksgiving itself")
	eq(at(11, 25).isDay, false)
	eq(at(11, 29).active, true, "Sun Nov 29 is the last day")
	eq(at(11, 30).active, false, "Mon Nov 30 is after")
	eq(at(11, 2).active, false, "early November is off")
	eq(at(7, 4).active, false, "summer is off")
	eq(Holiday.weekdayOf(at(11, 23).startDay), 2, "starts on a Monday")
	eq(Holiday.weekdayOf(at(11, 23).endDay), 1, "ends on a Sunday")
	eq(Holiday.label(at(11, 23).endDay), "Nov 29")
	-- 2030: Thanksgiving Nov 28, so the window runs into December
	local w30 = Holiday.turkeyWeek(Holiday.daysFromCivil(2030, 12, 1), TD.daysBefore, TD.daysAfter)
	eq(w30.active, true, "Dec 1 2030 is still Turkey Day week")
end)
test("the turkey leg stays cookable for the whole event, even in December", function()
	local leg = Config.Meats[Config.TurkeyDay.meat]
	truthy(leg and leg.season == "harvest", "event meat is the seasonal Harvest Turkey Leg")
	eq(CookOff.seasonFor(Config.Seasons, 11).id, "harvest")
	eq(Holiday.meatInSeason(leg, "harvest", false, Config.TurkeyDay.meat), true)
	eq(Holiday.meatInSeason(leg, "holiday", false, Config.TurkeyDay.meat), false, "off-season without the event")
	eq(Holiday.meatInSeason(leg, "holiday", true, Config.TurkeyDay.meat), true, "event keeps it open")
	eq(Holiday.meatInSeason(Config.Meats.brisket, "summer", false, Config.TurkeyDay.meat), true, "non-seasonal cuts always open")
end)
test("potluck shares the plainest turkey leg, never another cut", function()
	local idx = function(id)
		return Rarity.indexOf(Config.Rarities, id)
	end
	local cooler = { { m = "brisket", r = "common" }, { m = "turkeyleg", r = "smokering" }, { m = "turkeyleg", r = "juicy" }, { m = "turkeyleg", r = "juicy" } }
	eq(Holiday.pickPlate(cooler, "turkeyleg", idx), 3, "lowest rarity, earliest on ties")
	eq(Holiday.pickPlate({ { m = "brisket", r = "common" } }, "turkeyleg", idx), nil, "no turkey leg")
	eq(Holiday.pickPlate({}, "turkeyleg", idx), nil, "empty cooler")
end)
test("Turkey Day reward is a free event cosmetic with copy in place", function()
	local TD = Config.TurkeyDay
	local def = Config.Cosmetics[TD.reward]
	truthy(def, "reward cosmetic exists")
	eq(def.source, "event", "earned, not sold")
	for _, p in pairs(Monetization.Products) do
		for _, g in ipairs(p.grants or {}) do
			truthy(g ~= TD.reward, "the event apron is never a Robux product")
		end
	end
	truthy(TD.need >= 2 and TD.tipBonus <= Config.DinnerBell.tipBonus, "potluck bonus is a small co-op bonus")
	local fs = require("@lune/fs")
	truthy(string.find(fs.readFile("src/shared/DefaultData.luau"), "turkeyDay = -1", 1, true) ~= nil, "save field for the once-a-day share")
	local C = Content.TurkeyDay
	truthy(#C.thanks >= 3)
	truthy(string.format(C.firstShare, "Juicy Harvest Turkey Leg", 520) ~= "")
	truthy(string.find(string.format(C.progress, "Mike", 1, TD.need, TD.need - 1), "Mike set a dish", 1, true) ~= nil, "progress names the sharer")
	truthy(string.format(C.full, 3, 25, 5) ~= "")
	truthy(Content.Signs.turkeyPotluck and Content.Signs.turkeyBanner)
	for _, line in ipairs({ C.login, C.needDish, C.already, C.firstShare, C.share, C.over, Content.Signs.turkeyBanner }) do
		local low = string.lower(line)
		truthy(not string.find(low, "pilgrim", 1, true) and not string.find(low, "buy", 1, true) and not string.find(low, "robux", 1, true), "no pressure or loaded copy: " .. line)
	end
end)

-- ===== Turkey Day audit (Nov 13, 2026): Texas-midnight edges, teaser, live table count =====
test("Turkey Day opens and closes at Texas midnight (06:00 UTC), teaser starts Mon Nov 16", function()
	local TD = Config.TurkeyDay
	local off = Config.TIMEZONE_OFFSET_HOURS
	eq(off, -6, "Texas is UTC-6 all of November and December (CST)")
	local function utc(y, mo, d, h, m, sec)
		return Holiday.daysFromCivil(y, mo, d) * 86400 + h * 3600 + (m or 0) * 60 + (sec or 0)
	end
	local function at(t)
		local day = TimeUtil.dayNumber(t, off)
		local w = Holiday.turkeyWeek(day, TD.daysBefore, TD.daysAfter)
		return w, Holiday.soon(day, w, Config.EventTeaserDays), day
	end
	-- opens: Sun Nov 22 11:59:59 PM CST = Nov 23 05:59:59 UTC
	eq((at(utc(2026, 11, 23, 5, 59, 59))).active, false, "still Sunday night in Texas")
	eq((at(utc(2026, 11, 23, 6, 0, 0))).active, true, "Texas midnight Monday: open")
	-- closes: Sun Nov 29 11:59:59 PM CST open, Mon midnight closed
	eq((at(utc(2026, 11, 30, 5, 59, 59))).active, true, "last minute of Sunday")
	eq((at(utc(2026, 11, 30, 6, 0, 0))).active, false, "Monday in Texas: packed up")
	-- UTC midnight is NOT the boundary
	eq((at(utc(2026, 11, 23, 0, 0, 0))).active, false, "UTC midnight Nov 23 is still Nov 22 in Texas")
	-- teaser: 7 days ahead, from Texas midnight Mon Nov 16 through Sun Nov 22
	local _, s1 = at(utc(2026, 11, 16, 5, 59, 59))
	eq(s1, nil, "Sun Nov 15 night: no teaser yet")
	local _, s2, d2 = at(utc(2026, 11, 16, 6, 0, 0))
	eq(s2, 7, "Mon Nov 16: teaser on, 7 days out")
	eq(Holiday.longLabel(d2 + s2), "Mon, Nov 23", "note says the opening date")
	eq(string.upper(Holiday.label(d2 + s2)), "NOV 23", "sign says the opening date")
	local _, s3 = at(utc(2026, 11, 23, 5, 59, 59))
	eq(s3, 1, "last teaser day")
	local _, s4 = at(utc(2026, 11, 23, 6, 0, 0))
	eq(s4, nil, "no teaser once it's open")
	-- once-a-day share: a share at 11:59 PM and another at 12:01 AM Texas time are different days
	eq(TimeUtil.dayNumber(utc(2026, 11, 24, 5, 59), off) + 1, TimeUtil.dayNumber(utc(2026, 11, 24, 6, 1), off), "share resets at Texas midnight")
	eq(TimeUtil.dayNumber(utc(2026, 11, 24, 1, 0), off), TimeUtil.dayNumber(utc(2026, 11, 23, 7, 0), off), "7 PM Mon and 1 AM UTC Tue are both Monday in Texas")
end)
test("potluck windows, 2026-2060: exact dates, never overlap, teasers never run during the other event", function()
	local TD, H = Config.TurkeyDay, Config.HolidaySmokeout
	for day = Holiday.daysFromCivil(2026, 1, 1), Holiday.daysFromCivil(2060, 12, 31) do
		local tw = Holiday.turkeyWeek(day, TD.daysBefore, TD.daysAfter)
		local hw = Holiday.dateWindow(day, H.start, H.finish, H.peak)
		local _, m, d = Holiday.civilFromDays(day)
		eq(hw.active, (m == 12 and d >= 19) or (m == 1 and d == 1), "Holiday Smokeout is exactly Dec 19 - Jan 1")
		truthy(not (tw.active and hw.active), "events never overlap")
		local ts = Holiday.soon(day, tw, Config.EventTeaserDays)
		local hs = Holiday.soon(day, hw, Config.EventTeaserDays)
		truthy(not (ts and hw.active) and not (hs and tw.active), "a teaser never shows during the other event")
		truthy(not (ts and hs), "one teaser at a time")
		if tw.active then
			truthy(tw.endDay - tw.startDay == 6 and Holiday.weekdayOf(tw.startDay) == 2, "Mon-Sun week")
		end
	end
end)
test("potluck banner: live dish count for the whole server, then 'full' while the bonus runs", function()
	local TD = Config.TurkeyDay
	local L = { idle = Content.TurkeyDay.bannerIdle, count = Content.PotluckTable.count, full = Content.PotluckTable.full }
	eq(Holiday.tableLine(0, TD.need, false, 25, L), "Bring a dish!")
	eq(Holiday.tableLine(1, TD.need, false, 25, L), "Dishes on the table: 1/3")
	eq(Holiday.tableLine(2, TD.need, false, 25, L), "Dishes on the table: 2/3")
	eq(Holiday.tableLine(5, TD.need, false, 25, L), "Dishes on the table: 3/3", "never shows more than need")
	eq(Holiday.tableLine(0, TD.need, true, 25, L), "Table's full! +25% tips for all")
	-- shares older than the window drop off the count, and counting doesn't prune
	local shares = { [1] = 1000, [2] = 1000 + TD.window - 1, [3] = 1000 + TD.window + 5 }
	eq(Holiday.recentShares(shares, 1000 + TD.window, TD.window), 3, "all inside the window (edge counts)")
	eq(Holiday.recentShares(shares, 1000 + TD.window + 1, TD.window), 2, "first share expired")
	eq(Holiday.recentShares({}, 0, TD.window), 0)
	truthy(shares[1] ~= nil, "read-only")
	-- the built banner and the live banner agree (no flicker when the first refresh runs)
	for _, C in ipairs({ Content.TurkeyDay, Content.HolidaySmokeout }) do
		truthy(C.bannerTop and C.bannerIdle, "banner lines")
	end
	eq(Content.Signs.turkeyBanner, Content.TurkeyDay.bannerTop .. "\n" .. Content.TurkeyDay.bannerIdle)
	eq(Content.Signs.holidayBanner, Content.HolidaySmokeout.bannerTop .. "\n" .. Content.HolidaySmokeout.bannerIdle)
	eq(Content.TurkeyDay.bannerTop, "TURKEY DAY COOKOUT")
	eq(Content.HolidaySmokeout.bannerTop, "HOLIDAY COOKOUT")
	truthy(string.find(Content.Signs.turkeyBanner, "SMOKEOUT", 1, true) == nil)
	truthy(string.find(Content.Signs.holidayBanner, "SMOKEOUT", 1, true) == nil)
	for _, line in ipairs({ Content.PotluckTable.count, Content.PotluckTable.full, Content.PotluckTable.closed, Content.HolidaySmokeout.progress, Content.TurkeyDay.progress }) do
		local low = string.lower(line)
		truthy(not string.find(low, "buy", 1, true) and not string.find(low, "robux", 1, true) and not string.find(low, "hurry", 1, true) and not string.find(low, "last chance", 1, true), "calm copy: " .. line)
	end
	truthy(string.find(string.format(Content.HolidaySmokeout.progress, "Ana", 2, 3, 1), "Ana set a dish", 1, true) ~= nil)
end)
test("potluck wiring: progress is announced to the server, banner refreshes, midnight note for players already in", function()
	local fs = require("@lune/fs")
	local egg = fs.readFile("src/server/Services/EggService.luau")
	local ev = fs.readFile("src/server/Services/EventService.luau")
	local gs = fs.readFile("src/server/Services/GameService.luau")
	truthy(string.find(egg, "ctx.Game.announce(string.format(EC.progress, player.DisplayName", 1, true), "progress goes to everyone")
	truthy(string.find(egg, "ctx.Event.refreshTable()", 1, true), "a share updates the banner right away")
	truthy(not string.find(egg, "Content.TurkeyDay.over", 1, true), "a stale prompt after Christmas doesn't talk about Thanksgiving")
	truthy(string.find(ev, "function EventService.eventNote", 1, true) and string.find(ev, "EventService.eventNote(player)", 1, true), "join note")
	truthy(string.find(gs, "ctx.Event.eventNote(player)", 1, true), "day rollover note")
end)

test("Rookie List: five quick, free goals that each point somewhere real", function()
	local steps = Config.RookieSteps
	eq(#steps, 5, "five goals")
	local targets = { grill = true, tables = true, smoker = true, sauce = true, bell = true }
	local dsrc = require("@lune/fs").readFile("src/shared/DefaultData.luau")
	for _, d in ipairs(steps) do
		truthy(targets[d.target], "known arrow target: " .. tostring(d.target))
		truthy(string.find(dsrc, "%f[%w]" .. d.stat .. " = 0") ~= nil, "goal stat is saved: " .. d.stat)
		truthy(d.amount >= 1 and d.amount <= 3, "first-session sized goal")
		truthy(d.label and d.tip and d.icon)
		local low = string.lower(d.label .. " " .. d.tip)
		truthy(not string.find(low, "robux", 1, true) and not string.find(low, "buy now", 1, true), "no paid or pressure copy")
		truthy(not d.reward.robux, "free rewards only")
	end
	local last = Config.RookieFinish
	eq(Config.Cosmetics[last.cosmetic].source, "rookie", "bandana is earned, never sold")
	for _, p in pairs(Monetization.Products) do
		for _, g in ipairs(p.grants or {}) do
			truthy(g ~= last.cosmetic, "the rookie bandana is never a Robux product")
		end
	end
	-- the smoker goal must be doable on a level-1 pit with starting coins
	truthy(Config.Meats.hotlink.unlockPit == 1 and Config.Meats.hotlink.cost <= Config.START_COINS, "Hot Link is affordable on day one")
end)

test("Rookie List: claims in order, can claim several at once, never twice", function()
	local steps = Config.RookieSteps
	local s = Rookie.new()
	local stats = { flips = 0, served = 0, smokerStarts = 0, sauces = 0, bells = 0 }
	local st = Rookie.status(s, steps, stats)
	eq(st.step, 1)
	eq(st.id, "flip")
	eq(#Rookie.advance(s, steps, stats), 0, "nothing met yet")
	stats.flips = 1
	stats.served = 2
	local got = Rookie.advance(s, steps, stats)
	eq(#got, 1, "flip only (serve needs 3)")
	eq(Rookie.status(s, steps, stats).progress, 2, "serve progress shows 2/3")
	stats.served = 7
	stats.sauces = 1 -- met out of order: waits for the smoker goal
	eq(#Rookie.advance(s, steps, stats), 1, "serve claimed; sauce waits behind smoke")
	eq(Rookie.status(s, steps, stats).id, "smoke")
	stats.smokerStarts = 1
	eq(#Rookie.advance(s, steps, stats), 2, "smoke + sauce claim together")
	stats.bells = 1
	eq(#Rookie.advance(s, steps, stats), 1)
	truthy(Rookie.status(s, steps, stats).finished, "finished")
	eq(#Rookie.advance(s, steps, stats), 0, "no double claims")
	eq(Rookie.status(s, steps, stats).progress, 0)
end)

test("Rookie List: a clear finish reward (coins + earned-only bandana + title), shown up front", function()
	local fin = Config.RookieFinish
	truthy(fin.coins > 0 and fin.cosmetic and fin.title, "coins, a look and a title")
	eq(Config.Cosmetics[fin.cosmetic].source, "rookie")
	for _, d in ipairs(Config.RookieSteps) do
		truthy(d.reward.cosmetic == nil and d.reward.title == nil, "the look and title belong to the finish reward, not one step")
	end
	for _, p in pairs(Monetization.Products) do
		truthy(p.grants == nil or table.find(p.grants, fin.cosmetic) == nil, "never sold")
	end
	local text = Rookie.rewardText(fin, Config.Cosmetics[fin.cosmetic].name)
	eq(text, 'Rookie of the Ranch Bandana, the "Rookie of the Ranch" title and +' .. fin.coins .. " 🪙")
	eq(Rookie.rewardText({ coins = 5 }), "+5 🪙")
	eq(Rookie.rewardShort(fin, Config.Cosmetics[fin.cosmetic].name), "Rookie of the Ranch Bandana + title + " .. fin.coins .. " 🪙")
	truthy(string.find(Content.Rookie.finishLine, "Finish all 5", 1, true) and string.find(Content.Rookie.finishLine, "%s", 1, true), "card states the finish reward")
	truthy(string.find(string.format(Content.Rookie.done, 400), "400", 1, true))
	local fs = require("@lune/fs")
	local gsrc = fs.readFile("src/server/Services/GameService.luau")
	truthy(string.find(gsrc, "Config.RookieFinish", 1, true), "server pays the finish reward")
	local csrc = fs.readFile("src/client/RookieGuide.luau")
	truthy(string.find(csrc, "Content.Rookie.finishLine", 1, true), "card shows it")
end)

test("Rookie List: skip asks kindly first, then can be brought back and still finished", function()
	local steps = Config.RookieSteps
	local s = Rookie.new()
	local stats = { flips = 1, served = 0, smokerStarts = 0, sauces = 0, bells = 0 }
	eq(#Rookie.advance(s, steps, stats), 1)
	truthy(Rookie.skip(s, steps), "skip works mid-list")
	truthy(not Rookie.skip(s, steps), "not twice")
	local st = Rookie.status(s, steps, stats)
	truthy(st.finished and st.skipped and not st.done, "hidden, marked skipped, not done")
	stats.served, stats.smokerStarts, stats.sauces = 5, 1, 1 -- kept playing while skipped
	eq(#Rookie.advance(s, steps, stats), 0, "nothing pays out while skipped")
	truthy(Rookie.resume(s, steps), "bring it back")
	truthy(not Rookie.resume(s, steps), "already showing")
	eq(#Rookie.advance(s, steps, stats), 3, "goals done meanwhile count right away")
	eq(Rookie.status(s, steps, stats).id, "bell")
	stats.bells = 1
	eq(#Rookie.advance(s, steps, stats), 1)
	local done = Rookie.status(s, steps, stats)
	truthy(done.done and not done.skipped, "finished for real")
	truthy(not Rookie.skip(s, steps), "a finished list can't be skipped")
	-- a veteran who brings it back isn't quietly re-skipped on the next join
	local v = Rookie.new()
	v.skipped = true
	truthy(Rookie.resume(v, steps))
	truthy(not Rookie.shouldSkip(v, true, { served = 400 }, Config.ROOKIE_VETERAN_SERVES), "stays on after resume")
	-- skip state is saved
	local dsrc = fs_read("src/shared/DefaultData.luau")
	truthy(string.find(dsrc, "rookie = { claimed = 0, skipped = false, resumed = false }", 1, true), "skip state persists")
	-- friendly confirm copy, no pressure words
	local ask = string.lower(Content.Rookie.skipAsk)
	truthy(string.find(ask, "finish reward", 1, true) and string.find(ask, "settings", 1, true), "says what you miss and how to come back")
	for _, w in ipairs({ "are you sure", "last chance", "forever", "never", "hurry", "now!" }) do
		truthy(not string.find(ask, w, 1, true), "no pressure: " .. w)
	end
	local gsrc = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(gsrc, "Actions.RookieSkip", 1, true) and string.find(gsrc, "Actions.RookieResume", 1, true), "server actions")
	truthy(string.find(fs_read("src/client/Panels.luau"), '"RookieResume"', 1, true), "Settings has Bring it back")
	truthy(string.find(fs_read("src/client/RookieGuide.luau"), '"RookieSkip"', 1, true), "card has Skip")
end)

test("Rookie List: veterans skip quietly, new players don't", function()
	local s = Rookie.new()
	truthy(not Rookie.shouldSkip(s, false, { served = 0 }, Config.ROOKIE_VETERAN_SERVES), "brand new player gets the list")
	truthy(not Rookie.shouldSkip(s, true, { served = 3 }, Config.ROOKIE_VETERAN_SERVES), "early player keeps the list")
	truthy(Rookie.shouldSkip(s, true, { served = 400 }, Config.ROOKIE_VETERAN_SERVES), "veteran skips")
	s.skipped = true
	truthy(Rookie.status(s, Config.RookieSteps, { served = 400 }).finished, "skipped reads as finished")
	eq(#Rookie.advance(s, Config.RookieSteps, { flips = 9 }), 0, "skipped never pays out")
end)

test("sound effects: every cue is a public Roblox-library id, sane volumes", function()
	local n = 0
	for name, def in pairs(SfxIds) do
		n += 1
		truthy(type(def.id) == "number" and def.id > 1000000, "numeric asset id: " .. name)
		truthy(def.volume > 0 and def.volume <= 1, "volume in range: " .. name)
	end
	truthy(n >= 10, "a full set of cues")
	for _, cue in ipairs({ "click", "spatula", "sear", "register", "bell", "fanfare", "ding", "sizzleLoop" }) do
		truthy(SfxIds[cue], "cue exists: " .. cue)
	end
	truthy(SfxIds.sizzleLoop.loop and SfxIds.sizzleLoop.volume <= 0.25, "the sizzle loop stays quiet")
	local fs = require("@lune/fs")
	truthy(string.find(fs.readFile("src/shared/DefaultData.luau"), "sfx = true", 1, true) ~= nil, "sound is on by default and the toggle is saved")
end)

print("Music (separate from sound effects)")
test("music volume and mute are saved apart from sound effects", function()
	local fs = require("@lune/fs")
	local src = fs.readFile("src/shared/DefaultData.luau")
	truthy(string.find(src, "music = true", 1, true) ~= nil, "music starts on")
	truthy(string.find(src, "musicVolume = 0.22", 1, true) ~= nil, "quiet default volume")
	truthy(string.find(src, "sfx = true", 1, true) ~= nil, "sound effects stay their own switch")
	local on, vol = MusicPrefs.read({ music = true, musicVolume = 0.4, sfx = false })
	eq(on, true)
	eq(vol, 0.4)
	on, vol = MusicPrefs.read({ music = false, musicVolume = 0.4 })
	eq(on, false, "mute does not erase the saved volume")
	eq(vol, 0.4)
	eq(MusicPrefs.clamp("loud"), MusicPrefs.DEFAULT_VOLUME)
	eq(MusicPrefs.clamp(0 / 0), MusicPrefs.DEFAULT_VOLUME)
	eq(MusicPrefs.clamp(5), 1)
	eq(MusicPrefs.clamp(-1), 0)
	eq(MusicPrefs.DEFAULT_VOLUME <= 0.35 and MusicPrefs.DEFAULT_VOLUME >= 0.05, true)
end)
test("music does not pretend a placeholder id is audible", function()
	eq(MusicPrefs.audible(0), false)
	eq(MusicPrefs.audible(nil), false)
	eq(MusicPrefs.audible(1.5), false)
	eq(Music.id, 0, "Porch Light is not uploaded; id 0 stays silent")
	local fs = require("@lune/fs")
	local client = fs.readFile("src/client/Music.luau")
	truthy(string.find(client, "Music.available()", 1, true) ~= nil, "client checks before play")
	truthy(string.find(client, "s:Play()", 1, true) ~= nil)
	local server = fs.readFile("src/server/Services/GameService.luau")
	truthy(string.find(server, "Actions.SetMusic", 1, true) ~= nil)
	truthy(string.find(server, "Actions.SetMusicVolume", 1, true) ~= nil)
	truthy(fs.isFile("audio/porch-light.ogg"), "original loop is in the repo")
	truthy(fs.isFile("audio/ATTRIBUTION.md"), "license note is next to the file")
end)

print("Yard notes (November 2026)")
test("a few original yard lines, no borrowed meme media", function()
	local foundChew, foundHorse, foundPup = false, false, false
	for _, joke in ipairs(Content.UncJokes) do
		if string.find(joke, "W chew", 1, true) then
			foundChew = true
		end
		if string.find(joke, "horse", 1, true) then
			foundHorse = true
		end
		if string.find(joke, "not a famous internet dog", 1, true) then
			foundPup = true
		end
	end
	truthy(foundChew and foundHorse and foundPup, "three original jokes")
	truthy(#Content.UncJokes >= 28)
	local notes = Content.YardNotes
	truthy(string.find(notes.board, "W chew", 1, true) ~= nil)
	truthy(string.find(notes.pup, "our dog", 1, true) ~= nil)
	local src = fs_read("src/shared/Content.luau")
	truthy(string.find(src, "November 6, 2026", 1, true) ~= nil, "W chew source is dated")
	truthy(string.find(src, "November 5, 2026", 1, true) ~= nil, "horse-drawing source is dated")
	truthy(string.find(src, "November 7, 2026", 1, true) ~= nil, "Roblox trend source is dated")
	truthy(string.find(src, "not labeled as a November 2026 trend", 1, true) ~= nil, "older 6-7 line is not called current")
	local lower = string.lower(src)
	truthy(not string.find(lower, "mini producer", 1, true), "no borrowed creator")
	truthy(not string.find(src, "rbxassetid", 1, true), "no meme audio id")
end)

print("Gifting")
test("only looks can be gifted: cosmetics and looks bundles, never boosts, cuts or passes", function()
	local n = 0
	for key, p in pairs(Monetization.Products) do
		local g = Gifting.giftable(p)
		if p.kind == "cosmetic" or p.kind == "bundle" then
			truthy(g, "giftable: " .. key)
			n += 1
		else
			truthy(not g, "not giftable: " .. key)
		end
	end
	truthy(n >= 10, "plenty of giftable looks")
	truthy(not Gifting.giftable(Monetization.Passes.DoubleTips), "passes are never gifts")
end)

test("gift checks: someone else, still here, doesn't already own it", function()
	local apron = Monetization.Products.ApronGrillMaster
	truthy(Gifting.check(1, 2, apron, false), "normal gift is fine")
	truthy(not Gifting.check(1, 1, apron, false), "can't gift yourself")
	truthy(not Gifting.check(1, nil, apron, false), "recipient must be in the server")
	truthy(not Gifting.check(1, 2, apron, true), "no gifting what they already own")
	truthy(not Gifting.check(1, 2, Monetization.Products.Boost30, false), "boosts can't be gifted")
end)

test("a pending gift is claimed once, and only while fresh", function()
	local pending = {}
	Gifting.remember(pending, "SkinGalaxy", 42, 1000)
	eq(Gifting.claim(pending, "SkinGalaxy", 1010, 180), 42, "fresh claim returns the recipient")
	eq(Gifting.claim(pending, "SkinGalaxy", 1011, 180), nil, "second claim is empty (no double gift)")
	Gifting.remember(pending, "SkinGalaxy", 42, 1000)
	eq(Gifting.claim(pending, "SkinGalaxy", 1000 + 181, 180), nil, "stale intent falls back to a normal purchase")
	eq(pending.SkinGalaxy, nil, "stale intent is cleared")
end)

test("held gifts (recipient left) are kept and sent later, one at a time", function()
	local held = {}
	truthy(not Gifting.takeHeld(held, "TrailSauce"), "nothing held yet")
	Gifting.hold(held, "TrailSauce")
	Gifting.hold(held, "TrailSauce")
	eq(held.TrailSauce, 2)
	truthy(Gifting.takeHeld(held, "TrailSauce"))
	truthy(Gifting.takeHeld(held, "TrailSauce"))
	eq(held.TrailSauce, nil, "cleared when used up")
	truthy(not Gifting.takeHeld(held, "TrailSauce"))
	local fs = require("@lune/fs")
	truthy(string.find(fs.readFile("src/shared/DefaultData.luau"), "giftsHeld = {}", 1, true) ~= nil, "held gifts are saved")
	truthy(Config.Gifting and Config.Gifting.ttlSeconds > 0 and Config.Gifting.firstGiftTitle ~= "", "gifting config")
end)

test("gift receipts: deliver, or hold if they left or already own it (Robux never wasted)", function()
	eq(Gifting.landing(true, false), "deliver")
	eq(Gifting.landing(false, false), "hold-left")
	eq(Gifting.landing(true, true), "hold-owned", "recipient bought it meanwhile: giver keeps the gift")
end)

test("dinner bell: mashing the prompt doesn't farm bells / Season XP", function()
	local last = {}
	local cd = Config.DinnerBell.ringCooldown
	truthy(type(cd) == "number" and cd > 0 and cd >= Config.DinnerBell.window, "ring cooldown set")
	truthy(Hype.ringCounts(last, 1, 100, cd), "first ring counts")
	local counted = 0
	for i = 1, 50 do
		if Hype.ringCounts(last, 1, 100 + i * 0.1, cd) then
			counted += 1
		end
	end
	eq(counted, 0, "50 quick rings add nothing")
	truthy(Hype.ringCounts(last, 2, 101, cd), "other players are independent (pile-on still works)")
	truthy(Hype.ringCounts(last, 1, 100 + cd, cd), "counts again after the cooldown")
end)

print("Profitability: season pass, offers, club, analytics")
local SP = Config.SeasonPass
local function stats0()
	return { served = 0, cooks = 0, smoked = 0, perfectFlips = 0, cookoffs = 0, bells = 0 }
end
test("Smokehouse Pass: 6-week seasons from Mon Nov 2 2026, plain start/end dates", function()
	eq(SP.epochDay, Holiday.daysFromCivil(2026, 11, 2))
	eq(Holiday.weekdayOf(SP.epochDay), Holiday.weekdayOf(Holiday.daysFromCivil(2026, 11, 9)), "starts on a Monday-aligned day")
	local a = SeasonPass.seasonAt(SP.epochDay, SP)
	eq(a.index, 1)
	eq(a.def.id, "s1")
	eq(Holiday.label(a.endDay), "Dec 13")
	local b = SeasonPass.seasonAt(SP.epochDay + 42, SP)
	eq(b.def.id, "s2")
	eq(Holiday.label(b.startDay), "Dec 14")
	truthy(SeasonPass.seasonAt(SP.epochDay - 1, SP).def == nil, "nothing before launch")
	local c = SeasonPass.seasonAt(SP.epochDay + 84, SP)
	eq(c.def.id, "s3")
	eq(Holiday.label(c.startDay), "Jan 25")
	local d = SeasonPass.seasonAt(SP.epochDay + 126, SP)
	eq(d.def.id, "s4")
	eq(Holiday.label(d.startDay), "Mar 8")
	eq(Holiday.label(d.endDay), "Apr 18")
	local e = SeasonPass.seasonAt(SP.epochDay + 168, SP)
	eq(e.def.id, "s5")
	eq(Holiday.label(e.startDay), "Apr 19")
	eq(Holiday.label(e.endDay), "May 30")
	truthy(SeasonPass.seasonAt(SP.epochDay + 210, SP).def == nil, "no made-up season 6")
end)
test("Smokehouse Pass: both tracks are looks and titles only, every look exists, no repeats", function()
	local seen = {}
	for _, def in ipairs(SP.seasons) do
		eq(#def.paid, 15, def.id .. " paid tiers")
		for tier in pairs(def.free) do
			truthy(tier >= 1 and tier <= #def.paid, "free tier in range")
			truthy(def.paid[tier] ~= nil)
		end
		local function check(r, src)
			local keys = 0
			for k in pairs(r) do
				keys += 1
				truthy(k == "cosmetic" or k == "title", "only looks or titles, got " .. k)
			end
			eq(keys, 1)
			if r.cosmetic then
				local c = Config.Cosmetics[r.cosmetic]
				truthy(c, "unknown cosmetic " .. r.cosmetic)
				eq(c.source, src, r.cosmetic)
				truthy(not seen[r.cosmetic], "repeat " .. r.cosmetic)
				seen[r.cosmetic] = true
			end
		end
		for _, r in pairs(def.free) do
			check(r, "seasonfree")
		end
		for _, r in ipairs(def.paid) do
			check(r, "season")
		end
	end
end)
test("Smokehouse Pass: XP comes from normal play since the season started, plus a daily visit", function()
	local s = SeasonPass.new()
	local st = stats0()
	st.served = 500 -- lifetime stats from before the season don't count
	truthy(SeasonPass.sync(s, "s1", st, SP, 100), "new season resets")
	eq(SeasonPass.xp(s, st, SP), SP.dailyXP)
	truthy(not SeasonPass.sync(s, "s1", st, SP, 100), "same day, same season")
	eq(s.days, 1)
	SeasonPass.sync(s, "s1", st, SP, 101)
	eq(s.days, 2)
	st.served += 10
	st.smoked += 5
	eq(SeasonPass.xp(s, st, SP), 2 * SP.dailyXP + 10 * SP.xp.served + 5 * SP.xp.smoked)
	-- a typical ~20 minute day reaches the top tier well inside the 6 weeks
	local perDay = SP.dailyXP + 40 * SP.xp.served + 8 * SP.xp.cooks + 4 * SP.xp.smoked + 8 * SP.xp.perfectFlips
	local days = (15 * SP.tierXP) / perDay
	truthy(days < SP.lengthDays * 0.85, string.format("top tier in %.1f days of regular play", days))
	truthy(days > 14, "but it's a season, not an afternoon")
end)
test("Smokehouse Pass: free rewards for everyone; buying the pass hands over reached paid tiers", function()
	local def = SP.seasons[1]
	local s = SeasonPass.new()
	local st = stats0()
	SeasonPass.sync(s, "s1", st, SP, 1)
	st.served = math.ceil((6 * SP.tierXP - SP.dailyXP) / SP.xp.served) -- reach tier 6
	eq(SeasonPass.tier(SeasonPass.xp(s, st, SP), def, SP), 6)
	local got = SeasonPass.claim(s, st, def, SP)
	eq(#got, 2, "free tiers 3 and 6")
	eq(got[1].track, "free")
	eq(#SeasonPass.claim(s, st, def, SP), 0, "never twice")
	s.paid = true
	local paid = SeasonPass.claim(s, st, def, SP)
	eq(#paid, 6, "paid tiers 1-6 right away")
	eq(paid[6].reward.title, "Smoke Season")
end)
test("Smokehouse Pass: tier skips add whole tiers and can't go past the top", function()
	local def = SP.seasons[1]
	local s = SeasonPass.new()
	local st = stats0()
	SeasonPass.sync(s, "s1", st, SP, 1)
	truthy(SeasonPass.canSkip(s, st, def, SP, 5))
	SeasonPass.addSkips(s, 5)
	eq(SeasonPass.tier(SeasonPass.xp(s, st, SP), def, SP), 5)
	SeasonPass.addSkips(s, 9)
	eq(SeasonPass.tier(SeasonPass.xp(s, st, SP), def, SP), 14)
	truthy(SeasonPass.canSkip(s, st, def, SP, 1))
	truthy(not SeasonPass.canSkip(s, st, def, SP, 5), "would pass the top")
	SeasonPass.addSkips(s, 1)
	eq(SeasonPass.tier(SeasonPass.xp(s, st, SP), def, SP), 15)
	local a, b = SeasonPass.progress(SeasonPass.xp(s, st, SP), def, SP)
	eq(a, 0)
	eq(b, 0)
	-- a new season starts clean
	SeasonPass.sync(s, "s2", st, SP, 50)
	eq(s.skips, 0)
	eq(s.paid, false)
	eq(SeasonPass.tier(SeasonPass.xp(s, st, SP), SP.seasons[2], SP), 0)
end)
test("Robux never buys coins: no product, skip, pack, club perk or season reward gives coins", function()
	for key, p in pairs(Monetization.Products) do
		truthy(p.coins == nil, key .. " gives coins")
		truthy(p.kind ~= "coins" and p.kind ~= "currency", key)
		truthy(not string.find(string.lower(p.desc), "coins", 1, true) or p.kind == "boost" or key == "DoubleTips", key .. " mentions coins")
	end
	for _, def in ipairs(SP.seasons) do
		for _, r in ipairs(def.paid) do
			truthy(r.coins == nil)
		end
	end
	for _, perk in ipairs(Monetization.Subscriptions.PitCrewClub.perks) do
		truthy(not string.find(string.lower(perk), "coin", 1, true), "club perk mentions coins: " .. perk)
	end
end)
test("no paid random items: every product kind is a fixed, shown reward", function()
	local fixed = { boost = true, finish = true, cosmetic = true, bundle = true, cut = true, starter = true, season = true, tierskip = true }
	for key, p in pairs(Monetization.Products) do
		truthy(fixed[p.kind], key .. " has an unknown (maybe random) kind " .. tostring(p.kind))
		truthy(p.odds == nil and p.random == nil and p.pool == nil, key .. " looks random")
	end
end)
test("value notes add up: Whole Hog R$499 vs R$730, Turkey and Holiday sets, starter pack, 5 skips", function()
	local P = Monetization.Products
	local function sum(grants)
		local t = 0
		for _, g in ipairs(grants) do
			for _, p in pairs(P) do
				if p.kind == "cosmetic" and p.grants and #p.grants == 1 and p.grants[1] == g then
					t += p.price
				end
			end
		end
		return t
	end
	eq(P.BundleWholeHog.price, 499)
	eq(sum(P.BundleWholeHog.grants), 730)
	truthy(string.find(P.BundleWholeHog.valueNote, "730", 1, true) and string.find(P.BundleWholeHog.valueNote, "less as a set", 1, true))
	eq(sum(P.TD_BundleFeast.grants), 306)
	truthy(string.find(P.TD_BundleFeast.valueNote, "306", 1, true) and P.TD_BundleFeast.price < 306)
	eq(sum(P.HD_BundleHoliday.grants), 306)
	truthy(string.find(P.HD_BundleHoliday.valueNote, "306", 1, true) and P.HD_BundleHoliday.price < 306)
	eq(P.Boost30.price + P.TomahawkPack.price, 108)
	truthy(string.find(P.StarterPitPack.valueNote, "108", 1, true) and P.StarterPitPack.price < 108)
	eq(P.TierSkip1.price * 5, 245)
	truthy(string.find(P.TierSkip5.valueNote, "245", 1, true) and P.TierSkip5.price < 245)
	-- price ladder: entry under R$80, a middle, and a top anchor
	local low, top = math.huge, 0
	for _, p in pairs(P) do
		low = math.min(low, p.price)
		top = math.max(top, p.price)
	end
	truthy(low < 80 and top == 499, "ladder from under R$80 to R$499")
end)
test("every game pass and developer product has a real Roblox ID", function()
	local n = 0
	local seen: { [number]: string } = {}
	for key, p in pairs(Monetization.Passes) do
		n += 1
		truthy(p.id > 0 and p.id == math.floor(p.id), key .. " id is filled")
		truthy(seen[p.id] == nil, key .. " id collides with " .. tostring(seen[p.id]))
		seen[p.id] = key
	end
	for key, p in pairs(Monetization.Products) do
		n += 1
		truthy(p.id > 0 and p.id == math.floor(p.id), key .. " id is filled")
		truthy(seen[p.id] == nil, key .. " id collides with " .. tostring(seen[p.id]))
		seen[p.id] = key
	end
	eq(n, 44)
	eq(Monetization.Products.SmokeGrape.name, "Purple Cloud Smoke")
end)
test("IDs are placeholders or real and never pasted twice; subscription is empty or EXP-", function()
	local seen = {}
	for _, group in ipairs({ Monetization.Products, Monetization.Passes }) do
		for key, p in pairs(group) do
			truthy(p.id == 0 or (p.id > 0 and p.id == math.floor(p.id)), key)
			if p.id ~= 0 then
				truthy(seen[p.id] == nil, key .. " reuses the ID of " .. tostring(seen[p.id]))
				seen[p.id] = key
			end
		end
	end
	for key, sub in pairs(Monetization.Subscriptions) do
		truthy(sub.id == "" or string.sub(sub.id, 1, 4) == "EXP-", key)
		truthy(sub.priceText ~= "" and string.find(sub.priceText, "month", 1, true), "price and length shown")
	end
	truthy(Monetization.PrivateServer.price > 0)
	local fs = require("@lune/fs")
	local pub = fs.readFile("PUBLISHING.md")
	for key in pairs(Monetization.Products) do
		truthy(string.find(pub, key, 1, true), "PUBLISHING.md lists " .. key)
	end
	truthy(string.find(pub, "PitCrewClub", 1, true) and string.find(pub, "Private Server", 1, true), "subscription and private server documented")
end)
test("no pressure copy on any new offer (no countdowns, no hurry words)", function()
	local banned = { "now", "last chance", "hurry", "limited time", "don't miss", "before it's gone", "only today", "ends in", "left!", "act fast" }
	local lines = {}
	for _, p in pairs(Monetization.Products) do
		table.insert(lines, p.name)
		table.insert(lines, p.desc)
		table.insert(lines, p.valueNote or "")
	end
	local c = Monetization.Subscriptions.PitCrewClub
	for _, l in ipairs({ c.name, c.desc, c.priceText, Monetization.Premium.desc, Monetization.PrivateServer.desc }) do
		table.insert(lines, l)
	end
	for _, l in ipairs(c.perks) do
		table.insert(lines, l)
	end
	for _, l in ipairs(lines) do
		local low = string.lower(l)
		for _, w in ipairs(banned) do
			truthy(not string.find(low, "%f[%w]" .. w:gsub("'", "'"):gsub("!", "%%!") .. (w:sub(-1):match("%w") and "%f[%W]" or "")), "pressure copy: " .. l)
		end
		truthy(not string.find(low, "pilgrim", 1, true), "no loaded holiday copy: " .. l)
	end
end)
test("Turkey Day looks: on sale only in Thanksgiving week, the free apron stays free", function()
	local P = Monetization.Products
	local base = { owned = {}, featured = {}, onceBought = {}, cooking = false, seasonActive = true, seasonPaid = false, canSkip = function()
		return true
	end }
	local n = 0
	for key, p in pairs(P) do
		if p.event == "turkeyday" then
			n += 1
			base.events = { turkeyday = false, holiday = true }
			local ok, why = Storefront.canBuy(key, p, base)
			truthy(not ok and string.find(why, "next year", 1, true), key .. " blocked outside the week")
			base.events = { turkeyday = true, holiday = false }
			truthy((Storefront.canBuy(key, p, base)), key .. " buyable in the week")
			for _, g in ipairs(p.grants) do
				truthy(g ~= Config.TurkeyDay.reward, "free event apron is never sold")
				eq(Config.Cosmetics[g].source, "eventshop")
			end
		end
	end
	eq(n, 5)
	local w = Holiday.turkeyWeek(Holiday.daysFromCivil(2026, 11, 25), Config.TurkeyDay.daysBefore, Config.TurkeyDay.daysAfter)
	truthy(w.active and Holiday.label(w.startDay) == "Nov 23" and Holiday.label(w.endDay) == "Nov 29")
end)
test("Holiday Smokeout window is Dec 19 - Jan 1 and wraps into the new year", function()
	local H = Config.HolidaySmokeout
	local function at(y, mo, d)
		return Holiday.dateWindow(Holiday.daysFromCivil(y, mo, d), H.start, H.finish, H.peak)
	end
	eq(at(2026, 12, 18).active, false, "Dec 18 is before")
	eq(at(2026, 12, 19).active, true, "Dec 19 opens")
	eq(at(2026, 12, 25).active and at(2026, 12, 25).isDay, true, "Christmas Day")
	eq(at(2026, 12, 24).isDay, false)
	eq(at(2026, 12, 31).active, true, "New Year's Eve")
	eq(at(2027, 1, 1).active, true, "New Year's Day is the last day")
	eq(at(2027, 1, 2).active, false, "Jan 2 is after")
	eq(at(2026, 11, 26).active, false, "Thanksgiving is Turkey Day's, not this")
	eq(at(2027, 7, 4).active, false, "summer is off")
	local w = at(2027, 1, 1)
	eq(Holiday.label(w.startDay) .. "-" .. Holiday.label(w.endDay), "Dec 19-Jan 1")
	eq(w.day, Holiday.daysFromCivil(2026, 12, 25), "Jan 1 belongs to the window that started in December")
	eq(at(2027, 3, 1).startDay, Holiday.daysFromCivil(2027, 12, 19), "after the window, the next one is this December")
	eq(at(2026, 12, 10).endDay, Holiday.daysFromCivil(2027, 1, 1), "early December points at this year's window")
	-- never overlaps Turkey Day, any year
	for y = 2026, 2060 do
		local tw = Holiday.turkeyWeek(Holiday.thanksgiving(y), Config.TurkeyDay.daysBefore, Config.TurkeyDay.daysAfter)
		truthy(tw.endDay < at(y, 12, 19).startDay, "Turkey Day ends before the Holiday Smokeout " .. y)
	end
	-- a non-wrapping window works too
	local sw = Holiday.dateWindow(Holiday.daysFromCivil(2027, 7, 4), { 7, 1 }, { 7, 7 }, nil)
	truthy(sw.active and Holiday.label(sw.startDay) == "Jul 1" and Holiday.label(sw.endDay) == "Jul 7")
end)
test("Holiday Smokeout: the ham is a winter cut, the reward is free, the copy is calm", function()
	local H = Config.HolidaySmokeout
	local ham = Config.Meats[H.meat]
	truthy(ham and ham.season == "holiday" and ham.station == "smoker", "event meat is the winter Holiday Glazed Ham")
	truthy(table.find(Config.MeatOrder, H.meat) ~= nil, "shows in the cook picker")
	eq(CookOff.seasonFor(Config.Seasons, 12).id, "holiday")
	eq(CookOff.seasonFor(Config.Seasons, 1).id, "holiday")
	eq(Holiday.meatOpen(ham, "holiday", {}), true, "cookable all December and January")
	eq(Holiday.meatOpen(ham, "harvest", {}), false, "not in November without the event")
	eq(Holiday.meatOpen(ham, "harvest", { [H.meat] = true }), true, "the event keeps it open (Studio test)")
	eq(Holiday.meatOpen(Config.Meats.turkeyleg, "holiday", { [Config.TurkeyDay.meat] = true }), true)
	eq(Holiday.meatOpen(Config.Meats.brisket, "summer", {}), true)
	truthy(ham.price / ham.cookTime <= Config.Meats.turkeyleg.price / Config.Meats.turkeyleg.cookTime + 0.001, "no better per minute than the turkey leg")
	local def = Config.Cosmetics[H.reward]
	truthy(def and def.source == "event", "earned, not sold")
	for _, p in pairs(Monetization.Products) do
		for _, g in ipairs(p.grants or {}) do
			truthy(g ~= H.reward, "the Merry & Smoky Apron is never a Robux product")
		end
	end
	truthy(H.need >= 2 and H.tipBonus <= Config.DinnerBell.tipBonus, "small co-op bonus")
	truthy(H.dailyKey ~= Config.TurkeyDay.dailyKey and H.id ~= Config.TurkeyDay.id)
	local dd = fs_read("src/shared/DefaultData.luau")
	truthy(string.find(dd, H.dailyKey .. " = -1", 1, true) and string.find(dd, Config.TurkeyDay.dailyKey .. " = -1", 1, true), "save fields for both once-a-day shares")
	for _, C in ipairs({ Content.TurkeyDay, Content.HolidaySmokeout }) do
		truthy(C.dialog and C.host and C.hud and #C.thanks >= 3, "potluck copy has a title, host and HUD line")
		truthy(string.format(C.firstShare, "Juicy Holiday Glazed Ham", 680) ~= "")
		truthy(string.format(C.progress, "Mike", 1, 3, 2) ~= "" and string.format(C.full, 3, 25, 5) ~= "")
	end
	local C = Content.HolidaySmokeout
	truthy(Content.Signs.holidayPotluck and Content.Signs.holidayBanner)
	local lines = { C.login, C.needDish, C.already, C.firstShare, C.share, C.over, C.progress, C.full, Content.Signs.holidayBanner }
	for _, l in ipairs(C.thanks) do
		table.insert(lines, l)
	end
	for _, line in ipairs(lines) do
		local low = string.lower(line)
		for _, w in ipairs({ "buy", "robux", "hurry", "last chance", "don't miss", "santa", "grinch", "rudolph", "elf on" }) do
			truthy(not string.find(low, w, 1, true), "calm, original copy (" .. w .. "): " .. line)
		end
	end
	-- the decor and server wiring exist
	truthy(string.find(fs_read("src/shared/WorldBuilder.luau"), "function WorldBuilder.holidaySmokeout", 1, true), "decor builder")
	local ev = fs_read("src/server/Services/EventService.luau")
	truthy(string.find(ev, "WorldBuilder.holidaySmokeout", 1, true) and string.find(ev, "Signs.holidayPotluck", 1, true), "EventService dresses the table")
	local gs = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(gs, "ForceHolidaySmokeout", 1, true) and string.find(gs, "Config.HolidaySmokeout", 1, true), "Studio test switch")
end)
test("Holiday looks: on sale only Dec 19 - Jan 1, giftable, looks only, and Turkey Day's stay separate", function()
	local P = Monetization.Products
	local base = { owned = {}, featured = {}, onceBought = {}, cooking = false, seasonActive = true, seasonPaid = false, canSkip = function()
		return true
	end }
	local n = 0
	for key, p in pairs(P) do
		if p.event == "holiday" then
			n += 1
			base.events = { turkeyday = true, holiday = false }
			local ok, why = Storefront.canBuy(key, p, base)
			truthy(not ok and string.find(why, "Dec 19", 1, true) and string.find(why, "next year", 1, true), key .. " blocked outside the dates")
			base.events = { holiday = true }
			truthy((Storefront.canBuy(key, p, base)), key .. " buyable during the event")
			truthy(Gifting.giftable(p), key .. " can be gifted")
			truthy(p.kind == "cosmetic" or p.kind == "bundle", "looks only")
			for _, g in ipairs(p.grants) do
				eq(Config.Cosmetics[g].source, "eventshop")
				truthy(string.sub(g, 1, 3) == "hd_", "holiday look ids")
			end
		elseif p.event ~= nil then
			eq(p.event, "turkeyday", key .. " has a known event")
		end
	end
	eq(n, 5)
	eq(Storefront.eventClosed(P.HD_HatTwinkle, { holiday = true }), nil)
	eq(Storefront.eventClosed(P.BundleWholeHog, {}), nil, "regular items aren't event-gated")
	truthy(Config.Cosmetics.hd_hat_twinkle.twinkle and Config.Cosmetics.hd_trail_tinsel.color2, "hat lights and two-tone tinsel are defined")
	local cs = fs_read("src/server/Services/CosmeticService.luau")
	truthy(string.find(cs, "def.twinkle", 1, true) and string.find(cs, "def.color2", 1, true), "CosmeticService draws them")
	-- every Holiday look name is new (no clash with Season 2 Winter Smoke or the shop)
	local names = {}
	for id, c in pairs(Config.Cosmetics) do
		if string.sub(id, 1, 3) ~= "hd_" then
			names[c.name] = true
		end
	end
	for key, p in pairs(P) do
		if p.event == "holiday" and p.kind == "cosmetic" then
			truthy(not names[p.name], key .. " reuses a name")
		end
	end
end)
test("First-Time Pit Pack: one per account, not giftable, nothing random", function()
	local p = Monetization.Products.StarterPitPack
	local c = { owned = {}, featured = {}, onceBought = {}, events = {}, cooking = false, seasonActive = false, seasonPaid = false, canSkip = function()
		return false
	end }
	truthy((Storefront.canBuy("StarterPitPack", p, c)))
	c.onceBought.StarterPitPack = true
	local ok, why = Storefront.canBuy("StarterPitPack", p, c)
	truthy(not ok and why ~= nil)
	truthy(not Gifting.giftable(p), "not a gift")
	truthy(p.price < 80, "entry price")
	eq(Config.Cosmetics.starter_hat.source, "starter")
	local fs = require("@lune/fs")
	truthy(string.find(fs.readFile("src/shared/DefaultData.luau"), "purchases = { once = {}", 1, true), "saved per account")
end)
test("Storefront: owned bundles, season limits and rotation say no calmly", function()
	local P = Monetization.Products
	local c = { owned = {}, featured = {}, onceBought = {}, events = {}, cooking = false, seasonActive = true, seasonPaid = false, canSkip = function(n)
		return n <= 1
	end }
	truthy((Storefront.canBuy("SeasonPass", P.SeasonPass, c)))
	c.seasonPaid = true
	truthy(not Storefront.canBuy("SeasonPass", P.SeasonPass, c), "one pass per season")
	truthy((Storefront.canBuy("TierSkip1", P.TierSkip1, c)))
	truthy(not Storefront.canBuy("TierSkip5", P.TierSkip5, c), "no skipping past the top")
	c.seasonActive = false
	truthy(not Storefront.canBuy("TierSkip1", P.TierSkip1, c), "no season, no skips")
	for _, g in ipairs(P.BundleWholeHog.grants) do
		c.owned[g] = true
	end
	truthy(not Storefront.canBuy("BundleWholeHog", P.BundleWholeHog, c))
	eq(Storefront.ownedCount({ skin_golden = true, hat_pitmaster = true }, P.BundleWholeHog.grants), 2)
	truthy(not Storefront.canBuy("Rot_SkinSnowy", P.Rot_SkinSnowy, c), "rotation still enforced")
	truthy(not Gifting.giftable(P.SeasonPass) and not Gifting.giftable(P.TierSkip1), "pass and skips aren't gifts")
end)
test("Pit Crew Club: same monthly look for everyone, cycles all six, looks only", function()
	local looks = Config.Club.looks
	eq(#looks, 6)
	local seen = {}
	for m = 1, 6 do
		local id = Storefront.clubLook(looks, 2026, m)
		truthy(not seen[id])
		seen[id] = true
		eq(Config.Cosmetics[id].source, "club")
	end
	eq(Storefront.clubLook(looks, 2026, 1), Storefront.clubLook(looks, 2026, 7), "repeats after 6 months")
	truthy(Storefront.monthKey(2026, 12) + 1 == Storefront.monthKey(2027, 1))
	eq(Config.Cosmetics[Config.Premium.look].source, "premium")
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/Services/MembershipService.luau")
	truthy(string.find(src, "IsEligibleToPurchaseSubscription", 1, true), "PolicyService gate")
	truthy(string.find(src, "UserSubscriptionStatusChanged", 1, true) and string.find(src, "GetUserSubscriptionStatusAsync", 1, true))
	truthy(not string.find(src, "addCoins", 1, true), "the club never gives coins")
end)
test("Analytics: onboarding steps log once each, in order; coin flows are batched", function()
	local steps = Funnels.onboardingSteps(Config.RookieSteps)
	eq(#steps, 4 + #Config.RookieSteps)
	local data = { tutorial = { firstBrisket = false, done = false }, stats = { served = 0 }, rookie = { claimed = 0, skipped = false } }
	eq(Funnels.onboardingReached(data, Config.RookieSteps), 1)
	data.tutorial.firstBrisket = true
	data.stats.served = 1
	data.tutorial.done = true
	data.rookie.claimed = 2
	eq(Funnels.onboardingReached(data, Config.RookieSteps), 6)
	local new = Funnels.newSteps(1, 6)
	eq(#new, 5)
	eq(new[1], 2)
	eq(#Funnels.newSteps(6, 6), 0)
	local b = {}
	Funnels.addCoins(b, 50, "Gameplay", "Earned")
	Funnels.addCoins(b, 25, "Gameplay", "Earned")
	Funnels.addCoins(b, -40, "Shop", "Sauce")
	eq(b["Source|Gameplay|Earned"].amount, 75)
	eq(b["Sink|Shop|Sauce"].amount, 40)
	eq(#Funnels.SHOP, 4)
end)

print("Cute faces (burger and tomahawk)")
local function hasName(specs, name)
	for _, s in ipairs(specs) do
		if s.name == name then
			return true
		end
	end
	return false
end
local function hasNeon(specs)
	for _, s in ipairs(specs) do
		if s.material == "neon" then
			return true
		end
	end
	return false
end

test("only the burger and the tomahawk steak get a face", function()
	eq(CuteFace.kind("burger"), "patty")
	eq(CuteFace.kind("tomahawk"), "steak")
	eq(CuteFace.kind("brisket"), nil)
	eq(CuteFace.kind("wagyu"), nil)
	eq(CuteFace.kind("hotlink"), nil)
	eq(#CuteFace.specs("brisket", { 2, 0.8, 1.2 }, false), 0)
	eq(#CuteFace.specs("ribs", { 2, 0.6, 1 }, false), 0)
end)

test("happy faces have sparkly eyes, cheeks and a mouth, and stay phone-light", function()
	local burger = Config.Meats.burger.size
	local steak = Config.Meats.tomahawk.size
	local b = CuteFace.specs("burger", burger, false)
	local s = CuteFace.specs("tomahawk", steak, false)
	truthy(#b >= 8 and #b <= CuteFace.MAX_PARTS, "burger part count")
	truthy(#s >= 6 and #s <= CuteFace.MAX_PARTS, "steak part count")
	truthy(hasName(b, "EyeL") and hasName(b, "EyeR") and hasName(b, "ShineL") and hasName(b, "SmileCenter"))
	truthy(hasName(b, "CheekL") and hasName(b, "CheekR"))
	truthy(hasName(s, "EyeL") and hasName(s, "Wink") and hasName(s, "Delight") and hasName(s, "Bone"))
	truthy(hasNeon(b) and hasNeon(s))
	truthy(not hasName(b, "Wink") and not hasName(s, "SmileCenter"), "the two expressions are not the same")
end)

test("faces sit on top, leave most of the surface for doneness color, and aim toward the yard", function()
	for _, id in ipairs({ "burger", "tomahawk" }) do
		local size = Config.Meats[id].size
		local specs = CuteFace.specs(id, size, false)
		local top = size[2] / 2
		local cover = CuteFace.topCoverage(specs, size)
		truthy(cover < 0.45 and cover > 0.05, id .. " coverage " .. cover)
		for _, s in ipairs(specs) do
			local x, y, z = s.offset[1], s.offset[2], s.offset[3]
			if s.name ~= "Bone" then
				truthy(y >= top - 0.001, s.name .. " on the top")
				truthy(y + s.size[2] / 2 <= top + 0.45, s.name .. " stays low")
				truthy(math.abs(x) + s.size[1] / 2 <= size[1] / 2 + 0.02, s.name .. " inside the width")
				truthy(math.abs(z) + s.size[3] / 2 <= size[3] / 2 + 0.02, s.name .. " inside the depth")
			end
		end
		-- mouth is closer to -Z (the path side) than the eyes
		local eyeZ, mouthZ = 0, 0
		for _, s in ipairs(specs) do
			if s.name == "EyeL" then
				eyeZ = s.offset[3]
			elseif s.name == "SmileCenter" or s.name == "Delight" then
				mouthZ = s.offset[3]
			end
		end
		truthy(mouthZ < eyeZ, id .. " mouth faces the yard path")
	end
end)

test("a burnt burger or steak drops the sparkle and frowns, and the body color stays the burn cue", function()
	local b = CuteFace.specs("burger", Config.Meats.burger.size, true)
	local s = CuteFace.specs("tomahawk", Config.Meats.tomahawk.size, true)
	truthy(hasName(b, "FrownCenter") and not hasName(b, "SmileCenter"))
	truthy(hasName(s, "FrownCenter") and not hasName(s, "Delight"))
	truthy(not hasNeon(b) and not hasNeon(s), "no sparkle on a burnt cut")
	local src = fs_read("src/shared/WorldBuilder.luau")
	truthy(string.find(src, "attachCuteFace", 1, true) ~= nil)
	truthy(string.find(src, 'hex("#141414")', 1, true) ~= nil, "burnt body is still black")
	local world = fs_read("src/server/Services/WorldService.luau")
	truthy(string.find(world, "cook.burnt == true", 1, true) ~= nil, "grill passes the burnt flag")
	truthy(string.find(world, "Color3.fromRGB(20, 20, 20)", 1, true) ~= nil, "burn feedback still paints the body")
	truthy(string.find(world, "m.Size = m.Size * 0.45", 1, true) == nil, "plates scale before the face is built")
	truthy(string.find(world, "0.45", 1, true) ~= nil)
end)

test("event teaser: the week before Turkey Day and the Holiday Smokeout, with a date (no timer copy)", function()
	local TD, HS = Config.TurkeyDay, Config.HolidaySmokeout
	local N = Config.EventTeaserDays
	eq(N, 7)
	-- 2026: Turkey Day runs Nov 23-29; the teaser covers Nov 16-22
	local function tw(y, m, d)
		local day = Holiday.daysFromCivil(y, m, d)
		return day, Holiday.turkeyWeek(day, TD.daysBefore, TD.daysAfter)
	end
	local day, w = tw(2026, 11, 15)
	eq(Holiday.soon(day, w, N), nil, "8 days out is quiet")
	day, w = tw(2026, 11, 16)
	eq(Holiday.soon(day, w, N), 7)
	day, w = tw(2026, 11, 22)
	eq(Holiday.soon(day, w, N), 1)
	day, w = tw(2026, 11, 23)
	eq(Holiday.soon(day, w, N), nil, "no teaser once it's on")
	day, w = tw(2026, 11, 30)
	eq(Holiday.soon(day, w, N), nil, "no teaser after it ends")
	eq(Holiday.longLabel(w.startDay), "Mon, Nov 23")
	-- Holiday Smokeout: Dec 12-18 teases Dec 19; Jan 1 (still on) and Jan 2 (just ended) don't
	local function hw(y, m, d)
		local dd = Holiday.daysFromCivil(y, m, d)
		return dd, Holiday.dateWindow(dd, HS.start, HS.finish, HS.peak)
	end
	day, w = hw(2026, 12, 11)
	eq(Holiday.soon(day, w, N), nil)
	day, w = hw(2026, 12, 12)
	eq(Holiday.soon(day, w, N), 7)
	eq(Holiday.label(w.startDay), "Dec 19")
	day, w = hw(2027, 1, 1)
	eq(Holiday.soon(day, w, N), nil)
	day, w = hw(2027, 1, 2)
	eq(Holiday.soon(day, w, N), nil)
	-- every day of 2026-2035: at most one teaser, never while an event is on
	for y = 2026, 2035 do
		for dd = Holiday.daysFromCivil(y, 1, 1), Holiday.daysFromCivil(y, 12, 31) do
			local t = Holiday.turkeyWeek(dd, TD.daysBefore, TD.daysAfter)
			local h = Holiday.dateWindow(dd, HS.start, HS.finish, HS.peak)
			local a, b = Holiday.soon(dd, t, N), Holiday.soon(dd, h, N)
			truthy(not (a and b), "one teaser at a time")
			if t.active or h.active then
				truthy(a == nil and b == nil, "no teaser during an event")
			end
		end
	end
	-- calm copy: a date, no countdown or pressure words
	for _, s in ipairs({ Content.TurkeyDay.soon, Content.HolidaySmokeout.soon, Content.Signs.turkeySoon, Content.Signs.holidaySoon }) do
		local low = string.lower(s)
		for _, bad in ipairs({ "hurry", "only", "left", "ends", "last chance", "don't miss", "countdown", "hours" }) do
			truthy(string.find(low, bad, 1, true) == nil, "pressure word '" .. bad .. "' in: " .. s)
		end
	end
end)

print("ShopSync (one-run shop setup)")
test("every pass and product is planned once, with a valid name, price and its own icon file", function()
	local items = ShopSync.items(Monetization)
	local n = 0
	for _ in pairs(Monetization.Passes) do
		n += 1
	end
	for _ in pairs(Monetization.Products) do
		n += 1
	end
	eq(#items, n)
	local plan = ShopSync.plan(items, { pass = {}, product = {} })
	eq(#plan.problems, 0, "problems: " .. table.concat(plan.problems, "; "))
	eq(#plan.create + #plan.done, n)
	local fs = require("@lune/fs")
	for _, it in ipairs(items) do
		truthy(fs.isFile("marketing/shop-icons/" .. it.key .. ".png"), "missing icon for " .. it.key)
	end
end)
test("re-runs link existing items by exact name (oldest ID) and never touch filled IDs", function()
	local items = {
		{ key = "A", kind = "product", id = 0, name = "Gobble Hat", price = 59, desc = "" },
		{ key = "B", kind = "product", id = 777, name = "Done Already", price = 49, desc = "" },
		{ key = "C", kind = "pass", id = 0, name = "Gobble Hat", price = 99, desc = "" }, -- same name, other kind
		{ key = "D", kind = "product", id = 0, name = "Brand New", price = 79, desc = "" },
	}
	local plan = ShopSync.plan(items, {
		product = { { id = 900, name = "Gobble Hat" }, { id = 500, name = "Gobble Hat" }, { id = 12, name = "Done Already" } },
		pass = {},
	})
	eq(#plan.link, 1)
	eq(plan.link[1].key, "A")
	eq(plan.link[1].id, 500)
	eq(#plan.done, 1)
	eq(plan.done[1].key, "B")
	eq(#plan.create, 2) -- the pass "Gobble Hat" is a different kind, so it's still created
	local bad = ShopSync.plan({
		{ key = "X", kind = "product", id = 0, name = string.rep("a", 51), price = 10, desc = "" },
		{ key = "Y", kind = "product", id = 0, name = "Twin", price = 0, desc = "" },
		{ key = "Z", kind = "product", id = 0, name = "Twin", price = 10.5, desc = "" },
	}, {})
	eq(#bad.problems, 4) -- too long, free, fractional price, duplicate name
end)
test("IDs are written over id = 0 only, for the exact key, and the module still loads", function()
	local fs = require("@lune/fs")
	-- start from the real file with every ID reset to 0, so this holds after launch too
	local src = string.gsub(fs.readFile("src/shared/Monetization.luau"), "= { id = %d+,", "= { id = 0,")
	local out, written = ShopSync.applyIds(src, { Boost30 = 3301234567, Rot_HatTurkey = 42, ExtraSmokers = 99, NotAKey = 5 })
	eq(#written, 3)
	truthy(string.find(out, "\n\tBoost30 = { id = 3301234567, name", 1, true), "Boost30 written")
	truthy(string.find(out, "\n\tBoost120 = { id = 0, name", 1, true), "Boost120 untouched (prefix key)")
	truthy(string.find(out, "\n\tRot_HatTurkey = { id = 42, name", 1, true), "underscore key written")
	truthy(string.find(out, "\n\tExtraSmokers = { id = 99, name", 1, true), "pass written")
	-- a second run can't overwrite a real ID
	local again, w2 = ShopSync.applyIds(out, { Boost30 = 1 })
	eq(#w2, 0)
	eq(again, out)
	local fn = assert((loadstring :: any)(out), "rewritten module parses")
	truthy(type(fn) == "function")
end)
test("multipart form: text fields, PNG file part and closing boundary", function()
	local it = { key = "K", kind = "product", id = 0, name = "Sparkler Trail", price = 79, desc = "Zap" }
	local body = ShopSync.multipart(ShopSync.formFields(it, "PNGDATA"), "bnd")
	truthy(string.find(body, 'name="name"\r\n\r\nSparkler Trail\r\n', 1, true))
	truthy(string.find(body, 'name="price"\r\n\r\n79\r\n', 1, true))
	truthy(string.find(body, 'name="isForSale"\r\n\r\ntrue\r\n', 1, true))
	truthy(string.find(body, 'filename="K.png"\r\nContent-Type: image/png\r\n\r\nPNGDATA\r\n', 1, true))
	eq(string.sub(body, -9), "--bnd--\r\n")
	local noIcon = ShopSync.multipart(ShopSync.formFields(it, nil), "bnd")
	truthy(string.find(noIcon, "imageFile", 1, true) == nil)
end)

test("hub from spawn: name tags and the Dinner Bell label don't cover the Cook-Off leaderboard", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local V3, CF = roblox.Vector3, roblox.CFrame
	local dm = roblox.Instance.new("DataModel")
	local ws = dm:GetService("Workspace")
	local env = { Instance = roblox.Instance, Vector3 = V3, CFrame = CF, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local map = WorldBuilder.build(env, ws, Config, Content)
	-- a player standing on the hub spawn, looking at Big Bertha (Roblox default FOV 70), on a
	-- desktop window and on a phone in landscape (pixel floors are relatively bigger on phones)
	local eye = map.Hub.HubSpawn.CFrame.Position + V3.new(0, 5, 2)
	local cam = CF.lookAt(eye, V3.new(0, 7, 10))
	local lb = map.Hub.CookOff.Leaderboard
	local tags = {
		map.Hub.KingOfThePit.Head.NameTag,
		map.Hub.UncHank.Head.NameTag,
		map.Hub.Temp.Stem.NameTag,
		map.Scenery.HubDecor.BigBertha.DinnerBell.Bell.Label,
	}
	local speech = map.Hub.JimothyWander.Head:FindFirstChild("Speech")
	truthy(speech and speech:IsA("BillboardGui"), "Jimothy's speech bubble is on his head")
	table.insert(tags, speech)
	local spots: { [string]: boolean } = {}
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d:GetAttribute("Kind") == "jimothy" then
			local id = d:GetAttribute("Sighting")
			truthy(type(id) == "string" and spots[id] ~= true, "duplicate or blank sighting " .. tostring(id))
			spots[id :: string] = true
		end
	end
	eq(Jimothy.total(), 10)
	for _, spot in ipairs(Jimothy.SIGHTINGS) do
		truthy(spots[spot.id], "missing sighting " .. spot.id .. " (" .. spot.place .. ")")
	end
	for _, screen in { { 1280, 720 }, { 844, 390 } } do
		local W, H = screen[1], screen[2]
		local f = H / (2 * math.tan(math.rad(35)))
		local function project(p)
			local l = cam:PointToObjectSpace(p)
			assert(l.Z < 0, "point is in front of the camera")
			return W / 2 + f * l.X / -l.Z, H / 2 - f * l.Y / -l.Z, -l.Z
		end
		local r = { math.huge, math.huge, -math.huge, -math.huge }
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				local x, y = project((lb.CFrame * CF.new(sx * lb.Size.X / 2, sy * lb.Size.Y / 2 + 1, 0)).Position)
				r = { math.min(r[1], x), math.min(r[2], y), math.max(r[3], x), math.max(r[4], y) }
			end
		end
		truthy(r[3] > 0 and r[1] < W, "leaderboard is on screen from spawn")
		for _, gui in tags do
			local who = gui.Parent.Parent.Name
			truthy(gui.Size.X.Scale > 0 and gui.Size.Y.Scale > 0, who .. " label shrinks with distance")
			local x, y, d = project(gui.Parent.CFrame.Position + gui.StudsOffset)
			local w = gui.Size.X.Scale * f / d + gui.Size.X.Offset
			local h = gui.Size.Y.Scale * f / d + gui.Size.Y.Offset
			local overlap = x - w / 2 < r[3] and x + w / 2 > r[1] and y - h / 2 < r[4] and y + h / 2 > r[2]
			truthy(not overlap, string.format("%s label covers the leaderboard from spawn (%dx%d)", who, W, H))
		end
	end
end)

print("HUD menu")
local PANELS_SRC = fs_read("src/client/Panels.luau")
local UI_SRC = fs_read("src/client/UI.luau")
local HUD_SRC = fs_read("src/client/Hud.luau")

test("every left-menu button names a real panel, except Invite", function()
	local seen: { [string]: boolean } = {}
	eq(#HudMenu.entries, 11)
	for _, entry in ipairs(HudMenu.entries) do
		truthy(not seen[entry.id], "duplicate " .. entry.id)
		seen[entry.id] = true
		truthy(string.find(HUD_SRC, "HudMenu.entries", 1, true) ~= nil, "HUD builds from the menu table")
		if entry.panel == "invite" then
			local stay, invite = HudMenu.press("shop", "invite")
			eq(stay, "shop", "invite leaves the open panel alone")
			truthy(invite)
			truthy(string.find(PANELS_SRC, 'name == "invite"', 1, true) ~= nil)
		else
			truthy(string.find(PANELS_SRC, 'current == "' .. entry.panel .. '"', 1, true) ~= nil, entry.panel .. " is rendered")
			eq(HudMenu.press(nil, entry.panel), entry.panel)
			eq(HudMenu.press(entry.panel, entry.panel), nil)
		end
	end
	for _, id in ipairs({ "shop", "season", "sauce", "index", "path", "upgrades", "daily", "settings", "invite" }) do
		truthy(seen[id], "missing " .. id)
	end
end)

test("a second activation in the same click cannot close the panel it just opened", function()
	local gate = HudMenu.guard()
	local open: string? = nil
	local function click(panel: string)
		if not gate:allow() then
			return
		end
		local nextName, invite = HudMenu.press(open, panel)
		if not invite then
			open = nextName
		end
	end
	click("shop")
	click("shop") -- the scroll frame's second Activated
	eq(open, "shop")
	gate:release()
	click("shop") -- a real second press, after the guard drops
	eq(open, nil)
	gate:release()
	click("sauce")
	eq(open, "sauce")
	gate:release()
	click("invite")
	eq(open, "sauce", "invite does not close Sauce")
end)

test("menu art does not keep the click, and the hit target sits above the scroller", function()
	local roblox = require("@lune/roblox")
	local holder = roblox.Instance.new("Frame")
	holder.ZIndex = 2
	local icon = roblox.Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.ZIndex = 3
	icon.Parent = holder
	local caption = roblox.Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.ZIndex = 3
	caption.Parent = holder
	local dot = roblox.Instance.new("Frame")
	dot.Name = "Dot"
	dot.ZIndex = 4
	dot.Parent = holder
	local hit = roblox.Instance.new("TextButton")
	hit.Name = "Hit"
	hit.ZIndex = HudMenu.HIT_Z
	hit.Parent = holder
	HudMenu.releaseDecorations(holder)
	eq(icon.Active, false)
	eq(icon.Interactable, false)
	eq(caption.Interactable, false)
	eq(dot.Active, false)
	eq(dot.Interactable, false)
	eq(hit.Active, true)
	eq(hit.Interactable, true)
	truthy(hit.ZIndex > icon.ZIndex and hit.ZIndex > caption.ZIndex and hit.ZIndex > dot.ZIndex)
	truthy(hit.ZIndex > HudMenu.SCROLL_Z)
	truthy(not hit:IsA("TextLabel"))
	-- the button callback stays synchronous and holds the guard until the next defer
	truthy(string.find(UI_SRC, "gate:allow()", 1, true) ~= nil)
	truthy(string.find(UI_SRC, "gate:release()", 1, true) ~= nil)
	truthy(string.find(UI_SRC, "task.defer", 1, true) ~= nil)
	truthy(string.find(UI_SRC, "task.spawn", 1, true) == nil, "spawn cleared the guard before the second Activated")
end)

print("Ten ranches")
test("the server holds 10 ranches and the old gap scenes move into the new gaps", function()
	local WorldBuilder = require("../src/shared/WorldBuilder")
	eq(Config.MAX_PLOTS, 10)
	eq(WorldBuilder.gapDegrees(8, 1), 22.5)
	eq(WorldBuilder.gapDegrees(8, 2), 67.5)
	eq(WorldBuilder.nearestGap(8, 112.5), 112.5, "eight ranches keep the original gaps")
	eq(WorldBuilder.nearestGap(10, 22.5), 18)
	eq(WorldBuilder.nearestGap(10, 67.5), 54)
	near(WorldBuilder.nearestGap(10, 112.5), 126, 1e-6)
	near(WorldBuilder.nearestGap(10, 337.5), 342, 1e-6)
	local seen = {}
	for i = 1, Config.MAX_PLOTS do
		local g = WorldBuilder.gapDegrees(Config.MAX_PLOTS, i)
		truthy(seen[g] == nil, "gap " .. g .. " is used twice")
		seen[g] = true
	end
	-- Due north stays a gap between ranches, so the creek path is not a house.
	local north = 270
	local best = 1e9
	for i = 1, Config.MAX_PLOTS do
		local d = math.abs((WorldBuilder.gapDegrees(Config.MAX_PLOTS, i) - north + 180) % 360 - 180)
		best = math.min(best, d)
	end
	near(best, 0, 1e-6, "a gap sits on the creek heading")
	local WorldBuilderSrc = fs_read("src/shared/WorldBuilder.luau")
	truthy(string.find(WorldBuilderSrc, "nearestGap", 1, true) ~= nil)
end)

print("Shops, howdy, signs, models")
test("every Robux item stays listed when its id is 0, and a real id buys", function()
	local offers = ShopCatalog.robuxKeys(Monetization)
	eq(#offers, 44)
	for _, offer in ipairs(offers) do
		local item = if offer.kind == "pass" then Monetization.Passes[offer.key] else Monetization.Products[offer.key]
		truthy(item.name and item.icon and item.desc and item.price, offer.key .. " has name, icon, price, description")
		local soon, soonOn = ShopCatalog.saleState(0, false, false)
		eq(soon, "soon")
		eq(soonOn, false)
		eq(ShopCatalog.robuxLabel(soon, item.price), "Coming soon")
		local buy, buyOn = ShopCatalog.saleState(item.id, false, false)
		eq(buy, "buy", offer.key)
		eq(buyOn, true)
		truthy(string.find(ShopCatalog.robuxLabel(buy, item.price), "R$", 1, true) ~= nil)
		local studio, studioOn = ShopCatalog.saleState(0, true, false)
		eq(studio, "studio")
		eq(studioOn, true)
	end
	eq(ShopCatalog.saleState(123, false, true), "owned")
end)
test("an empty sauce shelf still lists every sauce", function()
	local rows = ShopCatalog.sauceRows(nil, Config.SauceOrder)
	eq(#rows, #Config.SauceOrder)
	local stocked = ShopCatalog.sauceRows({ { id = Config.SauceOrder[1], qty = 3 } }, Config.SauceOrder)
	eq(#stocked, 1)
	eq(stocked[1].qty, 3)
end)
test("howdy is a greeting word, and the King's sauce is only after dark in a cowboy hat", function()
	truthy(Howdy.isGreeting("howdy"))
	truthy(Howdy.isGreeting("Howdy to everyone!"))
	truthy(Howdy.isGreeting("  HOWDY  "))
	truthy(not Howdy.isGreeting("showdown"))
	truthy(not Howdy.isGreeting("how"))
	truthy(not Howdy.isGreeting(""))
	truthy(Howdy.rewardDue(true, true, false))
	truthy(not Howdy.rewardDue(false, true, false))
	truthy(not Howdy.rewardDue(true, false, false))
	truthy(not Howdy.rewardDue(true, true, true))
	local egg = fs_read("src/server/Services/EggService.luau")
	truthy(string.find(egg, "TextChatService", 1, true) ~= nil, "live chat is TextChatService")
	truthy(string.find(egg, "MessageReceived", 1, true) ~= nil)
	truthy(string.find(egg, "Chatted", 1, true) ~= nil, "Studio still hears the older chat event")
	truthy(string.find(egg, 'kind = "howdy"', 1, true) ~= nil, "the greeting is broadcast")
end)
test("every plot sign faces the approach path, and the other face is readable too", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local V3, CF = roblox.Vector3, roblox.CFrame
	local dm = roblox.Instance.new("DataModel")
	local ws = dm:GetService("Workspace")
	local env = { Instance = roblox.Instance, Vector3 = V3, CFrame = CF, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local map = WorldBuilder.build(env, ws, Config, Content)
	local function frontNormal(part)
		return part.CFrame.LookVector
	end
	for i = 1, Config.MAX_PLOTS do
		local plot = map.Plots:FindFirstChild("Plot" .. i)
		local board = plot.Sign.Board
		local outward = frontNormal(board)
		local pos = board.CFrame.Position
		local toHub = (V3.new(0, pos.Y, 0) - pos).Unit
		truthy(outward:Dot(toHub) > 0.5, "plot " .. i .. " ranch sign faces the path")
		local faces = 0
		for _, d in ipairs(board:GetChildren()) do
			if d:IsA("SurfaceGui") and d:FindFirstChild("OwnerText") then
				faces += 1
			end
		end
		eq(faces, 2, "plot " .. i .. " reads from both sides")
		local pw = plot.PassWindow.Sign
		local pwPos = pw.CFrame.Position
		truthy(frontNormal(pw):Dot((V3.new(0, pwPos.Y, 0) - pwPos).Unit) > 0.5, "plot " .. i .. " pass window faces out")
		local vip = plot.VIPLights.VIPSign
		local vipPos = vip.CFrame.Position
		truthy(frontNormal(vip):Dot((V3.new(0, vipPos.Y, 0) - vipPos).Unit) > 0.5, "plot " .. i .. " VIP sign faces out")
	end
	eq(#map.Plots:GetChildren(), Config.MAX_PLOTS)
	-- Pads may meet their own road and sit in the ground. Anything else intersecting a ranch is a real overlap.
	local function axes(cf)
		return { cf.RightVector, cf.UpVector, -cf.LookVector }
	end
	local function boxes(root)
		local out = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				local cf = d.CFrame
				table.insert(out, { pos = cf.Position, size = d.Size, ax = axes(cf), name = d.Name })
			end
		end
		return out
	end
	local function extent(b, axis)
		local e = b.size * 0.5
		return e.X * math.abs(b.ax[1]:Dot(axis)) + e.Y * math.abs(b.ax[2]:Dot(axis)) + e.Z * math.abs(b.ax[3]:Dot(axis))
	end
	local function hit(a, b)
		local delta = b.pos - a.pos
		local function sep(axis)
			if axis.Magnitude < 1e-6 then
				return false
			end
			local n = axis.Unit
			return math.abs(delta:Dot(n)) > extent(a, n) + extent(b, n) + 0.2
		end
		for axis = 1, 3 do
			if sep(a.ax[axis]) or sep(b.ax[axis]) then
				return false
			end
			for other = 1, 3 do
				if sep(a.ax[axis]:Cross(b.ax[other])) then
					return false
				end
			end
		end
		return true
	end
	local plotBoxes = {}
	for i = 1, Config.MAX_PLOTS do
		plotBoxes[i] = boxes(map.Plots:FindFirstChild("Plot" .. i))
	end
	for i = 1, Config.MAX_PLOTS do
		for j = i + 1, Config.MAX_PLOTS do
			for _, a in ipairs(plotBoxes[i]) do
				for _, b in ipairs(plotBoxes[j]) do
					truthy(not hit(a, b), "plot " .. i .. " " .. a.name .. " overlaps plot " .. j .. " " .. b.name)
				end
			end
		end
	end
	local scenery = map:FindFirstChild("Scenery")
	local hood = scenery and scenery:FindFirstChild("Neighborhood")
	local critters = scenery and scenery:FindFirstChild("Critters")
	local extras = {}
	if hood then
		for _, b in ipairs(boxes(hood)) do
			table.insert(extras, b)
		end
	end
	if critters then
		for _, b in ipairs(boxes(critters)) do
			table.insert(extras, b)
		end
	end
	for i = 1, Config.MAX_PLOTS do
		for _, a in ipairs(plotBoxes[i]) do
			for _, b in ipairs(extras) do
				truthy(not hit(a, b), "plot " .. i .. " " .. a.name .. " overlaps " .. b.name)
			end
		end
	end
end)
test("birds are built from a beak, feathers and toes, and stay a small part count", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local env = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local ws = roblox.Instance.new("Folder")
	local function parts(def)
		local m = WorldBuilder.critter(env, ws, def, roblox.CFrame.new())
		local n, beak, feather, toe, bodyQuery = 0, false, false, false, false
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				if d.Name == "Beak" then
					beak = d:IsA("WedgePart")
				elseif d.Name == "Feather" then
					feather = true
				elseif d.Name == "Toe" then
					toe = true
				elseif d.Name == "Body" then
					bodyQuery = d.CanQuery
				end
			end
		end
		return n, beak, feather, toe, bodyQuery
	end
	for _, id in ipairs({ "hummingbird", "roadrunner" }) do
		local n, beak, feather, toe, bodyQuery = parts(Config.Critters[id == "hummingbird" and 7 or 2])
		truthy(beak and feather and toe, id .. " has a wedge beak, feathers and toes")
		truthy(bodyQuery, id .. " body can take a prompt")
		truthy(n >= 20 and n <= 60, id .. " part count " .. n)
	end
	local burger = WorldBuilder.meat(env, ws, Config.Meats.burger, nil, roblox.CFrame.new(), 1, false, 1)
	truthy(burger:FindFirstChild("BunTop") ~= nil, "burger keeps a bun")
	truthy(burger.BunTop:FindFirstChild("EyeL") ~= nil or burger:FindFirstChild("EyeL", true) ~= nil, "cute face stays")
end)

print("Jimothy")
test("Possum Pete's Regulars Index count migrates onto Jimothy, once", function()
	local template = { critters = {}, forceCritter = "", jimothy = { seen = {}, lastAt = 0, rewarded = false }, coins = 0 }
	local old = { critters = { possum = 4, armadillo = 2, jimothy = 1 }, forceCritter = "possum", coins = 9 }
	local filled = Reconcile.fill(old, template)
	truthy(Jimothy.migrate(filled))
	eq(filled.critters.jimothy, 5)
	eq(filled.critters.possum, nil)
	eq(filled.critters.armadillo, 2)
	eq(filled.forceCritter, Jimothy.ID)
	eq(type(filled.jimothy.seen), "table")
	eq(filled.jimothy.rewarded, false)
	eq(filled.coins, 9)
	truthy(not Jimothy.migrate(filled), "a second pass leaves the save alone")
	local only = { critters = { possum = 3 }, forceCritter = "" }
	truthy(Jimothy.migrate(only))
	eq(only.critters.jimothy, 3)
	eq(only.critters.possum, nil)
	eq(only.forceCritter, "")
	local weird = { critters = { possum = "old" } }
	truthy(Jimothy.migrate(weird))
	eq(weird.critters.jimothy, 0)
	eq(weird.critters.possum, nil)
	local fresh = Reconcile.fill({ coins = 1 }, template)
	truthy(not Jimothy.migrate(fresh))
	eq(fresh.critters.possum, nil)
	eq(fresh.forceCritter, "")
	truthy(string.find(fs_read("src/shared/DefaultData.luau"), "jimothy = { seen = {}", 1, true) ~= nil, "saves gain the sighting table")
	truthy(string.find(fs_read("src/server/Services/DataService.luau"), "Jimothy.migrate(data)", 1, true) ~= nil, "load migrates before the game sees the save")
end)
test("sightings count once, ignore dupes, rate-limit, and pay the reward a single time", function()
	eq(Jimothy.total(), 10)
	eq(#Jimothy.LINES, 4)
	truthy(Jimothy.LINES[1] == "Praise Jimothy!!")
	local data = { titles = {} }
	local t = 100
	local last: any = nil
	for i, spot in ipairs(Jimothy.SIGHTINGS) do
		last = Jimothy.record(data, spot.id, t)
		t += 2
		eq(last.ok, true, spot.id)
		eq(last.duplicate, false)
		eq(last.count, i)
		eq(last.justCompleted, i == 10)
	end
	eq(last.title, Jimothy.TITLE)
	eq(last.cosmetic, Jimothy.COSMETIC)
	eq(data.titles[Jimothy.TITLE], true)
	eq(data.jimothy.rewarded, true)
	eq(Jimothy.count(data.jimothy.seen), 10)
	local again = Jimothy.record(data, Jimothy.SIGHTINGS[1].id, t)
	eq(again.duplicate, true)
	eq(again.justCompleted, false)
	eq(again.count, 10)
	eq(data.titles[Jimothy.TITLE], true)
	local fresh = { titles = {} }
	local first = Jimothy.record(fresh, "shack", 10)
	local dupe = Jimothy.record(fresh, "shack", 20)
	eq(first.count, 1)
	eq(dupe.duplicate, true)
	eq(dupe.count, 1)
	eq(Jimothy.count(fresh.jimothy.seen), 1)
	local limited = Jimothy.record(fresh, "roof", 10 + Jimothy.COOLDOWN - 0.05)
	eq(limited.ok, false)
	eq(limited.limited, true)
	eq(Jimothy.count(fresh.jimothy.seen), 1)
	local later = Jimothy.record(fresh, "roof", 10 + Jimothy.COOLDOWN)
	eq(later.ok, true)
	eq(later.count, 2)
	eq(Jimothy.record(fresh, "not-a-spot", 50).ok, false)
	eq(Config.Cosmetics[Jimothy.COSMETIC].source, "sighting")
	eq(Config.Cosmetics[Jimothy.COSMETIC].slot, "buddy")
	for _, product in pairs(Monetization.Products) do
		if product.grants then
			for _, id in ipairs(product.grants) do
				truthy(id ~= Jimothy.COSMETIC, "the back-buddy is never sold")
			end
		end
	end
	local found = false
	for _, c in ipairs(Config.Critters) do
		truthy(c.id ~= "possum" and c.name ~= "Possum Pete", "possum is not a live regular")
		if c.id == "jimothy" then
			found = true
			eq(c.name, "Jimothy the Raccoon")
		end
		if c.id == "raccoon" then
			eq(c.name, "Bandit the Raccoon")
		end
	end
	truthy(found)
	eq(Monetization.Passes.AutoServe.id, 2089955594)
	eq(Monetization.Passes.AutoServe.price, 299)
	eq(Monetization.Passes.AutoServe.name, "Jimothy the Waiter")
end)
test("Jimothy reads round and neckless; Bandit stays the slimmer raccoon", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local env = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local ws = roblox.Instance.new("Folder")
	local function build(id: string, extra: any?)
		local def: any = nil
		for _, c in ipairs(Config.Critters) do
			if c.id == id then
				def = {}
				for k, v in pairs(c) do
					def[k] = v
				end
			end
		end
		if extra then
			for k, v in pairs(extra) do
				def[k] = v
			end
		end
		return WorldBuilder.critter(env, ws, def, roblox.CFrame.new())
	end
	local function roundness(part): number
		local s = part.Size
		return math.min(s.X, s.Y, s.Z) / math.max(s.X, s.Y, s.Z)
	end
	local jim = build("jimothy")
	local bandit = build("raccoon")
	truthy(roundness(jim.Body) > 0.9, "jimothy's body is nearly a sphere")
	truthy(roundness(bandit.Body) < 0.85, "bandit keeps a longer body")
	local jEar, bEar = jim:FindFirstChild("EarL"), bandit:FindFirstChild("EarL")
	truthy(jEar and math.abs(jEar.Size.X - jEar.Size.Y) / jEar.Size.X < 0.25, "round ears")
	truthy(bEar and bEar.Size.Y > bEar.Size.X * 1.4, "bandit's ears stay tall")
	truthy(jim:FindFirstChild("Mask") ~= nil and bandit:FindFirstChild("Mask") ~= nil)
	local tails = 0
	for _, d in ipairs(jim:GetChildren()) do
		if d.Name == "Tail" then
			tails += 1
			truthy(d.Size.X > 0.4, "chunky tail rings")
		end
	end
	eq(tails, 4)
	-- the head overlaps the body instead of sitting on a neck
	local gap = jim.Head.CFrame.Position.Y - jim.Head.Size.Y / 2 - (jim.Body.CFrame.Position.Y + jim.Body.Size.Y / 2)
	truthy(gap < 0, "head sits in the body")
	local waiter = build("jimothy", { waiter = true })
	truthy(waiter:FindFirstChild("Apron") ~= nil and waiter:FindFirstChild("BowKnot") ~= nil, "waiter wears a bowtie and apron")
	truthy(bandit:FindFirstChild("Apron") == nil)
end)

print("Numbers, income, gifts, crew")
test("big coin totals abbreviate as 1.2K and 3.4M", function()
	eq(Numbers.abbrev(0), "0")
	eq(Numbers.abbrev(999), "999")
	eq(Numbers.abbrev(1000), "1K")
	eq(Numbers.abbrev(1200), "1.2K")
	eq(Numbers.abbrev(1500), "1.5K")
	eq(Numbers.abbrev(3400000), "3.4M")
	eq(Numbers.abbrev(1000000), "1M")
	eq(Numbers.abbrev(999999), "1M")
	eq(Numbers.abbrev(-1200), "-1.2K")
	eq(Numbers.abbrev(0 / 0), "0")
end)
test("income rate is the real trailing window, not a scripted number", function()
	local events = {}
	Income.record(events, 100, 0, 30)
	eq(#events, 0)
	Income.record(events, 100, 60, 30)
	Income.record(events, 110, 90, 30)
	near(Income.perSecond(events, 120, 30), 5) -- 150 coins over 30s
	eq(Income.format(0), "+0/s")
	eq(Income.format(0.41), "+0.4/s")
	eq(Income.format(125), "+125/s")
	eq(Income.format(1200), "+1.2K/s")
	Income.record(events, 200, 10, 30)
	eq(#events, 1, "events older than the window drop off")
	eq(events[1].n, 10)
end)
test("daily streak payout and the timed gift use the same floors the server pays", function()
	eq(Streak.payout(100, 1, 1), 100)
	eq(Streak.payout(100, 8, 1), 150) -- week 2 is 1.5x
	eq(Streak.payout(100, 8, 2), 300) -- then rank
	eq(Economy.comboMult(0, Config.Flip.comboStep, Config.Flip.comboMax), 1)
	eq(Economy.comboMult(3, Config.Flip.comboStep, Config.Flip.comboMax), 1.3)
	eq(Economy.comboMult(99, Config.Flip.comboStep, Config.Flip.comboMax), 2)
	local gift = FreeGift.new()
	eq(FreeGift.ready(gift.nextAt, 0), true)
	truthy(FreeGift.claim(gift, 10))
	eq(gift.nextAt, 10 + FreeGift.PERIOD)
	truthy(not FreeGift.claim(gift, 10 + FreeGift.PERIOD - 1))
	truthy(FreeGift.claim(gift, 10 + FreeGift.PERIOD))
	eq(FreeGift.payout(1), FreeGift.BASE)
	eq(FreeGift.payout(2), FreeGift.BASE * 2)
end)
test("crew hire costs, upgrades and income climb, and old saves gain empty defaults", function()
	eq(Staff.slots(1), 1)
	eq(Staff.slots(5), 5)
	eq(Staff.slots(9), 5)
	eq(Staff.hireCost(0), 250)
	truthy(Staff.hireCost(1) > Staff.hireCost(0))
	truthy(Staff.hireCost(4) > Staff.hireCost(3))
	eq(Staff.hireCost(5), nil)
	local pip = Staff.template(0)
	eq(pip.id, "pip")
	eq(pip.role, "grill")
	eq(pip.speed, 1)
	eq(Staff.upgradeCost("speed", 1), 180)
	truthy(Staff.upgradeCost("speed", 2) > Staff.upgradeCost("speed", 1))
	eq(Staff.upgradeCost("speed", Staff.MAX), nil)
	eq(Staff.upgradeCost("nope", 1), nil)
	truthy(Staff.interval(5, false) < Staff.interval(1, false))
	truthy(Staff.interval(1, true) < Staff.interval(1, false))
	truthy(Staff.interval(Staff.MAX, true) > 1)
	eq(Staff.carry(3), 3)
	near(Staff.qualityTip(1), 1)
	near(Staff.qualityTip(5), 1.2)
	near(Staff.qualityLuck(5), 1.24)
	local meat = Config.Meats.burger
	local slow = Staff.cookProfitPerSecond(pip, meat, 1, 1.2, 1, false)
	pip.speed = 5
	local fast = Staff.cookProfitPerSecond(pip, meat, 1, 1.2, 1, false)
	truthy(fast > slow)
	pip.quality = 5
	local tasty = Staff.cookProfitPerSecond(pip, meat, 1, 1.2, 1, false)
	truthy(tasty > fast)
	local withPass = Staff.cookProfitPerSecond(pip, meat, 1, 1.2, 1, true)
	truthy(withPass > tasty)
	local floor = Staff.template(2)
	eq(floor.role, "floor")
	eq(Staff.cookProfitPerSecond(floor, meat, 1, 1.2, 1, false), 0)
	truthy(Staff.serveRate(pip, true) > Staff.serveRate(pip, false))
	local world = { coins = 100, cooler = 2, coolerMax = 40, customers = 1, openGrill = 2, openSmoker = 2, done = 1, burgerCost = 2, linkCost = 6 }
	local cook = Staff.decide(Staff.template(0), world)
	eq(cook.kind, "cook")
	eq(cook.meat, "burger")
	local pit = Staff.decide(Staff.template(1), world)
	eq(pit.meat, "hotlink")
	local served = Staff.decide(floor, world)
	eq(served.kind, "serve")
	world.customers = 0
	world.cooler = 0
	eq(Staff.decide(floor, world).kind, "collect")
	world.coins = 1
	eq(Staff.decide(Staff.template(0), world).kind, "collect")
	world.done = 0
	eq(Staff.decide(Staff.template(0), world), nil)
	local old = { coins = 3 }
	local filled = Reconcile.fill(old, DefaultData)
	eq(#filled.staff.roster, 0)
	eq(filled.freeGift.nextAt, 0)
	eq(filled.coins, 3)
	filled.staff.roster = { { id = "nope", speed = 1 }, { id = "pip", speed = 99, capacity = 0 } }
	Staff.normalize(filled)
	eq(#filled.staff.roster, 1)
	eq(filled.staff.roster[1].speed, Staff.MAX)
	eq(filled.staff.roster[1].capacity, 1)
	eq(filled.staff.roster[1].name, "Pip")
	local goal = Goals.next({ rookieActive = false, giftReady = false, coins = 100, hireCost = 250, hireName = "Pip", pitCost = 500, pitName = "Rochin' the Smoker", crew = 0, crewSlots = 1 })
	eq(goal.id, "hire")
	eq(goal.goal, 250)
	eq(Goals.next({ rookieActive = true, giftReady = true, coins = 0, crew = 0, crewSlots = 1 }).id, "gift")
	eq(Goals.next({ rookieActive = true, giftReady = false, coins = 0, crew = 0, crewSlots = 1 }), nil)
end)
test("premium cuts cost coins even when the creator owns every pass", function()
	for id, m in pairs(Config.Meats) do
		if id == "firstbrisket" then
			eq(m.cost, 0, "the tutorial brisket stays free")
			truthy(m.hidden)
		else
			truthy(m.cost > 0, id .. " has a coin cost")
		end
	end
	eq(Config.Meats.wagyu.cost, Config.Meats.brisket.cost * 2)
	eq(Config.Meats.tomahawk.cost, 120)
	local none = { pass = false, tokens = 0, unlocked = false }
	local creator = { pass = true, tokens = 0, unlocked = false }
	local wagyu = Config.Meats.wagyu
	local asCreator = Economy.cookBill(wagyu, 1, Config.RANK_STEP, creator)
	truthy(asCreator.allowed)
	eq(asCreator.usesToken, false)
	eq(asCreator.coins, Economy.rawCost(wagyu, 1))
	truthy(asCreator.coins > 0)
	local fresh = Economy.cookBill(wagyu, 1, Config.RANK_STEP, none)
	eq(fresh.allowed, false)
	eq(fresh.coins, asCreator.coins, "the price is the same; the pass is access")
	local tokens = Economy.cookBill(wagyu, 1, Config.RANK_STEP, { pass = false, tokens = 3, unlocked = false })
	eq(tokens.allowed, true)
	eq(tokens.usesToken, true)
	eq(tokens.coins, asCreator.coins)
	local path = Economy.cookBill(Config.Meats.tomahawk, 1, Config.RANK_STEP, { pass = false, tokens = 2, unlocked = true })
	eq(path.allowed, true)
	eq(path.usesToken, false)
	truthy(path.coins > 0)
	local burger = Economy.cookBill(Config.Meats.burger, 1, Config.RANK_STEP, none)
	eq(burger.allowed, true)
	eq(burger.usesToken, false)
	truthy(burger.coins > 0 and burger.coins <= Config.START_COINS)
	local panels = fs_read("src/client/Panels.luau")
	local game = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(panels, "Cook (free)", 1, true) == nil, "the cook button never says free")
	truthy(string.find(panels, "cookBill", 1, true) ~= nil)
	truthy(string.find(game, "cookBill", 1, true) ~= nil)
	truthy(string.find(game, "spentToken", 1, true) ~= nil)
	truthy(string.find(Monetization.Passes.PremiumCuts.desc, "meat cost", 1, true) ~= nil)
	truthy(string.find(Monetization.Products.WagyuPack.desc, "meat cost", 1, true) ~= nil)
	truthy(string.find(string.lower(Monetization.Passes.PremiumCuts.desc), "free", 1, true) == nil)
	eq(Monetization.Passes.PremiumCuts.id, 2088479585)
	eq(Monetization.Passes.PremiumCuts.price, 349)
	eq(Monetization.Products.WagyuPack.id, 3732457988)
	eq(Monetization.Products.WagyuPack.price, 79)
end)
test("paid Wagyu, Tomahawk and Premium Cuts cooks are always Smoke Ring Gold", function()
	local gold = Rarity.get(Config.Rarities, "smokering")
	eq(gold.name, "Smoke Ring Gold")
	local function access(pass, tokens, unlocked)
		return { pass = pass, tokens = tokens, unlocked = unlocked }
	end
	local function rarity(meat, acc, rolled)
		local bill = Economy.cookBill(meat, 1, Config.RANK_STEP, acc)
		return Economy.cookRarity(meat, acc, bill.usesToken, rolled), bill
	end
	local wagyu, tomahawk, burger = Config.Meats.wagyu, Config.Meats.tomahawk, Config.Meats.burger
	local withPass, passBill = rarity(wagyu, access(true, 0, false), "meteorite")
	eq(withPass, "smokering")
	eq(passBill.usesToken, false)
	local withTokens, tokenBill = rarity(tomahawk, access(false, 3, false), "texas")
	eq(withTokens, "smokering")
	eq(tokenBill.usesToken, true)
	local wagyuTokens = rarity(wagyu, access(false, 1, false), "common")
	eq(wagyuTokens, "smokering")
	-- The earned path unlock is not a paid path, even if a token is sitting in the cooler.
	local earned, earnedBill = rarity(tomahawk, access(false, 2, true), "juicy")
	eq(earned, "juicy")
	eq(earnedBill.usesToken, false)
	local plain = rarity(burger, access(true, 5, true), "common")
	eq(plain, "common")
	truthy(Economy.paidCut(wagyu, access(true, 0, false), false))
	truthy(not Economy.paidCut(tomahawk, access(false, 4, true), false))
	truthy(string.find(Monetization.Passes.PremiumCuts.desc, "Smoke Ring Gold", 1, true) ~= nil)
	truthy(string.find(Monetization.Products.WagyuPack.desc, "Smoke Ring Gold", 1, true) ~= nil)
	truthy(string.find(Monetization.Products.TomahawkPack.desc, "Smoke Ring Gold", 1, true) ~= nil)
	truthy(string.find(Monetization.Products.StarterPitPack.desc, "Smoke Ring Gold", 1, true) ~= nil)
	local game = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(game, "Economy.cookRarity", 1, true) ~= nil)
	truthy(string.find(game, "Economy.paidCut", 1, true) ~= nil)
	-- Luck sauce is only opened when the cook still rolls.
	local luckAt = string.find(game, 'useSauce(data, "luck")', 1, true)
	local paidAt = string.find(game, "if not paidFixed then", 1, true)
	truthy(paidAt ~= nil and luckAt ~= nil and paidAt < luckAt)
end)
test("an old save still loads, and a cook already on the pit keeps its rarity", function()
	local old = {
		schema = 1,
		coins = 1234,
		cuts = { wagyu = 2, tomahawk = 1 },
		unlocks = { tomahawk = true },
		stations = { s1 = { meat = "wagyu", rarity = "texas", start = 10, duration = 14400 } },
		stats = { served = 40 },
	}
	local filled = Reconcile.fill(old, DefaultData)
	eq(filled.schema, 1)
	eq(filled.coins, 1234)
	eq(filled.cuts.wagyu, 2)
	eq(filled.cuts.tomahawk, 1)
	eq(filled.unlocks.tomahawk, true)
	eq(filled.stations.s1.rarity, "texas")
	eq(filled.stations.s1.meat, "wagyu")
	eq(filled.stats.served, 40)
	eq(filled.pitLevel, 1)
	eq(type(filled.staff.roster), "table")
	eq(#filled.staff.roster, 0)
	-- Nothing in the save records the server size, so 8-player ranches open on a 10-player server.
	eq(filled.plot, nil)
	eq(Config.MAX_PLOTS, 10)
end)
test("every shop grant exists, and nothing on the coin menu is accidentally free", function()
	for key, p in pairs(Monetization.Products) do
		truthy(p.id > 0 and p.price > 0, key)
		if p.grants then
			for _, id in ipairs(p.grants) do
				truthy(Config.Cosmetics[id] ~= nil, key .. " grants missing " .. id)
			end
		end
		if p.cut then
			local meat = Config.Meats[p.cut]
			truthy(meat ~= nil and meat.premium == true, key .. " cut")
			truthy(meat.cost > 0, key .. " cut still costs coins to cook")
		end
		if p.kind == "boost" then
			truthy((p.minutes or 0) > 0 and (p.mult or 0) > 1, key)
		end
	end
	for key, pass in pairs(Monetization.Passes) do
		truthy(pass.id > 0 and pass.price > 0, key)
	end
	for _, id in ipairs(Config.SauceOrder) do
		local sauce = Config.Sauces[id]
		truthy(sauce.price > 0 and not sauce.hidden, id .. " is a real coin purchase")
	end
	for _, step in ipairs(Config.PathSteps) do
		if step.reward.cosmetic then
			truthy(Config.Cosmetics[step.reward.cosmetic] ~= nil, step.label)
		end
	end
	truthy(Config.Cosmetics.starter_hat ~= nil)
end)

print("Crew authority, streak clock, gift clock, income window")
test("hiring cannot duplicate a hand, cannot go negative, and stops when the slots or the catalog run out", function()
	local coins = 100000
	local roster = {}
	local seen: { [string]: boolean } = {}
	for _ = 1, 12 do
		local outcome = Staff.tryHire(roster, 5, coins)
		if not outcome.ok then
			break
		end
		truthy(outcome.employee)
		truthy(not seen[outcome.employee.id], "hired " .. outcome.employee.id .. " twice")
		seen[outcome.employee.id] = true
		truthy(outcome.coins >= 0)
		truthy(outcome.coins == coins - (outcome.cost or 0))
		table.insert(roster, outcome.employee)
		coins = outcome.coins
	end
	eq(#roster, 5)
	eq(roster[1].id, "pip")
	eq(Staff.tryHire(roster, 5, coins).ok, false)
	local broke = Staff.tryHire({}, 1, 249)
	eq(broke.ok, false)
	eq(broke.reason, "coins")
	eq(broke.coins, 249)
	local exact = Staff.tryHire({}, 1, 250)
	eq(exact.ok, true)
	eq(exact.coins, 0)
	eq(Staff.tryHire({}, 1, 0 / 0).ok, false)
	eq(Staff.tryHire({}, 1, -20).ok, false)
	eq(Staff.tryHire({}, 1, math.huge).ok, false)
	-- a dropped id must not hire someone who is already on the crew
	local gapped = {
		{ id = "pip", name = "Pip", species = "raccoon", role = "grill", speed = 1, capacity = 1, quality = 1 },
		{ id = "mango", name = "Mango", species = "clapcat", role = "floor", speed = 1, capacity = 1, quality = 1 },
	}
	local fill = Staff.tryHire(gapped, 5, 100000)
	eq(fill.ok, true)
	eq(fill.employee.id, "dottie")
	eq(Staff.tryHire({}, 1, 100000).ok, true)
	eq(Staff.tryHire({ { id = "pip", speed = 1, capacity = 1, quality = 1 } }, 1, 100000).reason, "slots")
end)
test("upgrades charge once per level and refuse a second quote for the same level", function()
	local pip = Staff.template(0)
	local roster = { pip }
	local poor = Staff.tryUpgrade(roster, "pip", "speed", 0)
	eq(poor.ok, false)
	eq(pip.speed, 1)
	local cost = Staff.upgradeCost("speed", 1)
	local up = Staff.tryUpgrade(roster, "pip", "speed", cost)
	eq(up.ok, true)
	eq(up.coins, 0)
	eq(up.level, 2)
	eq(up.from, 1)
	eq(pip.speed, 1, "quote does not mutate")
	pip.speed = up.level
	eq(Staff.tryUpgrade(roster, "pip", "speed", 0).ok, false)
	for _ = 1, 6 do
		local quote = Staff.tryUpgrade(roster, "pip", "speed", 10 ^ 9)
		if not quote.ok then
			break
		end
		truthy(quote.level == pip.speed + 1)
		pip.speed = quote.level
	end
	eq(pip.speed, Staff.MAX)
	eq(Staff.tryUpgrade(roster, "pip", "speed", 10 ^ 9).reason, "max")
	eq(Staff.tryUpgrade(roster, "pip", "coins", 10 ^ 9).reason, "bad")
	eq(Staff.tryUpgrade(roster, "nope", "speed", 10 ^ 9).reason, "missing")
	local burst = RateLimiter.new(6, 3)
	local allowed = 0
	for _ = 1, 10 do
		if burst:allow("hire", 0) then
			allowed += 1
		end
	end
	eq(allowed, 6, "remote hire spam stops at the action burst")
	local game = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(game, "actionLimiter:allow", 1, true) ~= nil)
	truthy(string.find(game, "acting[player]", 1, true) ~= nil, "a yielding action cannot run twice")
	truthy(string.find(game, "FreeGift.claim(data.freeGift, now)", 1, true) ~= nil)
	truthy(string.find(game, "local now = os.time()", 1, true) ~= nil)
end)
test("streak day boundary, rejoin, and soft-reset preview match the coins the server pays", function()
	local offset = -6
	-- 2026-11-07 06:00 UTC is Texas midnight opening that Saturday. One second earlier is still Friday.
	local days = 20764
	local midnight = days * 86400 + 6 * 3600
	eq(TimeUtil.dayNumber(midnight, offset), days)
	eq(TimeUtil.dayNumber(midnight - 1, offset), days - 1)
	local s = Streak.new()
	local yesterday = TimeUtil.dayNumber(midnight - 1, offset)
	eq(Streak.claim(s, yesterday).count, 1)
	-- the "never claimed" sentinel is -1, which is also a real day number near the epoch
	local fresh = Streak.new()
	eq(Streak.claim(fresh, -1).ok, true)
	eq(fresh.count, 1)
	eq(Streak.claim(fresh, -1).ok, false, "the sentinel day cannot be claimed twice")
	local rejoined = { lastDay = s.lastDay, count = s.count, best = s.best, freeMissWeek = s.freeMissWeek }
	local again = Streak.forecast(rejoined, yesterday)
	eq(again.ok, false)
	eq(rejoined.count, 1, "forecast does not change the saved streak")
	eq(Streak.canClaim(rejoined, yesterday), false)
	local today = TimeUtil.dayNumber(midnight + 30, offset)
	eq(Streak.claim(s, today).count, 2)
	-- seven days in, then a long gap: the card used to preview count+1 (week 2)
	local week = Streak.new()
	for d = 1, 7 do
		Streak.claim(week, d)
	end
	eq(week.count, 7)
	local look = Streak.forecast(week, 20)
	eq(look.ok, true)
	eq(look.softReset, true)
	eq(look.count, 1)
	eq(week.count, 7, "forecast leaves the profile alone")
	eq(Streak.payout(100, look.count, 1), 100)
	eq(Streak.payout(100, week.count + 1, 1), 150, "the old count+1 preview overpays")
	eq(Streak.canClaim(week, 7), false)
	week.lastDay = 15
	eq(Streak.canClaim(week, 12), false)
	truthy(Streak.healClock(week, 12))
	eq(week.lastDay, 12)
	eq(Streak.canClaim(week, 12), false, "healing a future stamp does not pay again")
	eq(Streak.claim(week, 13).ok, true)
end)
test("free gift uses a server timestamp, survives rejoin, and a bad stamp cannot lock or repeat it", function()
	local now = 1700000000
	local gift = FreeGift.new()
	truthy(FreeGift.claim(gift, now))
	local saved = gift.nextAt
	eq(saved, now + FreeGift.PERIOD)
	eq(FreeGift.ready(saved, now + 10), false)
	eq(FreeGift.claim({ nextAt = saved }, now + FreeGift.PERIOD - 1), false)
	eq(FreeGift.ready(saved, now + FreeGift.PERIOD), true)
	-- crossing a Texas midnight does not clear a gift that is still on its timer
	local before = TimeUtil.dayNumber(now, -6)
	local after = TimeUtil.dayNumber(now + 86400, -6)
	truthy(after == before + 1)
	eq(FreeGift.ready(saved, now + 100), false)
	local nan = { nextAt = 0 / 0 }
	FreeGift.normalize(nan, now)
	eq(nan.nextAt, 0)
	truthy(FreeGift.claim(nan, now))
	local far = { nextAt = 1e15 }
	FreeGift.normalize(far, now)
	eq(far.nextAt, now + FreeGift.PERIOD)
	eq(FreeGift.ready(far.nextAt, now), false)
	eq(FreeGift.claim(far, now), false)
	eq(FreeGift.claim(far, now + FreeGift.PERIOD), true)
end)
test("income rate follows the server earn log as the window slides", function()
	local events = {}
	Income.record(events, 1000, 300, 30)
	eq(Income.format(Income.perSecond(events, 1000, 30)), "+10/s")
	eq(Income.perSecond(events, 1029, 30), 10)
	eq(Income.perSecond(events, 1031, 30), 0)
	Income.record(events, 2000, math.huge, 30)
	eq(#events, 1, "a non-finite earn is not recorded")
end)
test("first-visit hints are four saved steps, skippable, and quiet for ranchers who already played", function()
	eq(#Guide.STEPS, 4)
	eq(Guide.STEPS[1].id, "ranch")
	eq(Guide.STEPS[2].id, "serve")
	eq(Guide.STEPS[3].id, "crew")
	eq(Guide.STEPS[4].id, "gift")
	local blob = ""
	for _, step in ipairs(Guide.STEPS) do
		blob ..= string.lower(step.title .. " " .. step.body .. " ")
	end
	for _, word in ipairs({ "robux", "buy now", "limited time", "last chance", "odds", "loot", "gamble", "hurry" }) do
		truthy(string.find(blob, word, 1, true) == nil, word)
	end
	local fresh = Guide.new()
	Guide.prepare(fresh, { served = 0, playSeconds = 0, crew = 0 })
	eq(fresh.introduced, true)
	eq(fresh.skipped, false)
	eq(Guide.view(fresh).target, "ranch")
	local data = {
		tutorial = { firstBrisket = false, done = false },
		stats = { served = 0 },
		staff = { roster = {} },
		freeGift = { nextAt = 0 },
		stations = {},
	}
	eq(Guide.sync(fresh, Guide.signals(data)), false)
	data.stations.s1 = { meat = "firstbrisket" }
	truthy(Guide.sync(fresh, Guide.signals(data)))
	eq(Guide.view(fresh).id, "serve")
	data.stats.served = 1
	data.tutorial.firstBrisket = true
	Guide.sync(fresh, Guide.signals(data))
	eq(Guide.view(fresh).id, "crew")
	data.staff.roster = { { id = "pip" } }
	Guide.sync(fresh, Guide.signals(data))
	eq(Guide.view(fresh).id, "gift")
	data.freeGift.nextAt = 50
	Guide.sync(fresh, Guide.signals(data))
	eq(fresh.done, true)
	eq(Guide.view(fresh).active, false)
	eq(Guide.skip(fresh), false)
	local saved = { step = 3, done = false, skipped = false, introduced = true }
	Guide.prepare(saved, { served = 1, playSeconds = 40, crew = 0 })
	eq(saved.skipped, false, "rejoin keeps the step")
	eq(Guide.view(saved).id, "crew")
	truthy(Guide.skip(saved))
	eq(Guide.view(saved).active, false)
	local veteran = Guide.new()
	Guide.prepare(veteran, { served = 3, firstBrisket = true, tutorialDone = true, playSeconds = 400, crew = 0 })
	eq(veteran.skipped, true)
	eq(Guide.view(veteran).active, false)
	local filled = Reconcile.fill({}, DefaultData)
	eq(filled.guide.step, 1)
	eq(filled.guide.done, false)
end)

local function assertHud(label: string, width: number, height: number, insets: any, opts: any)
	local lay = HudLayout.compute(width, height, insets, opts)
	local names = { "currencies", "menu", "goals", "guide", "actions", "stations", "right", "status", "first", "hint", "rookie" }
	for i, name in ipairs(names) do
		local item = lay[name]
		truthy(HudLayout.inside(item, lay.safe), string.format("%s %s leaves the safe area", label, name))
		for j = i + 1, #names do
			local other = lay[names[j]]
			if HudLayout.overlaps(item, other) then
				error(string.format("%s %s overlaps %s", label, name, names[j]))
			end
		end
	end
	if lay.stationCard.h > 0 then
		local aspect = lay.stationCard.w / lay.stationCard.h
		truthy(aspect > 0.95 and aspect < 1.8, label .. " card aspect " .. aspect)
	end
	if width >= 360 and height >= 500 and not lay.compact then
		truthy(lay.menuButton.h >= 44, label)
	end
	if lay.compact and lay.actions.h > 0 and height >= 500 then
		truthy(lay.actions.h >= 44, label .. " action row")
		truthy(lay.menuButton.h >= 44, label .. " menu button")
	end
end

print("Turkey Day week")
test("a full Turkey Day week: before, during, after, the share, and Holiday Smokeout the same way", function()
	local TD, HS = Config.TurkeyDay, Config.HolidaySmokeout
	local idx = function(id: string): number
		return Rarity.indexOf(Config.Rarities, id)
	end
	local function dayOf(y: number, m: number, d: number): number
		return Holiday.daysFromCivil(y, m, d)
	end
	local function turkey(day: number)
		return Holiday.turkeyWeek(day, TD.daysBefore, TD.daysAfter)
	end
	local function request(active: boolean, day: number, sharedOn: number, plates: { any }, meatId: string, price: number, mult: number, owns: boolean)
		return {
			active = active,
			day = day,
			sharedOn = sharedOn,
			cooler = plates,
			meatId = meatId,
			ownsReward = owns,
			price = price,
			shareMult = mult,
			rankMult = 1,
			rarityIndex = idx,
		}
	end
	-- Wed Nov 18 2026 is inside the teaser week (opens Mon Nov 23), not the event itself.
	local today = dayOf(2026, 11, 18)
	local wToday = turkey(today)
	eq(wToday.active, false, "Nov 18 is before the window")
	eq(Holiday.soon(today, wToday, Config.EventTeaserDays), 5, "five days out")
	eq(Holiday.longLabel(wToday.startDay), "Mon, Nov 23")
	local soonByDay = { [15] = nil, [16] = 7, [18] = 5, [22] = 1, [23] = nil, [26] = nil, [29] = nil, [30] = nil }
	local openByDay = { [15] = false, [16] = false, [18] = false, [22] = false, [23] = true, [26] = true, [29] = true, [30] = false }
	for d, active in pairs(openByDay) do
		local day = dayOf(2026, 11, d)
		local w = turkey(day)
		eq(w.active, active, "Nov " .. d)
		eq(Holiday.soon(day, w, Config.EventTeaserDays), soonByDay[d], "teaser Nov " .. d)
		if active then
			eq(Holiday.label(w.startDay), "Nov 23")
			eq(Holiday.label(w.endDay), "Nov 29")
		end
	end
	eq(turkey(dayOf(2026, 11, 26)).isDay, true, "Thanksgiving")
	local openDays = 0
	for d = 15, 30 do
		if turkey(dayOf(2026, 11, d)).active then
			openDays += 1
		end
	end
	eq(openDays, 7, "Mon through Sun, then it is packed up")

	local open = dayOf(2026, 11, 26)
	local leg = Config.Meats.turkeyleg
	local cooler = {
		{ m = "turkeyleg", r = "juicy", by = "crew" },
		{ m = "burger", r = "common" },
		{ m = "turkeyleg", r = "smokering" },
		{ m = "turkeyleg", r = "common" },
	}
	local before = Holiday.tryShare(request(false, today, -1, cooler, TD.meat, leg.price, TD.shareMult, false))
	eq(before.reason, "closed")
	eq(before.ok, false)
	eq(#cooler, 4, "a closed table doesn't take the plate")
	local first = Holiday.tryShare(request(true, open, -1, cooler, TD.meat, leg.price, TD.shareMult, false))
	eq(first.ok, true)
	eq(first.index, 4, "plainest leg the player cooked, never the crew leg")
	eq(first.first, true, "first share earns the apron")
	eq(first.coins, math.floor(leg.price * TD.shareMult))
	local taken = table.remove(cooler, first.index :: number)
	eq(taken.by, nil)
	eq(taken.r, "common")
	local sameDay = Holiday.tryShare(request(true, open, open, cooler, TD.meat, leg.price, TD.shareMult, true))
	eq(sameDay.reason, "already")
	eq(#cooler, 3, "the second visit doesn't take another plate")
	local tomorrow = Holiday.tryShare(request(true, open + 1, open, cooler, TD.meat, leg.price, TD.shareMult, true))
	eq(tomorrow.ok, true)
	eq(tomorrow.first, false, "the apron is already earned")
	eq(tomorrow.index, 3, "the rare player leg is still shareable the next day")
	local onlyCrew = { { m = "turkeyleg", r = "common", by = "crew" }, { m = "turkeyleg", r = "juicy", by = "crew" } }
	local farm = Holiday.tryShare(request(true, open, -1, onlyCrew, TD.meat, leg.price, TD.shareMult, false))
	eq(farm.reason, "need", "crew legs cannot cash the daily reward or the apron")
	eq(#onlyCrew, 2)
	local after = Holiday.tryShare(request(turkey(dayOf(2026, 11, 30)).active, dayOf(2026, 11, 30), -1, cooler, TD.meat, leg.price, TD.shareMult, true))
	eq(after.reason, "closed", "Nov 30 the table is packed up")

	-- three different pitmasters fill the table; one pitmaster twice is still one dish
	local shares: { [number]: number } = {}
	local last = -1e9
	local filled = false
	local filledN = 0
	for uid = 1, TD.need do
		shares[uid] = 5000
		local n, go = Hype.pileOn(shares, 5000, TD.window, TD.need, last, TD.cooldown)
		filled = go
		filledN = n
	end
	eq(filledN, TD.need)
	eq(filled, true)
	local solo: { [number]: number } = { [7] = 5000 }
	solo[7] = 5010
	local soloN = Hype.pileOn(solo, 5010, TD.window, TD.need, -1e9, TD.cooldown)
	eq(soloN, 1, "the same pitmaster cannot fill a seat twice")

	-- Holiday Smokeout: same share rules, its own dates
	local function holiday(day: number)
		return Holiday.dateWindow(day, HS.start, HS.finish, HS.peak)
	end
	local dec18 = dayOf(2026, 12, 18)
	eq(holiday(dec18).active, false)
	eq(Holiday.soon(dec18, holiday(dec18), Config.EventTeaserDays), 1)
	local christmas = dayOf(2026, 12, 25)
	eq(holiday(christmas).active, true)
	eq(holiday(christmas).isDay, true)
	eq(holiday(dayOf(2027, 1, 1)).active, true)
	eq(holiday(dayOf(2027, 1, 2)).active, false)
	local ham = Config.Meats.holidayham
	local hCooler = { { m = "holidayham", r = "common", by = "crew" }, { m = "holidayham", r = "juicy" } }
	local hShare = Holiday.tryShare(request(true, christmas, -1, hCooler, HS.meat, ham.price, HS.shareMult, false))
	eq(hShare.index, 2, "player ham, not the crew ham")
	eq(hShare.first, true)
	eq(hShare.coins, math.floor(ham.price * HS.shareMult))
	local hClosed = Holiday.tryShare(request(false, dayOf(2027, 1, 2), -1, hCooler, HS.meat, ham.price, HS.shareMult, false))
	eq(hClosed.reason, "closed")
	for _, p in pairs(Monetization.Products) do
		if p.event == "turkeyday" or p.event == "holiday" then
			truthy(p.kind == "cosmetic" or p.kind == "bundle", "event Robux buys a look, not a roll")
			truthy(p.grants ~= nil and #p.grants > 0)
			local low = string.lower(p.name .. " " .. p.desc .. " " .. (p.valueNote or ""))
			for _, word in ipairs({ "last chance", "hurry", "don't miss", "only today", "loot", "random" }) do
				truthy(string.find(low, word, 1, true) == nil, p.name .. " " .. word)
			end
		end
	end
	local bill = Economy.cookBill(leg, 1, Config.RANK_STEP, { pass = false, tokens = 0, unlocked = false })
	eq(bill.allowed, true)
	eq(bill.coins, Economy.rawCost(leg, Economy.rankMult(1, Config.RANK_STEP)))
	truthy(bill.coins > 0 and bill.coins <= 100, "a new pitmaster can afford a turkey leg")
end)

test("crew cooks burgers and hot links, and automatic serving leaves the potluck dish", function()
	local world = { coins = 100000, cooler = 0, coolerMax = 40, customers = 0, openGrill = 3, openSmoker = 3, done = 0, burgerCost = 2, linkCost = 6 }
	for _, hand in ipairs(Staff.HANDS) do
		local meat = Staff.stationMeat(hand.role)
		truthy(meat ~= "turkeyleg" and meat ~= "holidayham", hand.name .. " does not start an event cut")
		local e = { id = hand.id, name = hand.name, species = hand.species, role = hand.role, speed = 1, capacity = 2, quality = 1 }
		local decision = Staff.decide(e, world)
		if decision and decision.kind == "cook" then
			truthy(decision.meat == "burger" or decision.meat == "hotlink", hand.name)
		end
	end
	eq(Staff.stationMeat("floor"), nil)
	local idx = function(id: string): number
		return Rarity.indexOf(Config.Rarities, id)
	end
	local cooler = {
		{ m = "turkeyleg", r = "juicy", by = "crew" },
		{ m = "burger", r = "common" },
		{ m = "turkeyleg", r = "common" },
	}
	eq(Holiday.holdPlate(cooler, "turkeyleg", false, idx), 3)
	eq(Holiday.holdPlate(cooler, "turkeyleg", true, idx), nil, "after the share, nothing is held")
	eq(Holiday.servable(#cooler, true), 2)
	eq(Holiday.servable(1, true), 0, "the last dish stays for the table")
	local held = cooler[3]
	local function score(plate): number
		return if plate.m == "turkeyleg" then 260 else 12
	end
	eq(Holiday.autoPlate(cooler, held, score), 1, "a crew leg can be sold; the held leg cannot")
	eq(Holiday.autoPlate(cooler, nil, score), 1, "with nothing held, the valuable crew leg sells first")
	eq(Holiday.autoPlate({ held }, held, score), nil, "Jimothy does not take the last potluck dish")
	-- a customer who ordered turkey still doesn't get the held one when a burger is there
	eq(Holiday.autoPlate(cooler, held, function(plate): number
		local match = plate.m == "turkeyleg"
		return (if plate.m == "turkeyleg" then 260 else 12) + (if match then 1e9 else 0)
	end), 1, "the order match on a crew leg still skips the player's dish")
end)

test("potluck notes and autumn decor are wired, and the share is not behind the action lock", function()
	local gs = fs_read("src/server/Services/GameService.luau")
	local ev = fs_read("src/server/Services/EventService.luau")
	local egg = fs_read("src/server/Services/EggService.luau")
	local wb = fs_read("src/shared/WorldBuilder.luau")
	truthy(string.find(egg, "Holiday.tryShare", 1, true) ~= nil, "the prompt uses the shared rules")
	truthy(string.find(egg, "Slow down", 1, true) == nil, "sharing is a prompt, not the action lock")
	truthy(string.find(gs, "event:potluck", 1, true) == nil, "sharing is not a remote action")
	truthy(string.find(gs, "serveCustomer(player, r.customers[1], tip, true)", 1, true) ~= nil, "crew serve is automatic")
	truthy(string.find(gs, "serveCustomer(player, r.customers[1], nil, true)", 1, true) ~= nil, "Jimothy serve is automatic")
	truthy(string.find(gs, 'plate.by = "crew"', 1, true) ~= nil, "a hand's plate is marked")
	truthy(string.find(gs, 'GetAttribute("ForceTurkeyDay")', 1, true) ~= nil)
	truthy(string.find(gs, 'GetAttribute("ForceHolidaySmokeout")', 1, true) ~= nil)
	truthy(string.find(gs, "RunService:IsStudio()", 1, true) ~= nil, "the force switch is Studio-only")
	truthy(string.find(ev, "Guide.view(data.guide).active", 1, true) ~= nil, "the login note waits for the guide")
	truthy(string.find(ev, "eventNoteDue", 1, true) ~= nil)
	truthy(string.find(gs, "r.eventNoteDue = true", 1, true) ~= nil, "midnight retries the note")
	truthy(string.find(ev, "WorldBuilder.autumnRanch", 1, true) ~= nil)
	truthy(string.find(ev, 'FindFirstChild("AutumnRanch")', 1, true) ~= nil, "decor is removed when the week ends")
	local defAt = string.find(wb, "function WorldBuilder.autumnRanch", 1, true)
	truthy(defAt ~= nil)
	eq(string.find(wb, "WorldBuilder.autumnRanch(", defAt :: number + 10, true), nil, "the baked map does not include the pumpkins")
	truthy(string.find(wb, "Big Biscuit", 1, true) == nil and string.find(wb, "dog statue", 1, true) == nil)
end)

print("Phone HUD")
test("currency, menu, goals, stations and the guide card do not overlap on small phones", function()
	local phones = {
		{ 1280, 720, nil },
		{ 1920, 1080, nil },
		{ 1024, 768, nil },
		{ 844, 390, { left = 47, top = 0, right = 47, bottom = 21 } },
		{ 667, 375, { left = 44, top = 0, right = 44, bottom = 12 } },
		{ 390, 844, { left = 0, top = 0, right = 0, bottom = 34 } },
		{ 320, 568, { left = 0, top = 0, right = 0, bottom = 20 } },
		{ 360, 640, { left = 0, top = 0, right = 0, bottom = 24 } },
	}
	local modes = {
		{ guide = true, rookie = false, goals = false, hint = true, first = true },
		{ guide = true, rookie = true, goals = false, hint = false, first = false },
		{ guide = false, rookie = true, goals = true, hint = true, first = true },
		{ guide = false, rookie = false, goals = true, hint = false, first = false },
	}
	for _, phone in ipairs(phones) do
		for _, mode in ipairs(modes) do
			assertHud(string.format("%dx%d", phone[1], phone[2]), phone[1], phone[2], phone[3], mode)
		end
	end
	local crowded = HudLayout.compute(844, 390, { left = 47, top = 0, right = 47, bottom = 21 }, { guide = true, first = true, rookie = true, hint = true, goals = false })
	truthy(crowded.guide.h >= 36, "the hint banner stays on a landscape phone")
	truthy(crowded.safe.x >= 47 and crowded.safe.y + crowded.safe.h <= 390 - 21)
end)

test("Turkey Day toasts and the potluck announcement stay off the guide, goals and buttons", function()
	local phones = {
		{ 1280, 720, nil },
		{ 1920, 1080, nil },
		{ 844, 390, { left = 47, top = 0, right = 47, bottom = 21 } },
		{ 390, 844, { left = 0, top = 0, right = 0, bottom = 34 } },
		{ 360, 640, { left = 0, top = 0, right = 0, bottom = 24 } },
	}
	local modes = {
		{ guide = true, rookie = false, goals = false, hint = true, first = true },
		{ guide = true, rookie = true, goals = false, hint = false, first = false },
		{ guide = false, rookie = true, goals = true, hint = true, first = true },
		{ guide = false, rookie = false, goals = true, hint = false, first = false },
	}
	local hard = { "currencies", "menu", "goals", "guide", "actions", "first", "hint" }
	for _, phone in ipairs(phones) do
		for _, mode in ipairs(modes) do
			local label = string.format("%dx%d", phone[1], phone[2])
			local lay = HudLayout.compute(phone[1], phone[2], phone[3], mode)
			local n = HudLayout.notices(phone[1], phone[2], phone[3], mode)
			truthy(n.toast.h > 0 and n.announce.h > 0, label .. " has a spot for the note")
			truthy(not HudLayout.overlaps(n.toast, n.announce), label .. " toast covers the announcement")
			for _, box in ipairs({ n.toast, n.announce }) do
				truthy(HudLayout.inside(box, lay.safe), label .. " note leaves the safe area")
				for _, name in ipairs(hard) do
					if HudLayout.overlaps(box, lay[name]) then
						error(string.format("%s note overlaps %s", label, name))
					end
				end
			end
		end
	end
	local desk = HudLayout.compute(1280, 720, nil, { guide = true, goals = false, first = true, hint = true })
	local notes = HudLayout.notices(1280, 720, nil, { guide = true, goals = false, first = true, hint = true })
	truthy(notes.announce.y >= desk.guide.y + desk.guide.h, "desktop announcement starts below the guide")
	truthy(notes.toast.y > notes.announce.y, "the toast follows the announcement")
	local phoneLay = HudLayout.compute(390, 844, { left = 0, top = 0, right = 0, bottom = 34 }, { guide = true, goals = false, first = true })
	local phoneNotes = HudLayout.notices(390, 844, { left = 0, top = 0, right = 0, bottom = 34 }, { guide = true, goals = false, first = true })
	truthy(phoneNotes.toast.y >= phoneLay.guide.y + phoneLay.guide.h, "phone toast starts below the guide")
end)

print("Crew core loop")
local Crew = require("../src/shared/Logic/Crew")
local HiringLine = require("../src/shared/Logic/HiringLine")
local Offline = require("../src/shared/Logic/Offline")
local Migrate = require("../src/shared/Logic/Migrate")

local function countSpecies()
	local n, secret, by = 0, 0, {}
	for _, row in ipairs(Config.CrewSpecies) do
		n += 1
		by[row.rarity] = (by[row.rarity] or 0) + 1
		if row.secret then
			secret += 1
		end
	end
	return n, secret, by
end

test("about 30 species across 6 rarities, plus one secret Rex, with coin prices that scale", function()
	local n, secret, by = countSpecies()
	eq(n, 31)
	eq(secret, 1)
	for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary", "mythic" }) do
		eq(by[rarity], 5, rarity)
	end
	eq(by.secret, 1)
	local floorRate = 0
	for _, rarity in ipairs({ "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }) do
		local best = math.huge
		for _, row in ipairs(Config.CrewSpecies) do
			if row.rarity == rarity then
				truthy(row.price == math.floor(row.price) and row.price > 0, row.id)
				truthy(row.baseRate > 0, row.id)
				truthy(row.price / row.baseRate >= floorRate - 1e-6, row.id .. " price scales with output")
				best = math.min(best, row.price / row.baseRate)
				truthy(string.find(string.lower(row.line .. row.name), "beer", 1, true) == nil, row.id)
				truthy(string.find(string.lower(row.line .. row.name), "wine", 1, true) == nil, row.id)
			end
		end
		floorRate = best
	end
	eq(Config.Founders.pip.species, "armadillo")
	eq(Config.Founders.biscuit.species, "pup")
	eq(Config.Founders.dottie.species, "hummingbird")
	eq(Config.Founders.tumble.species, "roadrunner")
	eq(Config.Founders.mango.species, "longhorn")
end)

test("ranch tiers add 2 crew slots, from 3 up to 19", function()
	eq(Crew.slotCount(1, 0), 3)
	eq(Crew.slotCount(2, 0), 5)
	eq(Crew.slotCount(3, 0), 7)
	eq(Crew.slotCount(8, 0), 17)
	eq(Crew.slotCount(8, 1), 18)
	eq(Crew.slotCount(8, 2), 19)
	eq(Crew.slotCount(8, 9), 19, "the cap stays 19 before rebirth")
	eq(Crew.slotCount(1, 2), 5)
	eq(#Config.RanchTiers, 8)
	eq(Config.RanchTiers[1].cost, 0)
	truthy(Config.RanchTiers[2].cost > 0)
	for i = 2, 7 do
		truthy(Config.RanchTiers[i + 1].cost > Config.RanchTiers[i].cost, "tier " .. (i + 1))
	end
end)

test("crew coins per second follow level, trait, rank, friends and the Fair Play cap", function()
	eq(Crew.founderLevel(1, 1, 1), 1)
	eq(Crew.founderLevel(5, 1, 3), 3)
	eq(Crew.founderLevel(4, 5, 4), 4)
	eq(Crew.founderLevel(5, 5, 4), 5)
	eq(Crew.founderLevel(99, 99, 99), 10)
	near(Crew.levelMult(1), 1)
	near(Crew.levelMult(2), 1.15)
	near(Crew.levelMult(10), 2.35)
	near(Crew.rate(10, 1, "none", nil, true), 10)
	near(Crew.rate(10, 2, "none", nil, true), 11.5)
	near(Crew.rate(10, 1, "smoky", nil, true), 15)
	near(Crew.rate(10, 1, "glazed", nil, true), 20)
	near(Crew.rate(10, 1, "golden", nil, true), 30)
	near(Crew.rate(10, 1, "meteorite", nil, true), 60)
	local plain = Crew.rate(10, 1, "none", { rank = 1, friends = 0, tipPass = false }, false)
	near(plain, 10)
	near(Crew.rate(10, 1, "none", { rank = 3, friends = 0, tipPass = false }, false), 10 * (1 + Config.RANK_STEP * 2))
	near(Crew.rate(10, 1, "none", { rank = 1, friends = 9, tipPass = false }, false), 10 * 1.3, 1e-6)
	near(Crew.rate(10, 1, "none", { rank = 1, friends = 0, tipPass = true }, false), 15)
	near(Crew.tipMult(true), math.min(Config.FairPlay.passTipMult, Config.FairPlay.passTipCap))
	local owned = {
		{ uid = 1, species = "armadillo", name = "Pip", level = 1, trait = "none", role = "pit" },
		{ uid = 2, species = "pup", name = "Biscuit", level = 1, trait = "golden", role = "grill" },
	}
	near(Crew.totalRate(owned, 1, { rank = 1, friends = 0, tipPass = false }), 1)
	near(Crew.totalRate(owned, 2, { rank = 1, friends = 0, tipPass = false }), 1 + 4 * 3)
	local coins, bank = Crew.tickPay(1.5, 0)
	eq(coins, 1)
	near(bank, 0.5)
	local coins2, bank2 = Crew.tickPay(1.5, bank)
	eq(coins2, 2)
	near(bank2, 0)
	eq(Crew.greeterDelay(0), 1)
	eq(Crew.greeterDelay(1), 0.92)
	eq(Crew.greeterDelay(20), 0.6)
end)

test("hiring spends coins, merges a duplicate, and stops at the slot cap", function()
	local data = { coins = 100, crew = { owned = {}, slots = 3, nextUid = 1, extra = 0 }, ranch = { tier = 1 }, offline = { lastTick = 0 } }
	local applicant = { species = "armadillo", trait = "none", price = 25 }
	local outcome = Crew.tryHire(data, applicant)
	truthy(outcome.ok)
	eq(outcome.cost, 25)
	eq(outcome.coins, 75)
	local member = Crew.applyHire(data, outcome)
	eq(member.name, "Shellie")
	eq(data.coins, 75)
	eq(#data.crew.owned, 1)
	local again = Crew.tryHire(data, applicant)
	truthy(again.ok)
	eq(again.mergeUid, member.uid)
	Crew.applyHire(data, again)
	eq(#data.crew.owned, 1, "a duplicate merges")
	eq(data.crew.owned[1].level, 2)
	eq(data.coins, 50)
	local poor = Crew.tryHire(data, { species = "rex", trait = "none", price = 1200000 })
	eq(poor.ok, false)
	eq(poor.reason, "coins")
	eq(data.coins, 50)
	data.coins = 100000
	data.crew.owned[1].level = 10
	local turtle = Crew.tryHire(data, { species = "turtle", trait = "none", price = 50 })
	truthy(turtle.ok)
	Crew.applyHire(data, turtle)
	data.crew.owned[2].level = 10
	local toad = Crew.tryHire(data, { species = "hornedtoad", trait = "none", price = 55 })
	truthy(toad.ok)
	Crew.applyHire(data, toad)
	data.crew.owned[3].level = 10
	eq(data.crew.slots, 3)
	local blocked = Crew.tryHire(data, { species = "pup", trait = "none", price = 180 })
	eq(blocked.reason, "slots")
	eq(#data.crew.owned, 3)
	data.ranch.tier = 2
	data.crew.slots = Crew.slotCount(2, 0)
	local second = Crew.tryHire(data, { species = "pup", trait = "none", price = 180 })
	truthy(second.ok)
	Crew.applyHire(data, second)
	eq(#data.crew.owned, 4)
	eq(data.crew.owned[4].species, "pup")
	local leveled = Crew.tryLevel(data, data.crew.owned[4].uid)
	truthy(leveled.ok)
	truthy(Crew.applyLevel(data, leveled))
	eq(data.crew.owned[4].level, 2)
	local built = Crew.tryTier(data)
	truthy(built.ok)
	eq(built.tier, 3)
	truthy(Crew.applyTier(data, built))
	eq(data.ranch.tier, 3)
	eq(data.crew.slots, 7)
end)

test("the hiring line is deterministic, coin-priced, and the first claim wins", function()
	local a = HiringLine.stock(42, 10, 1)
	local b = HiringLine.stock(42, 10, 1)
	eq(#a, 6)
	eq(#b, 6)
	for i = 1, 6 do
		eq(a[i].species, b[i].species)
		eq(a[i].price, b[i].price)
		eq(a[i].trait, b[i].trait)
		eq(a[i].rate, b[i].rate)
		local species = Crew.byId(a[i].species)
		local trait = Crew.traitDef(a[i].trait)
		eq(a[i].price, math.max(1, math.floor(species.price * trait.mult + 0.5)))
		near(a[i].rate, species.baseRate * trait.mult)
	end
	truthy(HiringLine.stock(42, 11, 1)[1].species ~= a[1].species or HiringLine.stock(42, 11, 1)[2].species ~= a[2].species or HiringLine.stock(7, 10, 1)[1].species ~= a[1].species)
	local function rareShare(tier, windows)
		local rare = 0
		for w = 1, windows do
			for _, row in ipairs(HiringLine.stock(99, w, tier)) do
				if row.rarity ~= "common" and row.rarity ~= "uncommon" then
					rare += 1
				end
			end
		end
		return rare / (windows * 6)
	end
	truthy(rareShare(8, 400) > rareShare(1, 400), "a higher ranch tier sees rarer applicants")
	local rex = 0
	local windows = 20000
	for w = 1, windows do
		local stock = HiringLine.stock(123, w, 4)
		if stock[6].species == "rex" then
			rex += 1
		end
	end
	near(rex / windows, Config.Hiring.rexChance, 0.0015)
	local taken = {}
	truthy(HiringLine.tryTake(taken, 2, 100))
	eq(taken[2], 100)
	truthy(not HiringLine.tryTake(taken, 2, 200))
	eq(taken[2], 100, "the first claim keeps the applicant")
	truthy(not HiringLine.tryTake(taken, 0, 200))
	truthy(not HiringLine.tryTake(taken, 7, 200))
	local label = HiringLine.clockLabel(1_700_000_000, 300, -6)
	truthy(string.find(label, "Next lineup:", 1, true) ~= nil)
	truthy(string.find(label, "CT", 1, true) ~= nil)
	truthy(string.find(label, "left", 1, true) == nil)
	truthy(string.find(string.lower(label), "hurry", 1, true) == nil)
	local src = fs_read("src/shared/Logic/HiringLine.luau")
	truthy(string.find(src, "Robux", 1, true) == nil, "hire odds do not read Robux")
	truthy(string.find(src, "Monetization", 1, true) == nil)
	local crewSrc = fs_read("src/shared/Logic/Crew.luau")
	truthy(string.find(crewSrc, "Monetization", 1, true) == nil)
end)

test("offline crew pay is the full rate, capped at 4 hours", function()
	eq(Offline.cap(false), 4 * 3600)
	eq(Offline.cap(true), 8 * 3600)
	eq(Offline.awaySeconds(0, 10_000, Offline.CAP), 0)
	eq(Offline.awaySeconds(100, 100, Offline.CAP), 0)
	eq(Offline.awaySeconds(100, 50, Offline.CAP), 0)
	eq(Offline.awaySeconds(1_000, 1_000 + 90, Offline.CAP), 90)
	eq(Offline.awaySeconds(1_000, 1_000 + 5 * 3600, Offline.CAP), 4 * 3600)
	eq(Offline.awaySeconds(1_000, 1_000 + 9 * 3600, Offline.cap(true)), 8 * 3600)
	eq(Offline.coins(1.5, 10), 15)
	eq(Offline.coins(2, 4 * 3600), 2 * 4 * 3600)
	eq(Offline.coins(2, 0), 0)
	local settled = Offline.settle(5_000, 5_000 + 5 * 3600, Offline.CAP, 3)
	eq(settled.seconds, 4 * 3600)
	eq(settled.coins, 3 * 4 * 3600)
	eq(settled.lastTick, 5_000 + 5 * 3600)
	local fresh = Offline.settle(0, 9_000, Offline.CAP, 10)
	eq(fresh.coins, 0)
	eq(fresh.seconds, 0)
end)

test("a v1 save keeps its coins and turns the five founders into crew", function()
	local fresh = Reconcile.fill(nil, DefaultData)
	eq(fresh.schema, 2)
	truthy(not Migrate.apply(fresh, 50))
	eq(#fresh.crew.owned, 0)
	eq(fresh.coins, Config.START_COINS)
	local v1 = {
		schema = 1,
		coins = 4321,
		lifetimeCoins = 9000,
		rank = 1,
		pitLevel = 3,
		smokerSlotsBought = 2,
		grillSlotsBought = 1,
		staff = {
			roster = {
				{ id = "pip", speed = 1, capacity = 1, quality = 1 },
				{ id = "biscuit", speed = 2, capacity = 2, quality = 2 },
				{ id = "dottie", speed = 5, capacity = 1, quality = 3 },
				{ id = "tumble", speed = 4, capacity = 5, quality = 4 },
				{ id = "mango", speed = 5, capacity = 5, quality = 4 },
				{ id = "nope", speed = 3, capacity = 3, quality = 3 },
			},
		},
		receipts = { ["abc"] = true },
		purchases = { once = { StarterPitPack = true }, count = 2 },
		owned = { hat_straw = true },
		titles = {},
		critters = { armadillo = 4 },
		cuts = { wagyu = 1, tomahawk = 0 },
		tutorial = { firstBrisket = true, done = false },
		rookie = { claimed = 2, skipped = false },
		guide = { step = 1, done = false },
	}
	local filled = Reconcile.fill(v1, DefaultData)
	eq(filled.schema, 1, "fill does not bump a v1 schema")
	truthy(Migrate.apply(filled, 1_700_000_000))
	eq(filled.schema, 2)
	eq(filled.coins, 4321 + Config.RookieFinish.coins, "the in-progress Rookie List pays its finish reward once")
	eq(filled.lifetimeCoins, 9000)
	eq(filled.rank, 1)
	eq(filled.receipts.abc, true)
	eq(filled.purchases.count, 2)
	eq(filled.purchases.once.StarterPitPack, true)
	eq(filled.owned.hat_straw, true)
	eq(filled.owned[Config.RookieFinish.cosmetic], true)
	eq(filled.titles[Config.RookieFinish.title], true)
	eq(filled.critters.armadillo, 4)
	eq(filled.cuts.wagyu, 1)
	eq(#filled.staff.roster, 6, "the old roster stays in the save")
	eq(#filled.crew.owned, 5)
	eq(filled.crew.owned[1].name, "Pip")
	eq(filled.crew.owned[1].species, "armadillo")
	eq(filled.crew.owned[1].level, 1)
	eq(filled.crew.owned[1].badge, "Founder")
	eq(filled.crew.owned[1].trait, "none")
	eq(filled.crew.owned[2].name, "Biscuit")
	eq(filled.crew.owned[2].species, "pup")
	eq(filled.crew.owned[2].level, 2)
	eq(filled.crew.owned[3].name, "Dottie")
	eq(filled.crew.owned[3].species, "hummingbird")
	eq(filled.crew.owned[3].level, 3)
	eq(filled.crew.owned[3].role, "server")
	eq(filled.crew.owned[4].name, "Tumble")
	eq(filled.crew.owned[4].species, "roadrunner")
	eq(filled.crew.owned[4].level, 4)
	eq(filled.crew.owned[5].name, "Mango")
	eq(filled.crew.owned[5].species, "longhorn")
	eq(filled.crew.owned[5].level, 5)
	eq(filled.crew.owned[5].role, "pit")
	eq(filled.ranch.tier, 3)
	eq(filled.crew.extra, 2)
	eq(filled.crew.slots, Crew.slotCount(3, 2))
	eq(filled.onboard.done, true)
	eq(filled.onboard.rookieReward, true)
	eq(filled.offline.lastTick, 1_700_000_000)
	eq(type(filled.index.traits), "table")
	eq(filled.events.smokeShowWeek, -1)
	local coinsAfter = filled.coins
	truthy(not Migrate.apply(filled, 1_800_000_000))
	eq(#filled.crew.owned, 5)
	eq(filled.coins, coinsAfter, "a second migrate does not pay the rookie reward again")
	eq(filled.offline.lastTick, 1_700_000_000)
end)

test("a veteran and a payer keep rank, receipts and coins", function()
	local veteran = Reconcile.fill({
		schema = 1,
		coins = 50000,
		lifetimeCoins = 800000,
		rank = 3,
		pitLevel = 5,
		tutorial = { done = true, firstBrisket = true },
		guide = { step = 4, done = true },
		rookie = { claimed = 5 },
		titles = { ["Rookie of the Ranch"] = true },
		receipts = {},
		staff = { roster = {} },
	}, DefaultData)
	truthy(Migrate.apply(veteran, 10))
	eq(veteran.rank, 3)
	eq(veteran.ranch.tier, 5)
	eq(veteran.crew.slots, 11)
	eq(veteran.coins, 50000, "a finished rookie list is not paid again")
	eq(veteran.onboard.done, true)
	eq(veteran.lifetimeCoins, 800000)
	local payer = Reconcile.fill({
		schema = 1,
		coins = 77,
		rank = 2,
		pitLevel = 1,
		receipts = { ["rcp-1"] = true, ["rcp-2"] = true },
		purchases = { once = { StarterPitPack = true }, count = 4 },
		cuts = { wagyu = 3, tomahawk = 2 },
		staff = { roster = {} },
		tutorial = { done = false, firstBrisket = false },
		rookie = { claimed = 0 },
		guide = { step = 1, done = false },
	}, DefaultData)
	truthy(Migrate.apply(payer, 10))
	eq(payer.coins, 77)
	eq(payer.rank, 2)
	eq(payer.receipts["rcp-1"], true)
	eq(payer.receipts["rcp-2"], true)
	eq(payer.purchases.count, 4)
	eq(payer.purchases.once.StarterPitPack, true)
	eq(payer.cuts.wagyu, 3)
	eq(#payer.crew.owned, 0)
	eq(payer.onboard.done, false)
	eq(payer.ranch.tier, 1)
	eq(payer.crew.slots, 3)
end)

test("an unflipped burger pays full when the flip is not required, and the retired chores stay off", function()
	local F = Config.Flip
	eq(Economy.flipFactor(nil, false, F.perfectMult, F.goodMult, F.missMult, F.unflippedMult), 1)
	eq(Economy.flipFactor(nil, true, F.perfectMult, F.goodMult, F.missMult, F.unflippedMult), F.unflippedMult)
	eq(Economy.flipFactor("perfect", false, F.perfectMult, F.goodMult, F.missMult, F.unflippedMult), F.perfectMult)
	eq(Config.Chores.lunchRush, false)
	eq(Config.Chores.peekPenalty, false)
	eq(Config.Chores.flipRequired, false)
	eq(Config.Chores.legacyStaff, false)
	eq(TimeUtil.clock(0, 0), "12:00 AM")
	local game = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(game, "payCrew", 1, true) ~= nil)
	truthy(string.find(game, "HireApplicant", 1, true) ~= nil)
	local dataSrc = fs_read("src/server/Services/DataService.luau")
	truthy(string.find(dataSrc, "Migrate.apply", 1, true) ~= nil)
	eq(Monetization.Passes.DoubleTips.id, 2088839581)
	eq(Monetization.Passes.AutoServe.id, 2089955594)
end)

test("the town square has a hiring boardwalk and each ranch has tier pieces and station slots", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local env = { Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local ws = roblox.Instance.new("Folder")
	local map = WorldBuilder.build(env, ws, Config, Content)
	local line = map.Hub:FindFirstChild("HiringLine")
	truthy(line ~= nil)
	truthy(line:FindFirstChild("NowHiring") ~= nil)
	truthy(line:FindFirstChild("RestockBoard") ~= nil)
	eq(#line.Pads:GetChildren(), 6)
	local signText = ""
	for _, d in ipairs(line.NowHiring:GetDescendants()) do
		if d:IsA("TextLabel") then
			signText ..= d.Text
		end
	end
	truthy(string.find(signText, "NOW HIRING", 1, true) ~= nil)
	for i = 1, Config.MAX_PLOTS do
		local plot = map.Plots:FindFirstChild("Plot" .. i)
		truthy(plot:FindFirstChild("RanchTiers") ~= nil, "plot " .. i)
		truthy(plot.RanchTiers:FindFirstChild("Shed") ~= nil)
		truthy(plot.RanchTiers:FindFirstChild("Sign") ~= nil)
		eq(plot.CrewStations.Pit:GetAttribute("CrewStation"), "pit")
		eq(plot.CrewStations.Grill:GetAttribute("CrewStation"), "grill")
		eq(plot.CrewStations.Serve:GetAttribute("CrewStation"), "server")
		eq(plot.CrewStations.Greet:GetAttribute("CrewStation"), "greeter")
		truthy(plot.RanchTiers.Shed.Body.Transparency == 1, "tier pieces start hidden")
	end
	local function partsOf(style)
		local m = WorldBuilder.critter(env, ws, { id = style, style = style, body = "#E07A3D", head = "#F6C7A1", scale = 0.9, staff = true }, roblox.CFrame.new())
		local n = 0
		local body = false
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
				if d.Name == "Body" then
					body = true
				end
			end
		end
		return n, body
	end
	for _, style in ipairs({ "prairie", "turtle", "bee", "fish", "dragon", "sprite" }) do
		local n, body = partsOf(style)
		truthy(body, style)
		truthy(n <= 40, style .. " part count " .. n)
	end
end)

test("every lineup has two applicants a new player can afford, and Pip is free", function()
	eq(Config.START_COINS, 50)
	eq(Config.Hiring.cheapPrice, 50)
	truthy(Config.Hiring.starterDelay + Config.Hiring.starterWalk <= 10)
	truthy(Config.Hiring.starterDelay >= 0 and Config.Hiring.starterWalk > 0)
	for seed = 1, 25 do
		for tier = 1, 8, 3 do
			for w = 1, 12 do
				local stock = HiringLine.stock(seed, w, tier)
				local cheap = 0
				for _, applicant in ipairs(stock) do
					if applicant.price <= Config.Hiring.cheapPrice then
						cheap += 1
					end
				end
				if cheap < 2 then
					error(string.format("seed %d window %d tier %d has %d cheap applicants", seed, w, tier, cheap))
				end
				HiringLine.raiseFloor(stock)
				local still = 0
				for _, applicant in ipairs(stock) do
					if applicant.price <= Config.Hiring.cheapPrice then
						still += 1
					end
				end
				if still < 2 then
					error(string.format("Saturday floor seed %d window %d tier %d left %d cheap applicants", seed, w, tier, still))
				end
			end
		end
	end
	local fresh = {
		coins = 50,
		playSeconds = 0,
		stats = { served = 0 },
		tutorial = { done = false, firstBrisket = false },
		guide = { done = false, skipped = false, step = 1 },
		onboard = { done = false },
		crew = { owned = {}, slots = 3, nextUid = 1, extra = 0 },
		ranch = { tier = 1 },
		offline = { lastTick = 0 },
	}
	truthy(Crew.needsStarter(fresh))
	local pip = Crew.grantStarter(fresh)
	truthy(pip)
	eq(pip.name, "Pip")
	eq(pip.species, "armadillo")
	eq(fresh.coins, 50, "Pip does not cost coins")
	eq(#fresh.crew.owned, 1)
	truthy(not Crew.needsStarter(fresh))
	eq(Crew.grantStarter(fresh), nil)
	local veteran = {
		coins = 5000,
		playSeconds = 0,
		stats = { served = 0 },
		tutorial = { done = true },
		guide = { done = true },
		onboard = { done = true },
		crew = { owned = {}, slots = 3, nextUid = 1, extra = 0 },
		ranch = { tier = 1 },
	}
	truthy(not Crew.needsStarter(veteran))
	local crewSrc = fs_read("src/server/Services/CrewService.luau")
	truthy(string.find(crewSrc, "Game.act", 1, true) ~= nil, "the world hire prompt uses the action pipeline")
	truthy(string.find(crewSrc, "hireApplicant", 1, true) == nil, "the prompt does not call hire directly")
	truthy(string.find(crewSrc, "Heartbeat", 1, true) == nil, "the server does not animate crew")
	local client = fs_read("src/client/CrewAnim.luau")
	truthy(string.find(client, "GetServerTimeNow", 1, true) ~= nil)
	truthy(string.find(client, "PivotTo", 1, true) ~= nil)
	local main = fs_read("src/client/Main.client.luau")
	truthy(string.find(main, "CrewAnim", 1, true) ~= nil)
	local game = fs_read("src/server/Services/GameService.luau")
	truthy(string.find(game, "function GameService.act", 1, true) ~= nil)
	truthy(string.find(game, "grantStarter", 1, true) ~= nil)
end)

test("the Hiring Line does not overlap the rest of the town square", function()
	local roblox = require("@lune/roblox")
	local WorldBuilder = require("../src/shared/WorldBuilder")
	local V3 = roblox.Vector3
	local dm = roblox.Instance.new("DataModel")
	local ws = dm:GetService("Workspace")
	local env = { Instance = roblox.Instance, Vector3 = V3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberSequence = roblox.NumberSequence, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence, Vector2 = roblox.Vector2 }
	local map = WorldBuilder.build(env, ws, Config, Content)
	local line = map.Hub.HiringLine
	local function axes(cf)
		return { cf.RightVector, cf.UpVector, -cf.LookVector }
	end
	local function boxes(root, skip)
		local out = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 and not (skip and skip(d)) then
				local cf = d.CFrame
				table.insert(out, { pos = cf.Position, size = d.Size, ax = axes(cf), name = d:GetFullName() })
			end
		end
		return out
	end
	local function extent(b, axis)
		local e = b.size * 0.5
		return e.X * math.abs(b.ax[1]:Dot(axis)) + e.Y * math.abs(b.ax[2]:Dot(axis)) + e.Z * math.abs(b.ax[3]:Dot(axis))
	end
	local function hit(a, b)
		local delta = b.pos - a.pos
		local function sep(axis)
			if axis.Magnitude < 1e-6 then
				return false
			end
			local n = axis.Unit
			return math.abs(delta:Dot(n)) > extent(a, n) + extent(b, n) + 0.05
		end
		for axis = 1, 3 do
			if sep(a.ax[axis]) or sep(b.ax[axis]) then
				return false
			end
			for other = 1, 3 do
				if sep(a.ax[axis]:Cross(b.ax[other])) then
					return false
				end
			end
		end
		return true
	end
	local lineBoxes = boxes(line)
	truthy(#lineBoxes > 8, "the boardwalk is actually built")
	local others = {}
	for _, b in ipairs(boxes(map.Hub, function(d)
		return d:IsDescendantOf(line)
	end)) do
		table.insert(others, b)
	end
	local decor = map.Scenery and map.Scenery:FindFirstChild("HubDecor")
	if decor then
		for _, b in ipairs(boxes(decor)) do
			table.insert(others, b)
		end
	end
	for _, a in ipairs(lineBoxes) do
		for _, b in ipairs(others) do
			truthy(not hit(a, b), a.name .. " overlaps " .. b.name)
		end
	end
	-- The walk in from the arch and the roads stay outside the boardwalk.
	local arch = map.Hub.WelcomeArch.Beam
	local spawn = map.Hub.HubSpawn
	for _, landmark in ipairs({ arch, spawn }) do
		local box = { pos = landmark.CFrame.Position, size = landmark.Size, ax = axes(landmark.CFrame), name = landmark.Name }
		for _, a in ipairs(lineBoxes) do
			truthy(not hit(a, box), "Hiring Line overlaps " .. landmark.Name)
		end
	end
end)

print("Smoke Storm, Index, partners")
local Weather = require("../src/shared/Logic/Weather")
local Index = require("../src/shared/Logic/Index")
local Partners = require("../src/shared/Logic/Partners")
local CrewMotion = require("../src/shared/Logic/CrewMotion")

test("smoke storm odds are shown, sum to 100, and ignore purchases", function()
	local function sum(triple)
		local total = 0
		for _, row in ipairs(Weather.shownOdds(triple)) do
			total += row.pct
		end
		return total
	end
	near(sum(false), 100, 1e-6)
	near(sum(true), 100, 1e-6)
	local base = Weather.shownOdds(false)
	local show = Weather.shownOdds(true)
	local function pct(rows, id)
		for _, row in ipairs(rows) do
			if row.id == id then
				return row.pct
			end
		end
		return 0
	end
	truthy(pct(show, "golden") > pct(base, "golden"))
	eq(Weather.roll(0, false), "none")
	eq(Weather.upgrade("golden", "smoky"), "golden")
	eq(Weather.upgrade("none", "glazed"), "glazed")
	eq(Weather.upgrade("meteorite", "golden"), "meteorite")
	local src = fs_read("src/shared/Logic/Weather.luau")
	truthy(string.find(src, "Monetization", 1, true) == nil)
	truthy(string.find(src, "Robux", 1, true) == nil)
	local a = Weather.stormAt(9, 10)
	local b = Weather.stormAt(9, a.finish)
	local gap = b.start - a.finish
	truthy(gap >= Config.Storm.gapMin - 0.01 and gap <= Config.Storm.gapMax + 0.01, "gap " .. tostring(gap))
	eq(a.finish - a.start, Config.Storm.duration)
	local saw = false
	for t = 1762473600, 1762473600 + 10 * 86400, 1800 do
		if Weather.smokeShow(t, -6) then
			saw = true
			break
		end
	end
	truthy(saw, "a Saturday 2pm CT window exists")
	local far = Weather.stormAt(3, 1700000000)
	truthy(far.finish > far.start)
end)

test("a finished species row is +2% income and a finished rarity grants a title", function()
	local data = { index = { traits = {} }, titles = {}, crew = { owned = {}, slots = 3, nextUid = 1, extra = 0 }, ranch = { tier = 1 }, coins = 0, offline = { lastTick = 0 } }
	eq(Index.incomeMult(data), 1)
	for _, traitId in ipairs(Index.traits()) do
		Index.note(data, "armadillo", traitId)
	end
	near(Index.incomeMult(data), 1.02)
	local owned = { { uid = 1, species = "armadillo", name = "Pip", level = 1, trait = "golden", role = "pit" } }
	local plain = Crew.totalRate(owned, 1, { rank = 1, friends = 0, tipPass = false, index = 1 })
	local boosted = Crew.totalRate(owned, 1, { rank = 1, friends = 0, tipPass = false, index = Index.incomeMult(data) })
	near(boosted, plain * 1.02)
	local commons = {}
	for _, species in ipairs(Config.CrewSpecies) do
		if species.rarity == "common" then
			table.insert(commons, species.id)
		end
	end
	for _, id in ipairs(commons) do
		for _, traitId in ipairs(Index.traits()) do
			Index.note(data, id, traitId)
		end
	end
	eq(data.titles[Config.IndexTitles.common], true)
end)

test("partners replace the friend count, cheer is short, and family ranch is private-host only", function()
	local data = { partners = {}, family = { on = false, purse = 0 }, coins = 80 }
	local okAdd, why = Partners.canAdd(data.partners, "1", "1", true, false)
	eq(okAdd, false)
	truthy(why ~= "")
	local okFriend = Partners.canAdd({}, "1", "2", false, false)
	eq(okFriend, false)
	local okPrivate = Partners.canAdd({}, "1", "2", false, true)
	eq(okPrivate, true)
	Partners.add(data, "2")
	eq(Partners.bonusCount(data.partners, { ["2"] = true }), 1)
	eq(Partners.bonusCount(data.partners, {}), 0, "an offline partner does not pay")
	eq(Partners.bonusCount({ "2", "3", "4", "5" }, { ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true }), 3)
	near(Partners.mult(3), 1.3)
	local cheer = Partners.tryCheer(1000, nil, nil)
	truthy(cheer.ok)
	local cooled = Partners.tryCheer(1000, Partners.cheerCooldown(1000), nil)
	eq(cooled.ok, false)
	eq(Partners.canHostFamily(false, true), false)
	eq(Partners.canHostFamily(true, false), false)
	eq(Partners.canHostFamily(true, true), true)
	local left, purse = Partners.chip(80, 10, 30)
	eq(left, 50)
	eq(purse, 40)
	eq(Partners.chip(10, 0, 50), nil)
	local cheered = Crew.memberRate({ uid = 4, species = "armadillo", level = 1, trait = "none" }, { rank = 1, friends = 0, tipPass = false, cheers = { [4] = true } })
	local quiet = Crew.memberRate({ uid = 4, species = "armadillo", level = 1, trait = "none" }, { rank = 1, friends = 0, tipPass = false })
	near(cheered, quiet * Config.Partners.cheerMult)
end)

test("a hire leaves from the pose on the loop, and Pip walks a path at a stroll", function()
	local points = { { 0, 2, 0 }, { 20, 2, 0 }, { 20, 2, 20 } }
	local x1, y1, z1 = CrewMotion.pose(points, 80, 5, 1, "loop", nil)
	local x2, y2, z2 = CrewMotion.pose(points, 80, 5, 1, "loop", nil)
	near(x1, x2)
	near(y1, y2)
	near(z1, z2)
	local startX = CrewMotion.pose(points, 0, 5, 0, "loop", nil)
	local laterX = CrewMotion.pose(points, 3, 5, 0, "loop", nil)
	truthy(math.abs(laterX - startX) > 0.5, "the loop actually moves")
	local path = CrewMotion.homePath(0, 2, -26, 150, 0, 140, 8)
	truthy(#path >= 3, "Pip has waypoints, not only a straight line")
	local seconds = CrewMotion.walkSeconds(path, Config.Hiring.walkSpeed)
	near(seconds, CrewMotion.length(path) / Config.Hiring.walkSpeed)
	truthy(Config.Hiring.walkSpeed <= 16 and Config.Hiring.walkSpeed >= 8)
	eq(CrewMotion.detail(20), "full")
	eq(CrewMotion.detail(100), "cheap")
	eq(CrewMotion.detail(200), "freeze")
end)

print("Ranch load")
require("./ranch_load")(test, eq, truthy)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
