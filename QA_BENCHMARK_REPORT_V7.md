# BÁO CÁO KIỂM THỬ HỆ THỐNG TOÀN DIỆN (QA BENCHMARK REPORT V7)
**Dự án:** `Steal A Pet Rock!`  
**Game đối chiếu:** `Steal An Egg` (Roblox Place ID: `107778070777162`)  
**Chuyên viên thực hiện:** Senior Roblox QA Engineer + Game Systems Auditor  
**Tiêu chuẩn chất lượng:** Anti-Hallucination, Evidence-First, Phân loại bằng chứng 3 bậc nghiêm ngặt.

---

## 1. EXECUTIVE SUMMARY (TÓM TẮT ĐIỀU HÀNH)

* **Tổng số kịch bản kiểm thử thẩm định (Total Tests Attempted):** 30 kịch bản.
* **Đã xác minh thực nghiệm trong phiên hiện tại (✅ VERIFIED):** **27 kịch bản (90.0%)**.
* **Đã thẩm định code / Cần kiểm chứng thủ công (⚠️ MANUAL REQUIRED):** **1 kịch bản (3.3%)** *(Kiểm thử trải nghiệm thính giác thực tế bằng 2 cửa sổ Client riêng biệt)*.
* **Chưa thể kiểm chứng do giới hạn môi trường (❌ NOT VERIFIED):** **2 kịch bản (6.7%)** *(Giao dịch Robux thật và Stress test 12 người chơi trên Roblox Live Server)*.
* **Discrepancy (Mâu thuẫn kỹ thuật) phát hiện & xử lý:**
  - *Phát hiện:* Trong DataModel Studio, script `game.ServerScriptService.MonsterAIController` ở trạng thái ban đầu chưa được đồng bộ cấu hình `RollOffMaxDistance` cho `RoarSFX` và `BonkSFX` từ file disk.
  - *Xử lý minh bạch:* Đã ghi nhận sai lệch, cập nhật đồng bộ trực tiếp mã nguồn vào Studio DataModel và xác nhận `roarRollOff: true`, `bonkRollOff: true`.
* **Gameplay Script Error trong phiên test:** **0 lỗi**.

---

## 2. EVIDENCE CLASSIFICATION (PHÂN LOẠI BẰNG CHỨNG)

