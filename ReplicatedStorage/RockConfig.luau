--!strict
--[[
    SCRIPT: RockConfig
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> RockConfig
    DESCRIPTION: Master configuration for Rock Types, Sizes, and Biome Boundaries.
                 Includes Biome boundary lookup contract for other services.
]]

local RockConfig = {}

-- Zone Types with Weight in KG (Steal An Egg standard)
RockConfig.ZoneTypes = {
    Mossy = {
        Id = "Mossy",
        Name = "Mossy Rock 🌿",
        Zone = 1,
        BaseIncome = 15,
        WeightKg = 25,     -- 25 KG
        BaseWeight = 3,
        MonsterSpeed = 16,
        Color = Color3.fromRGB(75, 140, 75),
        Material = Enum.Material.Grass,
        BaseScale = Vector3.new(3.0, 2.6, 2.8)
    },
    Obsidian = {
        Id = "Obsidian",
        Name = "Obsidian Crystal 🔮",
        Zone = 2,
        BaseIncome = 120,
        WeightKg = 500,    -- 500 KG
        BaseWeight = 7,
        MonsterSpeed = 22,
        Color = Color3.fromRGB(30, 25, 45),
        Material = Enum.Material.Basalt,
        BaseScale = Vector3.new(3.4, 3.2, 3.4)
    },
    Magma = {
        Id = "Magma",
        Name = "Magma Core 🔥",
        Zone = 3,
        BaseIncome = 1500,
        WeightKg = 50000,  -- 50,000 KG (50 Tons)
        BaseWeight = 14,
        MonsterSpeed = 30,
        Color = Color3.fromRGB(220, 60, 20),
        Material = Enum.Material.CrackedLava,
        BaseScale = Vector3.new(4.0, 3.8, 4.0)
    },
    Meteor = {
        Id = "Meteor",
        Name = "Cosmic Meteor ☄️",
        Zone = 4,
        BaseIncome = 30000,
        WeightKg = 100000, -- 100,000 KG (100 Tons)
        BaseWeight = 22,
        MonsterSpeed = 38,
        Color = Color3.fromRGB(255, 190, 40),
        Material = Enum.Material.Neon,
        BaseScale = Vector3.new(4.8, 4.6, 4.8)
    },
    Cyber = {
        Id = "Cyber",
        Name = "Cyber Matrix Core 🤖⚡",
        Zone = 5,
        BaseIncome = 500000,
        WeightKg = 2000000, -- 2,000,000 KG
        BaseWeight = 35,
        MonsterSpeed = 52,
        Color = Color3.fromRGB(0, 255, 180),
        Material = Enum.Material.Neon,
        BaseScale = Vector3.new(5.2, 5.0, 5.2)
    },
    Pegasus = {
        Id = "Pegasus",
        Name = "Divine Star Stone 🦄✨",
        Zone = 6,
        BaseIncome = 15000000,
        WeightKg = 50000000, -- 50,000,000 KG
        BaseWeight = 50,
        MonsterSpeed = 68,
        Color = Color3.fromRGB(255, 240, 120),
        Material = Enum.Material.Neon,
        BaseScale = Vector3.new(6.0, 5.6, 6.0)
    },
    Anomaly = {
        Id = "Anomaly",
        Name = "Eternal Singularity 🌌⚛️",
        Zone = 7,
        BaseIncome = 500000000,
        WeightKg = 1000000000, -- 1 Billion KG
        BaseWeight = 75,
        MonsterSpeed = 88,
        Color = Color3.fromRGB(255, 40, 150),
        Material = Enum.Material.Neon,
        BaseScale = Vector3.new(7.0, 6.5, 7.0)
    }
}

-- Size Mutations
RockConfig.Sizes = {
    {
        Name = "Small",
        Prefix = "[SMALL] ",
        Chance = 30,
        ScaleMult = 0.75,
        IncomeMult = 0.8,
        WeightMult = 0.65, -- Lighter
        TitleColor = Color3.fromRGB(200, 200, 200)
    },
    {
        Name = "Normal",
        Prefix = "",
        Chance = 45,
        ScaleMult = 1.0,
        IncomeMult = 1.0,
        WeightMult = 1.0,
        TitleColor = Color3.fromRGB(255, 255, 255)
    },
    {
        Name = "Huge",
        Prefix = "[HUGE] ",
        Chance = 20,
        ScaleMult = 1.5,
        IncomeMult = 1.6,
        WeightMult = 1.5, -- Heavier
        TitleColor = Color3.fromRGB(255, 180, 40)
    },
    {
        Name = "Titanic",
        Prefix = "[TITANIC] ",
        Chance = 5,
        ScaleMult = 2.2,
        IncomeMult = 3.0,
        WeightMult = 2.2, -- Super Heavy!
        TitleColor = Color3.fromRGB(255, 60, 180)
    }
}

-- =============================================================================
-- INTERFACE CONTRACT §3.2: BIOMES & REGIONS
-- =============================================================================
RockConfig.Biomes = {
    Base = {
        name = "Village Safe Zone 🛡️",
        minZ = -325,
        maxZ = -5,
        theme = "Village",
        zoneId = 0
    },
    Mossy = {
        name = "Meadow Runway 🌿",
        minZ = -5,
        maxZ = 140,
        theme = "Forest",
        zoneId = 1
    },
    Obsidian = {
        name = "Obsidian Chasm 🔮",
        minZ = 140,
        maxZ = 440,
        theme = "Cavern",
        zoneId = 2
    },
    Magma = {
        name = "Magma Abyss 🔥",
        minZ = 440,
        maxZ = 980,
        theme = "Volcano",
        zoneId = 3
    },
    Meteor = {
        name = "Celestial Void Vault ☄️",
        minZ = 980,
        maxZ = 1750,
        theme = "Cosmic",
        zoneId = 4
    },
    Cyber = {
        name = "Cyber Matrix Grid 🤖⚡",
        minZ = 1750,
        maxZ = 2700,
        theme = "Cyber",
        zoneId = 5
    },
    Pegasus = {
        name = "Divine Olympus 🦄✨",
        minZ = 2700,
        maxZ = 3950,
        theme = "Divine",
        zoneId = 6
    },
    Anomaly = {
        name = "Apex Eternal Singularity 🌌⚛️",
        minZ = 3950,
        maxZ = 5500,
        theme = "Eternal",
        zoneId = 7
    }
}

function RockConfig.GetBiomeAt(position: Vector3): string
    local z = position.Z
    if z < -5 then
        return "Base"
    elseif z <= 140 then
        return "Mossy"
    elseif z <= 440 then
        return "Obsidian"
    elseif z <= 980 then
        return "Magma"
    elseif z <= 1750 then
        return "Meteor"
    elseif z <= 2700 then
        return "Cyber"
    elseif z <= 3950 then
        return "Pegasus"
    else
        return "Anomaly"
    end
end

function RockConfig.RollSize()
    local roll = math.random(1, 100)
    local accumulated = 0
    for _, s in ipairs(RockConfig.Sizes) do
        accumulated = accumulated + s.Chance
        if roll <= accumulated then
            return s
        end
    end
    return RockConfig.Sizes[2]
end

function RockConfig.GetSizeByName(name)
    for _, s in ipairs(RockConfig.Sizes) do
        if s.Name == name then return s end
    end
    return RockConfig.Sizes[2]
end

return RockConfig
