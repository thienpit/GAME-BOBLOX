--!strict
--[[
    SCRIPT: RetentionClientController
    TYPE: LocalScript
    LOCATION: StarterPlayerScripts -> RetentionClientController
    DESCRIPTION: Premium Floating Dock HUD (Shop, Daily, Quests, Index) with glossy glassmorphism,
                 spring hover physics, and modern modal dialogs. 100% English.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local retentionRemote = ReplicatedStorage:WaitForChild("RetentionRemote") :: RemoteEvent
local getRetentionData = ReplicatedStorage:WaitForChild("GetRetentionData") :: RemoteFunction
local RetentionConfig = require(ReplicatedStorage:WaitForChild("RetentionConfig"))
local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))
local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))

-- =============================================================================
-- 1. PREMIUM FLOATING HUD DOCK (LEFT SIDE)
-- =============================================================================
local retentionGui = Instance.new("ScreenGui")
retentionGui.Name = "RetentionHubGui"
retentionGui.ResetOnSpawn = false
retentionGui.DisplayOrder = 10
retentionGui.Parent = pGui

-- Dock Container (Vertical Stack, centered vertically on left margin, compact mobile-safe)
local dock = Instance.new("Frame")
dock.Name = "FloatingDock"
dock.Position = UDim2.new(0, 10, 0, 16)
dock.Size = UDim2.new(0, 52, 0, 185)
dock.BackgroundColor3 = UITheme.Colors.DarkBg
dock.BackgroundTransparency = 0.15
dock.BorderSizePixel = 0
dock.Visible = true
dock.Parent = retentionGui

local dCorner = UITheme.ApplyCorner(dock, UITheme.CornerRadius)
local dStroke = UITheme.ApplyStroke(dock, UITheme.Colors.SubtleBorder, UITheme.StrokeThicknessThin)

local dList = Instance.new("UIListLayout")
dList.Padding = UDim.new(0, 4)
dList.HorizontalAlignment = Enum.HorizontalAlignment.Center
dList.VerticalAlignment = Enum.VerticalAlignment.Center
dList.Parent = dock

-- Helper function to create premium glossy icon buttons
local function CreateDockButton(name: string, iconSymbol: string, labelText: string, accentColor: Color3): TextButton
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 42, 0, 42)
    btn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = dock
    
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 12)
    bCorner.Parent = btn
    
    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 2
    bStroke.Color = accentColor
    bStroke.Parent = btn
    
    -- Icon Display
    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 0, 28)
    icon.Position = UDim2.new(0, 0, 0, 3)
    icon.Text = iconSymbol
    icon.TextSize = 18
    icon.BackgroundTransparency = 1
    icon.Parent = btn
    
    -- Label Capsule
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.Position = UDim2.new(0, 0, 1, -13)
    lbl.Text = labelText
    lbl.TextColor3 = accentColor
    lbl.TextSize = 9
    lbl.Font = Enum.Font.FredokaOne
    lbl.BackgroundTransparency = 1
    lbl.Parent = btn
    
    -- Interactive Spring Animation on Hover / Click
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 38, 0, 38),
            BackgroundColor3 = Color3.fromRGB(35, 42, 60)
        }):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 38, 0, 38),
            BackgroundColor3 = Color3.fromRGB(24, 28, 40)
        }):Play()
    end)
    
    return btn
end

local shopBtn = CreateDockButton("ShopDockBtn", "💎", "SHOP", Color3.fromRGB(0, 220, 255))
local trailBtn = CreateDockButton("TrailDockBtn", "💨", "TRAIL", Color3.fromRGB(0, 220, 255))
local dailyBtn = CreateDockButton("DailyDockBtn", "🎁", "DAILY", Color3.fromRGB(255, 105, 180))
local questBtn = CreateDockButton("QuestDockBtn", "📋", "QUESTS", Color3.fromRGB(255, 205, 50))
local indexBtn = CreateDockButton("IndexDockBtn", "📖", "INDEX", Color3.fromRGB(120, 255, 150))

