--!strict
--[[
    SCRIPT: ShopClientController
    TYPE: LocalScript
    LOCATION: StarterPlayerScripts -> ShopClientController
    DESCRIPTION: Robux Store UI with 2D Gamepass & Product graphic thumbnails.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")
local monetizationRemote = ReplicatedStorage:WaitForChild("MonetizationRemote") :: RemoteEvent
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UITheme"))
local OwnedTag = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Components"):WaitForChild("OwnedTag"))

-- 1. SCREEN GUI SHOP ROBUX
local shopGui = Instance.new("ScreenGui")
shopGui.Name = "RobuxShopGui"
shopGui.ResetOnSpawn = false
shopGui.Parent = pGui

local shopBtn = Instance.new("TextButton")
shopBtn.Name = "OpenRobuxShopBtn"
shopBtn.Position = UDim2.new(0, 20, 0.5, 45)
shopBtn.Size = UDim2.new(0, 65, 0, 65)
shopBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 65)
shopBtn.Text = "💎\nSHOP"
shopBtn.TextColor3 = Color3.fromRGB(80, 220, 255)
shopBtn.TextSize = 14
shopBtn.Font = Enum.Font.FredokaOne
shopBtn.Visible = true
shopBtn.Parent = shopGui

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(0, 12)
sCorner.Parent = shopBtn

local sStroke = Instance.new("UIStroke")
sStroke.Thickness = 2.5
sStroke.Color = Color3.fromRGB(0, 200, 255)
sStroke.Parent = shopBtn

local modal = Instance.new("Frame")
modal.Name = "ShopModal"
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.Size = UDim2.new(0, 0, 0, 0)
modal.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
modal.BorderSizePixel = 0
modal.Visible = false
modal.Parent = shopGui

local mCorner = Instance.new("UICorner")
mCorner.CornerRadius = UDim.new(0, 16)
mCorner.Parent = modal

local mStroke = Instance.new("UIStroke")
mStroke.Thickness = 3
mStroke.Color = Color3.fromRGB(0, 200, 255)
mStroke.Parent = modal

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 48)
title.Position = UDim2.new(0, 0, 0, 8)
title.Text = "💎 ROBUX STORE (PASSES & BOOSTS)"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 19
title.Font = Enum.Font.FredokaOne
title.BackgroundTransparency = 1
title.Parent = modal

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -12, 0, 12)
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Parent = modal

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 8)
cCorner.Parent = closeBtn

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -30, 1, -75)
scroll.Position = UDim2.new(0, 15, 0, 65)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 460)
scroll.Parent = modal

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 210, 0, 195)
grid.CellPadding = UDim2.new(0, 12, 0, 12)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.Parent = scroll

local function CreateStoreCard(itemData: any)
    local card = Instance.new("Frame")
    card.Name = "Card_" .. itemData.Id
    card.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
    card.BorderSizePixel = 0
    card.Parent = scroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(60, 75, 100)
    stroke.Parent = card

    local thumb = Instance.new("ImageLabel")
    thumb.Name = "Thumbnail"
    thumb.Size = UDim2.new(1, -16, 0, 75)
    thumb.Position = UDim2.new(0, 8, 0, 8)
    thumb.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
    thumb.BorderSizePixel = 0
    thumb.Image = itemData.Icon or ""
    thumb.ScaleType = Enum.ScaleType.Fit
    thumb.Parent = card

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 8)
    tCorner.Parent = thumb

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -16, 0, 22)
    nameLbl.Position = UDim2.new(0, 8, 0, 88)
    nameLbl.Text = itemData.Name
    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLbl.TextSize = 13
    nameLbl.Font = Enum.Font.FredokaOne
    nameLbl.TextWrapped = true
    nameLbl.BackgroundTransparency = 1
    nameLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -16, 0, 28)
    descLbl.Position = UDim2.new(0, 8, 0, 110)
    descLbl.Text = itemData.Desc
    descLbl.TextColor3 = Color3.fromRGB(160, 175, 195)
    descLbl.TextSize = 10
    descLbl.Font = Enum.Font.GothamBold
    descLbl.TextWrapped = true
    descLbl.BackgroundTransparency = 1
    descLbl.Parent = card

    local buyBtn = Instance.new("TextButton")
    buyBtn.Name = "BuyBtn"
    buyBtn.Size = UDim2.new(1, -16, 0, 34)
    buyBtn.Position = UDim2.new(0, 8, 1, -42)
    buyBtn.BackgroundColor3 = Color3.fromRGB(0, 185, 90)
    buyBtn.Text = "R$ " .. itemData.Price
    buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    buyBtn.TextSize = 14
    buyBtn.Font = Enum.Font.FredokaOne
    buyBtn.Parent = card

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = buyBtn

    local isOwned = false
    if itemData.Type == "Gamepass" and itemData.Attr then
        isOwned = player:GetAttribute(itemData.Attr) == true
        if isOwned then
            OwnedTag.Apply(card, UDim2.new(1, -8, 0, 8))
            buyBtn.Text = "OWNED"
            buyBtn.BackgroundColor3 = Color3.fromRGB(50, 60, 75)
            buyBtn.AutoButtonColor = false
        end
    end

    buyBtn.MouseButton1Click:Connect(function()
        if isOwned then return end
        monetizationRemote:FireServer("PurchaseItem", itemData.Id)
    end)
end

for passKey, passInfo in pairs(MonetizationConfig.GAMEPASSES) do
    CreateStoreCard({
        Id = passInfo.Id,
        Name = passInfo.Name,
        Desc = passInfo.Description,
        Price = 149,
        Icon = passInfo.IconAssetId,
        Type = "Gamepass",
        Attr = passInfo.AttributeKey,
    })
end

for prodId, prodInfo in pairs(MonetizationConfig.PRODUCTS) do
    CreateStoreCard({
        Id = prodInfo.Id,
        Name = prodInfo.Name,
        Desc = prodInfo.Description,
        Price = 49,
        Icon = prodInfo.IconAssetId,
        Type = "Product",
    })
end

local isOpen = false
local function ToggleShop()
    isOpen = not isOpen
    if isOpen then
        modal.Visible = true
        modal.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 480, 0, 440)
        }):Play()
    else
        local tw = TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        tw:Play()
        tw.Completed:Connect(function()
            if not isOpen then modal.Visible = false end
        end)
    end
end

shopBtn.MouseButton1Click:Connect(ToggleShop)
closeBtn.MouseButton1Click:Connect(ToggleShop)
