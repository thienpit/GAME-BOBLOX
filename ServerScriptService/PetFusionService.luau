--!strict
--[[
    SCRIPT: PetFusionService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> PetFusionService
    DESCRIPTION: Server-authoritative Pet Fusion Anvil System (Steal a Pet style).
                 - Strict server-side validation (3 pets of identical species & tier)
                 - Race-condition guard: 1.0s cooldown + atomic profile mutation
                 - Transforms 3 Normal -> 1 Golden (2.5x) or 3 Golden -> 1 Rainbow (5x)
                 - Physical Deco_FusionAnvil model in village plaza with ProximityPrompt
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local RockPetConfig = require(ReplicatedStorage:WaitForChild("RockPetConfig"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))

local fuseEvent = ReplicatedStorage:WaitForChild("FuseEvent") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")

local fuseCooldowns: { [number]: number } = {}
local FUSE_COOLDOWN = 1.0

-- Helper: Floating text feedback
local function ShowFloatingText(head: BasePart?, text: string, color: Color3)
    if not head then return end
    task.spawn(function()
        local bb = Instance.new("BillboardGui")
        bb.Size = UDim2.new(0, 240, 0, 42)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = head
        
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0)
        tl.Text = text
        tl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        tl.TextSize = 16
        tl.Font = Enum.Font.FredokaOne
        tl.BackgroundTransparency = 1
        tl.TextStrokeTransparency = 0.4
        tl.Parent = bb
        
        for step = 1, 25 do
            task.wait(0.04)
            bb.StudsOffset = bb.StudsOffset + Vector3.new(0, 0.12, 0)
            tl.TextTransparency = step / 25
        end
        bb:Destroy()
    end)
end

-- =============================================================================
-- 1. BUILD PHYSICAL FUSION ANVIL IN VILLAGE PLAZA (X = 0, Z = -45)
-- =============================================================================
local function BuildFusionAnvil()
    local oldAnvil = arena:FindFirstChild("Deco_FusionAnvil")
    if oldAnvil then oldAnvil:Destroy() end

    local anvilModel = Instance.new("Model")
    anvilModel.Name = "Deco_FusionAnvil"

    -- Stone Base
    local base = Instance.new("Part")
    base.Name = "Deco_AnvilBase"
    base.Size = Vector3.new(7, 1.2, 7)
    base.CFrame = CFrame.new(0, 0.6, -45)
    base.Material = Enum.Material.Basalt
    base.Color = Color3.fromRGB(45, 40, 52)
    base.Anchored = true
    base.CanCollide = false
    base.Parent = anvilModel
    anvilModel.PrimaryPart = base

    -- Glowing Magic Rune Circle
    local runeRing = Instance.new("Part")
    runeRing.Name = "Deco_RuneRing"
    runeRing.Shape = Enum.PartType.Cylinder
    runeRing.Size = Vector3.new(0.2, 9.5, 9.5)
    runeRing.CFrame = CFrame.new(0, 0.05, -45) * CFrame.Angles(0, 0, math.rad(90))
    runeRing.Material = Enum.Material.Neon
    runeRing.Color = Color3.fromRGB(255, 215, 30)
    runeRing.Anchored = true
    runeRing.CanCollide = false
    runeRing.Parent = anvilModel

    -- Chunky Anvil Body
    local anvilBody = Instance.new("Part")
    anvilBody.Name = "Deco_AnvilBody"
    anvilBody.Size = Vector3.new(3.8, 3.2, 5.2)
    anvilBody.CFrame = CFrame.new(0, 2.6, -45)
    anvilBody.Material = Enum.Material.Metal
    anvilBody.Color = Color3.fromRGB(75, 80, 95)
    anvilBody.Anchored = true
    anvilBody.CanCollide = false
    anvilBody.Parent = anvilModel

    -- Light
    local pl = Instance.new("PointLight")
    pl.Color = Color3.fromRGB(255, 215, 40)
    pl.Brightness = 2.2
    pl.Range = 18
    pl.Parent = anvilBody

    -- Proximity Prompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "FusePrompt"
    prompt.ActionText = "Fuse 3 Pets ✨"
    prompt.ObjectText = "Fusion Anvil"
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = anvilBody

    prompt.Triggered:Connect(function(player)
        PerformAutoFuse(player)
    end)

    anvilModel.Parent = arena
end

-- =============================================================================
-- 2. SERVER-SIDE FUSION LOGIC (ATOMIC & ANTI-DUPING)
-- =============================================================================
function PerformFuse(player: Player, petName: string, targetTier: "Golden" | "Rainbow"): boolean
    local userId = player.UserId
    local now = os.clock()
    if now < (fuseCooldowns[userId] or 0) then
        return false
    end
    fuseCooldowns[userId] = now + FUSE_COOLDOWN

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local head = char and char:FindFirstChild("Head") :: BasePart?
    if not char or not hrp or not head then return false end

    -- Distance check: player must be within 35 studs of the Anvil
    local dist = (hrp.Position - Vector3.new(0, 2, -45)).Magnitude
    if dist > 35 then
        ShowFloatingText(head, "Too far from Anvil! ❌", Color3.fromRGB(255, 100, 100))
        return false
    end

    local pData = DataService.GetData(player)
    if not pData or not pData.Pets or #pData.Pets < 3 then
        ShowFloatingText(head, "Need at least 3 pets! ❌", Color3.fromRGB(255, 100, 100))
        return false
    end

    local rule = RockPetConfig.FusionRules[targetTier]
    if not rule then return false end

    -- Check cost
    if pData.Money < rule.Cost then
        ShowFloatingText(head, string.format("Need $%d to Fuse! ❌", rule.Cost), Color3.fromRGB(255, 100, 100))
        return false
    end

    -- 1. Scan for 3 matching pets
    local matchedIndices: { number } = {}
    local samplePet: any = nil

    for idx, pet in ipairs(pData.Pets) do
        local pMut = pet.Mutation or "Normal"
        if pet.Name == petName and pMut == rule.InputMutation then
            table.insert(matchedIndices, idx)
            samplePet = pet
            if #matchedIndices == 3 then
                break
            end
        end
    end

    if #matchedIndices < 3 or not samplePet then
        ShowFloatingText(head, string.format("Need 3x %s (%s) to Fuse! ❌", petName, rule.InputMutation), Color3.fromRGB(255, 120, 120))
        return false
    end

    -- 2. Deduct Cost
    if not DataService.SubMoney(player, rule.Cost) then
        return false
    end

    -- 3. Remove the 3 pets in reverse index order to maintain array integrity
    table.sort(matchedIndices, function(a, b) return a > b end)
    for _, idx in ipairs(matchedIndices) do
        table.remove(pData.Pets, idx)
    end

    -- 4. Calculate new fused pet stats
    local newMultiplier = rule.Multiplier
    local baseInc = samplePet.BaseIncome or 1
    local sizeMult = samplePet.SizeMultiplier or 1.0
    local finalInc = math.max(1, math.floor(baseInc * sizeMult * newMultiplier))

    local newPet = {
        Id = HttpService:GenerateGUID(false),
        Name = samplePet.Name,
        Rarity = samplePet.Rarity,
        BaseIncome = baseInc,
        Size = samplePet.Size or "Normal",
        SizeMultiplier = sizeMult,
        Mutation = rule.OutputMutation,
        MutationMultiplier = newMultiplier,
        TotalIncomePerSec = finalInc,
        ObtainedAt = os.time()
    }

    table.insert(pData.Pets, newPet)

    -- Synchronize physical 3D models in base pen
    local BaseService = require(ServerScriptService:WaitForChild("BaseService"))
    local base = BaseService.GetPlayerBase(player)
    if base then
        local petRocks = base:FindFirstChild("PetRocks")
        if petRocks then
            local removedCount = 0
            for _, r in ipairs(petRocks:GetChildren()) do
                if removedCount < 3 and string.find(r.Name, petName) then
                    r:Destroy()
                    removedCount = removedCount + 1
                end
            end
            if _G.SpawnRoamingPetInPen then
                _G.SpawnRoamingPetInPen(base, newPet)
            end
            if _G.RecalculateBaseIncome then
                _G.RecalculateBaseIncome(base)
            end
        end
    end

    -- Feedback
    local tierColor = targetTier == "Rainbow" and Color3.fromRGB(255, 100, 255) or Color3.fromRGB(255, 215, 30)
    ShowFloatingText(head, string.format("✨ FUSED %s %s! (+%s/s)", string.upper(targetTier), newPet.Name, tostring(finalInc)), tierColor)
    fuseEvent:FireClient(player, "FuseSuccess", newPet)

    -- Announcement for Rainbow pets
    if targetTier == "Rainbow" then
        for _, p in ipairs(Players:GetPlayers()) do
            fuseEvent:FireClient(p, "GlobalFuseAlert", {
                PlayerName = player.DisplayName,
                PetName = newPet.Name,
                Tier = targetTier
            })
        end
    end

    print(string.format("[PetFusion] %s successfully fused 3x %s into %s %s!", player.Name, petName, targetTier, newPet.Name))
    return true
end

-- Convenience Auto-Fuse: fuses the first available triplet
function PerformAutoFuse(player: Player): boolean
    local pData = DataService.GetData(player)
    if not pData or not pData.Pets or #pData.Pets < 3 then
        local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
        ShowFloatingText(head, "Need at least 3 matching pets! ❌", Color3.fromRGB(255, 100, 100))
        return false
    end

    local counts: { [string]: number } = {}
    for _, pet in ipairs(pData.Pets) do
        local pMut = pet.Mutation or "Normal"
        local key = pet.Name .. "::" .. pMut
        counts[key] = (counts[key] or 0) + 1
    end

    -- Try Rainbow fusion first (3 Golden -> 1 Rainbow)
    for key, count in pairs(counts) do
        if count >= 3 then
            local parts = string.split(key, "::")
            local pName, pMut = parts[1], parts[2]
            if pMut == "Golden" then
                return PerformFuse(player, pName, "Rainbow")
            end
        end
    end

    -- Try Golden fusion (3 Normal -> 1 Golden)
    for key, count in pairs(counts) do
        if count >= 3 then
            local parts = string.split(key, "::")
            local pName, pMut = parts[1], parts[2]
            if pMut == "Normal" then
                return PerformFuse(player, pName, "Golden")
            end
        end
    end

    local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
    ShowFloatingText(head, "No 3 identical pets found to fuse! ❌", Color3.fromRGB(255, 120, 120))
    return false
end

-- 3. REMOTE EVENT DISPATCH
fuseEvent.OnServerEvent:Connect(function(player: Player, action: string, petName: any, targetTier: any)
    if action == "FusePet" and typeof(petName) == "string" and (targetTier == "Golden" or targetTier == "Rainbow") then
        PerformFuse(player, petName, targetTier)
    elseif action == "AutoFuse" then
        PerformAutoFuse(player)
    end
end)

BuildFusionAnvil()
print("[PetFusionService] ✅ Fusion Anvil built and initialized successfully!")
