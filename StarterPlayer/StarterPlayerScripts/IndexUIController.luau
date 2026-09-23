--!strict
--[[
    SCRIPT: IndexUIController
    TYPE: LocalScript (Client-side)
    LOCATION: StarterPlayerScripts -> IndexUIController
    DESCRIPTION: Pet Index Zone Mastery & Trophy Bat Rewards UI.
                 Opens via 3D Pedestal in Village or via the 📖 INDEX button in FloatingDock.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local BatConfig = require(ReplicatedStorage:WaitForChild("BatConfig"))
local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))

local indexRemote = ReplicatedStorage:WaitForChild("IndexRewardRemote") :: RemoteEvent

-- Cached State
local discoveredPets: { [string]: boolean } = {}
local claimedBats: { [string]: boolean } = {}
local ownedBats: { string } = { "wooden_bat" }
local equippedBat: string = "wooden_bat"

-- 1. SCREEN GUI
local indexGui = Instance.new("ScreenGui")
indexGui.Name = "PetIndexGui"
indexGui.ResetOnSpawn = false
indexGui.DisplayOrder = 20
indexGui.Parent = pGui

-- Modal Dialog
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.Text = ""
overlay.Visible = false
overlay.ZIndex = 30
overlay.Parent = indexGui

local modal = Instance.new("Frame")
modal.Name = "IndexModal"
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.Size = UDim2.new(0, 640, 0, 480)
modal.BackgroundColor3 = UITheme.Colors.DarkBg
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 35
modal.Parent = indexGui

UITheme.ApplyCorner(modal, UITheme.CornerRadius)
UITheme.ApplyStroke(modal, Color3.fromRGB(255, 215, 30), UITheme.StrokeThicknessThick)
UITheme.ApplyShadow(modal, 6, UITheme.Colors.Shadow, 0.45)
UITheme.ApplyGradient(modal)

-- Header Title
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -70, 0, 36)
header.Position = UDim2.new(0, 24, 0, 14)
header.Text = "📖 SỔ TAY THÚ CƯNG & VŨ KHÍ BIOME (PET INDEX)"
header.TextColor3 = Color3.fromRGB(255, 215, 40)
header.TextSize = 17
header.Font = UITheme.Fonts.Header
header.TextXAlignment = Enum.TextXAlignment.Left
header.BackgroundTransparency = 1
header.ZIndex = 36
header.Parent = modal

local subHeader = Instance.new("TextLabel")
subHeader.Size = UDim2.new(1, -70, 0, 20)
subHeader.Position = UDim2.new(0, 24, 0, 48)
subHeader.Text = "Sưu tập đủ 3 Pet của từng Vùng để nhận Vũ Khí Thần Thoại tương ứng!"
subHeader.TextColor3 = UITheme.Colors.Muted
subHeader.TextSize = 12
subHeader.Font = UITheme.Fonts.Body
subHeader.TextXAlignment = Enum.TextXAlignment.Left
subHeader.BackgroundTransparency = 1
subHeader.ZIndex = 36
subHeader.Parent = modal

-- Close Button
local closeBtn = Instance.new("TextButton")
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
UITheme.ApplyCorner(closeBtn, UDim.new(0, 8))

-- Scrolling Area
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ZoneList"
scroll.Size = UDim2.new(1, -36, 1, -85)
scroll.Position = UDim2.new(0, 18, 0, 75)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 40)
scroll.CanvasSize = UDim2.new(0, 0, 0, 680)
scroll.ZIndex = 36
scroll.Parent = modal

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 14)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent = scroll

