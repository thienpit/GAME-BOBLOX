--!strict
--[[
    TÊN SCRIPT: BatClientController
    LOẠI: LocalScript
    VỊ TRÍ: StarterPlayerScripts -> BatClientController
    MÔ TẢ: Giao diện Combat, Bat Shop (Bat Shop Modal), Nút vung gậy Mobile/PC,
          Kill-Feed thông báo drama và hiệu ứng khiên bảo vệ tân thủ/chống camp.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local OwnedTag = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Components"):WaitForChild("OwnedTag"))

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local batRemote = ReplicatedStorage:WaitForChild("BatRemote") :: RemoteEvent
local getBatShopInfo = ReplicatedStorage:WaitForChild("GetBatShopInfo") :: RemoteFunction

-- =============================================================================
-- 1. SCREEN GUI COMBAT & NÚT SHOP GẬY
-- =============================================================================
local combatGui = Instance.new("ScreenGui")
combatGui.Name = "CombatGui"
combatGui.ResetOnSpawn = false
combatGui.Parent = pGui

-- Nút Vung Gậy Mobile/PC
local swingBtn = Instance.new("TextButton")
swingBtn.Name = "SwingButton"
swingBtn.AnchorPoint = Vector2.new(1, 1)
swingBtn.Position = UDim2.new(1, -25, 1, -95)
swingBtn.Size = UDim2.new(0, 85, 0, 85)
swingBtn.BackgroundColor3 = Color3.fromRGB(255, 95, 45)
swingBtn.Text = "SWING\n[F]"
swingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
swingBtn.TextSize = 16
swingBtn.Font = Enum.Font.FredokaOne
swingBtn.Parent = combatGui
swingBtn.Visible = false -- UI combat không che gameplay; F/Tool.Activated vẫn xử lý Swing.

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = swingBtn

local stroke = Instance.new("UIStroke")
stroke.Thickness = 3.5
stroke.Color = Color3.fromRGB(255, 210, 80)
stroke.Parent = swingBtn

-- Nút Mở Cửa Hàng Gậy (Góc trái màn hình)
local openShopBtn = Instance.new("TextButton")
openShopBtn.Name = "OpenBatShopBtn"
openShopBtn.Position = UDim2.new(0, 20, 0.5, -30)
openShopBtn.Size = UDim2.new(0, 65, 0, 65)
openShopBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 52)
openShopBtn.Text = "🏏\nBATS"
openShopBtn.TextColor3 = Color3.fromRGB(255, 215, 60)
openShopBtn.TextSize = 14
openShopBtn.Font = Enum.Font.FredokaOne
openShopBtn.Parent = combatGui

local shopBtnCorner = Instance.new("UICorner")
shopBtnCorner.CornerRadius = UDim.new(0, 12)
shopBtnCorner.Parent = openShopBtn

local shopBtnStroke = Instance.new("UIStroke")
shopBtnStroke.Thickness = 2.5
shopBtnStroke.Color = Color3.fromRGB(255, 215, 60)
shopBtnStroke.Parent = openShopBtn

-- =============================================================================
-- 2. DRAMA KILL-FEED (GÓC TRÊN BÊN PHẢI)
-- =============================================================================
local feedFrame = Instance.new("Frame")
feedFrame.Name = "DramaFeedContainer"
feedFrame.AnchorPoint = Vector2.new(1, 0)
feedFrame.Position = UDim2.new(1, -20, 0, 25)
feedFrame.Size = UDim2.new(0, 320, 0, 150)
feedFrame.BackgroundTransparency = 1
feedFrame.Parent = combatGui

local function ShowDramaFeed(message: string)
    local msgLabel = Instance.new("TextLabel")
    msgLabel.Size = UDim2.new(1, 0, 0, 34)
    msgLabel.Position = UDim2.new(0, 40, 0, 0) -- Slide in từ bên phải
    msgLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    msgLabel.BackgroundTransparency = 0.2
    msgLabel.BorderSizePixel = 0
    msgLabel.Text = message
    msgLabel.TextColor3 = Color3.fromRGB(255, 220, 70)
    msgLabel.TextSize = 13
    msgLabel.Font = Enum.Font.FredokaOne
    msgLabel.Parent = feedFrame
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = msgLabel
    
    local s = Instance.new("UIStroke")
    s.Thickness = 2
    s.Color = Color3.fromRGB(255, 80, 50)
    s.Parent = msgLabel
    
    -- Slide in
    TweenService:Create(msgLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    
    -- Sau 3.5s thì mờ dần và tự hủy
    task.delay(3.5, function()
        local tOut = TweenService:Create(msgLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            TextTransparency = 1,
            BackgroundTransparency = 1
        })
        tOut:Play()
        tOut.Completed:Connect(function() msgLabel:Destroy() end)
    end)
end

-- =============================================================================
-- 3. CỬA HÀNG GẬY (BAT SHOP MODAL)
-- =============================================================================
local shopModal = Instance.new("Frame")
shopModal.Name = "BatShopModal"
shopModal.AnchorPoint = Vector2.new(0.5, 0.5)
shopModal.Position = UDim2.new(0.5, 0, 0.5, 0)
shopModal.Size = UDim2.new(0, 0, 0, 0)
shopModal.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
shopModal.BorderSizePixel = 0
shopModal.Visible = false
shopModal.Parent = combatGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 16)
modalCorner.Parent = shopModal

