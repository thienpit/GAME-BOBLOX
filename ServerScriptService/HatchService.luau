--!strict
--[[
    SCRIPT: HatchService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> HatchService
    DESCRIPTION: Free-placement Pen Incubation & Hatching System (Steal a Pet style).
                 No rigid slots or tables. Eggs are placed freely on the pen grass
                 up to the Pen Capacity limit. Full visual incubation, countdowns,
                 and hatching into roaming pet rocks!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local hatchRemote = ReplicatedStorage:WaitForChild("HatchRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

export type IncubatingEggState = {
    EggId: string,
    Player: Player,
    EggName: string,
    FinishTime: number,
    TotalDuration: number,
    EggModel: Model,
    Prompt: ProximityPrompt,
    CountdownLabel: TextLabel,
    IsClaiming: boolean
}

-- [Model] -> IncubatingEggState
local activeEggs: { [Model]: IncubatingEggState } = {}

-- Helper: Floating text above head
local function ShowFloatingText(head: BasePart?, text: string, color: Color3)
    if not head then return end
    task.spawn(function()
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 220, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head
        
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.Text = text
        tl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        tl.TextSize = 15
        tl.Font = Enum.Font.FredokaOne
        tl.BackgroundTransparency = 1
        tl.TextStrokeTransparency = 0.5
        tl.Parent = bb
        
        local tw = TweenService:Create(bb, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            StudsOffset = Vector3.new(0, 6.0, 0)
        })
        tw:Play()
        task.wait(1.4)
        bb:Destroy()
    end)
end

-- GUARANTEED BASE FINDER (VIA BASESERVICE)
local function GetPlayerBase(player: Player): Model?
    return BaseService.GetOrClaimBase(player)
end

-- PEN CAPACITY HELPER (MATCHING UPGRADE PEN SYSTEM)
local function GetPenCapacity(player: Player): number
    local pData = DataService.GetData(player)
    local level = pData and (pData.PedestalLevel or 1) or 1
    local tier = UpgradeConfig.PEDESTAL_TIERS[level]
    local baseCapacity = tier and tier.Slots or 3
    local extra = player:GetAttribute("HasExtraSlots") and 2 or 0
    return baseCapacity + extra
end

-- CLEAN PLAYER CARRIED EGG
local function CleanPlayerCarriedEgg(player: Player)
    local char = player.Character
    if not char then return end
    
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsCarriedItem") == true then
            child:Destroy()
        end
    end
    char:SetAttribute("IsCarryingEgg", false)
    char:SetAttribute("IsCarryingRock", false)
    char:SetAttribute("CarriedEggName", nil)
    char:SetAttribute("CarryingZone", 0)
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local pData = DataService.GetData(player)
    if hum and pData then
        hum.WalkSpeed = pData.Speed
    end
end

-- RECALCULATE BASE INCOME HELPER
local function RecalculateBaseIncome(base: Model)
    local petRocks = base:FindFirstChild("PetRocks")
    if not petRocks then return end
    local totalInc = 0
    local rockCount = 0
    for _, rock in ipairs(petRocks:GetChildren()) do
        local inc = rock:GetAttribute("Income") or 0
        totalInc = totalInc + inc
        rockCount = rockCount + 1
    end
    base:SetAttribute("IncomePerSec", totalInc)
    base:SetAttribute("RockCount", rockCount)
end
_G.RecalculateBaseIncome = RecalculateBaseIncome

-- SPAWN PHYSICAL ROAMING PET IN BASE PEN (CARTOON PROCEDURAL 3D)
local function SpawnRoamingPetInPen(base: Model, pet: any): Model?
    local petRocks = base:FindFirstChild("PetRocks")
    if not petRocks then return nil end
    
    local bFloor = base:FindFirstChild("BaseFloor") :: BasePart?
    local spawnX = bFloor and (bFloor.Position.X + math.random(-14, 14)) or 0
    local spawnZ = bFloor and (bFloor.Position.Z + math.random(-14, 14)) or -270
    
    local petModel = Instance.new("Model")
    local petId = string.lower(pet.Id or pet.Name or "")
    local mutation = pet.Mutation or "Normal"
    local rarity = pet.Rarity or "Common"
    local sizeMult = pet.SizeMultiplier or 1.0
    petModel.Name = "Pet_" .. pet.Name
    
    -- 1. CORE BODY
    local core = Instance.new("Part")
    core.Name = "PetCore"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(2.4, 2.4, 2.4) * sizeMult
    core.CFrame = CFrame.new(spawnX, 2.2, spawnZ)
    
    local colorMap = {
        Common = Color3.fromRGB(160, 165, 175),
        Rare = Color3.fromRGB(80, 180, 255),
        Epic = Color3.fromRGB(180, 80, 255),
        Legendary = Color3.fromRGB(255, 215, 30),
        Secret = Color3.fromRGB(255, 40, 120)
    }
    
    if mutation == "Golden" then
        core.Material = Enum.Material.Foil
        core.Color = Color3.fromRGB(255, 215, 30)
    elseif mutation == "Rainbow" then
        core.Material = Enum.Material.Neon
        core.Color = Color3.fromRGB(255, 100, 255)
    elseif rarity == "Legendary" or rarity == "Secret" then
        core.Material = Enum.Material.Neon
        core.Color = colorMap[rarity] or Color3.fromRGB(255, 215, 30)
    else
        core.Material = Enum.Material.SmoothPlastic
        core.Color = colorMap[rarity] or Color3.fromRGB(200, 200, 200)
    end
    
    core.Anchored = false
    core.CanCollide = true
    core.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.5, 0.4, 1.0, 1.0)
    core.Parent = petModel
    petModel.PrimaryPart = core

    local function attachPart(p: BasePart, cfOffset: CFrame)
        p.CFrame = core.CFrame * cfOffset
        p.CanCollide = false
        p.Anchored = false
        p.Parent = petModel
        local w = Instance.new("WeldConstraint")
        w.Part0 = core
        w.Part1 = p
        w.Parent = core
    end

    -- 2. SPECIES SPECIFIC PROCEDURAL DETAILS
    if string.find(petId, "dog") or string.find(petId, "puppy") then
        local earL = Instance.new("Part")
        earL.Name = "EarL"; earL.Size = Vector3.new(0.5, 0.9, 0.5) * sizeMult
        earL.Color = core.Color; earL.Material = core.Material
        attachPart(earL, CFrame.new(-0.8 * sizeMult, 1.1 * sizeMult, 0) * CFrame.Angles(0, 0, math.rad(25)))

        local earR = Instance.new("Part")
        earR.Name = "EarR"; earR.Size = Vector3.new(0.5, 0.9, 0.5) * sizeMult
        earR.Color = core.Color; earR.Material = core.Material
        attachPart(earR, CFrame.new(0.8 * sizeMult, 1.1 * sizeMult, 0) * CFrame.Angles(0, 0, math.rad(-25)))

        local snout = Instance.new("Part")
        snout.Name = "Snout"; snout.Size = Vector3.new(0.8, 0.5, 0.6) * sizeMult
        snout.Color = Color3.fromRGB(50, 45, 45); snout.Material = Enum.Material.SmoothPlastic
        attachPart(snout, CFrame.new(0, -0.1 * sizeMult, -1.2 * sizeMult))

        local tail = Instance.new("Part")
        tail.Name = "Tail"; tail.Size = Vector3.new(0.4, 0.4, 0.9) * sizeMult
        tail.Color = core.Color; tail.Material = core.Material
        attachPart(tail, CFrame.new(0, 0.6 * sizeMult, 1.2 * sizeMult) * CFrame.Angles(math.rad(40), 0, 0))

    elseif string.find(petId, "turtle") then
        local head = Instance.new("Part")
        head.Name = "TurtleHead"; head.Shape = Enum.PartType.Ball
        head.Size = Vector3.new(1.0, 0.9, 1.1) * sizeMult
        head.Color = Color3.fromRGB(90, 140, 95); head.Material = Enum.Material.SmoothPlastic
        attachPart(head, CFrame.new(0, 0.2 * sizeMult, -1.4 * sizeMult))

        local footPositions = {
            {-1.1, -0.6, -0.8}, {1.1, -0.6, -0.8},
            {-1.1, -0.6, 0.8}, {1.1, -0.6, 0.8}
        }
        for idx, pos in ipairs(footPositions) do
            local foot = Instance.new("Part")
            foot.Name = "Foot_" .. idx; foot.Shape = Enum.PartType.Ball
            foot.Size = Vector3.new(0.6, 0.5, 0.7) * sizeMult
            foot.Color = Color3.fromRGB(80, 125, 85); foot.Material = Enum.Material.SmoothPlastic
            attachPart(foot, CFrame.new(pos[1] * sizeMult, pos[2] * sizeMult, pos[3] * sizeMult))
        end

    elseif string.find(petId, "crab") then
        local clawL = Instance.new("Part")
        clawL.Name = "ClawL"; clawL.Size = Vector3.new(0.6, 1.1, 0.8) * sizeMult
        clawL.Color = Color3.fromRGB(200, 70, 50); clawL.Material = Enum.Material.SmoothPlastic
        attachPart(clawL, CFrame.new(-1.3 * sizeMult, 0.6 * sizeMult, -1.0 * sizeMult) * CFrame.Angles(math.rad(20), math.rad(-20), math.rad(-30)))

        local clawR = Instance.new("Part")
        clawR.Name = "ClawR"; clawR.Size = Vector3.new(0.6, 1.1, 0.8) * sizeMult
        clawR.Color = Color3.fromRGB(200, 70, 50); clawR.Material = Enum.Material.SmoothPlastic
        attachPart(clawR, CFrame.new(1.3 * sizeMult, 0.6 * sizeMult, -1.0 * sizeMult) * CFrame.Angles(math.rad(20), math.rad(20), math.rad(30)))

    elseif string.find(petId, "geode") or string.find(petId, "amethyst") then
        local crystalColors = { Color3.fromRGB(190, 60, 255), Color3.fromRGB(220, 120, 255), Color3.fromRGB(150, 40, 230) }
        local spikeOffsets = {
            CFrame.new(0, 1.2 * sizeMult, -0.4 * sizeMult) * CFrame.Angles(math.rad(25), 0, 0),
            CFrame.new(-0.7 * sizeMult, 0.8 * sizeMult, -0.6 * sizeMult) * CFrame.Angles(math.rad(30), math.rad(-30), 0),
            CFrame.new(0.7 * sizeMult, 0.8 * sizeMult, -0.6 * sizeMult) * CFrame.Angles(math.rad(30), math.rad(30), 0),
            CFrame.new(0, 0.9 * sizeMult, 0.7 * sizeMult) * CFrame.Angles(math.rad(-25), 0, 0)
        }
        for i, cf in ipairs(spikeOffsets) do
            local spike = Instance.new("Part")
            spike.Name = "Crystal_" .. i
            spike.Size = Vector3.new(0.5, 1.2, 0.5) * sizeMult
            spike.Color = crystalColors[(i % 3) + 1]
            spike.Material = Enum.Material.Neon
            attachPart(spike, cf)
        end
        local pLight = Instance.new("PointLight")
        pLight.Color = Color3.fromRGB(190, 60, 255)
        pLight.Brightness = 2.0
        pLight.Range = 10
        pLight.Parent = core
    end

    -- 3. CARTOON EYES WITH PUPILS
    local eyeL = Instance.new("Part")
    eyeL.Name = "EyeL"; eyeL.Shape = Enum.PartType.Ball; eyeL.Size = Vector3.new(0.6, 0.6, 0.4) * sizeMult
    eyeL.Color = Color3.fromRGB(255, 255, 255); eyeL.Material = Enum.Material.SmoothPlastic
    attachPart(eyeL, CFrame.new(-0.5 * sizeMult, 0.3 * sizeMult, -1.0 * sizeMult))

    local pupilL = Instance.new("Part")
    pupilL.Name = "PupilL"; pupilL.Shape = Enum.PartType.Ball; pupilL.Size = Vector3.new(0.3, 0.3, 0.2) * sizeMult
    pupilL.Color = Color3.fromRGB(20, 20, 25); pupilL.Material = Enum.Material.SmoothPlastic
    attachPart(pupilL, CFrame.new(-0.5 * sizeMult, 0.3 * sizeMult, -1.15 * sizeMult))

    local eyeR = Instance.new("Part")
    eyeR.Name = "EyeR"; eyeR.Shape = Enum.PartType.Ball; eyeR.Size = Vector3.new(0.6, 0.6, 0.4) * sizeMult
    eyeR.Color = Color3.fromRGB(255, 255, 255); eyeR.Material = Enum.Material.SmoothPlastic
    attachPart(eyeR, CFrame.new(0.5 * sizeMult, 0.3 * sizeMult, -1.0 * sizeMult))

    local pupilR = Instance.new("Part")
    pupilR.Name = "PupilR"; pupilR.Shape = Enum.PartType.Ball; pupilR.Size = Vector3.new(0.3, 0.3, 0.2) * sizeMult
    pupilR.Color = Color3.fromRGB(20, 20, 25); pupilR.Material = Enum.Material.SmoothPlastic
    attachPart(pupilR, CFrame.new(0.5 * sizeMult, 0.3 * sizeMult, -1.15 * sizeMult))

    -- 4. GOLDEN & RAINBOW & HUGE/TITANIC VISUAL EFFECTS
    local petSize = pet.Size or "Normal"
    if petSize == "Huge" or petSize == "Titanic" then
        local beaconLight = Instance.new("PointLight")
        beaconLight.Color = (petSize == "Titanic") and Color3.fromRGB(255, 60, 180) or Color3.fromRGB(180, 80, 255)
        beaconLight.Brightness = 3.5
        beaconLight.Range = 25
        beaconLight.Parent = core

        local pEmitter = Instance.new("ParticleEmitter")
        pEmitter.Name = "TitanicAura"
        pEmitter.Rate = (petSize == "Titanic") and 25 or 12
        pEmitter.Speed = NumberRange.new(4, 8)
        pEmitter.Lifetime = NumberRange.new(1.0, 1.8)
        pEmitter.SpreadAngle = Vector2.new(180, 180)
        pEmitter.Size = NumberSequence.new(0.6 * sizeMult, 0)
        pEmitter.Color = ColorSequence.new(beaconLight.Color)
        pEmitter.Parent = core
    end

    if mutation == "Golden" then
        local spk = Instance.new("Sparkles")
        spk.SparkleColor = Color3.fromRGB(255, 220, 50)
        spk.Parent = core
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 215, 0)
        hl.OutlineColor = Color3.fromRGB(255, 245, 120)
        hl.FillTransparency = 0.6
        hl.Parent = petModel
    elseif mutation == "Rainbow" then
        local spk = Instance.new("Sparkles")
        spk.SparkleColor = Color3.fromRGB(255, 100, 255)
        spk.Parent = core
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 80, 220)
        hl.OutlineColor = Color3.fromRGB(100, 255, 255)
        hl.FillTransparency = 0.5
        hl.Parent = petModel
    end

    -- 5. FLOATING BILLBOARD LABEL
    local incVal = pet.TotalIncomePerSec or pet.BaseIncome or 1
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 140, 0, 32)
    bg.StudsOffset = Vector3.new(0, 2.5 * sizeMult, 0)
    bg.AlwaysOnTop = true
    bg.Parent = core
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Text = string.format("+$%s/s", UpgradeConfig.FormatNumber(incVal))
    lbl.TextColor3 = (mutation == "Rainbow" and Color3.fromRGB(255, 120, 255))
        or (mutation == "Golden" and Color3.fromRGB(255, 215, 40))
        or Color3.fromRGB(80, 255, 120)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.FredokaOne
    lbl.BackgroundTransparency = 1
    lbl.Parent = bg
    
    petModel:SetAttribute("PetId", pet.Id or pet.Name)
    petModel:SetAttribute("Income", incVal)
    petModel:SetAttribute("Mutation", mutation)
    petModel.Parent = petRocks

    RecalculateBaseIncome(base)
    return petModel
