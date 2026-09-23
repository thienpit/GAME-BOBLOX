--!strict
--[[
    TÊN SCRIPT: PlayerDataTemplate
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> PlayerDataTemplate
    MÔ TẢ: Khai báo cấu trúc kiểu dữ liệu (Types) và giá trị mặc định cho người chơi mới.
          Bao gồm SpeedPoints (hệ thống điểm rèn luyện số to) và EquippedTrail.
]]

export type PetData = {
    Id: string,
    Name: string,
    Rarity: string,
    Size: string,
    Mutation: string,
    ObtainedAt: number
}

export type EggData = {
    Id: string,
    EggType: string,
    ZoneId: number,
    AcquiredAt: number
}

export type PlayerData = {
    Money: number,
    Speed: number,               -- Real WalkSpeed (16 to 200)
    SpeedPoints: number,         -- Điểm rèn luyện số to (0 to trillions)
    EquippedTrail: string,       -- ID của Trail đang trang bị
    PedestalLevel: number,
    TreadmillLevel: number,
    OwnedBats: { string },
    EquippedBat: string,
    Pets: { PetData },
    Eggs: { EggData },
    LastSaved: number,
    ActiveSession: string?,
    
    -- Retention features
    DiscoveredPets: { [string]: boolean },
    DailyStreak: number,
    LastDailyClaimTime: number,
    QuestDayId: number,
    QuestProgress: { [string]: number },
    QuestClaimed: { [string]: boolean },
    TutorialDone: boolean
}

local PlayerDataTemplate = {}

PlayerDataTemplate.DEFAULT_DATA = {
    Money = 500,
    Speed = 16,
    SpeedPoints = 0,
    EquippedTrail = "trail_dust",
    PedestalLevel = 1,
    TreadmillLevel = 1,
    OwnedBats = { "wooden_bat" },
    EquippedBat = "wooden_bat",
    Pets = {},
    Eggs = {},
    LastSaved = 0,
    ActiveSession = nil,
    
    DiscoveredPets = {},
    DailyStreak = 1,
    LastDailyClaimTime = 0,
    QuestDayId = 0,
    QuestProgress = {
        HatchEggs = 0,
        StealZoneEggs = 0,
        BatHits = 0
    },
    QuestClaimed = {
        HatchEggs = false,
        StealZoneEggs = false,
        BatHits = false
    },
    TutorialDone = false
} :: PlayerData

function PlayerDataTemplate.CreateNewProfile(): PlayerData
    local function DeepCopy(original: any): any
        local copy = {}
        for key, value in pairs(original) do
            if type(value) == "table" then
                copy[key] = DeepCopy(value)
            else
                copy[key] = value
            end
        end
        return copy
    end
    
    return DeepCopy(PlayerDataTemplate.DEFAULT_DATA) :: PlayerData
end

return PlayerDataTemplate
