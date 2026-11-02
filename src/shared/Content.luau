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
	done = "Rookie List: done! You're officially Rookie of the Ranch. Wear that bandana with pride.\n\n+%d coins, the Rookie of the Ranch Bandana, and a new title: Rookie of the Ranch.",
	stepDone = "✅ %s  +%d coins",
}

Content.Signs = {
	hub = "ROCHIN' RANCH RD.",
	shop = "ROCH & ROLL SAUCE SHACK",
	cookoff = "SATURDAY COOK-OFF",
	potluck = "SUNDAY POTLUCK",
	turkeyPotluck = "TURKEY DAY POTLUCK",
	turkeyBanner = "TURKEY DAY SMOKEOUT\nBring a dish!",
	creek = "(nothing to see here)",
	welcome = "BACKYARD SMOKEOUT",
	bertha = "BIG BERTHA\nThe King of the Pit's 1,000-gallon smoker · Ring the bell when supper's on",
}

return Content