end
_G.SpawnRoamingPetInPen = SpawnRoamingPetInPen

-- CLAIM & HATCH EGG
local function ClaimHatchedEgg(player: Player, eggModel: Model)
    local state = activeEggs[eggModel]
    if not state or state.IsClaiming then return end
    
    local now = os.time()
    if now < state.FinishTime then return end
    state.IsClaiming = true
    
    local rollResult = RockPetConfig.RollPet(state.EggName)
    if not rollResult then
        state.IsClaiming = false
        return
    end
    
    local newPet = {
        Id = rollResult.PetId,
        Name = rollResult.Name,
        Rarity = rollResult.Rarity,
        BaseIncome = rollResult.BaseIncome,
        Size = rollResult.Size,
        SizeMultiplier = rollResult.SizeMultiplier,
        Mutation = rollResult.Mutation,
        MutationMultiplier = rollResult.MutationMultiplier,
        TotalIncomePerSec = rollResult.TotalIncomePerSec,
        ObtainedAt = now
    }
    
    DataService.AddPet(player, newPet)
    
    hatchRemote:FireClient(player, "HatchReveal", {
        Pet = newPet,
        PetName = newPet.Name,
        Name = newPet.Name,
        Rarity = newPet.Rarity,
        Size = newPet.Size,
        Mutation = newPet.Mutation,
        Income = newPet.TotalIncomePerSec,
        EggName = state.EggName
    })
    
    local isHighRarity = rollResult.Rarity == "Legendary" or rollResult.Rarity == "Secret" or rollResult.Rarity == "Divine" or rollResult.Rarity == "Eternal"
    local isColossal = rollResult.Size == "Huge" or rollResult.Size == "Titanic"
    if isHighRarity or isColossal then
        for _, p in ipairs(Players:GetPlayers()) do
            hatchRemote:FireClient(p, "GlobalAnnouncement", {
                PlayerName = player.DisplayName,
                PetName = rollResult.Name,
                Rarity = rollResult.Rarity,
                Size = rollResult.Size,
                EggName = state.EggName
            })
        end
    end
    
    local base = GetPlayerBase(player)
    if base then
        SpawnRoamingPetInPen(base, newPet)
    end
    
    activeEggs[eggModel] = nil
    eggModel:Destroy()
    
    local char = player.Character
    ShowFloatingText(char and char:FindFirstChild("Head"), string.format("HATCHED %s (%s)! 🎉", rollResult.Name, rollResult.Rarity), Color3.fromRGB(255, 215, 40))
