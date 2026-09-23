--!strict
--[[
    SCRIPT: SoundManager
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> Shared -> SoundManager
    DESCRIPTION: Master Audio Engine for Steal A Pet Rock!
                 Interface Contract §3.1: Play SFX with optional 3D position,
                 manage BGM transitions with smooth volume tweening.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local SoundManager = {}

-- Verified Roblox Sound Assets Library
local SOUND_CATALOG = {
    Bonk = {
        Id = "rbxassetid://132937320140224", -- Cartoon bonk impact (Verified Audio ID 132937320140224)
        Volume = 1.0,
        PlaybackSpeed = 1.0,
    },
    Crack = {
        Id = "rbxassetid://12222076", -- Rock crack / Snap
        Volume = 0.9,
        PlaybackSpeed = 1.1,
    },
    Cash = {
        Id = "rbxassetid://5153734608", -- Cha-ching / Coin
        Volume = 0.7,
        PlaybackSpeed = 1.0,
    },
    Whoosh = {
        Id = "rbxassetid://12222200", -- Speed dash whoosh
        Volume = 0.7,
        PlaybackSpeed = 1.3,
    },
    HatchStep1 = {
        Id = "rbxassetid://12222200", -- Wobble tap whoosh
        Volume = 0.6,
        PlaybackSpeed = 1.8,
    },
    HatchStep2 = {
        Id = "rbxassetid://12222076", -- Hard crack snap
        Volume = 0.9,
        PlaybackSpeed = 1.2,
    },
    HatchStep3 = {
        Id = "rbxassetid://12222253", -- Victory fanfare burst
        Volume = 1.0,
        PlaybackSpeed = 1.0,
    },
    Siren = {
        Id = "rbxassetid://9081625499", -- Nuclear alarm siren (Verified Audio)
        Volume = 0.65,
        PlaybackSpeed = 1.0,
    },
    Roar = {
        Id = "rbxassetid://133651202885353", -- Monster roar (Verified Audio)
        Volume = 0.85,
        PlaybackSpeed = 1.0,
    },
    Fanfare = {
        Id = "rbxassetid://1844584698", -- APM Winner Fanfare (Verified Audio)
        Volume = 0.85,
        PlaybackSpeed = 1.0,
    },
}

local BGM_CATALOG = {
    Base = {
        Id = "rbxassetid://9038666023", -- A Walk in the Park - Holiday (APMOfficial, 114s)
        Volume = 0.32,
    },
    StealZone = {
        Id = "rbxassetid://1845554017", -- Uptown action chase (APMOfficial, 201s)
        Volume = 0.35,
    },
    Chase = {
        Id = "rbxassetid://1845554017", -- Uptown action chase (APMOfficial, 201s)
        Volume = 0.45,
    },
}

-- Active Audio State
local currentBGM: Sound? = nil
local currentBGMTag: string? = nil
local bgmFolder: Folder? = nil

local function GetBGMFolder(): Folder
    if bgmFolder and bgmFolder.Parent then
        return bgmFolder
    end
    local existing = SoundService:FindFirstChild("MusicTracks") :: Folder?
    if existing then
        bgmFolder = existing
        return existing
    end
    local f = Instance.new("Folder")
    f.Name = "MusicTracks"
    f.Parent = SoundService
    bgmFolder = f
    return f
end

-- =============================================================================
-- INTERFACE CONTRACT §3.1: PLAY SFX
-- =============================================================================
function SoundManager.Play(soundId: string, position: Vector3?): Sound?
    local data = SOUND_CATALOG[soundId]
    if not data then
        warn(string.format("[SoundManager] Invalid soundId: '%s'", tostring(soundId)))
        return nil
    end

    local sound = Instance.new("Sound")
    sound.Name = "SFX_" .. soundId
    sound.SoundId = data.Id
    sound.Volume = data.Volume
    sound.PlaybackSpeed = data.PlaybackSpeed

    if position then
        -- 3D Spatial Audio Anchor
        local part = Instance.new("Part")
        part.Name = "AudioEmitter_" .. soundId
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Position = position
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Parent = workspace

        sound.RollOffMode = Enum.RollOffMode.Linear
        sound.RollOffMaxDistance = 80
        sound.RollOffMinDistance = 10
        sound.Parent = part
        sound:Play()

        sound.Ended:Connect(function()
            part:Destroy()
        end)
        task.delay(sound.TimeLength > 0 and (sound.TimeLength + 1) or 4, function()
            if part and part.Parent then
                part:Destroy()
            end
        end)
    else
        -- 2D Global Audio (UI / Player action)
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
        task.delay(sound.TimeLength > 0 and (sound.TimeLength + 1) or 4, function()
            if sound and sound.Parent then
                sound:Destroy()
            end
        end)
    end

    return sound
end

-- =============================================================================
-- INTERFACE CONTRACT §3.1: BGM TRANSITIONS
-- =============================================================================
function SoundManager.PlayBGM(zoneTag: "Base" | "StealZone" | "Chase")
    if currentBGMTag == zoneTag and currentBGM and currentBGM.IsPlaying then
        return
    end

    local bgmData = BGM_CATALOG[zoneTag]
    if not bgmData then return end

    local folder = GetBGMFolder()
    local oldBGM = currentBGM

    -- Fade out and destroy old BGM
    if oldBGM and oldBGM.IsPlaying then
        local fadeOut = TweenService:Create(oldBGM, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
        fadeOut:Play()
        task.delay(0.85, function()
            if oldBGM and oldBGM.Parent then
                oldBGM:Stop()
                oldBGM:Destroy()
            end
        end)
    end

    -- Fade in new BGM
    local newBGM = Instance.new("Sound")
    newBGM.Name = "BGM_" .. zoneTag
    newBGM.SoundId = bgmData.Id
    newBGM.Volume = 0
    newBGM.Looped = true
    newBGM.Parent = folder
    newBGM:Play()

    newBGM.PlaybackSpeed = bgmData.Pitch or 1.0
    local fadeIn = TweenService:Create(newBGM, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = bgmData.Volume })
    fadeIn:Play()

    currentBGM = newBGM
    currentBGMTag = zoneTag
end

function SoundManager.StopBGM()
    if currentBGM and currentBGM.IsPlaying then
        local fadeOut = TweenService:Create(currentBGM, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            if currentBGM then
                currentBGM:Stop()
                currentBGM:Destroy()
                currentBGM = nil
                currentBGMTag = nil
            end
        end)
    end
end

-- =============================================================================
-- INTERFACE CONTRACT §3.2: CLIENT-EXCLUSIVE HEIST SIREN
-- =============================================================================
local activeSiren: Sound? = nil

function SoundManager.PlaySiren()
    if activeSiren and activeSiren.IsPlaying then return end
    local folder = GetBGMFolder()
    local sound = Instance.new("Sound")
    sound.Name = "LocalSirenSFX"
    sound.SoundId = "rbxassetid://9081625499"
    sound.Volume = 0.65
    sound.Looped = true
    sound.Parent = folder
    sound:Play()
    activeSiren = sound
end

function SoundManager.StopSiren()
    if activeSiren then
        local s = activeSiren
        activeSiren = nil
        local tw = TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
        tw:Play()
        tw.Completed:Connect(function()
            s:Stop()
            s:Destroy()
        end)
    end
end

return SoundManager
