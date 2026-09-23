--!strict
--[[
    TÊN SCRIPT: GridSellPanel
    LOẠI: ModuleScript
    VỊ TRÍ: ReplicatedStorage -> Shared -> Components -> GridSellPanel
    MÔ TẢ: Grid Card Panel chuẩn hóa phong cách Simulator (tham khảo phong cách Pet Sim / Steal a Brainrot).
          Hiển thị danh sách item theo dạng lưới đều nhau, mỗi card tự chứa đủ thông tin
          (Ảnh/Icon, Rarity, Weight, Value) kèm nút thao tác riêng và thanh tổng kết ở đáy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UITheme = require(ReplicatedStorage.Shared.UITheme)

export type GridItemData = {
    Id: string,
    Name: string,
    Icon: string,
    Rarity: string?,
    RarityColor: Color3?,
    Weight: number?,
    Value: number?,
    ExtraText: string?,
    IsSelected: boolean?,
}

export type GridSellPanelConfig = {
    Title: string,
    Subtitle: string?,
    ActionText: string?,
    Size: UDim2?,
    Position: UDim2?,
    Parent: GuiObject | ScreenGui?,
}

local GridSellPanel = {}
GridSellPanel.__index = GridSellPanel

function GridSellPanel.new(config: GridSellPanelConfig)
    local self = setmetatable({}, GridSellPanel)

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "GridSellPanel"
    mainFrame.Size = config.Size or UDim2.new(0, 520, 0, 420)
    mainFrame.Position = config.Position or UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = UITheme.Colors.DarkBg
    mainFrame.BorderSizePixel = 0

    local corner = UITheme.ApplyCorner(mainFrame, UITheme.CornerRadius)
    local stroke = UITheme.ApplyStroke(mainFrame, UITheme.Colors.SubtleBorder, UITheme.StrokeThicknessThick)

    -- Header
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Name = "HeaderLabel"
    headerLabel.Size = UDim2.new(1, -60, 0, 40)
    headerLabel.Position = UDim2.new(0, 20, 0, 10)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Font = UITheme.Fonts.Header
    headerLabel.Text = string.upper(config.Title)
    headerLabel.TextColor3 = UITheme.Colors.White
    headerLabel.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    headerLabel.TextStrokeTransparency = 0.3
    headerLabel.TextSize = 20
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = mainFrame

    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 36, 0, 36)
    closeBtn.Position = UDim2.new(1, -16, 0, 12)
    closeBtn.AnchorPoint = Vector2.new(1, 0)
    closeBtn.BackgroundColor3 = UITheme.Colors.Danger
    closeBtn.Font = UITheme.Fonts.Header
    closeBtn.Text = "X"
    closeBtn.TextColor3 = UITheme.Colors.White
    closeBtn.TextSize = 18
    closeBtn.Parent = mainFrame
    UITheme.ApplyCorner(closeBtn, UITheme.CornerRadiusSmall)

    -- Scrolling Frame for Grid Cards
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ItemsScroll"
    scrollFrame.Size = UDim2.new(1, -32, 1, -120)
    scrollFrame.Position = UDim2.new(0, 16, 0, 52)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = UITheme.Colors.SubtleBorder
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = mainFrame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 112, 0, 140)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = scrollFrame

    -- Bottom Bar: Action Button (e.g. SELL ALL)
    local bottomBar = Instance.new("Frame")
    bottomBar.Name = "BottomBar"
    bottomBar.Size = UDim2.new(1, -32, 0, 48)
    bottomBar.Position = UDim2.new(0, 16, 1, -60)
    bottomBar.BackgroundTransparency = 1
    bottomBar.Parent = mainFrame

    local actionBtn = Instance.new("TextButton")
    actionBtn.Name = "ActionButton"
    actionBtn.Size = UDim2.new(1, 0, 1, 0)
    actionBtn.BackgroundColor3 = UITheme.Colors.Positive
    actionBtn.Font = UITheme.Fonts.Header
    actionBtn.Text = string.upper(config.ActionText or "SELL ALL")
    actionBtn.TextColor3 = UITheme.Colors.White
    actionBtn.TextStrokeColor3 = UITheme.Colors.StrokeOutline
    actionBtn.TextStrokeTransparency = 0.3
    actionBtn.TextSize = 18
    actionBtn.Parent = bottomBar
    UITheme.ApplyCorner(actionBtn, UITheme.CornerRadiusSmall)
    UITheme.ApplyStroke(actionBtn, UITheme.Colors.White, UITheme.StrokeThicknessThin)

    if config.Parent then
        mainFrame.Parent = config.Parent
    end

    self.MainFrame = mainFrame
    self.ScrollFrame = scrollFrame
    self.GridLayout = gridLayout
    self.CloseButton = closeBtn
    self.ActionButton = actionBtn
    self.Cards = {}

    closeBtn.MouseButton1Click:Connect(function()
        self:CloseAnimated()
    end)

    return self
