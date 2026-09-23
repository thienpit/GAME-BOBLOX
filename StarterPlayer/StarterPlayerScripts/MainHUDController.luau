--!strict
--[[
    TÊN SCRIPT: MainHUDController
    LOẠI: LocalScript
    VỊ TRÍ: StarterPlayerScripts -> MainHUDController
    MÔ TẢ: HUD chính phong cách Simulator hiện đại (Pet Sim / Steal a Brainrot).
          Hiển thị dạng thanh Capsule hàng ngang ở đỉnh màn hình (Top Bar),
          giải phóng 100% không gian góc dưới trái cho Thumbstick di chuyển trên Mobile:
          - StatBadge Tiền ($ Cash) bind trực tiếp từ leaderstats.Money kèm hiệu ứng punch scale
          - StatBadge Tốc độ (⚡ Speed) bind trực tiếp từ leaderstats.Speed
          - Multiplier Badge (🔥 2X ACTIVE) tự kích hoạt khi có gamepass HasDoubleMoney
          - StatBadge Vật phẩm đang vác (🎒 Holding Rock/Egg)
          Tuyệt đối không tự tính toán số liệu ở client; cập nhật 100% theo data server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local StatBadge = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Components"):WaitForChild("StatBadge"))

-- 1. TẠO SCREEN GUI HUD CHÍNH
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "MainSimulatorHUD"
hudGui.ResetOnSpawn = false
hudGui.DisplayOrder = 5
hudGui.Parent = pGui

-- Container hàng ngang ở đỉnh màn hình (Top Center Simulator Capsule Bar)
local hudContainer = Instance.new("Frame")
hudContainer.Name = "HUDContainer"
hudContainer.AnchorPoint = Vector2.new(0.5, 0)
hudContainer.Position = UDim2.new(0.5, 0, 0, 8)
hudContainer.Size = UDim2.new(0, 600, 0, 44)
hudContainer.BackgroundTransparency = 1
hudContainer.Parent = hudGui

local hudList = Instance.new("UIListLayout")
hudList.FillDirection = Enum.FillDirection.Horizontal
hudList.HorizontalAlignment = Enum.HorizontalAlignment.Center
hudList.VerticalAlignment = Enum.VerticalAlignment.Center
hudList.Padding = UDim.new(0, 10)
hudList.SortOrder = Enum.SortOrder.LayoutOrder
hudList.Parent = hudContainer

-- 2. TẠO CÁC STAT BADGE THEO DESIGN SYSTEM
-- Badge Tiền ($ Money)
local moneyBadge = StatBadge.new({
    Icon = "💵",
    Label = "CASH",
    Value = 0,
    AccentColor = UITheme.Colors.Money,
    Size = UDim2.new(0, 140, 0, 40),
    Parent = hudContainer,
})
moneyBadge.Frame.LayoutOrder = 1

-- Badge Tốc độ (⚡ Speed)
local speedBadge = StatBadge.new({
    Icon = "⚡",
    Label = "SPEED",
    Value = 16,
    AccentColor = Color3.fromRGB(0, 215, 255),
    Size = UDim2.new(0, 125, 0, 40),
    Parent = hudContainer,
})
speedBadge.Frame.LayoutOrder = 2

-- Badge Trạng thái 2X MULTIPLIER (Chỉ hiện khi có Gamepass / Buff)
local boostBadge = StatBadge.new({
    Icon = "🔥",
    Label = "BOOST",
    Value = "2X ACTIVE",
    AccentColor = UITheme.Colors.Positive,
    Size = UDim2.new(0, 125, 0, 40),
    Parent = hudContainer,
})
boostBadge.Frame.LayoutOrder = 3
boostBadge:SetVisible(false)

-- Badge Vật phẩm đang vác (Carrying Rock/Egg)
local carryBadge = StatBadge.new({
    Icon = "🎒",
    Label = "HOLDING",
    Value = "EMPTY",
    AccentColor = UITheme.Colors.AccentWarm,
    Size = UDim2.new(0, 150, 0, 40),
    Parent = hudContainer,
})
carryBadge.Frame.LayoutOrder = 4
carryBadge:SetVisible(false)

-- =============================================================================
-- 3. BIND TRỰC TIẾP DỮ LIỆU TỪ SERVER (LEADERSTATS & ATTRIBUTES)
-- =============================================================================

-- Bind leaderstats (Money & Speed) kèm tween pop scale
local function HookLeaderstats(ls: Folder)
    local moneyVal = ls:WaitForChild("Money", 5) :: IntValue?
    if moneyVal and moneyVal:IsA("IntValue") then
        moneyBadge:SetValue(moneyVal.Value, false)
        moneyVal.Changed:Connect(function(newVal)
            moneyBadge:SetValue(newVal, true)
            pcall(function()
                local f = moneyBadge.Frame
                local origSize = UDim2.new(0, 140, 0, 40)
                local popSize = UDim2.new(0, 148, 0, 43)
                local tw1 = TweenService:Create(f, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = popSize })
                tw1:Play()
                tw1.Completed:Connect(function()
                    TweenService:Create(f, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = origSize }):Play()
                end)
            end)
        end)
    end

    local speedVal = ls:WaitForChild("Speed", 5) :: IntValue?
    if speedVal and speedVal:IsA("IntValue") then
        local function GetFormattedSpeed(pts: number): string
            if pts <= 0 then return "16 ⚡" end
            return string.format("%s ⚡", UpgradeConfig.FormatNumber(pts))
        end

        speedBadge:SetValue(GetFormattedSpeed(speedVal.Value), false)
        speedVal.Changed:Connect(function(newVal)
            speedBadge:SetValue(GetFormattedSpeed(newVal), true)
            pcall(function()
                local f = speedBadge.Frame
                local origSize = UDim2.new(0, 125, 0, 40)
                local popSize = UDim2.new(0, 132, 0, 43)
                local tw1 = TweenService:Create(f, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = popSize })
                tw1:Play()
                tw1.Completed:Connect(function()
                    TweenService:Create(f, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = origSize }):Play()
                end)
            end)
        end)
    end
