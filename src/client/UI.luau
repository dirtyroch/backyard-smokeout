--!strict
-- Tiny UI kit: everything is built in code, so no uploaded images are needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudMenu = require(Shared:WaitForChild("Logic"):WaitForChild("HudMenu"))
local HudLayout = require(Shared:WaitForChild("Logic"):WaitForChild("HudLayout"))
local Numbers = require(Shared:WaitForChild("Logic"):WaitForChild("Numbers"))

local UI = {}

UI.Theme = {
	-- "Night Market" palette. Deep navy panels, cream type, BBQ-orange actions.
	-- No wood-brown surfaces. Gold stays a light fill so ink is used on it.
	bg = Color3.fromHex("#12263F"),
	panel = Color3.fromHex("#1A3354"),
	card = Color3.fromHex("#234268"),
	cardHi = Color3.fromHex("#2C5282"),
	accent = Color3.fromHex("#F26B1D"),
	gold = Color3.fromHex("#FFD15A"),
	green = Color3.fromHex("#1F9D57"),
	red = Color3.fromHex("#E23B4A"),
	blue = Color3.fromHex("#3D8BFF"),
	gift = Color3.fromHex("#E23B6A"),
	text = Color3.fromHex("#F5F9FF"),
	dim = Color3.fromHex("#D3E2F5"),
	ink = Color3.fromHex("#102033"),
	paper = Color3.fromHex("#F4F7FB"),
	stroke = Color3.fromHex("#8FB4D8"),
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
	UI.compact = HudLayout.compact(v.X, v.Y)
end

UI.insets = { left = 0, top = 0, right = 0, bottom = 0 }

function UI.setInsets(insets: { left: number, top: number, right: number, bottom: number })
	UI.insets = insets
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
	return UI.new("UIStroke", { Color = color or T.stroke, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
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
	UI.corner(b, 12)
	UI.stroke(b, T.stroke, 1.5)
	UI.fitText(b, math.max(b.TextSize, 16), 14)
	if onClick then
		-- One press must run the handler once. A ScrollingFrame can fire
		-- Activated twice for that press. Deferring the handler used to
		-- finish it and clear the guard before the second event, so a toggle
		-- opened a panel and closed it again in the same click.
		local gate = HudMenu.guard()
		b.Activated:Connect(function()
			if not gate:allow() then
				return
			end
			if UI.onClick then
				pcall(function()
					(UI.onClick :: any)()
				end)
			end
			local ok, err = pcall(function(): any
				(onClick :: any)()
				return nil
			end)
			if not ok then
				warn(err)
			end
			task.defer(function()
				gate:release()
			end)
		end)
	end
	return b
end

function UI.bar(parent: Instance, color: Color3, props: Props?): (Frame, Frame)
	local back = UI.frame({ BackgroundColor3 = Color3.fromHex("#0C1A2E"), Size = UDim2.new(1, 0, 0, 12), Parent = parent })
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
	return Numbers.abbrev(n)
end

-- A gold coin built from frames. No uploaded image.
function UI.coin(parent: Instance, px: number?): Frame
	local s = px or 22
	local f = UI.new("Frame", {
		Name = "Coin",
		BackgroundColor3 = Color3.fromHex("#F5C518"),
		Size = UDim2.fromOffset(s, s),
		BorderSizePixel = 0,
		Active = false,
		Parent = parent,
	})
	UI.corner(f, s)
	UI.new("UIStroke", { Color = Color3.fromHex("#B8860B"), Thickness = math.max(1.5, s / 9), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	local shine = UI.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.fromHex("#FFF6C8"),
		Size = UDim2.fromScale(0.42, 0.26),
		Position = UDim2.fromScale(0.18, 0.14),
		BorderSizePixel = 0,
		Active = false,
		Parent = f,
	})
	UI.corner(shine, s)
	UI.new("TextLabel", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "$",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromHex("#8A5A00"),
		TextScaled = true,
		Active = false,
		Parent = f,
	})
	return f
end

-- Puts a coin and an abbreviated amount inside a button. Clicks still hit the button.
function UI.fillPrice(button: TextButton, prefix: string, amount: number)
	local old = button:FindFirstChild("PriceRow")
	if old then
		old:Destroy()
	end
	button.Text = ""
	local row = UI.new("Frame", {
		Name = "PriceRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = button.ZIndex + 1,
		Active = false,
		Parent = button,
	})
	local list = UI.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local function quiet(gui: GuiObject)
		gui.Active = false
		gui.Interactable = false
	end
	if prefix ~= "" then
		local word = UI.label(prefix, {
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = button.TextColor3,
			Font = T.bold,
			ZIndex = button.ZIndex + 2,
			Parent = row,
		})
		quiet(word)
	end
	local coin = UI.coin(row, 18)
	coin.LayoutOrder = 2
	coin.ZIndex = button.ZIndex + 2
	quiet(coin)
	local amt = UI.label(Numbers.abbrev(amount), {
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = button.TextColor3,
		Font = T.bold,
		LayoutOrder = 3,
		ZIndex = button.ZIndex + 2,
		Parent = row,
	})
	quiet(amt)
	quiet(row)
end

function UI.clear(parent: Instance)
	for _, c in ipairs(parent:GetChildren()) do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

return UI
