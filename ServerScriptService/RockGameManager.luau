local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RockConfig = require(ReplicatedStorage:WaitForChild("RockConfig"))
local UpgradeConfig = require(ReplicatedStorage:WaitForChild("UpgradeConfig"))
local DataService = require(game:GetService("ServerScriptService"):WaitForChild("DataService"))
local BaseService = require(game:GetService("ServerScriptService"):WaitForChild("BaseService"))

local EGG_NAME_MAP = {
    [1] = "Common Rock",
    [2] = "Obsidian Geode",
    [3] = "Magma Core",
    [4] = "Celestial Meteor",
    [5] = "Cyber Matrix Egg",
    [6] = "Pegasus Egg",
    [7] = "Experiment Egg"
}

local arena = workspace:WaitForChild("Arena_Map")
local platform = arena:WaitForChild("Platform")
local bases = arena:WaitForChild("Bases")
local gate = arena:WaitForChild("RunwayGate")
local zones = arena:WaitForChild("Zones")
local activeSpawns = arena:WaitForChild("ActiveSpawns")

local ROUND_DURATION = 300
local INTERMISSION_DURATION = 20
local timeLeft = ROUND_DURATION
local isIntermission = false

local playerCarrying = {}
local playerOnTreadmill = {}
local playerTreadmillCooldown = {}

-- 1. CLEAN SHORT FLOATING TEXT
local function ShowFloatingText(head, text, color)
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 180, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head
    
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.Text = text
    tl.TextColor3 = color or Color3.fromRGB(0, 255, 255)
    tl.TextSize = 16
    tl.Font = Enum.Font.FredokaOne
    tl.BackgroundTransparency = 1
    tl.TextStrokeTransparency = 0.5
    tl.Parent = bb
    
    task.spawn(function()
        for step = 1, 20 do
            task.wait(0.04)
            bb.StudsOffset = bb.StudsOffset + Vector3.new(0, 0.12, 0)
            tl.TextTransparency = step / 20
        end
        bb:Destroy()
    end)
end

-- 2. RECALCULATE BASE INCOME
local function RecalculateBaseIncome(base)
    if not base then return 0 end
    local rocksFolder = base:FindFirstChild("PetRocks")
    if not rocksFolder then return 0 end
    
    local totalInc = 0
    local rockCount = 0
    for _, rock in ipairs(rocksFolder:GetChildren()) do
        local inc = rock:GetAttribute("Income") or 0
        totalInc = totalInc + inc
        rockCount = rockCount + 1
    end
    
    base:SetAttribute("IncomePerSec", totalInc)
    base:SetAttribute("RockCount", rockCount)
    return totalInc
end

-- 3. LEADERSTATS (DataService creates leaderstats with Money & Speed)
local function SetupLeaderstats(player)
    -- DataService.LoadProfile handles leaderstats creation ("Money" + "Speed")
    DataService.LoadProfile(player)
end

-- 4. SILENT AUTO-ASSIGN BASE VIA BASESERVICE
local function ClaimBase(player)
    local base = BaseService.GetOrClaimBase(player)
    if base then
        RecalculateBaseIncome(base)
        local char = player.Character
        if char and char.PrimaryPart then
            char:PivotTo(base.BaseFloor.CFrame + Vector3.new(0, 5, 0))
        end
    end
    return base
end

local function ReleaseBase(player)
    BaseService.ReleaseBase(player)

    if playerCarrying[player] and playerCarrying[player].Model then
        playerCarrying[player].Model:Destroy()
        playerCarrying[player] = nil
    end
end

