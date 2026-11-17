--!strict
-- Left-side HUD menu: which button opens which window, and how one click
-- is allowed to count once.
--
-- The menu sits in a ScrollingFrame. Roblox can deliver two Activated events
-- for a single press there (the button, then the frame's scroll-release).
-- Panel buttons toggle, so the second event used to open the window and
-- close it again before it ever painted. Invite does not toggle a window,
-- which is why it was the only button that still looked alive.
local HudMenu = {}

export type Entry = {
	id: string,
	icon: string,
	label: string,
	panel: string,
	order: number,
}

-- Invite is the only entry that does not open a Panels window.
HudMenu.entries = {
	{ id = "shop", icon = "🛒", label = "Pit Shop", panel = "shop", order = 1 },
	{ id = "season", icon = "🎟️", label = "Season", panel = "season", order = 2 },
	{ id = "sauce", icon = "🥫", label = "Sauce", panel = "sauce", order = 3 },
	{ id = "index", icon = "📖", label = "Index", panel = "index", order = 4 },
	{ id = "path", icon = "🗺️", label = "Path", panel = "path", order = 5 },
	{ id = "upgrades", icon = "⬆️", label = "Upgrade", panel = "upgrades", order = 6 },
	{ id = "crew", icon = "🍳", label = "Crew", panel = "crew", order = 7 },
	{ id = "daily", icon = "🎁", label = "Daily", panel = "daily", order = 8 },
	{ id = "settings", icon = "⚙️", label = "Settings", panel = "settings", order = 9 },
	{ id = "invite", icon = "👋", label = "Invite", panel = "invite", order = 10 },
} :: { Entry }

-- Scroller stays under the buttons. The hit target stays above the icon and caption.
HudMenu.SCROLL_Z = 1
HudMenu.HIT_Z = 6

export type Guard = {
	allow: (self: Guard) -> boolean,
	release: (self: Guard) -> (),
}

-- True for the first activation of a click. Stays closed until release, which
-- the button schedules with task.defer so a second event in the same press
-- cannot run the handler again.
function HudMenu.guard(): Guard
	local held = false
	local gate: Guard = {
		allow = function(_self: Guard): boolean
			if held then
				return false
			end
			held = true
			return true
		end,
		release = function(_self: Guard)
			held = false
		end,
	}
	return gate
end

-- Returns the panel that should be open afterwards, and whether to run the
-- invite flow. Invite never opens or closes a window.
function HudMenu.press(current: string?, panel: string): (string?, boolean)
	if panel == "invite" then
		return current, true
	end
	if current == panel then
		return nil, false
	end
	return panel, false
end

-- Icon, caption and the notification dot are drawn on the button. They must
-- not take the click. The hit button itself is a GuiButton and is left alone.
function HudMenu.releaseDecorations(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and not d:IsA("GuiButton") then
			local g = d :: GuiObject
			g.Active = false
			g.Interactable = false
			pcall(function()
				(g :: any).InputSink = Enum.InputSink.None
			end)
		end
	end
end

return HudMenu