end

function GridSellPanel:CreateItemCard(itemData: GridItemData, onClick: ((GridItemData) -> ())?): Frame
    local card = Instance.new("Frame")
    card.Name = "Card_" .. itemData.Id
    card.BackgroundColor3 = UITheme.Colors.CardBg
    card.BorderSizePixel = 0

    local cardCorner = UITheme.ApplyCorner(card, UITheme.CornerRadiusSmall)
    local rColor = itemData.RarityColor or UITheme.Colors.Money
    local cardStroke = UITheme.ApplyStroke(card, rColor, UITheme.StrokeThicknessThin)

    -- Item Icon / Emoji
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "ItemIcon"
    iconLabel.Size = UDim2.new(1, 0, 0, 52)
    iconLabel.Position = UDim2.new(0, 0, 0, 6)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = itemData.Icon or "🪨"
    iconLabel.TextSize = 36
    iconLabel.Parent = card

    -- Item Name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ItemName"
    nameLabel.Size = UDim2.new(1, -8, 0, 20)
    nameLabel.Position = UDim2.new(0, 4, 0, 58)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = UITheme.Fonts.Header
    nameLabel.Text = itemData.Name
    nameLabel.TextColor3 = UITheme.Colors.White
    nameLabel.TextSize = 12
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Stats: Weight & Value
    local statLabel = Instance.new("TextLabel")
    statLabel.Name = "StatLabel"
    statLabel.Size = UDim2.new(1, -8, 0, 20)
    statLabel.Position = UDim2.new(0, 4, 0, 78)
    statLabel.BackgroundTransparency = 1
    statLabel.Font = UITheme.Fonts.Body
    local statStr = ""
    if itemData.Value then
        statStr = "💵 " .. UITheme.FormatNumber(itemData.Value)
    elseif itemData.Weight then
        statStr = "⚖️ " .. tostring(itemData.Weight) .. "kg"
    else
        statStr = itemData.ExtraText or ""
    end
    statLabel.Text = statStr
    statLabel.TextColor3 = UITheme.Colors.Money
    statLabel.TextSize = 11
    statLabel.Parent = card

    -- Action mini-button inside card
    local selectBtn = Instance.new("TextButton")
    selectBtn.Name = "SelectBtn"
    selectBtn.Size = UDim2.new(1, -12, 0, 26)
    selectBtn.Position = UDim2.new(0, 6, 1, -32)
    selectBtn.BackgroundColor3 = itemData.IsSelected and UITheme.Colors.Positive or UITheme.Colors.Neutral
    selectBtn.Font = UITheme.Fonts.Header
    selectBtn.Text = itemData.IsSelected and "SELECTED" or "SELECT"
    selectBtn.TextColor3 = UITheme.Colors.White
    selectBtn.TextSize = 10
    selectBtn.Parent = card
    UITheme.ApplyCorner(selectBtn, UDim.new(0, 6))

    if onClick then
        selectBtn.MouseButton1Click:Connect(function()
            onClick(itemData)
        end)
    end

    card.Parent = self.ScrollFrame
    table.insert(self.Cards, card)
    return card
end

function GridSellPanel:PopulateItems(items: { GridItemData }, onItemClick: ((GridItemData) -> ())?)
    self:Clear()
    for _, item in ipairs(items) do
        self:CreateItemCard(item, onItemClick)
    end
end

function GridSellPanel:Clear()
    for _, card in ipairs(self.Cards) do
        card:Destroy()
    end
    self.Cards = {}
end

function GridSellPanel:OnAction(callback: () -> ())
    return self.ActionButton.MouseButton1Click:Connect(callback)
end

function GridSellPanel:OpenAnimated()
    self.MainFrame.Visible = true
    local origSize = self.MainFrame.Size
    self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
    TweenService:Create(self.MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = origSize
    }):Play()
end

function GridSellPanel:CloseAnimated(onComplete: (() -> ())?)
    local origSize = self.MainFrame.Size
    local t = TweenService:Create(self.MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    t:Play()
    t.Completed:Connect(function()
        self.MainFrame.Visible = false
        self.MainFrame.Size = origSize
        if onComplete then onComplete() end
    end)
end

function GridSellPanel:Destroy()
    if self.MainFrame then
        self.MainFrame:Destroy()
    end
end

return GridSellPanel