-- 5. ROCK MODEL BUILDER
local function CreateRockModel(rockType, sizeData, targetCFrame, isPhysical, isGolden)
    local model = Instance.new("Model")
    model.Name = "Rock_" .. rockType.Id
    
    local finalScale = rockType.BaseScale * sizeData.ScaleMult
    
    local core = Instance.new("Part")
    core.Name = "RockCore"
    core.Shape = Enum.PartType.Ball
    core.Size = finalScale
    core.Material = isGolden and Enum.Material.Foil or rockType.Material
    core.Color = isGolden and Color3.fromRGB(255, 215, 40) or rockType.Color
    core.CanCollide = isPhysical or false
    core.Massless = not isPhysical
    core.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.4, 0.6, 1.0, 1.0)
    core.CFrame = targetCFrame or CFrame.new(0, 50, 0)
    core.Parent = model
    model.PrimaryPart = core

    local function attachPart(p: BasePart, cfOffset: CFrame)
        p.CFrame = core.CFrame * cfOffset
        p.CanCollide = false
        p.Massless = true
        p.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = core
        w.Part1 = p
        w.Parent = core
    end
    
    -- Expressive cartoon eyes with dark pupils
    local eyeRadius = math.clamp(finalScale.X * 0.2, 0.4, 2.0)
    local eyeL = Instance.new("Part")
    eyeL.Name = "EyeL"
    eyeL.Shape = Enum.PartType.Ball
    eyeL.Size = Vector3.new(eyeRadius, eyeRadius, eyeRadius * 0.6)
    eyeL.Color = Color3.fromRGB(255, 255, 255)
    eyeL.Material = Enum.Material.SmoothPlastic
    attachPart(eyeL, CFrame.new(-finalScale.X * 0.25, finalScale.Y * 0.2, -finalScale.Z * 0.45))
    
    local pupilL = Instance.new("Part")
    pupilL.Name = "PupilL"
    pupilL.Shape = Enum.PartType.Ball
    pupilL.Size = Vector3.new(eyeRadius * 0.5, eyeRadius * 0.5, eyeRadius * 0.3)
    pupilL.Color = Color3.fromRGB(20, 20, 25)
    pupilL.Material = Enum.Material.SmoothPlastic
    attachPart(pupilL, CFrame.new(-finalScale.X * 0.25, finalScale.Y * 0.2, -finalScale.Z * 0.52))

    local eyeR = Instance.new("Part")
    eyeR.Name = "EyeR"
    eyeR.Shape = Enum.PartType.Ball
    eyeR.Size = Vector3.new(eyeRadius * 1.05, eyeRadius * 1.05, eyeRadius * 0.6)
    eyeR.Color = Color3.fromRGB(255, 255, 255)
    eyeR.Material = Enum.Material.SmoothPlastic
    attachPart(eyeR, CFrame.new(finalScale.X * 0.25, finalScale.Y * 0.22, -finalScale.Z * 0.45))

    local pupilR = Instance.new("Part")
    pupilR.Name = "PupilR"
    pupilR.Shape = Enum.PartType.Ball
    pupilR.Size = Vector3.new(eyeRadius * 0.5, eyeRadius * 0.5, eyeRadius * 0.3)
    pupilR.Color = Color3.fromRGB(20, 20, 25)
    pupilR.Material = Enum.Material.SmoothPlastic
    attachPart(pupilR, CFrame.new(finalScale.X * 0.25, finalScale.Y * 0.22, -finalScale.Z * 0.52))

    -- Biome-Themed Visual Accents
    if rockType.Zone == 1 then
        local mossTuft = Instance.new("Part")
        mossTuft.Name = "MossTuft"
        mossTuft.Size = Vector3.new(finalScale.X * 0.6, finalScale.Y * 0.25, finalScale.Z * 0.6)
        mossTuft.Color = Color3.fromRGB(90, 160, 60)
        mossTuft.Material = Enum.Material.Grass
        attachPart(mossTuft, CFrame.new(0, finalScale.Y * 0.45, 0))
    elseif rockType.Zone == 2 then
        local crystal = Instance.new("Part")
        crystal.Name = "ObsidianSpire"
        crystal.Size = Vector3.new(finalScale.X * 0.3, finalScale.Y * 0.6, finalScale.Z * 0.3)
        crystal.Color = Color3.fromRGB(160, 60, 230)
        crystal.Material = Enum.Material.Neon
        attachPart(crystal, CFrame.new(0, finalScale.Y * 0.45, 0) * CFrame.Angles(math.rad(15), 0, math.rad(15)))
    elseif rockType.Zone == 3 then
        local fireVein = Instance.new("Part")
        fireVein.Name = "MagmaVein"
        fireVein.Size = Vector3.new(finalScale.X * 0.5, finalScale.Y * 0.3, finalScale.Z * 0.5)
        fireVein.Color = Color3.fromRGB(255, 100, 20)
        fireVein.Material = Enum.Material.Neon
        attachPart(fireVein, CFrame.new(0, finalScale.Y * 0.42, 0))
    elseif rockType.Zone == 4 then
        local halo = Instance.new("Part")
        halo.Name = "CelestialHalo"
        halo.Shape = Enum.PartType.Cylinder
        halo.Size = Vector3.new(finalScale.Y * 0.15, finalScale.X * 1.1, finalScale.Z * 1.1)
        halo.Color = Color3.fromRGB(100, 230, 255)
        halo.Material = Enum.Material.Neon
        attachPart(halo, CFrame.new(0, finalScale.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)))
    end
    
    if sizeData.Name == "Huge" or sizeData.Name == "Titanic" or isGolden then
        local pl = Instance.new("PointLight")
        pl.Color = isGolden and Color3.fromRGB(255, 220, 60) or sizeData.TitleColor
        pl.Brightness = 1.6
        pl.Range = 12
        pl.Parent = core

        local spk = Instance.new("Sparkles")
        spk.SparkleColor = isGolden and Color3.fromRGB(255, 215, 40) or Color3.fromRGB(120, 220, 255)
        spk.Parent = core
    end
    
    return model