-- Render Zone Cards
local function RefreshIndexCards()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    for zoneId = 1, 4 do
        local rInfo = BatConfig.GetZoneReward(zoneId)
        if not rInfo then continue end

        local batInfo = BatConfig.GetBat(rInfo.BatId)
        local isClaimed = (claimedBats["Zone_" .. zoneId] == true)
        local isEquipped = (equippedBat == rInfo.BatId)

        -- Count discovered
        local discCount = 0
        for _, pId in ipairs(rInfo.RequiredPets) do
            if discoveredPets[pId] == true then
                discCount = discCount + 1
            end
        end

        local card = Instance.new("Frame")
        card.Name = "ZoneCard_" .. zoneId
        card.Size = UDim2.new(1, -12, 0, 150)
        card.BackgroundColor3 = UITheme.Colors.CardBg
        card.BorderSizePixel = 0
        card.ZIndex = 37
        card.Parent = scroll

        UITheme.ApplyCorner(card, UITheme.CornerRadiusSmall)
        local strokeColor = isClaimed and Color3.fromRGB(255, 215, 30) or (discCount >= 3 and Color3.fromRGB(80, 255, 120) or UITheme.Colors.SubtleBorder)
        UITheme.ApplyStroke(card, strokeColor, 2)
        UITheme.ApplyGradient(card)

        -- Zone Header
        local zTitle = Instance.new("TextLabel")
        zTitle.Size = UDim2.new(0.6, 0, 0, 24)
        zTitle.Position = UDim2.new(0, 14, 0, 10)
        zTitle.Text = string.format("VÙNG %d: %s", zoneId, string.upper(rInfo.ZoneName))
        zTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        zTitle.TextSize = 15
        zTitle.Font = UITheme.Fonts.Header
        zTitle.TextXAlignment = Enum.TextXAlignment.Left
        zTitle.BackgroundTransparency = 1
        zTitle.ZIndex = 38
        zTitle.Parent = card

        local progressLabel = Instance.new("TextLabel")
        progressLabel.Size = UDim2.new(0.35, 0, 0, 24)
        progressLabel.Position = UDim2.new(0.6, 0, 0, 10)
        progressLabel.Text = string.format("TIẾN ĐỘ: %d/3 PETS", discCount)
        progressLabel.TextColor3 = (discCount >= 3) and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 215, 40)
        progressLabel.TextSize = 14
        progressLabel.Font = UITheme.Fonts.Header
        progressLabel.TextXAlignment = Enum.TextXAlignment.Right
        progressLabel.BackgroundTransparency = 1
        progressLabel.ZIndex = 38
        progressLabel.Parent = card

        -- 3 Pet Badges Row
        local petRow = Instance.new("Frame")
        petRow.Size = UDim2.new(0.6, 0, 0, 50)
        petRow.Position = UDim2.new(0, 14, 0, 42)
        petRow.BackgroundTransparency = 1
        petRow.ZIndex = 38
        petRow.Parent = card

        local pList = Instance.new("UIListLayout")
        pList.FillDirection = Enum.FillDirection.Horizontal
        pList.Padding = UDim.new(0, 8)
        pList.Parent = petRow

        for _, petId in ipairs(rInfo.RequiredPets) do
            local pConfig = RockPetConfig.PETS[petId]
            local isDiscovered = (discoveredPets[petId] == true)

            local pBadge = Instance.new("Frame")
            pBadge.Size = UDim2.new(0, 105, 0, 48)
            pBadge.BackgroundColor3 = isDiscovered and Color3.fromRGB(28, 36, 52) or Color3.fromRGB(20, 22, 28)
            pBadge.ZIndex = 39
            pBadge.Parent = petRow
            UITheme.ApplyCorner(pBadge, UDim.new(0, 8))
            UITheme.ApplyStroke(pBadge, isDiscovered and Color3.fromRGB(0, 210, 255) or Color3.fromRGB(45, 50, 60), 1.5)

            local pLbl = Instance.new("TextLabel")
            pLbl.Size = UDim2.new(1, -6, 1, 0)
            pLbl.Position = UDim2.new(0, 3, 0, 0)
            pLbl.Text = isDiscovered and (pConfig and pConfig.Name or petId) or "???"
            pLbl.TextColor3 = isDiscovered and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 125, 135)
            pLbl.TextSize = isDiscovered and 11 or 15
            pLbl.Font = UITheme.Fonts.Header
            pLbl.TextWrapped = true
            pLbl.BackgroundTransparency = 1
            pLbl.ZIndex = 40
            pLbl.Parent = pBadge
        end

        -- Trophy Bat Reward Box (Right Side)
        local batBox = Instance.new("Frame")
        batBox.Size = UDim2.new(0.35, 0, 0, 85)
        batBox.Position = UDim2.new(0.62, 0, 0, 42)
        batBox.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
        batBox.ZIndex = 38
        batBox.Parent = card
        UITheme.ApplyCorner(batBox, UDim.new(0, 8))
        UITheme.ApplyStroke(batBox, Color3.fromRGB(255, 215, 30), 1.5)

        local batNameLbl = Instance.new("TextLabel")
        batNameLbl.Size = UDim2.new(1, -8, 0, 20)
        batNameLbl.Position = UDim2.new(0, 4, 0, 4)
        batNameLbl.Text = batInfo and batInfo.Name or "Trophy Bat"
        batNameLbl.TextColor3 = Color3.fromRGB(255, 215, 40)
        batNameLbl.TextSize = 12
        batNameLbl.Font = UITheme.Fonts.Header
        batNameLbl.TextWrapped = true
        batNameLbl.BackgroundTransparency = 1
        batNameLbl.ZIndex = 39
        batNameLbl.Parent = batBox

        local batStatLbl = Instance.new("TextLabel")
        batStatLbl.Size = UDim2.new(1, -8, 0, 16)
        batStatLbl.Position = UDim2.new(0, 4, 0, 24)
        batStatLbl.Text = string.format("Lực văng: %d | Choáng: %.1fs", batInfo and batInfo.Knockback or 40, batInfo and batInfo.StunDuration or 1.2)
        batStatLbl.TextColor3 = UITheme.Colors.Muted
        batStatLbl.TextSize = 10
        batStatLbl.Font = UITheme.Fonts.Body
        batStatLbl.BackgroundTransparency = 1
        batStatLbl.ZIndex = 39
        batStatLbl.Parent = batBox

        -- Claim / Equip Button
        local claimBtn = Instance.new("TextButton")
        claimBtn.Size = UDim2.new(1, -12, 0, 32)
        claimBtn.Position = UDim2.new(0, 6, 1, -38)
        claimBtn.Font = UITheme.Fonts.Header
        claimBtn.TextSize = 12
        claimBtn.ZIndex = 40
        claimBtn.Parent = batBox
        UITheme.ApplyCorner(claimBtn, UDim.new(0, 6))

        if isEquipped then
            claimBtn.Text = "ĐANG DÙNG ✅"
            claimBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
            claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            claimBtn.AutoButtonColor = false
        elseif isClaimed then
            claimBtn.Text = "TRANG BỊ ⚔️"
            claimBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 220)
            claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            claimBtn.MouseButton1Click:Connect(function()
                indexRemote:FireServer("EquipOwnedBat", rInfo.BatId)
                equippedBat = rInfo.BatId
                RefreshIndexCards()
            end)
        elseif discCount >= 3 then
            claimBtn.Text = "NHẬN GẬY 🏆"
            claimBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 20)
            claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            claimBtn.MouseButton1Click:Connect(function()
                indexRemote:FireServer("ClaimZoneBat", zoneId)
            end)
        else
            claimBtn.Text = "CẦN 3/3 PETS 🔒"
            claimBtn.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
            claimBtn.TextColor3 = Color3.fromRGB(130, 135, 145)
            claimBtn.AutoButtonColor = false
        end
    end
