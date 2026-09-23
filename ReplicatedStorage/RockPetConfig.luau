--!strict
--[[
    SCRIPT: RockPetConfig
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> RockPetConfig
    DESCRIPTION: Master configuration for all 5 Egg Types, 15 Pet Species across 5 rarities,
                 Size multipliers, and Mutation multipliers. Fully English for global release.
]]

export type RarityType = "Common" | "Rare" | "Epic" | "Legendary" | "Secret" | "Divine" | "Eternal"
export type SizeType = "Normal" | "Big" | "Giant" | "Huge" | "Titanic"
export type MutationType = "Normal" | "Golden" | "Rainbow"

export type EggConfig = {
    Name: string,
    Price: number,
    HatchTime: number,
    RarityOdds: { [RarityType]: number }
}

export type PetConfig = {
    Id: string,
    Name: string,
    Rarity: RarityType,
    BaseIncomePerSec: number,
    Description: string
}

local RockPetConfig = {}

-- 1. CONFIGURATION FOR 5 EGG TYPES
RockPetConfig.EGGS = {
    ["Common Rock"] = {
        Name = "Common Rock",
        Price = 100,
        HatchTime = 10,
        RarityOdds = {
            Common = 0.85,
            Rare = 0.14,
            Epic = 0.01,
            Legendary = 0.00,
            Secret = 0.00
        }
    },
    ["Mossy Stone"] = {
        Name = "Mossy Stone",
        Price = 100,
        HatchTime = 10,
        RarityOdds = {
            Common = 0.80,
            Rare = 0.18,
            Epic = 0.02,
            Legendary = 0.00,
            Secret = 0.00
        }
    },
    ["Obsidian Geode"] = {
        Name = "Obsidian Geode",
        Price = 500,
        HatchTime = 25,
        RarityOdds = {
            Common = 0.40,
            Rare = 0.45,
            Epic = 0.14,
            Legendary = 0.01,
            Secret = 0.00
        }
    },
    ["Magma Core"] = {
        Name = "Magma Core",
        Price = 2500,
        HatchTime = 60,
        RarityOdds = {
            Common = 0.10,
            Rare = 0.35,
            Epic = 0.45,
            Legendary = 0.09,
            Secret = 0.01
        }
    },
    ["Celestial Meteor"] = {
        Name = "Celestial Meteor",
        Price = 10000,
        HatchTime = 150,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.15,
            Epic = 0.40,
            Legendary = 0.40,
            Secret = 0.05
        }
    },
    ["Primordial Relic"] = {
        Name = "Primordial Relic",
        Price = 50000,
        HatchTime = 300,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.00,
            Epic = 0.20,
            Legendary = 0.65,
            Secret = 0.15
        }
    },
    ["Abyssal Void"] = {
        Name = "Abyssal Void",
        Price = 75000,
        HatchTime = 360,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.00,
            Epic = 0.10,
            Legendary = 0.60,
            Secret = 0.30
        }
    },
    ["Cyber Matrix Egg"] = {
        Name = "Cyber Matrix Egg",
        Price = 2500000,
        HatchTime = 120,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.00,
            Epic = 0.45,
            Legendary = 0.45,
            Secret = 0.10,
            Divine = 0.00,
            Eternal = 0.00
        }
    },
    ["Pegasus Egg"] = {
        Name = "Pegasus Egg",
        Price = 5000000,
        HatchTime = 150,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.00,
            Epic = 0.20,
            Legendary = 0.50,
            Secret = 0.20,
            Divine = 0.10,
            Eternal = 0.00
        }
    },
    ["Experiment Egg"] = {
        Name = "Experiment Egg",
        Price = 50000000,
        HatchTime = 240,
        RarityOdds = {
            Common = 0.00,
            Rare = 0.00,
            Epic = 0.00,
            Legendary = 0.25,
            Secret = 0.40,
            Divine = 0.25,
            Eternal = 0.10
        }
    }
} :: { [string]: EggConfig }

