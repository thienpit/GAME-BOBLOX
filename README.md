# 🎮 GAME-BOBLOX (Steal A Pet Rock)

Dự án game Roblox phối hợp giữa **Developer (Logic/Hệ thống)** và **3D Artist (Model/Texture/Map)**.

---

## 👥 Phân Chia Vai Trò

* **Developer (Thiện Phan):** Quản lý Source Code Luau, DataStore, Combat, AI Monster, Hatch, Network Security và tích hợp Model.
* **3D Artist / Modeler (Thằng Anh):** Thiết kế 3D Models (Blender/Studio), Textures, Biome Props, Pet Rocks, Weapons và trang trí bản đồ.

---

## 📂 Cấu Trúc Dự Án Chuẩn

```text
GAME-BOBLOX/
├── StealAPetRock.rbxl          # File Place Roblox Studio nền (3D Artist mở trực tiếp file này)
├── default.project.json        # File cấu hình Rojo (dùng để sync code vào Studio)
├── assets/                     # Kho tài nguyên 3D & hình ảnh của Artist
│   ├── models/                 # Chứa file .rbxm (Roblox Model), .fbx, .blend
│   ├── textures/               # Chứa texture, icon, decal (.png, .jpg)
│   └── README.md               # Quy ước đặt tên & hướng dẫn xuất file cho Artist
├── ReplicatedStorage/          # Client/Server shared modules & configs
├── ServerScriptService/        # Server backend services (Combat, Data, Hatch, AI...)
├── StarterPlayer/              # Client controllers & UI scripts
├── docs/                       # Tài liệu kiến trúc & QA benchmark reports
└── tests/                      # Kịch bản kiểm thử bảo mật & logic
```

---

## 🛠️ Hướng Dẫn Dành Cho 3D Artist (Cách Làm Việc Đơn Giản Nhất)

### Bước 1: Tải dự án về máy
* Clone repo về máy bằng Git, hoặc lên GitHub bấm **Code -> Download ZIP** và giải nén.

### Bước 2: Mở Roblox Studio
* Nhấp đúp vào file **`StealAPetRock.rbxl`** ở thư mục gốc để mở game trong Roblox Studio.

### Bước 3: Làm Model & Xuất File
1. Tạo/import model 3D (từ Blender dạng `.fbx` hoặc dựng trực tiếp bằng Part/Mesh trong Studio).
2. Tinh chỉnh màu sắc, Material, kích thước và căn chỉnh va chạm (`CanCollide`).
3. Gom các Part của model thành 1 `Model`, đặt `PrimaryPart`.
4. Chuột phải vào Model trong cửa sổ **Explorer** -> Chọn **Save to File...**
5. Lưu file định dạng **`.rbxm`** vào thư mục `assets/models/`.
6. Commit & Push lên nhánh riêng của mình trên Git (hoặc gửi file `.rbxm` cho Thiện Phan).

*Xem chi tiết quy ước đặt tên tại: [`assets/README.md`](assets/README.md)*

---

## 💻 Hướng Dẫn Dành Cho Developer (Rojo + VS Code)

### Đồng bộ Code vào Roblox Studio
1. Cài đặt plugin **Rojo** trên VS Code và Roblox Studio.
2. Mở thư mục dự án trong VS Code.
3. Khởi động Rojo:
   ```bash
   rojo serve
   ```
4. Trong Roblox Studio (đang mở `StealAPetRock.rbxl`), mở tab **Plugins** -> bấm **Rojo** -> bấm **Connect**.
5. Mọi chỉnh sửa script trong `ReplicatedStorage`, `ServerScriptService`, `StarterPlayer` sẽ tự động đồng bộ theo thời gian thực vào Studio.

---

## 🌿 Quy Trình Phối Hợp Nhánh (Git Workflow)

1. Nhánh `main`: Nhánh ổn định, chứa code và place mới nhất.
2. Khi làm tính năng hoặc model mới: Tạo nhánh mới (ví dụ: `art/new-pet-models` hoặc `feature/combat-update`).
3. Sau khi hoàn thành và kiểm tra: Tạo Pull Request (PR) về `main`.