-- Hook Trail button in dock to open Trail Shop
if trailBtn then
    trailBtn.MouseButton1Click:Connect(function()
        if _G.OpenTrailShop then
            _G.OpenTrailShop()
        else
            local trailGui = pGui:FindFirstChild("TrailShopGui")
            local modal = trailGui and trailGui:FindFirstChild("TrailModal", true) :: Frame?
            local overlay = trailGui and trailGui:FindFirstChild("BackgroundOverlay", true) :: TextButton?
            if modal and overlay then
                overlay.Visible = true
                overlay.BackgroundTransparency = 0.5
                modal.Size = UDim2.new(0, 540, 0, 420)
                modal.Visible = true
            end
        end
    end)
end

-- Hook Shop button to open the Robux Shop
shopBtn.MouseButton1Click:Connect(function()
    if _G.OpenRobuxShop then
        _G.OpenRobuxShop()
    else
        local shopGui = pGui:FindFirstChild("RobuxShopGui")
        local openBtn = shopGui and shopGui:FindFirstChild("OpenRobuxShopBtn", true)
        if openBtn and openBtn:IsA("GuiButton") then
            local modal = shopGui:FindFirstChild("ShopModal", true) :: Frame?
            if modal then
                modal.Visible = true
                TweenService:Create(modal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 560, 0, 360)
                }):Play()
            end
        end
    end
end)

-- Hide the standalone old Shop button so only the Dock button is visible
task.spawn(function()
    task.wait(0.5)
    local shopGui = pGui:FindFirstChild("RobuxShopGui")
    local oldShopBtn = shopGui and shopGui:FindFirstChild("OpenRobuxShopBtn", true)
    if oldShopBtn and oldShopBtn:IsA("GuiObject") then
        oldShopBtn.Visible = false
    end
end)

-- =============================================================================
-- 2. MODAL DIALOG CONTAINER WITH CYBER SLATE GLASSMORPHISM
-- =============================================================================
local mainModal = Instance.new("Frame")
mainModal.Name = "FeatureModal"
mainModal.AnchorPoint = Vector2.new(0.5, 0.5)
mainModal.Position = UDim2.new(0.5, 0, 0.5, 0)
mainModal.Size = UDim2.new(0, 0, 0, 0)
mainModal.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
mainModal.BorderSizePixel = 0
mainModal.Visible = false
mainModal.Parent = retentionGui

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 16)
mCorner.Parent = mainModal

local mStroke = Instance.new("UIStroke")
mStroke.Thickness = 3
mStroke.Color = Color3.fromRGB(255, 215, 60)
mStroke.Parent = mainModal

local mTitle = Instance.new("TextLabel")
mTitle.Size = UDim2.new(1, 0, 0, 46)
mTitle.Position = UDim2.new(0, 0, 0, 8)
mTitle.Text = "MODAL TITLE"
mTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
mTitle.TextSize = 20
mTitle.Font = Enum.Font.FredokaOne
mTitle.BackgroundTransparency = 1
mTitle.Parent = mainModal

local mClose = Instance.new("TextButton")
mClose.AnchorPoint = Vector2.new(1, 0)
mClose.Position = UDim2.new(1, -12, 0, 12)
mClose.Size = UDim2.new(0, 36, 0, 36)
mClose.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
mClose.Text = "X"
mClose.TextColor3 = Color3.fromRGB(255, 255, 255)
mClose.TextSize = 18
mClose.Font = Enum.Font.FredokaOne
mClose.Parent = mainModal

local cClose = Instance.new("UICorner")
cClose.CornerRadius = UDim.new(0, 8)
cClose.Parent = mClose

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Position = UDim2.new(0.04, 0, 0.18, 0)
contentScroll.Size = UDim2.new(0.92, 0, 0.76, 0)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 6
contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
contentScroll.Parent = mainModal

