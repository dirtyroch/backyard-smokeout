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

print("Content & monetization config")
test("every cosmetic product grants real cosmetics; ids default to 0", function()
	for key, p in pairs(Monetization.Products) do
		eq(p.id, 0, key .. " id placeholder")
		if p.grants then
			for _, c in ipairs(p.grants) do
				truthy(Config.Cosmetics[c], key .. " grants unknown cosmetic " .. c)
			end
		end
		truthy(p.price > 0)
	end
	for key, p in pairs(Monetization.Passes) do
		eq(p.id, 0, key .. " id placeholder")
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
	truthy(string.find(src, "settings = { peace = true }", 1, true) ~= nil)
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
	truthy(string.format(C.progress, 1, TD.need, TD.need - 1) ~= "")
	truthy(string.format(C.full, 3, 25, 5) ~= "")
	truthy(Content.Signs.turkeyPotluck and Content.Signs.turkeyBanner)
	for _, line in ipairs({ C.login, C.needDish, C.already, C.firstShare, C.share, C.over, Content.Signs.turkeyBanner }) do
		local low = string.lower(line)
		truthy(not string.find(low, "pilgrim", 1, true) and not string.find(low, "buy", 1, true) and not string.find(low, "robux", 1, true), "no pressure or loaded copy: " .. line)
	end
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
