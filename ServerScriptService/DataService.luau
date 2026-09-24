--!strict
--[[
    TÊN SCRIPT: DataService
    LOẠI: ModuleScript
    VỊ TRÍ: ServerScriptService -> DataService
    MÔ TẢ: Hệ thống lưu trữ dữ liệu tập trung với Session Locking, Exponential Backoff, UserId Indexing và Mock Fallback cho Studio
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataTemplate = require(ReplicatedStorage:WaitForChild("PlayerDataTemplate"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local TrailConfig = require(ReplicatedStorage:WaitForChild("TrailConfig"))
type PlayerData = PlayerDataTemplate.PlayerData
type PetData = PlayerDataTemplate.PetData
type EggData = PlayerDataTemplate.EggData

local DATASTORE_NAME = "StealEgg_PlayerProfile_v1.0"
local PROFILE_KEY_PREFIX = "Player_"
local SESSION_TIMEOUT = 900 -- 15 phút

-- =============================================================================
-- DATASTORE CONNECTION & STUDIO MOCK FALLBACK
-- =============================================================================
local mockMemoryStore: { [string]: any } = {}
local realDataStore: any = nil

local connectSuccess, connectResult = pcall(function()
    return DataStoreService:GetDataStore(DATASTORE_NAME)
end)

if connectSuccess and connectResult then
    -- PROBE: Try one real DataStore call to verify API access is actually enabled
    local probeOk, probeErr = pcall(function()
        connectResult:UpdateAsync("__probe_connection_test", function(old)
            return old -- No-op transform, just test access
        end)
    end)

    if probeOk then
        realDataStore = connectResult
        print("[DataService] ✅ Cloud DataStore connected and verified!")
    else
        realDataStore = nil
        warn("[DataService] ⚠️ DataStore object exists but API access denied (Studio). Using Mock Store. (" .. tostring(probeErr) .. ")")
    end
else
    warn("[DataService] Không thể kết nối Cloud DataStore. Tự động kích hoạt Mock Memory Store!")
end

local StorageAdapter = {}

function StorageAdapter.UpdateAsync(key: string, transformFunc: (any) -> any): any
    if realDataStore then
        return realDataStore:UpdateAsync(key, transformFunc)
    else
        local current = mockMemoryStore[key]
        local updated = transformFunc(current)
        if updated ~= nil then
            mockMemoryStore[key] = updated
        end
        return updated
    end
end

-- =============================================================================
-- SERVICE STATE & CACHE (INDEXED BY USERID)
-- =============================================================================
local DataService = {}
local loadedProfiles: { [number]: PlayerData } = {}
local isSaving: { [number]: boolean } = {}

local function RetryOperation<T>(operation: () -> T, maxAttempts: number?): (boolean, T?)
    local attempts = maxAttempts or 3
    for i = 1, attempts do
        local success, result = pcall(operation)
        if success then
            return true, result
        end
        warn(string.format("[DataService] Lần thử %d/%d thất bại: %s", i, attempts, tostring(result)))
        if i < attempts then
            task.wait(math.pow(2, i) * 0.5)
        end
    end
    return false, nil
end

local function UpdateLeaderstats(player: Player, data: PlayerData)
    local ls = player:FindFirstChild("leaderstats")
    if not ls then
        ls = Instance.new("Folder")
        ls.Name = "leaderstats"
        ls.Parent = player
    end
    
    local cash = ls:FindFirstChild("Money") :: IntValue?
    if not cash then
        cash = Instance.new("IntValue")
        cash.Name = "Money"
        cash.Parent = ls
    end
    cash.Value = data.Money
    
    local speed = ls:FindFirstChild("Speed") :: IntValue?
    if not speed then
        speed = Instance.new("IntValue")
        speed.Name = "Speed"
        speed.Parent = ls
    end
    
    local pts = data.SpeedPoints or 0
    speed.Value = math.clamp(pts, 0, 2147483647)

    -- Set precision attributes for UI, Trail & Physics
    player:SetAttribute("SpeedPoints", pts)
    player:SetAttribute("RealWalkSpeed", data.Speed or 16)
    player:SetAttribute("EquippedTrail", data.EquippedTrail or "trail_dust")
end

-- =============================================================================
-- PROFILE MANAGEMENT & SESSION LOCKING
-- =============================================================================

function DataService.LoadProfile(player: Player): boolean
    local userId = player.UserId
    if loadedProfiles[userId] then
        return true -- Đã load sẵn trong cache
    end

    -- FAST PATH: If mock mode (no real DataStore), create mock profile immediately
    if not realDataStore then
        local mockProf = PlayerDataTemplate.CreateNewProfile()
        if mockProf.SpeedPoints == nil then mockProf.SpeedPoints = 0 end
        mockProf.Speed = UpgradeConfig.GetRealWalkSpeed(mockProf.SpeedPoints)
        loadedProfiles[userId] = mockProf
        UpdateLeaderstats(player, mockProf)
        print(string.format("[DataService] Mock profile loaded for %s (Money: %d | Speed: %d)", player.Name, mockProf.Money, mockProf.Speed))
        return true
    end

    local storeKey = PROFILE_KEY_PREFIX .. tostring(userId)
    local myJobId = game.JobId ~= "" and game.JobId or "StudioSession"
    local now = os.time()
    
    local success, profileResult = RetryOperation(function()
        return StorageAdapter.UpdateAsync(storeKey, function(storedValue: any)
            local currentProfile: PlayerData
            
            if storedValue == nil then
                currentProfile = PlayerDataTemplate.CreateNewProfile()
                currentProfile.ActiveSession = myJobId .. "_" .. tostring(now)
                currentProfile.LastSaved = now
                return currentProfile
            else
                currentProfile = storedValue :: PlayerData
                
                -- KIỂM TRA SESSION LOCK (CHỐNG DUP ĐỒ KHI ĐỔI SERVER NHANH)
                if currentProfile.ActiveSession ~= nil and currentProfile.ActiveSession ~= "" then
                    local sessionParts = string.split(currentProfile.ActiveSession, "_")
                    local activeJobId = sessionParts[1]
                    local sessionTimestamp = tonumber(sessionParts[2]) or 0
                    
                    if activeJobId ~= myJobId and (now - sessionTimestamp) < SESSION_TIMEOUT then
                        return nil -- Phiên cũ vẫn đang mở ở server khác
                    end
                end
                
                currentProfile.ActiveSession = myJobId .. "_" .. tostring(now)
                currentProfile.LastSaved = now
                return currentProfile
            end
        end)
    end)
    
    if not success or profileResult == nil then
        if RunService:IsStudio() then
            warn("[DataService] Studio API disabled (403). Automatically loaded Local Mock Profile for testing!")
            local mockProf = PlayerDataTemplate.CreateNewProfile()
            loadedProfiles[userId] = mockProf
            UpdateLeaderstats(player, mockProf)
            return true
        end
        player:Kick("Your data is currently active on another server. Please rejoin in 30 seconds!")
        return false
    end
    
    local finalProfile = profileResult :: PlayerData
    for k, v in pairs(PlayerDataTemplate.DEFAULT_DATA) do
        if (finalProfile :: any)[k] == nil then
            (finalProfile :: any)[k] = v
        end
    end
    
    loadedProfiles[userId] = finalProfile
    UpdateLeaderstats(player, finalProfile)
    print(string.format("[DataService] Tải thành công dữ liệu cho %s (Money: %d | Speed: %d)", player.Name, finalProfile.Money, finalProfile.Speed))
    return true
end

function DataService.SaveProfile(player: Player, isClosingSession: boolean?): boolean
    local userId = player.UserId
    local profile = loadedProfiles[userId]
    if not profile then return false end
    if isSaving[userId] then return false end
    
    isSaving[userId] = true
    local storeKey = PROFILE_KEY_PREFIX .. tostring(userId)
    local now = os.time()
    
    local success, _ = RetryOperation(function()
        return StorageAdapter.UpdateAsync(storeKey, function(storedValue: any)
            profile.LastSaved = now
            if isClosingSession then
                profile.ActiveSession = nil
            end
            return profile
        end)
    end)
    
    isSaving[userId] = nil
    
    if success then
        print(string.format("[DataService] Lưu thành công cho %s (Closing: %s)", player.Name, tostring(isClosingSession)))
    else
        warn(string.format("[DataService] Lưu thất bại cho %s!", player.Name))
    end
    
    if isClosingSession then
        loadedProfiles[userId] = nil
    end
    
    return success
end

-- =============================================================================
-- PUBLIC DATA ACCESSORS (GET / SET / ADD / REMOVE)
-- =============================================================================

function DataService.GetData(player: Player): PlayerData?
    local userId = player.UserId
    local profile = loadedProfiles[userId]
    if not profile then
        DataService.LoadProfile(player)
        profile = loadedProfiles[userId]
    end
    return profile
end

function DataService.SetData(player: Player, key: string, value: any): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    (profile :: any)[key] = value
    if key == "Money" or key == "Speed" then
        UpdateLeaderstats(player, profile)
    end
    return true
end

function DataService.AddMoney(player: Player, amount: number): number
    local profile = DataService.GetData(player)
    if not profile then return 0 end
    if amount <= 0 or amount ~= amount then return profile.Money end
    
    profile.Money = math.clamp(profile.Money + math.floor(amount), 0, 10^14)
    UpdateLeaderstats(player, profile)
    return profile.Money
end

function DataService.SubMoney(player: Player, amount: number): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    if amount <= 0 or amount ~= amount then return false end
    
    local cost = math.floor(amount)
    if profile.Money >= cost then
        profile.Money = profile.Money - cost
        UpdateLeaderstats(player, profile)
        return true
    end
    return false
end

function DataService.AddSpeedPoints(player: Player, pointsToAdd: number): (number, number)
    local profile = DataService.GetData(player)
    if not profile then return 0, 16 end
    if pointsToAdd <= 0 then return profile.SpeedPoints or 0, profile.Speed or 16 end

    local currentPts = profile.SpeedPoints or 0
    local newPts = math.clamp(currentPts + math.floor(pointsToAdd), 0, 10^15)
    profile.SpeedPoints = newPts
    
    profile.Speed = UpgradeConfig.GetRealWalkSpeed(newPts)
    
    local bestTrail = TrailConfig.GetTrailForPoints(newPts)
    profile.EquippedTrail = bestTrail.Id

    UpdateLeaderstats(player, profile)

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local isCarrying = char and (char:GetAttribute("IsCarryingRock") or char:GetAttribute("IsCarryingEgg"))
    if hum and not isCarrying then
        hum.WalkSpeed = profile.Speed
    end

    return profile.SpeedPoints, profile.Speed
end

function DataService.AddSpeed(player: Player, amount: number): number
    local _, realSpd = DataService.AddSpeedPoints(player, amount * 25)
    return realSpd
end

function DataService.AddPet(player: Player, pet: PetData): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    table.insert(profile.Pets, pet)

    -- Tự động ghi nhận thú cưng vào Pet Index
    profile.DiscoveredPets = profile.DiscoveredPets or {}
    profile.DiscoveredPets[pet.Id] = true

    local indexRemote = ReplicatedStorage:FindFirstChild("IndexRewardRemote") :: RemoteEvent?
    if indexRemote then
        indexRemote:FireClient(player, "SyncIndexData", {
            DiscoveredPets = profile.DiscoveredPets,
            ClaimedBats = (profile :: any).ClaimedIndexBats or {},
            OwnedBats = profile.OwnedBats or { "wooden_bat" },
            EquippedBat = profile.EquippedBat or "wooden_bat"
        })
    end

    return true
end

function DataService.RemovePet(player: Player, petId: string): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    for idx, pet in ipairs(profile.Pets) do
        if pet.Id == petId then
            table.remove(profile.Pets, idx)
            return true
        end
    end
    return false
end

function DataService.AddEgg(player: Player, egg: EggData): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    table.insert(profile.Eggs, egg)
    return true
end

function DataService.RemoveEgg(player: Player, eggId: string): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    for idx, egg in ipairs(profile.Eggs) do
        if egg.Id == eggId then
            table.remove(profile.Eggs, idx)
            return true
        end
    end
    return false
end

function DataService.OwnsBat(player: Player, batId: string): boolean
    local profile = DataService.GetData(player)
    if not profile or not profile.OwnedBats then return batId == "wooden_bat" end
    for _, bId in ipairs(profile.OwnedBats) do
        if bId == batId then return true end
    end
    return false
end

function DataService.AddBat(player: Player, batId: string): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    profile.OwnedBats = profile.OwnedBats or { "wooden_bat" }
    
    if not DataService.OwnsBat(player, batId) then
        table.insert(profile.OwnedBats, batId)
        return true
    end
    return false
end

function DataService.EquipBat(player: Player, batId: string): boolean
    local profile = DataService.GetData(player)
    if not profile then return false end
    
    if DataService.OwnsBat(player, batId) then
        profile.EquippedBat = batId
        return true
    end
    return false
end

function DataService.UpgradePedestal
(player: Player): number
    local profile = DataService.GetData(player)
    if not profile then return 1 end
    profile.PedestalLevel = (profile.PedestalLevel or 1) + 1
    return profile.PedestalLevel
end

function DataService.UpgradeTreadmill(player: Player): number
    local profile = DataService.GetData(player)
    if not profile then return 1 end
    profile.TreadmillLevel = (profile.TreadmillLevel or 1) + 1
    return profile.TreadmillLevel
end

function DataService.IsPurchaseGrantedInProfile(player: Player, purchaseId: string): boolean
    local profile = loadedProfiles[player.UserId]
    if not profile or not profile.ProcessedPurchases then return false end
    return profile.ProcessedPurchases[purchaseId] == true
end

function DataService.RecordPurchaseInProfile(player: Player, purchaseId: string)
    local profile = loadedProfiles[player.UserId]
    if not profile then return end
    if not profile.ProcessedPurchases then
        profile.ProcessedPurchases = {}
    end
    profile.ProcessedPurchases[purchaseId] = true
end

function DataService.SaveAll
(isServerShutdown: boolean)
    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        task.spawn(function()
            DataService.SaveProfile(player, isServerShutdown)
        end)
    end
end

return DataService
