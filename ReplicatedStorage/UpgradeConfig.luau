--!strict
--[[
    TÊN SCRIPT: UpgradeConfig
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> UpgradeConfig
    MÔ TẢ: Bảng thông số, công thức quy đổi SpeedPoints -> RealWalkSpeed (16 - 200),
          Format số to (K, M, B, T, Qa) và cấu hình nâng cấp Bệ ấp & Máy chạy bộ.
]]

export type PedestalTierInfo = {
    Level: number,
    Slots: number,
    Cost: number
}

export type TreadmillTierInfo = {
    Level: number,
    PointCap: number,       -- Giới hạn SpeedPoints có thể luyện được ở cấp này
    TrainRate: number,      -- Lượng SpeedPoints cộng cơ bản mỗi nhịp 0.6s
    BeltColor: Color3,      -- Màu sắc dải băng chuyền
    Cost: number
}

local UpgradeConfig = {}

-- =============================================================================
-- 1. CẤU HÌNH BỆ ĐẶT ĐÁ / ẤP TRỨNG (PEDESTAL)
-- =============================================================================
UpgradeConfig.PEDESTAL_MAX_LEVEL = 10
UpgradeConfig.PEDESTAL_BASE_COST = 500
UpgradeConfig.PEDESTAL_COST_MULTIPLIER = 2.6

UpgradeConfig.PEDESTAL_TIERS = {
    [1] = { Level = 1, Slots = 3, Cost = 0 },
    [2] = { Level = 2, Slots = 4, Cost = 500 },
    [3] = { Level = 3, Slots = 5, Cost = 1500 },
    [4] = { Level = 4, Slots = 6, Cost = 5000 },
    [5] = { Level = 5, Slots = 8, Cost = 20000 },
    [6] = { Level = 6, Slots = 10, Cost = 80000 },
    [7] = { Level = 7, Slots = 12, Cost = 350000 },
    [8] = { Level = 8, Slots = 14, Cost = 1500000 },
    [9] = { Level = 9, Slots = 16, Cost = 6000000 },
    [10] = { Level = 10, Slots = 20, Cost = 25000000 },
} :: { [number]: PedestalTierInfo }

function UpgradeConfig.GetPedestalUpgrade(currentLevel: number): (number, number, boolean)
    if currentLevel >= UpgradeConfig.PEDESTAL_MAX_LEVEL then
        local maxTier = UpgradeConfig.PEDESTAL_TIERS[UpgradeConfig.PEDESTAL_MAX_LEVEL]
        return 0, maxTier.Slots, true
    end
    
    local nextLevel = currentLevel + 1
    local nextTier = UpgradeConfig.PEDESTAL_TIERS[nextLevel]
    if nextTier then
        return nextTier.Cost, nextTier.Slots, false
    end
    
    local calcCost = math.floor(UpgradeConfig.PEDESTAL_BASE_COST * math.pow(UpgradeConfig.PEDESTAL_COST_MULTIPLIER, currentLevel - 1))
    return calcCost, currentLevel + 3, false
end

function UpgradeConfig.GetMaxPetCapacity(currentLevel: number): number
    local tier = UpgradeConfig.PEDESTAL_TIERS[currentLevel] or UpgradeConfig.PEDESTAL_TIERS[1]
    return tier and tier.Slots or 3
end

-- =============================================================================
-- 2. CẤU HÌNH MÁY CHẠY BỘ (TREADMILL) - 20 TIERS PROGRESSION CHUẨN STEAL AN EGG
-- =============================================================================
UpgradeConfig.TREADMILL_MAX_LEVEL = 20
UpgradeConfig.GLOBAL_MAX_WALKSPEED = 220

