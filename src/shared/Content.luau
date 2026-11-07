--!strict
-- Content.luau — all jokes, NPC lines and swappable slang in one place.
-- Slang ages fast: swap words here without touching game code. All text is original.
local Content = {}

-- "Hi Hungry, I'm Unc" — one dad joke per day (index = day number % count).
Content.UncJokes = {
	"Why did the brisket go to school? To get a little more well-done.",
	"I told my smoker a joke. It didn't laugh, but it did get a little warmer.",
	"What do you call a sleeping cow? A bulldozer. Now go flip that burger.",
	"I'm reading a book about anti-gravity. Can't put it down. Kinda like this rib.",
	"Why don't eggs tell jokes at cookouts? They'd crack each other up.",
	"What did the hot sauce say to the burger? 'You're lookin' sharp, bun.'",
	"I used to hate facial hair. Then it grew on me. Like this smoke smell.",
	"What's a pitmaster's favorite music? Anything with a good brisket beat.",
	"How do you make a tissue dance? Put a little boogie in it. Not in the sauce.",
	"Why did the pickle go to the doctor? It was feeling kinda dill.",
	"What kind of shoes do hot dogs wear? Buns-lippers. ...I'll see myself out.",
	"I asked the smoker how it was doing. It said 'low and slow, unc.'",
	"Why was the corn so popular? Everyone was all ears.",
	"What do you call cheese that isn't yours? Nacho cheese. What do you call brisket that isn't yours? Getting taxed.",
	"Why did the cowboy adopt a dachshund? He wanted to get a long little doggie.",
	"What did the grill say to the steak? 'You're so hot right now.'",
	"Why don't skeletons fight at barbecues? They don't have the guts.",
	"How does a BBQ say goodbye? 'Brisket later!'",
	"I'm on a seafood diet. I see food, and I smoke it.",
	"What do you call a fake noodle? An impasta. Not on my pit.",
	"Why did the sauce bottle blush? It saw the salad dressing.",
	"Did you hear about the restaurant on the moon? Great food, no atmosphere.",
	"What did the ribs say after the joke? 'That's a rib-tickler.'",
	"Why did the burger join the gym? To work on its buns.",
	"What's brown and sticky? A stick. ...and also my sauce.",
	"Why did the scarecrow win an award? He was outstanding in his field. Like your pit.",
	"I only know 25 letters of the alphabet. I don't know Y. But I know BBQ.",
	"What do you call a pig that does karate? A pork chop.",
	"Why are spiders great at cookouts? They know their way around the web of sauce.",
	"Back in my day we didn't have smoke signals. We had... well, actually we had smoke signals.",
	-- Yard jokes for early November 2026. Original sentences. See Content.YardNotes for sources.
	"Granny held up a perfect slice and called it a W chew. The burnt end was L nibbles. I nodded like I had invented both words.",
	"Half this brisket could sit on a postcard. The other half is what happens when Unc starts a story and forgets the fire. Same cook. Two drawings of one horse.",
	"The yard pup flopped over for a belly wash. He is not a famous internet dog. He is our dog, and the belly is still the whole bit.",
}

Content.UncYap = {
	"Now let me tell you about the summer of '98, the year the grill caught...",
	"Back in my day, a brisket took TWELVE hours and we liked it...",
	"You know what your problem is? You don't wait for the bark. The bark is everything...",
}

-- The King of the Pit hums ORIGINAL tunes (no real songs, lyrics, or likenesses).
Content.KingLines = {
	"♪ Hmm-hmm, low and slow, let that hickory go... ♪",
	"♪ Got a cooler full of brisket and a sky full of smoke... ♪",
	"♪ Dum-da-dum, the pit don't lie, the pit don't lie... ♪",
	"♪ Mesquite moon over the backyard tonight... ♪",
	"♪ Porch light, low fire, hum it again from the top... ♪",
	"Howdy, partner. A pit's like a promise: you keep it lit.",
}

-- Temp the talking thermometer. A little too helpful. Creepier at night (still kid-friendly).
Content.TempDay = {
	"Hi! I'm Temp! I measure things! Your brisket is doing GREAT!",
	"Fun fact: I'm always watching the internal temperature. Always.",
	"Need help? I love helping! Helping is my favorite thing!",
}
Content.TempNight = {
	"I see your brisket... I always see your brisket.",
	"It's dark out. I'm still measuring. Don't worry about what.",
	"Why are you awake? ...Me? I don't sleep. I'm a thermometer.",
	"The mosquitoes told me things. Terrible things. About ketchup.",
}

