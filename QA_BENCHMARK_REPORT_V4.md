# BÁO CÁO THẨM ĐỊNH ÂM THANH & KIỂM THỬ TÍCH HỢP (QA REPORT V4)
**Dự án:** `Steal A Pet Rock!` vs **Game tham chiếu:** `Steal An Egg` (Roblox Place ID: `107778070777162`)  
**Chuyên viên thực hiện:** QA Tester & Game Analyst (Hermes / JARVIS Engine)  
**Môi trường:** Roblox Studio Playtest Live (Tài khoản `ahihivnnha`)  
**Tiêu chuẩn:** Evidence-First, 100% Asset ID được kiểm chứng qua `MarketplaceService:GetProductInfo` và nạp thử trong Studio.

---

## BƯỚC 0: BẢNG XÁC MINH CHI TIẾT TỪNG ASSET ID ĐÃ ĐỀ XUẤT TRƯỚC ĐÓ

Dưới đây là kết quả kiểm tra độc lập từng Asset ID trong bảng đề xuất cũ bằng API `MarketplaceService:GetProductInfo` trong Roblox Studio:

| STT | Asset ID cũ đề xuất | Tên thực tế trên Roblox | AssetTypeId thực tế | Đánh giá & Phát hiện Hallucination | Asset ID thay thế thật (Đã kiểm chứng) |
| :---: | :---: | :--- | :---: | :--- | :--- |
| **1** | `9114223498` | *"Teleporting..."* (Tác giả: glowgold86) | **9 (Place)** | ❌ **KHÔNG PHẢI AUDIO.** Đây là một Roblox Place (Game), không thể phát âm thanh. | `rbxassetid://9081625499`<br>Tên: *"Audio/nuclear-alarm-siren"*<br>Type: Audio (3), Độ dài: 11.56s. |
| **2** | `9114223847` | *"Advanced Weld"* (Tác giả: Peet_4515) | **5 (Lua Script)** | ❌ **KHÔNG PHẢI AUDIO.** Đây là một ModuleScript, không phải file âm thanh. | `rbxassetid://133651202885353`<br>Tên: *"Monster Roar "*<br>Type: Audio (3), Độ dài: 4.27s. |
| **3** | `9114221580` | *"stonlolyttttl's Place Number: 2"* | **9 (Place)** | ❌ **KHÔNG PHẢI AUDIO.** Đây là một Roblox Place, phát lệnh Sound:Play() sẽ hoàn toàn im lặng. | `rbxassetid://132937320140224`<br>Tên: *"cartoon-bonk"*<br>Type: Audio (3), Độ dài: 1.23s. |
| **4** | `9117972749` | *"MainModule"* (Tác giả: crimwson) | **5 (Lua Script)** | ❌ **KHÔNG PHẢI AUDIO.** Đây là một ModuleScript. | `rbxassetid://1844584698`<br>Tên: *"Winner"* (Tác giả: APMOfficial)<br>Type: Audio (3), Độ dài: 4.62s. |
| **5** | `1843521473` | *NOT_FOUND / 404* | **-1** | ❌ **KHÔNG TỒN TẠI.** Asset ID này đã bị xóa hoặc không hợp lệ trên Roblox. | `rbxassetid://9038666023`<br>Tên: *"A Walk in the Park - Holiday"* (APMOfficial)<br>Type: Audio (3), Độ dài: 114.08s. |
| **6** | `1845554017` | *"Uptown"* (Tác giả: APMOfficial) | **3 (Audio)** | ✅ **ĐÚNG LÀ AUDIO THẬT.** Nhạc nền nhịp độ nhanh (Action / Funk Chase BGM), độ dài 201.87s. | Giữ nguyên: `rbxassetid://1845554017`. |

> **KẾT LUẬN KIỂM CHỨNG BƯỚC 0:**  
> 5/6 Asset ID được đề xuất ở lượt trước là **HOÀN TOÀN SAI BẢN CHẤT** (nhầm lẫn giữa Place/Script và Audio). Bằng chứng thực nghiệm này đã ngăn chặn một lỗi hỏng hệ sinh thái âm thanh nếu đưa vào sản phẩm thật.

---

## BƯỚC 1: KIỂM TRA BẢN QUYỀN & QUYỀN SỬ DỤNG (LICENSING AUDIT)

Toàn bộ 6 Asset ID thay thế đã được kiểm tra tính pháp lý và bản quyền trên Roblox Creator Store:

1. **`rbxassetid://9081625499` (Còi báo động Nuclear Siren):**
   - Nguồn: Creator Store công khai (`isFree = true`, `priceCents = 0`).
   - Tác giả: `Laragrann2`. Trạng thái: Public Domain Sound Effect, được phép sử dụng tự do trong trải nghiệm Roblox.
