--!strict
-- Sound effects: one SoundGroup, short one-shots and the grill's sizzle loop.
-- Players can turn sound effects off in Settings > Game (saved with their ranch).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SfxIds = require(Shared.SfxIds) :: { [string]: any }

local Sfx = {}
local group: SoundGroup = nil :: any
local base: { [string]: Sound } = {}
local sizzle: Sound? = nil
local enabled = true
local lastPlayed: { [string]: number } = {}

function Sfx.mount()
	group = Instance.new("SoundGroup")
	group.Name = "BackyardSfx"
	group.Volume = 0.8
	group.Parent = SoundService
	local list = {}
	for name, def in pairs(SfxIds) do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = "rbxassetid://" .. tostring(def.id)
		s.Volume = def.volume or 0.5
		s.Looped = def.loop == true
		s.SoundGroup = group
		s.Parent = group
		base[name] = s
		table.insert(list, s)
	end
	sizzle = base.sizzleLoop
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

function Sfx.setEnabled(on: boolean)
	enabled = on
	if group then
		group.Volume = on and 0.8 or 0
	end
	if not on and sizzle then
		sizzle:Stop()
	end
end

function Sfx.isEnabled(): boolean
	return enabled
end

-- Play a one-shot. `pitch` lets combos climb; `minGap` stops spam from rapid repeats.
function Sfx.play(name: string, pitch: number?, minGap: number?)
	local s = base[name]
	if not enabled or not s then
		return
	end
	local now = os.clock()
	if minGap and lastPlayed[name] and now - lastPlayed[name] < minGap then
		return
	end
	lastPlayed[name] = now
	local c = s:Clone()
	c.Looped = false
	c.PlaybackSpeed = pitch or 1
	c.Parent = group
	c:Play()
	local def = SfxIds[name]
	local life = (def and def.stop) or 6
	task.delay(life, function()
		if def and def.stop and c.IsPlaying then
			c:Stop()
		end
		c:Destroy()
	end)
end

-- The grill sizzles softly while any burger or steak is on it. The sound sits on your grill,
-- so it fades out as you walk away to the hub.
function Sfx.setSizzle(on: boolean, at: BasePart?)
	local s = sizzle
	if not s then
		return
	end
	local parent: Instance = at or group
	if s.Parent ~= parent then
		s.Parent = parent
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 70
	end
	if on and enabled then
		if not s.IsPlaying then
			s:Play()
		end
	elseif s.IsPlaying then
		s:Stop()
	end
end

return Sfx
