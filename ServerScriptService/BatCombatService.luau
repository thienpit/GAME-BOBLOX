--!strict
--[[
    TÊN SCRIPT: BatCombatService
    LOẠI: Script (Server-side)
    VỊ TRÍ: ServerScriptService -> BatCombatService
    MÔ TẢ: Hệ thống Combat gậy, Cửa hàng gậy (Bat Shop), Bảo vệ tân thủ 60s,
          Chống spawn-camp 3s, Kill-feed thông báo drama và bảo mật chống exploit toàn diện.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local BatConfig = require(ReplicatedStorage:WaitForChild("BatConfig"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local batRemote = ReplicatedStorage:WaitForChild("BatRemote") :: RemoteEvent
local getBatShopInfo = ReplicatedStorage:WaitForChild("GetBatShopInfo") :: RemoteFunction

local arena = workspace:WaitForChild("Arena_Map")
local stealZoneModel = arena:WaitForChild("StealZone")
local activeEggsFolder = stealZoneModel:WaitForChild("ActiveEggs")

local lastSwingTime: { [Player]: number } = {}
local targetInvincibleUntil: { [Player]: number } = {}

-- 1. HÀM TẠO VŨ KHÍ 3D CHO NGƯỜI CHƠI
local function CreateBatTool(batId: string): Tool
    local config = BatConfig.GetBat(batId) or BatConfig.BATS["wooden_bat"]
    
    local tool = Instance.new("Tool")
    tool.Name = config.Name
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool:SetAttribute("BatId", config.Id)
    tool.GripPos = Vector3.new(0, -1.2, 0)
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.6, 3.4, 0.6)
    handle.Material = config.HandleMaterial
    handle.Color = config.HandleColor
    handle.CanCollide = false
    handle.Parent = tool
    
    if config.Rarity == "Legendary" then
        local pl = Instance.new("PointLight")
        pl.Color = config.HandleColor
        pl.Brightness = 2.0
        pl.Range = 10
        pl.Parent = handle
    end
    
    return tool
end

local function GiveEquippedBat(player: Player)
    local pData = DataService.GetData(player)
    local equippedId = pData and pData.EquippedBat or "wooden_bat"
    
    local bp = player:FindFirstChild("Backpack")
    local char = player.Character
    
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("BatId") then
                item:Destroy()
            end
        end
    end
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute("BatId") then
                item:Destroy()
            end
        end
    end
    
    local newTool = CreateBatTool(equippedId)
    newTool.Parent = bp
end

-- 2. CỬA HÀNG GẬY TRUY VẤN
getBatShopInfo.OnServerInvoke = function(player: Player)
    local pData = DataService.GetData(player)
    if not pData then return nil end
    
    return {
        Money = pData.Money,
        OwnedBats = pData.OwnedBats or { "wooden_bat" },
        EquippedBat = pData.EquippedBat or "wooden_bat",
        Catalog = BatConfig.BATS
    }
end

-- 3. BẢO MẬT & KIỂM TRA RANH GIỚI
local function IsInStealZone(pos: Vector3): boolean
    local inZ = (pos.Z >= BatConfig.STEAL_ZONE_MIN_Z) and (pos.Z <= BatConfig.STEAL_ZONE_MAX_Z)
    local inX = math.abs(pos.X) <= BatConfig.STEAL_ZONE_MAX_X
    return inZ and inX
end

local function DropCarriedEgg(victimChar: Model, dropPos: Vector3, eggName: string)
    -- Find and REUSE the existing egg model instead of creating a duplicate!
    local existingEgg: Model? = nil
    for _, child in ipairs(victimChar:GetChildren()) do
        if child:IsA("Model") and child:GetAttribute("IsCarriedItem") == true then
            existingEgg = child
            break
        end
    end
    
    -- Sever all welds connecting egg to player
    if existingEgg then
        for _, desc in ipairs(victimChar:GetDescendants()) do
            if (desc:IsA("WeldConstraint") or desc:IsA("Weld")) then
                if desc.Part1 and desc.Part1:IsDescendantOf(existingEgg) then
                    desc:Destroy()
                end
            end
        end
        for _, desc in ipairs(existingEgg:GetDescendants()) do
            if (desc:IsA("WeldConstraint") or desc:IsA("Weld")) then
                if desc.Part0 and desc.Part0:IsDescendantOf(victimChar) then
                    desc:Destroy()
                end
            end
        end
    end
    
    victimChar:SetAttribute("IsCarryingEgg", false)
    victimChar:SetAttribute("IsCarryingRock", false)
    victimChar:SetAttribute("CarriedEggName", "")
    victimChar:SetAttribute("CarryingZone", 0)
    victimChar:SetAttribute("CarriedRockId", nil)
    
    -- Reuse existing model or create one if somehow missing
    local model: Model
    if existingEgg and existingEgg.PrimaryPart then
        model = existingEgg
        model.PrimaryPart.CFrame = CFrame.new(dropPos.X, 2.4, dropPos.Z)
        model.PrimaryPart.Anchored = true
        model.PrimaryPart.CanCollide = false
        model:SetAttribute("IsClaimed", false)
        model:SetAttribute("EggName", eggName)
        -- Remove old pickup prompts
        local oldP = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
        if oldP then oldP:Destroy() end
    else
        model = Instance.new("Model")
        model.Name = "DroppedEgg_" .. string.gsub(eggName, " ", "") .. "_" .. HttpService:GenerateGUID(false):sub(1, 4)
        model:SetAttribute("EggName", eggName)
        model:SetAttribute("IsClaimed", false)
        
        local core = Instance.new("Part")
        core.Name = "EggCore"
        core.Shape = Enum.PartType.Ball
        core.Size = Vector3.new(2.8, 3.8, 2.8)
        core.CFrame = CFrame.new(dropPos.X, 2.4, dropPos.Z)
        core.Anchored = true
        core.CanCollide = false
        core.Material = Enum.Material.Neon
        core.Color = Color3.fromRGB(255, 220, 60)
        core.Parent = model
        model.PrimaryPart = core
    end
    
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "PickupPrompt"
    prompt.ActionText = "Steal Dropped Egg"
    prompt.ObjectText = eggName
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 12
    prompt.Enabled = false
    prompt.Parent = model.PrimaryPart
    
    model.Parent = activeEggsFolder
    
    task.delay(3.0, function()
        if prompt and prompt.Parent then prompt.Enabled = true end
    end)
    
    task.delay(60.0, function()
        if model and model.Parent and not model:GetAttribute("IsClaimed") then model:Destroy() end
    end)
    
    prompt.Triggered:Connect(function(thiefPlayer)
        if model:GetAttribute("IsClaimed") == true then return end
        model:SetAttribute("IsClaimed", true)
        prompt.Enabled = false
        
        local tChar = thiefPlayer.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
        local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
        local tTorso = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")) :: BasePart?
        
        if not tChar or not tHrp or not tHum or not tTorso or tHum.Health <= 0 then
            model:SetAttribute("IsClaimed", false)
            prompt.Enabled = true
            return
        end
        
        if tChar:GetAttribute("IsCarryingEgg") == true or tChar:GetAttribute("IsCarryingRock") == true then
            model:SetAttribute("IsClaimed", false)
            prompt.Enabled = true
            return
        end
        
        local dist = (tHrp.Position - model.PrimaryPart.Position).Magnitude
        if dist > 16 then
            model:SetAttribute("IsClaimed", false)
            prompt.Enabled = true
            return
        end
        
        prompt:Destroy()
        model.PrimaryPart.Anchored = false
        model.PrimaryPart.CanCollide = false
        model.PrimaryPart.CFrame = tTorso.CFrame * CFrame.new(0, -0.2, -1.8) * CFrame.Angles(math.rad(-8), 0, 0)
        model:SetAttribute("IsCarriedItem", true)
        model.Parent = tChar
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = tTorso
        weld.Part1 = model.PrimaryPart
        weld.Parent = tTorso
        
        local pData = DataService.GetData(thiefPlayer)
        local curSpeed = pData and pData.Speed or 16
        tHum.WalkSpeed = math.max(6, curSpeed - 4)
        
        tChar:SetAttribute("IsCarryingEgg", true)
        tChar:SetAttribute("CarriedEggName", eggName)
        tChar:SetAttribute("Slowdown", 4)
        
        stealRemote:FireClient(thiefPlayer, "StartCarrying", eggName, 4)
    end)
end

-- 4. UNIFIED SINGLE SERVER EVENT HANDLER (SHOP + COMBAT DISPATCH)
batRemote.OnServerEvent:Connect(function(player: Player, action: string, arg1: any)
    local pData = DataService.GetData(player)
    if not pData then return end
    
    if action == "BuyBat" then
        local batId = tostring(arg1)
        local config = BatConfig.BATS[batId]
        if not config then return end
        
        if DataService.OwnsBat(player, batId) then return end
        
        if DataService.SubMoney(player, config.Price) then
            DataService.AddBat(player, batId)
            DataService.EquipBat(player, batId)
            GiveEquippedBat(player)
            print(string.format("[BatShop] %s purchased '%s' ($%d)!", player.Name, config.Name, config.Price))
            batRemote:FireClient(player, "ShopRefresh")
        end
        
    elseif action == "EquipBat" then
        local batId = tostring(arg1)
        if DataService.OwnsBat(player, batId) then
            DataService.EquipBat(player, batId)
            GiveEquippedBat(player)
            print(string.format("[BatShop] %s equipped '%s'!", player.Name, batId))
            batRemote:FireClient(player, "ShopRefresh")
        end
        
    elseif action == "SwingBat" then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        
        local equippedTool = char:FindFirstChildOfClass("Tool")
        if not equippedTool then return end
        
        local batId = equippedTool:GetAttribute("BatId") or "wooden_bat"
        local batConfig = BatConfig.GetBat(batId)
        if not batConfig then return end
        
        -- Cooldown rate-limit
        local now = os.clock()
        local lastSwing = lastSwingTime[player] or 0
        if (now - lastSwing) < (batConfig.Cooldown - 0.05) then return end
        lastSwingTime[player] = now
        
        -- Phải trong StealZone và không trong Căn cứ
        if not IsInStealZone(hrp.Position) then return end
        if char:GetAttribute("InSafeZone") == true then return end
        
        batRemote:FireClient(player, "PlaySwingAnim")
        
        -- Quét mục tiêu trên Server
        local range = batConfig.Range
        local attackCenterCF = hrp.CFrame * CFrame.new(0, 0, -range / 2)
        local boxSize = Vector3.new(6.5, 6.0, range)
        
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Exclude
        overlapParams.FilterDescendantsInstances = { char }
        
        local touchingParts = workspace:GetPartBoundsInBox(attackCenterCF, boxSize, overlapParams)
        local hitVictims: { [Model]: boolean } = {}
        
        for _, part in ipairs(touchingParts) do
            local targetModel = part:FindFirstAncestorOfClass("Model")
            if targetModel and not hitVictims[targetModel] then
                local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
                local targetHrp = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?
                local targetPlayer = Players:GetPlayerFromCharacter(targetModel)
                
                if targetPlayer and targetPlayer ~= player and targetHum and targetHrp and targetHum.Health > 0 then
                    hitVictims[targetModel] = true
                    
                    local realDist = (targetHrp.Position - hrp.Position).Magnitude
                    if realDist > (range + 2.5) then continue end
                    if not IsInStealZone(targetHrp.Position) then continue end
                    if targetModel:GetAttribute("InSafeZone") == true then continue end
                    
                    -- 1. BẢO VỆ TÂN THỦ 60S
                    local newbieUntil = targetPlayer:GetAttribute("NewbieShieldUntil") or 0
                    if os.time() < newbieUntil then continue end
                    
                    -- 2. CHỐNG SPAWN-CAMP 3S
                    local graceUntil = targetModel:GetAttribute("StealZoneGraceUntil") or 0
                    if os.clock() < graceUntil then continue end
                    
                    -- 3. MIỄN NHIỄM 2S (ANTI CHAIN-STUN)
                    local immuneEnd = targetInvincibleUntil[targetPlayer] or 0
                    if now < immuneEnd then continue end
                    targetInvincibleUntil[targetPlayer] = now + BatConfig.INVINCIBILITY_DURATION
                    
                    targetModel:SetAttribute("IsInvincible", true)
                    task.delay(BatConfig.INVINCIBILITY_DURATION, function()
                        if targetModel and targetModel.Parent then targetModel:SetAttribute("IsInvincible", false) end
                    end)
                    
                    -- Lực hất văng & Choáng
                    local knockDir = (targetHrp.Position - hrp.Position).Unit
                    targetHrp.AssemblyLinearVelocity = Vector3.new(knockDir.X * batConfig.Knockback, 22, knockDir.Z * batConfig.Knockback)
                    
                    targetHum.Sit = true
                    targetHum.WalkSpeed = 0
                    targetHum.JumpHeight = 0
                    
                    task.delay(batConfig.StunDuration, function()
                        if targetHum and targetHum.Parent and targetHum.Health > 0 then
                            local targetPData = DataService.GetData(targetPlayer)
                            local realSpd = targetPData and targetPData.Speed or (targetPlayer:GetAttribute("RealWalkSpeed") or 16)
                            targetHum.WalkSpeed = realSpd
                            targetHum.JumpHeight = 7.2
                        end
                    end)
                    
                    -- ĐÁNH RƠI TRỨNG & PHÁT DRAMA FEED TOÀN SERVER
                    if targetModel:GetAttribute("IsCarryingEgg") == true or targetModel:GetAttribute("IsCarryingRock") == true then
                        local carriedEggName = targetModel:GetAttribute("CarriedEggName") or "Common Rock"
                        DropCarriedEgg(targetModel, targetHrp.Position, carriedEggName)
                        batRemote:FireClient(targetPlayer, "HitAndDroppedEgg", carriedEggName)
                        
                        local feedMsg = string.format("⚔️ %s STOLE %s'S EGG!", string.upper(player.DisplayName), string.upper(targetPlayer.DisplayName))
                        for _, p in ipairs(Players:GetPlayers()) do
                            batRemote:FireClient(p, "ActionFeed", feedMsg)
                        end
                    end
                    
                    batRemote:FireAllClients("PlayHitVFX", targetHrp.Position, batConfig.Rarity, targetPlayer.Name)
                end
            end
        end
    end
end)

-- 5. GIÁM SÁT TÂN THỦ & VÀO STEALZONE GRACE 3S
local playerWasInStealZone: { [Player]: boolean } = {}

Players.PlayerAdded:Connect(function(player)
    player:SetAttribute("NewbieShieldUntil", os.time() + 60)
    player.CharacterAdded:Connect(function(char)
        task.wait(1.0)
        GiveEquippedBat(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.4)
        for _, player in ipairs(Players:GetPlayers()) do
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hrp then
                local inZone = IsInStealZone(hrp.Position)
                local wasIn = playerWasInStealZone[player] or false
                if inZone and not wasIn then
                    char:SetAttribute("StealZoneGraceUntil", os.clock() + 3.0)
                    batRemote:FireClient(player, "GraceActivated", 3.0)
                end
                playerWasInStealZone[player] = inZone
            end
        end
    end
end)
