--!strict
-- Saved music preferences. Mute and volume are independent: muting does not
-- zero the volume, so unmuting comes back to the level the player picked.
local MusicPrefs = {}

MusicPrefs.DEFAULT_VOLUME = 0.22 -- quiet porch, not a blast

MusicPrefs.STEPS = {
	{ id = "quiet", label = "Quiet", volume = 0.22 },
	{ id = "easy", label = "Easy", volume = 0.4 },
	{ id = "full", label = "Full", volume = 0.7 },
}

function MusicPrefs.clamp(volume: any): number
	if type(volume) ~= "number" or volume ~= volume or volume == math.huge or volume == -math.huge then
		return MusicPrefs.DEFAULT_VOLUME
	end
	return math.clamp(volume, 0, 1)
end

function MusicPrefs.read(settings: any): (boolean, number)
	local on = true
	local volume = MusicPrefs.DEFAULT_VOLUME
	if type(settings) == "table" then
		if settings.music == false then
			on = false
		end
		if settings.musicVolume ~= nil then
			volume = MusicPrefs.clamp(settings.musicVolume)
		end
	end
	return on, volume
end

-- A Roblox audio id. 0 means the original file is in the repo and not uploaded yet,
-- so the client must stay silent instead of playing a placeholder.
function MusicPrefs.audible(trackId: any): boolean
	return type(trackId) == "number" and trackId > 0 and trackId == math.floor(trackId)
end

return MusicPrefs