end

local existingLs = player:FindFirstChild("leaderstats") :: Folder?
if existingLs then
    task.spawn(HookLeaderstats, existingLs)
end
player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" and child:IsA("Folder") then
        HookLeaderstats(child)
    end
end)

-- Bind Player Boost Attributes (HasDoubleMoney)
local function UpdateBoosts()
    local has2x = player:GetAttribute("HasDoubleMoney") == true
    boostBadge:SetVisible(has2x)
end
player:GetAttributeChangedSignal("HasDoubleMoney"):Connect(UpdateBoosts)
UpdateBoosts()

-- Bind Character Carrying Attributes
local function HookCharacter(char: Model)
    local function UpdateCarrying()
        local isCarryingRock = char:GetAttribute("IsCarryingRock") == true
        local isCarryingEgg = char:GetAttribute("IsCarryingEgg") == true
        
        if isCarryingRock or isCarryingEgg then
            local rockName = char:GetAttribute("CarryingRockName") or (isCarryingEgg and "Egg" or "Heavy Rock")
            local rockVal = char:GetAttribute("CarryingRockValue")
            if rockVal then
                carryBadge:SetValue(string.format("%s ($%s)", tostring(rockName), UITheme.FormatNumber(rockVal)), true)
            else
                carryBadge:SetValue(tostring(rockName), true)
            end
            carryBadge:SetVisible(true)
        else
            carryBadge:SetVisible(false)
        end
    end

    char:GetAttributeChangedSignal("IsCarryingRock"):Connect(UpdateCarrying)
    char:GetAttributeChangedSignal("IsCarryingEgg"):Connect(UpdateCarrying)
    char:GetAttributeChangedSignal("CarryingRockName"):Connect(UpdateCarrying)
    char:GetAttributeChangedSignal("CarryingRockValue"):Connect(UpdateCarrying)
    UpdateCarrying()
end

if player.Character then
    HookCharacter(player.Character)
end
player.CharacterAdded:Connect(HookCharacter)