-- 2. 15 PETS ACROSS 5 RARITIES (100% ENGLISH DESCRIPTIONS)
RockPetConfig.PETS = {
    -- COMMON ($1 - $3/s)
    ["pebble_dog"] = {
        Id = "pebble_dog",
        Name = "Pebble Dog 🐶🪨",
        Rarity = "Common",
        BaseIncomePerSec = 1,
        Description = "A hyperactive pebble puppy that loves chasing heels."
    },
    ["mossy_roll"] = {
        Id = "mossy_roll",
        Name = "Mossy Roll 🌿⚪",
        Rarity = "Common",
        BaseIncomePerSec = 2,
        Description = "A smooth mossy stone that enjoys rolling on lush grass."
    },
    ["slate_turtle"] = {
        Id = "slate_turtle",
        Name = "Slate Turtle 🐢🧱",
        Rarity = "Common",
        BaseIncomePerSec = 3,
        Description = "A calm and patient turtle protected by layered slate armor."
    },

    -- RARE ($8 - $20/s)
    ["basalt_crab"] = {
        Id = "basalt_crab",
        Name = "Basalt Crab 🦀⛰️",
        Rarity = "Rare",
        BaseIncomePerSec = 8,
        Description = "A sturdy volcanic rock crab with sharp angular claws."
    },
    ["obsidian_spire"] = {
        Id = "obsidian_spire",
        Name = "Obsidian Spire 🗡️🔮",
        Rarity = "Rare",
        BaseIncomePerSec = 14,
        Description = "A sleek, pitch-black obsidian monolith shrouded in mystery."
    },
    ["amethyst_geode"] = {
        Id = "amethyst_geode",
        Name = "Amethyst Geode 💎✨",
        Rarity = "Rare",
        BaseIncomePerSec = 20,
        Description = "A glittering amethyst hollow reflecting cosmic starlight."
    },

    -- EPIC ($50 - $120/s)
    ["lava_pup"] = {
        Id = "lava_pup",
        Name = "Lava Pup 🐕🔥",
        Rarity = "Epic",
        BaseIncomePerSec = 50,
        Description = "A warm magma puppy leaving fiery embers with every step."
    },
    ["flame_golem"] = {
        Id = "flame_golem",
        Name = "Flame Golem 🗿🌋",
        Rarity = "Epic",
        BaseIncomePerSec = 80,
        Description = "A raging boulder titan infused with molten lava core."
    },
    ["inferno_core"] = {
        Id = "inferno_core",
        Name = "Inferno Core 🔴💥",
        Rarity = "Epic",
        BaseIncomePerSec = 120,
        Description = "A pulsating heart of primordial subterranean magma."
    },
    ["cyber_hound"] = {
        Id = "cyber_hound",
        Name = "Cyber Hound 🤖🐕",
        Rarity = "Epic",
        BaseIncomePerSec = 200,
        Description = "A digital sentinel hound forged in the cyber matrix."
    },

    -- LEGENDARY ($300 - $800/s)
    ["star_shard"] = {
        Id = "star_shard",
        Name = "Star Shard ⭐🌌",
        Rarity = "Legendary",
        BaseIncomePerSec = 300,
        Description = "A crystalline meteorite fragment humming with stellar energy."
    },
    ["meteor_titan"] = {
        Id = "meteor_titan",
        Name = "Meteor Titan ☄️🛡️",
        Rarity = "Legendary",
        BaseIncomePerSec = 500,
        Description = "A colossal comet sentinel that crash-landed from deep space."
    },
    ["cosmic_eye"] = {
        Id = "cosmic_eye",
        Name = "Cosmic Eye 👁️🌀",
        Rarity = "Legendary",
        BaseIncomePerSec = 800,
        Description = "An omniscient extraterrestrial watcher perceiving all dimensions."
    },
    ["matrix_glitch"] = {
        Id = "matrix_glitch",
        Name = "Glitch Entity 👾💾",
        Rarity = "Legendary",
        BaseIncomePerSec = 1500,
        Description = "An unstable floating sentient memory corruption."
    },

    -- SECRET ($2,500 - $10,000/s)
    ["abyss_leviathan"] = {
        Id = "abyss_leviathan",
        Name = "Abyss Leviathan 🐉🌊",
        Rarity = "Secret",
        BaseIncomePerSec = 2500,
        Description = "A terrifying serpentine behemoth from the deepest ocean trench."
    },
    ["eclipse_overlord"] = {
        Id = "eclipse_overlord",
        Name = "Eclipse Overlord 🌑👑",
        Rarity = "Secret",
        BaseIncomePerSec = 5000,
        Description = "A celestial cosmic entity devouring solar light."
    },
    ["genesis_monolith"] = {
        Id = "genesis_monolith",
        Name = "Genesis Monolith 💠⚛️",
        Rarity = "Secret",
        BaseIncomePerSec = 10000,
        Description = "The primordial stone of creation from which all minerals were born."
    },
    ["mecha_dragon"] = {
        Id = "mecha_dragon",
        Name = "Mecha Wyvern 🦾🐉",
        Rarity = "Secret",
        BaseIncomePerSec = 25000,
        Description = "A titanium-alloy winged beast armed with high-frequency laser breath."
    },

    -- DIVINE ($100K - $1M/s)
    ["pegasus_rock"] = {
        Id = "pegasus_rock",
        Name = "Celestial Pegasus 🦄🪨",
        Rarity = "Divine",
        BaseIncomePerSec = 250000,
        Description = "A divine winged stallion sculpted from pure star-rock."
    },
    ["seraph_rock"] = {
        Id = "seraph_rock",
        Name = "Seraphim Core 👼✨",
        Rarity = "Divine",
        BaseIncomePerSec = 500000,
        Description = "A radiant haloed rock hovering in holy celestial grace."
    },
    ["dr_scramble"] = {
        Id = "dr_scramble",
        Name = "Dr. Scramble 🧪🍳",
        Rarity = "Divine",
        BaseIncomePerSec = 1000000,
        Description = "A mad yolk-scientist hatching mutant anomalies."
    },

    -- ETERNAL ($10M - $1B/s)
    ["experiment_001"] = {
        Id = "experiment_001",
        Name = "Experiment #001 🧬⚡",
        Rarity = "Eternal",
        BaseIncomePerSec = 25000000,
        Description = "The first forbidden biological mineral creation."
    },
    ["experiment_013"] = {
        Id = "experiment_013",
        Name = "Experiment #013 ☣️👑",
        Rarity = "Eternal",
        BaseIncomePerSec = 100000000,
        Description = "An omnipotent apex entity that radiates catastrophic wealth."
    },
    ["singularity_god"] = {
        Id = "singularity_god",
        Name = "Singularity Overlord 🌌⚛️",
        Rarity = "Eternal",
        BaseIncomePerSec = 1000000000,
        Description = "The primordial cosmic singularity controlling space, time, and matter."
    }
} :: { [string]: PetConfig }