end

-- Listen for client hatch claims (Mobile / Desktop / Prompt fallback)
hatchRemote.OnServerEvent:Connect(function(player: Player, action: any, eggModel: any)
    if action == "ClaimHatch" and typeof(eggModel) == "Instance" and eggModel:IsA("Model") then
        ClaimHatchedEgg(player, eggModel)
    end
end)

-- =============================================================================
-- FREE PLACEMENT IN PEN (WITH CAPACITY LIMIT)
-- =============================================================================
local function PlaceEggInPen(player: Player, eggName: string, dropPos: Vector3?): boolean
    local base = GetPlayerBase(player)
    if not base then return false end
    
    local bFloor = base:FindFirstChild("BaseFloor") :: BasePart?
    if not bFloor then return false end
    
    local eggFolder = base:FindFirstChild("IncubatingEggs")
    if not eggFolder then
        eggFolder = Instance.new("Folder")
        eggFolder.Name = "IncubatingEggs"
        eggFolder.Parent = base
    end
    
    local currentCount = #eggFolder:GetChildren()
    local maxCapacity = GetPenCapacity(player)
    
    local char = player.Character
    local head = char and char:FindFirstChild("Head") :: BasePart?
    
    -- Check Capacity Limit (Steal a Pet style)
    if currentCount >= maxCapacity then
        ShowFloatingText(head, string.format("PEN FULL! (%d/%d) UPGRADE PEN! 🛑", currentCount, maxCapacity), Color3.fromRGB(255, 100, 100))
        return false -- Keeps egg with player, zero disappearing!
    end
    
    local eggConfig = RockPetConfig.EGGS[eggName]
    if not eggConfig then
        eggName = "Common Rock"
        eggConfig = RockPetConfig.EGGS["Common Rock"]
    end
    
    -- Calculate free position on pen grass
    local targetPos = dropPos or (char and char.PrimaryPart and char.PrimaryPart.Position) or bFloor.Position
    local clampX = math.clamp(targetPos.X, bFloor.Position.X - 20, bFloor.Position.X + 20)
    local clampZ = math.clamp(targetPos.Z, bFloor.Position.Z - 20, bFloor.Position.Z + 20)
    
    -- Nudge if overlapping another egg
    for _, other in ipairs(eggFolder:GetChildren()) do
        if other:IsA("Model") and other.PrimaryPart then
            local dist = (Vector3.new(clampX, 0, clampZ) - Vector3.new(other.PrimaryPart.Position.X, 0, other.PrimaryPart.Position.Z)).Magnitude
            if dist < 3.5 then
                clampX = math.clamp(clampX + math.random(-4, 4), bFloor.Position.X - 20, bFloor.Position.X + 20)
                clampZ = math.clamp(clampZ + math.random(-4, 4), bFloor.Position.Z - 20, bFloor.Position.Z + 20)
            end
        end
    end
    
    local eggCF = CFrame.new(clampX, bFloor.Position.Y + 2.0, clampZ)
    
    -- Build Incubating Egg Model
    local eggModel = Instance.new("Model")
    eggModel.Name = "Incubating_" .. eggName
    
    local colorMap = {
        ["Common Rock"] = Color3.fromRGB(160, 165, 175),
        ["Mossy Stone"] = Color3.fromRGB(100, 180, 90),
        ["Obsidian Geode"] = Color3.fromRGB(45, 30, 70),
        ["Magma Core"] = Color3.fromRGB(220, 80, 20),
        ["Celestial Meteor"] = Color3.fromRGB(80, 40, 160),
        ["Primordial Relic"] = Color3.fromRGB(0, 220, 200),
        ["Abyssal Void"] = Color3.fromRGB(130, 40, 255)
    }
    local baseColor = colorMap[eggName] or Color3.fromRGB(180, 180, 180)
    
    local core = Instance.new("Part")
    core.Name = "EggCore"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(3.4, 4.0, 3.4)
    core.CFrame = eggCF + Vector3.new(0, 1.8, 0)
    core.Material = (eggName == "Common Rock") and Enum.Material.Slate or Enum.Material.Marble
    core.Color = baseColor
    core.Anchored = true
    core.CanCollide = false
    core.Parent = eggModel
    eggModel.PrimaryPart = core
    
    -- Magic Halo on grass floor
    local halo = Instance.new("Part")
    halo.Name = "MagicHalo"
    halo.Shape = Enum.PartType.Cylinder
    halo.Size = Vector3.new(0.2, 5.0, 5.0)
    halo.CFrame = eggCF * CFrame.Angles(0, 0, math.rad(90))
    halo.Material = Enum.Material.Neon
    halo.Color = baseColor
    halo.Anchored = true
    halo.CanCollide = false
    halo.Parent = eggModel
    
    local pLight = Instance.new("PointLight")
    pLight.Color = baseColor
    pLight.Brightness = 1.0
    pLight.Range = 12
    pLight.Parent = core
    
    -- Cartoon eyes
    local eyeL = Instance.new("Part")
    eyeL.Name = "EyeL"
    eyeL.Shape = Enum.PartType.Ball
    eyeL.Size = Vector3.new(0.7, 0.7, 0.4)
    eyeL.Color = Color3.fromRGB(255, 255, 255)
    eyeL.CanCollide = false
    eyeL.Anchored = true
    eyeL.CFrame = core.CFrame * CFrame.new(-0.7, 0.4, -1.4)
    eyeL.Parent = eggModel
    
    local eyeR = Instance.new("Part")
    eyeR.Name = "EyeR"
    eyeR.Shape = Enum.PartType.Ball
    eyeR.Size = Vector3.new(0.7, 0.7, 0.4)
    eyeR.Color = Color3.fromRGB(255, 255, 255)
    eyeR.CanCollide = false
    eyeR.Anchored = true
    eyeR.CFrame = core.CFrame * CFrame.new(0.7, 0.4, -1.4)
    eyeR.Parent = eggModel
    
    -- Countdown BillboardGui
    local bGui = Instance.new("BillboardGui")
    bGui.Name = "CountdownUI"
    bGui.Size = UDim2.new(0, 160, 0, 50)
    bGui.StudsOffset = Vector3.new(0, 3.8, 0)
    bGui.AlwaysOnTop = true
    bGui.Parent = core
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, 0, 0, 20)
    titleLbl.Text = eggName
    titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLbl.TextSize = 13
    titleLbl.Font = Enum.Font.FredokaOne
    titleLbl.BackgroundTransparency = 1
    titleLbl.Parent = bGui
    
    local countLbl = Instance.new("TextLabel")
    countLbl.Name = "TimeLabel"
    countLbl.Size = UDim2.new(1, 0, 0, 28)
    countLbl.Position = UDim2.new(0, 0, 0, 20)
    countLbl.Text = "⏳ Incubating..."
    countLbl.TextColor3 = Color3.fromRGB(255, 220, 50)
    countLbl.TextSize = 15
    countLbl.Font = Enum.Font.FredokaOne
    countLbl.BackgroundTransparency = 1
    countLbl.Parent = bGui
    
    -- Hatch ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "HatchPrompt"
    prompt.ActionText = "Crack & Hatch Pet! ✨"
    prompt.ObjectText = eggName
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Enabled = false
    prompt.Parent = core
    
    prompt.Triggered:Connect(function(triggerPlayer)
        local ownerId = base:GetAttribute("OwnerUserId")
        if triggerPlayer.UserId == ownerId then
            ClaimHatchedEgg(triggerPlayer, eggModel)
        end
    end)
    
    eggModel.Parent = eggFolder
    
    local duration = eggConfig.HatchTime
    if player:GetAttribute("HasFasterHatch") == true then
        duration = math.max(1, math.floor(duration * 0.5))
    end
    
    activeEggs[eggModel] = {
        EggId = HttpService:GenerateGUID(false),
        Player = player,
        EggName = eggName,
        FinishTime = os.time() + duration,
        TotalDuration = duration,
        EggModel = eggModel,
        Prompt = prompt,
        CountdownLabel = countLbl,
        IsClaiming = false
    }
    
    CleanPlayerCarriedEgg(player)
    ShowFloatingText(head, string.format("PLACED IN PEN! 🥚✨ (%d/%d)", currentCount + 1, maxCapacity), Color3.fromRGB(80, 255, 120))
    return true
