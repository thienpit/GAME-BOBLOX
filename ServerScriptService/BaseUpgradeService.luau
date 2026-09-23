--!strict
--[[
    SCRIPT: BaseUpgradeService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> BaseUpgradeService
    DESCRIPTION: Physical 3D Signboards for Treadmill and Base upgrades,
                 exactly matching the clean, immersive "Steal a Pet" aesthetic.
                 Zero screen-blocking popups, zero intrusive BillboardGuis.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

local upgradeCooldowns: { [number]: number } = {} -- UserId -> next allowed time
local UPGRADE_COOLDOWN = 0.8 -- seconds between upgrades

-- FLOATING TEXT FEEDBACK
local function ShowFloatingText(head: BasePart?, text: string, color: Color3)
    if not head then return end
    task.spawn(function()
        local bg = Instance.new("BillboardGui")
        bg.Size = UDim2.new(0, 200, 0, 40)
        bg.StudsOffset = Vector3.new(0, 3, 0)
        bg.AlwaysOnTop = true
        bg.Parent = head
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0.2
        lbl.TextSize = 16
        lbl.Font = Enum.Font.FredokaOne
        lbl.BackgroundTransparency = 1
        lbl.Parent = bg
        
        local tween = TweenService:Create(bg, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            StudsOffset = Vector3.new(0, 6, 0)
        })
        tween:Play()
        task.wait(1.4)
        bg:Destroy()
    end)
end

-- GUARANTEED BASE FINDER (VIA BASESERVICE)
local function GetPlayerBase(player: Player): Model?
    return BaseService.GetOrClaimBase(player)
end

-- APPLY TREADMILL VISUAL UPGRADES
local function ApplyTreadmillVisuals(base: Model, tierLevel: number)
    local tm = base:FindFirstChild("Treadmill") :: Model?
    if not tm then return end
    
    local tier = UpgradeConfig.TREADMILL_TIERS[tierLevel]
    if not tier then return end
    
    for _, part in ipairs(tm:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Belt" or part.Name == "NeonAccent" or part.Name == "TM_Belt") then
            part.Color = tier.BeltColor or tier.AccentColor
        end
    end
    base:SetAttribute("TreadmillTier", tierLevel)
end

-- APPLY PEDESTAL / PEN SLOTS UPGRADE (MANAGED VIRTUALLY VIA PEN CAPACITY)
local function ApplyPedestalSlots(base: Model, slotCount: number)
    local oldStation = base:FindFirstChild("IncubationStation") or base:FindFirstChild("PedestalStation")
    if oldStation then oldStation:Destroy() end
    base:SetAttribute("PenCapacity", slotCount)
end

-- =============================================================================
-- UPDATE PHYSICAL 3D SIGNBOARDS
-- =============================================================================
local function UpdateSignboards(base: Model, pedLevel: number, tmLevel: number)
    -- 1. Update Treadmill Signboard
    local tmSign = base:FindFirstChild("TreadmillSignboard")
    local tmBoard = tmSign and tmSign:FindFirstChild("Board") :: BasePart?
    if tmBoard then
        local sg = tmBoard:FindFirstChildOfClass("SurfaceGui")
        local prompt = tmBoard:FindFirstChildOfClass("ProximityPrompt")
        local lvlText = sg and sg:FindFirstChild("LvlText", true) :: TextLabel?
        local diffText = sg and sg:FindFirstChild("DiffText", true) :: TextLabel?
        local buyBtn = sg and sg:FindFirstChild("BuyBtn", true) :: TextButton?
        
        local tmTier = UpgradeConfig.TREADMILL_TIERS[tmLevel]
        local tmCost, tmNextCap, tmNextRate, _, tmIsMax = UpgradeConfig.GetTreadmillUpgrade(tmLevel)
        
        if tmIsMax then
            if lvlText then lvlText.Text = string.format("Level %d [MAX]", tmLevel) end
            if diffText then diffText.Text = string.format("Cap: %s ⚡ | +%s/s", UpgradeConfig.FormatNumber(tmTier and tmTier.PointCap or 1e12), UpgradeConfig.FormatNumber(tmTier and tmTier.TrainRate or 60000)) end
            if buyBtn then
                buyBtn.Text = "MAXED OUT 🏆"
                buyBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
            end
            if prompt then prompt.Enabled = false end
        else
            if lvlText then lvlText.Text = string.format("Level %d > Level %d", tmLevel, tmLevel + 1) end
            if diffText then diffText.Text = string.format("Cap: %s > %s ⚡ | +%s/s", UpgradeConfig.FormatNumber(tmTier and tmTier.PointCap or 1000), UpgradeConfig.FormatNumber(tmNextCap), UpgradeConfig.FormatNumber(tmNextRate)) end
            if buyBtn then
                buyBtn.Text = string.format("$%d", tmCost)
                buyBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 45)
            end
            if prompt then
                prompt.Enabled = true
                prompt.ObjectText = string.format("$%d", tmCost)
            end
        end
    end
    
    -- 2. Update Base Signboard
    local baseSign = base:FindFirstChild("BaseSignboard")
    local baseBoard = baseSign and baseSign:FindFirstChild("Board") :: BasePart?
    if baseBoard then
        local sg = baseBoard:FindFirstChildOfClass("SurfaceGui")
        local prompt = baseBoard:FindFirstChildOfClass("ProximityPrompt")
        local lvlText = sg and sg:FindFirstChild("LvlText", true) :: TextLabel?
        local diffText = sg and sg:FindFirstChild("DiffText", true) :: TextLabel?
        local buyBtn = sg and sg:FindFirstChild("BuyBtn", true) :: TextButton?
        
        local pedTier = UpgradeConfig.PEDESTAL_TIERS[pedLevel]
        local pedCost, pedNextSlots, pedIsMax = UpgradeConfig.GetPedestalUpgrade(pedLevel)
        
        if pedIsMax then
            if lvlText then lvlText.Text = string.format("Level %d [MAX]", pedLevel) end
            if diffText then diffText.Text = string.format("Pen Capacity: %d Eggs", pedTier and pedTier.Slots or 8) end
            if buyBtn then
                buyBtn.Text = "MAXED OUT 🏆"
                buyBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
            end
            if prompt then prompt.Enabled = false end
        else
            if lvlText then lvlText.Text = string.format("Level %d > Level %d", pedLevel, pedLevel + 1) end
            if diffText then diffText.Text = string.format("Pen Capacity: %d > %d Eggs", pedTier and pedTier.Slots or 3, pedNextSlots) end
            if buyBtn then
                buyBtn.Text = string.format("$%d", pedCost)
                buyBtn.BackgroundColor3 = Color3.fromRGB(225, 45, 45)
            end
            if prompt then
                prompt.Enabled = true
                prompt.ObjectText = string.format("$%d", pedCost)
            end
        end
    end
end

-- =============================================================================
-- HOOK PROXIMITY PROMPT ON PHYSICAL SIGNBOARDS
-- =============================================================================
local function HookBaseSignboardPrompts(base: Model)
    -- Treadmill Prompt
    local tmSign = base:FindFirstChild("TreadmillSignboard")
    local tmBoard = tmSign and tmSign:FindFirstChild("Board")
    local tmPrompt = tmBoard and tmBoard:FindFirstChildOfClass("ProximityPrompt")
    if tmPrompt then
        tmPrompt.Triggered:Connect(function(player)
            local ownerId = base:GetAttribute("OwnerUserId")
            if ownerId ~= 0 and ownerId ~= nil and player.UserId ~= ownerId then
                ShowFloatingText(player.Character and player.Character.Head, "Not your base! ❌", Color3.fromRGB(255, 100, 100))
                return
            end
            
            local pData = DataService.GetData(player)
            if not pData then return end
            
            local tmLevel = pData.TreadmillLevel or 1
            local cost, nextCap, nextRate, _, isMax = UpgradeConfig.GetTreadmillUpgrade(tmLevel)
            if isMax then
                ShowFloatingText(player.Character and player.Character.Head, "Max Level Reached! 🏆", Color3.fromRGB(255, 215, 40))
                return
            end
            
            if DataService.SubMoney(player, cost) then
                local newLevel = DataService.UpgradeTreadmill(player)
                ApplyTreadmillVisuals(base, newLevel)
                UpdateSignboards(base, pData.PedestalLevel or 1, newLevel)
                ShowFloatingText(player.Character and player.Character.Head, string.format("⚡ TREADMILL UPGRADED! (Cap: %s ⚡)", UpgradeConfig.FormatNumber(nextCap)), Color3.fromRGB(80, 255, 120))
            else
                ShowFloatingText(player.Character and player.Character.Head, string.format("Need $%d! ❌", cost), Color3.fromRGB(255, 100, 100))
            end
        end)
    end
    
    -- Base Prompt
    local baseSign = base:FindFirstChild("BaseSignboard")
    local baseBoard = baseSign and baseSign:FindFirstChild("Board")
    local basePrompt = baseBoard and baseBoard:FindFirstChildOfClass("ProximityPrompt")
    if basePrompt then
        basePrompt.Triggered:Connect(function(player)
            local ownerId = base:GetAttribute("OwnerUserId")
            if ownerId ~= 0 and ownerId ~= nil and player.UserId ~= ownerId then
                ShowFloatingText(player.Character and player.Character.Head, "Not your base! ❌", Color3.fromRGB(255, 100, 100))
                return
            end
            
            local pData = DataService.GetData(player)
            if not pData then return end
            
            local pedLevel = pData.PedestalLevel or 1
            local cost, nextSlots, isMax = UpgradeConfig.GetPedestalUpgrade(pedLevel)
            if isMax then
                ShowFloatingText(player.Character and player.Character.Head, "Max Level Reached! 🏆", Color3.fromRGB(255, 215, 40))
                return
            end
            
            if DataService.SubMoney(player, cost) then
                local newLevel = DataService.UpgradePedestal(player)
                local extra = player:GetAttribute("HasExtraSlots") and 2 or 0
                ApplyPedestalSlots(base, nextSlots + extra)
                UpdateSignboards(base, newLevel, pData.TreadmillLevel or 1)
                ShowFloatingText(player.Character and player.Character.Head, string.format("🏺 BASE UPGRADED! (%d Slots)", nextSlots + extra), Color3.fromRGB(80, 255, 120))
            else
                ShowFloatingText(player.Character and player.Character.Head, string.format("Need $%d! ❌", cost), Color3.fromRGB(255, 100, 100))
            end
        end)
    end
end

for _, base in ipairs(bases:GetChildren()) do
    HookBaseSignboardPrompts(base)
    UpdateSignboards(base, 1, 1)
end

-- UPGRADE REMOTE EVENT (FOR CLICKS ON SURFACEGUI BUY BUTTON)
upgradeRemote.OnServerEvent:Connect(function(player: Player, action: string)
    -- 1. COOLDOWN CHECK
    local now = os.clock()
    local userId = player.UserId
    if now < (upgradeCooldowns[userId] or 0) then return end
    upgradeCooldowns[userId] = now + UPGRADE_COOLDOWN

    -- 2. VALIDATE ACTION TYPE (only accept known strings)
    if action ~= "UpgradeTreadmill" and action ~= "UpgradeBase" and action ~= "UpgradePedestal" then
        return
    end

    -- 3. DATA + BASE CHECK
    local pData = DataService.GetData(player)
    if not pData then return end
    local base = GetPlayerBase(player)
    if not base then return end

    -- 4. OWNERSHIP CHECK
    if not BaseService.IsOwner(player, base) then return end

    -- 5. DISTANCE CHECK: player must be near their base (within 60 studs)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    local bFloor = base:FindFirstChild("BaseFloor") :: BasePart?
    if bFloor then
        local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(bFloor.Position.X, 0, bFloor.Position.Z)).Magnitude
        if dist > 60 then return end
    end
    
    if action == "UpgradeTreadmill" then
        local tmLevel = pData.TreadmillLevel or 1
        local cost, nextCap, nextRate, _, isMax = UpgradeConfig.GetTreadmillUpgrade(tmLevel)
        if not isMax and DataService.SubMoney(player, cost) then
            local newLevel = DataService.UpgradeTreadmill(player)
            ApplyTreadmillVisuals(base, newLevel)
            UpdateSignboards(base, pData.PedestalLevel or 1, newLevel)
            ShowFloatingText(player.Character and player.Character.Head, string.format("⚡ TREADMILL UPGRADED! (Max: %d Spd)", nextCap), Color3.fromRGB(80, 255, 120))
        end
    elseif action == "UpgradeBase" or action == "UpgradePedestal" then
        local pedLevel = pData.PedestalLevel or 1
        local cost, nextSlots, isMax = UpgradeConfig.GetPedestalUpgrade(pedLevel)
        if not isMax and DataService.SubMoney(player, cost) then
            local newLevel = DataService.UpgradePedestal(player)
            local extra = player:GetAttribute("HasExtraSlots") and 2 or 0
            ApplyPedestalSlots(base, nextSlots + extra)
            UpdateSignboards(base, newLevel, pData.TreadmillLevel or 1)
            ShowFloatingText(player.Character and player.Character.Head, string.format("🏺 BASE UPGRADED! (%d Slots)", nextSlots + extra), Color3.fromRGB(80, 255, 120))
        end
    end
end)

