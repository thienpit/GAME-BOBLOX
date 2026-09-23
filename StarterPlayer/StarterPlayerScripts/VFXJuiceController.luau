--!strict
--[[
    SCRIPT: VFXJuiceController
    TYPE: LocalScript (Client-side)
    LOCATION: StarterPlayerScripts -> VFXJuiceController
    DESCRIPTION: Client-authoritative visual effects (juice) & Audio Hooks:
                 - Dynamic carry dust particles when hauling rocks/eggs
                 - Confetti & starburst celebration on successful base delivery
                 - Hatch explosion & 3-step ASMR audio sequence (Tap -> Crack -> Tada!)
                 - Combat "BONK" sound & impact dust on bat swings
                 - Dynamic BGM transition between Village Base and StealZone
                 - Cash & Whoosh audio feedback on leaderstats updates
                 Pure client presentation: 0 server network traffic!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local SoundManager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundManager"))

local hatchRemote = ReplicatedStorage:WaitForChild("HatchRemote") :: RemoteEvent
local stealRemote = ReplicatedStorage:WaitForChild("StealZoneRemote") :: RemoteEvent
local batRemote = ReplicatedStorage:WaitForChild("BatRemote") :: RemoteEvent

-- Helper: Create burst particle emitter
local function SpawnParticleBurst(position: Vector3, color: ColorSequence, size: number, count: number, speed: number)
    local p = Instance.new("Part")
    p.Name = "VFX_ParticleAnchor"
    p.Size = Vector3.new(0.5, 0.5, 0.5)
    p.Position = position
    p.Transparency = 1
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "VFX_Burst"
    emitter.Color = color
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, size),
        NumberSequenceKeypoint.new(0.6, size * 0.8),
        NumberSequenceKeypoint.new(1, 0)
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.1),
        NumberSequenceKeypoint.new(1, 1)
    })
    emitter.Lifetime = NumberRange.new(0.6, 1.2)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(speed * 0.5, speed)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Acceleration = Vector3.new(0, -12, 0)
    emitter.Drag = 2.5
    emitter.Parent = p

    emitter:Emit(count)
    task.delay(1.5, function()
        p:Destroy()
    end)
end

-- 1. CARRY DUST & HEAVY EFFORT TRAIL
local activeCarryEmitter: ParticleEmitter? = nil

local function UpdateCarryVFX(char: Model)
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    
    if isCarrying and hrp then
        if not activeCarryEmitter or not activeCarryEmitter.Parent then
            local att = hrp:FindFirstChild("VFX_CarryAtt") :: Attachment?
            if not att then
                att = Instance.new("Attachment")
                att.Name = "VFX_CarryAtt"
                att.Position = Vector3.new(0, -2.2, 0)
                att.Parent = hrp
            end
            
            local emitter = Instance.new("ParticleEmitter")
            emitter.Name = "VFX_HeavyFootstepDust"
            emitter.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 205, 180)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 165, 140))
            })
            emitter.Size = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1.2),
                NumberSequenceKeypoint.new(1, 2.8)
            })
            emitter.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.3),
                NumberSequenceKeypoint.new(1, 1)
            })
            emitter.Lifetime = NumberRange.new(0.4, 0.8)
            emitter.Rate = 14
            emitter.Speed = NumberRange.new(1, 3)
            emitter.SpreadAngle = Vector2.new(30, 30)
            emitter.Parent = att
            activeCarryEmitter = emitter
        end
    else
        if activeCarryEmitter then
            activeCarryEmitter:Destroy()
            activeCarryEmitter = nil
        end
        if hrp then
            local att = hrp:FindFirstChild("VFX_CarryAtt")
            if att then att:Destroy() end
        end
    end
end

-- 2. DELIVERY CELEBRATION (CONFETTI BURST ON DROP-OFF)
local wasCarrying = false

local function CheckDeliveryVFX(char: Model)
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    local inSafe = char:GetAttribute("InSafeZone") == true
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if wasCarrying and not isCarrying then
        -- Dropped off! If near or inside base -> play celebration burst + Cash sound!
        if (inSafe or (hrp and hrp.Position.Z <= 5)) and hrp then
            local starColor = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 80)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 160, 40)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 255, 130))
            })
            SpawnParticleBurst(hrp.Position + Vector3.new(0, 2, 0), starColor, 0.8, 35, 18)
            SoundManager.Play("Cash")
        end
    end
    wasCarrying = isCarrying