end

-- INITIALIZE ALL BASES (CLEAN OLD PEDESTALS)
local function InitBasePen(base: Model)
    local oldStation = base:FindFirstChild("IncubationStation") or base:FindFirstChild("PedestalStation")
    if oldStation then oldStation:Destroy() end
    
    local eggFolder = base:FindFirstChild("IncubatingEggs")
    if not eggFolder then
        eggFolder = Instance.new("Folder")
        eggFolder.Name = "IncubatingEggs"
        eggFolder.Parent = base
    end
    
    local petFolder = base:FindFirstChild("PetRocks")
    if not petFolder then
        petFolder = Instance.new("Folder")
        petFolder.Name = "PetRocks"
        petFolder.Parent = base
    end
end

for _, base in ipairs(bases:GetChildren()) do
    InitBasePen(base)
end

-- =============================================================================
-- COUNTDOWN TICK LOOP (UPDATE ALL INCUBATING EGGS IN REAL TIME)
-- =============================================================================
task.spawn(function()
    while true do
        task.wait(1)
        local now = os.time()
        
        for eggModel, state in pairs(activeEggs) do
            if eggModel and eggModel.PrimaryPart then
                local isNight = arena:GetAttribute("IsNightTime") == true
                if isNight and state.FinishTime > now then
                    state.FinishTime = math.max(now, state.FinishTime - 4)
                end
                local timeLeft = math.max(0, state.FinishTime - now)
                if timeLeft > 0 then
                    local mins = math.floor(timeLeft / 60)
                    local secs = timeLeft % 60
                    if state.CountdownLabel then
                        state.CountdownLabel.Text = string.format("⏳ %02d:%02d", mins, secs)
                        state.CountdownLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
                    end
                else
                    if state.CountdownLabel then
                        state.CountdownLabel.Text = "✨ READY TO HATCH! ✨"
                        state.CountdownLabel.TextColor3 = Color3.fromRGB(80, 255, 120)
                    end
                    if state.Prompt and not state.Prompt.Enabled then
                        state.Prompt.Enabled = true
                    end
                end
            else
                activeEggs[eggModel] = nil
            end
        end
    end
end)

-- BINDABLE FUNCTION FOR STEAL ZONE / EXTERNAL SERVICES
local incubateFunc = ReplicatedStorage:WaitForChild("IncubateEggFunction") :: BindableFunction
incubateFunc.OnInvoke = function(player: Player, eggName: string, dropPos: Vector3?): boolean
    return PlaceEggInPen(player, eggName, dropPos)
end

_G.HatchPlaceEgg = function(player: Player, eggName: string, dropPos: Vector3?): boolean
    return PlaceEggInPen(player, eggName, dropPos)
end

-- SYNC SAVED PETS ON PLAYER JOIN
local function SyncPlayerPets(player: Player)
    task.wait(1.5)
    local pData = DataService.GetData(player)
    local base = GetPlayerBase(player)
    if base and pData and pData.Pets then
        local petRocks = base:FindFirstChild("PetRocks")
        if petRocks then
            petRocks:ClearAllChildren()
            for _, pet in ipairs(pData.Pets) do
                SpawnRoamingPetInPen(base, pet)
            end
            RecalculateBaseIncome(base)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(SyncPlayerPets, player)
end)

for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(SyncPlayerPets, p)
end
