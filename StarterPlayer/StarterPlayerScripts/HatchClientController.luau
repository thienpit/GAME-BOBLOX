--!strict
--[[
    TÊN SCRIPT: HatchClientController
    LOẠI: LocalScript
    VỊ TRÍ: StarterPlayerScripts -> HatchClientController
    MÔ TẢ: Xử lý hiệu ứng đập trứng điện ảnh (TweenService Shake, Burst, Reveal Card)
          và hiệu ứng đặc biệt dành riêng cho thú cưng Legendary/Secret.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local hatchRemote = ReplicatedStorage:WaitForChild("HatchRemote") :: RemoteEvent

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

-- =============================================================================
-- 1. TẠO GIAO DIỆN SCREEN GUI CHO HIỆU ỨNG NỞ TRỨNG
-- =============================================================================
local hatchGui = Instance.new("ScreenGui")
hatchGui.Name = "HatchCinematicGui"
hatchGui.ResetOnSpawn = false
hatchGui.DisplayOrder = 100 -- Luôn nổi lên trên cùng
hatchGui.Parent = pGui

-- Màn đen mờ phủ toàn màn hình
local overlay = Instance.new("Frame")
overlay.Name = "DarkOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
overlay.BackgroundTransparency = 1
overlay.Visible = false
overlay.Parent = hatchGui

-- Tia hào quang xoay tròn (Dành cho Legendary/Secret)
local sunburst = Instance.new("ImageLabel")
sunburst.Name = "SunburstRay"
sunburst.AnchorPoint = Vector2.new(0.5, 0.5)
sunburst.Position = UDim2.new(0.5, 0, 0.45, 0)
sunburst.Size = UDim2.new(0, 0, 0, 0)
sunburst.Image = "rbxassetid://13840742116" -- Texture tia sáng tỏa tròn
sunburst.ImageColor3 = Color3.fromRGB(255, 220, 60)
sunburst.BackgroundTransparency = 1
sunburst.Visible = false
sunburst.Parent = overlay

-- Khung hiển thị Trứng đập vỡ
local eggFrame = Instance.new("Frame")
eggFrame.Name = "EggDisplay"
eggFrame.AnchorPoint = Vector2.new(0.5, 0.5)
eggFrame.Position = UDim2.new(0.5, 0, 0.45, 0)
eggFrame.Size = UDim2.new(0, 180, 0, 240)
eggFrame.BackgroundTransparency = 1
eggFrame.Visible = false
eggFrame.Parent = overlay

local eggIcon = Instance.new("TextLabel")
eggIcon.Name = "EggIcon"
eggIcon.Size = UDim2.new(1, 0, 1, 0)
eggIcon.Text = "🥚"
eggIcon.TextSize = 130
eggIcon.BackgroundTransparency = 1
eggIcon.Parent = eggFrame

-- Thẻ thông tin Thú Cưng nở ra (Pet Card ActionCard)
local card = Instance.new("Frame")
card.Name = "PetCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.45, 0)
card.Size = UDim2.new(0, 0, 0, 0) -- Bắt đầu từ kích thước 0 để phóng to
card.BackgroundColor3 = UITheme.Colors.DarkBg
card.BackgroundTransparency = 0.05
card.BorderSizePixel = 0
card.Visible = false
card.Parent = overlay

local cardCorner = UITheme.ApplyCorner(card, UITheme.CornerRadiusLarge)
local cardStroke = UITheme.ApplyStroke(card, UITheme.Colors.Money, UITheme.StrokeThicknessThick)

local petEmoji = Instance.new("TextLabel")
petEmoji.Name = "PetEmoji"
petEmoji.Size = UDim2.new(1, 0, 0.4, 0)
petEmoji.Position = UDim2.new(0, 0, 0.05, 0)
petEmoji.Text = "🪨"
petEmoji.TextSize = 80
petEmoji.BackgroundTransparency = 1
petEmoji.Parent = card

local petName = Instance.new("TextLabel")
petName.Name = "PetName"
petName.Size = UDim2.new(1, -20, 0, 32)
petName.Position = UDim2.new(0, 10, 0.46, 0)
petName.Text = "METEOR TITAN"
petName.TextColor3 = UITheme.Colors.White
petName.TextStrokeColor3 = UITheme.Colors.StrokeOutline
petName.TextStrokeTransparency = 0.2
petName.TextSize = 22
petName.Font = UITheme.Fonts.Header
petName.BackgroundTransparency = 1
petName.Parent = card

local rarityBadge = Instance.new("TextLabel")
rarityBadge.Name = "RarityBadge"
rarityBadge.Size = UDim2.new(1, -20, 0, 24)
rarityBadge.Position = UDim2.new(0, 10, 0.58, 0)
rarityBadge.Text = "LEGENDARY"
rarityBadge.TextColor3 = UITheme.Colors.Money
rarityBadge.TextStrokeColor3 = UITheme.Colors.StrokeOutline
rarityBadge.TextStrokeTransparency = 0.3
rarityBadge.TextSize = 15
rarityBadge.Font = UITheme.Fonts.Header
rarityBadge.BackgroundTransparency = 1
rarityBadge.Parent = card

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -20, 0, 24)
statsLabel.Position = UDim2.new(0, 10, 0.68, 0)
statsLabel.Text = "+$550/s (Giant 👑)"
statsLabel.TextColor3 = UITheme.Colors.Positive
statsLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
statsLabel.TextStrokeTransparency = 0.3
statsLabel.TextSize = 17
statsLabel.Font = UITheme.Fonts.Header
statsLabel.BackgroundTransparency = 1
statsLabel.Parent = card

local claimBtn = Instance.new("TextButton")
claimBtn.Name = "ClaimButton"
claimBtn.AnchorPoint = Vector2.new(0.5, 1)
claimBtn.Position = UDim2.new(0.5, 0, 0.95, 0)
claimBtn.Size = UDim2.new(0.85, 0, 0, 48)
claimBtn.BackgroundColor3 = UITheme.Colors.Positive
claimBtn.AutoButtonColor = false
claimBtn.Text = "AWESOME! ✨"
claimBtn.TextColor3 = UITheme.Colors.White
claimBtn.TextStrokeColor3 = UITheme.Colors.StrokeOutline
claimBtn.TextStrokeTransparency = 0.2
claimBtn.TextSize = 18
claimBtn.Font = UITheme.Fonts.Header
claimBtn.Parent = card

local btnCorner = UITheme.ApplyCorner(claimBtn, UITheme.CornerRadiusSmall)
local btnStroke = UITheme.ApplyStroke(claimBtn, UITheme.Colors.White, UITheme.StrokeThicknessThin)

claimBtn.MouseEnter:Connect(function()
    TweenService:Create(claimBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 230, 115) }):Play()
