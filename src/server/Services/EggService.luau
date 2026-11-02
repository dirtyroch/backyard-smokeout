--!strict
--[[
	EggService — every ProximityPrompt the server handles, plus NPC dialogue and Easter eggs.
	Prompts carry a "Kind" attribute set by WorldBuilder. Kinds starting with "ui:" and
	"npc:unc" are handled by the client (they only open UI or call a normal Action).

	Easter eggs (all original):
	  blessed  - a tiny figure on the Sunday potluck table holding a "Jesus loves you" ribbon
	  roof     - bounce off the trampoline onto the Sauce Shack roof ("Roof Club")
	  creek    - the whisper stone past the hedge gap: "Shhh... quiet on the creek." (daily sauce)
	  apron    - the World's Okayest Unc apron hanging by the creek
	  king     - visit the King of the Pit after dark wearing a cowboy hat
	  temp     - Temp the thermometer has a thing to say if you keep poking him
	  rex      - Rex visits your ranch ("RAWR means I love you")
	  meteorite- cook a Meteorite cut
	  cooked   - get a "Cooked" rating from Granny Pecan
	  sixseven - serve a plate worth ...67 coins ("6-7!")
	  dinnerbell - be one of 3 players who ring Big Bertha's dinner bell together (server-wide tip bonus)
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Hype = require(Shared.Logic.Hype)
local Economy = require(Shared.Logic.Economy)
local Rarity = require(Shared.Logic.Rarity)
local Holiday = require(Shared.Logic.Holiday)

local EggService = {}
local ctx: any = nil
local rng = Random.new()
local tempPokes: { [Player]: number } = {}

EggService.EGGS = { "blessed", "roof", "creek", "apron", "king", "temp", "rex", "meteorite", "cooked", "sixseven", "dinnerbell" }

local bellRings: { [number]: number } = {}
local lastDinner = -1e9
local potluckShares: { [number]: number } = {}
local lastPotluck = -1e9

local function today(): number
	return TimeUtil.dayNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

local function dialog(player: Player, npc: string, text: string, reward: number?)
	ctx.Remotes.Push:FireClient(player, "dialog", { npc = npc, text = text, reward = reward or 0 })
end

function EggService.found(player: Player, data: any, egg: string): boolean
	if data.eggs[egg] then
		return false
	end
	data.eggs[egg] = true
	local n = 0
	for _, e in ipairs(EggService.EGGS) do
		if data.eggs[e] then
			n += 1
		end
	end
	ctx.Game.toast(player, string.format("🥚 Secret found! (%d/%d)", n, #EggService.EGGS), "good")
	if n == #EggService.EGGS then
		data.titles["Egg Hunter"] = true
		ctx.Game.toast(player, "You found every secret! New title: Egg Hunter", "good")
	end
	ctx.Game.markDirty(player)
	return true
end

local function ownsPrompt(player: Player, prompt: ProximityPrompt): boolean
	return prompt:GetAttribute("OwnerUserId") == player.UserId
end

local function customerFor(player: Player, prompt: ProximityPrompt): any?
	if not ownsPrompt(player, prompt) then
		return nil
	end
	local id = prompt:GetAttribute("CustomerId")
	if typeof(id) ~= "number" then
		return nil
	end
	return ctx.World.findCustomer(player, id)
end

local handlers: { [string]: (Player, any, ProximityPrompt) -> () } = {}

handlers.serve = function(player, _data, prompt)
	local c = customerFor(player, prompt)
	if c then
		ctx.Game.advanceAll(player, ctx.Game.dataOf(player), workspace:GetServerTimeNow(), true)
		local ok, msg = ctx.Game.serveCustomer(player, c)
		if not ok and msg then
			ctx.Game.toast(player, msg, "info")
		end
	end
end

handlers.bellyrub = function(player, _data, prompt)
	local c = customerFor(player, prompt)
	if c then
		ctx.Game.bellyRub(player, c)
	end
end

handlers.wash = function(player, _data, prompt)
	local c = customerFor(player, prompt)
	if c then
		ctx.Game.washPup(player, c)
		prompt:Destroy()
	end
end

handlers.snag = function(player, _data, prompt)
	ctx.Social.trySnag(player, prompt)
end

handlers.catch = function(player, _data, prompt)
	ctx.Social.tryCatch(player, prompt)
end

handlers.cookoff = function(player)
	ctx.Event.enterCookOff(player)
end

handlers["npc:king"] = function(player, data)
	local line = Content.KingLines[rng:NextInteger(1, #Content.KingLines)]
	local hat = data.equipped.hat
	local cowboy = hat == "hat_pitmaster" or hat == "hat_straw"
	if ctx.Event.isNight() and cowboy and not data.daily.kingDone then
		data.daily.kingDone = true
		ctx.Game.addSauce(data, "straitshootin")
		EggService.found(player, data, "king")
		dialog(player, "The King of the Pit", "Well now, that's a fine hat, partner. A pitmaster after dark is a pitmaster for life.\nTake a bottle of my Strait-Shootin' Sauce. Don't tell Unc.\n\n(Strait-Shootin' Sauce: +30% cook speed for 3 cooks)")
	elseif not data.daily.kingDone then
		dialog(player, "The King of the Pit", line .. "\n\n(He tips his hat.) Come see me after sundown in a proper cowboy hat, partner.")
	else
		dialog(player, "The King of the Pit", line)
	end
end

handlers["npc:temp"] = function(player, data)
	local night = ctx.Event.isNight()
	local pool = night and Content.TempNight or Content.TempDay
	tempPokes[player] = (tempPokes[player] or 0) + 1
	if tempPokes[player] >= 7 and not data.eggs.temp then
		EggService.found(player, data, "temp")
		ctx.Game.addCoins(player, data, 300, true)
		dialog(player, "Temp", "Okay okay, you got me. I don't actually know what temperature it is. I'm a thermometer with stage fright.\nHere's 300 coins to keep it between us.", 300)
		return
	end
	dialog(player, "Temp", pool[rng:NextInteger(1, #pool)])
end

handlers["egg:blessed"] = function(player, data)
	local first = EggService.found(player, data, "blessed")
	local d = today()
	if first then
		data.titles["Blessed"] = true
		ctx.Game.addPlate(data, { m = "brisket", r = "smokering" })
		ctx.Game.awardBadge(player, "BlessedPlate")
		dialog(player, "Sunday Potluck", "A tiny figure holds a little ribbon: \"Jesus loves you ♥\"\n\nSomebody left you a Blessed Plate (a Smoke Ring Gold brisket) and a new title: Blessed.")
		data.eggs.potluckDay = d
	elseif ctx.Game.isSunday() and data.eggs.potluckDay ~= d then
		data.eggs.potluckDay = d
		ctx.Game.addPlate(data, { m = "ribs", r = "juicy" })
		dialog(player, "Sunday Potluck", "\"Jesus loves you ♥\"\n\nIt's Sunday, so there's a potluck plate for you: Juicy Roch & Roll Ribs. Come back next Sunday!")
	else
		dialog(player, "Sunday Potluck", "\"Jesus loves you ♥\"\n\n(There's a potluck plate here every Sunday.)")
	end
	ctx.World.refreshStations(player)
end

handlers["egg:roof"] = function(player, data)
	if EggService.found(player, data, "roof") then
		data.titles["Roof Club"] = true
		ctx.Game.addCoins(player, data, 500, true)
		dialog(player, "Roof Club", "You signed the Sauce Shack roof. Only real ones make it up here.\n+500 coins and a new title: Roof Club", 500)
	else
		dialog(player, "Roof Club", "Your name's already up here. Nice view, huh?")
	end
end

handlers["egg:creek"] = function(player, data)
	local d = today()
	local first = EggService.found(player, data, "creek")
	if first then
		data.titles["Creek Whisperer"] = true
		ctx.Game.awardBadge(player, "SecretCreek")
	end
	if data.daily.creekDay ~= d then
		data.daily.creekDay = d
		ctx.Game.addSauce(data, "secretcreek")
		dialog(player, "Whisper Stone", Content.Slang.quietCreek .. "\n\nYou found a bottle of Secret Creek Sauce wedged in the rocks. (+50% luck for 5 cooks.) The creek gives one a day.")
	else
		dialog(player, "Whisper Stone", Content.Slang.quietCreek .. "\n\n(The creek already gave you a bottle today. Come back tomorrow.)")
	end
end

handlers["egg:apron"] = function(player, data)
	local isNew = ctx.Game.grantCosmetic(player, data, "apron_okayestunc")
	EggService.found(player, data, "apron")
	if isNew then
		dialog(player, "Mystery Apron", "WORLD'S OKAYEST UNC.\nIt fits perfectly. Too perfectly. Equip it in Settings > Fits.")
	else
		dialog(player, "Mystery Apron", "You already have this one. It's still okay.")
	end
end

-- Big Bertha's dinner bell, by the King of the Pit's 1,000-gallon smoker in the hub square.
-- One ring a day pays a small tip buff; every ring after that is free noise.
local BELL_LINES = {
	"CLANG! Somewhere across the county, a brisket sits up a little straighter.",
	"The bell rings out over the square. Big Bertha answers with a big puff of smoke.",
	"The King of the Pit tips his hat without looking up. \"That's the sound of supper.\"",
	"You ring it. A roadrunner stops, listens, and starts walking toward the food.",
	"Big Bertha's firebox crackles. She heard you.",
}

-- Dinner Bell pile-on: enough different players ring inside the window -> free server-wide tips.
local function checkDinnerBell(player: Player)
	local B = Config.DinnerBell
	local now = workspace:GetServerTimeNow()
	bellRings[player.UserId] = now
	local n, go = Hype.pileOn(bellRings, now, B.window, B.need, lastDinner, B.cooldown)
	if go then
		lastDinner = now
		ctx.Game.dinnerUntil = now + B.minutes * 60
		ctx.Game.announce(string.format("🔔 DINNER'S ON! %d pitmasters rang Big Bertha's bell. Everyone gets +%d%% tips for %d min!", n, math.floor(B.tipBonus * 100 + 0.5), B.minutes), "#FFC83C")
		ctx.Remotes.Push:FireAllClients("fx", { kind = "dinnerbell", data = { n = n } })
		for id in pairs(bellRings) do
			local p = Players:GetPlayerByUserId(id)
			local pd = p and ctx.Game.dataOf(p)
			if p and pd then
				EggService.found(p, pd, "dinnerbell")
			end
		end
		table.clear(bellRings)
		for p in pairs(ctx.Game.runtime) do
			ctx.Game.markDirty(p)
		end
	elseif now - lastDinner >= B.cooldown then
		ctx.Game.toast(player, string.format("🔔 Dinner bell: %d/%d. Get %d more pitmasters to ring it within %ds and the whole server gets bonus tips!", n, B.need, B.need - n, B.window), "info")
	end
end

-- Turkey Day Smokeout: share a smoked Harvest Turkey Leg at the potluck table (once a day). When enough
-- different pitmasters share inside the window, the table is full: free server-wide tips.
local function checkPotluck(player: Player)
	local TD = Config.TurkeyDay
	local now = workspace:GetServerTimeNow()
	potluckShares[player.UserId] = now
	local n, go = Hype.pileOn(potluckShares, now, TD.window, TD.need, lastPotluck, TD.cooldown)
	if go then
		lastPotluck = now
		ctx.Game.potluckUntil = now + TD.minutes * 60
		ctx.Game.announce(string.format(Content.TurkeyDay.full, n, math.floor(TD.tipBonus * 100 + 0.5), TD.minutes), "#E8761E")
		table.clear(potluckShares)
		for p in pairs(ctx.Game.runtime) do
			ctx.Game.markDirty(p)
		end
	elseif now - lastPotluck >= TD.cooldown then
		ctx.Game.toast(player, string.format(Content.TurkeyDay.progress, n, TD.need, TD.need - n), "info")
	end
end

handlers["event:potluck"] = function(player, data)
	local TD = Config.TurkeyDay
	local TC = Content.TurkeyDay
	if not ctx.Game.turkeyWeek().active then
		dialog(player, "Granny Pecan", TC.over)
		return
	end
	local d = today()
	if data.daily.turkeyDay == d then
		dialog(player, "Granny Pecan", TC.already)
		return
	end
	local i = Holiday.pickPlate(data.cooler, TD.meat, function(id: string): number
		return Rarity.indexOf(Config.Rarities, id)
	end)
	if not i then
		dialog(player, "Granny Pecan", TC.needDish)
		return
	end
	local plate = table.remove(data.cooler, i)
	data.daily.turkeyDay = d
	local meat = Config.Meats[plate.m]
	local coins = math.floor(meat.price * TD.shareMult * Economy.rankMult(data.rank, Config.RANK_STEP))
	ctx.Game.addCoins(player, data, coins, true)
	local label = Rarity.get(Config.Rarities, plate.r).name .. " " .. meat.name
	local thanks = TC.thanks[rng:NextInteger(1, #TC.thanks)]
	if ctx.Game.grantCosmetic(player, data, TD.reward) then
		data.titles[TD.title] = true
		dialog(player, "Turkey Day Potluck", string.format(TC.firstShare, label, coins) .. "\n\n" .. thanks, coins)
	else
		dialog(player, "Turkey Day Potluck", string.format(TC.share, label, coins) .. "\n\n" .. thanks, coins)
	end
	checkPotluck(player)
	ctx.World.refreshStations(player)
end

handlers["landmark:bell"] = function(player, data)
	local d = today()
	ctx.Game.fx(player, "bell", {})
	checkDinnerBell(player)
	local line = BELL_LINES[rng:NextInteger(1, #BELL_LINES)]
	if data.daily.bellDay ~= d then
		data.daily.bellDay = d
		ctx.Game.addSauce(data, "burntend")
		if not data.titles["Dinner Bell Ringer"] then
			data.titles["Dinner Bell Ringer"] = true
			ctx.Game.toast(player, "New title: Dinner Bell Ringer", "good")
		end
		ctx.Game.markDirty(player)
		dialog(player, "Big Bertha", line .. "\n\nThe King of the Pit slides you a jar of Burnt-End Glaze. (+20% tips for 3 serves.) You get one jar a day.")
	else
		dialog(player, "Big Bertha", line .. "\n\n(You already got today's glaze. Ringing is still free.)")
	end
end

function EggService.init(c: any)
	ctx = c
end

function EggService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		local kind = prompt:GetAttribute("Kind")
		if typeof(kind) ~= "string" then
			return
		end
		local fn = handlers[kind]
		if not fn then
			return -- client-side kinds (ui:*, npc:unc)
		end
		local data = ctx.Game.dataOf(player)
		if not data or not ctx.Game.runtime[player] then
			return
		end
		ctx.Game.runtime[player].lastActive = os.clock()
		local ok, err = pcall(function(): any
			fn(player, data, prompt)
			return nil
		end)
		if not ok then
			warn("[EggService] " .. kind .. ": " .. tostring(err))
		end
		ctx.Game.markDirty(player)
	end)
	-- Rex / meteorite / cooked eggs are detected from stats & state.
	task.spawn(function()
		while true do
			task.wait(3)
			for player in pairs(ctx.Game.runtime) do
				local data = ctx.Game.dataOf(player)
				if data then
					if (data.critters.rex or 0) > 0 then
						EggService.found(player, data, "rex")
					end
					for key in pairs(data.cutsIndex) do
						if string.find(key, ":meteorite", 1, true) then
							EggService.found(player, data, "meteorite")
							break
						end
					end
				end
			end
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		tempPokes[p] = nil
	end)
end

return EggService
