--!strict
-- Runs the Smoke Storm clock and rolls traits. Rolls are free. Nothing here reads a purchase.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weather = require(Shared.Logic.Weather)
local Index = require(Shared.Logic.Index)
local Crew = require(Shared.Logic.Crew)
local TimeUtil = require(Shared.Logic.TimeUtil)

local WeatherService = {}
local ctx: any = nil
local seed = 1
local rolled: { [string]: boolean } = {}
local stormIndex = -1

function WeatherService.state(): any
	local now = os.time()
	local show = Weather.smokeShow(now, Config.TIMEZONE_OFFSET_HOURS)
	local storm = Weather.stormAt(seed, now)
	local active = storm.active or show
	return {
		active = active,
		show = show,
		banner = if active then Weather.banner(show) else "",
		odds = Weather.shownOdds(show),
		nextAt = TimeUtil.clock(if storm.active then storm.finish else storm.start, Config.TIMEZONE_OFFSET_HOURS),
	}
end

function WeatherService.init(c: any)
	ctx = c
end

local function shoutTrait(player: Player, member: any, traitId: string)
	if traitId ~= "golden" and traitId ~= "meteorite" then
		return
	end
	local trait = Crew.traitDef(traitId)
	ctx.Game.announce(string.format("%s's %s caught %s!", player.DisplayName, member.name, trait.name), "#FFC83C")
end

local function rollPlayer(player: Player, stormKey: string)
	local data = ctx.Game.dataOf(player)
	if type(data) ~= "table" or type(data.crew) ~= "table" or type(data.crew.owned) ~= "table" then
		return
	end
	local show = Weather.smokeShow(os.time(), Config.TIMEZONE_OFFSET_HOURS)
	local slots = data.crew.slots or 0
	local changed = false
	for i, member in ipairs(data.crew.owned) do
		if i > slots then
			break
		end
		local key = stormKey .. ":" .. tostring(player.UserId) .. ":" .. tostring(member.uid)
		if not rolled[key] then
			rolled[key] = true
			local rolledTrait = Weather.roll(Random.new():NextNumber(), show)
			local nextTrait = Weather.upgrade(member.trait, rolledTrait)
			if nextTrait ~= member.trait then
				member.trait = nextTrait
				changed = true
				local note = Index.note(data, member.species, nextTrait)
				shoutTrait(player, member, nextTrait)
				if note.rowDone then
					ctx.Game.toast(player, member.name .. " completed a Crew Index row. +2% crew income.", "good")
				end
				if note.title then
					ctx.Game.toast(player, "Title earned: " .. note.title, "good")
				end
			end
		end
	end
	if changed then
		ctx.Game.markDirty(player)
	end
end

local function grantShow(player: Player, week: number)
	local data = ctx.Game.dataOf(player)
	if type(data) ~= "table" then
		return
	end
	if type(data.events) ~= "table" then
		data.events = { smokeShowWeek = -1 }
	end
	if data.events.smokeShowWeek == week then
		return
	end
	data.events.smokeShowWeek = week
	local species = Crew.byId("hummingbird")
	if not species then
		return
	end
	Crew.ensure(data)
	local merge = Crew.findSpecies(data.crew.owned, species.id)
	if merge then
		merge.level = math.min(Config.Hiring.maxLevel, (merge.level or 1) + 1)
		ctx.Game.toast(player, "Saturday Smoke Show: " .. merge.name .. " learned a little more.", "good")
	elseif #data.crew.owned < (data.crew.slots or 0) then
		local member = {
			uid = data.crew.nextUid,
			species = species.id,
			name = species.name,
			level = 1,
			trait = "none",
			badge = nil,
			role = species.role,
		}
		table.insert(data.crew.owned, member)
		data.crew.nextUid = member.uid + 1
		ctx.Game.toast(player, "Saturday Smoke Show: " .. species.name .. " joined your ranch.", "good")
	else
		ctx.Game.toast(player, "Saturday Smoke Show is on, and the ranch is full, so Zip sat this one out.", "info")
	end
	ctx.Game.markDirty(player)
end

function WeatherService.start()
	seed = Random.new():NextInteger(1, 2000000000)
	task.spawn(function()
		while true do
			local now = os.time()
			local storm = Weather.stormAt(seed, now)
			local show = Weather.smokeShow(now, Config.TIMEZONE_OFFSET_HOURS)
			if storm.index ~= stormIndex then
				stormIndex = storm.index
				table.clear(rolled)
			end
			if storm.active or show then
				local key = tostring(storm.index) .. (if show then ":show" else "")
				for _, player in ipairs(Players:GetPlayers()) do
					local ok, err = pcall(rollPlayer, player, key)
					if not ok then
						warn("[Weather] " .. tostring(err))
					end
				end
			end
			if show then
				local week = TimeUtil.weekNumber(now, Config.TIMEZONE_OFFSET_HOURS)
				for _, player in ipairs(Players:GetPlayers()) do
					grantShow(player, week)
				end
			end
			task.wait(1)
		end
	end)
end

return WeatherService
