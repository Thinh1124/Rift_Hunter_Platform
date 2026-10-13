# 07 · TRA CỨU DỰNG MAP — RIFT HUNTER

Mọi thứ dưới đây lấy từ dữ liệu thật trong project, không phải ước lượng.

---

## 0. Hai ảnh tra cứu nhanh

| Ảnh | Nội dung |
|---|---|
| `docs/tile_ground_atlas.png` | Atlas 1 `world_tileset.png` 16×16 — **viền xanh = ô có collision** |
| `docs/tile_platform_atlas.png` | Atlas 2 `platforms.png` 4×4 — viền xanh = collision, **viền vàng = one-way** |

Mở 2 ảnh đó cạnh Godot Editor khi vẽ map. Không có ảnh này thì không biết ô nào
đi được, ô nào chỉ để trang trí.

---

## 1. GROUND — đất đi được

Tileset: `assets/Terrain/level_ground_tileset.tres` → **source 0** = `world_tileset.png`

Chỉ **9 ô** có collision: cột 0–2 × hàng 0–2.

| Toạ độ (cột, hàng) | Vai trò |
|---|---|
| `(0,0)` `(1,0)` `(2,0)` | mặt cỏ — hàng trên cùng của khối đất |
| `(0,1)` `(1,1)` `(2,1)` | đất giữa |
| `(0,2)` `(1,2)` `(2,2)` | đất đáy |

Ghép theo cột: **0 = mép trái, 1 = giữa, 2 = mép phải**.

⚠️ 207 ô còn lại trong atlas này **không có collision** — dùng làm nền hoặc trang
trí đều được, nhưng đừng đặt làm mặt đất.

---

## 2. BỆ ĐI (platform)

Tileset: `level_ground_tileset.tres` → **source 1** = `platforms.png`

| Hàng | Loại | Collision |
|---|---|---|
| 0 | bệ cỏ xanh | ❌ **không có** |
| **1** | **bệ đất** | ✅ **có, ONE-WAY** |
| 2 | bệ lửa | ❌ **không có** |
| 3 | bệ băng | ❌ **không có** |

Ô có collision: `(0,1)` trái · `(1,1)` giữa · `(2,1)` phải.

**ONE-WAY nghĩa là:**
- Nhảy từ dưới lên → đứng được
- Đi từ trên xuống / rơi xuống → **xuyên qua**

### ⚠️ Cái bẫy dễ nhất khi làm map

Bệ cỏ, bệ lửa, bệ băng nhìn đẹp và rất dễ bị đặt nhầm, **nhưng player đi xuyên
qua không dừng**. Trong atlas đó chỉ bệ đất ở hàng 1 là đi được.

Muốn một bệ cỏ đi được thì **ghép 3 ô bệ đất hàng 1**, rồi trang trí viền bằng
bệ cỏ đặt ở `Decor`.

---

## 3. DECOR — trang trí

Tileset: `assets/Terrain/level_decor_tileset.tres` — 256 ô, **không ô nào có
collision**. Node `Decor` trong LevelBase đã bật `collision_enabled = false`.

| Toạ độ | Thứ |
|---|---|
| `(0,3)`–`(0,5)`, `(1,3)`–`(1,5)` | bụi cây xanh (cao 3 ô) |
| `(2,4)`–`(2,6)` | cây cọ |
| `(3,5)`–`(3,6)` | cây lớn màu cam |
| `(4,3)`–`(4,5)` | cây thông xanh đậm |
| `(5,3)`–`(5,4)` | bảng gỗ |
| `(5,7)` | đồng xu vàng |
| `(6,3)`–`(6,5)` | nấm nỏ |
| `(7,5)`–`(7,7)` | nấm tím |
| `(8,5)`–`(8,7)` | nấm xanh |
| `(6,7)`–`(6,8)`, `(7,7)`, `(8,7)`–`(8,8)` | đá tảng / đá trang trí |
| `(0,6)` | hoa |
| `(0,7)` `(1,7)` `(0,8)` `(1,8)` | bình thuốc — xanh / vàng / xanh dương / tím |
| `(2,3)` | biển báo "!" |
| `(2,7)`–`(2,8)` | cột gỗ |
| `(3,8)` | bơm (rộng 2 ô) |
| `(3,0)`–`(3,2)` | khối đá nâu 3×3 (trang trí) |
| `(4,0)`–`(4,2)` | khối đá đỏ sẫm |
| `(5,0)`–`(5,2)` | khối đá vàng |
| `(6,0)`–`(6,2)` | tinh thể xanh |
| `(7,0)`–`(7,2)` | đá xám có dấu "?" |
| `(8,0)`–`(8,2)` | đá xám có dấu "!" |
| `(9,0)`–`(11,0)` | sỏi nâu (3 ô rộng) |
| `(9,1)`–`(11,1)` | sỏi kem |
| `(9,2)`–`(11,2)` | sỏi hồng |

Cây / nấm / đá tảng là khối **nhiều ô** — đặt liền nhau theo chiều dọc như trong
ảnh atlas.

---

## 4. NỀN & NƯỚC

Cũng nằm trong `world_tileset.png`, đặt vào `Decor` hoặc dùng cho
`ParallaxBackground`.

| Toạ độ | Thứ |
|---|---|
| `(0,9)`–`(0,15)` | trời trắng → xanh nhạt |
| `(1,9)`–`(1,15)` | trời kem → cam |
| `(2,9)`–`(2,15)` | trời hồng → tím |
| `(3,9)`–`(3,15)` | trời xám → xám tím |
| `(4,9)`–`(4,14)` | nước sâu, mép sóng **hồng** |
| `(5,9)`–`(5,14)` | nước sâu, mép sóng **cam** |