-- 3. PET SIZE MULTIPLIERS (HUGE & TITANIC CARTOON FLEX)
RockPetConfig.SIZES = {
    ["Normal"]  = { Multiplier = 1.0,   Weight = 80,  Scale = 1.0 },
    ["Big"]     = { Multiplier = 1.6,   Weight = 14,  Scale = 1.35 },
    ["Giant"]   = { Multiplier = 3.5,   Weight = 5,   Scale = 1.8 },
    ["Huge"]    = { Multiplier = 35.0,  Weight = 0.9, Scale = 3.8 },
    ["Titanic"] = { Multiplier = 300.0, Weight = 0.1, Scale = 6.5 }
}

-- 4. MUTATION MULTIPLIERS
RockPetConfig.MUTATIONS = {
    ["Normal"]  = { Multiplier = 1.0, Weight = 94, Color = Color3.fromRGB(255, 255, 255) },
    ["Golden"]  = { Multiplier = 2.5, Weight = 5,  Color = Color3.fromRGB(255, 215, 0) },
    ["Rainbow"] = { Multiplier = 5.0, Weight = 1,  Color = Color3.fromRGB(255, 100, 255) }
}

-- 5. WEIGHTED RANDOM ROLL PET ALGORITHM (CALLED BY SERVER HATCHSERVICE)
function RockPetConfig.RollPet(eggName: string)
    local egg = RockPetConfig.EGGS[eggName] or RockPetConfig.EGGS["Common Rock"]
    local rng = Random.new()
    
    -- 1. Roll Rarity based on Egg odds
    local totalProb = 0
    for _, prob in pairs(egg.RarityOdds) do
        totalProb = totalProb + prob
    end
    
    local rollVal = rng:NextNumber(0, totalProb)
    local current = 0
    local chosenRarity: RarityType = "Common"
    for _, rName in ipairs({ "Common", "Rare", "Epic", "Legendary", "Secret", "Divine", "Eternal" } :: { RarityType }) do
        local prob = egg.RarityOdds[rName] or 0
        current = current + prob
        if rollVal <= current then
            chosenRarity = rName
            break
        end
    end
    
    -- 2. Pick matching Pet
    local matchingPets: { PetConfig } = {}
    for _, pet in pairs(RockPetConfig.PETS) do
        if pet.Rarity == chosenRarity then
            table.insert(matchingPets, pet)
        end
    end
    
    local chosenPet: PetConfig = #matchingPets > 0 and matchingPets[rng:NextInteger(1, #matchingPets)] or RockPetConfig.PETS["pebble_dog"]
    
    -- 3. Roll Size (Normal, Big, Giant, Huge, Titanic)
    local sizeRoll = rng:NextNumber(0, 100)
    local chosenSizeName = "Normal"
    local sizeData = RockPetConfig.SIZES["Normal"]
    local accumSize = 0
    for _, sName in ipairs({ "Titanic", "Huge", "Giant", "Big", "Normal" }) do
        local sInfo = RockPetConfig.SIZES[sName]
        if sInfo then
            accumSize = accumSize + sInfo.Weight
            if sizeRoll <= accumSize then
                chosenSizeName = sName
                sizeData = sInfo
                break
            end
        end
    end
    
    -- 4. Roll Mutation
    local mutRoll = rng:NextInteger(1, 100)
    local chosenMutName = "Normal"
    local mutData = RockPetConfig.MUTATIONS["Normal"]
    local accumMut = 0
    for _, mName in ipairs({ "Rainbow", "Golden", "Normal" }) do
        local mInfo = RockPetConfig.MUTATIONS[mName]
        if mInfo then
            accumMut = accumMut + mInfo.Weight
            if mutRoll <= accumMut then
                chosenMutName = mName
                mutData = mInfo
                break
            end
        end
    end
    
    local totalIncome = math.max(1, math.floor(chosenPet.BaseIncomePerSec * sizeData.Multiplier * mutData.Multiplier))
    
    return {
        PetId = chosenPet.Id,
        Name = chosenPet.Name,
        Rarity = chosenPet.Rarity,
        BaseIncome = chosenPet.BaseIncomePerSec,
        Size = chosenSizeName,
        SizeMultiplier = sizeData.Multiplier,
        Mutation = chosenMutName,
        MutationMultiplier = mutData.Multiplier,
        TotalIncomePerSec = totalIncome
    }
end


-- =============================================================================
-- INTERFACE CONTRACT §3.3: PET FUSION TIERS & RULES
-- =============================================================================
RockPetConfig.Tiers = { "Normal", "Golden", "Rainbow" }

RockPetConfig.FusionRules = {
    Golden = {
        InputMutation = "Normal",
        RequiredCount = 3,
        OutputMutation = "Golden",
        Cost = 500,
        Multiplier = 2.5,
    },
    Rainbow = {
        InputMutation = "Golden",
        RequiredCount = 3,
        OutputMutation = "Rainbow",
        Cost = 2500,
        Multiplier = 5.0,
    }
}

function RockPetConfig.GetMultiplier(tier: string): number
    local mut = RockPetConfig.MUTATIONS[tier]
    return mut and mut.Multiplier or 1.0
end

return RockPetConfig
