--!strict
--[[
    TÊN SCRIPT: BatConfig
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> BatConfig
    MÔ TẢ: Cấu hình vũ khí Gậy và Phần Thưởng Sổ Tay Thú Cưng (Pet Index Zone Mastery).
          Gậy không bán bằng tiền; người chơi thu thập đủ 3 Pet của từng Vùng (Biome)
          để nhận thưởng loại gậy độc quyền tương ứng!
]]

export type BatInfo = {
    Id: string,
    Name: string,
    Price: number,
    Cooldown: number,
    Range: number,
    Knockback: number,
    StunDuration: number,
    Rarity: string,
    HandleColor: Color3,
    HandleMaterial: Enum.Material,
    RequiredZone: number,
    ZoneRewardText: string,
}

local BatConfig = {}

-- CẤU HÌNH LUẬT GIAO TRANH
BatConfig.INVINCIBILITY_DURATION = 2.0  -- 2 giây miễn nhiễm sau khi bị đánh (chống chain-stun)
BatConfig.STEAL_ZONE_MIN_Z = -5
BatConfig.STEAL_ZONE_MAX_Z = 5500
BatConfig.STEAL_ZONE_MAX_X = 55

-- DANH SÁCH 7 LOẠI GẬY TƯƠNG ỨNG 7 BIOME INDEX
BatConfig.BATS = {
    ["wooden_bat"] = {
        Id = "wooden_bat",
        Name = "Mossy Wooden Bat 🪵🌿",
        Price = 0,
        Cooldown = 1.1,
        Range = 6.5,
        Knockback = 38,
        StunDuration = 1.2,
        Rarity = "Common",
        HandleColor = Color3.fromRGB(125, 140, 75),
        HandleMaterial = Enum.Material.Wood,
        RequiredZone = 1,
        ZoneRewardText = "Collect all 3 pets from Mossy Forest"
    },
    ["baseball_bat"] = {
        Id = "baseball_bat",
        Name = "Obsidian Spike Bat 🔮",
        Price = 0,
        Cooldown = 0.95,
        Range = 7.5,
        Knockback = 55,
        StunDuration = 1.6,
        Rarity = "Rare",
        HandleColor = Color3.fromRGB(160, 80, 240),
        HandleMaterial = Enum.Material.Basalt,
        RequiredZone = 2,
        ZoneRewardText = "Collect all 3 pets from Obsidian Cavern"
    },
    ["iron_bat"] = {
        Id = "iron_bat",
        Name = "Magma Sledgehammer 🔨🔥",
        Price = 0,
        Cooldown = 1.4,
        Range = 8.5,
        Knockback = 78,
        StunDuration = 2.3,
        Rarity = "Epic",
        HandleColor = Color3.fromRGB(255, 75, 20),
        HandleMaterial = Enum.Material.CrackedLava,
        RequiredZone = 3,
        ZoneRewardText = "Collect all 3 pets from Magma Core"
    },
    ["golden_bat"] = {
        Id = "golden_bat",
        Name = "Celestial Sun Bat 👑⚡",
        Price = 0,
        Cooldown = 0.8,
        Range = 10.0,
        Knockback = 110,
        StunDuration = 3.0,
        Rarity = "Legendary",
        HandleColor = Color3.fromRGB(255, 215, 30),
        HandleMaterial = Enum.Material.Neon,
        RequiredZone = 4,
        ZoneRewardText = "Collect all 3 pets from Celestial Meteor"
    },
    ["cyber_bat"] = {
        Id = "cyber_bat",
        Name = "Cyber Laser Bat 🤖⚡",
        Price = 0,
        Cooldown = 0.7,
        Range = 11.5,
        Knockback = 145,
        StunDuration = 3.2,
        Rarity = "Secret",
        HandleColor = Color3.fromRGB(0, 255, 200),
        HandleMaterial = Enum.Material.Neon,
        RequiredZone = 5,
        ZoneRewardText = "Collect all 3 pets from Cyber Matrix"
    },
    ["divine_scepter"] = {
        Id = "divine_scepter",
        Name = "Archangel Divine Scepter 🦄✨",
        Price = 0,
        Cooldown = 0.6,
        Range = 13.0,
        Knockback = 190,
        StunDuration = 3.5,
        Rarity = "Divine",
        HandleColor = Color3.fromRGB(255, 240, 120),
        HandleMaterial = Enum.Material.Neon,
        RequiredZone = 6,
        ZoneRewardText = "Collect all 3 pets from Divine Olympus"
    },
    ["singularity_scythe"] = {
        Id = "singularity_scythe",
        Name = "Singularity Void Scythe 🌌⚛️",
        Price = 0,
        Cooldown = 0.5,
        Range = 15.0,
        Knockback = 260,
        StunDuration = 4.0,
        Rarity = "Eternal",
        HandleColor = Color3.fromRGB(255, 40, 160),
        HandleMaterial = Enum.Material.Neon,
        RequiredZone = 7,
        ZoneRewardText = "Collect all 3 pets from Eternal Singularity"
    }
} :: { [string]: BatInfo }

-- ÁNH XẠ BIOME INDEX -> PET YÊU CẦU & GẬY THƯỞNG
BatConfig.ZONE_REWARDS = {
    [1] = {
        ZoneId = 1,
        ZoneName = "Mossy Forest 🌿",
        BatId = "wooden_bat",
        RequiredPets = { "pebble_dog", "mossy_roll", "slate_turtle" },
    },
    [2] = {
        ZoneId = 2,
        ZoneName = "Obsidian Cavern 🔮",
        BatId = "baseball_bat",
        RequiredPets = { "basalt_crab", "obsidian_spire", "amethyst_geode" },
    },
    [3] = {
        ZoneId = 3,
        ZoneName = "Magma Core 🔥",
        BatId = "iron_bat",
        RequiredPets = { "lava_pup", "flame_golem", "inferno_core" },
    },
    [4] = {
        ZoneId = 4,
        ZoneName = "Celestial Meteor ☄️",
        BatId = "golden_bat",
        RequiredPets = { "star_shard", "meteor_titan", "cosmic_eye" },
    }
}

function BatConfig.GetBat(batId: string): BatInfo?
    return BatConfig.BATS[batId] or BatConfig.BATS["wooden_bat"]
end

function BatConfig.GetZoneReward(zoneId: number)
    return BatConfig.ZONE_REWARDS[zoneId]
end

return BatConfig