end

-- 6. ATTACH ROCK TO PLAYER (WHEN CARRYING IN WILD BIOMES)
local function AttachRockToPlayer(player, rockType, sizeData, isGolden, spotIndex, rockId)
    local char = player.Character
    if not char then return end
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local hum = char:FindFirstChild("Humanoid")
    if not torso or not hum then return end
    
    if playerCarrying[player] and playerCarrying[player].Model then
        playerCarrying[player].Model:Destroy()
    end
    
    -- Position rock naturally in front of chest/arms (HUGGING ROCK POSTURE, NOT ON HEAD!)
    local forwardOffset = math.clamp((rockType.BaseScale.Z * sizeData.ScaleMult) / 2 + 0.8, 1.4, 2.2)
    local targetCF = torso.CFrame * CFrame.new(0, -0.2, -forwardOffset) * CFrame.Angles(math.rad(-8), 0, 0)
    local rockModel = CreateRockModel(rockType, sizeData, targetCF, false, isGolden)
    rockModel.Parent = char
    rockModel:SetAttribute("IsCarriedItem", true)
    
    local rId = rockId or ("Rock_" .. HttpService:GenerateGUID(false):sub(1, 8))
    rockModel:SetAttribute("RockId", rId)
    rockModel:SetAttribute("RockState", "Carried")
    char:SetAttribute("CarriedRockId", rId)
    
    local sIdx = spotIndex or 1
    rockModel:SetAttribute("OriginSpotIndex", sIdx)
    rockModel:SetAttribute("OriginZoneId", rockType.Zone)
    char:SetAttribute("OriginSpotIndex", sIdx)
    char:SetAttribute("OriginZoneId", rockType.Zone)
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = torso
    weld.Part1 = rockModel.PrimaryPart
    weld.Parent = torso
    
    local pData = DataService.GetData(player)
    local trainedSpeed = pData and pData.Speed or 16
    local finalWeight = math.floor(rockType.BaseWeight * sizeData.WeightMult)
    local effectiveSpeed = math.max(6, trainedSpeed - finalWeight)
    hum.WalkSpeed = effectiveSpeed
    
    local eggName = EGG_NAME_MAP[rockType.Zone] or "Common Rock"
    char:SetAttribute("IsCarryingRock", true)
    char:SetAttribute("IsCarryingEgg", true)
    char:SetAttribute("CarryingZone", rockType.Zone)
    char:SetAttribute("CarriedEggName", eggName)
    char:SetAttribute("Slowdown", finalWeight)
    char:SetAttribute("CarryingZone", rockType.Zone)
    char:SetAttribute("CarriedEggName", eggName)
    
    local baseInc = math.floor(rockType.BaseIncome * sizeData.IncomeMult)
    local finalIncome = isGolden and (baseInc * 3) or baseInc
    
    playerCarrying[player] = {
        RockId = rId,
        RockType = rockType,
        SizeData = sizeData,
        Model = rockModel,
        Income = finalIncome,
        Weight = finalWeight,
        IsGolden = isGolden or false
    }
    
    local head = char:FindFirstChild("Head")
    if head then
        local prefix = isGolden and "👑 " or sizeData.Prefix
        ShowFloatingText(head, prefix .. rockType.Name .. " (-" .. finalWeight .. " Wgt)", isGolden and Color3.fromRGB(255, 215, 30) or sizeData.TitleColor)
    end
end