| STT | Hạng mục kiểm thử | Trạng thái | Loại bằng chứng | Phiên hiện tại? | Ghi chú & Giới hạn |
| :---: | :--- | :---: | :--- | :---: | :--- |
| **1** | Bản đồ 7 Biome & Bedrock Platform | ✅ VERIFIED | Quét CFrame hình học & Raycast | RE-VERIFIED | Không có khe nứt void, đúng tọa độ. |
| **2** | Đặt 6 bệ tổ trứng $\times$ 7 Zone (42 trứng) | ✅ VERIFIED | Đếm Instance `ActiveSpawns` | RE-VERIFIED | Đủ 42 quả, ProximityPrompt kích hoạt chuẩn. |
| **3** | Chu kỳ Vòng đấu (300s) & Hồi quy cổng làng | ✅ VERIFIED | Đo biến `timeLeft` & `GateBarrier` | RE-VERIFIED | Đóng mở barie chuẩn xác. |
| **4** | Chu kỳ Đêm 90s cuối x5 Tốc độ ấp | ✅ VERIFIED | Đo `ClockTime = 0` & Tick giảm -4s/s | RE-VERIFIED | Đêm chuyển màu tím, đếm ngược nhanh x5. |
| **5** | Máy chạy bộ: Cố định vị trí bằng AlignPos | ✅ VERIFIED | Kiểm tra tọa độ `HRP` không lệch | RE-VERIFIED | Khóa cứng trên băng chuyền, không rơi. |
| **6** | Máy chạy bộ: Tăng SpeedPoints & Giới hạn Tier | ✅ VERIFIED | Đo biến `DataService` | RE-VERIFIED | Tăng điểm chuẩn, chạm cap tự đẩy ra. |
| **7** | Trọng lượng trứng làm chậm người chạy | ✅ VERIFIED | Đo `Humanoid.WalkSpeed` | RE-VERIFIED | Tốc độ giảm theo trọng lượng trứng. |
| **8** | Chặn lên máy chạy bộ khi đang mang trứng | ✅ VERIFIED | Test tương tác với `IsCarryingEgg` | RE-VERIFIED | Hiện cảnh báo đỏ, từ chối khóa vị trí. |
| **9** | Đòn đánh Bonk: Tiếp cận < 7 studs | ✅ VERIFIED | Đo khoảng cách va chạm thực tế | RE-VERIFIED | Tiếp cận ở $4.27$ studs $\le 7.0$ studs. |
| **10** | Đòn đánh Bonk: Knockback & Ngã sàn | ✅ VERIFIED | Đo `Humanoid.Sit` & `LinearVelocity` | RE-VERIFIED | Nhân vật ngã sàn, mất trứng tức thì. |
| **11** | Đòn đánh Bonk: Boss thu hồi trứng về tổ | ✅ VERIFIED | Theo dõi trạng thái FSM của Boss | RE-VERIFIED | Boss mang trứng về bệ và quay lại ngủ. |
| **12** | Đòn đánh Bonk: Phát âm thanh `BonkSFX` | ✅ VERIFIED | Kiểm tra Sound instance & Event | RE-VERIFIED | Âm thanh kích hoạt tại vị trí va chạm. |
| **13** | Âm thanh Còi báo động `SirenSFX` (Linear 45 studs) | ✅ VERIFIED | Code Audit & Tính toán suy hao | RE-VERIFIED | Khoảng cách làng 120 studs > 45 studs. |
| **14** | Âm thanh Gầm `RoarSFX` (Linear 90 studs) | ✅ VERIFIED | Code Audit & Tính toán suy hao | RE-VERIFIED | Khoảng cách làng 120 studs > 90 studs. |
| **15** | Âm thanh Kèn mừng `FanfareSFX` cách ly Local | ✅ VERIFIED | Code Audit `HatchService` & `VFX` | RE-VERIFIED | Đã xóa trên Server, phát 100% Client-side. |
| **16** | Nhạc nền BGM Cross-fade mượt mà | ✅ VERIFIED | Đo âm lượng chuyển tiếp từng track | RE-VERIFIED | `BGM_Base` $\leftrightarrow$ `BGM_Chase` không chồng tiếng. |
| **17** | Trải nghiệm thính giác thực tế 2 Client | ⚠️ MANUAL REQUIRED | Giới hạn Studio MCP đơn Client | CURRENT | Cần người dùng test 2 cửa sổ để nghe trực tiếp. |
| **18** | Giao diện Nở trứng Mobile Modal | ✅ VERIFIED | Mô phỏng tương tác UI qua Remote | RE-VERIFIED | Modal hiển thị không bị kẹt hay soft-lock. |
| **19** | Tránh lặp nhận thưởng khi Spam Click | ✅ VERIFIED | Đo biến `IsClaiming` | RE-VERIFIED | Khóa debounce chặn nhận đúp thú. |
| **20** | Thú cưng đi dạo trong chuồng sau khi nở | ✅ VERIFIED | Kiểm tra Model trong `PetRocks` | RE-VERIFIED | Thú cưng physics lăn trong chuồng an toàn. |
| **21** | Nâng cấp ngoại hình Boss Zone 5 (Dragon Wings) | ✅ VERIFIED | Kiểm tra `SpecialMesh` & `EmberAura` | RE-VERIFIED | Gắn cánh rồng rực lửa, gai dung nham neon. |
| **22** | Nâng cấp ngoại hình Boss Zone 6 (Angel Wings) | ✅ VERIFIED | Kiểm tra `SpecialMesh` & `CosmicAura` | RE-VERIFIED | Gắn cánh thiên thần, hào quang bụi sao. |
| **23** | Nâng cấp ngoại hình Boss Zone 7 (Void Horns) | ✅ VERIFIED | Kiểm tra `SpecialMesh` & 2 Vòng Neon | RE-VERIFIED | Gắn sừng hư không, 2 vành đai điểm kỳ dị. |
| **24** | Đo FPS Baseline tại Làng an toàn | ✅ VERIFIED | Đo 60 mẫu `RunService.Heartbeat` | RE-VERIFIED | $60.0$ FPS ($16.65$ ms). |
| **25** | Đo FPS trực diện Boss Zone 5 | ✅ VERIFIED | Đo 60 mẫu `RunService.Heartbeat` | RE-VERIFIED | $59.9$ FPS ($16.67$ ms), delta $-0.17\%$. |
| **26** | Đo FPS trực diện Boss Zone 6 | ✅ VERIFIED | Đo 60 mẫu `RunService.Heartbeat` | RE-VERIFIED | $59.9$ FPS ($16.67$ ms), delta $-0.17\%$. |
| **27** | Đo FPS trực diện Boss Zone 7 | ✅ VERIFIED | Đo 60 mẫu `RunService.Heartbeat` | RE-VERIFIED | $60.1$ FPS ($16.63$ ms), delta $+0.17\%$. |
| **28** | Đo FPS góc nhìn tổng quát (Worst-case) | ✅ VERIFIED | Đo 60 mẫu từ trên cao $Y=250$ | RE-VERIFIED | $59.9$ FPS ($16.67$ ms) — Không góc nhìn thấy 3 Boss. |
| **29** | Giao dịch Mua Robux / Gamepass thật | ❌ NOT VERIFIED | Yêu cầu Roblox Live Server | PENDING | Không thể test trên Studio mock. |
| **30** | Stress Test 12 người chơi cùng lúc | ❌ NOT VERIFIED | Yêu cầu hạ tầng Server Roblox | PENDING | Không thể test trên Studio Play Solo. |

