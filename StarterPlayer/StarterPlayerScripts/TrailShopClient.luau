--!strict
--[[
    SCRIPT: TrailShopClient
    TYPE: LocalScript (Client-side)
    LOCATION: StarterPlayerScripts -> TrailShopClient
    DESCRIPTION: Clean 3D Trail Stall UI (Modal popup).
                 Opens instantly when interacting with Deco_TrailShopStall in village plaza,
                 or via the 💨 TRAIL button in FloatingDock.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local TrailConfig = require(ReplicatedStorage:WaitForChild("TrailConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))

local trailRemote = ReplicatedStorage:WaitForChild("TrailShopRemote") :: RemoteEvent

-- 1. SCREEN GUI
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "TrailShopGui"
shopGui.ResetOnSpawn = false
shopGui.DisplayOrder = 25
shopGui.Parent = pGui

local overlay = Instance.new("TextButton")
overlay.Name = "BackgroundOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 30
overlay.Parent = shopGui

local modal = Instance.new("Frame")
modal.Name = "TrailModal"
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.Size = UDim2.new(0, 540, 0, 420)
modal.BackgroundColor3 = UITheme.Colors.DarkBg
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 35
modal.Parent = shopGui

UITheme.ApplyCorner(modal, UITheme.CornerRadius)
UITheme.ApplyStroke(modal, Color3.fromRGB(0, 220, 255), UITheme.StrokeThicknessThick)
UITheme.ApplyShadow(modal, 6, UITheme.Colors.Shadow, 0.45)
UITheme.ApplyGradient(modal)

-- Header Title
local header = Instance.new("TextLabel")
header.Name = "HeaderTitle"
header.Size = UDim2.new(1, -60, 0, 36)
header.Position = UDim2.new(0, 20, 0, 14)
header.Text = "💨 SẠP VỆT TỐC ĐỘ (SPEED TRAILS)"
header.TextColor3 = Color3.fromRGB(0, 225, 255)
header.TextSize = 18
header.Font = UITheme.Fonts.Header
header.TextXAlignment = Enum.TextXAlignment.Left
header.BackgroundTransparency = 1
header.ZIndex = 36
header.Parent = modal

local subHeader = Instance.new("TextLabel")
subHeader.Name = "SubHeader"
subHeader.Size = UDim2.new(1, -60, 0, 20)
subHeader.Position = UDim2.new(0, 20, 0, 48)
subHeader.Text = "Mở khóa bằng SpeedPoints để tăng tốc độ luyện tập trên máy chạy bộ!"
subHeader.TextColor3 = UITheme.Colors.Muted
subHeader.TextSize = 12
subHeader.Font = UITheme.Fonts.Body
subHeader.TextXAlignment = Enum.TextXAlignment.Left
subHeader.BackgroundTransparency = 1
subHeader.ZIndex = 36
subHeader.Parent = modal

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 14)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = UITheme.Fonts.Header
closeBtn.ZIndex = 37
closeBtn.Parent = modal
UITheme.ApplyCorner(closeBtn, UITheme.CornerRadiusSmall)

-- Scrolling Grid Area
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "TrailList"
scroll.Size = UDim2.new(1, -32, 1, -85)
scroll.Position = UDim2.new(0, 16, 0, 75)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 450)
scroll.ZIndex = 36
scroll.Parent = modal

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 236, 0, 132)
grid.CellPadding = UDim2.new(0, 12, 0, 12)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = scroll

-- Render Trail Cards
local function RefreshCards(speedPoints: number?, equippedTrail: string?)
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local currentPts = speedPoints or (player:GetAttribute("SpeedPoints") or 0)
    local curEquipped = equippedTrail or (player:GetAttribute("EquippedTrail") or "trail_dust")

    for _, tId in ipairs(TrailConfig.ORDER) do
        local info = TrailConfig.TRAILS[tId]
        if not info then continue end

        local card = Instance.new("Frame")
        card.Name = "Card_" .. tId
        card.BackgroundColor3 = UITheme.Colors.CardBg
        card.BorderSizePixel = 0
        card.ZIndex = 37
        card.Parent = scroll

        UITheme.ApplyCorner(card, UITheme.CornerRadiusSmall)
        local isUnlocked = currentPts >= info.UnlockPoints
        local isEquipped = (curEquipped == tId)

        local strokeColor = isEquipped and Color3.fromRGB(80, 255, 120) or (isUnlocked and Color3.fromRGB(0, 220, 255) or UITheme.Colors.SubtleBorder)
        UITheme.ApplyStroke(card, strokeColor, 2)
        UITheme.ApplyGradient(card)

        -- Title
        local tLabel = Instance.new("TextLabel")
        tLabel.Size = UDim2.new(1, -12, 0, 22)
        tLabel.Position = UDim2.new(0, 10, 0, 8)
        tLabel.Text = info.Name
        tLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        tLabel.TextSize = 14
        tLabel.Font = UITheme.Fonts.Header
        tLabel.TextXAlignment = Enum.TextXAlignment.Left
        tLabel.BackgroundTransparency = 1
        tLabel.ZIndex = 38
        tLabel.Parent = card

        -- Multiplier badge
        local multLabel = Instance.new("TextLabel")
        multLabel.Size = UDim2.new(1, -12, 0, 18)
        multLabel.Position = UDim2.new(0, 10, 0, 32)
        multLabel.Text = string.format("⚡ Tốc độ luyện: x%.1f", info.Multiplier)
        multLabel.TextColor3 = Color3.fromRGB(255, 215, 40)
        multLabel.TextSize = 12
        multLabel.Font = UITheme.Fonts.Body
        multLabel.TextXAlignment = Enum.TextXAlignment.Left
        multLabel.BackgroundTransparency = 1
        multLabel.ZIndex = 38
        multLabel.Parent = card

        -- Unlock Req
        local reqLabel = Instance.new("TextLabel")
        reqLabel.Size = UDim2.new(1, -12, 0, 16)
        reqLabel.Position = UDim2.new(0, 10, 0, 52)
        reqLabel.Text = string.format("Yêu cầu: %s Speed", UpgradeConfig.FormatNumber(info.UnlockPoints))
        reqLabel.TextColor3 = isUnlocked and UITheme.Colors.Positive or UITheme.Colors.Muted
        reqLabel.TextSize = 11
        reqLabel.Font = UITheme.Fonts.Body
        reqLabel.TextXAlignment = Enum.TextXAlignment.Left
        reqLabel.BackgroundTransparency = 1
        reqLabel.ZIndex = 38
        reqLabel.Parent = card

        -- Action Button
        local actBtn = Instance.new("TextButton")
        actBtn.Size = UDim2.new(1, -20, 0, 32)
        actBtn.AnchorPoint = Vector2.new(0.5, 1)
        actBtn.Position = UDim2.new(0.5, 0, 1, -8)
        actBtn.Font = UITheme.Fonts.Header
        actBtn.TextSize = 13
        actBtn.ZIndex = 39
        actBtn.Parent = card
        UITheme.ApplyCorner(actBtn, UDim.new(0, 8))

        if isEquipped then
            actBtn.Text = "ĐANG DÙNG ✅"
            actBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
            actBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actBtn.AutoButtonColor = false
        elseif isUnlocked then
            actBtn.Text = "TRANG BỊ ⚡"
            actBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
            actBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            actBtn.MouseButton1Click:Connect(function()
                trailRemote:FireServer("EquipTrail", tId)
                RefreshCards(currentPts, tId)
            end)
        else
            actBtn.Text = "CHƯA ĐẠT 🔒"
            actBtn.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
            actBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
            actBtn.AutoButtonColor = false
        end
    end
end

local function OpenModal()
    local curPts = player:GetAttribute("SpeedPoints") or 0
    local curTrail = player:GetAttribute("EquippedTrail") or "trail_dust"
    RefreshCards(curPts, curTrail)
    overlay.Visible = true
    overlay.BackgroundTransparency = 0.5
    modal.Size = UDim2.new(0, 540, 0, 420)
    modal.Visible = true
end

local function CloseModal()
    modal.Visible = false
    overlay.Visible = false
end

closeBtn.MouseButton1Click:Connect(CloseModal)
overlay.MouseButton1Click:Connect(CloseModal)

_G.OpenTrailShop = OpenModal

-- PROXIMITY PROMPT TRIGGER ON CLIENT (0ms latency!)
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
    if triggerPlayer == player and (prompt.Name == "TrailPrompt" or (prompt.Parent and prompt.Parent.Name == "Deco_StallCounter")) then
        OpenModal()
    end
end)

-- Listen to RemoteEvent Open from server
trailRemote.OnClientEvent:Connect(function(action: string, arg: any)
    if action == "OpenTrailShop" then
        OpenModal()
    elseif action == "EquipSuccess" and typeof(arg) == "string" then
        RefreshCards(player:GetAttribute("SpeedPoints") or 0, arg)
    end
end)

-- AUTO-SYNC: When modal becomes visible from any trigger (Dock button, 3D Stall, or Script)
modal:GetPropertyChangedSignal("Visible"):Connect(function()
    if modal.Visible then
        overlay.Visible = true
        local curPts = player:GetAttribute("SpeedPoints") or 0
        local curTrail = player:GetAttribute("EquippedTrail") or "trail_dust"
        RefreshCards(curPts, curTrail)
    end
end)

-- Initial populate on start
task.spawn(function()
    task.wait(0.5)
    local curPts = player:GetAttribute("SpeedPoints") or 0
    local curTrail = player:GetAttribute("EquippedTrail") or "trail_dust"
    RefreshCards(curPts, curTrail)
end)
