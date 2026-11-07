--!strict
-- Tiny UI kit: everything is built in code, so no uploaded images are needed.
local UI = {}

UI.Theme = {
	-- "Porch Light" palette. Warm BBQ browns, cream type, ember actions.
	-- Contrast vs #FFF8F0 (cream), checked as WCAG ratios:
	--   bg #3A2418 13.8:1, panel #4A2E1E 11.7:1, card #543524 10.4:1, cardHi #5C3A24 9.6:1
	--   dim #F3D2B4 on card 7.7:1
	--   accent #C2410C 4.9:1, green #146B34 6.3:1, red #B42318 6.2:1, blue #1D4E89 8.0:1, gift #9D174D 7.5:1
	-- Gold #FFD15A is a light fill: dark ink #2A140C on it is 12.1:1. Buttons pick ink or cream from the fill.
	bg = Color3.fromHex("#3A2418"),
	panel = Color3.fromHex("#4A2E1E"),
	card = Color3.fromHex("#543524"),
	cardHi = Color3.fromHex("#5C3A24"),
	accent = Color3.fromHex("#C2410C"),
	gold = Color3.fromHex("#FFD15A"),
	green = Color3.fromHex("#146B34"),
	red = Color3.fromHex("#B42318"),
	blue = Color3.fromHex("#1D4E89"),
	gift = Color3.fromHex("#9D174D"),
	text = Color3.fromHex("#FFF8F0"),
	dim = Color3.fromHex("#F3D2B4"),
	ink = Color3.fromHex("#2A140C"),
	paper = Color3.fromHex("#F6E2C4"),
	font = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}
local T = UI.Theme

-- Touch targets stay at least 44px. Compact is a short or narrow viewport (phones).
UI.TOUCH = 44
UI.viewport = Vector2.new(1280, 720)
UI.compact = false
UI.stationReserve = 188
UI.topChrome = 68

UI.onClick = nil :: (() -> ())?

type Props = { [string]: any }

local function channel(u: number): number
	return if u <= 0.04045 then u / 12.92 else ((u + 0.055) / 1.055) ^ 2.4
end

function UI.luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

function UI.contrast(a: Color3, b: Color3): number
	local l1 = UI.luminance(a)
	local l2 = UI.luminance(b)
	local hi, lo = math.max(l1, l2), math.min(l1, l2)
	return (hi + 0.05) / (lo + 0.05)
end

-- Cream on dark fills, ink on light fills (gold, paper).
function UI.labelOn(bg: Color3): Color3
	local cream = UI.contrast(T.text, bg)
	local ink = UI.contrast(T.ink, bg)
	return if cream >= ink then T.text else T.ink
end

function UI.setViewport(v: Vector2)
	UI.viewport = v
	UI.compact = v.X < 1000 or v.Y < 620
end

function UI.new(className: string, props: Props?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UI.corner(parent: Instance, r: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 12), Parent = parent })
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return UI.new("UIStroke", { Color = color or Color3.fromHex("#2A160E"), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function UI.pad(parent: Instance, px: number)
	return UI.new("UIPadding", { PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), Parent = parent })
end

function UI.list(parent: Instance, dir: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

function UI.frame(props: Props): Frame
	local f = UI.new("Frame", {
		BackgroundColor3 = T.panel,
		BorderSizePixel = 0,
	})
	for k, v in pairs(props) do
		(f :: any)[k] = v
	end
	return f
end

function UI.fitText(label: TextLabel | TextButton, maxSize: number, minSize: number?)
	local g = label :: any
	g.TextScaled = true
	g.TextWrapped = true
	UI.new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize or 14, Parent = label })
end

function UI.label(text: string, props: Props?): TextLabel
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.text,
		Font = T.font,
		TextScaled = false,
		TextSize = 20,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 28),
	})
	if props then
		for k, v in pairs(props) do
			(l :: any)[k] = v
		end
	end
	if l.TextSize < 15 and not l.TextScaled then
		l.TextSize = 15
	end
	return l
end

function UI.button(text: string, color: Color3?, props: Props?, onClick: (() -> ())?): TextButton
	local fill = color or T.accent
	local b = UI.new("TextButton", {
		Text = text,
		BackgroundColor3 = fill,
		TextColor3 = UI.labelOn(fill),
		Font = T.font,
		TextSize = 20,
		TextWrapped = true,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 160, 0, UI.TOUCH),
	})
	local explicitColor = props ~= nil and props.TextColor3 ~= nil
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	if not explicitColor then
		b.TextColor3 = UI.labelOn(b.BackgroundColor3)
	end
	if b.Size.Y.Scale == 0 and b.Size.Y.Offset > 0 and b.Size.Y.Offset < UI.TOUCH then
		b.Size = UDim2.new(b.Size.X.Scale, b.Size.X.Offset, 0, UI.TOUCH)
	end
	if b.Size.X.Scale == 0 and b.Size.X.Offset > 0 and b.Size.X.Offset < UI.TOUCH then
		b.Size = UDim2.new(0, UI.TOUCH, b.Size.Y.Scale, b.Size.Y.Offset)
	end
	UI.corner(b, 10)
	UI.stroke(b, Color3.fromHex("#2A160E"), 2)
	UI.fitText(b, math.max(b.TextSize, 16), 14)
	if onClick then
		local busy = false
		b.Activated:Connect(function()
			if UI.onClick then
				(UI.onClick :: any)()
			end
			if busy then
				return
			end
			busy = true
			task.spawn(function()
				local ok, err = pcall(function(): any
					(onClick :: any)()
					return nil
				end)
				if not ok then
					warn(err)
				end
				busy = false
			end)
		end)
	end
	return b
end

function UI.bar(parent: Instance, color: Color3, props: Props?): (Frame, Frame)
	local back = UI.frame({ BackgroundColor3 = Color3.fromHex("#2A160E"), Size = UDim2.new(1, 0, 0, 12), Parent = parent })
	if props then
		for k, v in pairs(props) do
			(back :: any)[k] = v
		end
	end
	UI.corner(back, 6)
	local fill = UI.frame({ BackgroundColor3 = color, Size = UDim2.new(0, 0, 1, 0), Parent = back })
	UI.corner(fill, 6)
	return back, fill
end

function UI.fmt(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

function UI.clear(parent: Instance)
	for _, c in ipairs(parent:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

return UI
