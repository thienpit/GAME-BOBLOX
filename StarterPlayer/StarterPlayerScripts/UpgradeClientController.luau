--!strict
--[[
    SCRIPT: UpgradeClientController
    TYPE: LocalScript
    LOCATION: StarterPlayerScripts -> UpgradeClientController
    DESCRIPTION: Hooks clicks on the 3D physical signboards in the world.
                 Zero screen-blocking popups. Clean, unobstructed view!
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local upgradeRemote = ReplicatedStorage:WaitForChild("UpgradeRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

-- Hook Buy Button clicks on the physical 3D signboards
local function HookSignboardClicks(base: Model)
    -- 1. Treadmill Signboard
    local tmSign = base:WaitForChild("TreadmillSignboard", 5)
    local tmBoard = tmSign and tmSign:FindFirstChild("Board")
    local tmGui = tmBoard and tmBoard:FindFirstChildOfClass("SurfaceGui")
    local tmBuy = tmGui and tmGui:FindFirstChild("BuyBtn", true)
    if tmBuy and tmBuy:IsA("GuiButton") then
        tmBuy.MouseButton1Click:Connect(function()
            upgradeRemote:FireServer("UpgradeTreadmill")
        end)
    end
    
    -- 2. Base Signboard
    local baseSign = base:WaitForChild("BaseSignboard", 5)
    local baseBoard = baseSign and baseSign:FindFirstChild("Board")
    local baseGui = baseBoard and baseBoard:FindFirstChildOfClass("SurfaceGui")
    local baseBuy = baseGui and baseGui:FindFirstChild("BuyBtn", true)
    if baseBuy and baseBuy:IsA("GuiButton") then
        baseBuy.MouseButton1Click:Connect(function()
            upgradeRemote:FireServer("UpgradeBase")
        end)
    end
end

for _, base in ipairs(bases:GetChildren()) do
    task.spawn(HookSignboardClicks, base)
end

bases.ChildAdded:Connect(function(child)
    if child:IsA("Model") then
        task.spawn(HookSignboardClicks, child)
    end
end)
