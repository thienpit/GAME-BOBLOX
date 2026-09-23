--!strict
--[[
    SCRIPT: TrailController
    TYPE: LocalScript (Client-side)
    LOCATION: StarterPlayerScripts -> TrailController
    DESCRIPTION: Physical Speed Trail Renderer for Steal A Pet Rock!
                 - Renders gorgeous glowing ribbons behind characters when running
                 - Auto-updates color palette and lifetime based on player's EquippedTrail
                 - Smooth fade out when stopped, 0 server network traffic!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local TrailConfig = require(ReplicatedStorage:WaitForChild("TrailConfig"))

type ActiveTrail = {
    Trail: Trail,
    Att0: Attachment,
    Att1: Attachment,
    Char: Model,
}

local characterTrails: { [Model]: ActiveTrail } = {}

local function SetupTrailForCharacter(char: Model, playerOwner: Player)
    local torso = char:WaitForChild("UpperTorso", 4) or char:WaitForChild("Torso", 4) :: BasePart?
    local hrp = char:WaitForChild("HumanoidRootPart", 4) :: BasePart?
    local hum = char:WaitForChild("Humanoid", 4) :: Humanoid?
    if not torso or not hrp or not hum then return end

    -- Clean old trail if any
    if characterTrails[char] then
        local old = characterTrails[char]
        if old.Trail and old.Trail.Parent then old.Trail:Destroy() end
        if old.Att0 and old.Att0.Parent then old.Att0:Destroy() end
        if old.Att1 and old.Att1.Parent then old.Att1:Destroy() end
        characterTrails[char] = nil
    end

    local att0 = Instance.new("Attachment")
    att0.Name = "SpeedTrail_Att0"
    att0.Position = Vector3.new(0, 0.7, 0.4)
    att0.Parent = torso

    local att1 = Instance.new("Attachment")
    att1.Name = "SpeedTrail_Att1"
    att1.Position = Vector3.new(0, -0.7, 0.4)
    att1.Parent = torso

    local trail = Instance.new("Trail")
    trail.Name = "SpeedTrail"
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.FaceCamera = true
    trail.Enabled = false
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.4),
        NumberSequenceKeypoint.new(0.6, 0.9),
        NumberSequenceKeypoint.new(1, 0.1)
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(0.7, 0.35),
        NumberSequenceKeypoint.new(1, 1)
    })

    -- Apply initial trail info
    local trailId = playerOwner:GetAttribute("EquippedTrail") or "trail_dust"
    local tInfo = TrailConfig.TRAILS[trailId] or TrailConfig.TRAILS["trail_dust"]
    trail.Color = tInfo.Color
    trail.Lifetime = tInfo.Lifetime
    trail.LightEmission = tInfo.LightEmission
    trail.Parent = torso

    characterTrails[char] = {
        Trail = trail,
        Att0 = att0,
        Att1 = att1,
        Char = char
    }

    -- Listen to Trail upgrade changes
    playerOwner:GetAttributeChangedSignal("EquippedTrail"):Connect(function()
        local newTrailId = playerOwner:GetAttribute("EquippedTrail") or "trail_dust"
        local newInfo = TrailConfig.TRAILS[newTrailId] or TrailConfig.TRAILS["trail_dust"]
        trail.Color = newInfo.Color
        trail.Lifetime = newInfo.Lifetime
        trail.LightEmission = newInfo.LightEmission
    end)
end

-- Render loop: enable trail only when moving fast enough
RunService.RenderStepped:Connect(function()
    for char, info in pairs(characterTrails) do
        if char and char.Parent then
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local vel = hrp.AssemblyLinearVelocity
                local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
                local onTreadmill = char:GetAttribute("OnTreadmill") == true

                -- Enable trail if moving fast or running on treadmill
                if (horizSpeed > 4 or onTreadmill) and not hum.Sit then
                    info.Trail.Enabled = true
                else
                    info.Trail.Enabled = false
                end
            else
                info.Trail.Enabled = false
            end
        else
            characterTrails[char] = nil
        end
    end
end)

-- Hook all players (local + other players in game)
local function HookPlayer(p: Player)
    p.CharacterAdded:Connect(function(char)
        SetupTrailForCharacter(char, p)
    end)
    if p.Character then
        SetupTrailForCharacter(p.Character, p)
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    HookPlayer(p)
end
Players.PlayerAdded:Connect(HookPlayer)
