# 06 · DANH MỤC KẺ ĐỊCH — RIFT HUNTER

Trạng thái sau khi gắn art mới từ `assets/Enemies/`.

---

## Cách dựng lại SpriteFrames

Art nằm rải rác rất nhiều file PNG (mỗi quái 8–90 file, có cặp `_L_` / `_R_`).
Không dựng tay trong `.tres` được. Dùng script:

```powershell
godot --headless --quit-after 900 res://tools/build_enemy_frames.tscn
```

Script quét thư mục, tự sắp frame theo số thứ tự, cắt sát nội dung rồi lưu
`assets/frames/<ten>_frames.tres`.

**Chỉ cần sửa bảng `ENEMIES` trong `tools/build_enemy_frames.gd` khi bổ sung art.**

### Quy tắc bắt buộc

`Enemy.gd: play_anim()` chỉ cần đúng 4 animation:

| Tên | Script gọi | Ghi chú |
|---|---|---|
| `idle` | `play_anim(&"idle")` | |
| `walk` | `play_anim(&"run")` | `ANIM_ALIASES = {run: walk}` → **phải đặt tên `walk`** |
| `hit` | `play_anim(&"hit")` | |
| `dead` | `play_anim(&"dead")` | không loop |

Đặt sai tên (vd `death`, `die`, `run`) → `play_anim()` **fallback về `idle`**,
quái đứng đơ. Script luôn tạo đủ 4 kể cả khi art không có.

### Hướng `_L_` / `_R_`

Chỉ lấy `_R_`. Engine tự `flip_h` khi quái quay trái — không cần nhân bả 2 hướng.

### Sheet ngang (Demon_A)

Ảnh boss là dải ngang ô 100×100 nhưng **quái chỉ chiếm ~20×20, lệch về góc**.
Script tự `get_used_rect()` từng frame để cắt sát, nếu không boss sẽ nhỏ như
không có gì. Số frame tính theo **chiều rộng ảnh** chứ không theo vùng có pixel —
tính theo vùng có pixel sẽ mất frame ở hai đầu.

---

## Bảng kẻ địch

| Scene | Hành vi | Art | Frame | Scale | Hiện | HP |
|---|---|---|---|---|---|---|
| `Mushroom.tscn` | đi tuần | mushroom | 24×24 | 1.5 | 36 | 1 |
| `Bomb.tscn` | đi tuần, chậm, trâu | bomb | 24×24 | 1.5 | 36 | 2 |
| `Bee.tscn` | bay, đuổi | bee | 24×24 | 1.0 | 24 | 1 |
| `FlyingBug.tscn` | bay, đuổi | balloon | 32×32 | 1.0 | 32 | 1 |
| `ShooterEnemy.tscn` | đứng yên, bắn | cactus | 24×24 | 1.5 | 36 | 1 |
| `RockGrunt.tscn` | đi tuần | brickhead | 48×48 | 1.0 | 48 | 1 |
| `PatrolRockGrunt.tscn` | đi tuần | brickhead | 48×48 | 1.0 | 48 | 1 |
| `ChargerEnemy.tscn` | lấy đà rồi lao | brickhead | 48×48 | 1.0 | 48 | 2 |
| `SummonedPatrolEnemy.tscn` | boss triệu hồi | brickhead | 48×48 | 1.0 | 48 | 1 |
| `Boss.tscn` | boss 2 giai đoạn | demon_a | 20×20 | **5.0** | 100 | 20 |

Tỉ lệ chuẩn: quái đi bộ ~36–48 px, quái bay 24–32 px, boss 100 px
(viewport 640×360, ô sàn 16 px).

### Art Brickhead: phải hiểu `Idle_3`

Bộ art Brickhead **không có** `Walk` thật — chỉ có `Idle` (9 hướng) + `Attack` (12 frame).

Điểm mấu chốt: **`Idle_3.png` là frame CHỚP MẮT — gạch không có mắt.**
Dùng nó ở `idle`/`walk` sẽ khiến nhân vật thành một cục gạch trống, người
chơi tưởng lỗi hình. `Attack_12` giống hệt `Idle` nên **không phải hình chết**.

Mapping đã dùng:

| Animation | Nguồn | Ghi chú |
|---|---|---|
| `idle` | `Idle_1_F` ×2, `Idle_3`, `Idle_1_F` @5fps | chớp mắt 1 lần mỗi vòng |
| `walk` | `Idle_1_F`, `Idle_2_F`, `Idle_4_F`, `Idle_1_F` @10fps | bồ đều phía trước |
| `hit` | `Idle_1_F`, `Idle_3` @9fps | chớp mắt mạnh = choáng |
| `dead` | `Idle_1_F`, `Idle_3` ×2 @6fps, không loop | mắt tắt hẳn |

Dùng `_F` (chính diện) chứ không phải `_R` (nghiêng): mắt ở chính diện nhìn rõ
nhất, và hình đối xứng nên `flip_h` không gây vấn đề gì.

---

## ⚠️ Collision layer phải là BITMASK, không phải số thứ tự

Godot đặt `collision_layer = N` theo **bit**, không phải theo số thứ tự layer:

| Layer | Tên | Giá đúng |
|---|---|---|
| 1 | World | 1 |
| 2 | Player | 2 |
| 3 | Enemy | 4 |
| 4 | PlayerHitbox | 8 |
| 5 | EnemyHitbox | 16 |
| 6 | Pickup | 32 |
| 7 | Interactable | 64 |
| 8 | Hazard | 128 |