local function OpenModalWithAnimation(titleText: string, strokeColor: Color3)
    mTitle.Text = titleText
    mStroke.Color = strokeColor
    mainModal.Visible = true
    TweenService:Create(mainModal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 560, 0, 340)
    }):Play()
end

local function CloseModal()
    local tOut = TweenService:Create(mainModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    tOut:Play()
    tOut.Completed:Wait()
    mainModal.Visible = false
end
mClose.MouseButton1Click:Connect(CloseModal)

-- =============================================================================
-- 3. 7-DAY DAILY REWARDS MODAL
-- =============================================================================
local function ShowDailyModal()
    local data = getRetentionData:InvokeServer()
    if not data then return end
    
    contentScroll:ClearAllChildren()
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 68, 0, 110)
    grid.CellPadding = UDim2.new(0, 6, 0, 6)
    grid.Parent = contentScroll
    
    local streak = data.DailyStreak or 1
    local canClaim = data.CanClaimDaily
    
    for day = 1, 7 do
        local rCfg = RetentionConfig.DAILY_REWARDS[day]
        if rCfg then
            local card = Instance.new("Frame")
            card.BackgroundColor3 = (day == streak and canClaim) and Color3.fromRGB(42, 52, 72) or Color3.fromRGB(24, 28, 38)
            card.BorderSizePixel = 0
            card.Parent = contentScroll
            
            local cc = Instance.new("UICorner")
            cc.CornerRadius = UDim.new(0, 8)
            cc.Parent = card
            
            if day == streak and canClaim then
                local cs = Instance.new("UIStroke")
                cs.Thickness = 2
                cs.Color = Color3.fromRGB(255, 105, 180)
                cs.Parent = card
            end
            
            local dLbl = Instance.new("TextLabel")
            dLbl.Size = UDim2.new(1, 0, 0, 20)
            dLbl.Text = "DAY " .. day
            dLbl.TextColor3 = Color3.fromRGB(255, 215, 60)
            dLbl.TextSize = 11
            dLbl.Font = Enum.Font.FredokaOne
            dLbl.BackgroundTransparency = 1
            dLbl.Parent = card
            
            local iconLbl = Instance.new("TextLabel")
            iconLbl.Size = UDim2.new(1, 0, 0, 42)
            iconLbl.Position = UDim2.new(0, 0, 0, 22)
            iconLbl.Text = rCfg.Icon
            iconLbl.TextSize = 28
            iconLbl.BackgroundTransparency = 1
            iconLbl.Parent = card
            
            local valLbl = Instance.new("TextLabel")
            valLbl.Size = UDim2.new(1, -4, 0, 36)
            valLbl.Position = UDim2.new(0, 2, 0, 64)
            valLbl.Text = rCfg.RewardName
            valLbl.TextColor3 = Color3.fromRGB(200, 205, 215)
            valLbl.TextSize = 9
            valLbl.Font = Enum.Font.FredokaOne
            valLbl.TextWrapped = true
            valLbl.BackgroundTransparency = 1
            valLbl.Parent = card
        end
    end
    
    local claimBtn = Instance.new("TextButton")
    claimBtn.Size = UDim2.new(0.6, 0, 0, 38)
    claimBtn.Position = UDim2.new(0.2, 0, 0.85, 0)
    claimBtn.Font = Enum.Font.FredokaOne
    claimBtn.TextSize = 15
    claimBtn.Parent = contentScroll
    
    local cbc = Instance.new("UICorner")
    cbc.CornerRadius = UDim.new(0, 8)
    cbc.Parent = claimBtn
    
    if canClaim then
        claimBtn.Text = "CLAIM DAY " .. streak .. " 🎁"
        claimBtn.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
        claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        claimBtn.MouseButton1Click:Connect(function()
            retentionRemote:FireServer("ClaimDailyReward")
            CloseModal()
        end)
    else
        claimBtn.Text = "COME BACK TOMORROW ⏳"
        claimBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
        claimBtn.TextColor3 = Color3.fromRGB(160, 165, 175)
    end
    
    OpenModalWithAnimation("🎁 7-DAY DAILY REWARDS", Color3.fromRGB(255, 105, 180))