local modalStroke = Instance.new("UIStroke")
modalStroke.Thickness = 3
modalStroke.Color = Color3.fromRGB(255, 215, 60)
modalStroke.Parent = shopModal

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, 0, 0, 45)
modalTitle.Position = UDim2.new(0, 0, 0, 8)
modalTitle.Text = "🏏 BAT ARMORY SHOP"
modalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
modalTitle.TextSize = 20
modalTitle.Font = Enum.Font.FredokaOne
modalTitle.BackgroundTransparency = 1
modalTitle.Parent = shopModal

local closeShopBtn = Instance.new("TextButton")
closeShopBtn.AnchorPoint = Vector2.new(1, 0)
closeShopBtn.Position = UDim2.new(1, -12, 0, 12)
closeShopBtn.Size = UDim2.new(0, 36, 0, 36)
closeShopBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeShopBtn.Text = "X"
closeShopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeShopBtn.TextSize = 18
closeShopBtn.Font = Enum.Font.FredokaOne
closeShopBtn.Parent = shopModal

local closeC = Instance.new("UICorner")
closeC.CornerRadius = UDim.new(0, 8)
closeC.Parent = closeShopBtn

local cardContainer = Instance.new("Frame")
cardContainer.Position = UDim2.new(0.04, 0, 0.2, 0)
cardContainer.Size = UDim2.new(0.92, 0, 0.74, 0)
cardContainer.BackgroundTransparency = 1
cardContainer.Parent = shopModal

local uil = Instance.new("UIListLayout")
uil.FillDirection = Enum.FillDirection.Horizontal
uil.Padding = UDim.new(0, 10)
uil.SortOrder = Enum.SortOrder.LayoutOrder
uil.Parent = cardContainer

