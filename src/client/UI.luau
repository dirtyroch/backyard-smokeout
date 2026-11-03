--!strict
-- Tiny UI kit: everything is built in code, so no uploaded images are needed.
local UI = {}

UI.Theme = {
	-- "Smoked Sunset" palette (see the plan page's Color & Look section). Warm, saturated
	-- action colors on deep smoked-chocolate panels; every button color keeps >= 3:1 with its
	-- label (WCAG large-text / UI-component minimum) and body text stays above 7:1.
	bg = Color3.fromHex("#24150E"),
	panel = Color3.fromHex("#3A2418"),
	card = Color3.fromHex("#4D301F"),
	cardHi = Color3.fromHex("#643F28"),
	accent = Color3.fromHex("#E8590C"), -- ember orange (white label 3.6:1)
	gold = Color3.fromHex("#FFC83C"), -- Robux/premium (dark label 11.8:1)
	green = Color3.fromHex("#1E9E4A"), -- go / collect (white label 3.5:1)
	red = Color3.fromHex("#D93636"), -- danger (white label 4.6:1)
	blue = Color3.fromHex("#2F7BD8"), -- info / social (white label 4.3:1)
	gift = Color3.fromHex("#C2378A"), -- gifting (white label 5.0:1)
	text = Color3.fromHex("#FFF6E6"), -- 13.5:1 on panel
	dim = Color3.fromHex("#D9C4A8"), -- 8.6:1 on panel
	font = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}
local T = UI.Theme
-- Set by Main.client to give every button a soft click (Sfx). Kept as a hook so UI has no dependencies.
UI.onClick = nil :: (() -> ())?

type Props = { [string]: any }

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
	return UI.new("UIStroke", { Color = color or Color3.fromHex("#1A0F0A"), Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
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

function UI.label(text: string, props: Props?): TextLabel
	local l = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.text,
		Font = T.font,
		TextScaled = false,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
	})
	if props then
		for k, v in pairs(props) do
			(l :: any)[k] = v
		end
	end
	return l
end

function UI.button(text: string, color: Color3?, props: Props?, onClick: (() -> ())?): TextButton
	local b = UI.new("TextButton", {
		Text = text,
		BackgroundColor3 = color or T.accent,
		TextColor3 = Color3.new(1, 1, 1),
		Font = T.font,
		TextSize = 18,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 140, 0, 40),
	})
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	UI.corner(b, 10)
	UI.stroke(b, Color3.fromHex("#1A0F0A"), 2)
	UI.new("UITextSizeConstraint", { MaxTextSize = b.TextSize, Parent = b })
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
	local back = UI.frame({ BackgroundColor3 = Color3.fromHex("#1A0F0A"), Size = UDim2.new(1, 0, 0, 10), Parent = parent })
	if props then
		for k, v in pairs(props) do
			(back :: any)[k] = v
		end
	end
	UI.corner(back, 5)
	local fill = UI.frame({ BackgroundColor3 = color, Size = UDim2.new(0, 0, 1, 0), Parent = back })
	UI.corner(fill, 5)
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
