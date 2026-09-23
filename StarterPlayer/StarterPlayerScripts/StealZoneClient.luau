--!strict
--[[
    TÊN SCRIPT: StealZoneClient
    LOẠI: LocalScript
    VỊ TRÍ: StarterPlayerScripts -> StealZoneClient
    MÔ TẢ: Hiển thị thanh cảnh báo vác đá/trứng phong cách Simulator hiện đại (ActionCard),
          popup thông báo giao nộp thành công và phát loa toàn server khi vật phẩm hiếm xuất hiện.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local stealRemote = ReplicatedStorage:WaitForChild("StealZoneRemote") :: RemoteEvent
local bountyRemote = ReplicatedStorage:WaitForChild("BountyAlertRemote") :: RemoteEvent

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

-- 1. SCREEN GUI THÔNG BÁO VÁC TRỨNG / CƯỚP ĐÁ
local stealGui = Instance.new("ScreenGui")
stealGui.Name = "StealZoneGui"
stealGui.ResetOnSpawn = false
stealGui.DisplayOrder = 20
stealGui.Parent = pGui

-- Thanh cảnh báo trạng thái nguy hiểm khi đang vác đá (Top Screen ActionCard)
local carryBanner = Instance.new("Frame")
carryBanner.Name = "CarryBanner"
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.Position = UDim2.new(0.5, 0, 0, -140) -- Ẩn trên đỉnh
carryBanner.Size = UDim2.new(0, 500, 0, 64)
carryBanner.BackgroundColor3 = UITheme.Colors.DarkBg
carryBanner.BackgroundTransparency = 0.05
carryBanner.BorderSizePixel = 0
carryBanner.Parent = stealGui

local corner = UITheme.ApplyCorner(carryBanner, UITheme.CornerRadius)
local stroke = UITheme.ApplyStroke(carryBanner, UITheme.Colors.Danger, UITheme.StrokeThicknessThick)

local carryIcon = Instance.new("TextLabel")
carryIcon.Name = "HazardIcon"
carryIcon.Size = UDim2.new(0, 48, 1, 0)
carryIcon.Position = UDim2.new(0, 10, 0, 0)
carryIcon.BackgroundTransparency = 1
carryIcon.Text = "⚠️"
carryIcon.TextSize = 28
carryIcon.Parent = carryBanner

local carryLabel = Instance.new("TextLabel")
carryLabel.Name = "CarryText"
carryLabel.Size = UDim2.new(1, -190, 0.52, 0)
carryLabel.Position = UDim2.new(0, 58, 0, 6)
carryLabel.TextXAlignment = Enum.TextXAlignment.Left
carryLabel.Text = "HAZARD: CARRYING HEAVY ROCK! (-4 SPD)"
carryLabel.TextColor3 = UITheme.Colors.Danger
carryLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
carryLabel.TextStrokeTransparency = 0.3
carryLabel.TextSize = 14
carryLabel.Font = UITheme.Fonts.Header
carryLabel.BackgroundTransparency = 1
carryLabel.Parent = carryBanner

local subLabel = Instance.new("TextLabel")
subLabel.Name = "SubText"
subLabel.Size = UDim2.new(1, -190, 0.44, 0)
subLabel.Position = UDim2.new(0, 58, 0.52, 0)
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.Text = "RUN BACK TO BASE SAFE ZONE! 🛡️"
subLabel.TextColor3 = UITheme.Colors.Money
subLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
subLabel.TextStrokeTransparency = 0.4
subLabel.TextSize = 12
subLabel.Font = UITheme.Fonts.Header
subLabel.BackgroundTransparency = 1
subLabel.Parent = carryBanner

-- Nút bấm thả đá nhanh (Tối ưu cảm ứng Mobile >= 46px và PC)
local dropBtn = Instance.new("TextButton")
dropBtn.Name = "DropButton"
dropBtn.Size = UDim2.new(0, 115, 0, 46)
dropBtn.AnchorPoint = Vector2.new(1, 0.5)
dropBtn.Position = UDim2.new(1, -12, 0.5, 0)
dropBtn.BackgroundColor3 = UITheme.Colors.Danger
dropBtn.AutoButtonColor = false
dropBtn.Text = "DROP ❌"
dropBtn.TextColor3 = UITheme.Colors.White
dropBtn.TextStrokeColor3 = UITheme.Colors.StrokeOutline
dropBtn.TextStrokeTransparency = 0.2
dropBtn.TextSize = 15
dropBtn.Font = UITheme.Fonts.Header
dropBtn.Parent = carryBanner

local dropCorner = UITheme.ApplyCorner(dropBtn, UITheme.CornerRadiusSmall)
local dropStroke = UITheme.ApplyStroke(dropBtn, UITheme.Colors.White, UITheme.StrokeThicknessThin)

-- Hiệu ứng Hover nút Drop
dropBtn.MouseEnter:Connect(function()
    TweenService:Create(dropBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(255, 110, 110) }):Play()
end)
dropBtn.MouseLeave:Connect(function()
    TweenService:Create(dropBtn, TweenInfo.new(0.15), { BackgroundColor3 = UITheme.Colors.Danger }):Play()
end)

local lastDropClick = 0
dropBtn.MouseButton1Click:Connect(function()
    local now = os.clock()
    if now - lastDropClick < 0.8 then return end
    lastDropClick = now
    stealRemote:FireServer("RequestDrop")
end)

-- Dòng chữ thông báo xuất hiện trứng hiếm (Rare Egg Alert Chunky Banner)
local alertLabel = Instance.new("TextLabel")
alertLabel.Name = "RareAlert"
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.Position = UDim2.new(0.5, 0, 0, 78)
alertLabel.Size = UDim2.new(0, 720, 0, 40)
alertLabel.Text = ""
alertLabel.TextColor3 = UITheme.Colors.Money
alertLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
alertLabel.TextStrokeTransparency = 1
alertLabel.TextTransparency = 1
alertLabel.TextSize = 22
alertLabel.Font = UITheme.Fonts.Header
alertLabel.BackgroundTransparency = 1
alertLabel.Parent = stealGui

-- Popup Toast Giao nộp thành công (Deliver Feedback)
local deliverToast = Instance.new("Frame")
deliverToast.Name = "DeliverToast"
deliverToast.AnchorPoint = Vector2.new(0.5, 0)
deliverToast.Position = UDim2.new(0.5, 0, 0, -120)
deliverToast.Size = UDim2.new(0, 380, 0, 54)
deliverToast.BackgroundColor3 = UITheme.Colors.DarkBg
deliverToast.BackgroundTransparency = 0.1
deliverToast.BorderSizePixel = 0
deliverToast.Parent = stealGui

UITheme.ApplyCorner(deliverToast, UITheme.CornerRadius)
UITheme.ApplyStroke(deliverToast, UITheme.Colors.Positive, UITheme.StrokeThicknessThick)

local deliverLabel = Instance.new("TextLabel")
deliverLabel.Name = "DeliverLabel"
deliverLabel.Size = UDim2.new(1, 0, 1, 0)
deliverLabel.BackgroundTransparency = 1
deliverLabel.Font = UITheme.Fonts.Header
deliverLabel.Text = "🎉 DELIVERED TO BASE! +$$$ 🎉"
deliverLabel.TextColor3 = UITheme.Colors.Positive
deliverLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
deliverLabel.TextStrokeTransparency = 0.2
deliverLabel.TextSize = 16
deliverLabel.Parent = deliverToast

-- =============================================================================
-- 2. HÀM HIỆN / ẨN THÔNG BÁO CẢNH BÁO VÁC ĐÁ
-- =============================================================================
local isBannerVisible = false

local function ShowCarryBanner(eggName: string, slowdown: number)
    local char = player.Character
    if char and char:GetAttribute("InSafeZone") == true then return end
    
    local sd = slowdown or 4
    carryLabel.Text = string.format("HAZARD: CARRYING %s (-%d SPD)", string.upper(eggName), sd)
    isBannerVisible = true
    
    TweenService:Create(carryBanner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 20)
    }):Play()
