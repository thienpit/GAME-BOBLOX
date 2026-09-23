# HƯỚNG DẪN DÀNH CHO 3D ARTIST (MODEL & TEXTURE)

Thư mục này dùng để lưu trữ toàn bộ file 3D, Texture và Model của game.

---

### 1. Cấu trúc thư mục
* `assets/models/`: Chứa file model 3D (`.rbxm`, `.fbx`, `.obj`, `.blend`).
* `assets/textures/`: Chứa file texture, icon, decal (`.png`, `.jpg`).

---

### 2. Quy trình làm việc chuẩn (Workflow)

#### Cách 1: Làm trực tiếp trong Roblox Studio (Khuyên dùng)
1. Mở file `StealAPetRock.rbxl` ở thư mục gốc bằng **Roblox Studio**.
2. Kéo model 3D hoặc build trực tiếp trong Studio.
3. Căn chỉnh kích thước, Color, Material, SurfaceAppearance (Texture) cho chuẩn.
4. Gom các Part thành 1 `Model`.
5. Chuột phải vào Model trong cửa sổ **Explorer** -> Chọn **Save to File...**
6. Lưu file định dạng **`.rbxm`** vào thư mục `assets/models/`.
7. Commit và push file `.rbxm` lên Git (hoặc báo Coder để kéo vào game).

> **Vì sao nên dùng file `.rbxm`?**
> File `.rbxm` giữ nguyên 100% các thiết lập của Roblox (Anchored, CanCollide, Material, Texture, ParticleEmitter...), Coder chỉ cần kéo vào Workspace là game chạy ngay mà không bị lệch vị trí hay mất texture.

#### Cách 2: Làm từ Blender / Maya
1. Xuất file định dạng **`.fbx`** (hoặc `.obj`), kích thước chuẩn tỉ lệ Roblox (1 Stud ≈ 28cm).
2. Lưu file `.fbx` vào `assets/models/`.
3. Lưu các map texture (Color, Normal, Roughness, Metalness) vào `assets/textures/`.

---

### 3. Quy ước đặt tên (Naming Convention)

Để Coder gắn code tự động dễ dàng, đặt tên file theo mẫu:

| Loại Asset | Tiền tố | Ví dụ |
| :--- | :--- | :--- |
| **Đá cưng (Rock Pet)** | `Rock_<Tên>` | `Rock_Ruby.rbxm`, `Rock_Diamond.rbxm` |
| **Quái vật (Monster)** | `Monster_<Tên>` | `Monster_Golem.rbxm`, `Monster_Ghost.rbxm` |
| **Trang trí (Deco/Map)** | `Deco_<Tên>` | `Deco_Tree_Pine.rbxm`, `Deco_Bench.rbxm` |
| **Vũ khí (Bat/Weapon)** | `Bat_<Tên>` | `Bat_Wooden.rbxm`, `Bat_Cyber.rbxm` |
| **Vùng đất/Cổng (Zone)** | `Zone_<Tên>` | `Zone_Magma_Gate.rbxm` |

---

### 4. Lưu ý kỹ thuật cho 3D Artist
* **MeshPart:** Đảm bảo `CollisionFidelity` hợp lý (Default cho part cần va chạm chính xác, Box hoặc Hull cho part trang trí để tối ưu FPS).
* **Anchored:** Các đồ decor/công trình nên để `Anchored = true`. Quái vật và Pet để `Anchored = false` (để code điều khiển di chuyển).
* **PrimaryPart:** Luôn set thuộc tính `PrimaryPart` cho Model (chọn part trung tâm/gốc của model).