-- 7. DELIVER ROCK TO BASE (AUTOMATICALLY SENDS TO INCUBATOR OR STORAGE, ZERO DUPING!)
local function DeliverRockToBase(player, base, carryInfo)
    local rType = carryInfo.RockType
    local eggName = EGG_NAME_MAP[rType.Zone] or "Common Rock"
    local carriedRockId = carryInfo.RockId
    
    if carryInfo.Model then carryInfo.Model:Destroy() end
    playerCarrying[player] = nil
    
    local char = player.Character
    if char then
        char:SetAttribute("IsCarryingRock", false)
        char:SetAttribute("IsCarryingEgg", false)
        char:SetAttribute("CarriedEggName", nil)
        char:SetAttribute("CarryingZone", 0)
        char:SetAttribute("CarriedRockId", nil)
        if carriedRockId then
            char:SetAttribute("LastDeliveredRockId", carriedRockId)
        end
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            local pDataD = DataService.GetData(player)
            hum.WalkSpeed = pDataD and pDataD.Speed or 16
        end
    end
    
    -- Auto-incubate on empty pedestal slot
    local placedOnSlot = false
    local incubateFunc = ReplicatedStorage:FindFirstChild("IncubateEggFunction") :: BindableFunction?
    if incubateFunc then
        placedOnSlot = incubateFunc:Invoke(player, eggName)
    end
    
    if placedOnSlot then
        ShowFloatingText(char and char:FindFirstChild("Head"), "PLACED ON PEDESTAL! 🥚✨", Color3.fromRGB(80, 255, 120))
    else
        -- Pedestal slots full: Save to inventory storage
        DataService.AddEgg(player, {
            Id = HttpService:GenerateGUID(false),
            EggType = eggName,
            ZoneId = rType.Zone,
            AcquiredAt = os.time()
        })
        ShowFloatingText(char and char:FindFirstChild("Head"), "SLOTS FULL! SAVED TO STORAGE! 🎒", Color3.fromRGB(255, 200, 50))
    end
end