local function RefreshShop()
    local info = getBatShopInfo:InvokeServer()
    if not info then return end
    
    cardContainer:ClearAllChildren()
    uil:Clone().Parent = cardContainer
    
    local batIcons = {
        wooden_bat = "🪵",
        baseball_bat = "⚾",
        iron_bat = "⚔️",
        golden_bat = "👑",
    }
    
    local batOrder = { "wooden_bat", "baseball_bat", "iron_bat", "golden_bat" }
    for idx, batId in ipairs(batOrder) do
        local bCfg = info.Catalog[batId]
        if bCfg then
            local isOwned = table.find(info.OwnedBats, batId) ~= nil
            local isEquipped = (info.EquippedBat == batId)
            
            local bCard = Instance.new("Frame")
            bCard.Name = batId
            bCard.Size = UDim2.new(0.23, 0, 1, 0)
            bCard.BackgroundColor3 = UITheme.Colors.CardBg
            bCard.BorderSizePixel = 0
            bCard.LayoutOrder = idx
            bCard.Parent = cardContainer
            
            UITheme.ApplyCorner(bCard, UITheme.CornerRadiusSmall)
            UITheme.ApplyStroke(bCard, isEquipped and UITheme.Colors.Money or (isOwned and UITheme.Colors.Positive or UITheme.Colors.SubtleBorder), UITheme.StrokeThicknessThin)

            -- Bat Icon centered
            local bIcon = Instance.new("TextLabel")
            bIcon.Name = "BatIcon"
            bIcon.Size = UDim2.new(1, 0, 0, 32)
            bIcon.Position = UDim2.new(0, 0, 0, 8)
            bIcon.BackgroundTransparency = 1
            bIcon.Text = batIcons[batId] or "🏏"
            bIcon.TextSize = 26
            bIcon.Parent = bCard

            -- Mini status tag at top right
            if isEquipped then
                local miniTag = Instance.new("TextLabel")
                miniTag.Name = "MiniTag"
                miniTag.Size = UDim2.new(0, 48, 0, 16)
                miniTag.Position = UDim2.new(1, -4, 0, 4)
                miniTag.AnchorPoint = Vector2.new(1, 0)
                miniTag.BackgroundColor3 = UITheme.Colors.Money
                miniTag.Font = UITheme.Fonts.Header
                miniTag.Text = "ACTIVE"
                miniTag.TextColor3 = Color3.new(0, 0, 0)
                miniTag.TextSize = 8
                miniTag.Parent = bCard
                UITheme.ApplyCorner(miniTag, UDim.new(0, 4))
            elseif isOwned then
                local miniTag = Instance.new("TextLabel")
                miniTag.Name = "MiniTag"
                miniTag.Size = UDim2.new(0, 48, 0, 16)
                miniTag.Position = UDim2.new(1, -4, 0, 4)
                miniTag.AnchorPoint = Vector2.new(1, 0)
                miniTag.BackgroundColor3 = UITheme.Colors.Positive
                miniTag.Font = UITheme.Fonts.Header
                miniTag.Text = "OWNED"
                miniTag.TextColor3 = UITheme.Colors.White
                miniTag.TextSize = 8
                miniTag.Parent = bCard
                UITheme.ApplyCorner(miniTag, UDim.new(0, 4))
            end
            
            local bName = Instance.new("TextLabel")
            bName.Size = UDim2.new(1, -6, 0, 20)
            bName.Position = UDim2.new(0, 3, 0, 42)
            bName.Text = string.upper(bCfg.Name)
            bName.TextColor3 = isEquipped and UITheme.Colors.Money or UITheme.Colors.White
            bName.TextStrokeColor3 = UITheme.Colors.StrokeOutline
            bName.TextStrokeTransparency = 0.4
            bName.TextSize = 12
            bName.Font = UITheme.Fonts.Header
            bName.BackgroundTransparency = 1
            bName.TextTruncate = Enum.TextTruncate.AtEnd
            bName.Parent = bCard
            
            local bStats = Instance.new("TextLabel")
            bStats.Size = UDim2.new(1, -8, 0, 56)
            bStats.Position = UDim2.new(0, 4, 0, 64)
            bStats.Text = string.format("Rng: %.1f • KB: %d\nStun: %.1fs\nCD: %.1fs", bCfg.Range, bCfg.Knockback, bCfg.StunDuration, bCfg.Cooldown)
            bStats.TextColor3 = UITheme.Colors.Muted
            bStats.TextSize = 10
            bStats.Font = UITheme.Fonts.Body
            bStats.BackgroundTransparency = 1
            bStats.Parent = bCard
            
            local actBtn = Instance.new("TextButton")
            actBtn.AnchorPoint = Vector2.new(0.5, 1)
            actBtn.Position = UDim2.new(0.5, 0, 1, -8)
            actBtn.Size = UDim2.new(0.88, 0, 0, 32)
            actBtn.Font = UITheme.Fonts.Header
            actBtn.TextSize = 12
            actBtn.Parent = bCard
            
            UITheme.ApplyCorner(actBtn, UDim.new(0, 6))
            
            if isEquipped then
                actBtn.Text = "EQUIPPED"
                actBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 75)
                actBtn.TextColor3 = Color3.fromRGB(160, 160, 160)
            elseif isOwned then
                actBtn.Text = "EQUIP"
                actBtn.BackgroundColor3 = UITheme.Colors.Awakened
                actBtn.TextColor3 = Color3.fromRGB(10, 20, 30)
                actBtn.MouseButton1Click:Connect(function()
                    batRemote:FireServer("EquipBat", batId)
                end)
            else
                actBtn.Text = "$" .. UITheme.FormatNumber(bCfg.Price)
                actBtn.BackgroundColor3 = (info.Money >= bCfg.Price) and UITheme.Colors.Positive or Color3.fromRGB(140, 50, 50)
                actBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                actBtn.MouseButton1Click:Connect(function()
                    batRemote:FireServer("BuyBat", batId)
                end)
            end
        end
    end
