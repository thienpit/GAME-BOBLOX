--!strict
--[[
    TÊN SCRIPT: StatBadge
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> Shared -> Components -> StatBadge
    MÔ TẢ: Component chuẩn hiển thị chỉ số (Tiền, Tốc độ, Multiplier, Rock mang theo...)
          với icon nổi bật phía trước, số liệu font chunky to rõ ràng, bo góc,
          viền nổi khối, UIGradient chiều sâu và Soft Shadow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UITheme = require(ReplicatedStorage.Shared.UITheme)

export type StatBadgeConfig = {
    Icon: string,
    Value: string | number,
    Label: string?,
    AccentColor: Color3?,
    Size: UDim2?,
    Position: UDim2?,
    Parent: GuiObject | ScreenGui?,
}

local StatBadge = {}
StatBadge.__index = StatBadge

function StatBadge.new(config: StatBadgeConfig)
    local self = setmetatable({}, StatBadge)
    local accent = config.AccentColor or UITheme.Colors.Money

    -- Frame container
    local frame = Instance.new("Frame")
    frame.Name = "StatBadge_" .. (config.Label or "Value")
    frame.Size = config.Size or UDim2.new(0, 160, 0, 48)
    frame.Position = config.Position or UDim2.new(0, 0, 0, 0)
    frame.BackgroundColor3 = UITheme.Colors.Neutral
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.ZIndex = 2

    local corner = UITheme.ApplyCorner(frame, UITheme.CornerRadiusSmall)
    local stroke = UITheme.ApplyStroke(frame, accent, UITheme.StrokeThickness)
    
    -- Áp dụng visual juice: Gradient & Shadow
    UITheme.ApplyShadow(frame, 3, UITheme.Colors.Shadow, 0.5)
    UITheme.ApplyGradient(frame)

    -- Layout & Icon
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "Icon"
    iconLabel.Size = UDim2.new(0, 42, 1, 0)
    iconLabel.Position = UDim2.new(0, 6, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = config.Icon or "⭐"
    iconLabel.TextSize = 24
    iconLabel.ZIndex = 3
    iconLabel.Parent = frame

    -- Label phụ (nếu có, VD: "CASH", "SPEED", "ROCK")
    local subLabel: TextLabel? = nil
    if config.Label and config.Label ~= "" then
        subLabel = Instance.new("TextLabel")
        subLabel.Name = "Label"
        subLabel.Size = UDim2.new(1, -54, 0, 16)
        subLabel.Position = UDim2.new(0, 48, 0, 4)
        subLabel.BackgroundTransparency = 1
        subLabel.Font = UITheme.Fonts.Header
        subLabel.Text = string.upper(config.Label)
        subLabel.TextColor3 = UITheme.Colors.Muted
        subLabel.TextSize = 10
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.ZIndex = 3
        subLabel.Parent = frame
    end

    -- Value text (số liệu font chunky)
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    if subLabel then
        valueLabel.Size = UDim2.new(1, -54, 1, -20)
        valueLabel.Position = UDim2.new(0, 48, 0, 18)
        valueLabel.TextSize = 18
    else
        valueLabel.Size = UDim2.new(1, -54, 1, 0)
        valueLabel.Position = UDim2.new(0, 48, 0, 0)
        valueLabel.TextSize = 20
    end
    valueLabel.BackgroundTransparency = 1
    valueLabel.Font = UITheme.Fonts.Header
    valueLabel.TextColor3 = accent
    valueLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    valueLabel.TextStrokeTransparency = 0.3
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
    valueLabel.ZIndex = 3

    local initialStr = typeof(config.Value) == "number" and UITheme.FormatNumber(config.Value) or tostring(config.Value)
    valueLabel.Text = initialStr
    valueLabel.Parent = frame

    if config.Parent then
        frame.Parent = config.Parent
    end

    self.Frame = frame
    self.IconLabel = iconLabel
    self.ValueLabel = valueLabel
    self.SubLabel = subLabel
    self.Stroke = stroke
    self.AccentColor = accent

    return self
end

function StatBadge:SetValue(val: string | number, animated: boolean?)
    local strVal = typeof(val) == "number" and UITheme.FormatNumber(val) or tostring(val)
    if self.ValueLabel.Text == strVal then return end

    self.ValueLabel.Text = strVal

    if animated ~= false then
        -- Hiệu ứng nảy số (Punch Pop Scale) mượt mà
        local origSize = self.ValueLabel.TextSize
        self.ValueLabel.TextSize = origSize + 4
        
        -- Pop tween nhẹ trên icon
        local twInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local twBack = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        pcall(function()
            local tw1 = TweenService:Create(self.IconLabel, twInfo, { TextSize = 28 })
            tw1:Play()
            tw1.Completed:Connect(function()
                TweenService:Create(self.IconLabel, twBack, { TextSize = 24 }):Play()
            end)
        end)

        task.delay(0.12, function()
            if self.ValueLabel then
                self.ValueLabel.TextSize = origSize
            end
        end)
    end
end

function StatBadge:SetIcon(icon: string)
    self.IconLabel.Text = icon
end

function StatBadge:SetAccentColor(color: Color3)
    self.AccentColor = color
    self.ValueLabel.TextColor3 = color
    self.Stroke.Color = color
end

function StatBadge:SetVisible(visible: boolean)
    self.Frame.Visible = visible
end

function StatBadge:Destroy()
    if self.Frame then
        self.Frame:Destroy()
    end
end

return StatBadge
