--!strict
--[[
	SocialService — friendly multiplayer.
	  * Crew bonus: +10% coins for each friend in the server (max 3).
	  * Plate snagging ("you got taxed!"): grab ONE Common/Juicy plate from another player's
	    pass window. Rules that keep it fun instead of mean:
	      - only while the owner is online and in the game (never offline),
	      - never from someone in Peace Mode (and Peace Mode players can't snag),
	      - new arrivals are shielded for their first 5 minutes,
	      - after a snag the victim's window locks for 3 minutes,
	      - the victim instantly gets 25% of the plate's value back ("insurance"),
	      - the victim can tag the snagger within 15 seconds to get it back plus a bonus,
	      - paid perks never change any of this.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Content = require(Shared.Content)
local Rarity = require(Shared.Logic.Rarity)
local Economy = require(Shared.Logic.Economy)
local WorldBuilder = require(Shared.WorldBuilder)

local SocialService = {}
local ctx: any = nil
local S = Config.Snag

local friendCache: { [string]: boolean } = {}
local running: { [Player]: any } = {} -- snagger -> { victim, plate, untilT, prompt, gui }

local function pairKey(a: number, b: number): string
	if a < b then
		return a .. ":" .. b
	end
	return b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local k = pairKey(a.UserId, b.UserId)
	local cached = friendCache[k]
	if cached ~= nil then
		return cached
	end
	local ok, res = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	if not ok then
		-- older engine builds only have the non-Async name
		ok, res = pcall(function()
			return (a :: any):IsFriendsWith(b.UserId)
		end)
	end
	local v = ok and res == true
	friendCache[k] = v
	return v
end

local function recountCrew()
	for player, r in pairs(ctx.Game.runtime) do
		local n = 0
		for other in pairs(ctx.Game.runtime) do
			if other ~= player and areFriends(player, other) then
				n += 1
			end
		end
		n = math.min(n, Config.Crew.maxFriends)
		if n ~= r.crew then
			if n > r.crew then
				ctx.Game.toast(player, string.format("Crew bonus! +%d%% coins with %d friend%s here. 🤝", math.floor(n * Config.Crew.perFriend * 100 + 0.5), n, n == 1 and "" or "s"), "good")
			end
			r.crew = n
			ctx.Game.markDirty(player)
		end
	end
end

function SocialService.onJoin(_player: Player)
	task.spawn(recountCrew)
end

function SocialService.onLeave(player: Player)
	local run = running[player]
	if run then
		-- snagger left mid-run: plate goes home
		SocialService.finishRun(player, true)
	end
	for snagger, rr in pairs(running) do
		if rr.victim == player then
			SocialService.finishRun(snagger, false)
		end
	end
	task.defer(recountCrew)
end

local function baseValue(plate: any): number
	-- Paid perks don't count: just price x rarity.
	local meat = Config.Meats[plate.m]
	local rar = Rarity.get(Config.Rarities, plate.r)
	return math.floor(meat.price * rar.mult)
end

local function snaggableIndex(data: any): number?
	local best, bestV = nil, math.huge
	for i, plate in ipairs(data.cooler) do
		local ri = Rarity.indexOf(Config.Rarities, plate.r)
		if ri <= S.maxRarityIndex and plate.m ~= "firstbrisket" then
			local v = baseValue(plate)
			if v < bestV then
				best, bestV = i, v
			end
		end
	end
	return best
end

-- Why can't `victim` be snagged right now? nil = they can.
local function victimBlock(victim: Player): string?
	local data = ctx.Game.dataOf(victim)
	local r = ctx.Game.runtime[victim]
	if not data or not r then
		return "loading"
	end
	if data.settings.peace then
		return "peace"
	end
	if os.clock() - r.sessionStart < S.newPlayerShield then
		return "shield"
	end
	if os.clock() < r.snagLockUntil then
		return "locked"
	end
	if r.resting then
		return "resting"
	end
	if not snaggableIndex(data) then
		return "empty"
	end
	for _, rr in pairs(running) do
		if rr.victim == victim then
			return "locked"
		end
	end
	return nil
end

function SocialService.refreshPassWindow(victim: Player)
	local plot = ctx.World.plotModel(victim)
	if not plot then
		return
	end
	local counter = plot.PassWindow.Counter :: BasePart
	local prompt = counter:FindFirstChild("Prompt") :: ProximityPrompt
	local gui = counter:FindFirstChild("LockGui") :: BillboardGui
	local label = gui:FindFirstChild("Text") :: TextLabel
	local why = victimBlock(victim)
	prompt.Enabled = why == nil
	prompt:SetAttribute("OwnerUserId", victim.UserId) -- the owner's client hides this prompt for themselves
	local r = ctx.Game.runtime[victim]
	if why == "peace" then
		label.Text = "🕊️ Peace Mode"
	elseif why == "shield" and r then
		label.Text = "🛡️ New arrival shield"
	elseif why == "locked" and r then
		local left = math.max(0, math.ceil(r.snagLockUntil - os.clock()))
		label.Text = left > 0 and ("🔒 Locked " .. left .. "s") or "🔒 Locked"
	elseif why == "resting" then
		label.Text = "💤 Resting"
	else
		label.Text = ""
	end
end

local function carryVisual(snagger: Player, plate: any): (ProximityPrompt?, BillboardGui?)
	local char = snagger.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	if not hrp or not head then
		return nil, nil
	end
	local meat = Config.Meats[plate.m]
	local gui = WorldBuilder.billboard(head, "TaxedGui", "🍽️ " .. meat.icon .. " TAXED!", 3, 120, "#FFC83C", 200, 40)
	gui.AlwaysOnTop = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CatchPrompt"
	prompt.ActionText = "Tag back!"
	prompt.ObjectText = snagger.DisplayName .. " has your plate"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = S.catchDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Kind", "catch")
	prompt:SetAttribute("SnaggerUserId", snagger.UserId)
	prompt.Parent = hrp
	return prompt, gui
end

function SocialService.finishRun(snagger: Player, returned: boolean)
	local run = running[snagger]
	if not run then
		return
	end
	running[snagger] = nil
	if run.prompt then
		run.prompt:Destroy()
	end
	if run.gui then
		run.gui:Destroy()
	end
	local victim: Player = run.victim
	local vdata = ctx.Game.dataOf(victim)
	local sdata = ctx.Game.dataOf(snagger)
	if returned then
		if vdata and victim.Parent then
			ctx.Game.addPlate(vdata, run.plate)
			ctx.World.refreshStations(victim)
			ctx.Game.markDirty(victim)
		end
	else
		if sdata and snagger.Parent then
			if not ctx.Game.addPlate(sdata, run.plate) then
				ctx.Game.addCoins(snagger, sdata, baseValue(run.plate), true)
			end
			sdata.stats.snags += 1
			ctx.Game.toast(snagger, "Clean getaway! The plate's in your cooler. 😎", "good")
			ctx.World.refreshStations(snagger)
			ctx.Game.markDirty(snagger)
		end
	end
end

function SocialService.trySnag(snagger: Player, prompt: ProximityPrompt)
	local node: Instance? = prompt.Parent
	while node and not node:GetAttribute("PlotIndex") do
		node = node.Parent
	end
	if not node then
		return
	end
	local victim = ctx.World.ownerOfPlot(node:GetAttribute("PlotIndex") :: number)
	if not victim or victim == snagger then
		return
	end
	local sdata = ctx.Game.dataOf(snagger)
	local sr = ctx.Game.runtime[snagger]
	if not sdata or not sr then
		return
	end
	if sdata.settings.peace then
		ctx.Game.toast(snagger, "You're in Peace Mode, so no snagging. (Turn it off in Settings.)", "info")
		return
	end
	if running[snagger] then
		return
	end
	if os.clock() < sr.snagCooldownUntil then
		ctx.Game.toast(snagger, string.format("Catch your breath! You can snag again in %ds.", math.ceil(sr.snagCooldownUntil - os.clock())), "info")
		return
	end
	if #sdata.cooler >= Config.COOLER_MAX then
		ctx.Game.toast(snagger, "Your cooler's full!", "info")
		return
	end
	if victimBlock(victim) then
		return
	end
	local vdata = ctx.Game.dataOf(victim)
	local vr = ctx.Game.runtime[victim]
	local idx = snaggableIndex(vdata)
	if not idx then
		return
	end
	local plate = table.remove(vdata.cooler, idx)
	sr.snagCooldownUntil = os.clock() + S.cooldown
	vr.snagLockUntil = os.clock() + S.victimLock
	local insurance = math.floor(baseValue(plate) * S.insurance)
	ctx.Game.addCoins(victim, vdata, insurance, true)
	local meat = Config.Meats[plate.m]
	ctx.Game.toast(victim, string.format("%s %s snagged your %s! You got %d coins back. Tag them within %ds to get it back!", Content.Slang.snagged, snagger.DisplayName, meat.name, insurance, S.catchWindow), "warn")
	ctx.Game.toast(snagger, Content.Slang.snagger, "good")
	local cp, gui = carryVisual(snagger, plate)
	if cp then
		cp:SetAttribute("OwnerUserId", victim.UserId) -- only the victim's client shows this prompt
	end
	running[snagger] = { victim = victim, plate = plate, untilT = os.clock() + S.catchWindow, prompt = cp, gui = gui }
	ctx.Remotes.Push:FireClient(victim, "fx", { kind = "snagged", data = { by = snagger.DisplayName, window = S.catchWindow } })
	ctx.World.refreshStations(victim)
	ctx.Game.markDirty(victim)
	ctx.Game.markDirty(snagger)
	task.delay(S.catchWindow, function()
		if running[snagger] and running[snagger].plate == plate then
			SocialService.finishRun(snagger, false)
		end
	end)
end

function SocialService.tryCatch(victim: Player, prompt: ProximityPrompt)
	local snaggerId = prompt:GetAttribute("SnaggerUserId")
	local snagger = typeof(snaggerId) == "number" and Players:GetPlayerByUserId(snaggerId) or nil
	if not snagger then
		return
	end
	local run = running[snagger]
	if not run or run.victim ~= victim or os.clock() > run.untilT then
		return
	end
	-- distance double-check on the server
	local a = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = snagger.Character and snagger.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not a or not b or (a.Position - b.Position).Magnitude > S.catchDistance + 4 then
		return
	end
	SocialService.finishRun(snagger, true)
	local vdata = ctx.Game.dataOf(victim)
	if vdata then
		local bonus = math.floor(S.catchBonus * Economy.rankMult(vdata.rank, Config.RANK_STEP))
		ctx.Game.addCoins(victim, vdata, bonus, true)
		ctx.Game.toast(victim, string.format("Caught 'em! Plate's back, +%d bonus. 💪", bonus), "good")
	end
	ctx.Game.toast(snagger, "Caught! " .. Content.Slang.crine, "bad")
end

function SocialService.init(c: any)
	ctx = c
end

function SocialService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(ctx.Game.runtime) do
				SocialService.refreshPassWindow(player)
			end
		end
	end)
end

return SocialService
