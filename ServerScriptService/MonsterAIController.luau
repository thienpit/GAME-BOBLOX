--!strict
--[[
    SCRIPT: MonsterAIController
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> MonsterAIController
    DESCRIPTION: Guard Boss AI with Nest Stealing & Egg Retrieval mechanics.
                 Fixes: Completely severs all welds to player so player is NEVER dragged along!
                 Carries egg back to nest and anchors it firmly in the nest for re-stealing!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local DataService = require(game:GetService("ServerScriptService"):WaitForChild("DataService"))
local stealRemote = ReplicatedStorage:WaitForChild("StealZoneRemote") :: RemoteEvent
local batRemote = ReplicatedStorage:WaitForChild("BatRemote") :: RemoteEvent

local arena = workspace:WaitForChild("Arena_Map")
local monstersFolder = arena:WaitForChild("Monsters")
local activeSpawns = arena:WaitForChild("ActiveSpawns")

local attackCooldowns: { [Model]: number } = {}
local monsterWakeState: { [Model]: string } = {} -- [Monster] = "Sleeping" | "Waking" | "Chasing" | "ReturningWithEgg"
local monsterCarriedEgg: { [Model]: Model? } = {}
local monsterEggWeld: { [Model]: WeldConstraint? } = {}

local ZONE_ROCK_NAMES = {
    [1] = "Mossy Rock 🌿",
    [2] = "Obsidian Crystal 🔮",
    [3] = "Magma Core 🔥",
    [4] = "Cosmic Meteor ☄️"
}

local ZONE_ROCK_COLORS = {
    [1] = Color3.fromRGB(75, 140, 75),
    [2] = Color3.fromRGB(30, 25, 45),
    [3] = Color3.fromRGB(220, 60, 20),
    [4] = Color3.fromRGB(255, 190, 40)
}

local function CreateFallbackEgg(zoneId: number, cframe: CFrame): Model
    local model = Instance.new("Model")
    local name = ZONE_ROCK_NAMES[zoneId] or "Mossy Rock 🌿"
    model.Name = "RestoredRock_Zone" .. zoneId
    model:SetAttribute("EggName", name)
    model:SetAttribute("ZoneId", zoneId)
    model:SetAttribute("IsClaimed", false)
    
    local core = Instance.new("Part")
    core.Name = "EggCore"
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(3.0, 3.4, 3.0)
    core.Color = ZONE_ROCK_COLORS[zoneId] or Color3.fromRGB(75, 140, 75)
    core.Material = (zoneId == 3 and Enum.Material.CrackedLava) or (zoneId == 4 and Enum.Material.Neon) or Enum.Material.Slate
    core.Anchored = true
    core.CanCollide = false
    core.CFrame = cframe
    core.Parent = model
    model.PrimaryPart = core
    
    return model
end

local function ShowFloatingText(head: BasePart?, text: string, color: Color3)
    if not head then return end
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 240, 0, 42)
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

-- Completely sever all welds/joints connecting character to an egg
local function CompletelySeverPlayerWelds(char: Model, eggModel: Model)
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") then
            if desc.Part0 and desc.Part0:IsDescendantOf(eggModel) then
                desc:Destroy()
            elseif desc.Part1 and desc.Part1:IsDescendantOf(eggModel) then
                desc:Destroy()
            end
        end
    end
    for _, desc in ipairs(eggModel:GetDescendants()) do
        if desc:IsA("WeldConstraint") or desc:IsA("Weld") or desc:IsA("Motor6D") then
            if desc.Part0 and desc.Part0:IsDescendantOf(char) then
                desc:Destroy()
            elseif desc.Part1 and desc.Part1:IsDescendantOf(char) then
                desc:Destroy()
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.05) -- 20Hz update rate
        
        for _, monster in ipairs(monstersFolder:GetChildren()) do
            if monster:IsA("Model") then
                local zoneId = monster:GetAttribute("ZoneId") or 1
                local hrp = monster:FindFirstChild("HumanoidRootPart") :: BasePart?
                local head = monster:FindFirstChild("Head") :: BasePart?
                local bg = head and head:FindFirstChildOfClass("BillboardGui")
                local label = bg and bg:FindFirstChildOfClass("TextLabel")
                
                local homeX = monster:GetAttribute("HomeX") or 0
                local homeZ = monster:GetAttribute("HomeZ") or 0
                local speedTable = { [1] = 14, [2] = 20, [3] = 28, [4] = 38, [5] = 52, [6] = 68, [7] = 88 }
                local speed = speedTable[zoneId] or (monster:GetAttribute("Speed") or 24)
                local mName = monster.Name
                local standingY = 4.5
                
                if not hrp then continue end
                
                local state = monsterWakeState[monster] or "Sleeping"
                
                -- =============================================================
                -- STATE: RETURNING WITH SNATCHED EGG
                -- =============================================================
                if state == "ReturningWithEgg" then
                    local homePos = Vector3.new(homeX, standingY, homeZ)
                    local distToHome = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(homeX, 0, homeZ)).Magnitude
                    
                    if distToHome > 4.5 then
                        local returnDir = (homePos - hrp.Position).Unit
                        local nextX = hrp.Position.X + returnDir.X * (speed * 0.95 * 0.05)
                        local nextZ = hrp.Position.Z + returnDir.Z * (speed * 0.95 * 0.05)
                        hrp.CFrame = CFrame.lookAt(Vector3.new(nextX, standingY, nextZ), homePos)
                        
                        -- Synchronize carried egg position firmly in front of monster (NEVER FALLS INTO VOID!)
                        local carriedEgg = monsterCarriedEgg[monster]
                        if carriedEgg and carriedEgg.PrimaryPart then
                            carriedEgg.PrimaryPart.CFrame = hrp.CFrame * CFrame.new(0, 1.2, -2.8)
                        end
                        
                        if label then
                            label.Text = mName .. "\n[RETURNING STOLEN EGG TO NEST... 🏃]"
                            label.TextColor3 = Color3.fromRGB(255, 180, 50)
                        end
                    else
                        -- Reached nest: Safely detach egg and place at clearly visible nest pedestal!
                        local carriedEgg = monsterCarriedEgg[monster]
                        monsterCarriedEgg[monster] = nil
                        if monsterEggWeld[monster] then
                            monsterEggWeld[monster]:Destroy()
                            monsterEggWeld[monster] = nil
                        end
                        
                        -- Target spot: find the EXACT spot it came from, or first empty spot in this zone
                        local zModel = arena:FindFirstChild("Zones") and arena.Zones:FindFirstChild("Zone_" .. zoneId)
                        local spots = zModel and zModel:FindFirstChild("SpawnSpots")
                        local origSpotIdx = (carriedEgg and carriedEgg:GetAttribute("OriginSpotIndex")) or 1
                        
                        local chosenSpotPart: BasePart? = nil
                        local chosenSpotIdx = origSpotIdx
                        
                        -- Check if origin spot is available (no other rock on it)
                        if spots then
                            local sCandidate = spots:FindFirstChild("Spot_" .. origSpotIdx) :: BasePart?
                            if sCandidate then
                                local occupied = false
                                for _, other in ipairs(activeSpawns:GetChildren()) do
                                    if other ~= carriedEgg and other.PrimaryPart then
                                        if (other.PrimaryPart.Position - sCandidate.Position).Magnitude < 3.0 then
                                            occupied = true
                                            break
                                        end
                                    end
                                end
                                if not occupied then
                                    chosenSpotPart = sCandidate
                                    chosenSpotIdx = origSpotIdx
                                end
                            end
                            
                            -- If origin spot was occupied or missing, find first empty spot in zone
                            if not chosenSpotPart then
                                for s = 1, 6 do
                                    local sCand = spots:FindFirstChild("Spot_" .. s) :: BasePart?
                                    if sCand then
                                        local occupied = false
                                        for _, other in ipairs(activeSpawns:GetChildren()) do
                                            if other ~= carriedEgg and other.PrimaryPart then
                                                if (other.PrimaryPart.Position - sCand.Position).Magnitude < 3.0 then
                                                    occupied = true
                                                    break
                                                end
                                            end
                                        end
                                        if not occupied then
                                            chosenSpotPart = sCand
                                            chosenSpotIdx = s
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        
                        local targetNestCF: CFrame
                        if chosenSpotPart then
                            targetNestCF = CFrame.new(chosenSpotPart.Position + Vector3.new(0, 2.0, 0))
                        else
                            targetNestCF = CFrame.new(homeX, 2.5, homeZ - 7.5)
                        end
                        
                        if not carriedEgg or not carriedEgg.PrimaryPart then
                            carriedEgg = CreateFallbackEgg(zoneId, targetNestCF)
                        end
                        
                        carriedEgg.Parent = activeSpawns
                        carriedEgg.PrimaryPart.Anchored = true
                        carriedEgg.PrimaryPart.CanCollide = false
                        carriedEgg.PrimaryPart.CFrame = targetNestCF
                        carriedEgg:SetAttribute("IsClaimed", false)
                        carriedEgg:SetAttribute("OriginSpotIndex", chosenSpotIdx)
                        carriedEgg:SetAttribute("OriginZoneId", zoneId)
                        
                        local nestEgg = carriedEgg
                        local nestEggName = carriedEgg:GetAttribute("EggName") or carriedEgg.Name
                        local nestZoneId = zoneId
                        local nestSpotId = chosenSpotIdx
                        
                        -- Add shiny floating label so player can easily spot it from afar
                        local bGui = carriedEgg.PrimaryPart:FindFirstChild("RestoredUI")
                        if not bGui then
                            bGui = Instance.new("BillboardGui")
                            bGui.Name = "RestoredUI"
                            bGui.Size = UDim2.new(0, 160, 0, 36)
                            bGui.StudsOffset = Vector3.new(0, 3.2, 0)
                            bGui.AlwaysOnTop = true
                            bGui.Parent = carriedEgg.PrimaryPart
                            
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1, 0, 1, 0)
                            lbl.Text = "✨ " .. nestEggName
                            lbl.TextColor3 = Color3.fromRGB(255, 220, 80)
                            lbl.TextSize = 14
                            lbl.Font = Enum.Font.FredokaOne
                            lbl.BackgroundTransparency = 1
                            lbl.TextStrokeTransparency = 0.5
                            lbl.Parent = bGui
                        end
                        
                        -- Re-add pickup prompt with RequiresLineOfSight = false (ALWAYS CLICKABLE!)
                        local oldPrompt = carriedEgg.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
                        if not oldPrompt then
                            oldPrompt = Instance.new("ProximityPrompt")
                            oldPrompt.Name = "PickupPrompt"
                            oldPrompt.ActionText = "Steal Rock/Egg 🪨"
                            oldPrompt.ObjectText = nestEggName
                            oldPrompt.HoldDuration = 0.5
                            oldPrompt.MaxActivationDistance = 14
                            oldPrompt.RequiresLineOfSight = false
                            oldPrompt.Parent = carriedEgg.PrimaryPart
                        else
                            oldPrompt.Enabled = true
                            oldPrompt.RequiresLineOfSight = false
                            oldPrompt.ObjectText = nestEggName
                        end
                        
                        oldPrompt.Triggered:Connect(function(trigPlayer)
                            if nestEgg:GetAttribute("IsClaimed") == true then return end
                            nestEgg:SetAttribute("IsClaimed", true)
                            oldPrompt.Enabled = false
                            
                            local tChar = trigPlayer.Character
                            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                            local tTorso = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso")) :: BasePart?
                            if not tHrp or not tHum or not tTorso or tHum.Health <= 0 then
                                nestEgg:SetAttribute("IsClaimed", false)
                                oldPrompt.Enabled = true
                                return
                            end
                            
                            if tChar:GetAttribute("IsCarryingRock") or tChar:GetAttribute("IsCarryingEgg") then
                                nestEgg:SetAttribute("IsClaimed", false)
                                oldPrompt.Enabled = true
                                return
                            end
                            
                            local bGui = nestEgg.PrimaryPart:FindFirstChild("RestoredUI")
                            if bGui then bGui:Destroy() end
                            
                            nestEgg.PrimaryPart.Anchored = false
                            nestEgg.PrimaryPart.CanCollide = false
                            nestEgg.PrimaryPart.CFrame = tTorso.CFrame * CFrame.new(0, -0.2, -1.8) * CFrame.Angles(math.rad(-8), 0, 0)
                            nestEgg.Parent = tChar
                            oldPrompt:Destroy()
                            
                            local weld = Instance.new("WeldConstraint")
                            weld.Part0 = tTorso
                            weld.Part1 = nestEgg.PrimaryPart
                            weld.Parent = tTorso
                            
                            local pData = DataService.GetData(trigPlayer)
                            local currentSpeed = pData and pData.Speed or 16
                            tHum.WalkSpeed = math.max(6, currentSpeed - 4)
                            
                            tChar:SetAttribute("IsCarryingRock", true)
                            tChar:SetAttribute("IsCarryingEgg", true)
                            tChar:SetAttribute("CarriedEggName", nestEggName)
                            tChar:SetAttribute("CarryingZone", nestZoneId)
                            tChar:SetAttribute("OriginSpotIndex", nestSpotId)
                            tChar:SetAttribute("OriginZoneId", nestZoneId)
                            tChar:SetAttribute("Slowdown", 4)
                            
                            stealRemote:FireClient(trigPlayer, "StartCarrying", nestEggName, 4)
                        end)
                        
                        monsterWakeState[monster] = "Sleeping"
                        if label then
                            label.Text = "💤 " .. mName .. "\n[SLEEPING IN NEST]"
                            label.TextColor3 = Color3.fromRGB(160, 200, 255)
                        end
                        hrp.CFrame = CFrame.new(homeX, 2.0, homeZ) * CFrame.Angles(math.rad(80), 0, 0)
                        ShowFloatingText(head, "EGG RESTORED TO SPOT #" .. chosenSpotIdx .. "! 🛡️", Color3.fromRGB(80, 255, 120))
                    end
                    continue
                end
                
                -- =============================================================
                -- FIND THIEF CARRYING EGG/ROCK FROM THIS ZONE
                -- =============================================================
                local zoneThief: Player? = nil
                local targetChar: Model? = nil
                local targetHrp: BasePart? = nil
                local targetHum: Humanoid? = nil
                
                for _, p in ipairs(Players:GetPlayers()) do
                    local char = p.Character
                    local pHrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local isCarrying = char and (char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true)
                    local carryZone = char and char:GetAttribute("CarryingZone")
                    
                    if pHrp and hum and hum.Health > 0 and isCarrying then
                        -- ONLY chase if player stole from THIS monster's zone (no cross-zone aggro)
                        local isMyThief = (carryZone == zoneId)
                        
                        -- Stop chasing if player reached safe zone (Z <= -5)
                        local inSafeZone = (pHrp.Position.Z <= -5) or (char:GetAttribute("InSafeZone") == true)
                        
                        if isMyThief and not inSafeZone then
                            zoneThief = p
                            targetChar = char
                            targetHrp = pHrp
                            targetHum = hum
                            break
                        end
                    end
                end
                
                if zoneThief and targetChar and targetHrp and targetHum then
                    if state == "Sleeping" then
                        monsterWakeState[monster] = "Waking"
                        monster:SetAttribute("WakeStartTime", os.clock())
                        if label then
                            label.Text = "⚠️ " .. mName .. "\n[WAKING UP - INTRUDER DETECTED!]"
                            label.TextColor3 = Color3.fromRGB(255, 100, 100)
                        end
                        ShowFloatingText(head, "GRRR! WHO TOUCHED MY EGG?! 💢", Color3.fromRGB(255, 50, 50))
                        
                        -- Fire Roar exclusively to the thief client (Zero server leak)
                        stealRemote:FireClient(zoneThief, "MonsterRoar")
                        
                    elseif state == "Waking" then
                        local wakeStart = monster:GetAttribute("WakeStartTime") or os.clock()
                        if (os.clock() - wakeStart) >= 0.35 then
                            monsterWakeState[monster] = "Chasing"
                            if label then
                                label.Text = "🚨 " .. mName .. "\n[ENRAGED CHASE!]"
                                label.TextColor3 = Color3.fromRGB(255, 20, 20)
                            end
                        else
                            hrp.CFrame = CFrame.lookAt(
                                Vector3.new(hrp.Position.X, standingY, hrp.Position.Z),
                                Vector3.new(targetHrp.Position.X, standingY, targetHrp.Position.Z)
                            )
                        end
                        
                    elseif state == "Chasing" then
                        local targetPos = Vector3.new(targetHrp.Position.X, standingY, targetHrp.Position.Z)
                        local dir = (targetPos - hrp.Position).Unit
                        local nextX = math.clamp(hrp.Position.X + dir.X * (speed * 0.05), -48, 48)
                        local nextZ = math.max(-10, hrp.Position.Z + dir.Z * (speed * 0.05))
                        
                        hrp.CFrame = CFrame.lookAt(
                            Vector3.new(nextX, standingY, nextZ),
                            targetPos
                        )
                        
                        -- BONK ATTACK (<= 7.0 studs)
                        local dist = (hrp.Position - targetHrp.Position).Magnitude
                        if dist <= 7.0 then
                            local cd = attackCooldowns[monster] or 0
                            if os.clock() >= cd then
                                attackCooldowns[monster] = os.clock() + 3.0
                                
                                -- 1. Find the carried item model attached to player
                                local snatchedModel: Model? = nil
                                for _, child in ipairs(targetChar:GetChildren()) do
                                    if child:IsA("Model") and child:GetAttribute("IsCarriedItem") == true then
                                        snatchedModel = child
                                        break
                                    end
                                end
                                
                                -- 2. SEVER ALL WELDS CONNECTING EGG TO PLAYER (PREVENTS DRAGGING PLAYER!)
                                if snatchedModel then
                                    CompletelySeverPlayerWelds(targetChar, snatchedModel)
                                end
                                
                                -- 3. Clear all carry attributes on player
                                local origSpotIdx = (snatchedModel and snatchedModel:GetAttribute("OriginSpotIndex")) 
                                    or targetChar:GetAttribute("OriginSpotIndex") 
                                    or 1
                                local origZoneId = (snatchedModel and snatchedModel:GetAttribute("OriginZoneId")) 
                                    or targetChar:GetAttribute("OriginZoneId") 
                                    or zoneId
                                
                                targetChar:SetAttribute("IsCarryingRock", false)
                                targetChar:SetAttribute("IsCarryingEgg", false)
                                targetChar:SetAttribute("CarryingZone", 0)
                                targetChar:SetAttribute("CarriedEggName", nil)
                                targetChar:SetAttribute("OriginSpotIndex", nil)
                                targetChar:SetAttribute("OriginZoneId", nil)
                                
                                local pDataRestore = DataService.GetData(zoneThief)
                                targetHum.WalkSpeed = pDataRestore and pDataRestore.Speed or 16
                                
                                -- 4. Knock back player and trip them onto ground safely
                                local knockDir = (targetHrp.Position - hrp.Position).Unit
                                targetHrp.AssemblyLinearVelocity = Vector3.new(knockDir.X * 35, 18, knockDir.Z * 35)
                                targetHum.Sit = true
                                ShowFloatingText(targetChar:FindFirstChild("Head"), "BONKED! EGG SNATCHED! 😱", Color3.fromRGB(255, 50, 50))
                                
                                -- Trigger Cartoon Bonk SFX exclusively on victim client (Zero server leak)
                                batRemote:FireClient(zoneThief, "PlayHitVFX", targetHrp.Position)
                                
                                -- 5. Attach egg EXCLUSIVELY to monster (Anchored firmly so it NEVER falls into void!)
                                if not snatchedModel or not snatchedModel.PrimaryPart then
                                    snatchedModel = CreateFallbackEgg(zoneId, hrp.CFrame * CFrame.new(0, 1.2, -2.8))
                                end
                                
                                snatchedModel:SetAttribute("OriginSpotIndex", origSpotIdx)
                                snatchedModel:SetAttribute("OriginZoneId", origZoneId)
                                
                                snatchedModel.Parent = monster
                                snatchedModel.PrimaryPart.Anchored = true
                                snatchedModel.PrimaryPart.CanCollide = false
                                snatchedModel.PrimaryPart.CFrame = hrp.CFrame * CFrame.new(0, 1.2, -2.8)
                                
                                monsterCarriedEgg[monster] = snatchedModel
                                monsterEggWeld[monster] = nil
                                
                                -- 6. Monster immediately heads back to nest with egg
                                monsterWakeState[monster] = "ReturningWithEgg"
                            end
                        end
                    end
                else
                    -- NO THIEF: RETURN TO NEST & SLEEP
                    local homePos = Vector3.new(homeX, standingY, homeZ)
                    local distToHome = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(homeX, 0, homeZ)).Magnitude
                    
                    if distToHome > 3.5 then
                        local returnDir = (homePos - hrp.Position).Unit
                        local nextX = hrp.Position.X + returnDir.X * (speed * 0.45 * 0.05)
                        local nextZ = hrp.Position.Z + returnDir.Z * (speed * 0.45 * 0.05)
                        hrp.CFrame = CFrame.lookAt(Vector3.new(nextX, standingY, nextZ), homePos)
                        if label then
                            label.Text = mName .. "\n[RETURNING TO NEST...]"
                            label.TextColor3 = Color3.fromRGB(200, 200, 150)
                        end
                    else
                        monsterWakeState[monster] = "Sleeping"
                        if label then
                            label.Text = "💤 " .. mName .. "\n[SLEEPING IN NEST]"
                            label.TextColor3 = Color3.fromRGB(160, 200, 255)
                        end
                        hrp.CFrame = CFrame.new(homeX, 2.0, homeZ) * CFrame.Angles(math.rad(80), 0, 0)
                    end
                end
            end
        end
    end
end)
