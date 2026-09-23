--!strict
--[[
    SCRIPT: RagdollHandler
    TYPE: ModuleScript
    LOCATION: ServerScriptService -> RagdollHandler
    DESCRIPTION: Physics-driven Ragdoll Meme Handler for Steal A Pet Rock!
                 Converts Motor6D joints to BallSocketConstraints on hit,
                 launches player ragdoll into the air, and recovers smoothly after 1.5s.
]]

local RagdollHandler = {}

type RagdollSession = {
    Motors: { Motor6D },
    Sockets: { BallSocketConstraint },
    Attachments: { Attachment },
    EndTime: number,
}

local activeSessions: { [Model]: RagdollSession } = {}

-- Applies smooth physics ragdoll to character
function RagdollHandler.StartRagdoll(char: Model, duration: number?, impulseVelocity: Vector3?)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hum or not hrp or hum.Health <= 0 then return end
    
    -- If already ragdolled, renew session duration
    if activeSessions[char] then
        activeSessions[char].EndTime = os.clock() + (duration or 1.5)
        if impulseVelocity then
            hrp.AssemblyLinearVelocity = impulseVelocity
        end
        return
    end

    local motors: { Motor6D } = {}
    local sockets: { BallSocketConstraint } = {}
    local attachments: { Attachment } = {}

    -- Convert Motor6D to BallSocketConstraints
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") and desc.Name ~= "RootJoint" and desc.Part0 and desc.Part1 then
            desc.Enabled = false
            table.insert(motors, desc)

            local att0 = Instance.new("Attachment")
            att0.Name = "RagdollAtt0_" .. desc.Name
            att0.CFrame = desc.C0
            att0.Parent = desc.Part0
            table.insert(attachments, att0)

            local att1 = Instance.new("Attachment")
            att1.Name = "RagdollAtt1_" .. desc.Name
            att1.CFrame = desc.C1
            att1.Parent = desc.Part1
            table.insert(attachments, att1)

            local socket = Instance.new("BallSocketConstraint")
            socket.Name = "RagdollSocket_" .. desc.Name
            socket.Attachment0 = att0
            socket.Attachment1 = att1
            socket.LimitsEnabled = true
            socket.UpperAngle = 45
            socket.TwistLimitsEnabled = true
            socket.TwistLowerAngle = -30
            socket.TwistUpperAngle = 30
            socket.Parent = desc.Part0
            table.insert(sockets, socket)
        end
    end

    hum.AutoRotate = false
    hum.PlatformStand = true
    hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
    char:SetAttribute("IsRagdolled", true)

    if impulseVelocity then
        hrp.AssemblyLinearVelocity = impulseVelocity
    end

    local ragDuration = duration or 1.5
    local session: RagdollSession = {
        Motors = motors,
        Sockets = sockets,
        Attachments = attachments,
        EndTime = os.clock() + ragDuration,
    }
    activeSessions[char] = session

    task.delay(ragDuration, function()
        if activeSessions[char] and os.clock() >= activeSessions[char].EndTime then
            RagdollHandler.StopRagdoll(char)
        end
    end)
end

-- Recovers character from ragdoll smoothly
function RagdollHandler.StopRagdoll(char: Model)
    local session = activeSessions[char]
    if not session then return end
    activeSessions[char] = nil

    -- Clean up physics constraints
    for _, socket in ipairs(session.Sockets) do
        if socket and socket.Parent then socket:Destroy() end
    end
    for _, att in ipairs(session.Attachments) do
        if att and att.Parent then att:Destroy() end
    end
    for _, motor in ipairs(session.Motors) do
        if motor and motor.Parent then motor.Enabled = true end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hum and hum.Health > 0 and hrp then
        -- Upright recovery without clipping
        hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, hrp.CFrame.Rotation.Y, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        hum.PlatformStand = false
        hum.AutoRotate = true
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end

    char:SetAttribute("IsRagdolled", false)
end

return RagdollHandler
