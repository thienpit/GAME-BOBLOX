--!strict
--[[
    TÊN SCRIPT: RetentionService
    LOẠI: Script (Server-side)
    VỊ TRÍ: ServerScriptService -> RetentionService
    MÔ TẢ: Quản lý Bảng xếp hạng giàu nhất (OrderedDataStore + 3D Board),
          Quà đăng nhập 7 ngày (Daily Rewards), 3 Nhiệm vụ hằng ngày reset lúc 0h UTC,
          Sổ tay sưu tầm thú cưng (Pet Index) và lưu trạng thái Tutorial tân thủ.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local RetentionConfig = require(ReplicatedStorage:WaitForChild("RetentionConfig"))
local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local retentionRemote = ReplicatedStorage:WaitForChild("RetentionRemote") :: RemoteEvent
local getRetentionData = ReplicatedStorage:WaitForChild("GetRetentionData") :: RemoteFunction

local arena = workspace:WaitForChild("Arena_Map")
local lbModel = arena:WaitForChild("WorldLeaderboard")
local lbGui = lbModel:WaitForChild("DisplayBoard"):WaitForChild("LeaderboardGui")
local listFrame = lbGui:WaitForChild("Frame"):WaitForChild("ListFrame")

-- =============================================================================
-- 1. QUẢN LÝ ORDERED DATASTORE BẢNG XẾP HẠNG (CÓ MOCK CHO STUDIO)
-- =============================================================================
local mockLeaderboard: { [string]: number } = {}
local realLeaderboardStore: any = nil

local connectSuccess, connectResult = pcall(function()
    return DataStoreService:GetOrderedDataStore("StealEgg_RichestLeaderboard_v1.0")
end)

if connectSuccess and connectResult then
    -- PROBE: Verify actual API access in Studio
    local probeOk = pcall(function()
        connectResult:GetSortedAsync(false, 1)
    end)
    if probeOk then
        realLeaderboardStore = connectResult
        print("[RetentionService] ✅ Cloud OrderedDataStore connected and verified!")
    else
        realLeaderboardStore = nil
        warn("[RetentionService] ⚠️ Studio API access disabled. Using Mock Leaderboard!")
    end
else
    warn("[RetentionService] API Services disabled in Studio. Using Mock Leaderboard!")
end

local function UpdatePlayerRankData(player: Player, money: number)
    local key = tostring(player.UserId)
    if realLeaderboardStore then
        pcall(function()
            realLeaderboardStore:SetAsync(key, math.clamp(money, 0, 10^11))
        end)
    else
        mockLeaderboard[key] = money
    end
end

local function FetchTopPlayers(): { { Rank: number, UserId: number, Name: string, Money: number } }
    local topList = {}
    
    if realLeaderboardStore then
        local success, pages = pcall(function()
            return realLeaderboardStore:GetSortedAsync(false, RetentionConfig.LEADERBOARD_TOP_COUNT)
        end)
        
        if success and pages then
            local entries = pages:GetCurrentPage()
            for rank, entry in ipairs(entries) do
                local uId = tonumber(entry.key) or 0
                local pName = "Player_" .. uId
                pcall(function()
                    pName = Players:GetNameFromUserIdAsync(uId)
                end)
                table.insert(topList, {
                    Rank = rank,
                    UserId = uId,
                    Name = pName,
                    Money = entry.value
                })
            end
        end
    else
        -- Sắp xếp từ Mock RAM
        local sortedArray = {}
        for uKey, val in pairs(mockLeaderboard) do
            table.insert(sortedArray, { UserId = tonumber(uKey) or 0, Money = val })
        end
        table.sort(sortedArray, function(a, b) return a.Money > b.Money end)
        
        for rank = 1, math.min(#sortedArray, RetentionConfig.LEADERBOARD_TOP_COUNT) do
            local item = sortedArray[rank]
            local pName = "Player_" .. item.UserId
            for _, onlineP in ipairs(Players:GetPlayers()) do
                if onlineP.UserId == item.UserId then
                    pName = onlineP.DisplayName
                    break
                end
            end
            table.insert(topList, {
                Rank = rank,
                UserId = item.UserId,
                Name = pName,
                Money = item.Money
            })
        end
    end
    
    return topList
end

-- Cập nhật giao diện bảng xếp hạng 3D trong làng
local function RefreshWorldLeaderboardUI()
    -- Cập nhật dữ liệu người chơi đang online
    for _, player in ipairs(Players:GetPlayers()) do
        local pData = DataService.GetData(player)
        if pData then
            UpdatePlayerRankData(player, pData.Money)
        end
    end
    
    local topPlayers = FetchTopPlayers()
    for rank = 1, 10 do
        local row = listFrame:FindFirstChild("Rank_" .. rank)
        if row then
            local data = topPlayers[rank]
            local nameLbl = row:FindFirstChild("PlayerName") :: TextLabel?
            local moneyLbl = row:FindFirstChild("MoneyVal") :: TextLabel?
            
            if data and nameLbl and moneyLbl then
                nameLbl.Text = data.Name
                moneyLbl.Text = "$" .. string.format("%d", data.Money)
            elseif nameLbl and moneyLbl then
                nameLbl.Text = "---"
                moneyLbl.Text = "$0"
            end
        end
    end
end

-- Vòng lặp tự động cập nhật bảng xếp hạng mỗi 60 giây
task.spawn(function()
    while true do
        task.wait(RetentionConfig.LEADERBOARD_UPDATE_INTERVAL)
        RefreshWorldLeaderboardUI()
    end
end)

-- =============================================================================
-- 2. NHIỆM VỤ HẰNG NGÀY (3 NHIỆM VỤ RESET LÚC 0H UTC)
-- =============================================================================
local function CheckDailyQuestReset(pData: any)
    local currentUtcDay = math.floor(os.time() / 86400)
    if pData.QuestDayId ~= currentUtcDay then
        pData.QuestDayId = currentUtcDay
        pData.QuestProgress = {
            HatchEggs = 0,
            StealZoneEggs = 0,
            BatHits = 0
        }
        pData.QuestClaimed = {
            HatchEggs = false,
            StealZoneEggs = false,
            BatHits = false
        }
    end
end

-- =============================================================================
-- 3. TRUY VẤN VÀ XỬ LÝ SỰ KIỆN RETENTION (DAILY / QUESTS / INDEX)
-- =============================================================================
getRetentionData.OnServerInvoke = function(player: Player)
    local pData = DataService.GetData(player)
    if not pData then return nil end
    
    CheckDailyQuestReset(pData)
    
    local now = os.time()
    local canClaimDaily = (now - (pData.LastDailyClaimTime or 0)) >= (86400 - 3600) -- 23 giờ chờ
    
    return {
        Money = pData.Money,
        Speed = pData.Speed,
        DailyStreak = pData.DailyStreak or 1,
        CanClaimDaily = canClaimDaily,
        LastDailyClaimTime = pData.LastDailyClaimTime or 0,
        QuestDayId = pData.QuestDayId,
        QuestProgress = pData.QuestProgress,
        QuestClaimed = pData.QuestClaimed,
        DiscoveredPets = pData.DiscoveredPets or {},
        TutorialDone = pData.TutorialDone or false,
        AllPetsCatalog = RockPetConfig.PETS
    }
end

retentionRemote.OnServerEvent:Connect(function(player: Player, action: string, arg1: any)
    local pData = DataService.GetData(player)
    if not pData then return end
    
    if action == "ClaimDailyReward" then
        local now = os.time()
        local lastClaim = pData.LastDailyClaimTime or 0
        local timeDiff = now - lastClaim
        
        -- Kiểm tra đủ 23 giờ từ lần nhận trước
        if timeDiff < (86400 - 3600) and lastClaim ~= 0 then return end
        
        -- Nếu bỏ lỡ quá 48 giờ -> Chuỗi quay về Ngày 1
        local currentStreak = pData.DailyStreak or 1
        if timeDiff > (86400 * 2) and lastClaim ~= 0 then
            currentStreak = 1
        end
        
        local reward = RetentionConfig.DAILY_REWARDS[currentStreak]
        if not reward then return end
        
        -- Trao thưởng theo cấu hình
        if reward.RewardType == "Money" then
            DataService.AddMoney(player, tonumber(reward.RewardValue) or 0)
        elseif reward.RewardType == "Speed" then
            DataService.AddSpeed(player, tonumber(reward.RewardValue) or 0)
        elseif reward.RewardType == "Egg" then
            DataService.AddEgg(player, {
                Id = HttpService:GenerateGUID(false),
                EggType = tostring(reward.RewardValue),
                ZoneId = 2,
                AcquiredAt = now
            })
        elseif reward.RewardType == "SpecialPet" then
            DataService.AddMoney(player, 5000)
            DataService.AddPet(player, {
                Id = "pebble_dog",
                Name = "Golden Pebble Dog 👑",
                Rarity = "Legendary",
                Size = "Big",
                Mutation = "Golden",
                ObtainedAt = now
            })
            pData.DiscoveredPets = pData.DiscoveredPets or {}
            pData.DiscoveredPets["pebble_dog"] = true
        end
        
        pData.LastDailyClaimTime = now
        pData.DailyStreak = (currentStreak % 7) + 1
        DataService.SaveProfile(player, false)
        
        retentionRemote:FireClient(player, "RetentionRefresh")
        print(string.format("[RetentionService] %s claimed Day %d Reward (%s)!", player.Name, currentStreak, reward.RewardName))
        
    elseif action == "ClaimQuestReward" then
        CheckDailyQuestReset(pData)
        local questId = tostring(arg1)
        local questInfo = RetentionConfig.DAILY_QUESTS[questId]
        if not questInfo then return end
        
        local currentProgress = (pData.QuestProgress and pData.QuestProgress[questId]) or 0
        local alreadyClaimed = (pData.QuestClaimed and pData.QuestClaimed[questId]) == true
        
        if currentProgress >= questInfo.TargetCount and not alreadyClaimed then
            DataService.AddMoney(player, questInfo.RewardMoney)
            pData.QuestClaimed = pData.QuestClaimed or {}
            pData.QuestClaimed[questId] = true
            DataService.SaveProfile(player, false)
            
            retentionRemote:FireClient(player, "RetentionRefresh")
            print(string.format("[RetentionService] %s completed quest '%s' (+%d$)!", player.Name, questInfo.Title, questInfo.RewardMoney))
        end
        
    elseif action == "CompleteTutorial" then
        pData.TutorialDone = true
        DataService.SaveProfile(player, false)
        retentionRemote:FireClient(player, "TutorialClosed")
    end
end)

-- Tự động kích hoạt khi người chơi vào game
Players.PlayerAdded:Connect(function(player)
    task.wait(1.5)
    local pData = DataService.GetData(player)
    if pData then
        CheckDailyQuestReset(pData)
        pData.DiscoveredPets = pData.DiscoveredPets or {}
        -- Đăng ký pet đang có vào sổ tay Index
        if pData.Pets then
            for _, pet in ipairs(pData.Pets) do
                pData.DiscoveredPets[pet.Id] = true
            end
        end
        UpdatePlayerRankData(player, pData.Money)
        RefreshWorldLeaderboardUI()
    end
end)
