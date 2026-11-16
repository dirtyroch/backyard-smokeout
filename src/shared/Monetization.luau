--!strict
--[[
	Monetization.luau — THE ONE PLACE FOR ROBUX IDS.

	FASTEST: `lune run scripts/create-shop <universeId> --apply` with an Open Cloud key creates every
	pass and product below (with its icon from marketing/shop-icons/) and fills in the IDs for you.

	HOW TO FILL THIS IN BY HAND (no coding needed, see PUBLISHING.md for screenshots-level steps):
	  1. Publish the game once (File > Publish to Roblox).
	  2. Go to https://create.roblox.com/dashboard/creations, click the game.
	  3. Monetization > Passes > "Create a Pass" for every entry in `Passes` below.
	     Use the name, description and price shown here. Copy its ID (the number in the
	     pass's URL or the "Copy Asset ID" menu) and paste it over the 0.
	  4. Monetization > Developer Products > "Create a Developer Product" for every entry
	     in `Products`. Same idea: paste each product ID over the 0.
	  5. Save this file, then File > Publish to Roblox again.

	Anything left at 0 is simply hidden from the shop in the live game (you can launch with
	just a few items). In Studio play-testing, 0-ID items show a "Studio test" button that
	grants the item for free so you can try it.

	Rules we follow (Roblox monetization + "promoting to younger audiences" guidance):
	  * No paid random items at all (no loot boxes); every purchase shows exactly what you get.
	  * Robux never buys coins, so free-play odds (rarities, restocks, bandanas) are never "paid random".
	  * Calm shop copy: "See item", "Buy for R$ X". No "LAST CHANCE", no countdowns on Robux items.
	  * Every advantage you can buy (speed, slots, premium cuts) can also be earned by playing.
	  * Paid perks never affect the Cook-Off leaderboard or plate snagging.
	  * Fair Play caps (Config.FairPlay): the tip pass is +50% (not x2), and buying a speed boost
	    gives everyone else in the server a free 5-minute Smoke Shower.
	  * The Smokehouse Pass, tier skips, the Pit Crew Club and Premium give looks and titles only.
	  * Event looks (the Turkey Day and Holiday sets) go on sale only during the event week and come back the next
	    year. The free event reward always stays free. Dates are shown plainly, never as a timer.
	  * Roblox PolicyService decides who sees the subscription (IsEligibleToPurchaseSubscription).
]]

export type Pass = { id: number, name: string, price: number, desc: string, icon: string }
export type Product = {
	id: number,
	name: string,
	price: number,
	desc: string,
	icon: string,
	kind: string, -- "boost" | "finish" | "cosmetic" | "bundle" | "cut" | "starter" | "season" | "tierskip"
	category: string, -- shop tab
	minutes: number?,
	mult: number?,
	grants: { string }?,
	cut: string?,
	count: number?,
	valueNote: string?,
	rotation: boolean?,
	event: string?, -- "turkeyday" | "holiday": only on sale during that event's window
	once: boolean?, -- one per account (the first-time Pit Pack)
}

export type Subscription = { id: string, name: string, price: number, priceText: string, icon: string, desc: string, perks: { string } }

local Monetization = {}

-- GAME PASSES (bought once, kept forever)
Monetization.Passes = {
	ExtraSmokers = { id = 0, name = "Extra Smoker Slots", price = 249, icon = "🔥", desc = "+2 smoker slots on your ranch, forever." },
	AutoServe = { id = 0, name = "Possum Pete Waiter", price = 299, icon = "🦝", desc = "Possum Pete serves your waiting customers for you while you're in the game." },
	DoubleTips = { id = 0, name = "Big Tipper", price = 299, icon = "💰", desc = "Every plate you serve earns +50% coins, forever. Capped for Fair Play; does not affect the Cook-Off or snagging." },
	PremiumCuts = { id = 0, name = "Premium Cuts", price = 349, icon = "🥩", desc = "Cook Wagyu Brisket and Tomahawk Steaks any time. (Both can also be earned on the Pitmaster Path.)" },
	VIPPatio = { id = 0, name = "VIP Patio", price = 149, icon = "✨", desc = "String lights over your ranch, a VIP sign and a gold name tag. Looks only." },
} :: { [string]: Pass }

-- DEVELOPER PRODUCTS (can be bought more than once; cosmetics are saved forever once bought)
Monetization.Products = {
	-- Boosts (advantage)
	Boost30 = { id = 0, name = "Smoke Speed x2 (30 min)", price = 49, icon = "⏩", kind = "boost", category = "Boosts", minutes = 30, mult = 2, desc = "Everything on your smokers and grill cooks twice as fast for 30 minutes, even while you're offline." },
	Boost120 = { id = 0, name = "Smoke Speed x2 (2 hours)", price = 149, icon = "⏩", kind = "boost", category = "Boosts", minutes = 120, mult = 2, desc = "Twice as fast for 2 hours, online or offline." },
	FinishSmokers = { id = 0, name = "Finish All Smokers", price = 39, icon = "✅", kind = "finish", category = "Boosts", desc = "Everything currently cooking finishes instantly. The rarity is already set and doesn't change." },
	WagyuPack = { id = 0, name = "Wagyu Brisket x3", price = 79, icon = "🥩", kind = "cut", category = "Boosts", cut = "wagyu", count = 3, desc = "3 Wagyu Briskets to smoke. Each sells for about 2x a regular brisket and smokes in 4 hours instead of 6." },
	TomahawkPack = { id = 0, name = "Tomahawk Steak x3", price = 59, icon = "🪓", kind = "cut", category = "Boosts", cut = "tomahawk", count = 3, desc = "3 Tomahawk Steaks for the grill (5 minute cook)." },

	-- Cosmetics (looks only)
	ApronGrillMaster = { id = 0, name = "Grill Master Apron", price = 75, icon = "🦺", kind = "cosmetic", category = "Fits", grants = { "apron_grillmaster" }, desc = "The classic. Red apron, big GRILL MASTER letters." },
	GoldenSpatula = { id = 0, name = "Golden Spatula", price = 149, icon = "🥄", kind = "cosmetic", category = "Fits", grants = { "tool_goldenspatula" }, desc = "A solid-gold spatula that sparkles in your hand." },
	HatPitmaster = { id = 0, name = "Pitmaster Cowboy Hat", price = 99, icon = "🤠", kind = "cosmetic", category = "Fits", grants = { "hat_pitmaster" }, desc = "A wide-brim cowboy hat fit for the King of the Pit." },
	SkinCandyRed = { id = 0, name = "Candy Apple Smoker", price = 99, icon = "🍎", kind = "cosmetic", category = "Smokers", grants = { "skin_candyred" }, desc = "Glossy candy-apple red paint on all your smokers." },
	SkinGalaxy = { id = 0, name = "Galaxy Smoker", price = 149, icon = "🌌", kind = "cosmetic", category = "Smokers", grants = { "skin_galaxy" }, desc = "Glowing deep-space purple smokers." },
	SkinGolden = { id = 0, name = "Solid Gold Smoker", price = 249, icon = "🏆", kind = "cosmetic", category = "Smokers", grants = { "skin_golden" }, desc = "Shiny gold smokers. Pure flex, zero stats." },
	SmokeGrape = { id = 0, name = "Grape Soda Smoke", price = 49, icon = "🟣", kind = "cosmetic", category = "Smoke", grants = { "smoke_grape" }, desc = "Your smoke (and smoke signals) puff purple." },
	SmokeBluebonnet = { id = 0, name = "Bluebonnet Smoke", price = 49, icon = "🔵", kind = "cosmetic", category = "Smoke", grants = { "smoke_bluebonnet" }, desc = "Texas-bluebonnet blue smoke." },
	SmokeSherbet = { id = 0, name = "Rainbow Sherbet Smoke", price = 79, icon = "🌈", kind = "cosmetic", category = "Smoke", grants = { "smoke_sherbet" }, desc = "Smoke that cycles through sherbet colors." },
	TrailSparkler = { id = 0, name = "Sparkler Trail", price = 79, icon = "🎇", kind = "cosmetic", category = "Trails", grants = { "trail_sparkler" }, desc = "Leave a sparkler streak behind you." },
	TrailSauce = { id = 0, name = "BBQ Sauce Drip Trail", price = 79, icon = "🥫", kind = "cosmetic", category = "Trails", grants = { "trail_sauce" }, desc = "A saucy drip trail. Napkins not included." },
	TrailPetals = { id = 0, name = "Bluebonnet Petal Trail", price = 79, icon = "💠", kind = "cosmetic", category = "Trails", grants = { "trail_petals" }, desc = "Blue petals follow you around." },

	-- Bundles (prices shown honestly vs buying separately)
	BundleStarter = { id = 0, name = "Pitmaster Starter Bundle", price = 199, icon = "🎁", kind = "bundle", category = "Bundles", grants = { "apron_grillmaster", "hat_pitmaster" }, minutes = 30, mult = 2, valueNote = "R$ 223 if bought separately", desc = "Grill Master Apron, Pitmaster Cowboy Hat and a 30-minute x2 speed boost." },
	BundleGoldRush = { id = 0, name = "Gold Rush Bundle", price = 349, icon = "💛", kind = "bundle", category = "Bundles", grants = { "tool_goldenspatula", "skin_golden" }, valueNote = "R$ 398 if bought separately", desc = "Golden Spatula and Solid Gold Smoker skin." },
	BundleWholeHog = { id = 0, name = "Whole Hog Collection", price = 499, icon = "🐖", kind = "bundle", category = "Bundles", grants = { "skin_golden", "tool_goldenspatula", "hat_pitmaster", "apron_grillmaster", "smoke_sherbet", "trail_sparkler" }, valueNote = "R$ 730 separately. Costs less as a set.", desc = "Six looks, including the Solid Gold Smoker, Golden Spatula and Sparkler Trail." },
	-- First-time Pit Pack: one per account, shown first in Bundles until you've bought anything.
	StarterPitPack = { id = 0, name = "First-Time Pit Pack", price = 49, icon = "🧢", kind = "starter", category = "Bundles", once = true, grants = { "starter_hat" }, minutes = 30, mult = 2, cut = "tomahawk", count = 3, valueNote = "R$ 108 of boost and steaks, plus a hat only found here", desc = "One per account: Rookie Pitmaster Hat, a 30-minute x2 speed boost and 3 Tomahawk Steaks." },

	-- Turkey Day look set (on sale only during the Turkey Day Smokeout, back next year; the free
	-- Thankful & Full Apron stays free for everyone who shares a dish)
	TD_HatCornucopia = { id = 0, name = "Cornucopia Cowboy Hat", price = 79, icon = "🌽", kind = "cosmetic", category = "Turkey Day", event = "turkeyday", grants = { "td_hat_cornucopia" }, desc = "A harvest-brown hat with a corn-gold band." },
	TD_SmokeCranberry = { id = 0, name = "Cranberry Smoke", price = 49, icon = "🫐", kind = "cosmetic", category = "Turkey Day", event = "turkeyday", grants = { "td_smoke_cranberry" }, desc = "Deep cranberry-red smoke." },
	TD_TrailLeaves = { id = 0, name = "Falling Leaves Trail", price = 79, icon = "🍁", kind = "cosmetic", category = "Turkey Day", event = "turkeyday", grants = { "td_trail_leaves" }, desc = "Autumn leaves drift behind you." },
	TD_SkinPecan = { id = 0, name = "Pecan Pie Smoker", price = 99, icon = "🥧", kind = "cosmetic", category = "Turkey Day", event = "turkeyday", grants = { "td_skin_pecan" }, desc = "Toasty pecan-brown smokers." },
	TD_BundleFeast = { id = 0, name = "Turkey Day Look Set", price = 229, icon = "🦃", kind = "bundle", category = "Turkey Day", event = "turkeyday", grants = { "td_hat_cornucopia", "td_smoke_cranberry", "td_trail_leaves", "td_skin_pecan" }, valueNote = "R$ 306 if bought separately", desc = "All four Turkey Day looks: hat, smoke, trail and smoker." },

	-- Holiday look set (on sale only during the Holiday Smokeout, Dec 19 - Jan 1, back next year;
	-- the Merry & Smoky Apron stays free for everyone who shares a dish)
	HD_HatTwinkle = { id = 0, name = "Twinkle Lights Cowboy Hat", price = 79, icon = "🎄", kind = "cosmetic", category = "Holiday", event = "holiday", grants = { "hd_hat_twinkle" }, desc = "An evergreen cowboy hat with a band of glowing colored lights." },
	HD_SmokeEvergreen = { id = 0, name = "Evergreen Smoke", price = 49, icon = "🌲", kind = "cosmetic", category = "Holiday", event = "holiday", grants = { "hd_smoke_evergreen" }, desc = "Pine-green smoke from every smoker." },
	HD_TrailTinsel = { id = 0, name = "Tinsel Trail", price = 79, icon = "✨", kind = "cosmetic", category = "Holiday", event = "holiday", grants = { "hd_trail_tinsel" }, desc = "A gold-and-silver tinsel shimmer behind you." },
	HD_SkinOrnament = { id = 0, name = "Ornament Smoker", price = 99, icon = "🔴", kind = "cosmetic", category = "Holiday", event = "holiday", grants = { "hd_skin_ornament" }, desc = "Shiny ornament-red smokers that catch the light." },
	HD_BundleHoliday = { id = 0, name = "Holiday Look Set", price = 229, icon = "🎁", kind = "bundle", category = "Holiday", event = "holiday", grants = { "hd_hat_twinkle", "hd_smoke_evergreen", "hd_trail_tinsel", "hd_skin_ornament" }, valueNote = "R$ 306 if bought separately", desc = "All four Holiday looks: hat, smoke, trail and smoker." },

	-- Smokehouse Pass (one per season; looks and titles only) and tier skips
	SeasonPass = { id = 0, name = "Smokehouse Pass", price = 399, icon = "🎟️", kind = "season", category = "Season", desc = "Unlocks this season's paid track: a look or title at every tier. Every paid reward you've already reached is yours right away." },
	TierSkip1 = { id = 0, name = "Skip 1 Tier", price = 49, icon = "⏭️", kind = "tierskip", category = "Season", count = 1, desc = "Move up one Smokehouse Pass tier. Looks and titles only." },
	TierSkip5 = { id = 0, name = "Skip 5 Tiers", price = 199, icon = "⏭️", kind = "tierskip", category = "Season", count = 5, valueNote = "R$ 245 as five single skips", desc = "Move up five Smokehouse Pass tiers. Looks and titles only." },

	-- Weekly rotation (limited-time looks; every one comes back in a later rotation)
	Rot_ApronHarvest = { id = 0, name = "Harvest Plaid Apron", price = 75, icon = "🍂", kind = "cosmetic", category = "This Week", grants = { "apron_harvest" }, rotation = true, desc = "Cozy plaid apron for the Harvest season." },
	Rot_SkinSnowy = { id = 0, name = "Snowy Smoker", price = 99, icon = "❄️", kind = "cosmetic", category = "This Week", grants = { "skin_snowy" }, rotation = true, desc = "Frosty white smokers." },
	Rot_SmokePumpkin = { id = 0, name = "Pumpkin Patch Smoke", price = 49, icon = "🎃", kind = "cosmetic", category = "This Week", grants = { "smoke_pumpkin" }, rotation = true, desc = "Pumpkin-orange smoke." },
	Rot_TrailFirework = { id = 0, name = "Firework Trail", price = 99, icon = "🎆", kind = "cosmetic", category = "This Week", grants = { "trail_firework" }, rotation = true, desc = "A celebratory firework streak." },
	Rot_HatTurkey = { id = 0, name = "Gobble Hat", price = 59, icon = "🦃", kind = "cosmetic", category = "This Week", grants = { "hat_turkey" }, rotation = true, desc = "A silly turkey hat. Gobble gobble." },
} :: { [string]: Product }

-- ROBLOX SUBSCRIPTION (Creator Dashboard > Monetization > Subscriptions). The ID is a string
-- like "EXP-1234567890". Leave "" to hide it. Shown only to players Roblox says can subscribe.
Monetization.Subscriptions = {
	PitCrewClub = {
		id = "",
		name = "Pit Crew Club",
		price = 4.99,
		priceText = "$4.99 a month, shown in your local price at checkout. Cancel any time in Roblox settings.",
		icon = "🔧",
		desc = "A monthly members' club for the ranch. Looks and friendly perks only, no coins.",
		perks = {
			"A new Pit Crew look every month you're a member, yours to keep",
			"A Pit Crew tag over your name",
			"Share a free Smoke Shower with your whole server once a day",
			"One free Smokehouse Pass tier every month",
		},
	},
} :: { [string]: Subscription }

-- ROBLOX PREMIUM: members get Config.Premium.look free. The game earns Premium Payouts from
-- the time Premium members spend playing (no setup needed).
Monetization.Premium = { name = "Roblox Premium", icon = "⭐", desc = "Premium members get the Premium Pitmaster Bandana free. Looks only." }

-- PRIVATE SERVERS: set this price on the Creator Dashboard (see PUBLISHING.md section 6c).
Monetization.PrivateServer = { price = 100, desc = "Your own ranch server for you and your friends, R$ 100 a month. The host gets a Ranch Host tag and can share a Smoke Shower every 10 minutes." }

-- Optional badges (Creator Dashboard > Associated Items > Badges). 0 = skip.
Monetization.Badges = {
	BlessedPlate = 0, -- found the little "Jesus loves you" figure
	FirstRare = 0,
	MetRex = 0,
	SecretCreek = 0,
	Cooked = 0, -- got a "Cooked" rating at a Cook-Off
}

Monetization.ShopTabs = { "This Week", "Bundles", "Fits", "Smokers", "Smoke", "Trails", "Boosts", "Passes" }

return Monetization
