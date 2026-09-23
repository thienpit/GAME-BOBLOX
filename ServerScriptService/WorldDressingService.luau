--!strict
--[[
    SCRIPT: WorldDressingService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> WorldDressingService
    DESCRIPTION: World dressing props & biome atmosphere decor for Arena_Map.
                 Includes 4 Biome dressing & Base Private Yard fencing and canopies.
                 All props use 'Deco_' prefix and CanCollide = false to never block gameplay.
]]

local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

local function BuildWorldDressing()
    -- Idempotent: remove old deco folder if exists
    local oldFolder = arena:FindFirstChild("Deco_Props")
    if oldFolder then oldFolder:Destroy() end

    local decoFolder = Instance.new("Folder")
    decoFolder.Name = "Deco_Props"
    decoFolder.Parent = arena

    -- Helper to create stylized cartoon bush
    local function CreateBush(pos: Vector3, scale: number, color: Color3)
        local m = Instance.new("Model")
        m.Name = "Deco_Bush"
        
        local main = Instance.new("Part")
        main.Name = "Deco_BushCore"
        main.Shape = Enum.PartType.Ball
        main.Size = Vector3.new(4, 3.2, 4) * scale
        main.CFrame = CFrame.new(pos)
        main.Material = Enum.Material.Grass
        main.Color = color
        main.Anchored = true
        main.CanCollide = false
        main.CastShadow = true
        main.Parent = m
        m.PrimaryPart = main

        local sub1 = Instance.new("Part")
        sub1.Name = "Deco_BushSide1"
        sub1.Shape = Enum.PartType.Ball
        sub1.Size = Vector3.new(2.8, 2.5, 2.8) * scale
        sub1.CFrame = CFrame.new(pos + Vector3.new(-1.4 * scale, -0.4 * scale, 0.6 * scale))
        sub1.Material = Enum.Material.Grass
        sub1.Color = color:Lerp(Color3.fromRGB(40, 110, 40), 0.2)
        sub1.Anchored = true
        sub1.CanCollide = false
        sub1.Parent = m

        local sub2 = Instance.new("Part")
        sub2.Name = "Deco_BushSide2"
        sub2.Shape = Enum.PartType.Ball
        sub2.Size = Vector3.new(3, 2.6, 3) * scale
        sub2.CFrame = CFrame.new(pos + Vector3.new(1.3 * scale, -0.3 * scale, -0.5 * scale))
        sub2.Material = Enum.Material.Grass
        sub2.Color = color:Lerp(Color3.fromRGB(90, 180, 80), 0.15)
        sub2.Anchored = true
        sub2.CanCollide = false
        sub2.Parent = m

        m.Parent = decoFolder
        return m
    end

    -- Helper to create cute cartoon lantern
    local function CreateLantern(pos: Vector3, lightColor: Color3)
        local m = Instance.new("Model")
        m.Name = "Deco_LanternPost"

        local post = Instance.new("Part")
        post.Name = "Deco_WoodPost"
        post.Size = Vector3.new(0.8, 7, 0.8)
        post.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
        post.Material = Enum.Material.WoodPlanks
        post.Color = Color3.fromRGB(115, 80, 50)
        post.Anchored = true
        post.CanCollide = false
        post.Parent = m
        m.PrimaryPart = post

        local arm = Instance.new("Part")
        arm.Name = "Deco_LanternArm"
        arm.Size = Vector3.new(1.8, 0.6, 0.6)
        arm.CFrame = CFrame.new(pos + Vector3.new(0.6, 6.6, 0))
        arm.Material = Enum.Material.WoodPlanks
        arm.Color = Color3.fromRGB(95, 65, 40)
        arm.Anchored = true
        arm.CanCollide = false
        arm.Parent = m

        local lamp = Instance.new("Part")
        lamp.Name = "Deco_LampGlass"
        lamp.Shape = Enum.PartType.Ball
        lamp.Size = Vector3.new(1.4, 1.8, 1.4)
        lamp.CFrame = CFrame.new(pos + Vector3.new(1.2, 5.5, 0))
        lamp.Material = Enum.Material.Neon
        lamp.Color = lightColor
        lamp.Anchored = true
        lamp.CanCollide = false
        lamp.Parent = m

        local pl = Instance.new("PointLight")
        pl.Color = lightColor
        pl.Brightness = 1.6
        pl.Range = 16
        pl.Parent = lamp

        m.Parent = decoFolder
        return m
    end

    -- Helper to create glowing biome crystals
    local function CreateCrystalCluster(pos: Vector3, crystalColor: Color3, scale: number)
        local m = Instance.new("Model")
        m.Name = "Deco_CrystalCluster"

        local base = Instance.new("Part")
        base.Name = "Deco_CrystalBase"
        base.Size = Vector3.new(3, 1, 3) * scale
        base.CFrame = CFrame.new(pos)
        base.Material = Enum.Material.Basalt
        base.Color = Color3.fromRGB(35, 30, 42)
        base.Anchored = true
        base.CanCollide = false
        base.Parent = m
        m.PrimaryPart = base

        for i = 1, 3 do
            local spike = Instance.new("Part")
            spike.Name = "Deco_CrystalShard_" .. i
            spike.Size = Vector3.new(1.2, 4 + i * 1.5, 1.2) * scale
            local angle = (i - 2) * 22
            spike.CFrame = CFrame.new(pos + Vector3.new((i - 2) * 1.2 * scale, (2 + i * 0.7) * scale, 0)) * CFrame.Angles(0, 0, math.rad(angle))
            spike.Material = Enum.Material.Neon
            spike.Color = crystalColor
            spike.Anchored = true
            spike.CanCollide = false
            spike.Parent = m
        end

        local pl = Instance.new("PointLight")
        pl.Color = crystalColor
        pl.Brightness = 1.8
        pl.Range = 18 * scale
        pl.Parent = base

        m.Parent = decoFolder
        return m
    end

    -- Helper to create Base Private Yard Fences & Archway
    local function DecorateBaseYard(baseModel: Model)
        local bFloor = baseModel:FindFirstChild("BaseFloor") :: BasePart?
        if not bFloor then return end
        local bX = bFloor.Position.X
        local bZ = bFloor.Position.Z
        local isLeft = bX < 0
        local entranceX = isLeft and (bX + 28) or (bX - 28)

        -- 1. Base Entry Archway (Cổng chào sân vườn)
        local arch = Instance.new("Model")
        arch.Name = "Deco_YardArch"
        
        local pL = Instance.new("Part")
        pL.Name = "Deco_ArchPillarLeft"
        pL.Size = Vector3.new(1.2, 7.5, 1.2)
        pL.CFrame = CFrame.new(entranceX, 3.75, bZ - 5)
        pL.Material = Enum.Material.WoodPlanks
        pL.Color = Color3.fromRGB(120, 85, 55)
        pL.Anchored = true; pL.CanCollide = false
        pL.Parent = arch

        local pR = Instance.new("Part")
        pR.Name = "Deco_ArchPillarRight"
        pR.Size = Vector3.new(1.2, 7.5, 1.2)
        pR.CFrame = CFrame.new(entranceX, 3.75, bZ + 5)
        pR.Material = Enum.Material.WoodPlanks
        pR.Color = Color3.fromRGB(120, 85, 55)
        pR.Anchored = true; pR.CanCollide = false
        pR.Parent = arch

        local topBeam = Instance.new("Part")
        topBeam.Name = "Deco_ArchBeam"
        topBeam.Size = Vector3.new(1.4, 1.0, 12)
        topBeam.CFrame = CFrame.new(entranceX, 7.8, bZ)
        topBeam.Material = Enum.Material.WoodPlanks
        topBeam.Color = Color3.fromRGB(140, 95, 60)
        topBeam.Anchored = true; topBeam.CanCollide = false
        topBeam.Parent = arch

        local archLantern = Instance.new("Part")
        archLantern.Name = "Deco_ArchLantern"
        archLantern.Shape = Enum.PartType.Ball
        archLantern.Size = Vector3.new(1.4, 1.4, 1.4)
        archLantern.CFrame = CFrame.new(entranceX, 6.6, bZ)
        archLantern.Material = Enum.Material.Neon
        archLantern.Color = Color3.fromRGB(255, 220, 110)
        archLantern.Anchored = true; archLantern.CanCollide = false
        archLantern.Parent = arch

        local archLight = Instance.new("PointLight")
        archLight.Color = Color3.fromRGB(255, 220, 110)
        archLight.Brightness = 1.8
        archLight.Range = 16
        archLight.Parent = archLantern

        arch.Parent = decoFolder

        -- 2. Mini Dojo Canopy over Treadmill (Mái che khu luyện tốc độ)
        local tm = baseModel:FindFirstChild("Treadmill") :: Model?
        local lockPoint = tm and tm:FindFirstChild("LockPoint") :: BasePart?
        if lockPoint then
            local tmPos = lockPoint.Position
            local canopy = Instance.new("Model")
            canopy.Name = "Deco_TreadmillCanopy"

            local roof = Instance.new("Part")
            roof.Name = "Deco_CanopyRoof"
            roof.Size = Vector3.new(10, 0.8, 12)
            roof.CFrame = CFrame.new(tmPos.X, tmPos.Y + 9, tmPos.Z)
            roof.Material = Enum.Material.WoodPlanks
            roof.Color = Color3.fromRGB(180, 50, 45) -- Mái ngói đỏ Nhật Bản / Dojo
            roof.Anchored = true; roof.CanCollide = false
            roof.Parent = canopy

            local lantern = Instance.new("Part")
            lantern.Name = "Deco_CanopyLantern"
            lantern.Shape = Enum.PartType.Ball
            lantern.Size = Vector3.new(1.2, 1.2, 1.2)
            lantern.CFrame = CFrame.new(tmPos.X, tmPos.Y + 7.8, tmPos.Z)
            lantern.Material = Enum.Material.Neon
            lantern.Color = Color3.fromRGB(255, 200, 80)
            lantern.Anchored = true; lantern.CanCollide = false
            lantern.Parent = canopy

            local cLight = Instance.new("PointLight")
            cLight.Color = Color3.fromRGB(255, 200, 80)
            cLight.Brightness = 1.4
            cLight.Range = 14
            cLight.Parent = lantern

            canopy.Parent = decoFolder
        end
    end

    -- 1. BASE / VILLAGE WALKWAY DRESSING
    for z = -280, -30, 45 do
        CreateLantern(Vector3.new(-24, 0.5, z), Color3.fromRGB(255, 215, 130))
        CreateBush(Vector3.new(-26, 0.5, z + 12), 1.1, Color3.fromRGB(75, 155, 65))
        CreateLantern(Vector3.new(24, 0.5, z), Color3.fromRGB(255, 215, 130))
        CreateBush(Vector3.new(26, 0.5, z - 12), 1.2, Color3.fromRGB(85, 170, 75))
    end

    -- 2. BASE PRIVATE YARD DECORATION (FOR ALL 6 BASES)
    for i = 1, 6 do
        local b = bases:FindFirstChild("Base_" .. i)
        if b and b:IsA("Model") then
            DecorateBaseYard(b)
        end
    end

    -- 3. ZONE 1: MOSSY FOREST DRESSING
    for z = 15, 65, 25 do
        CreateBush(Vector3.new(-45, 1, z), 1.5, Color3.fromRGB(60, 140, 55))
        CreateBush(Vector3.new(45, 1, z), 1.6, Color3.fromRGB(70, 160, 65))
        CreateLantern(Vector3.new(-44, 1, z + 12), Color3.fromRGB(150, 255, 140))
        CreateLantern(Vector3.new(44, 1, z + 12), Color3.fromRGB(150, 255, 140))
    end

    -- 4. ZONE 2: OBSIDIAN CAVERN DRESSING
    for z = 90, 170, 35 do
        CreateCrystalCluster(Vector3.new(-45, 1, z), Color3.fromRGB(180, 80, 255), 1.2)
        CreateCrystalCluster(Vector3.new(45, 1, z), Color3.fromRGB(200, 100, 255), 1.1)
    end

    -- 5. ZONE 3: MAGMA CORE DRESSING
    for z = 205, 315, 40 do
        CreateCrystalCluster(Vector3.new(-45, 1, z), Color3.fromRGB(255, 75, 20), 1.3)
        CreateCrystalCluster(Vector3.new(45, 1, z), Color3.fromRGB(255, 120, 30), 1.2)
    end

    -- 6. ZONE 4: CELESTIAL METEOR DRESSING
    for z = 360, 470, 40 do
        CreateCrystalCluster(Vector3.new(-45, 1, z), Color3.fromRGB(255, 215, 50), 1.5)
        CreateCrystalCluster(Vector3.new(45, 1, z), Color3.fromRGB(0, 225, 255), 1.4)
    end

    print(string.format("[WorldDressingService] ✅ Generated %d decorative props with 'Deco_' prefix safely!", #decoFolder:GetChildren()))
end

BuildWorldDressing()
