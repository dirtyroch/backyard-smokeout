--!strict
-- Pixel boxes for the always-on HUD. The client turns these into scale coordinates
-- inside the safe area (notch, home indicator, top bar). Boxes never overlap.
local HudLayout = {}

export type Insets = { left: number, top: number, right: number, bottom: number }
export type Box = { x: number, y: number, w: number, h: number }
export type Options = {
	guide: boolean?,
	rookie: boolean?,
	goals: boolean?,
	hint: boolean?,
	first: boolean?,
}

export type Layout = {
	compact: boolean,
	horizontalMenu: boolean,
	safe: Box,
	currencies: Box,
	menu: Box,
	goals: Box,
	guide: Box,
	actions: Box,
	stations: Box,
	right: Box,
	status: Box,
	first: Box,
	hint: Box,
	rookie: Box,
	stationCard: { w: number, h: number },
	menuButton: { w: number, h: number },
}

function HudLayout.compact(width: number, height: number): boolean
	return width < 1000 or height < 620
end

function HudLayout.overlaps(a: Box, b: Box): boolean
	if a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0 then
		return false
	end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function HudLayout.inside(a: Box, bounds: Box): boolean
	if a.w <= 0 or a.h <= 0 then
		return true
	end
	local eps = 0.51
	return a.x >= bounds.x - eps and a.y >= bounds.y - eps and a.x + a.w <= bounds.x + bounds.w + eps and a.y + a.h <= bounds.y + bounds.h + eps
end

local function box(x: number, y: number, w: number, h: number): Box
	return { x = math.floor(x + 0.5), y = math.floor(y + 0.5), w = math.max(0, math.floor(w + 0.5)), h = math.max(0, math.floor(h + 0.5)) }
end

local function empty(): Box
	return box(0, 0, 0, 0)
end

local function insetsOf(insets: Insets?): Insets
	local src = insets or { left = 0, top = 0, right = 0, bottom = 0 }
	return {
		left = math.max(0, src.left or 0),
		top = math.max(0, src.top or 0),
		right = math.max(0, src.right or 0),
		bottom = math.max(0, src.bottom or 0),
	}
end

local function cardSize(stationW: number, stationH: number, compact: boolean): { w: number, h: number }
	local w = if compact then math.clamp(stationW * 0.42, 132, 168) else 176
	local ratio = if compact then (158 / 112) else (176 / 168)
	local h = math.floor(w / ratio + 0.5)
	if h > stationH - 8 then
		h = math.max(72, stationH - 8)
		w = math.floor(h * ratio + 0.5)
	end
	return { w = w, h = h }
end

local function phone(width: number, height: number, inset: Insets, opts: Options): Layout
	local gap = 4
	local x0 = inset.left
	local y0 = inset.top
	local availW = math.max(0, width - inset.left - inset.right)
	local availH = math.max(0, height - inset.top - inset.bottom)
	local safe = box(x0, y0, availW, availH)

	local topH = 48
	local menuH = 56
	local bannerH = if (opts.goals or opts.guide) then 40 else 0
	local actionH = 48
	local stationH = math.clamp(math.floor(availH * 0.28), 96, 132)
	local firstH = if opts.first then 52 else 0
	local hintH = if opts.hint then 32 else 0
	local rookieH = if opts.rookie then 88 else 0

	local function used(): number
		return topH + menuH + bannerH + rookieH + hintH + firstH + actionH + stationH + gap * 6
	end

	-- Drop the least important row first. The guide/goals banner and the core
	-- buttons stay until the screen is genuinely too short to hold them.
	local stationFloor = 80
	local guard = 0
	while used() > availH and guard < 100 do
		guard += 1
		if hintH > 0 then
			hintH = 0
		elseif rookieH > 0 then
			rookieH -= 4
		elseif stationH > stationFloor then
			stationH -= 4
		elseif firstH > 44 then
			firstH -= 4
		elseif menuH > 48 then
			menuH -= 4
		elseif topH > 40 then
			topH -= 4
		elseif firstH > 0 then
			firstH = 0
		elseif bannerH > 36 then
			bannerH -= 4
		elseif stationFloor > 64 then
			stationFloor = 64
		else
			break
		end
	end

	local y = y0
	local currencies = box(x0, y, availW, topH)
	y += topH + gap
	local menu = box(x0, y, availW, menuH)
	y += menuH + gap
	local showGuide = opts.guide == true and bannerH > 0
	local showGoals = opts.goals == true and not showGuide and bannerH > 0
	local goals = if showGoals then box(x0, y, availW, bannerH) else empty()
	local guide = if showGuide then box(x0, y, availW, bannerH) else empty()
	if bannerH > 0 then
		y += bannerH + gap
	end

	local bottom = y0 + availH
	local stations = box(x0, bottom - stationH, availW, stationH)
	local actions = box(x0, stations.y - gap - actionH, availW, actionH)
	local cursor = actions.y - gap
	local first = if firstH > 0 then box(x0 + 8, cursor - firstH, math.max(0, availW - 16), firstH) else empty()
	if firstH > 0 then
		cursor = first.y - gap
	end
	local hint = if hintH > 0 then box(x0 + 8, cursor - hintH, math.max(0, availW - 16), hintH) else empty()
	if hintH > 0 then
		cursor = hint.y - gap
	end
	local room = math.max(0, cursor - y)
	local rookH = math.min(rookieH, room)
	local rookie = if rookH > 0 then box(x0, y, availW, rookH) else empty()

	local buttons = math.max(44, math.min(menuH - 4, 56))
	return {
		compact = true,
		horizontalMenu = true,
		safe = safe,
		currencies = currencies,
		menu = menu,
		goals = goals,
		guide = guide,
		actions = actions,
		stations = stations,
		right = empty(),
		status = empty(),
		first = first,
		hint = hint,
		rookie = rookie,
		stationCard = cardSize(availW, stationH, true),
		menuButton = { w = 96, h = buttons },
	}
