--!strict
--[[
    TÊN SCRIPT: UITheme
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> Shared -> UITheme
    MÔ TẢ: Design System chuẩn hoá cho toàn bộ giao diện Rock Simulator.
          Bao gồm bảng màu (bổ sung tông ấm), bo góc, viền chunky, UIGradient,
          soft shadow, và các hàm tiện ích định dạng số (K, M, B).
]]

export type ColorTheme = {
    Money: Color3,
    Positive: Color3,
    Danger: Color3,
    Rare: Color3,
    Awakened: Color3,
    Neutral: Color3,
    DarkBg: Color3,
    White: Color3,
    Muted: Color3,
    SubtleBorder: Color3,
    StrokeOutline: Color3,
    CardBg: Color3,
    -- Bổ sung tông ấm & gradient
    AccentWarm: Color3,
    Gold: Color3,
    Coral: Color3,
    Shadow: Color3,
    CardGradientTop: Color3,
    CardGradientBottom: Color3,
}

local UITheme = {
    Colors = {
        Money = Color3.fromRGB(255, 214, 51),       -- Vàng kim cho tiền, thưởng, VIP
        Positive = Color3.fromRGB(76, 209, 90),     -- Xanh lá cho action tích cực: Deliver, Sell, Owned, 2x
        Danger = Color3.fromRGB(255, 82, 82),       -- Đỏ cảnh báo nguy hiểm, cướp đá, hủy
        Rare = Color3.fromRGB(178, 102, 255),       -- Tím huyền bí cho Rock / Pet hiếm
        Awakened = Color3.fromRGB(0, 224, 255),     -- Cyan dạ quang cho Rock Thức Tỉnh / Pet Thần Thoại
        Neutral = Color3.fromRGB(30, 34, 46),       -- Nền panel tối nổi khối
        DarkBg = Color3.fromRGB(16, 20, 28),        -- Nền sâu cho modal dialogs
        CardBg = Color3.fromRGB(24, 28, 40),        -- Nền card trong grid
        White = Color3.fromRGB(255, 255, 255),      -- Chữ chính
        Muted = Color3.fromRGB(160, 168, 185),      -- Chữ phụ / subtitle
        SubtleBorder = Color3.fromRGB(50, 58, 78),  -- Viền ngăn cách nhẹ
        StrokeOutline = Color3.fromRGB(12, 14, 20), -- Viền bóng đen tạo cảm giác chunky
        
        -- Bổ sung tông ấm theo VISUAL_UPGRADE_PLAN Phase 2
        AccentWarm = Color3.fromRGB(255, 150, 40),        -- Cam rực rỡ
        Gold = Color3.fromRGB(255, 215, 30),              -- Vàng ánh kim cao cấp
        Coral = Color3.fromRGB(255, 95, 85),              -- Đỏ san hô năng động
        Shadow = Color3.fromRGB(10, 12, 18),              -- Bóng đổ sâu
        CardGradientTop = Color3.fromRGB(38, 42, 56),     -- Đỉnh card nổi sáng nhẹ
        CardGradientBottom = Color3.fromRGB(20, 23, 32),  -- Đáy card chìm tối
    },

    CornerRadius = UDim.new(0, 18),
    CornerRadiusSmall = UDim.new(0, 10),
    CornerRadiusLarge = UDim.new(0, 24),
    
    StrokeThickness = 3,
    StrokeThicknessThin = 2,
    StrokeThicknessThick = 4,

    Fonts = {
        Header = Enum.Font.FredokaOne,
        Body = Enum.Font.GothamBold,
        Number = Enum.Font.FredokaOne,
    },

    IconMap = {
        Coin = "🪙",
        Money = "💵",
        Weight = "⚖️",
        Speed = "⚡",
        Rock = "🪨",
        Egg = "🥚",
        Gem = "💎",
        Check = "✅",
        Danger = "⚠️",
        Crown = "👑",
        Star = "⭐",
        Lock = "🔒",
        Bag = "🎒",
    }
}

-- Định dạng số simulator rút gọn: 1.5K, 2.4M, 10B...
function UITheme.FormatNumber(val: number): string
    if not val or val ~= val then return "0" end
    local absVal = math.abs(val)
    local sign = val < 0 and "-" or ""
    if absVal >= 1e12 then
        return string.format("%s%.2fT", sign, absVal / 1e12)
    elseif absVal >= 1e9 then
        return string.format("%s%.2fB", sign, absVal / 1e9)
    elseif absVal >= 1e6 then
        return string.format("%s%.2fM", sign, absVal / 1e6)
    elseif absVal >= 1e3 then
        return string.format("%s%.1fK", sign, absVal / 1e3)
    else
        return string.format("%s%d", sign, math.floor(absVal))
    end
end

-- Helper tạo viền chuẩn UIStroke
function UITheme.ApplyStroke(target: GuiObject, color: Color3?, thickness: number?): UIStroke
    local existing = target:FindFirstChildOfClass("UIStroke")
    local stroke = existing or Instance.new("UIStroke")
    stroke.Thickness = thickness or UITheme.StrokeThickness
    stroke.Color = color or UITheme.Colors.SubtleBorder
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = target
    return stroke
end

-- Helper tạo bo góc chuẩn UICorner
function UITheme.ApplyCorner(target: GuiObject, radius: UDim?): UICorner
    local existing = target:FindFirstChildOfClass("UICorner")
    local corner = existing or Instance.new("UICorner")
    corner.CornerRadius = radius or UITheme.CornerRadius
    corner.Parent = target
    return corner
end

-- [MỚI] Helper tạo hiệu ứng dải màu UIGradient nổi khối
function UITheme.ApplyGradient(target: GuiObject, colorSequence: ColorSequence?, rotation: number?): UIGradient
    local existing = target:FindFirstChildOfClass("UIGradient")
    local grad = existing or Instance.new("UIGradient")
    grad.Rotation = rotation or 90
    grad.Color = colorSequence or ColorSequence.new({
        ColorSequenceKeypoint.new(0, UITheme.Colors.CardGradientTop),
        ColorSequenceKeypoint.new(1, UITheme.Colors.CardGradientBottom)
    })
    grad.Parent = target
    return grad
end

-- [MỚI] Helper tạo bóng đổ mềm (Soft Depth Shadow) không chặn input
function UITheme.ApplyShadow(target: GuiObject, offsetY: number?, color: Color3?, transparency: number?): Frame
    target.ZIndex = math.max(2, target.ZIndex)
    
    local existing = target:FindFirstChild("UITheme_Shadow") :: Frame?
    local shadow = existing or Instance.new("Frame")
    shadow.Name = "UITheme_Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 0, 0.5, offsetY or 4)
    shadow.Size = UDim2.new(1, 0, 1, 0)
    shadow.BackgroundColor3 = color or UITheme.Colors.Shadow
    shadow.BackgroundTransparency = transparency or 0.55
    shadow.BorderSizePixel = 0
    shadow.ZIndex = target.ZIndex - 1
    shadow.Active = false
    shadow.Selectable = false
    
    local targetCorner = target:FindFirstChildOfClass("UICorner")
    if targetCorner then
        local sCorner = shadow:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
        sCorner.CornerRadius = targetCorner.CornerRadius
        sCorner.Parent = shadow
    end
    
    shadow.Parent = target
    return shadow
end

return UITheme
