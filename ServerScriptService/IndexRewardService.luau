--!strict
--[[
    SCRIPT: IndexRewardService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> IndexRewardService
    DESCRIPTION: Manages Pet Index Zone Mastery & Trophy Bat Rewards:
                 - Automatically indexes hatched pets
                 - Verifies full 3/3 pet discovery per Biome
                 - Awards exclusive Biome Bats (Mossy, Obsidian, Magma, Celestial)
                 - Hooks ProximityPrompt on Deco_IndexPedestal in village plaza
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BatConfig = require(ReplicatedStorage:WaitForChild("BatConfig"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))

local indexRemote = ReplicatedStorage:WaitForChild("IndexRewardRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")

-- Helper: Create weapon tool for player inventory
local function GivePlayerBatTool(player: Player, batId: string)
    local config = BatConfig.GetBat(batId)
    if not config then return end

    local bp = player:FindFirstChild("Backpack")
    local char = player.Character

    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("BatId") then
                item:Destroy()
            end
        end
    end
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("BatId") then
                item:Destroy()
            end
        end
    end

    local tool = Instance.new("Tool")
    tool.Name = config.Name
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool:SetAttribute("BatId", config.Id)
    tool.GripPos = Vector3.new(0, -1.2, 0)

    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.6, 3.4, 0.6)
    handle.Material = config.HandleMaterial
    handle.Color = config.HandleColor
    handle.CanCollide = false
    handle.Parent = tool

    if config.Rarity == "Legendary" then
        local pl = Instance.new("PointLight")
        pl.Color = config.HandleColor
        pl.Brightness = 2.0
        pl.Range = 10
        pl.Parent = handle
    end

    tool.Parent = bp or char
end

-- 1. Sync Index and backfill existing pets on Player join
local function SyncPlayerIndex(player: Player)
    local pData = DataService.GetData(player)
    if not pData then return end

    pData.DiscoveredPets = pData.DiscoveredPets or {}
    (pData :: any).ClaimedIndexBats = (pData :: any).ClaimedIndexBats or {}

    -- Backfill from current pets
    if pData.Pets then
        for _, pet in ipairs(pData.Pets) do
            pData.DiscoveredPets[pet.Id] = true
        end
    end

    -- Default unlock starter wooden bat if zone 1 completed
    indexRemote:FireClient(player, "SyncIndexData", {
        DiscoveredPets = pData.DiscoveredPets,
        ClaimedBats = (pData :: any).ClaimedIndexBats or {},
        OwnedBats = pData.OwnedBats or { "wooden_bat" },
        EquippedBat = pData.EquippedBat or "wooden_bat"
    })
end

-- 2. Hook Prompt on 3D Pedestal
local function HookPedestalPrompt()
    local ped = arena:WaitForChild("Deco_IndexPedestal", 10)
    local col = ped and ped:WaitForChild("Deco_PedestalColumn", 10)
    local prompt = col and col:WaitForChild("IndexPrompt", 10) :: ProximityPrompt?
    if prompt then
        prompt.Triggered:Connect(function(player)
            SyncPlayerIndex(player)
            indexRemote:FireClient(player, "OpenIndexUI")
        end)
    end
end

-- 3. Claim Zone Bat Reward
local function ClaimZoneReward(player: Player, zoneId: number): boolean
    local rewardInfo = BatConfig.GetZoneReward(zoneId)
    if not rewardInfo then return false end

    local pData = DataService.GetData(player)
    if not pData then return false end

    pData.DiscoveredPets = pData.DiscoveredPets or {}
    local claimed = (pData :: any).ClaimedIndexBats or {}
    (pData :: any).ClaimedIndexBats = claimed

    if claimed["Zone_" .. zoneId] == true then
        return false -- Already claimed
    end

    -- Verify all 3 required pets are discovered
    local discoveredCount = 0
    for _, petId in ipairs(rewardInfo.RequiredPets) do
        if pData.DiscoveredPets[petId] == true then
            discoveredCount = discoveredCount + 1
        end
    end

    if discoveredCount < #rewardInfo.RequiredPets then
        return false -- Chưa đủ 3/3 pets!
    end

    -- Grant Bat Reward
    local batId = rewardInfo.BatId
    claimed["Zone_" .. zoneId] = true
    DataService.AddBat(player, batId)
    DataService.EquipBat(player, batId)
    GivePlayerBatTool(player, batId)

    indexRemote:FireClient(player, "BatClaimedSuccess", {
        BatId = batId,
        ZoneId = zoneId,
        BatName = BatConfig.GetBat(batId).Name
    })

    -- Global Celebration Announcement
    local msg = string.format("🏆 %s MASTERED %s & UNLOCKED %s!", string.upper(player.DisplayName), string.upper(rewardInfo.ZoneName), string.upper(BatConfig.GetBat(batId).Name))
    for _, p in ipairs(Players:GetPlayers()) do
        indexRemote:FireClient(p, "GlobalMasteryAlert", msg)
    end
    print(string.format("[IndexReward] %s completed Zone %d Index -> Claimed '%s'!", player.Name, zoneId, batId))
    return true
end

-- 4. Remote Event Listeners
indexRemote.OnServerEvent:Connect(function(player: Player, action: string, arg: any)
    if action == "RequestSync" then
        SyncPlayerIndex(player)
    elseif action == "ClaimZoneBat" and typeof(arg) == "number" then
        ClaimZoneReward(player, arg)
    elseif action == "EquipOwnedBat" and typeof(arg) == "string" then
        local pData = DataService.GetData(player)
        if pData and DataService.OwnsBat(player, arg) then
            DataService.EquipBat(player, arg)
            GivePlayerBatTool(player, arg)
            SyncPlayerIndex(player)
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    task.wait(2.0)
    SyncPlayerIndex(player)
end)

for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(SyncPlayerIndex, p)
end

HookPedestalPrompt()
print("[IndexRewardService] ✅ Pet Index & Trophy Bat System initialized successfully!")