end)
claimBtn.MouseLeave:Connect(function()
    TweenService:Create(claimBtn, TweenInfo.new(0.15), { BackgroundColor3 = UITheme.Colors.Positive }):Play()
end)

-- =============================================================================
-- 2. HÀM CHẠY ANIMATION TWEENSERVICE ĐẬP TRỨNG
-- =============================================================================
local rarityColors = {
    Common    = Color3.fromRGB(200, 205, 215),
    Rare      = Color3.fromRGB(60, 160, 255),
    Epic      = UITheme.Colors.Rare,
    Legendary = UITheme.Colors.Money,
    Secret    = Color3.fromRGB(255, 60, 160),
    Awakened  = UITheme.Colors.Awakened,
}

local function PlayHatchAnimation(data: any)
    local petData = data.Pet or data
    local pName = petData.Name or petData.PetName or "Pebble Dog"
    local pRarity = petData.Rarity or "Common"
    local pSize = petData.Size or "Normal"
    local pMutation = petData.Mutation or "Normal"
    local pIncome = petData.TotalIncomePerSec or petData.Income or petData.BaseIncome or 1

    overlay.Visible = true
    overlay.BackgroundTransparency = 1
    eggFrame.Visible = true
    card.Visible = false
    card.Size = UDim2.new(0, 0, 0, 0)
    sunburst.Visible = false
    
    -- 1. Làm mờ màn hình
    TweenService:Create(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.4}):Play()
    
    -- 2. Trứng rung lắc 3 nhịp tăng dần cường độ (Shake Animation)
    local origPos = UDim2.new(0.5, 0, 0.45, 0)
    for shake = 1, 3 do
        local offset = shake * 9
        TweenService:Create(eggFrame, TweenInfo.new(0.06, Enum.EasingStyle.Sine), {Position = origPos + UDim2.new(0, -offset, 0, 0)}):Play()
        task.wait(0.06)
        TweenService:Create(eggFrame, TweenInfo.new(0.06, Enum.EasingStyle.Sine), {Position = origPos + UDim2.new(0, offset, 0, 0)}):Play()
        task.wait(0.06)
    end
    eggFrame.Position = origPos
    
    -- 3. Trứng nổ vỡ (Scale up and vanish)
    local tBurst = TweenService:Create(eggFrame, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 300, 0, 380)
    })
    tBurst:Play()
    tBurst.Completed:Wait()
    eggFrame.Visible = false
    eggFrame.Size = UDim2.new(0, 180, 0, 240)
    
    -- 4. Đổ dữ liệu vào Thẻ Thú Cưng
    local rColor = rarityColors[pRarity] or Color3.fromRGB(255, 255, 255)
    cardStroke.Color = rColor
    petName.Text = string.upper(pName)
    rarityBadge.Text = string.upper(pRarity) .. " • " .. string.upper(pSize)
    rarityBadge.TextColor3 = rColor
    
    local mutText = (pMutation ~= "None" and pMutation ~= "Normal") and (" (" .. pMutation .. " 👑)") or ""
    statsLabel.Text = string.format("+$%d/s%s", pIncome, mutText)
    
    -- 5. Nở ra thẻ với hiệu ứng nảy bật (Overshoot Bounce)
    card.Visible = true
    TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 300, 0, 380)
    }):Play()
    
    -- 6. HIỆU ỨNG ĐẶC BIỆT KHI TRÚNG LEGENDARY HOẶC SECRET!
    if pRarity == "Legendary" or pRarity == "Secret" then
        sunburst.Visible = true
        sunburst.ImageColor3 = rColor
        TweenService:Create(sunburst, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 650, 0, 650)}):Play()
        
        -- Vòng lặp xoay tròn tia hào quang liên tục
        task.spawn(function()
            while card.Visible do
                sunburst.Rotation = (sunburst.Rotation + 2) % 360
                task.wait(0.03)
            end
        end)
    end
end

local function CloseHatch()
    TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    TweenService:Create(sunburst, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 0, 0, 0)}):Play()
    local tOut = TweenService:Create(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
    tOut:Play()
    tOut.Completed:Wait()
    overlay.Visible = false
    card.Visible = false
end

claimBtn.MouseButton1Click:Connect(CloseHatch)

-- =============================================================================
-- 3. BẮT SỰ KIỆN TỪ SERVER (REMOTEEVENT)
-- =============================================================================
hatchRemote.OnClientEvent:Connect(function(action: string, payload: any)
    if action == "HatchReveal" then
        PlayHatchAnimation(payload)
    elseif action == "GlobalAnnouncement" then
        -- Banner thông báo toàn server khi có người trúng đồ quý
        print(string.format("🌟 [SERVER] %s just hatched %s (%s)! 🌟", payload.Winner, payload.PetName, payload.Rarity))
    end
end)
