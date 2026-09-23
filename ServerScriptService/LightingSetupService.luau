--!strict
--[[
    SCRIPT: LightingSetupService
    TYPE: Script (Server-side)
    LOCATION: ServerScriptService -> LightingSetupService
    DESCRIPTION: Master visual lighting, atmosphere, and post-processing setup.
                 Applies AAA cartoon studio lighting inspired by Pet Simulator & Steal a Pet.
]]

local Lighting = game:GetService("Lighting")

local function ApplyLighting()
    -- 1. Lighting properties
    Lighting.Ambient = Color3.fromRGB(110, 105, 120)
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
    Lighting.Brightness = 2.4
    Lighting.ClockTime = 14.5
    Lighting.GeographicLatitude = 35
    Lighting.ExposureCompensation = 0.15
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = 0.2
    
    pcall(function()
        Lighting.Technology = Enum.Technology.Future
    end)

    -- Clean up legacy/duplicate effects to keep a single authoritative set
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
            child:Destroy()
        end
    end

    -- 2. Atmosphere
    local atmosphere = Instance.new("Atmosphere")
    atmosphere.Name = "GameAtmosphere"
    atmosphere.Density = 0.3
    atmosphere.Offset = 0.25
    atmosphere.Color = Color3.fromRGB(199, 170, 143)
    atmosphere.Decay = Color3.fromRGB(92, 108, 138)
    atmosphere.Glare = 0.3
    atmosphere.Haze = 1.4
    atmosphere.Parent = Lighting

    -- 3. Sky
    local sky = Instance.new("Sky")
    sky.Name = "StylizedSky"
    sky.StarCount = 3000
    sky.CelestialBodiesShown = true
    sky.SunAngularSize = 11
    sky.MoonAngularSize = 11
    sky.Parent = Lighting

    -- 4. Post-processing effects
    local colorCorrection = Instance.new("ColorCorrectionEffect")
    colorCorrection.Name = "WarmColorCorrection"
    colorCorrection.Brightness = 0.02
    colorCorrection.Contrast = 0.12
    colorCorrection.Saturation = 0.18
    colorCorrection.TintColor = Color3.fromRGB(255, 246, 235)
    colorCorrection.Parent = Lighting

    local bloom = Instance.new("BloomEffect")
    bloom.Name = "DreamyBloom"
    bloom.Intensity = 0.55
    bloom.Size = 24
    bloom.Threshold = 1.35
    bloom.Parent = Lighting

    local sunRays = Instance.new("SunRaysEffect")
    sunRays.Name = "AtmosphericSunRays"
    sunRays.Intensity = 0.18
    sunRays.Spread = 0.65
    sunRays.Parent = Lighting

    local depthOfField = Instance.new("DepthOfFieldEffect")
    depthOfField.Name = "CinematicDoF"
    depthOfField.FarIntensity = 0.35
    depthOfField.FocusDistance = 45
    depthOfField.InFocusRadius = 30
    depthOfField.NearIntensity = 0
    depthOfField.Parent = Lighting

    print("[LightingSetupService] ✅ High-fidelity cartoon lighting & atmosphere applied successfully!")
end

ApplyLighting()
