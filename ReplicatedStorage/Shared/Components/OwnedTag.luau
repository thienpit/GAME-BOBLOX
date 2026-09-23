--!strict
--[[
    TÊN SCRIPT: OwnedTag
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> Shared -> Components -> OwnedTag
    MÔ TẢ: Badge trạng thái sở hữu (Owned / Price Tag) chuẩn phong cách Simulator.
          Khi đã sở hữu: Hiển thị badge xanh lá "OWNED ✅" nổi bật.
          Khi chưa sở hữu: Hiển thị giá tiền "🪙 $500" font chunky vàng rực rỡ.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage.Shared.UITheme)

export type OwnedTagConfig = {
    IsOwned: boolean,
    Price: number?,
    CustomText: string?,
    Size: UDim2?,
    Position: UDim2?,
    Parent: GuiObject?,
}

local OwnedTag = {}
OwnedTag.__index = OwnedTag

function OwnedTag.new(config: OwnedTagConfig)
    local self = setmetatable({}, OwnedTag)

    local tag = Instance.new("Frame")
    tag.Name = "OwnedTag"
    tag.Size = config.Size or UDim2.new(0, 95, 0, 26)
    tag.Position = config.Position or UDim2.new(1, -6, 0, 6)
    tag.AnchorPoint = Vector2.new(1, 0)
    tag.BorderSizePixel = 0

    local corner = UITheme.ApplyCorner(tag, UDim.new(0, 8))
    local stroke = UITheme.ApplyStroke(tag, UITheme.Colors.White, UITheme.StrokeThicknessThin)

    local label = Instance.new("TextLabel")
    label.Name = "TagLabel"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = UITheme.Fonts.Header
    label.TextSize = 12
    label.TextColor3 = UITheme.Colors.White
    label.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    label.TextStrokeTransparency = 0.3
    label.Parent = tag

    if config.Parent then
        tag.Parent = config.Parent
    end

    self.Tag = tag
    self.Label = label
    self.Stroke = stroke

    self:SetOwned(config.IsOwned, config.Price, config.CustomText)

    return self
end

function OwnedTag:SetOwned(isOwned: boolean, price: number?, customText: string?)
    if isOwned then
        self.Tag.BackgroundColor3 = UITheme.Colors.Positive
        self.Stroke.Color = UITheme.Colors.Positive:Lerp(Color3.new(1, 1, 1), 0.3)
        self.Label.Text = customText or "OWNED ✅"
        self.Label.TextColor3 = UITheme.Colors.White
    else
        self.Tag.BackgroundColor3 = UITheme.Colors.Neutral
        self.Stroke.Color = UITheme.Colors.Money
        if price ~= nil then
            self.Label.Text = "🪙 " .. UITheme.FormatNumber(price)
            self.Label.TextColor3 = UITheme.Colors.Money
        else
            self.Label.Text = customText or "BUY"
            self.Label.TextColor3 = UITheme.Colors.Money
        end
    end
end

function OwnedTag:SetVisible(visible: boolean)
    self.Tag.Visible = visible
end

function OwnedTag:Destroy()
    if self.Tag then
        self.Tag:Destroy()
    end
end

return OwnedTag
