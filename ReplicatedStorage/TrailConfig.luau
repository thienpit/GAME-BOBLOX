--!strict
--[[
    SCRIPT: TrailConfig
    TYPE: ModuleScript
    LOCATION: ReplicatedStorage -> TrailConfig
    DESCRIPTION: Master configuration for Speed Trails:
                 - 6 progression tiers unlocked by SpeedPoints
                 - Multipliers applied to treadmill training (1.0x to 30.0x)
                 - Trail ColorSequences, LightEmission, and Lifetimes
]]

export type TrailInfo = {
    Id: string,
    Name: string,
    UnlockPoints: number,
    Multiplier: number,
    Color: ColorSequence,
    Lifetime: number,
    LightEmission: number,
}

local TrailConfig = {}

TrailConfig.TRAILS = {
    trail_dust = {
        Id = "trail_dust",
        Name = "Rookie Dust 💨",
        UnlockPoints = 0,
        Multiplier = 1.0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(230, 215, 190)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 155, 130))
        }),
        Lifetime = 0.5,
        LightEmission = 0.1,
    },
    trail_neon = {
        Id = "trail_neon",
        Name = "Blue Lightning Trail ⚡",
        UnlockPoints = 10000,
        Multiplier = 1.5,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 240, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 120, 255))
        }),
        Lifetime = 0.8,
        LightEmission = 0.8,
    },
    trail_fire = {
        Id = "trail_fire",
        Name = "Inferno Flame Trail 🔥",
        UnlockPoints = 500000,
        Multiplier = 2.5,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 10))
        }),
        Lifetime = 1.0,
        LightEmission = 0.85,
    },
    trail_void = {
        Id = "trail_void",
        Name = "Void Shadow Trail 🔮",
        UnlockPoints = 25000000,
        Multiplier = 5.0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 100, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 20, 160))
        }),
        Lifetime = 1.2,
        LightEmission = 0.9,
    },
    trail_star = {
        Id = "trail_star",
        Name = "Stardust Trail ⭐",
        UnlockPoints = 1000000000,
        Multiplier = 12.0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 90)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 20))
        }),
        Lifetime = 1.5,
        LightEmission = 1.0,
    },
    trail_quantum = {
        Id = "trail_quantum",
        Name = "Quantum Rainbow Trail 🌈",
        UnlockPoints = 50000000000,
        Multiplier = 30.0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 120)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 40)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(40, 230, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 60, 255)),
        }),
        Lifetime = 1.8,
        LightEmission = 1.0,
    }
} :: { [string]: TrailInfo }

TrailConfig.ORDER = {
    "trail_dust",
    "trail_neon",
    "trail_fire",
    "trail_void",
    "trail_star",
    "trail_quantum"
}

-- Tự động trả về Trail cao nhất mà người chơi đã mở khóa dựa trên SpeedPoints
function TrailConfig.GetTrailForPoints(points: number): TrailInfo
    local pts = points or 0
    local highest: TrailInfo = TrailConfig.TRAILS["trail_dust"]
    
    for _, tId in ipairs(TrailConfig.ORDER) do
        local info = TrailConfig.TRAILS[tId]
        if info and pts >= info.UnlockPoints then
            highest = info
        end
    end
    
    return highest
end

function TrailConfig.GetMultiplier(trailId: string?): number
    if not trailId then return 1.0 end
    local info = TrailConfig.TRAILS[trailId]
    return info and info.Multiplier or 1.0
end

return TrailConfig