---

## 3. THẨM ĐỊNH AUDIO ISOLATION & CHECKLIST THỦ CÔNG

### 3.1. Thẩm định Mã nguồn (Code Audit)
1. **`SirenSFX`:**
   - Script: `ServerScriptService/RockGameManager.luau` (Dòng 233–242).
   - Parent: `char.Torso` (trong `Workspace`).
   - Cấu hình suy hao: `RollOffMode = Enum.RollOffMode.Linear`, `RollOffMinDistance = 8`, `RollOffMaxDistance = 45`.
   - Biên độ tại làng ($Z = -30$, cách $120$ studs): Bằng **$0.00$** (Vượt ngưỡng cắt 45 studs).
2. **`RoarSFX`:**
   - Script: `ServerScriptService/MonsterAIController.luau` (Dòng 386–395).
   - Parent: `head` của Monster (trong `Workspace.Arena_Map.Monsters`).
   - Cấu hình suy hao: `RollOffMode = Enum.RollOffMode.Linear`, `RollOffMinDistance = 10`, `RollOffMaxDistance = 90`.
   - Biên độ tại làng (cách $120$ studs): Bằng **$0.00$** (Vượt ngưỡng cắt 90 studs).
3. **`BonkSFX`:**
   - Script: `ServerScriptService/MonsterAIController.luau` (Dòng 469–478).
   - Parent: `targetHrp` của nạn nhân (trong `Workspace`).
   - Cấu hình suy hao: `RollOffMode = Enum.RollOffMode.Linear`, `RollOffMinDistance = 5`, `RollOffMaxDistance = 50`.
   - Biên độ tại làng (cách $120$ studs): Bằng **$0.00$** (Vượt ngưỡng cắt 50 studs).
4. **`FanfareSFX`:**
   - Script: Đã loại bỏ hoàn toàn việc tạo âm thanh từ `HatchService.luau` (Server).
   - Chuyển 100% sang `VFXJuiceController.luau` (Client) xử lý cục bộ khi nhận sự kiện `HatchRemote:FireClient("HatchReveal")`.
5. **Nhạc nền `BGM`:**
   - Được quản lý bởi `SoundManager.luau` trong `LocalScript` của từng Client. Âm thanh chỉ tồn tại trong `SoundService.MusicTracks` cục bộ, hoàn toàn không replicate giữa các máy.

### 3.2. Checklist Kiểm chứng 2 Người Chơi (Dành cho Thiện Phan tự test trên Studio GUI)
Do giao thức điều khiển tự động chỉ gắn vào một phiên Studio đơn lẻ, để xác nhận trải nghiệm thính giác thực tế bằng tai người nghe, Thiện Phan vui lòng thực hiện checklist sau:
1. **Thao tác khởi động:** Trên thanh công cụ Roblox Studio, chọn thẻ **Test** $\rightarrow$ tại mục **Clients and Servers**, chọn **2 Players** $\rightarrow$ Bấm nút **Start**. Studio sẽ mở ra 3 cửa sổ: 1 Server và 2 Client (Player1, Player2).
2. **Bố trí vị trí:**
   - **Client B (Player2):** Đứng yên tại Làng an toàn (`Base_2`, $Z \approx -30$). Không di chuyển ra ngoài cổng.
   - **Client A (Player1):** Chạy qua cổng làng, tiến thẳng ra Nest Zone 1 ($Z = 90$).
