--!strict
--[[
    TÊN SCRIPT: DataServerHandler
    LOẠI: Script (Server-side)
    VỊ TRÍ: ServerScriptService -> DataServerHandler
    MÔ TẢ: Xử lý sự kiện PlayerAdded, PlayerRemoving, BindToClose và vòng lặp tự động lưu mỗi 60 giây
]]

local Players = game:GetService("Players")
local DataService = require(script.Parent:WaitForChild("DataService"))

local AUTO_SAVE_INTERVAL = 60 -- Tự động lưu mỗi 60 giây

-- 1. Xử lý khi người chơi vào game
local function OnPlayerAdded(player: Player)
    local loaded = DataService.LoadProfile(player)
    if not loaded then
        warn(string.format("[DataServerHandler] Không thể tải dữ liệu cho %s", player.Name))
    end
end

-- 2. Xử lý khi người chơi thoát game (Lưu và xóa Session Lock)
local function OnPlayerRemoving(player: Player)
    DataService.SaveProfile(player, true)
end

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Xử lý người chơi đã có sẵn trong server khi script khởi động
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(function()
        OnPlayerAdded(player)
    end)
end

-- 3. Vòng lặp Auto-Save mỗi 60 giây cho tất cả người chơi online
task.spawn(function()
    while true do
        task.wait(AUTO_SAVE_INTERVAL)
        print("[DataServerHandler] Đang kích hoạt Auto-Save định kỳ 60s...")
        for _, player in ipairs(Players:GetPlayers()) do
            task.spawn(function()
                DataService.SaveProfile(player, false)
            end)
        end
    end
end)

-- 4. Xử lý khi Server bị đóng (Tắt game / Cập nhật phiên bản mới)
game:BindToClose(function()
    print("[DataServerHandler] Server đang đóng, tiến hành lưu khẩn cấp toàn bộ dữ liệu...")
    DataService.SaveAll(true)
    task.wait(3) -- Đợi các luồng lưu dữ liệu hoàn tất trước khi server tắt hoàn toàn
end)