end
dailyBtn.MouseButton1Click:Connect(ShowDailyModal)

-- =============================================================================
-- 4. DAILY QUESTS MODAL
-- =============================================================================
local function ShowQuestsModal()
    local data = getRetentionData:InvokeServer()
    if not data then return end
    
    contentScroll:ClearAllChildren()
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.Parent = contentScroll
    
    for questKey, qInfo in pairs(RetentionConfig.DAILY_QUESTS) do
        local progress = (data.QuestProgress and data.QuestProgress[questKey]) or 0
        local claimed = (data.QuestClaimed and data.QuestClaimed[questKey]) == true
        local isFinished = progress >= qInfo.TargetCount
        
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 68)
        row.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
        row.BorderSizePixel = 0
        row.Parent = contentScroll
        
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row
        
        local qTitle = Instance.new("TextLabel")
        qTitle.Size = UDim2.new(0.65, 0, 0, 24)
        qTitle.Position = UDim2.new(0, 12, 0, 6)
        qTitle.Text = qInfo.Icon .. " " .. qInfo.Title .. string.format(" (%d/%d)", math.min(progress, qInfo.TargetCount), qInfo.TargetCount)
        qTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
        qTitle.TextSize = 14
        qTitle.Font = Enum.Font.FredokaOne
        qTitle.TextXAlignment = Enum.TextXAlignment.Left
        qTitle.BackgroundTransparency = 1
        qTitle.Parent = row
        
        local qDesc = Instance.new("TextLabel")
        qDesc.Size = UDim2.new(0.65, 0, 0, 20)
        qDesc.Position = UDim2.new(0, 12, 0, 32)
        qDesc.Text = qInfo.Description .. " (+$" .. qInfo.RewardMoney .. ")"
        qDesc.TextColor3 = Color3.fromRGB(180, 185, 195)
        qDesc.TextSize = 11
        qDesc.Font = Enum.Font.FredokaOne
        qDesc.TextXAlignment = Enum.TextXAlignment.Left
        qDesc.BackgroundTransparency = 1
        qDesc.Parent = row
        
        local cBtn = Instance.new("TextButton")
        cBtn.AnchorPoint = Vector2.new(1, 0.5)
        cBtn.Position = UDim2.new(1, -12, 0.5, 0)
        cBtn.Size = UDim2.new(0, 110, 0, 36)
        cBtn.Font = Enum.Font.FredokaOne
        cBtn.TextSize = 13
        cBtn.Parent = row
        
        local cbc = Instance.new("UICorner")
        cbc.CornerRadius = UDim.new(0, 6)
        cbc.Parent = cBtn
        
        if claimed then
            cBtn.Text = "CLAIMED ✅"
            cBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
            cBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        elseif isFinished then
            cBtn.Text = "CLAIM $" .. qInfo.RewardMoney
            cBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 90)
            cBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            cBtn.MouseButton1Click:Connect(function()
                retentionRemote:FireServer("ClaimQuestReward", questKey)
                CloseModal()
            end)
        else
            cBtn.Text = "IN PROGRESS"
            cBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 58)
            cBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
        end
    end
    
    OpenModalWithAnimation("📋 DAILY QUESTS (RESET 00:00 UTC)", Color3.fromRGB(255, 195, 45))
end
questBtn.MouseButton1Click:Connect(ShowQuestsModal)