-- Granny Pecan, head Cook-Off judge.
Content.GrannyLines = {
	L = { "Bless your heart, sugar.", "Well... you tried, and that's what counts. Bless your heart." },
	Mid = { "It's mid, baby. Fine, but mid.", "I've had worse. At a gas station." },
	W = { "Now THAT is a W plate!", "Mm-hmm! Granny approves!" },
	Cooked = { "Child, you COOKED. Somebody call the newspaper!", "You cooked so hard the cat's clapping!" },
}

Content.PitmasterScold = {
	"If you're lookin', you ain't cookin'!",
	"Close that lid! Every peek costs you time!",
	"The smoke ring can't form if you keep peekin'!",
}

-- Swappable slang (edit freely as memes age).
Content.Slang = {
	perfectFlip = "+1000 AURA",
	lockedIn = "LOCKED IN 🔒",
	burnt = "Skill issue... 🤿 (everybody's doing the scuba wave)",
	crine = "😭 crine",
	snagged = "You got taxed!",
	snagger = "TAXED! Run before they tag you!",
	resting = "💤 Unc is resting his eyes",
	unclocked = "Unc Status unlocked. Socks and sandals are now legal.",
	quietCreek = "Shhh... quiet on the creek.",
	skipYap = "Skip the yap",
	sixSeven = "6-7! 🤷 (that tip ended in 67)",
	rush = "🍽️ LUNCH RUSH CLEARED!",
	dinnerBell = "🔔 DINNER'S ON! 🔔",
}

-- Turkey Day Smokeout (Thanksgiving week). Family-friendly, original lines only.
Content.TurkeyDay = {
	dialog = "Turkey Day Potluck",
	host = "Granny Pecan",
	hud = "🦃 Potluck's full: +25% tips",
	login = "🦃 It's Turkey Day Smokeout week! Smoke a Harvest Turkey Leg and share it at the potluck table for a free Thankful & Full Apron.",
	needDish = "Everybody brings a dish! Smoke a Harvest Turkey Leg (any smoker, 15 min), then set it on the table here.",
	already = "You already brought a dish today. Thank you, sugar! Come back tomorrow, and bring your crew: when 3 pitmasters share, the table's full for everybody.",
	firstShare = "You set your %s on the table. Granny Pecan gives you a hug and a brand-new apron.\n\n+%d coins, the Thankful & Full Apron, and a new title: Thankful.",
	share = "You set your %s on the table. \"Now THAT's a potluck!\"\n\n+%d coins. Come back tomorrow with another dish.",
	progress = "🥧 Potluck table: %d/%d dishes. %d more pitmasters sharing in the next few minutes fills the table, and everybody gets bonus tips!",
	full = "🦃 THE POTLUCK'S FULL! %d pitmasters shared a dish. Everyone gets +%d%% tips for %d min!",
	over = "The Turkey Day potluck is packed up for the year. See y'all next Thanksgiving!",
	thanks = {
		"Granny Pecan: \"I'm thankful for good smoke and better company.\"",
		"Unc Hank: \"I'm thankful for elastic waistbands. That's it. That's the joke.\"",
		"The King of the Pit: \"Thankful for low fire, slow days, and folks to feed.\"",
		"Temp: \"I am thankful for... 165 degrees. Always 165.\"",
	},
}

-- Holiday Smokeout (Dec 19 - Jan 1). Christmas at the ranch: family-friendly, original lines only.
Content.HolidaySmokeout = {
	dialog = "Holiday Smokeout Potluck",
	host = "Granny Pecan",
	hud = "🎄 Christmas potluck's full: +25% tips",
	login = "🎄 Merry Christmas from the ranch! The Holiday Smokeout runs through New Year's Day. Smoke a Holiday Glazed Ham and share it at the potluck table for a free Merry & Smoky Apron.",
	needDish = "Christmas potluck! Everybody brings a dish. Smoke a Holiday Glazed Ham (any smoker, 20 min), then set it on the table here.",
	already = "You already brought a dish today, sugar. Merry Christmas! Come back tomorrow, and bring your crew: when 3 pitmasters share, the table's full for everybody.",
	firstShare = "You set your %s on the table. Granny Pecan tucks a wrapped box under your arm: it's an apron!\n\n+%d coins, the Merry & Smoky Apron, and a new title: Merry & Smoky.",
	share = "You set your %s on the table. \"Now THAT's a Christmas spread!\"\n\n+%d coins. Come back tomorrow with another dish.",
	progress = "🎄 Christmas potluck: %d/%d dishes. %d more pitmasters sharing in the next few minutes fills the table, and everybody gets bonus tips!",
	full = "🎄 THE CHRISTMAS POTLUCK'S FULL! %d pitmasters shared a dish. Everyone gets +%d%% tips for %d min!",
	over = "The Christmas potluck is packed up till next December. Happy New Year, y'all!",
	thanks = {
		"Granny Pecan: \"Merry Christmas, sugar. Grab a tamale before Unc finds 'em.\"",
		"Unc Hank: \"I asked for a new grill brush. Got socks again. Unc things.\"",
		"The King of the Pit: \"Best gift there is: a full table and a slow fire.\"",
		"Temp: \"Ham's done at 140. I checked it twice. Like a list.\"",
		"Unc Hank: \"Ugly sweater? Sir, this is my good sweater.\"",
	},
}

