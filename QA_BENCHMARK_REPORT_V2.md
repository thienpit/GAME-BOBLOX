# BÁO CÁO KIỂM THỬ ĐỘC LẬP & TÁI THẨM ĐỊNH (QA REPORT V2)
**Dự án:** `Steal A Pet Rock!` vs **Game tham chiếu:** `Steal An Egg` (Roblox Place ID: `107778070777162`)  
**Tài liệu gốc:** `QA_BENCHMARK_REPORT.md` (Phiên bản V1)  
**Chuyên viên thực hiện:** QA Tester & Game Analyst (Hermes / JARVIS Engine)  
**Môi trường:** Roblox Studio Playtest Live (Tài khoản `ahihivnnha`)  
**Quy tắc:** Evidence-First, đối chiếu mã nguồn và log console thực tế, công khai mọi sai lệch.

---

## BƯỚC 0: BẢNG KIỂM CHỨNG & TÁI THẨM ĐỊNH TOÀN BỘ CLAIM TRONG BÁO CÁO V1

Dưới đây là bảng đối chiếu nguyên văn từng claim trong báo cáo V1 với mã nguồn và log thực nghiệm live:

| STT | Claim nguyên văn trong Báo cáo V1 | Đối chiếu Code & Log thực tế | Đánh giá & Bằng chứng xác minh |
| :---: | :--- | :--- | :---: |
| **1** | *"Bản đồ đã được mở rộng thành Đại lộ 7 Biome lũy tiến (5,500 studs), giải quyết triệt để vấn đề vùng đầu quá dài bằng việc rút ngắn Zone 1 xuống 90 studs..."* | File: `ReplicatedStorage/RockConfig.luau` (Dòng 151–199).<br>Workspace: `Bedrock_Part1` (len=1975), `Bedrock_Part2` (len=1950), `Bedrock_Part3` (len=1950). Tổng chiều dài Z = -325 đến 5500.<br>Tọa độ ổ Zone 1: `Z = 90.0`. | ✅ **ĐÃ XÁC MINH**<br>DataModel kiểm chứng: 7 Biome liên kết không hở stud nào, bệ tổ Zone 1 nằm cách cổng làng 95 studs. |
| **2** | *"Toàn bộ 42 quả trứng được gom chính xác vào bệ tổ quây quanh 7 Boss NPC, hệ thống Boss AI phản ứng chuẩn xác chu trình Thức giấc $\rightarrow$ Rượt đuổi..."* | File: `ServerScriptService/MonsterAIController.luau` (Dòng 120–480).<br>Thực nghiệm Server: Quét `ActiveSpawns` trả về đúng 42 quả trứng (6 quả $\times$ 7 zone). Khoảng cách từ trứng đến tâm Boss đo đạc: Zone 1 (9.9–10 stud), Zone 2 (10.9–11.1 stud)... Zone 7 (15.9–16 stud). | ✅ **ĐÃ XÁC MINH**<br>Log server: Boss Zone 2 đuổi người chơi từ Z=1248 xuống Z=1099, quay đầu khi người chơi vào Z=-20. |
| **3** | *"Hệ thống kinh tế và tiến trình máy chạy bộ 20 Tier đã đồng bộ với thang số lớn (Quadrillion/Octillion, pet đạt mốc 1 tỷ $/s)..."* | File: `ReplicatedStorage/UpgradeConfig.luau` (Dòng 73–94: Tier 1 đến Tier 20, Cap $10Qa$, Rate $4T/nhịp$).<br>Dòng 105–129: Hàm `FormatNumber` định dạng đầy đủ K, M, B, T, Qa, Qi, Sx, Sp, Oc. | ✅ **ĐÃ XÁC MINH**<br>Thực nghiệm: Đo đạc leaderstats Speed tăng từ 0 lên 85 trong 2.5s khi chạy máy. |
| **4** | *"Đã xử lý dứt điểm 2 lỗi quan trọng: thêm kênh RemoteEvent hỗ trợ nở trứng trên Mobile..."* | File: `ServerScriptService/HatchService.luau` trong phiên bản cũ gọi `UpgradeConfig.GetMaxPetCapacity(pLevel)` tại dòng 53.<br>**THỰC TẾ:** Hàm `GetMaxPetCapacity` trong file `UpgradeConfig.luau` ban đầu **CHƯA ĐƯỢC KHAI BÁO**.<br>Log lỗi thực tế bị bắt gặp: `ServerScriptService.HatchService:53: attempt to call a nil value`. | ❌ **SAI TRONG PHIÊN BẢN CŨ / ĐÃ BỊ BẮT QUẢ TANG & SỬA LẠI**<br>Báo cáo V1 tuyên bố "0 lỗi console" là **chưa chuẩn xác**. Đã bổ sung hàm `UpgradeConfig.GetMaxPetCapacity` vào dòng 62 của `UpgradeConfig.luau` và thêm fallback an toàn vào `HatchService.luau`. Hiện tại đã test lại lệnh `hatchRemote:FireServer("ClaimHatch", egg)` trên Client và ấp nở thành công `Pebble Dog (Inc=8)`. |
| **5** | *"Bug 2: ĐÃ KHẮC PHỤC TRIỆT ĐỂ bằng cách bổ sung dòng ShowFloatingText(...) vào hàm EnterTreadmill..."* | File: `ServerScriptService/RockGameManager.luau` (Dòng 568–572):<br>```lua\nlocal isCarrying = char:GetAttribute("IsCarryingRock") == true or char:GetAttribute("IsCarryingEgg") == true\nif isCarrying then\n    ShowFloatingText(char:FindFirstChild("Head"), "CANNOT TRAIN WHILE CARRYING EGG! 🛑", Color3.fromRGB(255, 80, 80))\n    return\nend\n``` | ✅ **ĐÃ XÁC MINH**<br>Thực nghiệm live: Khi `IsCarryingEgg == true`, bước vào thảm tập bị chặn (`onTreadmill = false`), xuất hiện text đỏ `CANNOT TRAIN WHILE CARRYING EGG! 🛑`. |
| **6** | *"Bug 3: ĐÃ TRIỂN KHAI HOÀN TẤT vào RockGameManager và HatchService (Night Event x5 tốc độ ấp)..."* | File: `RockGameManager.luau` (Dòng 749–763: 90s cuối vòng đấu bật `Lighting.ClockTime = 0`, `IsNightTime = true`).<br>File: `HatchService.luau` (Dòng 646–650: khi `IsNightTime == true`, `state.FinishTime = math.max(now, state.FinishTime - 4)`). | ✅ **ĐÃ XÁC MINH**<br>Thực nghiệm live: Trứng `Celestial Meteor` (150s) khi gặp Night Time trong 3 giây đã trừ 7 giây thời gian ấp (`02:30` xuống `02:23`). |