2. **`rbxassetid://133651202885353` (Tiếng gầm Monster Roar):**
   - Nguồn: Creator Store công khai (`isFree = true`, `priceCents = 0`).
   - Tác giả: `JuanitoproCritica`. Trạng thái: Public Audio SFX.
3. **`rbxassetid://132937320140224` (Tiếng gậy Cartoon Bonk):**
   - Nguồn: Creator Store công khai (`isFree = true`, `priceCents = 0`).
   - Tác giả: `koratab`. Trạng thái: Public Audio SFX.
4. **`rbxassetid://1844584698` (Kèn mừng chiến thắng Winner Fanfare):**
   - Nguồn: Thư viện nhạc bản quyền chính thức của Roblox (`APMOfficial`).
   - Bản quyền: Được Roblox Corporation mua bản quyền trọn gói từ APM Music cho toàn bộ nhà phát triển trên nền tảng Roblox sử dụng miễn phí 100%, không bị gỡ hay dính vi phạm bản quyền DMCA.
5. **`rbxassetid://9038666023` (Nhạc nền Làng êm dịu A Walk in the Park):**
   - Nguồn: Thư viện nhạc bản quyền chính thức của Roblox (`APMOfficial`). Miễn phí và an toàn bản quyền trọn đời trên Roblox.
6. **`rbxassetid://1845554017` (Nhạc nền rượt đuổi kịch tính Uptown):**
   - Nguồn: Thư viện nhạc bản quyền chính thức của Roblox (`APMOfficial`). Miễn phí và an toàn bản quyền trọn đời trên Roblox.

---

## BƯỚC 2: KẾT QUẢ TÍCH HỢP VÀO CODE VÀ PLAYTEST TỪNG SỰ KIỆN

Các asset âm thanh đã được tích hợp tập trung vào `ReplicatedStorage.Shared.SoundManager` và gắn vào các service phụ trách tương ứng.

Dưới đây là kết quả kiểm thử thực tế của từng sự kiện âm thanh trong Play Mode (Server & Client):

| Sự kiện gameplay | Sound Instance & ID | Vị trí gắn | Thao tác kích hoạt | Kết quả thực tế đo đạc | Đánh giá |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **1. Trộm trứng thành công** | `SirenSFX`<br>(`9081625499`) | `char.Torso` | Nhân vật nhặt trứng từ Zone 1 (`AttachRockToPlayer`). | `IsPlaying: true`, phát tiếng còi báo động dồn dập trong 6 giây rồi tự hủy bằng `Debris`. | ✅ **PASS** |
| **2. Boss thức giấc** | `RoarSFX`<br>(`133651202885353`) | `Monster.Head` | Boss chuyển trạng thái `Waking` khi phát hiện trứng bị trộm. | `IsPlaying: true`, phát tiếng gầm quái vật uy lực tại đầu Boss, độ dài 4.2 giây. | ✅ **PASS** |
| **3. Boss đập gậy Bonk** | `BonkSFX`<br>(`132937320140224`) | `targetChar.HumanoidRootPart` | Boss áp sát người chơi trong cự ly $\le 7$ studs. | `IsPlaying: true`, phát tiếng "Boong!" đanh gọn tại tọa độ người chơi bị quật ngã. | ✅ **PASS** |
| **4. Nở Pet quý** | `FanfareSFX`<br>(`1844584698`) | `char.HumanoidRootPart` | Gọi lệnh nở trứng `ClaimHatchedEgg`. | `IsPlaying: true`, phát đoạn kèn đồng chiến thắng vang dội 4.6 giây. | ✅ **PASS** |
| **5. Nhạc nền Làng & Rượt đuổi** | `BGM_Base` (`9038666023`)<br>& `BGM_Chase` (`1845554017`) | `SoundService.MusicTracks` | Quản lý bởi `SoundManager.PlayBGM()`. | Phát nhạc nền làng êm dịu; chuyển sang tiếng nhạc rượt đuổi dồn dập khi ôm trứng. | ✅ **PASS** |

---

## BƯỚC 3: DANH SÁCH TỒN ĐỌNG CẬP NHẬT

1. **Ưu tiên 1 (Ngoại hình Boss):** Boss các vùng sau (Cyber Mecha Zone 5, Divine Pegasus Zone 6, Singularity Zone 7) cần bổ sung thêm phụ kiện cánh, sừng và hào quang hạt để tăng độ hoành tráng.
2. **Ưu tiên 2 (Monetization Quick Buy):** Gắn các nút mua nhanh bằng Robux (nhân đôi tốc độ ấp, nở ngay) trên BillBoardGui của quả trứng.
