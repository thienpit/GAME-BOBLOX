--!strict
--[[
    SCRIPT: BaseService
    TYPE: ModuleScript
    LOCATION: ServerScriptService -> BaseService
    DESCRIPTION: Single authoritative writer for Base ownership (OwnerUserId, OwnerName).
                 ALL other scripts MUST go through this module to claim, release, or query bases.
                 NO other script may set OwnerUserId or OwnerName directly.
]]

local Players = game:GetService("Players")

local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

local BaseService = {}

-- Internal cache: Player -> Base Model
local playerBases: { [Player]: Model } = {}

-- =========================================================================
-- CLAIM: Assign the first available base to a player. Returns base or nil.
-- =========================================================================
function BaseService.ClaimBase(player: Player): Model?
    -- Already owns a base?
    if playerBases[player] then
        return playerBases[player]
    end

    for i = 1, 6 do
        local base = bases:FindFirstChild("Base_" .. i)
        if base and (base:GetAttribute("OwnerUserId") == 0 or base:GetAttribute("OwnerUserId") == nil) then
            base:SetAttribute("OwnerUserId", player.UserId)
            base:SetAttribute("OwnerName", player.Name)
            playerBases[player] = base
            return base
        end
    end
    return nil -- No free base
end

-- =========================================================================
-- RELEASE: Clear ownership when a player leaves.
-- =========================================================================
function BaseService.ReleaseBase(player: Player)
    local base = playerBases[player]
    if base then
        base:SetAttribute("OwnerUserId", 0)
        base:SetAttribute("OwnerName", "")
        base:SetAttribute("IncomePerSec", 0)
        base:SetAttribute("RockCount", 0)

        local rocksFolder = base:FindFirstChild("PetRocks")
        if rocksFolder then rocksFolder:ClearAllChildren() end

        local eggsFolder = base:FindFirstChild("IncubatingEggs")
        if eggsFolder then eggsFolder:ClearAllChildren() end
    end
    playerBases[player] = nil
end

-- =========================================================================
-- GET: Read-only lookup. Never writes ownership.
-- =========================================================================
function BaseService.GetPlayerBase(player: Player): Model?
    if playerBases[player] then
        return playerBases[player]
    end

    -- Scan for already-assigned base (e.g. after script restart)
    for _, base in ipairs(bases:GetChildren()) do
        if base:GetAttribute("OwnerUserId") == player.UserId then
            playerBases[player] = base
            return base
        end
    end
    return nil
end

-- =========================================================================
-- GET OR CLAIM: Convenience wrapper — returns existing base or claims new one.
-- =========================================================================
function BaseService.GetOrClaimBase(player: Player): Model?
    return BaseService.GetPlayerBase(player) or BaseService.ClaimBase(player)
end

-- =========================================================================
-- IS OWNER: Check if player owns a specific base.
-- =========================================================================
function BaseService.IsOwner(player: Player, base: Model): boolean
    return base:GetAttribute("OwnerUserId") == player.UserId
end

-- =========================================================================
-- INTERNAL CACHE ACCESS (for carry cleanup on RockGameManager)
-- =========================================================================
function BaseService.GetCachedBase(player: Player): Model?
    return playerBases[player]
end

function BaseService.SetCachedBase(player: Player, base: Model?)
    playerBases[player] = base
end

return BaseService
