--!strict
--[[
	Config.luau — every piece of game balance and content lives here as plain data.
	Weekly updates should mostly be "add a row": a new meat, sauce, critter, cosmetic,
	Pitmaster Path step or season theme. No Roblox APIs are used in this file so the
	pure-logic unit tests (Lune) can load it too. Colors are hex strings.
]]

local Config = {}

Config.GAME_NAME = "Backyard Smokeout"
Config.TAGLINE = "Low and slow. Smoke it while you sleep."

-- Daily resets, streaks and the Saturday Cook-Off use Texas time (Central, fixed UTC-6).
Config.TIMEZONE_OFFSET_HOURS = -6

Config.MAX_PLOTS = 8 -- set the server size to 8 in Game Settings > Places
Config.START_COINS = 50
Config.COOLER_MAX = 40
Config.AUTOSAVE_SECONDS = 60
Config.RESTOCK_SECONDS = 300 -- sauce shop restocks every 5 minutes
Config.BURGER_BURN_GRACE = 15 -- seconds a finished burger can sit before it burns (only while you're online)
Config.PEEK_PENALTY_FRACTION = 0.10 -- "If you're lookin', you ain't cookin'"
Config.PEEK_PENALTY_MIN = 10
Config.PLAYTIME_NUDGE_MINUTES = 60
Config.CUSTOMER_SPOTS = 3
Config.CUSTOMER_SPAWN_SECONDS = 9
Config.CUSTOMER_PATIENCE = 120
Config.MATCH_ORDER_BONUS = 1.25
Config.NEW_REGULAR_REWARD = 50
Config.RESTING_IDLE_SECONDS = 120

-- Spatula flip (burgers): flip near the halfway mark. Fractions of total cook time.
Config.Flip = {
	target = 0.5,
	perfectWindow = 0.08, -- +-2.4s on a 30s burger
	goodWindow = 0.2,
	perfectMult = 1.5,
	goodMult = 1.15,
	missMult = 0.9,
	unflippedMult = 0.85,
	perfectAura = 1000, -- "+1000 Aura"
	comboStep = 0.1, -- each perfect in a row adds +10% tip (max +100%)
	comboMax = 10,
	lockedInAt = 3, -- "LOCKED IN" combo status
}

Config.Stations = { "grill", "smoker" }

export type Meat = {
	id: string,
	name: string,
	station: string,
	cookTime: number,
	cost: number,
	price: number,
	unlockPit: number,
	maxRarity: number,
	color: string,
	icon: string,
	premium: boolean?,
	season: string?,
	hidden: boolean?,
	size: { number },
}

Config.Meats = {
	burger = { id = "burger", name = "Backyard Burger", station = "grill", cookTime = 30, cost = 2, price = 12, unlockPit = 1, maxRarity = 3, color = "#8B4A2B", icon = "🍔", size = { 1.6, 0.5, 1.6 } },
	hotlink = { id = "hotlink", name = "Hot Link", station = "smoker", cookTime = 120, cost = 6, price = 30, unlockPit = 1, maxRarity = 5, color = "#9E2A2B", icon = "🌭", size = { 2.2, 0.5, 0.5 } },
	brisket = { id = "brisket", name = "Texas Brisket", station = "smoker", cookTime = 21600, cost = 300, price = 3600, unlockPit = 1, maxRarity = 5, color = "#3E2215", icon = "🥩", size = { 3, 1, 1.8 } },
	yardbird = { id = "yardbird", name = "Smoked Yardbird", station = "smoker", cookTime = 480, cost = 20, price = 110, unlockPit = 2, maxRarity = 5, color = "#C27C3A", icon = "🍗", size = { 1.6, 1, 1.4 } },
	ribs = { id = "ribs", name = "Roch & Roll Ribs", station = "smoker", cookTime = 1800, cost = 60, price = 420, unlockPit = 2, maxRarity = 5, color = "#7A2E1C", icon = "🍖", size = { 2.8, 0.5, 1.2 } },
	porkbutt = { id = "porkbutt", name = "Pork Butt", station = "smoker", cookTime = 7200, cost = 150, price = 1500, unlockPit = 3, maxRarity = 5, color = "#6B3A20", icon = "🐖", size = { 1.8, 1.4, 1.8 } },
	turkeyleg = { id = "turkeyleg", name = "Harvest Turkey Leg", station = "smoker", cookTime = 900, cost = 30, price = 260, unlockPit = 1, maxRarity = 5, color = "#A0522D", icon = "🦃", season = "harvest", size = { 1, 1, 2.2 } },
	holidayham = { id = "holidayham", name = "Holiday Glazed Ham", station = "smoker", cookTime = 1200, cost = 40, price = 340, unlockPit = 1, maxRarity = 5, color = "#B8553A", icon = "🍖", season = "holiday", size = { 1.8, 1.3, 1.6 } },
	wagyu = { id = "wagyu", name = "Wagyu Brisket", station = "smoker", cookTime = 14400, cost = 0, price = 7000, unlockPit = 1, maxRarity = 5, color = "#2B140B", icon = "🥩", premium = true, size = { 3.2, 1.1, 1.9 } },
	tomahawk = { id = "tomahawk", name = "Tomahawk Steak", station = "grill", cookTime = 300, cost = 0, price = 700, unlockPit = 1, maxRarity = 5, color = "#5A1E12", icon = "🪓", premium = true, size = { 3, 0.6, 1.4 } },
	firstbrisket = { id = "firstbrisket", name = "First Brisket", station = "smoker", cookTime = 75, cost = 0, price = 100, unlockPit = 1, maxRarity = 5, color = "#3E2215", icon = "🥩", hidden = true, size = { 3, 1, 1.8 } },
}

Config.MeatOrder = { "burger", "tomahawk", "hotlink", "yardbird", "turkeyleg", "holidayham", "ribs", "porkbutt", "brisket", "wagyu" }

-- Rarity of a finished cut. Rolled on the server when the cook starts. Odds are shown in the Index.
Config.Rarities = {
	{ id = "common", name = "Common", weight = 70, mult = 1, color = "#D6D0C6", flex = false },
	{ id = "juicy", name = "Juicy", weight = 22, mult = 1.5, color = "#5AD2FF", flex = false },
	{ id = "smokering", name = "Smoke Ring Gold", weight = 6, mult = 3, color = "#FFC83C", flex = true },
	{ id = "texas", name = "Texas-Size", weight = 1.8, mult = 6, color = "#FF5A36", flex = true },
	{ id = "meteorite", name = "Meteorite", weight = 0.2, mult = 12, color = "#9B5CFF", flex = true },
}

-- Pit levels upgrade every smoker and grill at once.
Config.PitLevels = {
	{ name = "Rusty Drum", speed = 1.0, luck = 1.0, cost = 0, color = "#6E4B3A" },
	{ name = "Rochin' the Smoker", speed = 1.25, luck = 1.1, cost = 500, color = "#3B3B3B" },
	{ name = "Big Pit", speed = 1.5, luck = 1.25, cost = 3000, color = "#2A2A2A" },
	{ name = "Pitmaster Rig", speed = 1.85, luck = 1.4, cost = 15000, color = "#1C2A3A" },
	{ name = "Golden Smokehouse", speed = 2.25, luck = 1.6, cost = 75000, color = "#D4A017" },
}

Config.Slots = {
	smoker = { base = 2, costs = { 400, 2500, 12000 }, passBonus = 2 },
	grill = { base = 2, costs = { 300, 2000 }, passBonus = 0 },
}
Config.MAX_SMOKERS = 7
Config.MAX_GRILLS = 4

-- Unc Status rebirths. `need` = coins earned this run to rebirth INTO this rank.
Config.Ranks = {
	{ name = "Lil Griller", need = 0 },
	{ name = "Big Bro", need = 100000 },
	{ name = "Unc", need = 400000, unlock = "feet_socksandals" },
	{ name = "Great Unc", need = 1500000 },
	{ name = "OG Pitmaster", need = 5000000 },
}
Config.RANK_STEP = 0.5 -- +50% income per rank, forever

-- Sauces: bought with coins (never Robux), each gives a few charges of an effect.
Config.Sauces = {
	sweetheat = { id = "sweetheat", name = "Sweet Heat", effect = "luck", amount = 0.15, charges = 3, price = 150, weight = 40, maxStock = 3, color = "#D2462E" },
	rochetfuel = { id = "rochetfuel", name = "Rochet Fuel Hot Sauce", effect = "speed", amount = 0.25, charges = 3, price = 200, weight = 30, maxStock = 3, color = "#FF5A00" },
	carolinagold = { id = "carolinagold", name = "Carolina Gold Mustard", effect = "tip", amount = 0.25, charges = 5, price = 120, weight = 30, maxStock = 3, color = "#E8B923" },
	peachfuzz = { id = "peachfuzz", name = "Peach Fuzz Glaze", effect = "tip", amount = 0.5, charges = 5, price = 600, weight = 10, maxStock = 2, color = "#FFA07A" },
	hillcountry = { id = "hillcountry", name = "Hill Country Mop", effect = "luck", amount = 0.35, charges = 3, price = 900, weight = 8, maxStock = 1, color = "#5B3A1E" },
	secretcreek = { id = "secretcreek", name = "Secret Creek Sauce", effect = "luck", amount = 0.5, charges = 5, price = 0, weight = 0, maxStock = 0, color = "#3FA7D6", hidden = true },
	burntend = { id = "burntend", name = "Burnt-End Glaze", effect = "tip", amount = 0.2, charges = 3, price = 0, weight = 0, maxStock = 0, color = "#E6B25A", hidden = true },
	straitshootin = { id = "straitshootin", name = "Strait-Shootin' Sauce", effect = "speed", amount = 0.3, charges = 3, price = 0, weight = 0, maxStock = 0, color = "#C19A6B", hidden = true },
}
Config.SauceOrder = { "sweetheat", "rochetfuel", "carolinagold", "peachfuzz", "hillcountry" }
Config.RESTOCK_SLOTS = 3

-- Daily login (7-day cycle). One free missed day per week; a longer break only drops you
-- back to the start of your current week, never to zero.
Config.DailyRewards = {
	{ coins = 100 },
	{ coins = 150 },
	{ coins = 200, sauce = "sweetheat" },
	{ coins = 300 },
	{ coins = 400, sauce = "rochetfuel" },
	{ coins = 600 },
	{ coins = 1000, sauce = "hillcountry", boostMinutes = 15 },
}

-- 28-day Pitmaster Path. Step N unlocks on your Nth play day; goals are lifetime stats.
Config.PathSteps = ({
	{ stat = "served", amount = 3, reward = { coins = 200 }, label = "Serve 3 plates" },
	{ stat = "perfectFlips", amount = 3, reward = { sauce = "sweetheat" }, label = "Land 3 perfect spatula flips" },
	{ stat = "smoked", amount = 3, reward = { cosmetic = "hat_straw" }, label = "Smoke 3 meats" },
	{ stat = "critters", amount = 3, reward = { coins = 500 }, label = "Meet 3 different regulars" },
	{ stat = "sauces", amount = 2, reward = { boostMinutes = 15 }, label = "Buy 2 sauces" },
	{ stat = "upgrades", amount = 1, reward = { coins = 800 }, label = "Upgrade your pit once" },
	{ stat = "rares", amount = 2, reward = { wagyu = 1, title = "Week 1 Pitmaster" }, label = "Cook 2 rare cuts" },
	{ stat = "served", amount = 60, reward = { coins = 1200 }, label = "Serve 60 plates" },
	{ stat = "cookoffs", amount = 1, reward = { sauce = "hillcountry" }, label = "Enter a Cook-Off" },
	{ stat = "critters", amount = 5, reward = { rex = true }, label = "Meet 5 regulars (someone special is coming...)" },
	{ stat = "perfectFlips", amount = 25, reward = { cosmetic = "trail_smokepuff" }, label = "Land 25 perfect flips" },
	{ stat = "smoked", amount = 25, reward = { coins = 2000 }, label = "Smoke 25 meats" },
	{ stat = "mosquitoes", amount = 10, reward = { boostMinutes = 30 }, label = "Swat 10 mosquitoes" },
	{ stat = "rares", amount = 6, reward = { cosmetic = "tool_goldtongs", title = "Two-Week Pitmaster" }, label = "Cook 6 rare cuts" },
	{ stat = "served", amount = 150, reward = { coins = 3000 }, label = "Serve 150 plates" },
	{ stat = "sauces", amount = 8, reward = { sauce = "peachfuzz" }, label = "Buy 8 sauces" },
	{ stat = "cookoffs", amount = 3, reward = { coins = 3500 }, label = "Enter 3 Cook-Offs" },
	{ stat = "critters", amount = 7, reward = { cosmetic = "smoke_hickory" }, label = "Meet 7 regulars" },
	{ stat = "upgrades", amount = 3, reward = { wagyu = 2 }, label = "Upgrade 3 times" },
	{ stat = "perfectFlips", amount = 60, reward = { coins = 4000 }, label = "Land 60 perfect flips" },
	{ stat = "rares", amount = 12, reward = { cosmetic = "smoke_sunset", title = "Three-Week Pitmaster" }, label = "Cook 12 rare cuts" },
	{ stat = "served", amount = 300, reward = { coins = 6000 }, label = "Serve 300 plates" },
	{ stat = "smoked", amount = 80, reward = { boostMinutes = 60 }, label = "Smoke 80 meats" },
	{ stat = "mosquitoes", amount = 40, reward = { coins = 7000 }, label = "Swat 40 mosquitoes" },
	{ stat = "cookoffs", amount = 6, reward = { cosmetic = "apron_pathfinder" }, label = "Enter 6 Cook-Offs" },
	{ stat = "critters", amount = 9, reward = { coins = 9000 }, label = "Meet 9 regulars" },
	{ stat = "rares", amount = 20, reward = { wagyu = 3 }, label = "Cook 20 rare cuts" },
	{ stat = "served", amount = 500, reward = { tomahawk = true, cosmetic = "skin_pathgold", title = "Pitmaster" }, label = "Serve 500 plates" },
} :: { any })

-- Unc Hank's Rookie List: five quick goals for a brand-new pitmaster's first five minutes, right
-- after the one-button first brisket. Each one is a lifetime stat; the client draws an arrow to
-- `target` ("grill", "tables", "smoker", "sauce", "bell"). All rewards are free.
Config.RookieSteps = ({
	{ id = "flip", stat = "flips", amount = 1, target = "grill", icon = "🍔", label = "Flip a burger on the grill", tip = "Tap FLIP! when the button turns gold for a perfect flip.", reward = { coins = 40 } },
	{ id = "serve", stat = "served", amount = 3, target = "tables", icon = "🍽️", label = "Serve 3 hungry critters", tip = "Walk up to a critter at your picnic tables, or tap Serve All.", reward = { coins = 60 } },
	{ id = "smoke", stat = "smokerStarts", amount = 1, target = "smoker", icon = "🌭", label = "Start a Hot Link in your smoker", tip = "Tap Cook on a smoker card. Hot Links are ready in 2 minutes.", reward = { coins = 80 } },
	{ id = "sauce", stat = "sauces", amount = 1, target = "sauce", icon = "🥫", label = "Grab a sauce at the Sauce Shack", tip = "Sauce gives your next few plates a boost. It restocks every 5 minutes.", reward = { coins = 100 } },
	{ id = "bell", stat = "bells", amount = 1, target = "bell", icon = "🔔", label = "Ring Big Bertha's dinner bell", tip = "She's the giant smoker in the town square. Ring it with 2 friends for bonus tips!", reward = { coins = 150 } },
} :: { any })
-- The finish reward for completing all five goals (free, earned only here, never sold). It is shown
-- on the Rookie List card from the start. Players who skip the list can bring it back from
-- Settings > Game and still earn this.
Config.RookieFinish = { coins = 250, cosmetic = "bandana_rookie", title = "Rookie of the Ranch" }
Config.ROOKIE_VETERAN_SERVES = 25 -- saves from before the list existed skip it quietly

-- Critter customers = the Regulars Index. All original characters.
Config.Critters = {
	{ id = "armadillo", name = "Dilly the Armadillo", weight = 20, tip = 1.0, body = "#9C8A7A", head = "#8A7868", scale = 1.0, ears = false },
	{ id = "roadrunner", name = "Zoom the Roadrunner", weight = 18, tip = 1.0, body = "#6B5B4B", head = "#3A6EA5", scale = 0.9, ears = false },
	{ id = "raccoon", name = "Bandit the Raccoon", weight = 16, tip = 1.1, body = "#7D7D7D", head = "#505050", scale = 1.0, ears = true },
	{ id = "possum", name = "Possum Pete", weight = 14, tip = 1.1, body = "#BEBEBE", head = "#F0E6E6", scale = 0.95, ears = true },
	{ id = "hornedtoad", name = "Spike the Horned Lizard", weight = 10, tip = 1.2, body = "#C2A36B", head = "#B08F55", scale = 0.7, ears = false },
	{ id = "longhorn", name = "Lil Longhorn", weight = 8, tip = 1.3, body = "#C46A2F", head = "#E0B080", scale = 1.3, ears = true, horns = true },
	{ id = "hummingbird", name = "Buzz the Hummingbird", weight = 7, tip = 1.3, body = "#2E8B57", head = "#C2185B", scale = 0.6, ears = false },
	{ id = "bellyrubpup", name = "Belly Rub Pup", weight = 6, tip = 1.5, body = "#E8D3B9", head = "#E8D3B9", scale = 0.9, ears = true, bellyRub = true },
	{ id = "clapcat", name = "Clapping Cat", weight = 5, tip = 1.4, body = "#151515", head = "#1E1E1E", scale = 0.85, ears = true },
	{ id = "rex", name = "Rex", weight = 0.8, tip = 3.0, body = "#6CC24A", head = "#7BD35A", scale = 1.2, ears = false, rex = true, ribbon = "RAWR means I love you ♥" },
}

-- Cosmetics. `source`: "robux" (developer product), "path", "egg", "rank", "suds", "pass", "rotation" (limited-time Robux),
-- "event" (free, earned during a date-gated event), "rookie" (free, for finishing Unc Hank's Rookie List).
Config.Cosmetics = {
	hat_pitmaster = { name = "Pitmaster Cowboy Hat", slot = "hat", source = "robux", color = "#3B2A1A" },
	hat_straw = { name = "Straw Cowboy Hat", slot = "hat", source = "path", color = "#E3C77A" },
	hat_turkey = { name = "Gobble Hat", slot = "hat", source = "rotation", color = "#8B5A2B" },
	apron_grillmaster = { name = "Grill Master Apron", slot = "apron", source = "robux", color = "#B22222", text = "GRILL MASTER" },
	apron_okayestunc = { name = "World's Okayest Unc Apron", slot = "apron", source = "egg", color = "#4A6FA5", text = "WORLD'S OKAYEST UNC" },
	apron_pathfinder = { name = "Pit Path Apron", slot = "apron", source = "path", color = "#2F4F2F", text = "28 DAYS LOW & SLOW" },
	apron_harvest = { name = "Harvest Plaid Apron", slot = "apron", source = "rotation", color = "#A0522D", text = "GIVE THANKS" },
	apron_thankful = { name = "Thankful & Full Apron", slot = "apron", source = "event", color = "#D9822B", text = "THANKFUL & FULL" },
	apron_merry = { name = "Merry & Smoky Apron", slot = "apron", source = "event", color = "#1E6B3A", text = "MERRY & SMOKY" },
	tool_goldenspatula = { name = "Golden Spatula", slot = "tool", source = "robux", color = "#FFD700" },
	tool_goldtongs = { name = "Golden Tongs", slot = "tool", source = "path", color = "#E6BE8A" },
	skin_candyred = { name = "Candy Apple Smoker", slot = "skin", source = "robux", color = "#C1121F" },
	skin_galaxy = { name = "Galaxy Smoker", slot = "skin", source = "robux", color = "#3A0CA3", neon = true },
	skin_golden = { name = "Solid Gold Smoker", slot = "skin", source = "robux", color = "#FFD700", gold = true },
	skin_pathgold = { name = "Pitmaster Bronze Smoker", slot = "skin", source = "path", color = "#CD7F32" },
	skin_snowy = { name = "Snowy Smoker", slot = "skin", source = "rotation", color = "#E8F4FF" },
	smoke_grape = { name = "Grape Soda Smoke", slot = "smoke", source = "robux", color = "#8E44AD" },
	smoke_bluebonnet = { name = "Bluebonnet Smoke", slot = "smoke", source = "robux", color = "#3B6FD8" },
	smoke_sherbet = { name = "Rainbow Sherbet Smoke", slot = "smoke", source = "robux", color = "#FF8FAB", rainbow = true },
	smoke_hickory = { name = "Hickory Gold Smoke", slot = "smoke", source = "path", color = "#D4A35A" },
	smoke_sunset = { name = "Sunset Smoke", slot = "smoke", source = "path", color = "#FF7F50" },
	smoke_pumpkin = { name = "Pumpkin Patch Smoke", slot = "smoke", source = "rotation", color = "#FF7518" },
	trail_sparkler = { name = "Sparkler Trail", slot = "trail", source = "robux", color = "#FFF3B0" },
	trail_sauce = { name = "BBQ Sauce Drip Trail", slot = "trail", source = "robux", color = "#7B1E10" },
	trail_petals = { name = "Bluebonnet Petal Trail", slot = "trail", source = "robux", color = "#4169E1" },
	trail_smokepuff = { name = "Smoke Puff Trail", slot = "trail", source = "path", color = "#BBBBBB" },
	trail_firework = { name = "Firework Trail", slot = "trail", source = "rotation", color = "#FF2E63" },
	feet_socksandals = { name = "Socks & Sandals", slot = "feet", source = "rank", color = "#FFFFFF" },
	bandana_red = { name = "Red Bandana", slot = "neck", source = "suds", color = "#C0392B" },
	bandana_blue = { name = "Blue Bandana", slot = "neck", source = "suds", color = "#2E86C1" },
	bandana_paws = { name = "Paw Print Bandana", slot = "neck", source = "suds", color = "#F5B7B1" },
	bandana_gold = { name = "Golden Bandana", slot = "neck", source = "suds", color = "#F1C40F" },
	bandana_rookie = { name = "Rookie of the Ranch Bandana", slot = "neck", source = "rookie", color = "#E8590C" },
	vip_lights = { name = "VIP Patio Lights", slot = "patio", source = "pass", color = "#FFE9A8" },
	-- Smokehouse Pass seasons (Config.SeasonPass). "seasonfree" = free track, "season" = paid track.
	s1_bandana_acorn = { name = "Acorn Bandana", slot = "neck", source = "seasonfree", color = "#8B5A2B" },
	s1_hat_hayride = { name = "Hayride Cowboy Hat", slot = "hat", source = "seasonfree", color = "#C8A165" },
	s1_trail_hayride = { name = "Hayride Trail", slot = "trail", source = "seasonfree", color = "#E3B448" },
	s1_apron_free = { name = "Season One Apron", slot = "apron", source = "seasonfree", color = "#6B8E23", text = "SEASON 1 SMOKER" },
	s1_smoke_applewood = { name = "Applewood Smoke", slot = "smoke", source = "season", color = "#E07B39" },
	s1_apron_flannel = { name = "Flannel Apron", slot = "apron", source = "season", color = "#8B1E1E", text = "FLANNEL SEASON" },
	s1_trail_ember = { name = "Ember Trail", slot = "trail", source = "season", color = "#FF6A00" },
	s1_hat_harvestmoon = { name = "Harvest Moon Hat", slot = "hat", source = "season", color = "#5C3317" },
	s1_skin_maple = { name = "Maple Smoker", slot = "skin", source = "season", color = "#B5651D" },
	s1_bandana_spice = { name = "Pumpkin Spice Bandana", slot = "neck", source = "season", color = "#E2725B" },
	s1_tool_copper = { name = "Copper Spatula", slot = "tool", source = "season", color = "#B87333" },
	s1_smoke_cider = { name = "Hot Cider Smoke", slot = "smoke", source = "season", color = "#C68E17" },
	s1_trail_moon = { name = "Harvest Moon Trail", slot = "trail", source = "season", color = "#FFC857" },
	s1_apron_boss = { name = "Harvest Boss Apron", slot = "apron", source = "season", color = "#3E2723", text = "HARVEST BOSS" },
	s1_skin_harvestgold = { name = "Harvest Gold Smoker", slot = "skin", source = "season", color = "#DAA520", gold = true },
	s2_bandana_frost = { name = "Frost Bandana", slot = "neck", source = "seasonfree", color = "#A7C7E7" },
	s2_hat_frost = { name = "Frosty Cowboy Hat", slot = "hat", source = "seasonfree", color = "#DDE7F0" },
	s2_trail_flurry = { name = "Flurry Trail", slot = "trail", source = "seasonfree", color = "#FFFFFF" },
	s2_apron_free = { name = "Season Two Apron", slot = "apron", source = "seasonfree", color = "#2E5984", text = "SEASON 2 SMOKER" },
	s2_smoke_peppermint = { name = "Peppermint Smoke", slot = "smoke", source = "season", color = "#FF4D6D" },
	s2_apron_sweater = { name = "Ugly Sweater Apron", slot = "apron", source = "season", color = "#1B5E20", text = "UGLY SWEATER" },
	s2_trail_aurora = { name = "Aurora Trail", slot = "trail", source = "season", color = "#7CFFCB" },
	s2_hat_snowcap = { name = "Snowcap Cowboy Hat", slot = "hat", source = "season", color = "#F5F5F5" },
	s2_skin_gingerbread = { name = "Gingerbread Smoker", slot = "skin", source = "season", color = "#A0522D" },
	s2_bandana_candycane = { name = "Candy Cane Bandana", slot = "neck", source = "season", color = "#E63946" },
	s2_tool_icicle = { name = "Icicle Spatula", slot = "tool", source = "season", color = "#BDE0FE", neon = true },
	s2_smoke_cocoa = { name = "Hot Cocoa Smoke", slot = "smoke", source = "season", color = "#6F4E37" },
	s2_trail_snowflake = { name = "Snowflake Trail", slot = "trail", source = "season", color = "#CFE8FF" },
	s2_apron_lodge = { name = "Lodge Apron", slot = "apron", source = "season", color = "#4E342E", text = "SMOKEHOUSE LODGE" },
	s2_skin_aurora = { name = "Aurora Smoker", slot = "skin", source = "season", color = "#5E60CE", neon = true },
	s3_bandana_rope = { name = "Lasso Rope Bandana", slot = "neck", source = "seasonfree", color = "#C9A66B" },
	s3_hat_rodeo = { name = "Rodeo Rookie Hat", slot = "hat", source = "seasonfree", color = "#A0522D" },
	s3_trail_dust = { name = "Arena Dust Trail", slot = "trail", source = "seasonfree", color = "#D2B48C" },
	s3_apron_free = { name = "Season Three Apron", slot = "apron", source = "seasonfree", color = "#7F4F24", text = "SEASON 3 SMOKER" },
	s3_smoke_mesquite = { name = "Mesquite Smoke", slot = "smoke", source = "season", color = "#9C6644" },
	s3_apron_denim = { name = "Denim Apron", slot = "apron", source = "season", color = "#3A5A8C", text = "RODEO READY" },
	s3_trail_horseshoe = { name = "Lucky Horseshoe Trail", slot = "trail", source = "season", color = "#C0C0C0" },
	s3_hat_tengallon = { name = "Big Ol' Ten-Gallon Hat", slot = "hat", source = "season", color = "#F5DEB3" },
	s3_skin_saddle = { name = "Saddle Leather Smoker", slot = "skin", source = "season", color = "#8B4513" },
	s3_bandana_paisley = { name = "Paisley Bandana", slot = "neck", source = "season", color = "#B22222" },
	s3_tool_branding = { name = "Branding Iron Spatula", slot = "tool", source = "season", color = "#FF7A1A", neon = true },
	s3_smoke_chili = { name = "Chili Cook-Off Smoke", slot = "smoke", source = "season", color = "#D62828" },
	s3_trail_lasso = { name = "Lasso Trail", slot = "trail", source = "season", color = "#E9C46A" },
	s3_apron_buckle = { name = "Big Buckle Apron", slot = "apron", source = "season", color = "#2B2118", text = "BIG BUCKLE" },
	s3_skin_silverbuckle = { name = "Silver Buckle Smoker", slot = "skin", source = "season", color = "#C0C7CE", gold = true },
	s4_bandana_bloom = { name = "Bloom Bandana", slot = "neck", source = "seasonfree", color = "#6A8FE8" },
	s4_hat_straw = { name = "Spring Straw Hat", slot = "hat", source = "seasonfree", color = "#E8D28A" },
	s4_trail_petal = { name = "Spring Petal Trail", slot = "trail", source = "seasonfree", color = "#FFB7C5" },
	s4_apron_free = { name = "Season Four Apron", slot = "apron", source = "seasonfree", color = "#3D6FE0", text = "SEASON 4 SMOKER" },
	s4_smoke_honey = { name = "Wildflower Honey Smoke", slot = "smoke", source = "season", color = "#F2B134" },
	s4_apron_gingham = { name = "Picnic Gingham Apron", slot = "apron", source = "season", color = "#E63946", text = "PICNIC PRO" },
	s4_trail_butterfly = { name = "Butterfly Trail", slot = "trail", source = "season", color = "#FF8C42" },
	s4_hat_bluebonnet = { name = "Bluebonnet Band Hat", slot = "hat", source = "season", color = "#F1E3C3" },
	s4_skin_peach = { name = "Hill Country Peach Smoker", slot = "skin", source = "season", color = "#FFB07C" },
	s4_bandana_paintbrush = { name = "Paintbrush Bandana", slot = "neck", source = "season", color = "#FF5A3C" },
	s4_tool_garden = { name = "Garden Trowel Spatula", slot = "tool", source = "season", color = "#5FAD56" },
	s4_smoke_rain = { name = "Spring Shower Smoke", slot = "smoke", source = "season", color = "#9AD1F5" },
	s4_trail_rainbow = { name = "After-the-Rain Trail", slot = "trail", source = "season", color = "#7CFFB2" },
	s4_apron_wildflower = { name = "Wildflower Apron", slot = "apron", source = "season", color = "#5B3E96", text = "WILDFLOWER" },
	s4_skin_bluebonnet = { name = "Bluebonnet Smoker", slot = "skin", source = "season", color = "#3D6FE0", neon = true },
	-- Turkey Day look set (Robux, only on sale during the Turkey Day Smokeout; the free apron stays free)
	td_hat_cornucopia = { name = "Cornucopia Cowboy Hat", slot = "hat", source = "eventshop", color = "#8B4513" },
	td_smoke_cranberry = { name = "Cranberry Smoke", slot = "smoke", source = "eventshop", color = "#9B1B30" },
	td_trail_leaves = { name = "Falling Leaves Trail", slot = "trail", source = "eventshop", color = "#D2691E" },
	td_skin_pecan = { name = "Pecan Pie Smoker", slot = "skin", source = "eventshop", color = "#7B4B2A" },
	-- Holiday look set (Robux, only on sale during the Holiday Smokeout; the free apron stays free)
	hd_hat_twinkle = { name = "Twinkle Lights Cowboy Hat", slot = "hat", source = "eventshop", color = "#1F4D2B", twinkle = true },
	hd_smoke_evergreen = { name = "Evergreen Smoke", slot = "smoke", source = "eventshop", color = "#2E8B57" },
	hd_trail_tinsel = { name = "Tinsel Trail", slot = "trail", source = "eventshop", color = "#FFD54A", color2 = "#E8EEF5" },
	hd_skin_ornament = { name = "Ornament Smoker", slot = "skin", source = "eventshop", color = "#B3122E", gold = true },
	-- Pit Crew Club (Roblox subscription): one members' look each month, kept forever
	club_apron = { name = "Pit Crew Apron", slot = "apron", source = "club", color = "#1D3557", text = "PIT CREW" },
	club_hat = { name = "Pit Crew Hat", slot = "hat", source = "club", color = "#264653" },
	club_trail = { name = "Pit Crew Trail", slot = "trail", source = "club", color = "#E9C46A" },
	club_smoke = { name = "Pit Crew Smoke", slot = "smoke", source = "club", color = "#F4A261" },
	club_skin = { name = "Pit Crew Smoker", slot = "skin", source = "club", color = "#2A9D8F" },
	club_bandana = { name = "Pit Crew Bandana", slot = "neck", source = "club", color = "#E76F51" },
	-- Roblox Premium members get this free (Premium Payouts reward time played by members)
	premium_bandana = { name = "Premium Pitmaster Bandana", slot = "neck", source = "premium", color = "#E2B714" },
	-- First-time Pit Pack (one per account)
	starter_hat = { name = "Rookie Pitmaster Hat", slot = "hat", source = "starter", color = "#E8590C" },
}
Config.CosmeticSlots = { "hat", "apron", "tool", "neck", "feet", "trail", "skin", "smoke", "patio" }

-- Suds Saturday & Sunday: wash a muddy pup for a free bandana. Odds shown in game.
Config.Bandanas = {
	{ id = "bandana_red", weight = 50 },
	{ id = "bandana_blue", weight = 30 },
	{ id = "bandana_paws", weight = 15 },
	{ id = "bandana_gold", weight = 5 },
}
Config.SUDS_PUP_CHANCE = 0.35

-- Limited-time cosmetics rotate weekly (2 at a time) and always come back in a later rotation.
Config.RotationPool = { "Rot_ApronHarvest", "Rot_SkinSnowy", "Rot_SmokePumpkin", "Rot_TrailFirework", "Rot_HatTurkey" }
Config.ROTATION_FEATURED = 2

-- Saturday Cook-Off. Judges rate W / Mid / L / Cooked (Cooked is the best: it's BBQ).
Config.CookOff = {
	ratings = {
		{ id = "L", min = 0, coins = 50, aura = 0, line = "Bless your heart, sugar." },
		{ id = "Mid", min = 35, coins = 150, aura = 100, line = "It's... food. Mid." },
		{ id = "W", min = 55, coins = 400, aura = 300, line = "Now THAT's a W plate!" },
		{ id = "Cooked", min = 75, coins = 1200, aura = 1000, line = "You COOKED. The cat is clapping." },
	},
	saturdayMult = 3, -- practice rounds on other days pay 1x; Saturdays pay 3x + leaderboard
	cooldown = 60,
}

-- Mosquito swarm at dusk (co-op).
Config.Mosquito = { baseCount = 6, perPlayer = 2, hp = 2, queenHp = 25, duration = 90, rewardPerPit = 120, aura = 250 }
Config.DAY_LENGTH_MINUTES = 20

-- Plate snagging ("you got taxed"). Only from ONLINE players, never rare cuts, with lock timers.
Config.Snag = {
	cooldown = 120, -- per snagger
	victimLock = 180, -- victim's pass window is locked after a snag
	newPlayerShield = 300, -- first 5 minutes of a session are protected
	insurance = 0.25, -- victim gets 25% of the plate value back right away
	catchWindow = 15, -- tag the snagger within 15s to get it back (+ bonus)
	catchDistance = 7,
	catchBonus = 50,
	maxRarityIndex = 2, -- only Common and Juicy plates can be snagged
}

Config.Crew = { perFriend = 0.10, maxFriends = 3 }

-- Fair Play: paid perks are capped so they never wall off free players.
--   * the tip pass is +50% (not x2) and never applies to the Cook-Off or snagging
--   * buying a speed boost gives everyone else in the server a free "Smoke Shower"
--   * snagging is opt-in: new players start in Peace Mode
-- Gifting: buy a look for someone in your server (Logic/Gifting). Looks only, never boosts or passes.
Config.Gifting = { ttlSeconds = 180, firstGiftTitle = "Good Neighbor" }

-- Smokehouse Pass: a 6-week season with a free track and a paid track. Rewards are looks and
-- titles only (never coins, cuts, boosts or anything that helps in the Cook-Off). Season XP is
-- worked out from what you already do (serving, cooking, flips, Cook-Offs, bells, a daily visit),
-- so there's nothing extra to grind. Tier skips are honest shortcuts: one tier = tierXP.
local function L(id: string): any
	return { cosmetic = id }
end
local function Ti(t: string): any
	return { title = t }
end
Config.SeasonPass = {
	epochDay = 20759, -- Monday Nov 2, 2026 (Texas day number); season n starts epochDay + (n-1) * lengthDays
	lengthDays = 42,
	tierXP = 400,
	dailyXP = 40, -- first visit each Texas day
	xp = { served = 2, cooks = 4, smoked = 6, perfectFlips = 1, cookoffs = 25, bells = 10 },
	seasons = {
		{
			id = "s1",
			name = "Harvest Smoke",
			icon = "🍂",
			free = { [3] = L("s1_bandana_acorn"), [6] = Ti("Harvest Helper"), [9] = L("s1_hat_hayride"), [12] = L("s1_trail_hayride"), [15] = L("s1_apron_free") },
			paid = {
				L("s1_smoke_applewood"), Ti("Low & Slow"), L("s1_apron_flannel"), L("s1_trail_ember"), L("s1_hat_harvestmoon"),
				Ti("Smoke Season"), L("s1_skin_maple"), L("s1_bandana_spice"), L("s1_tool_copper"), Ti("Bark Boss"),
				L("s1_smoke_cider"), L("s1_trail_moon"), L("s1_apron_boss"), Ti("Hickory Hero"), L("s1_skin_harvestgold"),
			},
		},
		{
			id = "s2",
			name = "Winter Smoke",
			icon = "❄️",
			free = { [3] = L("s2_bandana_frost"), [6] = Ti("Snow Day Smoker"), [9] = L("s2_hat_frost"), [12] = L("s2_trail_flurry"), [15] = L("s2_apron_free") },
			paid = {
				L("s2_smoke_peppermint"), Ti("Cold Smoke"), L("s2_apron_sweater"), L("s2_trail_aurora"), L("s2_hat_snowcap"),
				Ti("Hot Cocoa Hand"), L("s2_skin_gingerbread"), L("s2_bandana_candycane"), L("s2_tool_icicle"), Ti("Frosty Flipper"),
				L("s2_smoke_cocoa"), L("s2_trail_snowflake"), L("s2_apron_lodge"), Ti("Winter Pitmaster"), L("s2_skin_aurora"),
			},
		},
		{
			id = "s3",
			name = "Rodeo Smoke",
			icon = "🤠",
			free = { [3] = L("s3_bandana_rope"), [6] = Ti("Rodeo Rookie"), [9] = L("s3_hat_rodeo"), [12] = L("s3_trail_dust"), [15] = L("s3_apron_free") },
			paid = {
				L("s3_smoke_mesquite"), Ti("Saddle Up"), L("s3_apron_denim"), L("s3_trail_horseshoe"), L("s3_hat_tengallon"),
				Ti("Chuckwagon Cook"), L("s3_skin_saddle"), L("s3_bandana_paisley"), L("s3_tool_branding"), Ti("Brisket Wrangler"),
				L("s3_smoke_chili"), L("s3_trail_lasso"), L("s3_apron_buckle"), Ti("Rodeo Pitmaster"), L("s3_skin_silverbuckle"),
			},
		},
		{
			id = "s4",
			name = "Bluebonnet Smoke",
			icon = "🌼",
			free = { [3] = L("s4_bandana_bloom"), [6] = Ti("Spring Chicken"), [9] = L("s4_hat_straw"), [12] = L("s4_trail_petal"), [15] = L("s4_apron_free") },
			paid = {
				L("s4_smoke_honey"), Ti("Picnic Pro"), L("s4_apron_gingham"), L("s4_trail_butterfly"), L("s4_hat_bluebonnet"),
				Ti("Hill Country Hand"), L("s4_skin_peach"), L("s4_bandana_paintbrush"), L("s4_tool_garden"), Ti("Fresh Bloom"),
				L("s4_smoke_rain"), L("s4_trail_rainbow"), L("s4_apron_wildflower"), Ti("Bluebonnet Boss"), L("s4_skin_bluebonnet"),
			},
		},
	},
}

-- Pit Crew Club (Roblox subscription, monthly). Perks are looks and a friendly server-wide
-- Smoke Shower, never coins or Cook-Off help. Members keep every monthly look they got.
Config.Club = {
	looks = { "club_apron", "club_hat", "club_trail", "club_smoke", "club_skin", "club_bandana" },
	title = "Pit Crew",
	monthlyTierSkips = 1, -- one free Smokehouse Pass tier each month you're a member
	showerMinutes = 5, -- the once-a-day Pit Crew Smoke Shower for everyone in the server
}

-- Roblox Premium: a free look for members. No coins, no stats.
Config.Premium = { look = "premium_bandana" }

-- Private servers (price is set on the Creator Dashboard, see PUBLISHING.md). The owner gets a
-- "Host" tag and can share a Smoke Shower with everyone in their server every 10 minutes.
-- Cook speed only; the Cook-Off and snagging aren't touched.
Config.PrivateServer = { hostShowerCooldown = 600, hostTitle = "Ranch Host" }
Config.FairPlay = { passTipMult = 1.5, passTipCap = 1.5, showerMinutes = 5, showerMult = 1.25 }

-- Big Bertha's Dinner Bell: 3 different players ring the bell within 20 s, and the whole server
-- gets +25% tips for 5 minutes (free, with a 10 minute cooldown).
Config.DinnerBell = { window = 20, need = 3, cooldown = 600, minutes = 5, tipBonus = 0.25 }

-- Lunch Rush: every 150 s window, serve 4 plates for +50% of what those plates earned.
Config.Rush = { period = 150, need = 4, bonusFrac = 0.5 }

-- Turkey Day Smokeout: Thanksgiving week (Mon-Sun around the 4th Thursday of November, Texas time).
-- Smoke a Harvest Turkey Leg and share it at the potluck table: once a day you get coins, and the first
-- share ever earns the free Thankful & Full Apron. When `need` different pitmasters share within
-- `window` seconds the table is full and the whole server gets +25% tips (free, like the Dinner Bell).
-- Nothing here is paid. In Studio, set the workspace attribute ForceTurkeyDay = true to test it any day.
Config.TurkeyDay = {
	id = "turkeyday",
	dailyKey = "turkeyDay", -- data.daily field for the once-a-day share
	daysBefore = 3,
	daysAfter = 3,
	meat = "turkeyleg",
	reward = "apron_thankful",
	title = "Thankful",
	shareMult = 2, -- coins = turkey leg price x2 x rank bonus, once per day
	need = 3,
	window = 600,
	cooldown = 900,
	minutes = 5,
	tipBonus = 0.25,
}

-- Holiday Smokeout: Christmas through New Year's Day (Dec 19 - Jan 1, Texas time). Same potluck
-- table as Turkey Day, dressed for Christmas: smoke a Holiday Glazed Ham (a winter cut, Dec-Jan) and
-- share it once a day for coins; the first share ever earns the free Merry & Smoky Apron. When `need`
-- pitmasters share within `window` seconds, everyone gets +25% tips. Nothing here is paid; the
-- Holiday look set is sold separately and only during these dates (Monetization, event = "holiday").
-- In Studio, set the workspace attribute ForceHolidaySmokeout = true to test it any day.
Config.HolidaySmokeout = {
	id = "holiday",
	dailyKey = "holidayDay",
	start = { 12, 19 }, -- month, day
	finish = { 1, 1 }, -- runs into the next year
	peak = { 12, 25 },
	meat = "holidayham",
	reward = "apron_merry",
	title = "Merry & Smoky",
	shareMult = 2,
	need = 3,
	window = 600,
	cooldown = 900,
	minutes = 5,
	tipBonus = 0.25,
}

-- Season themes: the Cook-Off template reskins by month.
Config.Seasons = {
	{ months = { 10 }, id = "spooky", name = "Spooky Smoke-Off", color = "#FF7518" },
	{ months = { 11 }, id = "harvest", name = "Harvest Smoke-Off", color = "#C46A2F" },
	{ months = { 12, 1 }, id = "holiday", name = "Holiday Ham Jam", color = "#C0392B" },
	{ months = { 2, 3, 4, 5 }, id = "bluebonnet", name = "Bluebonnet Bash", color = "#3B6FD8" },
	{ months = { 6, 7, 8, 9 }, id = "summer", name = "Summer Sizzle", color = "#F4D03F" },
}

return Config
