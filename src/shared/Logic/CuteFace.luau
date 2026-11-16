--!strict
-- Original faces for the grill burger and the tomahawk steak.
-- Every offset is in the meat part's local space (Y up, -Z toward the yard path).
-- Features sit on the top surface and stay small, so the patty or steak color
-- (raw pink through cooked brown, or black when burnt) stays the doneness cue.
local CuteFace = {}

CuteFace.MAX_PARTS = 12

export type Spec = {
	name: string,
	size: { number },
	offset: { number },
	color: string,
	shape: string, -- "ball" | "block"
	material: string, -- "smooth" | "neon"
}

local KINDS: { [string]: string } = {
	burger = "patty",
	tomahawk = "steak",
}

function CuteFace.kind(meatId: string): string?
	return KINDS[meatId]
end

local function spec(list: { Spec }, name: string, sx: number, sy: number, sz: number, x: number, y: number, z: number, color: string, shape: string, material: string?)
	table.insert(list, {
		name = name,
		size = { sx, sy, sz },
		offset = { x, y, z },
		color = color,
		shape = shape,
		material = material or "smooth",
	})
end

local function eyeSize(span: number): number
	return math.clamp(span * 0.26, span * 0.2, 0.42)
end

-- Happy patty: matching sparkly eyes, rosy cheeks, a three-part smile.
-- Burnt patty: closed eyes, ashy cheeks, a frown. No sparkle.
local function patty(size: { number }, burnt: boolean): { Spec }
	local out: { Spec } = {}
	local span = math.min(size[1], size[3])
	local eye = eyeSize(span)
	local top = size[2] / 2
	local ex = math.min(size[1] * 0.2, size[1] / 2 - eye / 2 - span * 0.04)
	local ez = -size[3] * 0.02
	local eyeY = top + eye * 0.34
	local white = if burnt then "#D9D3CC" else "#FFF8F0"
	local pupil = if burnt then "#F2EBE3" else "#2A140C"
	local cheek = if burnt then "#A89890" else "#F4A0B0"
	for _, side in ipairs({ -1, 1 }) do
		local x = side * ex
		if burnt then
			spec(out, side < 0 and "EyeL" or "EyeR", eye * 0.92, eye * 0.22, eye * 0.28, x, top + eye * 0.12, ez, pupil, "block")
		else
			spec(out, side < 0 and "EyeL" or "EyeR", eye, eye * 0.92, eye * 0.72, x, eyeY, ez, white, "ball")
			spec(out, side < 0 and "PupilL" or "PupilR", eye * 0.4, eye * 0.46, eye * 0.28, x, eyeY + eye * 0.04, ez - eye * 0.22, pupil, "ball")
			spec(out, side < 0 and "ShineL" or "ShineR", eye * 0.2, eye * 0.2, eye * 0.12, x - side * eye * 0.12, eyeY + eye * 0.16, ez - eye * 0.26, "#FFFFFF", "ball", "neon")
		end
		spec(out, side < 0 and "CheekL" or "CheekR", eye * 0.42, eye * 0.2, eye * 0.32, side * (ex + eye * 0.42), top + eye * 0.08, ez - eye * 0.28, cheek, "ball")
	end
	local mouth = if burnt then "#E4DCD4" else "#5C2E2A"
	local mz = ez - eye * 0.95
	if burnt then
		spec(out, "FrownCenter", eye * 0.7, eye * 0.16, eye * 0.16, 0, top + eye * 0.2, mz, mouth, "block")
		spec(out, "FrownL", eye * 0.22, eye * 0.16, eye * 0.14, -eye * 0.42, top + eye * 0.08, mz + eye * 0.12, mouth, "ball")
		spec(out, "FrownR", eye * 0.22, eye * 0.16, eye * 0.14, eye * 0.42, top + eye * 0.08, mz + eye * 0.12, mouth, "ball")
	else
		spec(out, "SmileCenter", eye * 0.62, eye * 0.2, eye * 0.2, 0, top + eye * 0.08, mz, mouth, "ball")
		spec(out, "SmileL", eye * 0.24, eye * 0.18, eye * 0.16, -eye * 0.46, top + eye * 0.16, mz + eye * 0.16, mouth, "ball")
		spec(out, "SmileR", eye * 0.24, eye * 0.18, eye * 0.16, eye * 0.46, top + eye * 0.16, mz + eye * 0.16, mouth, "ball")
	end
	return out
end

