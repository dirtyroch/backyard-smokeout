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
local Gifting = require("../src/shared/Logic/Gifting")
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
	truthy(string.format(C.progress, 1, TD.need, TD.need - 1) ~= "")
	truthy(string.format(C.full, 3, 25, 5) ~= "")
	truthy(Content.Signs.turkeyPotluck and Content.Signs.turkeyBanner)
	for _, line in ipairs({ C.login, C.needDish, C.already, C.firstShare, C.share, C.over, Content.Signs.turkeyBanner }) do
		local low = string.lower(line)
		truthy(not string.find(low, "pilgrim", 1, true) and not string.find(low, "buy", 1, true) and not string.find(low, "robux", 1, true), "no pressure or loaded copy: " .. line)
	end
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
		truthy(string.format(C.progress, 1, 3, 2) ~= "" and string.format(C.full, 3, 25, 5) ~= "")
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


print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
