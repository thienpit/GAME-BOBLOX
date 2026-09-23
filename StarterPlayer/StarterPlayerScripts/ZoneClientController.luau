local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local pGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "ZoneNotificationGui"
gui.ResetOnSpawn = false
gui.Parent = pGui

-- Pure Floating Text Announcement
local textLabel = Instance.new("TextLabel")
textLabel.Name = "AnnouncementText"
textLabel.AnchorPoint = Vector2.new(0.5, 0)
textLabel.Position = UDim2.new(0.5, 0, 0, 22)
textLabel.Size = UDim2.new(0, 700, 0, 42)
textLabel.BackgroundTransparency = 1
textLabel.Font = Enum.Font.FredokaOne
textLabel.TextSize = 25
textLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
textLabel.TextStrokeTransparency = 1
textLabel.TextTransparency = 1
textLabel.Text = ""
textLabel.Parent = gui

local currentZone = ""
local currentTween = nil

local function ShowAnnouncement(text, textColor)
    if not text or text == "" then return end
    if currentTween then currentTween:Cancel() end
    
    textLabel.Text = text
    textLabel.TextColor3 = textColor or Color3.fromRGB(255, 220, 50)
    
    TweenService:Create(textLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        TextStrokeTransparency = 0.3
    }):Play()
    
    task.delay(2.6, function()
        if textLabel.Text == text then
            currentTween = TweenService:Create(textLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                TextTransparency = 1,
                TextStrokeTransparency = 1
            })
            currentTween:Play()
        end
    end)
end

-- Detect Zone / Base
local arena = workspace:WaitForChild("Arena_Map")
local bases = arena:WaitForChild("Bases")

local function GetCurrentLocation(pos)
    local pZ = pos.Z
    local pX = pos.X
    
    if pZ > -5 then
        if pZ <= 75 then
            return "🌲 MOSSY FOREST (ZONE 1)", Color3.fromRGB(100, 255, 110)
        elseif pZ <= 185 then
            return "🔮 OBSIDIAN GROTTO (ZONE 2)", Color3.fromRGB(195, 100, 255)
        elseif pZ <= 335 then
            return "🔥 MAGMA VALLEY (ZONE 3)", Color3.fromRGB(255, 90, 50)
        else
            return "🏛️ COSMIC TEMPLE (ZONE 4)", Color3.fromRGB(255, 220, 50)
        end
    else
        for i = 1, 6 do
            local base = bases:FindFirstChild("Base_" .. i)
            local floor = base and base:FindFirstChild("BaseFloor")
            if floor then
                local bX = floor.Position.X
                local bZ = floor.Position.Z
                if math.abs(pX - bX) <= 29 and math.abs(pZ - bZ) <= 29 then
                    local ownerName = base:GetAttribute("OwnerName")
                    if ownerName and ownerName ~= "" then
                        if ownerName == player.Name then
                            return "🏡 YOUR BASE", Color3.fromRGB(100, 255, 120)
                        else
                            return "🏡 " .. string.upper(ownerName) .. "'S BASE", Color3.fromRGB(255, 185, 75)
                        end
                    else
                        -- Empty plot: silent, no notification!
                        return "", nil
                    end
                end
            end
        end
        return "🏰 GRAND PROMENADE", Color3.fromRGB(150, 220, 255)
    end
end

task.spawn(function()
    while true do
        task.wait(0.35)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local locName, locColor = GetCurrentLocation(hrp.Position)
            if locName and locName ~= "" and locName ~= currentZone then
                currentZone = locName
                ShowAnnouncement(locName, locColor)
            elseif locName == "" then
                currentZone = ""
            end
        end
    end
end)
