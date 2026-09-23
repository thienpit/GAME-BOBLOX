--!strict
--[[
    TÊN SCRIPT: ActionCard
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> Shared -> Components -> ActionCard
    MÔ TẢ: Thẻ / Panel hành động chuẩn hóa phong cách Simulator hiện đại.
          Bo góc lớn (18-24px), viền dày 3-4px nổi khối, typography chunky text,
          UIGradient chiều sâu, Soft Shadow và nút hành động to ở đáy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UITheme = require(ReplicatedStorage.Shared.UITheme)

export type ActionCardConfig = {
    Title: string,
    Subtitle: string?,
    Icon: string?,
    ActionText: string,
    ActionColor: Color3?,
    StrokeColor: Color3?,
    Size: UDim2?,
    Position: UDim2?,
    Parent: GuiObject | ScreenGui?,
}

local ActionCard = {}
ActionCard.__index = ActionCard

function ActionCard.new(config: ActionCardConfig)
    local self = setmetatable({}, ActionCard)

    local strokeColor = config.StrokeColor or UITheme.Colors.SubtleBorder
    local actionColor = config.ActionColor or UITheme.Colors.Positive

    -- Outer Card Frame
    local card = Instance.new("Frame")
    card.Name = "ActionCard_" .. string.gsub(config.Title, "%s+", "")
    card.Size = config.Size or UDim2.new(0, 380, 0, 260)
    card.Position = config.Position or UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = UITheme.Colors.DarkBg
    card.BorderSizePixel = 0
    card.ZIndex = 2

    local corner = UITheme.ApplyCorner(card, UITheme.CornerRadius)
    local stroke = UITheme.ApplyStroke(card, strokeColor, UITheme.StrokeThicknessThick)

    -- Áp dụng Soft Shadow & Gradient
    UITheme.ApplyShadow(card, 6, UITheme.Colors.Shadow, 0.45)
    UITheme.ApplyGradient(card)

    -- Header Icon
    local iconLabel: TextLabel? = nil
    if config.Icon and config.Icon ~= "" then
        iconLabel = Instance.new("TextLabel")
        iconLabel.Name = "CardIcon"
        iconLabel.Size = UDim2.new(1, 0, 0, 60)
        iconLabel.Position = UDim2.new(0, 0, 0, 16)
        iconLabel.BackgroundTransparency = 1
        iconLabel.Text = config.Icon
        iconLabel.TextSize = 46
        iconLabel.ZIndex = 3
        iconLabel.Parent = card
    end

    -- Header Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "CardTitle"
    local titleY = iconLabel and 80 or 20
    titleLabel.Size = UDim2.new(1, -30, 0, 32)
    titleLabel.Position = UDim2.new(0, 15, 0, titleY)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = UITheme.Fonts.Header
    titleLabel.Text = string.upper(config.Title)
    titleLabel.TextColor3 = UITheme.Colors.White
    titleLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    titleLabel.TextStrokeTransparency = 0.2
    titleLabel.TextSize = 20
    titleLabel.TextWrapped = true
    titleLabel.ZIndex = 3
    titleLabel.Parent = card

    -- Subtitle
    local subLabel: TextLabel? = nil
    if config.Subtitle and config.Subtitle ~= "" then
        subLabel = Instance.new("TextLabel")
        subLabel.Name = "CardSubtitle"
        subLabel.Size = UDim2.new(1, -30, 0, 44)
        subLabel.Position = UDim2.new(0, 15, 0, titleY + 34)
        subLabel.BackgroundTransparency = 1
        subLabel.Font = UITheme.Fonts.Body
        subLabel.Text = config.Subtitle
        subLabel.TextColor3 = UITheme.Colors.Muted
        subLabel.TextSize = 13
        subLabel.TextWrapped = true
        subLabel.ZIndex = 3
        subLabel.Parent = card
    end

    -- Body Container for custom content
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentArea"
    contentFrame.Size = UDim2.new(1, -30, 0, 60)
    contentFrame.Position = UDim2.new(0, 15, 0, titleY + (subLabel and 80 or 40))
    contentFrame.BackgroundTransparency = 1
    contentFrame.ZIndex = 3
    contentFrame.Parent = card

    -- Full-width Action Button
    local actionBtn = Instance.new("TextButton")
    actionBtn.Name = "ActionButton"
    actionBtn.Size = UDim2.new(1, -32, 0, 48)
    actionBtn.AnchorPoint = Vector2.new(0.5, 1)
    actionBtn.Position = UDim2.new(0.5, 0, 1, -16)
    actionBtn.BackgroundColor3 = actionColor
    actionBtn.AutoButtonColor = false
    actionBtn.Font = UITheme.Fonts.Header
    actionBtn.Text = string.upper(config.ActionText)
    actionBtn.TextColor3 = UITheme.Colors.White
    actionBtn.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    actionBtn.TextStrokeTransparency = 0.3
    actionBtn.TextSize = 18
    actionBtn.ZIndex = 3
    actionBtn.Parent = card

    local btnCorner = UITheme.ApplyCorner(actionBtn, UITheme.CornerRadiusSmall)
    local btnStroke = UITheme.ApplyStroke(actionBtn, UITheme.Colors.White, UITheme.StrokeThicknessThin)

    -- Hover & Click effects
    actionBtn.MouseEnter:Connect(function()
        TweenService:Create(actionBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = actionColor:Lerp(Color3.new(1, 1, 1), 0.15)
        }):Play()
    end)
    actionBtn.MouseLeave:Connect(function()
        TweenService:Create(actionBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundColor3 = actionColor
        }):Play()
    end)

    if config.Parent then
        card.Parent = config.Parent
    end

    self.Card = card
    self.TitleLabel = titleLabel
    self.SubLabel = subLabel
    self.IconLabel = iconLabel
    self.ContentArea = contentFrame
    self.ActionButton = actionBtn
    self.CardStroke = stroke

    return self
end

function ActionCard:OnAction(callback: () -> ())
    return self.ActionButton.MouseButton1Click:Connect(callback)
end

function ActionCard:SetTitle(title: string)
    self.TitleLabel.Text = string.upper(title)
end

function ActionCard:SetSubtitle(subtitle: string)
    if self.SubLabel then
        self.SubLabel.Text = subtitle
    end
end

function ActionCard:SetActionText(text: string)
    self.ActionButton.Text = string.upper(text)
end

function ActionCard:SetActionColor(color: Color3)
    self.ActionButton.BackgroundColor3 = color
end

function ActionCard:SetStrokeColor(color: Color3)
    self.CardStroke.Color = color
end

function ActionCard:OpenAnimated()
    self.Card.Visible = true
    local origSize = self.Card.Size
    self.Card.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(self.Card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = origSize
    }):Play()
end

function ActionCard:CloseAnimated(onComplete: (() -> ())?)
    local origSize = self.Card.Size
    local t = TweenService:Create(self.Card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    t:Play()
    t.Completed:Connect(function()
        self.Card.Visible = false
        self.Card.Size = origSize
        if onComplete then onComplete() end
    end)
end

function ActionCard:Destroy()
    if self.Card then
        self.Card:Destroy()
    end
end

return ActionCard