end

-- 3. HATCH REVEAL VFX + 3-STEP ASMR AUDIO SEQUENCE
hatchRemote.OnClientEvent:Connect(function(action: string, data: any)
    if action == "HatchReveal" and data then
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local pos = hrp and (hrp.Position + Vector3.new(0, 3, 0)) or Vector3.new(0, 5, 0)
        
        -- ASMR Audio sequence
        task.spawn(function()
            SoundManager.Play("HatchStep1", pos)
            task.wait(0.2)
            SoundManager.Play("HatchStep2", pos)
            task.wait(0.25)
            SoundManager.Play("HatchStep3", pos)
        end)

        local burstColor: ColorSequence
        local r = data.Rarity or "Common"
        if r == "Eternal" then
            burstColor = ColorSequence.new(Color3.fromRGB(0, 255, 230), Color3.fromRGB(255, 40, 120))
        elseif r == "Divine" then
            burstColor = ColorSequence.new(Color3.fromRGB(255, 240, 100), Color3.fromRGB(100, 220, 255))
        elseif r == "Secret" then
            burstColor = ColorSequence.new(Color3.fromRGB(255, 40, 140), Color3.fromRGB(180, 40, 255))
        elseif r == "Legendary" then
            burstColor = ColorSequence.new(Color3.fromRGB(255, 215, 30), Color3.fromRGB(255, 140, 20))
        elseif r == "Epic" then
            burstColor = ColorSequence.new(Color3.fromRGB(180, 80, 255), Color3.fromRGB(255, 100, 255))
        elseif r == "Rare" then
            burstColor = ColorSequence.new(Color3.fromRGB(80, 200, 255), Color3.fromRGB(100, 255, 180))
        else
            burstColor = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 220))
        end
        
        SpawnParticleBurst(pos, burstColor, 1.2, 50, 22)
    end
end)

-- 4. COMBAT "BONK" AUDIO & HIT VFX
batRemote.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
    if action == "PlayHitVFX" and typeof(arg1) == "Vector3" then
        SoundManager.Play("Bonk", arg1)
        local hitDustColor = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 200)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 180, 140))
        })
        SpawnParticleBurst(arg1 + Vector3.new(0, 2, 0), hitDustColor, 0.6, 20, 14)
    end
end)

-- 4.1. BOSS ROAR SFX (Exclusively for targeted player)
stealRemote.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any)
    if action == "MonsterRoar" then
        SoundManager.Play("Roar")
    end
end)

-- 5. LEADERSTATS AUDIO FEEDBACK (CASH & WHOOSH)
local lastMoney = -1
local lastSpeed = -1

local function HookLeaderstats(ls: Folder)
    local moneyVal = ls:WaitForChild("Money", 5) :: IntValue?
    if moneyVal and moneyVal:IsA("IntValue") then
        lastMoney = moneyVal.Value
        moneyVal.Changed:Connect(function(newVal)
            if lastMoney >= 0 and newVal > lastMoney then
                SoundManager.Play("Cash")
            end
            lastMoney = newVal
        end)
    end

    local speedVal = ls:WaitForChild("Speed", 5) :: IntValue?
    if speedVal and speedVal:IsA("IntValue") then
        lastSpeed = speedVal.Value
        local lastWhooshPlayTime = 0
        speedVal.Changed:Connect(function(newVal)
            local now = os.clock()
            if lastSpeed >= 0 and newVal > lastSpeed and (now - lastWhooshPlayTime) >= 1.2 then
                lastWhooshPlayTime = now
                SoundManager.Play("Whoosh")
            end
            lastSpeed = newVal
        end)
    end
end

local existingLs = player:FindFirstChild("leaderstats") :: Folder?
if existingLs then
    task.spawn(HookLeaderstats, existingLs)
end
player.ChildAdded:Connect(function(child)
    if child.Name == "leaderstats" and child:IsA("Folder") then
        HookLeaderstats(child)
    end
end)

