--!strict
--[[
    SCRIPT: CameraController
    TYPE: LocalScript (Client-side)
    LOCATION: StarterPlayerScripts -> CameraController
    DESCRIPTION: Dynamic Camera Juice for Steal A Pet Rock!
                 - FOV Warp: Expands camera FOV from 70 to 92 based on running speed
                 - Heavy Cam Shake: Subtle tactile footstep thuds when carrying heavy rocks
                 Pure client presentation: 0 server network traffic!
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BASE_FOV = 70
local MAX_FOV = 92
local currentTargetFOV = BASE_FOV

-- 1. FOV WARP LOOP (BASED ON SPEED & MOVEMENT)
RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    
    if hum and hrp and hum.Health > 0 then
        local velocity = hrp.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
        
        if horizontalSpeed > 3 then
            -- Speed ratio from base 16 to max 135
            local ratio = math.clamp((horizontalSpeed - 16) / (120 - 16), 0, 1)
            currentTargetFOV = BASE_FOV + (ratio * (MAX_FOV - BASE_FOV))
        else
            currentTargetFOV = BASE_FOV
        end
    else
        currentTargetFOV = BASE_FOV
    end

    -- Smooth lerp camera FOV
    camera.FieldOfView = camera.FieldOfView + (currentTargetFOV - camera.FieldOfView) * math.clamp(dt * 8, 0, 1)
end)

-- 2. HEAVY CAM SHAKE (WHEN CARRYING MASSIVE BOULDERS)
local shakeStep = 0

RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    
    if not char or not hum or not hrp or hum.Health <= 0 then return end
    
    local isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true
    if not isCarrying then return end

    local velocity = hrp.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

    if horizontalSpeed > 3 and hum.FloorMaterial ~= Enum.Material.Air then
        local slowdown = char:GetAttribute("Slowdown") or 4
        local weightFactor = math.clamp(slowdown / 16, 0.4, 1.8)
        
        shakeStep = shakeStep + dt * 14
        local bobY = math.sin(shakeStep) * (0.04 * weightFactor)
        local bobX = math.cos(shakeStep * 0.5) * (0.02 * weightFactor)
        
        camera.CFrame = camera.CFrame * CFrame.new(bobX, bobY, 0)
    end
end)