-- 8. STRICT BOUNDARY RETENTION FOR ROLLING PET ROCKS (NEVER LEAVES OWNER'S BASE)
task.spawn(function()
    while true do
        task.wait(2.2)
        
        for _, base in ipairs(bases:GetChildren()) do
            local rocksFolder = base:FindFirstChild("PetRocks")
            local floor = base:FindFirstChild("BaseFloor")
            
            if rocksFolder and floor then
                local bX = floor.Position.X
                local bZ = floor.Position.Z
                
                for _, rock in ipairs(rocksFolder:GetChildren()) do
                    local core = rock.PrimaryPart
                    if core and core:IsA("BasePart") and not core.Anchored then
                        local distX = core.Position.X - bX
                        local distZ = core.Position.Z - bZ
                        
                        -- If pushed near fence border, immediately nudge back towards yard center!
                        if math.abs(distX) > 22 or math.abs(distZ) > 22 then
                            local toCenter = Vector3.new(bX - core.Position.X, 2, bZ - core.Position.Z).Unit
                            core.AssemblyLinearVelocity = Vector3.new(toCenter.X * 16, 4, toCenter.Z * 16)
                            core.AssemblyAngularVelocity = Vector3.new(toCenter.Z * 3, 0, -toCenter.X * 3)
                        else
                            -- Gentle peaceful roll strictly within internal yard
                            local targetX = bX + math.random(-14, 14)
                            local targetZ = bZ + math.random(-14, 14)
                            local dir = (Vector3.new(targetX, core.Position.Y, targetZ) - core.Position).Unit
                            local hopY = (math.random(1, 4) == 1) and math.random(5, 9) or 0
                            
                            core.AssemblyLinearVelocity = Vector3.new(dir.X * 12, hopY, dir.Z * 12)
                            core.AssemblyAngularVelocity = Vector3.new(dir.Z * 2.5, 0, -dir.X * 2.5)
                        end
                    end
                end
            end
        end
    end
end)

-- 9. SPAWN 6 ROCKS IN EACH WILD BIOME NEST
local function SpawnZoneRocks()
    activeSpawns:ClearAllChildren()
    
    for zIdx = 1, 7 do
        local zModel = zones:FindFirstChild("Zone_" .. zIdx)
        if zModel then
            local rTypeId = zModel:GetAttribute("RockType")
            local rockType = RockConfig.ZoneTypes[rTypeId]
            local spots = zModel:FindFirstChild("SpawnSpots")
            
            if rockType and spots then
                for sIdx = 1, 6 do
                    local spot = spots:FindFirstChild("Spot_" .. sIdx)
                    if spot then
                        local sData = RockConfig.RollSize()
                        local targetCF = CFrame.new(spot.Position + Vector3.new(0, (rockType.BaseScale.Y * sData.ScaleMult)/2 + 0.8, 0))
                        local rockModel = CreateRockModel(rockType, sData, targetCF, false, false)
                        local rockId = "Rock_" .. HttpService:GenerateGUID(false):sub(1, 8)
                        rockModel.Name = "Spawned_" .. rockType.Id .. "_" .. sIdx
                        rockModel.PrimaryPart.Anchored = true
                        rockModel:SetAttribute("RockId", rockId)
                        rockModel:SetAttribute("RockState", "Spawned")
                        rockModel:SetAttribute("IsClaimed", false)
                        rockModel.Parent = activeSpawns
                        
                        local finalInc = math.floor(rockType.BaseIncome * sData.IncomeMult)
                        local finalWgt = math.floor(rockType.BaseWeight * sData.WeightMult)
                        rockModel:SetAttribute("Value", finalInc)
                        rockModel:SetAttribute("Weight", finalWgt)
                        
                        local pickPrompt = Instance.new("ProximityPrompt")
                        pickPrompt.Name = "PickPrompt"
                        pickPrompt.ActionText = "Grab"
                        pickPrompt.ObjectText = sData.Prefix .. rockType.Name .. " (+$" .. finalInc .. "/s)"
                        pickPrompt.HoldDuration = 0.5
                        pickPrompt.MaxActivationDistance = 9
                        pickPrompt.Parent = rockModel.PrimaryPart
                        
                        pickPrompt.Triggered:Connect(function(player)
                            -- 1. Atomic Claim Check (chống nhặt trùng 2 player trong cùng 1 frame)
                            if rockModel:GetAttribute("RockState") ~= "Spawned" or rockModel:GetAttribute("IsClaimed") == true then
                                return
                            end
                            rockModel:SetAttribute("IsClaimed", true)
                            rockModel:SetAttribute("RockState", "Claimed")
                            pickPrompt.Enabled = false
                            
                            -- 2. Kiểm tra trạng thái mang vác của player
                            if playerCarrying[player] then
                                rockModel:SetAttribute("IsClaimed", false)
                                rockModel:SetAttribute("RockState", "Spawned")
                                pickPrompt.Enabled = true
                                return
                            end
                            
                            local char = player.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if not char or not hrp or not hum or hum.Health <= 0 then
                                rockModel:SetAttribute("IsClaimed", false)
                                rockModel:SetAttribute("RockState", "Spawned")
                                pickPrompt.Enabled = true
                                return
                            end
                            
                            if char:GetAttribute("IsCarryingRock") or char:GetAttribute("IsCarryingEgg") then
                                rockModel:SetAttribute("IsClaimed", false)
                                rockModel:SetAttribute("RockState", "Spawned")
                                pickPrompt.Enabled = true
                                return
                            end
                            
                            -- 3. Kiểm tra khoảng cách chống exploit từ xa
                            local dist = (hrp.Position - rockModel.PrimaryPart.Position).Magnitude
                            if dist > (pickPrompt.MaxActivationDistance + 4) then
                                rockModel:SetAttribute("IsClaimed", false)
                                rockModel:SetAttribute("RockState", "Spawned")
                                pickPrompt.Enabled = true
                                return
                            end
                            
                            -- 4. Chuyển state sang Carried và gắn vào player
                            rockModel:SetAttribute("RockState", "Carried")
                            rockModel:Destroy()
                            AttachRockToPlayer(player, rockType, sData, false, sIdx, rockId)
                        end)
                    end
                end
            end
        end
    end
end

-- 10. RESET PLAYERS TO BASE AT END OF ROUND
local function ResetPlayersToBase()
    for _, player in ipairs(Players:GetPlayers()) do
        local base = BaseService.GetPlayerBase(player)
        local char = player.Character
        if base and char and char.PrimaryPart then
            if char.PrimaryPart.Position.Z > -5 then
                char:PivotTo(base.BaseFloor.CFrame + Vector3.new(0, 5, 0))
                
                if playerCarrying[player] and playerCarrying[player].Model then
                    playerCarrying[player].Model:Destroy()
                    playerCarrying[player] = nil
                    char:SetAttribute("IsCarryingRock", false)
                    char:SetAttribute("CarryingZone", 0)
                    if char:FindFirstChild("Humanoid") then
                        local pDataR = DataService.GetData(player)
                        char.Humanoid.WalkSpeed = pDataR and pDataR.Speed or 16
                    end
                end
                
                ShowFloatingText(char:FindFirstChild("Head"), "Round Over! ⛺", Color3.fromRGB(255, 100, 100))
            end
        end
    end
end

-- 11. TREADMILL UPGRADE HANDLED CENTRALLY BY BaseUpgradeService
-- (All 5 tiers, Speed caps, train rates, and 3D UI boards are managed in BaseUpgradeService)

-- 12. TREADMILL RUNNING & LOCK
local function GetRunAnimation(char)
    local animate = char:FindFirstChild("Animate")
    if animate then
        local runVal = animate:FindFirstChild("run")
        if runVal then
            local animObj = runVal:FindFirstChildOfClass("Animation")
            if animObj and animObj.AnimationId ~= "" then return animObj end
        end
    end
    local fallback = Instance.new("Animation")
    fallback.AnimationId = "rbxassetid://913376220"
    return fallback
end

local function ExitTreadmill(player)
    local info = playerOnTreadmill[player]
    if not info then return end
    
    local base = info.Base
    playerOnTreadmill[player] = nil
    playerTreadmillCooldown[player] = os.clock() + 6.0 -- 6.0s cooldown chống hút ngược tuyệt đối!
    
    if info.AnimTrack then
        pcall(function() info.AnimTrack:Stop(0.15); info.AnimTrack:Destroy() end)
    end
    if info.AlignPos then info.AlignPos:Destroy() end
    if info.AlignRot then info.AlignRot:Destroy() end
    if info.Attach0 then info.Attach0:Destroy() end
    
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local hrp = char.HumanoidRootPart
        local hum = char.Humanoid
        
        char:SetAttribute("OnTreadmill", false)
        
        -- Đặt người chơi ra PHÍA SAU máy chạy bộ hẳn 16 studs (ra tận bãi cỏ căn cứ)
        local tm = base and base:FindFirstChild("Treadmill")
        local lockPoint = tm and tm:FindFirstChild("LockPoint")
        if lockPoint then
            hrp.CFrame = lockPoint.CFrame * CFrame.new(0, 1.5, 16.0)
        else
            hrp.CFrame = hrp.CFrame * CFrame.new(0, 1.5, 16.0)
        end
        hrp.AssemblyLinearVelocity = Vector3.new(0, 18, 0)
        
        if playerCarrying[player] then
            local pDataE = DataService.GetData(player)
            local trained = pDataE and pDataE.Speed or 16
            hum.WalkSpeed = math.max(6, trained - playerCarrying[player].Weight)
        else
            local pDataE = DataService.GetData(player)
            hum.WalkSpeed = pDataE and pDataE.Speed or 16
        end
    end
end

local function EnterTreadmill(player, base)
    if playerOnTreadmill[player] then return end
    local char = player.Character
    if not char then return end
    
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    if isCarrying then
        ShowFloatingText(char:FindFirstChild("Head"), "CANNOT TRAIN WHILE CARRYING EGG! 🛑", Color3.fromRGB(255, 80, 80))
        return
    end
    if os.clock() < (playerTreadmillCooldown[player] or 0) then return end
    
    -- Kiểm tra nếu đã MAX TIER POINT CAP thì từ chối, không khóa người chơi vào máy!
    local pData = DataService.GetData(player)
    if pData then
        local tmLevel = pData.TreadmillLevel or 1
        local tmTierConfig = UpgradeConfig.TREADMILL_TIERS[tmLevel] or UpgradeConfig.TREADMILL_TIERS[1]
        local maxPoints = tmTierConfig.PointCap or 1000
        local curPoints = pData.SpeedPoints or 0
        if curPoints >= maxPoints then
            playerTreadmillCooldown[player] = os.clock() + 3.0
            ShowFloatingText(char:FindFirstChild("Head"), "TIER MAXED! UPGRADE BASE 🏆⚡", Color3.fromRGB(255, 215, 60))
            return
        end
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    
    local tm = base:FindFirstChild("Treadmill")
    local lockPoint = tm and tm:FindFirstChild("LockPoint")
    if not lockPoint then return end
    
    hrp.CFrame = lockPoint.CFrame
    hrp.AssemblyLinearVelocity = Vector3.zero
    char:SetAttribute("OnTreadmill", true)
    
    local att0 = Instance.new("Attachment")
    att0.Name = "TM_Attachment"
    att0.Parent = hrp
    
    local att1 = lockPoint:FindFirstChild("TM_LockAtt") or Instance.new("Attachment")
    att1.Name = "TM_LockAtt"
    att1.Parent = lockPoint
    
    local ap = Instance.new("AlignPosition")
    ap.Attachment0 = att0
    ap.Attachment1 = att1
    ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    -- Khóa chắc tại LockPoint khi đang luyện. Thoát máy được xử lý bởi JumpRequest / Jump Off,
    -- không dựa vào việc người chơi phải thắng lực physics.
    ap.MaxAxesForce = Vector3.new(100000, 100000, 100000)
    ap.Responsiveness = 200
    ap.Parent = hrp
    
    local ar = Instance.new("AlignOrientation")
    ar.Attachment0 = att0
    ar.Attachment1 = att1
    ar.MaxTorque = 100000
    ar.Responsiveness = 200
    ar.Parent = hrp
    
    local animator = hum:FindFirstChildOfClass("Animator") or hum
    local animTrack = nil
    pcall(function()
        animTrack = animator:LoadAnimation(GetRunAnimation(char))
        animTrack.Looped = true
        animTrack.Priority = Enum.AnimationPriority.Action
        animTrack:Play(0.1)
        animTrack:AdjustSpeed(1.4)
    end)
    
    playerOnTreadmill[player] = {
        Base = base,
        AlignPos = ap,
        AlignRot = ar,
        Attach0 = att0,
        AnimTrack = animTrack
    }
    print(string.format("[RGM] %s ENTERED TREADMILL ON BASE %s!", player.Name, base.Name))
end

_G.GetPlayerOnTreadmill = function()
    local list = {}
    for pl, _ in pairs(playerOnTreadmill) do
        table.insert(list, pl.Name)
    end
    return list
end
_G.ExitTreadmill = ExitTreadmill

-- Trigger server-authoritative theo vị trí HRP. Không phụ thuộc Touched nên chạy vào
-- TrainZone cũng nhận chắc chắn, kể cả phần va chạm client không phát event.
task.spawn(function()
    while true do
        task.wait(0.1)
        for i = 1, 6 do
            local base = bases:FindFirstChild("Base_" .. i)
            local tm = base and base:FindFirstChild("Treadmill")
            local zone = tm and tm:FindFirstChild("TrainZone")
            if not zone then continue end

            for _, player in ipairs(Players:GetPlayers()) do
                if playerOnTreadmill[player] then continue end
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then continue end

                -- Nới vừa đủ theo hitbox nhân vật; vẫn dùng không gian local của zone,
                -- nên không thể nhận máy từ ngoài nền hoặc từ treadmill base khác.
                local localPos = zone.CFrame:PointToObjectSpace(hrp.Position)
                local half = zone.Size * 0.5
                local insideTrainZone = math.abs(localPos.X) <= (half.X + 1.5)
                    and math.abs(localPos.Z) <= (half.Z + 1.5)
                    and math.abs(localPos.Y) <= (half.Y + 4.0)
                if not insideTrainZone then continue end

                local ownerId = base:GetAttribute("OwnerUserId")
                if ownerId == 0 or ownerId == nil then
                    BaseService.ClaimBase(player)
                    ownerId = base:GetAttribute("OwnerUserId")
                end
                if ownerId == player.UserId then
                    EnterTreadmill(player, base)
                end
            end
        end
    end
end)

-- 13. TREADMILL TICK
task.spawn(function()
    print("[RGM] Treadmill training loop running!")
    while true do
        task.wait(0.6)
        local ok, err = pcall(function()
            for player, info in pairs(playerOnTreadmill) do
                local char = player.Character
                if char and char:FindFirstChild("Head") and char:FindFirstChild("Humanoid") then
                    local pDataT = DataService.GetData(player)
                    if pDataT then
                        local tmLevel = pDataT.TreadmillLevel or 1
                        local tmTierConfig = UpgradeConfig.TREADMILL_TIERS[tmLevel] or UpgradeConfig.TREADMILL_TIERS[1]
                        local baseGain = tmTierConfig.TrainRate or 5
                        local maxPoints = tmTierConfig.PointCap or 1000
                        local curPoints = pDataT.SpeedPoints or 0
                        
                        -- Áp dụng Multiplier từ Trail đang trang bị
                        local TrailConfig = require(ReplicatedStorage:WaitForChild("TrailConfig"))
                        local trailMult = TrailConfig.GetMultiplier(pDataT.EquippedTrail)
                        local finalGain = math.max(1, math.floor(baseGain * trailMult))
                        
                        if curPoints < maxPoints then
                            local newPts, newRealSpd = DataService.AddSpeedPoints(player, finalGain)
                            local fmtGain = UpgradeConfig.FormatNumber(finalGain)
                            ShowFloatingText(char.Head, "+" .. fmtGain .. " ⚡ (" .. newRealSpd .. " Spd)", Color3.fromRGB(0, 230, 255))
                        else
                            ShowFloatingText(char.Head, "TIER " .. tmLevel .. " MAXED! UPGRADE BASE 🏆⚡", Color3.fromRGB(255, 215, 60))
                            ExitTreadmill(player)
                        end
                    end
                end
            end
        end)
        if not ok then
            warn("[RGM Treadmill Loop Error]:", err)
        end
    end
end)

-- 14. ROUND & INCOME TICK LOOP
local gateUI = gate.Arch_Top.TimerUI
local gateBarrier = gate.GateBarrier
SpawnZoneRocks()

task.spawn(function()
    while true do
        task.wait(1.0)
        
        if not isIntermission then
            timeLeft = timeLeft - 1
            local mins = math.floor(timeLeft / 60)
            local secs = timeLeft % 60
            
            -- DAY / NIGHT CYCLE (Steal An Egg standard: Last 90s of round is NIGHT with 5X Fast Hatch!)
            local isNight = (timeLeft <= 90)
            arena:SetAttribute("IsNightTime", isNight)
            
            local Lighting = game:GetService("Lighting")
            if isNight then
                Lighting.ClockTime = 0
                Lighting.OutdoorAmbient = Color3.fromRGB(60, 45, 110)
                gateUI.RoundStatus.Text = "🌙 NIGHT TIME (5X HATCH) ⚡"
                gateUI.RoundStatus.TextColor3 = Color3.fromRGB(180, 100, 255)
            else
                Lighting.ClockTime = 14.5
                Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 135)
                gateUI.RoundStatus.Text = "🚨 ROUND ACTIVE 🚨"
                gateUI.RoundStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
            
            gateUI.TimeLeft.Text = string.format("%02d:%02d", mins, secs)
            gateUI.TimeLeft.TextColor3 = Color3.fromRGB(255, 220, 50)
            gateBarrier.CanCollide = false
            gateBarrier.Transparency = 0.85
            
            if timeLeft <= 0 then
                isIntermission = true
                timeLeft = INTERMISSION_DURATION
                ResetPlayersToBase()
                gateBarrier.CanCollide = true
                gateBarrier.Transparency = 0.3
            end
        else
            timeLeft = timeLeft - 1
            gateUI.RoundStatus.Text = "⛔ ROUND OVER ⛔"
            gateUI.RoundStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
            gateUI.TimeLeft.Text = string.format("NEW IN: %02ds", timeLeft)
            gateUI.TimeLeft.TextColor3 = Color3.fromRGB(255, 100, 100)
            gateBarrier.CanCollide = true
            gateBarrier.Transparency = 0.3
            
            if timeLeft <= 0 then
                isIntermission = false
                timeLeft = ROUND_DURATION
                SpawnZoneRocks()
                gateBarrier.CanCollide = false
                gateBarrier.Transparency = 0.85
            end
        end
        
        -- Pet income is centrally awarded by BaseUpgradeService with Gamepass multipliers
        
        for player, _ in pairs(playerCarrying) do
            local char = player.Character
            if not char or (char:GetAttribute("IsCarryingRock") ~= true and char:GetAttribute("IsCarryingEgg") ~= true) then
                playerCarrying[player] = nil
            end
        end
    end
end)