end

local function OpenModal()
    indexRemote:FireServer("RequestSync")
    RefreshIndexCards()
    overlay.Visible = true
    overlay.BackgroundTransparency = 0.5
    modal.Size = UDim2.new(0, 640, 0, 480)
    modal.Visible = true
end

local function CloseModal()
    modal.Visible = false
    overlay.Visible = false
end

closeBtn.MouseButton1Click:Connect(CloseModal)
overlay.MouseButton1Click:Connect(CloseModal)

_G.OpenIndexUI = OpenModal

-- PROXIMITY PROMPT TRIGGER ON CLIENT (0ms latency!)
ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
    if triggerPlayer == player and (prompt.Name == "IndexPrompt" or (prompt.Parent and prompt.Parent.Name == "Deco_PedestalColumn")) then
        OpenModal()
    end
end)

-- Listen to Server Sync Events
indexRemote.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
    if action == "SyncIndexData" and arg1 then
        discoveredPets = arg1.DiscoveredPets or {}
        claimedBats = arg1.ClaimedBats or {}
        ownedBats = arg1.OwnedBats or {}
        equippedBat = arg1.EquippedBat or "wooden_bat"
        RefreshIndexCards()
    elseif action == "OpenIndexUI" then
        OpenModal()
    elseif action == "BatClaimedSuccess" and arg1 then
        claimedBats["Zone_" .. tostring(arg1.ZoneId)] = true
        equippedBat = arg1.BatId
        RefreshIndexCards()
    end
end)

-- AUTO-SYNC: When modal becomes visible from any trigger (Dock button, 3D Pedestal, or Script)
modal:GetPropertyChangedSignal("Visible"):Connect(function()
    if modal.Visible then
        overlay.Visible = true
        indexRemote:FireServer("RequestSync")
        RefreshIndexCards()
    end
end)

-- Initial populate on start
task.spawn(function()
    task.wait(0.5)
    indexRemote:FireServer("RequestSync")
    RefreshIndexCards()
end)