-- 6. DYNAMIC BGM TRACKER (BASE vs CHASE / STEALZONE) & LOCAL SIREN
local function UpdateBGMState()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end
    
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    if isCarrying then
        SoundManager.PlayBGM("Chase")
        SoundManager.PlaySiren()
    else
        SoundManager.StopSiren()
        if hrp.Position.Z <= -5 then
            SoundManager.PlayBGM("Base")
        else
            SoundManager.PlayBGM("StealZone")
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1.0)
        UpdateBGMState()
    end
end)

-- 7. HOOK CHARACTER LIFECYCLE & R15 HEAVY CARRYING POSTURE
local originalShoulderC0_L: CFrame? = nil
local originalShoulderC0_R: CFrame? = nil

local function UpdateHoldingPosture(char: Model)
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return end

    local shoulderL = torso:FindFirstChild("LeftShoulder") :: Motor6D?
    local shoulderR = torso:FindFirstChild("RightShoulder") :: Motor6D?

    if shoulderL and not originalShoulderC0_L then originalShoulderC0_L = shoulderL.C0 end
    if shoulderR and not originalShoulderC0_R then originalShoulderC0_R = shoulderR.C0 end

    if isCarrying then
        -- Hug egg in front: raise arms, point hands forward and inward
        if shoulderL and originalShoulderC0_L then
            shoulderL.C0 = originalShoulderC0_L * CFrame.Angles(math.rad(65), math.rad(20), math.rad(-15))
        end
        if shoulderR and originalShoulderC0_R then
            shoulderR.C0 = originalShoulderC0_R * CFrame.Angles(math.rad(65), math.rad(-20), math.rad(15))
        end
    else
        -- Restore natural arm joints
        if shoulderL and originalShoulderC0_L then shoulderL.C0 = originalShoulderC0_L end
        if shoulderR and originalShoulderC0_R then shoulderR.C0 = originalShoulderC0_R end
    end
end

local function HookCharacter(char: Model)
    wasCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    originalShoulderC0_L = nil
    originalShoulderC0_R = nil
    
    char:GetAttributeChangedSignal("IsCarryingRock"):Connect(function()
        UpdateCarryVFX(char)
        UpdateHoldingPosture(char)
        CheckDeliveryVFX(char)
        UpdateBGMState()
    end)
    char:GetAttributeChangedSignal("IsCarryingEgg"):Connect(function()
        UpdateCarryVFX(char)
        UpdateHoldingPosture(char)
        CheckDeliveryVFX(char)
        UpdateBGMState()
    end)
    char:GetAttributeChangedSignal("InSafeZone"):Connect(function()
        UpdateCarryVFX(char)
        UpdateBGMState()
    end)
    
    local hum = char:WaitForChild("Humanoid") :: Humanoid
    hum.Died:Connect(function()
        SoundManager.StopSiren()
        if activeCarryEmitter then
            activeCarryEmitter:Destroy()
            activeCarryEmitter = nil
        end
        UpdateHoldingPosture(char)
    end)
end

if player.Character then
    HookCharacter(player.Character)
end
player.CharacterAdded:Connect(HookCharacter)

-- 8. CLIENT-SIDE INCUBATING EGG WOBBLE ANIMATION (STEAL AN EGG STYLE)
task.spawn(function()
    while true do
        task.wait(2.2)
        local basesFolder = workspace:FindFirstChild("Arena_Map") and workspace.Arena_Map:FindFirstChild("Bases")
        if basesFolder then
            for _, base in ipairs(basesFolder:GetChildren()) do
                local eggs = base:FindFirstChild("IncubatingEggs")
                if eggs then
                    for _, egg in ipairs(eggs:GetChildren()) do
                        local core = egg:FindFirstChild("EggCore") :: BasePart?
                        if core and core.Anchored then
                            task.spawn(function()
                                local origCF = core.CFrame
                                local twL = TweenService:Create(core, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                                    CFrame = origCF * CFrame.Angles(0, 0, math.rad(6))
                                })
                                local twR = TweenService:Create(core, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                                    CFrame = origCF * CFrame.Angles(0, 0, math.rad(-6))
                                })
                                local twBack = TweenService:Create(core, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                                    CFrame = origCF
                                })
                                twL:Play()
                                twL.Completed:Wait()
                                twR:Play()
                                twR.Completed:Wait()
                                twBack:Play()
                            end)
                        end
                    end
                end
            end
        end
    end
end)