-- 15. HOOK JUMP
local function HookCharacter(player, char)
    local hum = char:WaitForChild("Humanoid")
    hum.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            if playerOnTreadmill[player] then
                ExitTreadmill(player)
            end
        end
    end)

    -- FALLBACK: Detect jump INPUT even when physics constraints block the actual jump state
    hum:GetPropertyChangedSignal("Jump"):Connect(function()
        if hum.Jump and playerOnTreadmill[player] then
            ExitTreadmill(player)
        end
    end)
    
    hum.Died:Connect(function()
        ExitTreadmill(player)
        if playerCarrying[player] then
            if playerCarrying[player].Model and playerCarrying[player].Model.Parent == char then
                playerCarrying[player].Model:Destroy()
            end
            playerCarrying[player] = nil
            char:SetAttribute("IsCarryingRock", false)
            char:SetAttribute("CarryingZone", 0)
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    SetupLeaderstats(player)
    player.CharacterAdded:Connect(function(char)
        playerOnTreadmill[player] = nil
        char:SetAttribute("OnTreadmill", false)
        task.wait(0.5)
        HookCharacter(player, char)
        local base = BaseService.GetOrClaimBase(player)
        if base and char.PrimaryPart then
            char:PivotTo(base.BaseFloor.CFrame + Vector3.new(0, 5, 0))
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    playerOnTreadmill[player] = nil
    playerTreadmillCooldown[player] = nil
    playerCarrying[player] = nil
    ReleaseBase(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    SetupLeaderstats(player)
    ClaimBase(player)
    if player.Character then
        HookCharacter(player, player.Character)
    end
end
