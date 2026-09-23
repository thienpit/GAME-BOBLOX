--!strict
--[[
    SCRIPT: MonetizationConfig
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> MonetizationConfig
    DESCRIPTION: Monetization settings for 3 Gamepasses and 2 Developer Products with 2D Icons.
]]

export type GamepassInfo = {
    Id: number,
    Name: string,
    Description: string,
    AttributeKey: string,
    IconAssetId: string,
    BadgeColor: Color3
}

export type ProductInfo = {
    Id: number,
    Name: string,
    Description: string,
    RewardType: string,
    RewardValue: any,
    IconAssetId: string,
    BadgeColor: Color3
}

local MonetizationConfig = {}

-- 1. THREE PERMANENT GAMEPASSES
MonetizationConfig.GAMEPASSES = {
    ["DoubleMoney"] = {
        Id = 12345678,
        Name = "2X MONEY 💰",
        Description = "Permanently doubles all income from pets!",
        AttributeKey = "HasDoubleMoney",
        IconAssetId = "rbxassetid://7170139915",
        BadgeColor = Color3.fromRGB(255, 215, 60)
    },
    ["FasterHatch"] = {
        Id = 12345679,
        Name = "FAST HATCH ⚡",
        Description = "Cuts incubation time in half (-50%)!",
        AttributeKey = "HasFasterHatch",
        IconAssetId = "rbxassetid://74211056782107",
        BadgeColor = Color3.fromRGB(60, 220, 255)
    },
    ["ExtraSlots"] = {
        Id = 12345680,
        Name = "+2 SLOTS 🏺",
        Description = "Permanently unlocks 2 extra egg slots!",
        AttributeKey = "HasExtraSlots",
        IconAssetId = "rbxassetid://12494247820",
        BadgeColor = Color3.fromRGB(220, 110, 255)
    }
} :: { [string]: GamepassInfo }

-- 2. TWO DEVELOPER PRODUCTS (REPEATABLE PURCHASES)
MonetizationConfig.PRODUCTS = {
    [98765431] = {
        Id = 98765431,
        Name = "$10K CASH 💵",
        Description = "Instantly receive $10,000 Cash in-game!",
        RewardType = "Money",
        RewardValue = 10000,
        IconAssetId = "rbxassetid://17863197977",
        BadgeColor = Color3.fromRGB(80, 255, 120)
    },
    [98765432] = {
        Id = 98765432,
        Name = "METEOR EGG ☄️",
        Description = "Instantly receive 1 ultra-rare Celestial Egg!",
        RewardType = "Egg",
        RewardValue = "Celestial Meteor",
        IconAssetId = "rbxassetid://120147817107847",
        BadgeColor = Color3.fromRGB(255, 120, 60)
    }
} :: { [number]: ProductInfo }

return MonetizationConfig