-- Steak: one wide sparkly eye, one happy squint, a little "o" mouth, rosy cheeks,
-- and a pale bone nub on the far end so it reads as a tomahawk without covering the face.
local function steak(size: { number }, burnt: boolean): { Spec }
	local out: { Spec } = {}
	local span = math.min(size[1], size[3])
	-- The steak is a wide slab, so the eyes are a little bigger than the patty's
	-- or they disappear into the meat at grill distance.
	local eye = math.clamp(span * 0.36, span * 0.28, 0.55)
	local top = size[2] / 2
	local faceX = -size[1] * 0.06
	local ez = -size[3] * 0.04
	local white = if burnt then "#D9D3CC" else "#FFF8F0"
	local pupil = if burnt then "#F2EBE3" else "#2A140C"
	local cheek = if burnt then "#A89890" else "#F4A0B0"
	local lx = faceX - eye * 0.7
	local rx = faceX + eye * 0.72
	local eyeY = top + eye * 0.32
	if burnt then
		spec(out, "EyeL", eye * 0.9, eye * 0.2, eye * 0.26, lx, top + eye * 0.1, ez, pupil, "block")
		spec(out, "EyeR", eye * 0.7, eye * 0.18, eye * 0.22, rx, top + eye * 0.1, ez, pupil, "block")
	else
		spec(out, "EyeL", eye, eye * 0.9, eye * 0.7, lx, eyeY, ez, white, "ball")
		spec(out, "PupilL", eye * 0.38, eye * 0.44, eye * 0.26, lx, eyeY + eye * 0.02, ez - eye * 0.2, pupil, "ball")
		spec(out, "ShineL", eye * 0.18, eye * 0.18, eye * 0.1, lx - eye * 0.12, eyeY + eye * 0.16, ez - eye * 0.24, "#FFFFFF", "ball", "neon")
		-- squint: short and wide, still a smile in the eye, not a scowl
		spec(out, "Wink", eye * 0.78, eye * 0.28, eye * 0.32, rx, top + eye * 0.2, ez, white, "ball")
		spec(out, "WinkPupil", eye * 0.16, eye * 0.12, eye * 0.1, rx, top + eye * 0.22, ez - eye * 0.12, pupil, "ball")
	end
	spec(out, "CheekL", eye * 0.36, eye * 0.16, eye * 0.26, lx - eye * 0.55, top + eye * 0.06, ez - eye * 0.2, cheek, "ball")
	spec(out, "CheekR", eye * 0.32, eye * 0.14, eye * 0.22, rx + eye * 0.48, top + eye * 0.06, ez - eye * 0.16, cheek, "ball")
	local mouth = if burnt then "#E4DCD4" else "#5C2E2A"
	local mz = ez - eye * 0.85
	if burnt then
		spec(out, "FrownCenter", eye * 0.5, eye * 0.14, eye * 0.14, faceX, top + eye * 0.16, mz, mouth, "block")
	else
		spec(out, "Delight", eye * 0.28, eye * 0.26, eye * 0.22, faceX, top + eye * 0.1, mz, mouth, "ball")
	end
	local boneColor = if burnt then "#8A8078" else "#F3E6D0"
	spec(out, "Bone", size[1] * 0.16, size[2] * 0.7, size[3] * 0.22, size[1] * 0.34, 0, size[3] * 0.08, boneColor, "block")
	return out
end

function CuteFace.specs(meatId: string, size: { number }, burnt: boolean?): { Spec }
	local kind = KINDS[meatId]
	if not kind or type(size) ~= "table" then
		return {}
	end
	local sx = size[1]
	local sy = size[2]
	local sz = size[3]
	if type(sx) ~= "number" or type(sy) ~= "number" or type(sz) ~= "number" then
		return {}
	end
	if sx <= 0 or sy <= 0 or sz <= 0 then
		return {}
	end
	if kind == "patty" then
		return patty({ sx, sy, sz }, burnt == true)
	end
	return steak({ sx, sy, sz }, burnt == true)
end

-- Share of the top face covered by features that sit on it. The bone is excluded;
-- it lives on the end, not on the browning surface.
function CuteFace.topCoverage(specs: { Spec }, size: { number }): number
	local area = 0
	local top = size[2] / 2
	for _, s in ipairs(specs) do
		if s.name ~= "Bone" and s.offset[2] >= top - 0.02 then
			area += s.size[1] * s.size[3]
		end
	end
	return area / (size[1] * size[3])
end

return CuteFace