-- =============================================================================
-- 5. PET COLLECTION INDEX MODAL
-- =============================================================================
local function ShowPetIndexModal()
    local data = getRetentionData:InvokeServer()
    if not data then return end
    
    contentScroll:ClearAllChildren()
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 94, 0, 115)
    grid.CellPadding = UDim2.new(0, 8, 0, 8)
    grid.Parent = contentScroll
    
    local discovered = data.DiscoveredPets or {}
    local totalDiscovered = 0
    
    local petOrder = {
        "pebble_dog", "mossy_roll", "slate_turtle",
        "basalt_crab", "obsidian_spire", "amethyst_geode",
        "lava_pup", "flame_golem", "inferno_core",
        "star_shard", "meteor_titan", "cosmic_eye",
        "abyss_leviathan", "eclipse_overlord", "genesis_monolith"
    }
    
    for _, petId in ipairs(petOrder) do
        local pCfg = RockPetConfig.PETS[petId]
        if pCfg then
            local isUnlocked = (discovered[petId] == true)
            if isUnlocked then totalDiscovered = totalDiscovered + 1 end
            
            local card = Instance.new("Frame")
            card.BackgroundColor3 = isUnlocked and Color3.fromRGB(32, 38, 52) or Color3.fromRGB(20, 22, 28)
            card.BorderSizePixel = 0
            card.Parent = contentScroll
            
            local cc = Instance.new("UICorner")
            cc.CornerRadius = UDim.new(0, 8)
            cc.Parent = card
            
            local icon = Instance.new("TextLabel")
            icon.Size = UDim2.new(1, 0, 0, 48)
            icon.Position = UDim2.new(0, 0, 0, 8)
            icon.Text = isUnlocked and "🪨" or "🔒"
            icon.TextSize = 18
            icon.TextColor3 = isUnlocked and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 105, 115)
            icon.BackgroundTransparency = 1
            icon.Parent = card
            
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(1, -6, 0, 32)
            nameLbl.Position = UDim2.new(0, 3, 0, 56)
            nameLbl.Text = isUnlocked and pCfg.Name or "???"
            nameLbl.TextColor3 = isUnlocked and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(100, 105, 115)
            nameLbl.TextSize = 10
            nameLbl.Font = Enum.Font.FredokaOne
            nameLbl.TextWrapped = true
            nameLbl.BackgroundTransparency = 1
            nameLbl.Parent = card
            
            local rarityLbl = Instance.new("TextLabel")
            rarityLbl.Size = UDim2.new(1, 0, 0, 18)
            rarityLbl.Position = UDim2.new(0, 0, 0, 92)
            rarityLbl.Text = isUnlocked and string.upper(pCfg.Rarity) or "LOCKED"
            rarityLbl.TextColor3 = isUnlocked and Color3.fromRGB(80, 220, 255) or Color3.fromRGB(70, 75, 85)
            rarityLbl.TextSize = 9
            rarityLbl.Font = Enum.Font.FredokaOne
            rarityLbl.BackgroundTransparency = 1
            rarityLbl.Parent = card
        end
    end
    
    OpenModalWithAnimation(string.format("📖 PET COLLECTION INDEX (%d/15)", totalDiscovered), Color3.fromRGB(80, 220, 255))
end
indexBtn.MouseButton1Click:Connect(function()
    if _G.OpenIndexUI then
        _G.OpenIndexUI()
    else
        ShowPetIndexModal()
    end
end)