end

local function desktop(width: number, height: number, inset: Insets, opts: Options): Layout
	local x0 = inset.left
	local y0 = inset.top
	local availW = math.max(0, width - inset.left - inset.right)
	local availH = math.max(0, height - inset.top - inset.bottom)
	local safe = box(x0, y0, availW, availH)
	local menuW = 108
	local rightW = 188
	local gap = 8
	local topH = 52
	local stationH = math.clamp(math.floor(availH * 0.26), 156, 184)
	local topY = y0 + gap
	local midX = x0 + menuW + 12
	local midRight = x0 + availW - 12 - rightW
	local midW = math.max(0, midRight - gap - midX)
	local currencies = box(midX, topY, midW, topH)
	local row2 = topY + topH + gap
	local bannerH = if (opts.guide or opts.goals) then 44 else 0
	local rookieW = if opts.rookie then math.min(360, math.max(220, math.floor(availW * 0.28))) else 0
	local rookieX = x0 + availW - 16 - rookieW
	local goalLimit = if rookieW > 0 then math.max(0, rookieX - gap - midX) else midW
	local bannerW = math.min(520, goalLimit, midW)
	local showGuide = opts.guide == true and bannerH > 0 and bannerW > 0
	local showGoals = opts.goals == true and not showGuide and bannerH > 0 and bannerW > 0
	local goals = if showGoals then box(midX, row2, bannerW, bannerH) else empty()
	local guide = if showGuide then box(midX, row2, bannerW, bannerH) else empty()
	local rookie = if rookieW > 0 then box(rookieX, row2, rookieW, math.min(188, availH - (row2 - y0) - stationH - 24)) else empty()
	local menuY = row2 + (if bannerH > 0 then bannerH + gap else 0)
	local stations = box(midX, y0 + availH - gap - stationH, math.max(0, midW), stationH)
	local menu = box(x0 + 8, menuY, menuW, math.max(0, stations.y - gap - menuY))
	local rightH = 156
	local right = box(midRight, stations.y - gap - rightH, rightW, rightH)
	local statusW = math.min(300, math.max(0, right.x - gap - (midX + 200)))
	local status = if statusW >= 140 then box(right.x - gap - statusW, right.y, statusW, 96) else empty()
	local firstW = math.min(460, math.max(0, (if status.w > 0 then status.x else right.x) - gap - stations.x))
	local first = if opts.first and firstW >= 200 then box(stations.x, stations.y - gap - 64, firstW, 64) else empty()
	local hint = if opts.hint and first.w > 0 then box(stations.x, first.y - gap - 40, firstW, 40) else empty()
	if hint.y < menuY then
		hint = empty()
	end
	return {
		compact = false,
		horizontalMenu = false,
		safe = safe,
		currencies = currencies,
		menu = menu,
		goals = goals,
		guide = guide,
		actions = empty(),
		stations = stations,
		right = right,
		status = status,
		first = first,
		hint = hint,
		rookie = rookie,
		stationCard = cardSize(stations.w, stationH, false),
		menuButton = { w = 96, h = 72 },
	}
end

function HudLayout.compute(width: number, height: number, insets: Insets?, opts: Options?): Layout
	local inset = insetsOf(insets)
	local flags = opts or {}
	if HudLayout.compact(width, height) then
		return phone(width, height, inset, flags)
	end
	return desktop(width, height, inset, flags)
end

return HudLayout