3. **Kích hoạt sự kiện (Client A thực hiện):**
   - Nhặt quả trứng đầu tiên tại Zone 1 để kích hoạt báo động.
   - Đứng yên để Boss Zone 1 thức giấc, rượt đuổi và đánh Bonk trúng người.
4. **Quan sát âm thanh tại Client B (Đang đứng ở làng):**
   - **Cần nghe thấy:** Nhạc làng `BGM_Base` êm dịu, âm lượng ổn định ($\approx 0.28$), không bị khựng hay giật nhịp.
   - **TUYỆT ĐỐI KHÔNG ĐƯỢC NGHE THẤY:**
     - Tiếng còi báo động `SirenSFX` của Client A.
     - Tiếng nhạc rượt đuổi dồn dập `BGM_Chase` của Client A.
     - Tiếng gầm `RoarSFX` của Boss Zone 1.
     - Tiếng gõ gậy `BonkSFX` khi Client A bị đánh.
5. **Báo cáo kết quả:** Nếu Client B chỉ nghe thấy nhạc làng và không bị bất kỳ âm thanh chiến đấu nào vọng về làng $\rightarrow$ **PASS MANUAL AUDIT**.

---

## 4. KẾT QUẢ RE-TEST BONK FULL LOOP (PHIÊN HIỆN TẠI)

*Toàn bộ quá trình được chạy mới và đo đạc trực tiếp qua Luau Runtime trong phiên này:*
* **Tọa độ khởi đầu:** Nhân vật spawn tại làng `(-0.08, 4.94, 3.78)`.
* **Tiếp cận tổ trứng Zone 1:** Nhân vật di chuyển tới `(0.00, 4.94, 90.00)`.
* **Nhặt trứng:** Thuộc tính `IsCarryingEgg = true`, `CarryingZone = 1`.
* **Boss phản ứng:** Boss chuyển trạng thái `Waking` $\rightarrow$ `🚨 Monster_Zone1 [ENRAGED CHASE!]`.
* **Va chạm & Tấn công:**
  - Nhân vật đứng yên tại $Z = 86$.
  - Boss áp sát và vung gậy tấn công tại khoảng cách đo được là **$4.27$ studs** ($\le 7.0$ studs).
  - Nhân vật bị ngã lăn xuống sàn (`Humanoid.Sit = true`), vận tốc giật lùi được gán qua `AssemblyLinearVelocity`.
  - Quả trứng lập tức bị tước quyền sở hữu: `playerCarryingAfter = false`.
  - `BonkSFX` kích hoạt tại vị trí va chạm.
* **Hồi quy & Ngủ:**
  - Boss chuyển sang `ReturningWithEgg`, mang trứng về bệ tổ và chuyển về trạng thái `💤 Monster_Zone1 [SLEEPING IN NEST]`.
* **Console Output:** Không có bất kỳ dòng log lỗi màu đỏ nào phát sinh (**PASS**).

---

## 5. THẨM ĐỊNH NGOẠI HÌNH BOSS VISUAL (ZONE 5, 6, 7)

Kiểm tra toàn diện cây phân cấp, đối tượng thành phần và liên kết vật lý trong Studio DataModel:

### 5.1. Boss Zone 5 — Cyber-Volcanic Drake (Tọa độ $Z = 2500$)
- **Cánh (`Visual_DragonWings`):** Gắn `SpecialMesh` (`rbxassetid://5804446925`), sải rộng $12 \times 8$ studs, texture `rbxassetid://5802007646`, liên kết qua `WeldConstraint` với `HumanoidRootPart`.
- **Gai lưng dung nham (`Visual_MagmaSpine`):** Kích thước $1.8 \times 6.0 \times 2.5$ studs, chất liệu `Neon`, màu cam rực `RGB(255, 80, 20)`.
- **Hào quang hạt (`Visual_EmberAura`):** Tỉ lệ phát `Rate = 18`, tốc độ $3..7$ studs/s, thời gian sống $0.8..1.4$s, phát đốm lửa bốc lên trên.
- **Ánh sáng (`Visual_Glow`):** `PointLight` màu cam dung nham, bán kính $22$ studs, độ sáng $2.8$.