-- INITIALIZE ON PLAYER JOIN & PET INCOME
Players.PlayerAdded:Connect(function(player)
    task.wait(1.5)
    local pData = DataService.GetData(player)
    local base = GetPlayerBase(player)
    if pData and base then
        local pedTier = UpgradeConfig.PEDESTAL_TIERS[pData.PedestalLevel or 1]
        local extra = player:GetAttribute("HasExtraSlots") and 2 or 0
        ApplyPedestalSlots(base, (pedTier and pedTier.Slots or 3) + extra)
        ApplyTreadmillVisuals(base, pData.TreadmillLevel or 1)
        UpdateSignboards(base, pData.PedestalLevel or 1, pData.TreadmillLevel or 1)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local pData = DataService.GetData(player)
            if pData and pData.Pets and #pData.Pets > 0 then
                local totalIncomePerSec = 0
                for _, pet in ipairs(pData.Pets) do
                    totalIncomePerSec = totalIncomePerSec + (pet.TotalIncomePerSec or 1)
                end
                if player:GetAttribute("HasDoubleMoney") == true then
                    totalIncomePerSec = totalIncomePerSec * 2
                end
                if totalIncomePerSec > 0 then
                    DataService.AddMoney(player, totalIncomePerSec)
                end
            end
        end
    end
end)
