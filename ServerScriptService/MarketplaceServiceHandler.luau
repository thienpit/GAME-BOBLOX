--!strict
--[[
    TÊN SCRIPT: MarketplaceServiceHandler
    LOẠI: Script (Server-side)
    VỊ TRÍ: ServerScriptService -> MarketplaceServiceHandler
    MÔ TẢ: Xử lý mua bán qua MarketplaceService chuẩn Roblox Production:
          kiểm tra 3 Gamepass khi người chơi vào game, cập nhật realtime khi mua in-game,
          xử lý ProcessReceipt chuẩn chỉ (chống cấp trùng bằng PurchaseId, không mất tiền khi lỗi mạng).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local monetizationRemote = ReplicatedStorage:WaitForChild("MonetizationRemote") :: RemoteEvent

-- =============================================================================
-- DATASTORE LƯU LỊCH SỬ GIAO DỊCH DEVELOPER PRODUCT (CHỐNG CẤP TRÙNG)
-- =============================================================================
local mockPurchaseHistory: { [string]: boolean } = {}
local realHistoryStore: any = nil

local connectSuccess, connectResult = pcall(function()
    return DataStoreService:GetDataStore("StealEgg_PurchaseHistory_v1.0")
end)

if connectSuccess and connectResult then
    realHistoryStore = connectResult
else
    warn("[Marketplace] Cloud DataStore unavailable. Using RAM Mock History!")
end

local function IsPurchaseProcessed(purchaseId: string): boolean
    if realHistoryStore then
        local success, result = pcall(function()
            return realHistoryStore:GetAsync(purchaseId)
        end)
        if success and result == true then
            return true
        end
        return false
    else
        return mockPurchaseHistory[purchaseId] == true
    end
end

local function MarkPurchaseProcessed(purchaseId: string): boolean
    if realHistoryStore then
        local success, _ = pcall(function()
            realHistoryStore:SetAsync(purchaseId, true)
        end)
        return success
    else
        mockPurchaseHistory[purchaseId] = true
        return true
    end
end

-- =============================================================================
-- 1. XỬ LÝ PROCESSRECEIPT (DEVELOPER PRODUCTS) CHUẨN ROBLOX PRODUCTION
-- =============================================================================
MarketplaceService.ProcessReceipt = function(receiptInfo: {
    PlayerId: number,
    PlaceIdWherePurchased: number,
    PurchaseId: string,
    ProductId: number,
    CurrencySpent: number,
    CurrencyType: Enum.CurrencyType
}): Enum.ProductPurchaseDecision
    local purchaseId = receiptInfo.PurchaseId
    
    -- BƯỚC 1: KIỂM TRA CHỐNG CẤP TRÙNG
    if IsPurchaseProcessed(purchaseId) then
        print(string.format("[ProcessReceipt] Transaction %s already processed. Completed!", purchaseId))
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    
    -- BƯỚC 2: TÌM NGƯỜI CHƠI TRONG SERVER
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Người chơi đã thoát game: Không cấp lúc này, yêu cầu Roblox gửi lại sau
        warn(string.format("[ProcessReceipt] Player %d not in server. Postponing retry!", receiptInfo.PlayerId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    local productConfig = MonetizationConfig.PRODUCTS[receiptInfo.ProductId]
    if not productConfig then
        warn(string.format("[ProcessReceipt] ProductId %d not found in config!", receiptInfo.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- BƯỚC 3: TRAO THƯỞNG CHO NGƯỜI CHƠI
    local grantSuccess = false
    if productConfig.RewardType == "Money" then
        local addAmount = tonumber(productConfig.RewardValue) or 0
        DataService.AddMoney(player, addAmount)
        grantSuccess = true
        print(string.format("[ProcessReceipt] Granted %d Cash to %s!", addAmount, player.Name))
    elseif productConfig.RewardType == "Egg" then
        local eggName = tostring(productConfig.RewardValue)
        DataService.AddEgg(player, {
            Id = HttpService:GenerateGUID(false),
            EggType = eggName,
            ZoneId = 4,
            AcquiredAt = os.time()
        })
        grantSuccess = true
        print(string.format("[ProcessReceipt] Granted egg '%s' to %s!", eggName, player.Name))
    end
    
    if not grantSuccess then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    
    -- BƯỚC 4: LƯU LỊCH SỬ GIAO DỊCH & LƯU DỮ LIỆU NGƯỜI CHƠI
    MarkPurchaseProcessed(purchaseId)
    DataService.SaveProfile(player, false)
    
    -- Thông báo chúc mừng cho Client
    monetizationRemote:FireClient(player, "PurchaseSuccess", "Product", productConfig.Name)
    
    -- BƯỚC 5: XÁC NHẬN ROBLOX ĐÃ GIAO DỊCH THÀNH CÔNG
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- =============================================================================
-- 2. KIỂM TRA & KÍCH HOẠT GAMEPASS KHI NGƯỜI CHƠI VÀO GAME
-- =============================================================================
local function CheckPlayerGamepasses(player: Player)
    for passKey, passInfo in pairs(MonetizationConfig.GAMEPASSES) do
        local success, hasPass = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passInfo.Id)
        end)
        
        if success and hasPass then
            player:SetAttribute(passInfo.AttributeKey, true)
            print(string.format("[Gamepass] %s owns '%s'!", player.Name, passInfo.Name))
        else
            player:SetAttribute(passInfo.AttributeKey, false)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(function()
        CheckPlayerGamepasses(player)
    end)
end)

-- =============================================================================
-- 3. XỬ LÝ MUA GAMEPASS THÀNH CÔNG TRỰC TIẾP TRONG GAME (REALTIME)
-- =============================================================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
    if wasPurchased then
        for _, passInfo in pairs(MonetizationConfig.GAMEPASSES) do
            if passInfo.Id == gamePassId then
                player:SetAttribute(passInfo.AttributeKey, true)
                print(string.format("[Gamepass] %s purchased '%s' in-game!", player.Name, passInfo.Name))
                monetizationRemote:FireClient(player, "PurchaseSuccess", "Gamepass", passInfo.Name)
                break
            end
        end
    end
end)

-- =============================================================================
-- 4. BẮT YÊU CẦU MUA TỪ CLIENT (PROMPT PURCHASE)
-- =============================================================================
monetizationRemote.OnServerEvent:Connect(function(player: Player, action: string, itemId: any)
    local RunService = game:GetService("RunService")
    
    if action == "PromptGamepass" then
        local passKey = tostring(itemId)
        local passInfo = MonetizationConfig.GAMEPASSES[passKey]
        if not passInfo then return end
        
        -- In Studio: Simulate instant purchase for testing
        if RunService:IsStudio() then
            player:SetAttribute(passInfo.AttributeKey, true)
            print(string.format("[Gamepass TEST] %s unlocked '%s' (Studio Simulation)!", player.Name, passInfo.Name))
            monetizationRemote:FireClient(player, "PurchaseSuccess", "Gamepass", passInfo.Name)
            
            -- If extra slots, immediately update pedestal
            if passInfo.AttributeKey == "HasExtraSlots" then
                local arena = workspace:FindFirstChild("Arena_Map")
                local bases = arena and arena:FindFirstChild("Bases")
                if bases then
                    for _, b in ipairs(bases:GetChildren()) do
                        if b:GetAttribute("OwnerUserId") == player.UserId then
                            local sss = game:GetService("ServerScriptService")
                            local ds = require(sss.DataService)
                            local pData = ds.GetData(player)
                            local uc = require(game:GetService("ReplicatedStorage").UpgradeConfig)
                            local pedTier = uc.PEDESTAL_TIERS[pData and pData.PedestalLevel or 1]
                            local slots = (pedTier and pedTier.Slots or 3) + 2
                            -- Update slots
                            local station = b:FindFirstChild("IncubationStation")
                            local tablePart = station and station:FindFirstChild("PedestalTable") :: BasePart?
                            if tablePart then
                                tablePart.Size = Vector3.new(12, 1.2, math.max(28, slots * 7.5))
                            end
                        end
                    end
                end
            end
        else
            MarketplaceService:PromptGamePassPurchase(player, passInfo.Id)
        end
        
    elseif action == "PromptProduct" then
        local prodId = tonumber(itemId)
        local prodInfo = prodId and MonetizationConfig.PRODUCTS[prodId]
        if not prodInfo then return end
        
        -- In Studio: Simulate instant product purchase
        if RunService:IsStudio() then
            if prodInfo.RewardType == "Money" then
                DataService.AddMoney(player, tonumber(prodInfo.RewardValue) or 10000)
                print(string.format("[Product TEST] Granted $%d Cash to %s (Studio Simulation)!", prodInfo.RewardValue, player.Name))
            elseif prodInfo.RewardType == "Egg" then
                DataService.AddEgg(player, {
                    Id = HttpService:GenerateGUID(false),
                    EggType = tostring(prodInfo.RewardValue),
                    ZoneId = 4,
                    AcquiredAt = os.time()
                })
                print(string.format("[Product TEST] Granted egg '%s' to %s (Studio Simulation)!", prodInfo.RewardValue, player.Name))
            end
            DataService.SaveProfile(player, false)
            monetizationRemote:FireClient(player, "PurchaseSuccess", "Product", prodInfo.Name)
        else
            MarketplaceService:PromptProductPurchase(player, prodId)
        end
    end
end)