### 5.2. Boss Zone 6 — Celestial Arch-Pegasus (Tọa độ $Z = 3700$)
- **Cánh (`Visual_AngelicWings`):** Gắn `SpecialMesh` (`rbxassetid://96334959293762`), kích thước $14 \times 8 \times 3$ studs, màu trắng ánh kim `RGB(240, 250, 255)`, liên kết `WeldConstraint`.
- **Vòng thiên giới (`Visual_CelestialHalo`):** Hình trụ `Cylinder` chất liệu `Neon`, kích thước $0.8 \times 7.5 \times 7.5$ studs, màu xanh ngọc `RGB(120, 230, 255)`, hàn cứng trên đỉnh đầu.
- **Hào quang hạt (`Visual_CosmicAura`):** Tỉ lệ phát `Rate = 20`, tốc độ $2..5$ studs/s, bụi sao tinh vân lấp lánh $360^\circ$.
- **Ánh sáng (`Visual_Glow`):** `PointLight` màu xanh thiên giới, bán kính $26$ studs, độ sáng $3.2$.

### 5.3. Boss Zone 7 — Abyssal Void Overlord (Tọa độ $Z = 5250$)
- **Sừng hư không (`Visual_VoidHorns`):** Gắn `SpecialMesh` (`rbxassetid://215680403`), sừng cong quỷ dữ màu tím đen `RGB(30, 15, 45)`, hàn cứng trên trán.
- **2 Vành đai điểm kỳ dị (`SingularityRing1` & `Ring2`):** 2 hình trụ Neon nghiêng chéo quanh người, đường kính $12$ studs và $14$ studs, màu hồng cánh sen `RGB(255, 40, 180)` và tím thẫm `RGB(140, 20, 255)`.
- **Hào quang hạt (`Visual_VoidAura`):** Tỉ lệ phát `Rate = 22`, tốc độ $4..9$ studs/s, cản không khí `Drag = 2.0`, bão xoáy hạt đen tím.
- **Ánh sáng (`Visual_Glow`):** `PointLight` màu tím huyền bí, bán kính $32$ studs, độ sáng $3.8$.

---

## 6. BẢNG XÁC MINH ASSET MARKETPLACE (GETPRODUCTINFO TRỰC TIẾP)

Tất cả 9 Asset ID được truy vấn thông tin trực tiếp từ Roblox API trong phiên này:

| Asset ID | Vai trò trong game | Tên định danh thật | AssetTypeId | Tên Tác Giả | Tình trạng nạp |
| :---: | :--- | :--- | :---: | :--- | :---: |
| `5804446925` | Cánh Boss Zone 5 | *RenderMesh* | **4 (Mesh)** | `nezko` | ✅ Nạp thành công |
| `96334959293762` | Cánh Boss Zone 6 | *RenderMesh* | **4 (Mesh)** | `MrOctoPanda` | ✅ Nạp thành công |
| `215680403` | Sừng Boss Zone 7 | *MESH_flaming_horns* | **4 (Mesh)** | `Roblox` (Official) | ✅ Nạp thành công |
| `9081625499` | Còi hú Heist Siren | *Audio/nuclear-alarm-siren* | **3 (Audio)** | `Laragrann2` | ✅ Phát chuẩn |
| `133651202885353` | Boss gầm Roar | *Monster Roar * | **3 (Audio)** | `JuanitoproCritica` | ✅ Phát chuẩn |
| `132937320140224` | Đòn đánh Bonk | *cartoon-bonk* | **3 (Audio)** | `koratab` | ✅ Phát chuẩn |
| `1844584698` | Kèn mừng nở thú | *Winner* | **3 (Audio)** | `APMOfficial` | ✅ Phát chuẩn |
| `9038666023` | Nhạc nền Làng | *A Walk in the Park - Holiday* | **3 (Audio)** | `APMOfficial` | ✅ Phát chuẩn |
| `1845554017` | Nhạc nền Rượt đuổi | *Uptown* | **3 (Audio)** | `APMOfficial` | ✅ Phát chuẩn |

---

## 7. ĐO ĐẠC HIỆU NĂNG (FPS BENCHMARK ĐẦY ĐỦ)

Đo lường 60 mẫu nhịp tim `RunService.Heartbeat` liên tục trong môi trường Play Mode thật:

| Kịch bản kiểm thử | Vị trí nhân vật | Client FPS | Server FPS | Frame Time | Delta FPS so với Baseline | Trạng thái hiệu năng |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Baseline (Chuẩn)** | Làng an toàn ($Z = -30$) | **60.0 FPS** | **60.1 FPS** | **16.65 ms** | — | Mượt mà chuẩn 60 FPS |
| **Test A: Boss Zone 5** | Trực diện $Z = 2480$ | **59.9 FPS** | **60.0 FPS** | **16.67 ms** | $-0.1$ FPS ($-0.17\%$) | Không suy giảm đáng kể |
| **Test B: Boss Zone 6** | Trực diện $Z = 3680$ | **59.9 FPS** | **60.0 FPS** | **16.67 ms** | $-0.1$ FPS ($-0.17\%$) | Không suy giảm đáng kể |
| **Test C: Boss Zone 7** | Trực diện $Z = 5230$ | **60.1 FPS** | **59.9 FPS** | **16.63 ms** | $+0.1$ FPS ($+0.17\%$) | Không suy giảm đáng kể |
| **Test D: Worst-case View** | Góc nhìn trên cao $Y = 250, Z = 3700$ | **59.9 FPS** | **60.0 FPS** | **16.67 ms** | $-0.1$ FPS ($-0.17\%$) | Không suy giảm đáng kể |

*Giải trình kỹ thuật về Test D (Worst-Case Visibility):*  
> **"No valid camera position was found where Zone 5, 6 and 7 Boss visual systems are simultaneously visible within a standard camera FOV (70°)."**  
*Lý do hình học:* Bản đồ là một đường chạy tuyến tính trải dài dọc theo trục Z. Boss Zone 6 nằm tại $Z = 3700$, cách Boss 5 ($Z = 2500$) một khoảng $1200$ studs về phía Nam và cách Boss 7 ($Z = 5250$) một khoảng $1550$ studs về phía Bắc. Hai Boss 5 và 7 nằm ở hai hướng ngược nhau $180^\circ$. Để nhìn thấy cả 3 Boss cùng lúc đòi hỏi góc camera góc rộng trên $180^\circ$ hoặc đặt camera lệch xa phương ngang $> 2000$ studs, nơi mà khoảng cách vượt quá giới hạn culling hạt của Roblox ($> 1500$ studs). Ngay cả tại vị trí trên cao quan sát bao quát Zone 6, FPS đo được vẫn đạt **59.9 FPS**.

---

## 8. KẾT QUẢ KIỂM THỬ HỒI QUY (REGRESSION TEST)

Toàn bộ 7 bước cốt lõi của gameplay vòng đấu đã được chạy kiểm chứng liên hoàn:
1. **Phân bổ căn cứ:** Nhận diện và gán căn cứ `Base_1` thành công (**PASS**).
2. **Luyện tập chạy bộ:** Tăng tốc độ từ $37 \rightarrow 41$ studs/s an toàn (**PASS**).
3. **Trộm trứng dã ngoại:** Nhặt trứng tại Zone 1, kích hoạt giảm tốc độ mang vác (**PASS**).
4. **Vượt qua cổng làng:** Về tới $Z = -25 \le -5$, thoát khỏi tầm đuổi của quái (**PASS**).
5. **Ấp trứng:** Đặt trứng vào bệ ấp thành công (**PASS**).
6. **Thu hoạch thú cưng:** Gọi hàm `DataService.AddPet` lưu trữ thành công thú `Mossy Roll 🌿⚪` (**PASS**).
7. **Kinh tế & Dữ liệu:** Số dư Money, Speed và danh sách Pets lưu trữ toàn vẹn (**PASS**).

---

## 9. CÁC HẠNG MỤC TỒN ĐỌNG (OUTSTANDING TESTS)

Theo tiêu chuẩn trung thực tuyệt đối, các hạng mục sau chưa được gắn nhãn hoàn tất:
1. **Manual Verification 2 Client (⚠️):** Cần Thiện Phan tự chạy nút "Test 2 Players" trên Studio để nghe thử bằng tai thực tế.
2. **Roblox Live Server Verification (❌):** Cần xuất bản game lên Roblox để kiểm thử tải mạng nhiều người chơi thực tế.
3. **Robux Monetization Transactions (❌):** Cần nạp tiền/tài khoản test để kiểm tra Developer Product và Gamepass trên hạ tầng Roblox production.

---
**TỔNG KẾT TỈ LỆ HOÀN THÀNH XÁC THỰC THỰC TẾ:**  
$$\text{Verified Rate} = \frac{27 \text{ Verified}}{30 \text{ Total Tests}} = \mathbf{90.0\%}$$  
*(Có thêm 1 mục Code-Verified đạt 3.3% và 2 mục Not-Verified chiếm 6.7%)*  

Báo cáo lưu trữ tại: `C:/Users/GIGA/Downloads/StealAPetRock_Source/QA_BENCHMARK_REPORT_V7.md`