UpgradeConfig.TREADMILL_TIERS = {
    [1]  = { Level = 1,  PointCap = 1e3,    TrainRate = 5,       BeltColor = Color3.fromRGB(30, 32, 38),   Cost = 0 },
    [2]  = { Level = 2,  PointCap = 1e4,    TrainRate = 25,      BeltColor = Color3.fromRGB(0, 220, 255),  Cost = 400 },
    [3]  = { Level = 3,  PointCap = 5e4,    TrainRate = 120,     BeltColor = Color3.fromRGB(60, 255, 120), Cost = 2500 },
    [4]  = { Level = 4,  PointCap = 25e4,   TrainRate = 500,     BeltColor = Color3.fromRGB(255, 220, 40), Cost = 15000 },
    [5]  = { Level = 5,  PointCap = 1e6,    TrainRate = 2000,    BeltColor = Color3.fromRGB(255, 140, 30), Cost = 80000 },
    [6]  = { Level = 6,  PointCap = 5e6,    TrainRate = 8000,    BeltColor = Color3.fromRGB(180, 60, 255), Cost = 400000 },
    [7]  = { Level = 7,  PointCap = 25e6,   TrainRate = 35000,   BeltColor = Color3.fromRGB(255, 60, 180), Cost = 2e6 },
    [8]  = { Level = 8,  PointCap = 1e8,    TrainRate = 140000,  BeltColor = Color3.fromRGB(40, 180, 255), Cost = 1e7 },
    [9]  = { Level = 9,  PointCap = 5e8,    TrainRate = 600000,  BeltColor = Color3.fromRGB(255, 80, 80),  Cost = 5e7 },
    [10] = { Level = 10, PointCap = 25e8,   TrainRate = 25e5,    BeltColor = Color3.fromRGB(255, 215, 0),  Cost = 25e7 },
    [11] = { Level = 11, PointCap = 1e10,   TrainRate = 1e7,     BeltColor = Color3.fromRGB(0, 255, 230),  Cost = 12e8 },
    [12] = { Level = 12, PointCap = 5e10,   TrainRate = 45e6,    BeltColor = Color3.fromRGB(160, 40, 255), Cost = 6e9 },
    [13] = { Level = 13, PointCap = 25e10,  TrainRate = 2e8,     BeltColor = Color3.fromRGB(255, 40, 100), Cost = 3e10 },
    [14] = { Level = 14, PointCap = 1e12,   TrainRate = 8e8,     BeltColor = Color3.fromRGB(255, 240, 80), Cost = 15e10 },
    [15] = { Level = 15, PointCap = 5e12,   TrainRate = 35e8,    BeltColor = Color3.fromRGB(80, 255, 200), Cost = 75e10 },
    [16] = { Level = 16, PointCap = 25e12,  TrainRate = 15e9,    BeltColor = Color3.fromRGB(200, 80, 255), Cost = 4e12 },
    [17] = { Level = 17, PointCap = 1e14,   TrainRate = 6e10,    BeltColor = Color3.fromRGB(255, 120, 40), Cost = 2e13 },
    [18] = { Level = 18, PointCap = 5e14,   TrainRate = 25e10,   BeltColor = Color3.fromRGB(255, 255, 255),Cost = 1e14 },
    [19] = { Level = 19, PointCap = 25e14,  TrainRate = 1e12,    BeltColor = Color3.fromRGB(255, 215, 0),  Cost = 5e14 },
    [20] = { Level = 20, PointCap = 1e16,   TrainRate = 4e12,    BeltColor = Color3.fromRGB(255, 40, 255), Cost = 25e14 }
} :: { [number]: TreadmillTierInfo }

-- CÔNG THỨC TOÁN HỌC QUY ĐỔI SPEEDPOINTS -> REAL WALKSPEED (16 đến 220)
function UpgradeConfig.GetRealWalkSpeed(points: number): number
    if not points or points <= 0 then return 16 end
    local logVal = math.log10(points + 1)
    local bonus = math.floor(12.8 * logVal)
    return math.clamp(16 + bonus, 16, UpgradeConfig.GLOBAL_MAX_WALKSPEED)
end

-- Định dạng số simulator rút gọn chuẩn quốc tế (K, M, B, T, Qa, Qi, Sx, Sp, Oc)
function UpgradeConfig.FormatNumber(val: number): string
    if not val or val ~= val then return "0" end
    local absVal = math.abs(val)
    local sign = val < 0 and "-" or ""
    if absVal >= 1e27 then
        return string.format("%s%.2fOc", sign, absVal / 1e27)
    elseif absVal >= 1e24 then
        return string.format("%s%.2fSp", sign, absVal / 1e24)
    elseif absVal >= 1e21 then
        return string.format("%s%.2fSx", sign, absVal / 1e21)
    elseif absVal >= 1e18 then
        return string.format("%s%.2fQi", sign, absVal / 1e18)
    elseif absVal >= 1e15 then
        return string.format("%s%.2fQa", sign, absVal / 1e15)
    elseif absVal >= 1e12 then
        return string.format("%s%.2fT", sign, absVal / 1e12)
    elseif absVal >= 1e9 then
        return string.format("%s%.2fB", sign, absVal / 1e9)
    elseif absVal >= 1e6 then
        return string.format("%s%.2fM", sign, absVal / 1e6)
    elseif absVal >= 1e3 then
        return string.format("%s%.1fK", sign, absVal / 1e3)
    else
        return string.format("%s%d", sign, math.floor(absVal))
    end
end

function UpgradeConfig.GetTreadmillUpgrade(currentLevel: number): (number, number, number, Color3, boolean)
    if currentLevel >= UpgradeConfig.TREADMILL_MAX_LEVEL then
        local maxTier = UpgradeConfig.TREADMILL_TIERS[UpgradeConfig.TREADMILL_MAX_LEVEL]
        return 0, maxTier.PointCap, maxTier.TrainRate, maxTier.BeltColor, true
    end
    
    local nextLevel = currentLevel + 1
    local nextTier = UpgradeConfig.TREADMILL_TIERS[nextLevel]
    if nextTier then
        return nextTier.Cost, nextTier.PointCap, nextTier.TrainRate, nextTier.BeltColor, false
    end
    
    local fallback = UpgradeConfig.TREADMILL_TIERS[UpgradeConfig.TREADMILL_MAX_LEVEL]
    return 0, fallback.PointCap, fallback.TrainRate, fallback.BeltColor, true
end

return UpgradeConfig
