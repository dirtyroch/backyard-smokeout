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
}

Content.Signs = {
	hub = "ROCHIN' RANCH RD.",
	shop = "ROCH & ROLL SAUCE SHACK",
	cookoff = "SATURDAY COOK-OFF",
	potluck = "SUNDAY POTLUCK",
	creek = "(nothing to see here)",
	welcome = "BACKYARD SMOKEOUT",
}

return Content