end

local function OpenShop()
    RefreshShop()
    shopModal.Visible = true
    TweenService:Create(shopModal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 520, 0, 280)
    }):Play()
end

local function CloseShop()
    local tOut = TweenService:Create(shopModal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    tOut:Play()
    tOut.Completed:Wait()
    shopModal.Visible = false
end

openShopBtn.MouseButton1Click:Connect(OpenShop)
closeShopBtn.MouseButton1Click:Connect(CloseShop)

-- Expose global function cho Dock mở trực tiếp
_G.OpenBatShop = OpenShop

-- Tự động ẩn nút rời khi Dock đã có nút Bat
task.spawn(function()
    task.wait(0.5)
    openShopBtn.Visible = false
end)

-- =============================================================================
-- 4. VUNG GẬY & HIỆU ỨNG COMBAT
-- =============================================================================
local isSwinging = false
local function TriggerSwing()
    if isSwinging then return end
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return end
    
    isSwinging = true
    batRemote:FireServer("SwingBat")
    
    TweenService:Create(swingBtn, TweenInfo.new(0.08, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 72, 0, 72)}):Play()
    task.delay(0.08, function()
        TweenService:Create(swingBtn, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 85, 0, 85)}):Play()
    end)
    
    local handle = tool:FindFirstChild("Handle") :: BasePart?
    if handle then
        local origCFrame = tool.Grip
        tool.Grip = origCFrame * CFrame.Angles(math.rad(-60), math.rad(45), 0)
        task.delay(0.18, function()
            tool.Grip = origCFrame
            isSwinging = false
        end)
    else
        task.delay(0.2, function() isSwinging = false end)
    end
end

swingBtn.MouseButton1Click:Connect(TriggerSwing)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then TriggerSwing() end
end)

local function HookTool(tool: Tool)
    tool.Activated:Connect(TriggerSwing)
end

player.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then HookTool(child) end
    end)
end)
if player.Character and player.Character:FindFirstChildOfClass("Tool") then
    HookTool(player.Character:FindFirstChildOfClass("Tool") :: Tool)
end

-- =============================================================================
-- 5. BẮT SỰ KIỆN TỪ SERVER (DRAMA FEED, SHOP REFRESH, VFX)
-- =============================================================================
batRemote.OnClientEvent:Connect(function(action: string, arg1: any, arg2: any, arg3: any)
    if action == "ActionFeed" then
        ShowDramaFeed(tostring(arg1))
    elseif action == "ShopRefresh" then
        if shopModal.Visible then RefreshShop() end
    elseif action == "GraceActivated" then
        ShowDramaFeed("🛡️ SPAWN IMMUNITY ACTIVE (3s)!")
    elseif action == "PlayHitVFX" then
        local hitPos: Vector3 = arg1
        local victimName: string = arg3
        
        local spark = Instance.new("Part")
        spark.Size = Vector3.new(1.2, 1.2, 1.2)
        spark.Position = hitPos + Vector3.new(0, 1.5, 0)
        spark.Shape = Enum.PartType.Ball
        spark.Material = Enum.Material.Neon
        spark.Color = Color3.fromRGB(255, 220, 50)
        spark.Anchored = true
        spark.CanCollide = false
        spark.Parent = workspace
        
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://6042053626"
        sound.Volume = 1.0
        sound.Parent = spark
        sound:Play()
        
        TweenService:Create(spark, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(4, 4, 4),
            Transparency = 1
        }):Play()
        task.delay(0.3, function() spark:Destroy() end)
        
        if victimName == player.Name then
            task.spawn(function()
                for i = 1, 3 do
                    local rx = (math.random() - 0.5) * 0.04
                    local ry = (math.random() - 0.5) * 0.04
                    camera.CFrame = camera.CFrame * CFrame.Angles(rx, ry, 0)
                    task.wait(0.04)
                end
            end)
        end
    end
end)