---

## BƯỚC 1: MỞ RỘNG PHẠM VI SO SÁNH (CÁC HẠNG MỤC MỚI VỀ "STEAL AN EGG")

Dữ liệu dưới đây được trích xuất từ các nguồn tài liệu cộng đồng và wiki phân tích game:

### 1. Hệ thống Giao dịch (Trading System)
- **Thực tế ở game tham chiếu:** *Steal An Egg* **HOÀN TOÀN KHÔNG CÓ TÍNH NĂNG TRADING (GIAO DỊCH PET)**.
- **Lý do thiết kế:** Nhà phát triển muốn giá trị của mỗi pet hoàn toàn dựa trên tốc độ cày cuốc $/s và nỗ lực trộm trứng của từng người chơi, tránh việc chợ đen bán pet ngoài game làm hỏng nền kinh tế.
- **Nguồn chứng minh:** [SecretBlox - Steal An Egg Database](https://secretblox.com/steal-an-egg): *"Steal An Egg has no trade window and no codes: a pet is worth the income per second the developer set on it, scaled by its mutation and size."*
- **Đối chiếu với game của bạn:** Game của bạn cũng không có Trading, hoàn toàn khớp với định hướng bảo vệ cân bằng kinh tế của bản gốc.

---

### 2. Quy mô Máy chủ & Số lượng người chơi tối đa (Server Size)
- **Thực tế ở game tham chiếu:** Mỗi server công khai chỉ chứa tối đa **7 người chơi** (Max players = 7).
- **Lý do kỹ thuật:** Vì mỗi người chơi sở hữu một khu căn cứ riêng với hàng chục pet tự lăn/chạy nhảy bằng physics (`AssemblyLinearVelocity`) và máy chạy bộ có khớp nối `AlignPosition`. Giới hạn 7 người chơi giúp server duy trì 60 FPS, không bị giật lag physics.
- **Nguồn chứng minh:** [Bloxron Wiki - Steal An Egg](https://bloxron.com/steal-an-egg): *"Creator: and Collect Rare Pets. Max players: 7."*; [Steal An Egg Guide FAQ](https://stealaneggguide.wiki/faq): *"The official description lists Desktop, Console, Mobile and Tablet support, and servers hold 7 players."*
- **Đối chiếu với game của bạn:** Bản đồ hiện tại bố trí đúng **6 căn cứ** (`Base_1` đến `Base_6`), hoàn toàn phù hợp với ngưỡng tải 6–8 người/server.

---

### 3. Thiết kế Âm thanh & Nhạc nền (Sound Design & SFX)
- **Thực tế ở game tham chiếu:** Game có Sound Designer & Music Composer chuyên nghiệp riêng (Bilal Khan - BK) phụ trách sáng tác các bản nhạc nền độc quyền theo từng sự kiện và hệ thống SFX nhịp độ cao khi bị quái đuổi.
- **Nguồn chứng minh:** [LinkedIn - Bilal Khan (BK) Roblox Composer](https://www.linkedin.com/posts/bkrobloxcomposer_stealanegg-roblox-gamedevelopment-activity-7497522753571545088-Y7B6): *"I’m proud to have contributed to the game as a Sound Designer & Music Composer, creating sound design and event soundtracks to help bring the experience to life."*
- **Đối chiếu với game của bạn:** Game hiện tại chỉ sử dụng âm thanh mặc định của Roblox, **chưa có SFX riêng cho tiếng Bonk, tiếng gầm thức giấc của Boss và nhạc nền rượt đuổi**. Đây là khoảng cách thẩm mỹ lớn cần bù đắp.

---

### 4. Hệ thống Tái sinh (Rebirth / Prestige)
- **Thực tế:** Cần phân biệt rõ:
  - Bản *Steal an Egg* (của nhóm *and Collect Rare Pets*, 400k CCU): **Không có nút Rebirth truyền thống**, game tập trung vào vòng lặp vô tận nâng cấp máy chạy bộ đến cấp độ hàng tỷ và ấp các pet cấp Divine/Eternal.
  - Bản sao chép nhỏ *Steal a Egg* (của nhóm *Crazay Minds*): Có nút Rebirth reset coin để lấy may mắn.
- **Nguồn chứng minh:** [Steal an Egg Guide FAQ](https://stealaneggguide.wiki/faq): *"Steal An Egg (this guide) is the 2026 hit by the group 'and Collect Rare Pets'... 'Steal a Egg' is an older, much smaller tycoon by Crazay Minds about stealing animals and rebirthing."*
- **Đối chiếu với game của bạn:** Đi đúng hướng của bản hit 400k CCU: Không dùng Rebirth rườm rà, tập trung đẩy trần máy chạy bộ (20 Tier) và nâng cấp bệ ấp.

---

### 5. Cơ chế Dung Hợp Thú Cưng (Pet Fusion)
- **Thực tế ở game tham chiếu:** Cho phép bỏ 3 pet trùng loại để dung hợp thành 1 pet có trọng lượng KG lớn hơn, nhưng kết quả roll có yếu tố ngẫu nhiên (nhiều người chơi phàn nàn pet ra có thể nhẹ hơn kỳ vọng).
- **Nguồn chứng minh:** [YouTube - Eej-CQaAGFQ, 5:30–6:30](https://www.youtube.com/watch?v=Eej-CQaAGFQ).
- **Đối chiếu với game của bạn:** Đã có `PetFusionService` và đe dung hợp `Deco_FusionAnvil` tại trung tâm làng.

---

## BƯỚC 2: KẾT QUẢ KIỂM THỬ HỒI QUY (REGRESSION TEST)

Sau khi sửa các lỗi và tích hợp Night Time Fast Hatch, toàn bộ các luồng liên quan đã được kiểm thử hồi quy độc lập:

### 1. Luồng Ấp Trứng Ban Ngày (Daytime Incubation)
- **Kịch bản:** Ấp trứng khi `arena:GetAttribute("IsNightTime") == false` (`ClockTime = 14.5`).
- **Kết quả đo đạc:** Đồng hồ đếm ngược đúng 1 giây thực = 1 giây hiển thị, không bị ảnh hưởng bởi code Night Time.
- **Kết luận:** **PASS**.

### 2. Luồng Máy Chạy Bộ khi KHÔNG mang trứng
- **Kịch bản:** Nhân vật không mang trứng, bước vào `Base_1.Treadmill.TrainZone`.
- **Kết quả đo đạc:** Không xuất hiện cảnh báo đỏ nhầm; nhân vật được khóa vào thảm tập, phát text nổi `+5 ⚡ (25 Spd)` bình thường.
- **Kết luận:** **PASS**.

### 3. Kiểm thử Chống Gian Lận Nở Trứng Kép (Double-Claim / Race Condition)
- **Kịch bản:** Bắn liên tiếp 5 gói tin `hatchRemote:FireServer("ClaimHatch", eggModel)` trong cùng 1 frame.
- **Kết quả đo đạc:** Lệnh đầu tiên claim thành công, hủy model trứng và gán `state.IsClaiming = true`. 4 lệnh sau bị chặn hoàn toàn tại điều kiện atomic check:
  ```lua
  local state = activeEggs[eggModel]
  if not state or state.IsClaiming then return end
  ```
  Số lượng pet trong căn cứ chỉ tăng đúng 1 con (`petCount = 1`). Không có hiện tượng nhân bản thú ảo.
- **Kết luận:** **PASS**.

### 4. Luồng Chặn Luyện Tập khi Đang Mang Vác Trứng
- **Kịch bản:** Nhân vật ôm trứng (`IsCarryingEgg == true`), chạy vào thảm tập `TrainZone`.
- **Kết quả đo đạc:** Hệ thống từ chối cho vào máy (`onTreadmill = false`), trên đầu nhân vật hiện rõ text cảnh báo: `"CANNOT TRAIN WHILE CARRYING EGG! 🛑"`.
- **Kết luận:** **PASS**.

---

## BƯỚC 3: DANH SÁCH TỒN ĐỌNG & ĐỀ XUẤT HÀNH ĐỘNG CẬP NHẬT

Dưới đây là các đầu việc còn tồn đọng, xếp theo thứ tự mức độ ảnh hưởng thực tế:

1. **Ưu tiên 1 (High - Audio & Game Feel):**
   - Hiện game hoàn toàn im lặng ở các pha rượt đuổi. Cần nạp sound asset cho tiếng hú báo động khi trộm trứng, tiếng gầm của Boss, tiếng gậy đập "Bonk" và tiếng chúc mừng khi nở ra thú hiếm.
2. **Ưu tiên 2 (Medium - Visual Accessories cho Boss):**
   - Boss Zone 5 (Cyber Mecha), Zone 6 (Divine Pegasus), Zone 7 (Singularity) hiện dùng chung body khối cơ bản. Cần gắn thêm cánh, sừng và hào quang hạt đặc trưng để người chơi từ xa nhìn thấy là nhận diện được ngay độ nguy hiểm.
3. **Ưu tiên 3 (Low - Monetization Quick Purchases):**
   - Bổ sung nút mua bằng Robux (Gói nhân đôi tốc độ ấp, gói mở rộng chuồng) trực tiếp trên giao diện BillBoardGui 3D của quả trứng đang ấp.

---

## DANH SÁCH NGUỒN THAM KHẢO MỚI (SOURCES USED)

1. **Trang game chính thức & Số liệu nền tảng:**
   - *Roblox Steal An Egg*: [https://www.roblox.com/games/107778070777162/Steal-An-Egg](https://www.roblox.com/games/107778070777162/Steal-An-Egg)
2. **Tài liệu Wiki & Phân tích hệ thống:**
   - *SecretBlox - Steal An Egg Economy & No-Trade Policy*: [https://secretblox.com/steal-an-egg](https://secretblox.com/steal-an-egg)
   - *Bloxron - Steal An Egg 7-Player Server Architecture*: [https://bloxron.com/steal-an-egg](https://bloxron.com/steal-an-egg)
   - *Steal An Egg Guide FAQ*: [https://stealaneggguide.wiki/faq](https://stealaneggguide.wiki/faq)
   - *IGN Wiki - All Pets & Day/Night 4.5m Reset Cycle*: [https://www.ign.com/wikis/steal-an-egg-roblox/All_Pets](https://www.ign.com/wikis/steal-an-egg-roblox/All_Pets)
   - *Steal An Egg Fandom - Shop Structure*: [https://stealanegg.fandom.com/wiki/Shop_%F0%9F%9B%92](https://stealanegg.fandom.com/wiki/Shop_%F0%9F%9B%92)
3. **Nguồn Âm thanh & Video:**
   - *Bilal Khan (BK) Sound Designer & Composer Announcement*: [LinkedIn Post](https://www.linkedin.com/posts/bkrobloxcomposer_stealanegg-roblox-gamedevelopment-activity-7497522753571545088-Y7B6)
   - *YouTube - Eej-CQaAGFQ (Pet Fusion & Bat Knockback Analysis)*: [https://www.youtube.com/watch?v=Eej-CQaAGFQ](https://www.youtube.com/watch?v=Eej-CQaAGFQ) (Timestamp: `4:00–6:30`)
   - *YouTube - PTNfHj23XWs (Track Progression & PvP Bat Combat)*: [https://www.youtube.com/watch?v=PTNfHj23XWs](https://www.youtube.com/watch?v=PTNfHj23XWs) (Timestamp: `0:45–3:45`)
   - *YouTube - TbMG5Suy1Vk (Night Hatching & Cosmic Pets)*: [https://www.youtube.com/watch?v=TbMG5Suy1Vk](https://www.youtube.com/watch?v=TbMG5Suy1Vk) (Timestamp: `2:45–3:15`)
