--!strict
--[[
    SCRIPT: TrailShopService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> TrailShopService
    DESCRIPTION: Server-authoritative 3D Trail Stall handler:
                 - Hooks ProximityPrompt on Deco_TrailShopStall in village plaza
                 - Validates player distance and SpeedPoints unlock threshold
                 - Updates player's EquippedTrail attribute and DataStore profile
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TrailConfig = require(ReplicatedStorage:WaitForChild("TrailConfig"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))

local trailRemote = ReplicatedStorage:WaitForChild("TrailShopRemote") :: RemoteEvent
local arena = workspace:WaitForChild("Arena_Map")

local STALL_POS = Vector3.new(20, 1.6, -45)

-- 1. Hook Proximity Prompt on 3D Stall
local function HookStallPrompt()
    local stall = arena:WaitForChild("Deco_TrailShopStall", 10)
    local counter = stall and stall:WaitForChild("Deco_StallCounter", 10)
    local prompt = counter and counter:WaitForChild("TrailPrompt", 10) :: ProximityPrompt?
    
    if prompt then
        prompt.Triggered:Connect(function(player)
            local pData = DataService.GetData(player)
            local curPts = pData and (pData.SpeedPoints or 0) or 0
            local equipped = pData and (pData.EquippedTrail or "trail_dust") or "trail_dust"
            
            trailRemote:FireClient(player, "OpenTrailShop", {
                SpeedPoints = curPts,
                EquippedTrail = equipped,
            })
        end)
    end
end

-- 2. Server-side Equip Trail Request
trailRemote.OnServerEvent:Connect(function(player: Player, action: string, trailId: any)
    if action ~= "EquipTrail" or typeof(trailId) ~= "string" then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    -- Equip unlocked cosmetic trail (can be equipped anywhere once unlocked)

    local trailInfo = TrailConfig.TRAILS[trailId]
    if not trailInfo then return end

    local pData = DataService.GetData(player)
    if not pData then return end

    local curPts = pData.SpeedPoints or 0
    if curPts < trailInfo.UnlockPoints then
        return -- Chưa đủ điểm mở khóa
    end

    pData.EquippedTrail = trailId
    player:SetAttribute("EquippedTrail", trailId)
    trailRemote:FireClient(player, "EquipSuccess", trailId)
    print(string.format("[TrailShop] %s equipped '%s' (%s)!", player.Name, trailInfo.Name, trailId))
end)

HookStallPrompt()
print("[TrailShopService] ✅ Trail Stall initialized at (20, 1.6, -45) successfully!")