`Enemy.tscn` từng dùng **số thứ tự** thay vì bitmask. Hậu quả:

- `ContactHitbox` khai báo `layer = 5` → thực chất nằm ở layer 1 **và layer 3**
- `Hurtbox` khai báo `mask = 4` → monitor layer 3

⇒ Enemy **phát hiện chính ContactHitbox của mình** → `take_damage()` lúc spawn →
mọi enemy 1 HP **tự chết ngay khi vừa xuất hiện**, enemy nhiều HP mất máu oan.

Đã sửa trong `Enemy.tscn`: body/hurtbox/stomp `layer = 4`, hurtbox `mask = 8`,
contact hitbox `layer = 16`.

`tests/enemy_library_test.gd` kiểm tra lại điều này cho cả 10 scene.

---

## Đã sửa thêm khi gắn art

| Vấn đề | Nguyên nhân | Sửa |
|---|---|---|
| Enemy đi nhưng hiện hình `idle` | `StateMachine._ready()` chạy **trước** `Enemy._ready()` (con trước cha), lúc đó `sprite` còn null nên `play_anim()` vô hiệu | `Enemy._ready()` áp lại `enter_state()` sau khi lấy được `sprite` |
| Animation `hit` không bao giờ chạy | `enter_state()` không có nhánh `STATE_HURT` | thêm `STATE_HURT → play_anim(&"hit")` |
| `sprite` là `null` ở scene không gán | `Enemy._ready()` fallback tìm node tên `"Sprite"` nhưng node thật tên `"AnimatedSprite2D"` | `_find_sprite()` tìm theo type; thêm `sprite = NodePath(...)` vào mọi scene |
| Boss nhỏ như hạt | `demon_a` frame thật 20×20, scale cũ 1.5 | scale 5, collision `84×100`, StompZone/ShotPoint/SummonGate tính lại |
| Boss bị nhuốm hồng | `modulate` hồng hardcode cho hình Spike Head cũ | bỏ `modulate` |

---

`Enemy.tscn`, `PatrolEnemy.tscn`, `FlyingEnemy.tscn` là scene lõi, không có
`sprite_frames`. Khi tạo quái mới chỉ cần instance 1 trong 3 scene này rồi gán
`sprite_frames` + `scale`.

## Boss

`boss.gd` tự tính `_body_half_size` từ `CollisionShape2D`, nên **đổi kích thước
collider là boss tự thích nghi** — không cần sửa code.

Khi đổi kích thước collider boss, nhớ sửa cả:

- `StompZone.position` (đỉnh đầu)
- `ShotPoint.position` (miệng bắn)
- `SummonGate.position` (cổng triệu hồi)

`BossTest` tự tính giới arena từ `_body_half_size` nên không cần sửa khi đổi size.

---

## Đã xoá

| File | Lý do |
|---|---|
| `rock_grunt_frames.tres` | thay bằng `brickhead_frames.tres` |
| `rift_boss_frames.tres` | thay bằng `demon_a_frames.tres` |
| `spiked_ball_frames.tres` | thay bằng `balloon_frames.tres` |

Ảnh trong `assets/Traps/` (Rock Head, Spike Head, Spiked Ball…) **vẫn giữ** —
còn dùng cho `Spikes.tscn`, `FallingPlatform.tscn`, `saw_frames.tres`,
`boss_projectile_frames.tres`.

---

## Scene thử tương tác: `tests/EnemyGalleryTest.tscn`

Mở scene này và bấm **Run (F6)** để chơi thử với đủ 10 loại quái.

Cấu trúc: kế thừa `LevelBase.tscn` nên có sẵn terrain thật, HUD, TouchControls,
PauseMenu, GameOver. Mọi quái nằm trong `Objects`, nhãn tên nằm trong `Labels`.

| Vị trí | Nội dung |
|---|---|
| `x ≈ 440 – 1140` | 9 quái thường, mỗi con một nhãn tên + HP + hành vi |
| `x ≈ 1230` | Boss, có `arena_left = 296` / `arena_right = 1280` |
| `PlayerSpawn` | `(336, 320)` — đặt sang phải của ngọn đồi vì LevelBase có một bức cao 64px chặn ngang tại `x ≈ 176` |

`limit_left = 296` để Player không đi lọt vào vùng bức chắn.

`InfoBar` là thanh `HBoxContainer` dán đáy màn hình (nền đen 45% để đọc được
trên terrain), `mouse_filter = 2` nên không chặn input.

`tests/gallery_shots.gd` chụp 4 ảnh của scene này vào `user://gallery_shots/`:

```powershell
godot --rendering-driver opengl3 --position -3000,-3000 res://tests/gallery_shots.tscn
```

### Không kiểm tra scene này bằng `run_tests.ps1`

Nó không có assert, giống `BossArenaTest` / `EnemyTest` — đã khai trong `$manual`.

---

## Lưu ý khi thêm art mới

1. Đặt PNG vào `assets/Enemies/<Ten>/` — **chính tả hoa/thường phải khớp**.
   Godot trên Windows chạy được cả hai, nhưng export Android/Linux (phân biệt
   hoa/thường) sẽ **mất sạch** nếu sai case.
2. Giữ kích thước ô vuông (24/32/48…) để `scale` giữ được số tròn.
3. Thêm mục vào `ENEMIES` trong `tools/build_enemy_frames.gd`, chạy lại script.
4. Test: `run_tests.ps1`.