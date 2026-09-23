--!strict
--[[
    SCRIPT: RetentionConfig
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> RetentionConfig
    DESCRIPTION: Configuration for 7-Day Daily Login Rewards, 3 Daily Quests (Reset 00:00 UTC),
                 and Global Richest Leaderboard. 100% English.
]]

export type DailyReward = {
    Day: number,
    RewardName: string,
    RewardType: string,
    RewardValue: any,
    Icon: string
}

export type QuestInfo = {
    Id: string,
    Title: string,
    Description: string,
    TargetCount: number,
    RewardMoney: number,
    Icon: string
}

local RetentionConfig = {}

-- 1. 7-DAY DAILY REWARDS
RetentionConfig.DAILY_REWARDS = {
    [1] = { Day = 1, RewardName = "$250 Cash", RewardType = "Money", RewardValue = 250, Icon = "💵" },
    [2] = { Day = 2, RewardName = "+5 WalkSpeed", RewardType = "Speed", RewardValue = 5, Icon = "⚡" },
    [3] = { Day = 3, RewardName = "$1,000 Cash", RewardType = "Money", RewardValue = 1000, Icon = "💰" },
    [4] = { Day = 4, RewardName = "1x Obsidian Geode", RewardType = "Egg", RewardValue = "Obsidian Geode", Icon = "🔮" },
    [5] = { Day = 5, RewardName = "$3,000 Cash", RewardType = "Money", RewardValue = 3000, Icon = "💎" },
    [6] = { Day = 6, RewardName = "1x Magma Core", RewardType = "Egg", RewardValue = "Magma Core", Icon = "🔥" },
    [7] = { Day = 7, RewardName = "👑 Golden Pebble Dog + $5,000", RewardType = "SpecialPet", RewardValue = 5000, Icon = "👑" }
} :: { [number]: DailyReward }

-- 2. 3 DAILY QUESTS (RESET AT 00:00 UTC)
RetentionConfig.DAILY_QUESTS = {
    ["HatchEggs"] = {
        Id = "HatchEggs",
        Title = "Speed Incubator",
        Description = "Hatch and open 2 eggs on your base pedestal",
        TargetCount = 2,
        RewardMoney = 500,
        Icon = "🥚"
    },
    ["StealZoneEggs"] = {
        Id = "StealZoneEggs",
        Title = "Egg Raider",
        Description = "Steal and secure 1 egg from the Steal Zone",
        TargetCount = 1,
        RewardMoney = 1000,
        Icon = "⚡"
    },
    ["BatHits"] = {
        Id = "BatHits",
        Title = "Bat Brawl",
        Description = "Strike 3 players with your bat inside Steal Zone",
        TargetCount = 3,
        RewardMoney = 1500,
        Icon = "🏏"
    }
} :: { [string]: QuestInfo }

-- 3. LEADERBOARD CONFIG
RetentionConfig.LEADERBOARD_UPDATE_INTERVAL = 60
RetentionConfig.LEADERBOARD_TOP_COUNT = 10

return RetentionConfig