Hàng 9–10 là **mặt nước / mép sóng**, hàng 11 trở xuống là **thân nước** (lặp
dọc). Không có collision.

---

## 5. VẬT THỂ ĐẶT VÀO MAP

### 5.1 Quái — `scenes/enemies/`

| Scene | Hành vi | HP | Nên đặt ở |
|---|---|---|---|
| `Mushroom.tscn` | đi tuần | 1 | mặt đất |
| `Bomb.tscn` | đi tuần, chậm | 2 | mặt đất |
| `RockGrunt.tscn` | đi tuần | 1 | mặt đất |
| `PatrolRockGrunt.tscn` | đi tuần nhanh | 1 | mặt đất |
| `ChargerEnemy.tscn` | lấy đà rồi lao, choang khi đụng tường | 2 | hành lang thẳng, cần chỗ trống phía trước |
| `ShooterEnemy.tscn` | đứng yên, bắn 1 phát / 2s | 1 | trên cao, tầm nhìn thẳng |
| `Bee.tscn` | bay, đuổi | 1 | trên không |
| `FlyingBug.tscn` | bay, đuổi | 1 | trên không |
| `SummonedPatrolEnemy.tscn` | loại boss gọi ra | 1 | tự sinh, không đặt tay |
| `Boss.tscn` | boss 2 giai đoạn, tự gọi quái mỗi 8s | 20 | cuối màn |

`Enemy.tscn` / `PatrolEnemy.tscn` / `FlyingEnemy.tscn` là **scene lõi**, không có
hình — không đặt được.

`MonsterGate.tscn` / `BigGate.tscn` là cổng, xem mục 5.4.

### 5.2 Bẫy — `scenes/objects/`

| Scene | Tham số chỉnh được | Ghi chú |
|---|---|---|
| `Spikes.tscn` | `tile_count` (số ô dài), `rotation_dir` (Up/Down/Left/Right) | Hazard layer 8, **giết ngay** |
| `Saw.tscn` | `speed`, `path_length`, `direction`, `rotation_speed`, `damage`, `pause_at_ends` | cưa chạy trên đoạn thẳng |
| `FallingPlatform.tscn` | `fall_delay`, `fall_gravity`, `respawn_time` | đứng vào rồi rơi, tự hồi lại |
| `KillZone.tscn` | — | vực chết, đặt dưới hố |

### 5.3 Spawner — `scenes/objects/`

| Scene | Tham số | Ghi chú |
|---|---|---|
| `EnemySpawner.tscn` | `enemy_scene`, `count`, `radius`, `once` | Player đi vào là thả quái quanh nó |

### 5.4 Cổng — `scenes/enemies/` + `scenes/objects/`

| Scene | Vai trò |
|---|---|
| `ExitGate.tscn` | cổng ra cuối màn — mở khi đủ **10 mảnh rift** (`requires_all_gates`) |
| `Checkpoint.tscn` | cổng lưu giữa màn, chạm là cứu |
| `MonsterGate.tscn` | cổng quái — giữ `interact` để đóng, quái ngừng thả |
| `BigGate.tscn` | cổng sau boss |

### 5.5 Vật phẩm — `scenes/objects/`

| Scene | Tham số | Ghi chú |
|---|---|---|
| `RiftShard.tscn` | — | mảnh rift, **quái tự rơi ra**, không đặt tay |
| `Pickup.tscn` | `kind`, `amount`, `value` | vật phẩm chủ động (điểm…) |
| `Shield.tscn` | — | khiên |
| `NPC.tscn` | `dialogue_id`, `hint_after_deaths`, `face_player` | nhân vật hướng dẫn |

### 5.6 Không đặt tay

`Projectile.tscn`, `EnemyProjectile.tscn`, `DustFX.tscn`, `PickupFX.tscn`,
`DialogueBubble.tscn` — engine tự sinh.

---

## 6. Thành phần bắt buộc của mỗi màn

| Node | Bắt buộc | Ghi chú |
|---|---|---|
| `PlayerSpawn` | ✅ | Player được đặt vào đây lúc `_ready()` |
| `Ground` | ✅ | ô có collision ở mục 1 |
| `Objects` | ✅ | chứa toàn bộ quái / bẫy / cổng |
| `KillZone` | ✅ nếu có hố | phải bọc hố, không phải để trống |
| `ExitGate` | ✅ | không có thì không hoàn thành màn |
| `Checkpoint` | ⭐ khuyến nghị | 1–2 cổng giữa màn |
| `Decor` | tuỳ chọn | cây, đá, nấm |
| **≥ 10 quái** | ✅ | đủ số mảnh rift để mở cổng |

---

## 7. Bẫy khi đặt Spawner

`EnemySpawner.radius` mặc định **48**, còn `TriggerZone` chỉ **32**.

⇒ Quái rải ra được tới 48px nhưng Player có thể đứng ngay tâm vùng (0px) →
quái **sinh đè lên Player** → Player đang rơi nên `can_stomp()` trả true →
quái bị giết ngay, không thu được mảnh rift.

**Khi đặt spawner trong map: đặt `radius ≤ 32`**, hoặc đặt ở chỗ Player không thể
đứng trùng (trên bệ, trong hố, sau cửa).

---

## 8. Ảnh PNG nào thực sự dùng

| File | Dùng cho |
|---|---|
| `assets/Terrain/world_tileset.png` | ✅ atlas chính — ground + decor + nền |
| `assets/Terrain/platforms.png` | ✅ bệ đi |
| `assets/Terrain/Terrain (16x16).png` | ❌ **không tileset nào tham chiếu** |

Muốn dùng ô trong `Terrain (16x16).png` thì phải thêm nó làm atlas source mới
trong TileSet trước.