-- =============================================================================
-- 6. BEGINNER ONBOARDING TUTORIAL (< 1 MINUTE)
-- =============================================================================
local function StartTutorial()
    local tutFrame = Instance.new("Frame")
    tutFrame.Name = "TutorialModal"
    tutFrame.AnchorPoint = Vector2.new(0.5, 0)
    tutFrame.Position = UDim2.new(0.5, 0, 0, 56)
    tutFrame.Size = UDim2.new(0, 540, 0, 44)
    tutFrame.BackgroundColor3 = UITheme.Colors.DarkBg
    tutFrame.BackgroundTransparency = 0.1
    tutFrame.BorderSizePixel = 0
    tutFrame.Parent = retentionGui
    
    local tc = UITheme.ApplyCorner(tutFrame, UITheme.CornerRadiusSmall)
    local ts = UITheme.ApplyStroke(tutFrame, UITheme.Colors.Money, UITheme.StrokeThicknessThin)
    
    local stepTitle = Instance.new("TextLabel")
    stepTitle.Size = UDim2.new(0, 130, 1, 0)
    stepTitle.Position = UDim2.new(0, 10, 0, 0)
    stepTitle.Text = "🔰 TUTORIAL 1/3:"
    stepTitle.TextColor3 = UITheme.Colors.Money
    stepTitle.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    stepTitle.TextStrokeTransparency = 0.3
    stepTitle.TextSize = 12
    stepTitle.Font = UITheme.Fonts.Header
    stepTitle.TextXAlignment = Enum.TextXAlignment.Left
    stepTitle.BackgroundTransparency = 1
    stepTitle.Parent = tutFrame
    
    local stepDesc = Instance.new("TextLabel")
    stepDesc.Size = UDim2.new(1, -255, 1, 0)
    stepDesc.Position = UDim2.new(0, 135, 0, 0)
    stepDesc.Text = "Step 1: Step onto Treadmill to train Speed!"
    stepDesc.TextColor3 = UITheme.Colors.White
    stepDesc.TextSize = 11
    stepDesc.Font = UITheme.Fonts.Body
    stepDesc.TextXAlignment = Enum.TextXAlignment.Left
    stepDesc.TextTruncate = Enum.TextTruncate.AtEnd
    stepDesc.BackgroundTransparency = 1
    stepDesc.Parent = tutFrame
    
    local nextBtn = Instance.new("TextButton")
    nextBtn.AnchorPoint = Vector2.new(1, 0.5)
    nextBtn.Position = UDim2.new(1, -44, 0.5, 0)
    nextBtn.Size = UDim2.new(0, 68, 0, 30)
    nextBtn.BackgroundColor3 = UITheme.Colors.Positive
    nextBtn.Text = "NEXT ➔"
    nextBtn.TextColor3 = UITheme.Colors.White
    nextBtn.TextSize = 11
    nextBtn.Font = UITheme.Fonts.Header
    nextBtn.Parent = tutFrame
    
    local nbc = UITheme.ApplyCorner(nextBtn, UDim.new(0, 6))
    
    local skipBtn = Instance.new("TextButton")
    skipBtn.AnchorPoint = Vector2.new(1, 0.5)
    skipBtn.Position = UDim2.new(1, -6, 0.5, 0)
    skipBtn.Size = UDim2.new(0, 34, 0, 30)
    skipBtn.BackgroundTransparency = 1
    skipBtn.Text = "X"
    skipBtn.TextColor3 = UITheme.Colors.Muted
    skipBtn.TextSize = 14
    skipBtn.Font = UITheme.Fonts.Header
    skipBtn.Parent = tutFrame
    
    local currentStep = 1
    local steps = {
        [1] = "Step 1: Step onto Treadmill outside base to train Speed!",
        [2] = "Step 2: Rush into Steal Zone to grab rare eggs/rocks!",
        [3] = "Step 3: Bring eggs to Pedestal to hatch pets for cash!"
    }
    
    local function FinishTut()
        retentionRemote:FireServer("CompleteTutorial")
        tutFrame:Destroy()
    end
    
    skipBtn.MouseButton1Click:Connect(FinishTut)
    nextBtn.MouseButton1Click:Connect(function()
        currentStep = currentStep + 1
        if currentStep <= 3 then
            stepTitle.Text = string.format("🔰 TUTORIAL %d/3:", currentStep)
            stepDesc.Text = steps[currentStep]
            if currentStep == 3 then
                nextBtn.Text = "DONE ✨"
                nextBtn.BackgroundColor3 = UITheme.Colors.Money
            end
        else
            FinishTut()
        end
    end)
end
task.spawn(function()
    task.wait(2.5)
    local data = getRetentionData:InvokeServer()
    if data and data.TutorialDone == false then
        StartTutorial()
    end
end)
