--!strict
--[[
    TÊN SCRIPT: StealZoneService
    LOẠI: Script (Server-side)
    VỊ TRÍ: ServerScriptService -> StealZoneService
    MÔ TẢ: Quản lý khu vực tranh trứng chung (StealZone), spawn trứng ngẫu nhiên,
          khóa tranh chấp chống nhặt trùng (Atomic Claim Lock), giảm tốc độ,
          bảo vệ Safe Zone căn cứ và cơ chế rơi trứng khi chết (3s immunity / 60s despawn).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local StealZoneConfig = require(ReplicatedStorage:WaitForChild("StealZoneConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local stealRemote = ReplicatedStorage:WaitForChild("StealZoneRemote") :: RemoteEvent
local bountyRemote = ReplicatedStorage:WaitForChild("BountyAlertRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")
local stealZoneModel = arena:WaitForChild("StealZone")
local activeEggsFolder = stealZoneModel:WaitForChild("ActiveEggs")
local bases = arena:WaitForChild("Bases")

type CarryRecord = {
    EggName: string,
    EggModel: Model,
    Slowdown: number,
    Weld: WeldConstraint?
}

local carryingPlayers: { [Player]: CarryRecord } = {}
local rng = Random.new()

-- Floating text above character head
local function ShowFloatingText(head: BasePart?, text: string, color: Color3)
    if not head then return end
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
    
    task.spawn(function()
        for step = 1, 25 do
            task.wait(0.04)
            bb.StudsOffset = bb.StudsOffset + Vector3.new(0, 0.12, 0)
            tl.TextTransparency = step / 25
        end
        bb:Destroy()
    end)
end

-- =============================================================================
-- 1. HÀM TẠO MODEL TRỨNG 3D VẬT LÝ VÀ CỘT SÁNG BEAM
-- =============================================================================
local function CreateWorldEgg(eggName: string, spawnCF: CFrame, isRare: boolean, beamColor: Color3): Model
    local model = Instance.new("Model")
    model.Name = "Egg_" .. string.gsub(eggName, " ", "") .. "_" .. HttpService:GenerateGUID(false):sub(1, 6)
    model:SetAttribute("EggName", eggName)
    model:SetAttribute("IsClaimed", false)
    model:SetAttribute("IsRare", isRare)
    
    local core = Instance.new("Part")
    core.Name = "EggCore"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(2.8, 3.8, 2.8)
    core.CFrame = spawnCF
    core.Anchored = true
    core.CanCollide = false
    
    -- Màu sắc & vật liệu
    if eggName == "Mossy Stone" then
        core.Material = Enum.Material.Grass; core.Color = Color3.fromRGB(75, 145, 65)
    elseif eggName == "Obsidian Geode" then
        core.Material = Enum.Material.Basalt; core.Color = Color3.fromRGB(35, 25, 45)
    elseif eggName == "Magma Core" then
        core.Material = Enum.Material.CrackedLava; core.Color = Color3.fromRGB(255, 65, 20)
    elseif eggName == "Celestial Meteor" then
        core.Material = Enum.Material.Marble; core.Color = Color3.fromRGB(255, 215, 60)
    elseif eggName == "Abyssal Void" then
        core.Material = Enum.Material.Neon; core.Color = Color3.fromRGB(130, 40, 255)
    else
        core.Material = Enum.Material.Slate; core.Color = Color3.fromRGB(160, 160, 160)
    end
    
    core.Parent = model
    model.PrimaryPart = core
    
    -- Cột sáng Neon (Beam / Light Pillar) cho trứng hiếm (Celestial / Void)
    if isRare then
        local pillar = Instance.new("Part")
        pillar.Name = "RareLightPillar"
        pillar.Shape = Enum.PartType.Cylinder
        pillar.Size = Vector3.new(100, 1.2, 1.2)
        pillar.CFrame = spawnCF * CFrame.new(0, 50, 0) * CFrame.Angles(0, 0, math.rad(90))
        pillar.Material = Enum.Material.Neon
        pillar.Color = beamColor
        pillar.Transparency = 0.4
        pillar.Anchored = true
        pillar.CanCollide = false
        pillar.CanQuery = false
        pillar.CanTouch = false
        pillar.Parent = model
        
        local pLight = Instance.new("PointLight")
        pLight.Color = beamColor
        pLight.Brightness = 2.0
        pLight.Range = 25
        pLight.Parent = core
    end
    
    return model
end

-- =============================================================================
-- 2. HÀM THẢ TRỨNG RƠI KHI CHẾT / THOÁT GAME (3S IMMUNITY + 60S DESPAWN)
-- =============================================================================
local function DropEggOnGround(position: Vector3, eggName: string)
    local eggConf = StealZoneConfig.GetEggConfig(eggName)
    local isRare = eggConf and eggConf.IsRare or false
    local bColor = eggConf and eggConf.BeamColor or Color3.fromRGB(255, 255, 255)
    
    local dropCF = CFrame.new(position.X, 2.4, position.Z)
    local droppedEgg = CreateWorldEgg(eggName, dropCF, isRare, bColor)
    droppedEgg.Parent = activeEggsFolder
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PickupPrompt"
    prompt.ActionText = "Steal Dropped Egg 🥚"
    prompt.ObjectText = eggName
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Enabled = false -- 3s Immunity (Không nhặt lại được ngay)
    prompt.Parent = droppedEgg.PrimaryPart
    
    -- Sau 3 giây mới mở khóa cho người khác nhặt
    task.delay(StealZoneConfig.PICKUP_IMMUNITY_TIME, function()
        if prompt and prompt.Parent then
            prompt.Enabled = true
        end
    end)
    
    -- Tự động dọn dẹp biến mất sau 60 giây nếu không ai nhặt
    task.delay(StealZoneConfig.DESPAWN_TIME, function()
        if droppedEgg and droppedEgg.Parent and not droppedEgg:GetAttribute("IsClaimed") then
            droppedEgg:Destroy()
        end
    end)
    
    -- Hook nhặt
    prompt.Triggered:Connect(function(player)
        OnEggTriggered(player, droppedEgg, eggName, eggConf and eggConf.Slowdown or 4)
    end)
end

-- =============================================================================
-- 3. XỬ LÝ NHẶT TRỨNG: ATOMIC CLAIM CHECK (CHỐNG NHẶT TRÙNG TUYỆT ĐỐI)
-- =============================================================================
function OnEggTriggered(player: Player, eggModel: Model, eggName: string, slowdown: number)
    -- 1. KIỂM TRA KHÓA TRANH CHẤP NGUYÊN TỬ (ATOMIC CLAIM LOCK)
    if eggModel:GetAttribute("IsClaimed") == true then
        return -- Người khác đã nhặt trước dù chỉ nhanh hơn 1 mili-giây!
    end
    eggModel:SetAttribute("IsClaimed", true)
    
    local prompt = eggModel.PrimaryPart and eggModel.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
    if prompt then prompt.Enabled = false end
    
    -- 2. Kiểm tra người chơi có đang cầm trứng khác không
    if carryingPlayers[player] ~= nil then
        eggModel:SetAttribute("IsClaimed", false)
        if prompt then prompt.Enabled = true end
        return
    end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
    
    if not hrp or not hum or not torso or hum.Health <= 0 then
        eggModel:SetAttribute("IsClaimed", false)
        if prompt then prompt.Enabled = true end
        return
    end
    
    -- 3. Kiểm tra khoảng cách chống exploit từ xa
    local dist = (hrp.Position - eggModel.PrimaryPart.Position).Magnitude
    if dist > (StealZoneConfig.MAX_PICKUP_DISTANCE + 4) then
        eggModel:SetAttribute("IsClaimed", false)
        if prompt then prompt.Enabled = true end
        return
    end
    
    -- 4. Gắn trứng lên người nhân vật
    local pillar = eggModel:FindFirstChild("RareLightPillar")
    if pillar then pillar:Destroy() end
    if prompt then prompt:Destroy() end
    
    eggModel.PrimaryPart.Anchored = false
    eggModel.PrimaryPart.CanCollide = false
    eggModel.PrimaryPart.CFrame = torso.CFrame * CFrame.new(0, -0.2, -1.8) * CFrame.Angles(math.rad(-8), 0, 0)
    eggModel.Parent = char
    eggModel:SetAttribute("IsCarriedItem", true)
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = torso
    weld.Part1 = eggModel.PrimaryPart
    weld.Parent = torso
    
    -- 5. Áp dụng giảm tốc độ chạy theo Config
    local pData = DataService.GetData(player)
    local currentSpeed = pData and pData.Speed or 16
    local finalSpeed = math.max(StealZoneConfig.MIN_CARRY_SPEED, currentSpeed - slowdown)
    hum.WalkSpeed = finalSpeed
    
    char:SetAttribute("IsCarryingEgg", true)
    char:SetAttribute("CarriedEggName", eggName)
    char:SetAttribute("Slowdown", slowdown)
    
    carryingPlayers[player] = {
        EggName = eggName,
        EggModel = eggModel,
        Slowdown = slowdown,
        Weld = weld
    }
    
        -- TICKET-W4-01: BOUNTY ESCAPE ALARM & BEACON FOR RARE/LEGENDARY EGGS
    if isRare or eggName == "Celestial Meteor" or eggName == "Abyssal Void" then
        local oldBeacon = char:FindFirstChild("Deco_BountyBeacon")
        if oldBeacon then oldBeacon:Destroy() end

        local beacon = Instance.new("Model")
        beacon.Name = "Deco_BountyBeacon"

        local beamPart = Instance.new("Part")
        beamPart.Name = "Deco_BeamColumn"
        beamPart.Shape = Enum.PartType.Cylinder
        beamPart.Size = Vector3.new(180, 2.0, 2.0)
        beamPart.CFrame = torso.CFrame * CFrame.new(0, 90, 0) * CFrame.Angles(0, 0, math.rad(90))
        beamPart.Material = Enum.Material.Neon
        beamPart.Color = eggName == "Abyssal Void" and Color3.fromRGB(180, 40, 255) or Color3.fromRGB(255, 215, 40)
        beamPart.Transparency = 0.3
        beamPart.CanCollide = false
        beamPart.CanTouch = false
        beamPart.CanQuery = false
        beamPart.Massless = true
        beamPart.Parent = beacon

        local bWeld = Instance.new("WeldConstraint")
        bWeld.Part0 = torso
        bWeld.Part1 = beamPart
        bWeld.Parent = beamPart

        beacon.Parent = char

        bountyRemote:FireAllClients({
            playerName = player.DisplayName,
            eggTier = eggName,
            position = hrp.Position
        })
        print(string.format("🚨 [BOUNTY ALERT] %s picked up rare '%s'! Beacon active!", player.Name, eggName))
    end

    -- Bắn tín hiệu sang Client hiển thị UI "RETURN TO BASE!"
    stealRemote:FireClient(player, "StartCarrying", eggName, slowdown)
end

-- =============================================================================
-- 4. SPAWN TRỨNG ĐỊNH KỲ THEO TỈ LỆ CONFIG TRONG STEAL ZONE
-- =============================================================================
local function RollEggFromTable(): (string, boolean, Color3, number)
    local totalWeight = 0
    for _, item in ipairs(StealZoneConfig.SPAWN_TABLE) do
        totalWeight = totalWeight + item.Weight
    end
    
    local roll = rng:NextNumber(0, totalWeight)
    local current = 0
    for _, item in ipairs(StealZoneConfig.SPAWN_TABLE) do
        current = current + item.Weight
        if roll <= current then
            return item.EggName, item.IsRare, item.BeamColor, item.Slowdown
        end
    end
    
    local fallback = StealZoneConfig.SPAWN_TABLE[1]
    return fallback.EggName, fallback.IsRare, fallback.BeamColor, fallback.Slowdown
end

task.spawn(function()
    while true do
        local waitSecs = rng:NextInteger(StealZoneConfig.SPAWN_INTERVAL_MIN, StealZoneConfig.SPAWN_INTERVAL_MAX)
        task.wait(waitSecs)
        
        local currentCount = #activeEggsFolder:GetChildren()
        if currentCount < StealZoneConfig.MAX_ACTIVE_EGGS then
            local eggName, isRare, beamColor, slowdown = RollEggFromTable()
            
            -- Tọa độ ngẫu nhiên bên trong ranh giới StealZone (X: -36 đến 36, Z: 45 đến 165)
            local randX = rng:NextInteger(-36, 36)
            local randZ = rng:NextInteger(45, 165)
            local spawnCF = CFrame.new(randX, 2.4, randZ)
            
            local newEgg = CreateWorldEgg(eggName, spawnCF, isRare, beamColor)
            newEgg.Parent = activeEggsFolder
            
            local prompt = Instance.new("ProximityPrompt")
            prompt.Name = "PickupPrompt"
            prompt.ActionText = "Steal Egg 🥚"
            prompt.ObjectText = eggName
            prompt.HoldDuration = 0.5
            prompt.MaxActivationDistance = 14
            prompt.RequiresLineOfSight = false
            prompt.Parent = newEgg.PrimaryPart
            
            prompt.Triggered:Connect(function(player)
                OnEggTriggered(player, newEgg, eggName, slowdown)
            end)
            
            -- Nếu là trứng cực hiếm (Celestial Meteor / Abyssal Void) -> Phát loa toàn server!
            if isRare then
                for _, p in ipairs(Players:GetPlayers()) do
                    stealRemote:FireClient(p, "RareSpawnAlert", eggName, beamColor)
                end
                print(string.format("⚡ [StealZone] ULTRA RARE '%s' SPAWNED IN STEAL ZONE!", eggName))
            end
        end
    end
end)

-- =============================================================================
-- 5. TRẢ TRỨNG VỀ CĂN CỨ (DROP OFF) & GIÁM SÁT SAFE ZONE
-- =============================================================================
-- GUARANTEED BASE FINDER (VIA BASESERVICE)
local function GetPlayerBase(player: Player): Model?
    return BaseService.GetOrClaimBase(player)
end

-- Vòng lặp giám sát SafeZone và tự động chuyển trứng vào slot khi về nhà
task.spawn(function()
    while true do
        task.wait(0.5)
        
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum then
                local base = GetPlayerBase(player)
                local isInsideMyBase = false
                
                -- VÙNG AN TOÀN: Toàn bộ khu vực căn cứ & đường băng sau cổng RunwayGate (Z <= -5) là vùng an toàn!
                local isSafeZone = (hrp.Position.Z <= -5)
                char:SetAttribute("InSafeZone", isSafeZone)
                
                if base then
                    local bFloor = base:FindFirstChild("BaseFloor") :: BasePart?
                    if bFloor then
                        local dist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(bFloor.Position.X, 0, bFloor.Position.Z)).Magnitude
                        if dist <= 52 then
                            isInsideMyBase = true
                        end
                    end
                end
                
                -- LOGIC VÙNG AN TOÀN: BỎ SLOW SPEED KHI VÀO VÙNG AN TOÀN (Z <= -5)
                local isCarryingAttr = char:GetAttribute("IsCarryingEgg") == true or char:GetAttribute("IsCarryingRock") == true
                local pData = DataService.GetData(player)
                if hum and pData then
                    if isSafeZone then
                        hum.WalkSpeed = pData.Speed -- Khôi phục 100% tốc độ chạy bình thường trong vùng an toàn!
                    else
                        if isCarryingAttr then
                            local slowdown = char:GetAttribute("Slowdown") or 4
                            hum.WalkSpeed = math.max(6, pData.Speed - slowdown)
                        else
                            hum.WalkSpeed = pData.Speed
                        end
                    end
                end
                
                -- KIỂM TRA TRẢ TRỨNG KHI BƯỚC VÀO CĂN CỨ (DROP-OFF DUY NHẤT TOÀN GAME)
                local carry = carryingPlayers[player]
                local isCarryingAttr = char:GetAttribute("IsCarryingEgg") == true or char:GetAttribute("IsCarryingRock") == true
                
                if (carry or isCarryingAttr) and isInsideMyBase then
                    local eggName = (carry and carry.EggName) or char:GetAttribute("CarriedEggName") or "Common Rock"
                    local carryZone = char:GetAttribute("CarryingZone") or 1
                    
                    -- Đặt trứng tự do trên bãi cỏ Pen (Có giới hạn số lượng giống Steal a Pet)
                    local placedInPen = false
                    local incubateFunc = game:GetService("ReplicatedStorage"):FindFirstChild("IncubateEggFunction") :: BindableFunction?
                    if incubateFunc then
                        placedInPen = incubateFunc:Invoke(player, eggName, hrp.Position)
                    end
                    
                    if placedInPen then
                        -- Đặt thành công lên bãi cỏ: Xóa model trên người
                        if carry and carry.EggModel then carry.EggModel:Destroy() end
                        if carry and carry.Weld then carry.Weld:Destroy() end
                        carryingPlayers[player] = nil
                        
                        for _, child in ipairs(char:GetChildren()) do
                            if child:IsA("Model") and child:GetAttribute("IsCarriedItem") == true then
                                child:Destroy()
                            end
                        end
                        
                        char:SetAttribute("IsCarryingEgg", false)
                        char:SetAttribute("IsCarryingRock", false)
                        char:SetAttribute("CarriedEggName", nil)
                        char:SetAttribute("CarryingZone", 0)
                        
                        local pData = DataService.GetData(player)
                        if hum and pData then
                            hum.WalkSpeed = pData.Speed
                        end
                        
                        stealRemote:FireClient(player, "StopCarrying")
                        print(string.format("[StealZone] %s placed '%s' freely in Pen!", player.Name, eggName))
                    else
                        -- Chuồng đầy: GIỮ NGUYÊN TRỨNG TRÊN TAY, TUYỆT ĐỐI KHÔNG XÓA MẤT!
                        -- Thông báo "PEN FULL! UPGRADE PEN!" đã được HatchService hiện trên đầu.
                    end
                end
            end
        end
    end
end)

-- =============================================================================
-- 6. DỌN DẸP SẠCH TRỨNG KHI NGƯỜI CHƠI RỜI GAME HOẶC CHẾT
-- =============================================================================
local function HookPlayerDeath(player: Player, char: Model)
    local hum = char:WaitForChild("Humanoid") :: Humanoid
    hum.Died:Connect(function()
        local carry = carryingPlayers[player]
        if carry then
            local dropPos = char.PrimaryPart and char.PrimaryPart.Position or Vector3.new(0, 5, 100)
            if carry.EggModel then carry.EggModel:Destroy() end
            carryingPlayers[player] = nil
            
            -- Thả trứng rơi xuống đất tại chỗ chết
            DropEggOnGround(dropPos, carry.EggName)
            stealRemote:FireClient(player, "EggDropped", carry.EggName)
            print(string.format("[StealZone] %s died! Dropped '%s' on battlefield!", player.Name, carry.EggName))
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        HookPlayerDeath(player, char)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local carry = carryingPlayers[player]
    if carry then
        local char = player.Character
        local dropPos = char and char.PrimaryPart and char.PrimaryPart.Position or Vector3.new(0, 5, 100)
        if carry.EggModel then carry.EggModel:Destroy() end
        carryingPlayers[player] = nil
        
        -- Thoát game khi đang cầm trứng -> Rơi xuống đất cho người khác nhặt
        DropEggOnGround(dropPos, carry.EggName)
        print(string.format("[StealZone] %s disconnected! Dropped '%s'!", player.Name, carry.EggName))
    end
end)

-- =============================================================================
-- 7. XỬ LÝ YÊU CẦU THẢ TRỨNG TỰ NGUYỆN TỪ CLIENT (VOLUNTARY DROP REQUEST)
-- =============================================================================
local dropCooldowns: { [number]: number } = {}

stealRemote.OnServerEvent:Connect(function(player: Player, action: string)
    if action == "ExitTreadmill" then
        if _G.ExitTreadmill then
            _G.ExitTreadmill(player)
        end
        return
    end
    
    if action == "RequestDrop" then
        local now = os.clock()
        local userId = player.UserId
        if now < (dropCooldowns[userId] or 0) then return end
        dropCooldowns[userId] = now + 1.0
        
        local carry = carryingPlayers[player]
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if not carry or not char or not hrp or not hum or hum.Health <= 0 then
            return
        end
        
        -- Không cho phép vứt bừa bãi trong Safe Zone (Z <= -5), chỉ áp dụng ngoài chiến trường
        if char:GetAttribute("InSafeZone") == true or hrp.Position.Z <= -5 then
            return
        end
        
        local eggName = carry.EggName
        local dropPos = hrp.Position
        
        if carry.EggModel then carry.EggModel:Destroy() end
        if carry.Weld then carry.Weld:Destroy() end
        carryingPlayers[player] = nil
        
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Model") and child:GetAttribute("IsCarriedItem") == true then
                child:Destroy()
            end
        end
        
        char:SetAttribute("IsCarryingEgg", false)
        char:SetAttribute("IsCarryingRock", false)
        char:SetAttribute("CarriedEggName", nil)
        char:SetAttribute("CarryingZone", 0)
        char:SetAttribute("CarriedRockId", nil)
        
        local pData = DataService.GetData(player)
        if pData then
            hum.WalkSpeed = pData.Speed
        end
        
        DropEggOnGround(dropPos, eggName)
        stealRemote:FireClient(player, "EggDropped", eggName)
        stealRemote:FireClient(player, "StopCarrying")
        print(string.format("[StealZone] %s voluntarily dropped '%s' at %.1f, %.1f!", player.Name, eggName, dropPos.X, dropPos.Z))
    end
end)
