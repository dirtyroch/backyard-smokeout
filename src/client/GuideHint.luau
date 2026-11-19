--!strict
-- A short first-visit card and a gold arrow on the button the server asked us to try.
-- The server decides the step and when it is finished. Skip is saved on the profile.
local UI = require(script.Parent.UI)
local Hud = require(script.Parent.Hud)
local Net = require(script.Parent.Net)
local T = UI.Theme
local GOLD = Color3.fromHex("#FFD15A")

local GuideHint = {}
local refs: any = {}
local glowed: GuiObject? = nil

local function restoreGlow()
	local target = glowed
	glowed = nil
	if not target then
		return
	end
	local stroke = target:FindFirstChildOfClass("UIStroke")
	local r = target:GetAttribute("GuideR")
	if stroke and type(r) == "number" then
		stroke.Color = Color3.new(r, target:GetAttribute("GuideG") :: number, target:GetAttribute("GuideB") :: number)
		stroke.Thickness = target:GetAttribute("GuideThick") :: number
	end
	target:SetAttribute("GuideR", nil)
end

local function glow(target: GuiObject?)
	if glowed == target then
		return
	end
	restoreGlow()
	if not target then
		return
	end
	local stroke = target:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	target:SetAttribute("GuideR", stroke.Color.R)
	target:SetAttribute("GuideG", stroke.Color.G)
	target:SetAttribute("GuideB", stroke.Color.B)
	target:SetAttribute("GuideThick", stroke.Thickness)
	stroke.Color = GOLD
	stroke.Thickness = 3
	glowed = target
end

function GuideHint.mount(root: GuiObject)
	local card = UI.frame({
		Name = "GuideHint",
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	UI.corner(card, 12)
	UI.stroke(card, GOLD, 2)
	UI.pad(card, 8)
	refs.card = card
	refs.root = root
	refs.title = UI.label("", { Size = UDim2.new(1, -100, 0, 22), TextSize = 18, TextColor3 = GOLD, ZIndex = 9, Parent = card })
	refs.body = UI.label("", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -100, 1, -28), TextSize = 15, Font = T.body, TextColor3 = T.dim, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 9, Parent = card })
	refs.skip = UI.button("Skip", T.card, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 88, 1, -8), TextSize = 16, ZIndex = 9, Parent = card }, function()
		task.spawn(Net.act, "GuideSkip")
	end)
	refs.arrow = UI.label("▼", {
		Name = "GuideArrow",
		BackgroundTransparency = 1,
		Active = false,
		Size = UDim2.fromOffset(36, 28),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.4,
		Visible = false,
		ZIndex = 12,
		Parent = root,
	})
	GuideHint.applyLayout()
end

function GuideHint.applyLayout()
	local card = refs.card
	local b = Hud.box("guide")
	if not card or not b or b.w <= 0 or b.h <= 0 then
		return
	end
	local w = math.max(1, UI.viewport.X)
	local h = math.max(1, UI.viewport.Y)
	card.AnchorPoint = Vector2.new(0, 0)
	card.Position = UDim2.fromScale(b.x / w, b.y / h)
	card.Size = UDim2.fromScale(b.w / w, b.h / h)
end

local function pointAt(target: GuiObject)
	local arrow = refs.arrow
	local root = refs.root
	if not arrow or not root then
		return
	end
	local tp = target.AbsolutePosition
	local ts = target.AbsoluteSize
	local rp = root.AbsolutePosition
	local x = tp.X - rp.X + ts.X * 0.5 - 18
	local above = tp.Y - rp.Y - 30
	if above < 4 then
		arrow.Text = "▲"
		arrow.Position = UDim2.fromOffset(x, tp.Y - rp.Y + ts.Y + 2)
	else
		arrow.Text = "▼"
		arrow.Position = UDim2.fromOffset(x, above)
	end
	arrow.Visible = target.Visible and ts.X > 0
end

function GuideHint.update(s: any)
	if not refs.card then
		return
	end
	local g = if s and type(s.onboard) == "table" and s.onboard.title then s.onboard else s and s.guide
	if type(g) == "table" and g.title and g.active ~= false and s and type(s.onboard) == "table" then
		g = s.onboard
		g.active = true
	end
	if not g or g.active ~= true then
		refs.card.Visible = false
		if refs.arrow then
			refs.arrow.Visible = false
		end
		restoreGlow()
		return
	end
	refs.card.Visible = true
	refs.title.Text = string.format("%d/%d  %s", g.step or 1, g.total or 4, g.title or "")
	refs.body.Text = g.body or ""
	GuideHint.applyLayout()
	local banner = Hud.box("guide")
	refs.body.Visible = banner ~= nil and banner.h >= 56
	local target = if type(g.target) == "string" then Hud.guideTarget(g.target) else nil
	if target then
		Hud.reveal(g.target)
		glow(target)
		pointAt(target)
	else
		restoreGlow()
		if refs.arrow then
			refs.arrow.Visible = false
		end
	end
end

return GuideHint
