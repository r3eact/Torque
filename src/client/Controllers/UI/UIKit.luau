-- UIKit: small helpers so every screen shares one modern look
-- (rounded panels, strokes, gradients, springy buttons).
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Theme = {
	Bg = Color3.fromRGB(14, 16, 26),
	Panel = Color3.fromRGB(24, 27, 42),
	Panel2 = Color3.fromRGB(36, 40, 62),
	Panel3 = Color3.fromRGB(50, 56, 84),
	Accent = Color3.fromRGB(0, 214, 255),
	Accent2 = Color3.fromRGB(255, 140, 36),
	Good = Color3.fromRGB(70, 220, 120),
	Bad = Color3.fromRGB(255, 80, 96),
	Gold = Color3.fromRGB(255, 200, 60),
	Text = Color3.fromRGB(242, 245, 255),
	Muted = Color3.fromRGB(150, 158, 188),
}
UIKit.Fonts = {
	Title = Enum.Font.FredokaOne,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}

-- Generic constructor: UIKit.new("Frame", { Size = ..., Parent = x }, { children })
function UIKit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent: Instance, radius: number?)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return UIKit.new("UIStroke", {
		Color = color or UIKit.Theme.Panel3,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.padding(parent: Instance, px: number)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3)
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

function UIKit.list(parent: Instance, padding: number?, horizontal: boolean?)
	return UIKit.new("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

function UIKit.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

function UIKit.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Bold,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 18,
		TextWrapped = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return UIKit.new("TextLabel", defaults)
end

function UIKit.panel(props: { [string]: any }): Frame
	local defaults = {
		BackgroundColor3 = UIKit.Theme.Panel,
		BorderSizePixel = 0,
	}
	for k, v in props do
		defaults[k] = v
	end
	local frame = UIKit.new("Frame", defaults)
	UIKit.corner(frame, props.Radius)
	return frame
end

-- A springy button. `onClick` fires on mouse, touch and gamepad (Activated).
function UIKit.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local color = props.Color or UIKit.Theme.Accent
	local defaults = {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = UIKit.Fonts.Title,
		TextColor3 = UIKit.Theme.Text,
		TextSize = 20,
		Text = "",
	}
	for k, v in props do
		if k ~= "Color" and k ~= "Radius" then
			defaults[k] = v
		end
	end
	local button = UIKit.new("TextButton", defaults) :: TextButton
	button:SetAttribute("BaseColor", color)
	UIKit.corner(button, props.Radius or 10)
	UIKit.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 210))
	local scale = UIKit.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UIKit.setButtonColor(button: GuiButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
end

-- Removes all children except layout objects (used when re-rendering lists).
function UIKit.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIGridStyleLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

-- A progress bar; returns (frame, setProgress(0..1))
function UIKit.bar(props: { [string]: any }, fillColor: Color3)
	local back = UIKit.panel({
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = UIKit.Theme.Bg,
		Radius = 8,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	local fill = UIKit.panel({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = fillColor,
		Radius = 8,
		Parent = back,
	})
	UIKit.gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200))
	local function set(alpha: number, instant: boolean?)
		local size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		if instant then
			fill.Size = size
		else
			UIKit.tween(fill, 0.25, { Size = size })
		end
	end
	return back, set, fill
end

return UIKit
