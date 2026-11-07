--!strict
-- One looping music bed, separate from sound effects.
-- Mute and volume are saved on the ranch. The default is quiet.
-- If Music.id is 0, nothing is loaded and nothing plays.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Track = require(Shared.Music)
local MusicPrefs = require(Shared.Logic.MusicPrefs)

local Music = {}
local group: SoundGroup? = nil
local bed: Sound? = nil
local playing = false

function Music.trackId(): number
	local id = (Track :: any).id
	return if type(id) == "number" then id else 0
end

function Music.available(): boolean
	return MusicPrefs.audible(Music.trackId())
end

function Music.mount()
	local g = Instance.new("SoundGroup")
	g.Name = "BackyardMusic"
	g.Volume = MusicPrefs.DEFAULT_VOLUME
	g.Parent = SoundService
	group = g
	local s = Instance.new("Sound")
	s.Name = "PorchLight"
	s.Looped = true
	s.Volume = 1
	s.SoundGroup = g
	s.Parent = g
	bed = s
	if Music.available() then
		s.SoundId = "rbxassetid://" .. tostring(Music.trackId())
	end
end

-- Apply saved prefs. Calling this every frame does not stack another copy.
function Music.apply(settings: any)
	local g = group
	local s = bed
	if not g or not s then
		return
	end
	local on, volume = MusicPrefs.read(settings)
	g.Volume = volume
	local shouldPlay = on and volume > 0 and Music.available()
	if not shouldPlay then
		if s.IsPlaying then
			s:Stop()
		end
		playing = false
		return
	end
	if playing and s.IsPlaying then
		return
	end
	if s.IsPlaying then
		return
	end
	s.SoundId = "rbxassetid://" .. tostring(Music.trackId())
	s.Looped = true
	s:Play()
	playing = true
end

return Music
