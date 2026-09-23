--!strict
--[[
    TÊN SCRIPT: StealZoneConfig
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> StealZoneConfig
    MÔ TẢ: Bảng thông số cấu hình khu vực tranh trứng chung (Steal Zone):
          tần suất spawn, số lượng tối đa, tỉ lệ độ hiếm, mức giảm tốc và thời gian rơi.
]]

export type SpawnChance = {
    EggName: string,
    Weight: number,         -- Trọng số xuất hiện
    IsRare: boolean,        -- Có phát hiệu ứng Beam & thông báo toàn server không
    BeamColor: Color3,      -- Màu sắc cột sáng nếu là trứng hiếm
    Slowdown: number        -- Số điểm tốc độ bị trừ khi vác (-WalkSpeed)
}

local StealZoneConfig = {}

-- CẤU HÌNH VẬN HÀNH KHU VỰC TRANH TRỨNG
StealZoneConfig.SPAWN_INTERVAL_MIN = 20         -- Thời gian spawn tối thiểu (giây)
StealZoneConfig.SPAWN_INTERVAL_MAX = 40         -- Thời gian spawn tối đa (giây)
StealZoneConfig.MAX_ACTIVE_EGGS = 8             -- Tối đa 8 quả trứng cùng lúc trong khu vực
StealZoneConfig.PICKUP_IMMUNITY_TIME = 3.0      -- Trứng rơi xuống đất không nhặt được trong 3s
StealZoneConfig.DESPAWN_TIME = 60.0             -- Trứng rơi tự động biến mất sau 60s nếu không ai nhặt
StealZoneConfig.MAX_PICKUP_DISTANCE = 12        -- Khoảng cách tối đa để nhặt trứng (chống exploit từ xa)
StealZoneConfig.MIN_CARRY_SPEED = 6             -- Tốc độ chạy tối thiểu khi vác trứng nặng nhất

-- BẢNG PHÂN BỔ TỈ LỆ ĐỘ HIẾM & MỨC GIẢM TỐC ĐỘ
StealZoneConfig.SPAWN_TABLE = {
    {
        EggName = "Mossy Stone",
        Weight = 50, -- 50%
        IsRare = false,
        BeamColor = Color3.fromRGB(100, 255, 100),
        Slowdown = 2
    },
    {
        EggName = "Obsidian Geode",
        Weight = 28, -- 28%
        IsRare = false,
        BeamColor = Color3.fromRGB(180, 80, 255),
        Slowdown = 4
    },
    {
        EggName = "Magma Core",
        Weight = 15, -- 15%
        IsRare = false,
        BeamColor = Color3.fromRGB(255, 80, 20),
        Slowdown = 6
    },
    {
        EggName = "Celestial Meteor",
        Weight = 6,  -- 6% (Hiếm!)
        IsRare = true,
        BeamColor = Color3.fromRGB(255, 215, 60),
        Slowdown = 8
    },
    {
        EggName = "Abyssal Void",
        Weight = 1,  -- 1% (Cực Phẩm Huyền Thoại!)
        IsRare = true,
        BeamColor = Color3.fromRGB(180, 40, 255),
        Slowdown = 10
    },
    {
        EggName = "Pegasus Egg",
        Weight = 0.4, -- 0.4% (Divine!)
        IsRare = true,
        BeamColor = Color3.fromRGB(0, 240, 255),
        Slowdown = 12
    },
    {
        EggName = "Experiment Egg",
        Weight = 0.1, -- 0.1% (Eternal Tier!)
        IsRare = true,
        BeamColor = Color3.fromRGB(255, 40, 80),
        Slowdown = 15
    }
} :: { SpawnChance }

-- Hàm hỗ trợ lấy cấu hình theo tên trứng
function StealZoneConfig.GetEggConfig(eggName: string): SpawnChance?
    for _, item in ipairs(StealZoneConfig.SPAWN_TABLE) do
        if item.EggName == eggName then
            return item
        end
    end
    return nil
end

return StealZoneConfig
