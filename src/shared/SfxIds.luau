--!strict
-- Sound effects. Every id is a public-domain sound from Roblox's own licensed library
-- (ProSoundEffects or the Roblox account), so the game needs no uploaded audio and nothing
-- here can be taken down for copyright. Swap a sound by changing one number.
-- `stop` cuts long files short (seconds). `volume` is relative to the SFX group.
return {
	click = { id = 15675059323, volume = 0.35 }, -- Roblox_UI_Bright_Click
	pop = { id = 15675055424, volume = 0.5 }, -- Roblox_UI_Cute_Pop
	popAiry = { id = 9117841338, volume = 0.5 }, -- Pop Airy 1
	spatula = { id = 9125594711, volume = 0.7 }, -- Grill Hits Metal Spatula Impacts On Skillet
	sear = { id = 9119165436, volume = 0.6 }, -- Sizzle Short And Explosive Sear 1
	sizzleLoop = { id = 9114542867, volume = 0.18, loop = true }, -- Fry Or Sizzle 1 (40 s loop)
	register = { id = 9113728756, volume = 0.55 }, -- Cash Register 5
	coins = { id = 9113849492, volume = 0.5 }, -- Coins Or Keys Jingle 6
	ding = { id = 9126073001, volume = 0.45 }, -- Synth Sparkle Tone High Pitch Bell Tone Ding
	bell = { id = 9113584163, volume = 0.6, stop = 2.6 }, -- Brass Hand Bell 1
	fanfare = { id = 9114898444, volume = 0.55 }, -- Kazoo Fanfare 3
	crunch = { id = 9113959343, volume = 0.8 }, -- Crack Egg Crunchy 11
	swat = { id = 9120907511, volume = 0.6 }, -- Wood Impact 5
}