end

local function HideCarryBanner()
    if not isBannerVisible then return end
    isBannerVisible = false
    
    TweenService:Create(carryBanner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0, -140)
    }):Play()
end

local function ShowDeliverToast()
    TweenService:Create(deliverToast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 24)
    }):Play()
    
    task.delay(2.5, function()
        TweenService:Create(deliverToast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, 0, -120)
        }):Play()
    end)
end

local function ShowRareAlert(eggName: string, color: Color3)
    alertLabel.Text = string.format("⚡ ULTRA RARE [%s] SPAWNED IN STEAL ZONE! ⚡", string.upper(eggName))
    alertLabel.TextColor3 = color or UITheme.Colors.Money
    
    TweenService:Create(alertLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        TextStrokeTransparency = 0.2
    }):Play()
    
    task.delay(4.0, function()
        TweenService:Create(alertLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1,
            TextStrokeTransparency = 1
        }):Play()
    end)
end

-- =============================================================================
-- 3. BẮT SỰ KIỆN TỪ SERVER & QUẢN LÝ TRẠNG THÁI LIÊN TỤC
-- =============================================================================
bountyRemote.OnClientEvent:Connect(function(data: any)
    if data and data.playerName and data.eggTier then
        ShowRareAlert(string.format("🚨 BOUNTY: %s ESCAPING WITH [%s]! 🚨", string.upper(data.playerName), string.upper(data.eggTier)), Color3.fromRGB(255, 70, 70))
    end
end)

stealRemote.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
    if action == "StartCarrying" then
        ShowCarryBanner(arg1, arg2)
    elseif action == "StopCarrying" or action == "EggDropped" then
        HideCarryBanner()
    elseif action == "DeliveredSuccess" then
        HideCarryBanner()
        ShowDeliverToast()
    elseif action == "RareSpawnAlert" then
        ShowRareAlert(arg1, arg2)
    end
end)

-- TỰ ĐỘNG TẮT KHI VÀO VÙNG AN TOÀN HOẶC KHÔNG CÒN VÁC ĐÁ
task.spawn(function()
    while true do
        task.wait(0.25)
        local char = player.Character
        if char then
            local isCarrying = char:GetAttribute("IsCarryingEgg") == true or char:GetAttribute("IsCarryingRock") == true
            local inSafe = char:GetAttribute("InSafeZone") == true
            
            if (not isCarrying or inSafe) and isBannerVisible then
                HideCarryBanner()
            end
        else
            if isBannerVisible then HideCarryBanner() end
        end
    end
end)

-- =============================================================================
-- 4. TREADMILL JUMP-OFF CONTROLLER
-- =============================================================================
local function TriggerExitTreadmill()
    local char = player.Character
    if char and char:GetAttribute("OnTreadmill") == true then
        stealRemote:FireServer("ExitTreadmill")
    end
end

UserInputService.JumpRequest:Connect(TriggerExitTreadmill)