-- Unc Hank's Rookie List (Config.RookieSteps). Unc's voice: warm, a little corny, never pushy.
Content.Rookie = {
	title = "📋 Unc's Rookie List",
	start = "Look at you, feedin' critters already! I wrote you a little list (top right). Five quick things and you're a real pitmaster. Follow the gold arrow!",
	cheers = {
		"Unc Hank: \"That's what I'm talkin' about!\"",
		"Unc Hank: \"Okay, okay, I see you!\"",
		"Unc Hank: \"Clean work. Your grandmama would be proud.\"",
		"Unc Hank: \"You're cookin' now. Literally.\"",
	},
	done = "Rookie List: done! You're officially Rookie of the Ranch. Wear that bandana with pride.\n\nFinish reward: +%d coins, the Rookie of the Ranch Bandana, and a new title: Rookie of the Ranch.",
	-- %s = the finish reward, e.g. "Rookie of the Ranch Bandana + title + 250 🪙"
	finishLine = "🏁 Finish all 5 to earn: %s",
	skipAsk = "Skip the Rookie List? You'll miss the finish reward for now: %s. You can bring the list back any time in Settings > Game and still earn it.",
	skipKeep = "Keep going",
	skipYes = "Skip for now",
	skipped = "Rookie List tucked away. Bring it back any time in Settings > Game.",
	resumed = "Unc's Rookie List is back (top right)! Goals you already did count right away.",
	stepDone = "✅ %s  +%d coins",
}

-- Yard flavor for the week of November 7, 2026. A few lines, not a meme wall.
-- Dated sources, checked while writing this:
-- * Know Your Meme, "The Weekly Meme Roundup", published November 6, 2026:
--   "W chews" (good food) and "L nibbles" (bad food) had spread from a late-October post
--   and were still circulating that week. We use the words in original BBQ sentences.
--   We do not use the person from those clips, the clips themselves, or anyone's audio.
-- * SocialBee, "Trending Instagram memes this week", November 5, 2026: a split
--   horse-drawing format (polished on one side, rough on the other). We do not use the
--   drawing. One brisket line borrows the shape of the joke only.
-- * RoTerminal, "Trends on Roblox", snapshot November 7, 2026, 8:59am New York time:
--   new games named tycoon were up about 73% and simulator about 61% versus the prior
--   30 days. The porch board says low and slow beats a rush. It does not name other games.
-- Left out on purpose from that same November 6 roundup: election jokes, thirst trends,
-- and a brand-mascot pile-on. Those do not belong at a backyard cookout.
-- "6-7" is already in the game from earlier. It is not labeled as a November 2026 trend.
-- Unc is already the host (Know Your Meme's unc entry was last updated February 14, 2025;
-- "Unc Still Got It" was updated April 9, 2026). He stays a small voice, not a new theme.
-- Pibble is a March 2025 pet-audio meme that fandom pages were still describing in August
-- 2026. One belly-rub line nods at it because Mike likes that joke. We do not play the audio,
-- and we do not call it the current trend.
Content.YardNotes = {
	board = "TODAY'S BOARD\nGood smoke is a W chew.\nBurnt ends are L nibbles.\nLow and slow beats a rush.",
	pup = "The pup flops over for a belly wash. He is our dog, not a famous one.",
}

Content.Signs = {
	hub = "ROCHIN' RANCH RD.",
	shop = "ROCH & ROLL SAUCE SHACK",
	cookoff = "SATURDAY COOK-OFF",
	potluck = "SUNDAY POTLUCK",
	turkeyPotluck = "TURKEY DAY POTLUCK",
	turkeyBanner = "TURKEY DAY SMOKEOUT\nBring a dish!",
	holidayPotluck = "CHRISTMAS POTLUCK",
	holidayBanner = "HOLIDAY SMOKEOUT\nMerry Christmas, y'all!",
	creek = "(nothing to see here)",
	welcome = "BACKYARD SMOKEOUT",
	bertha = "BIG BERTHA\nThe King of the Pit's 1,000-gallon smoker · Ring the bell when supper's on",
}

return Content
