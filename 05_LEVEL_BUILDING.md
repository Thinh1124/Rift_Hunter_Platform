# 05 · XÂY DỰNG MÀN CHƠI — RIFT HUNTER

## Nguyên tắc

Mọi màn **kế thừa** từ `scenes/levels/LevelBase.tscn` (New Inherited Scene).
`LevelBase` đã có sẵn: Ground / Decor / Objects / PlayerSpawn / Player / HUD /
TouchControls / PauseMenu / ParallaxBackground + nhạc.

Cài đặt của màn nằm ở `@export` của `LevelBase`:

| Thuộc tính | Ý nghĩa |
|---|---|
| `level_number` | **Bắt buộc** — phải trùng số màn (1..6). Màn hướng dẫn là 0. |
| `music` | Nhạc nền (AudioStream) |
| `limit_left / right / top / bottom` | Giới hạn camera theo toạ độ thế giới |
| `season` | Chỉ là metadata, không ảnh hưởng gì |

---

## Thành phần BẮT BUỘC để màn chơi được

| Node | Vì sao |
|---|---|
| **PlayerSpawn** | Điểm spawn đầu màn. Thiếu → player nằm ở (0,0) |
| **Ground** | Sàn. Thiếu → rơi xuống vô tận |
| **KillZone** | Rơi xuống = chết ngay (không trừ dần máu) |
| **ExitGate** | Đặt cuối màn. **Chỉ mở khi thu đủ 10 mảnh Rift** |
| **≥ 10 kẻ địch** | Mỗi quái rơi **1 mảnh Rift**. Ít hơn 10 con → không bao giờ mở được cổng |

Thêm **Checkpoint.tscn** ở giữa màn để người chơi không phải chơi lại từ đầu.

---

## Luồng chơi của một màn

```
vào màn
   ↓  reset_run(): điểm=0, mạng=3, shard_count=0
đánh quái  →  mỗi quái rơi 1 RiftShard
   ↓
nhặt đủ 10 mảnh  →  ExitGate nghe shards_changed → mở cánh cổng
   ↓
chạm vào cánh cổng  →  level_completed
   ↓
lưu sao (3/2/1 theo máu còn lại) + mở khoá màn tiếp theo
```

> **Lưu ý thiết kế:** `ExitGate` cũng mở khi **hết cổng quái** (`MonsterGate`).
> Đó là đường thoát *dự phòng* cho màn không đánh quái. Nếu màn bắt buộc phải
> gom mảnh thì **tắt `requires_all_gates` trên ExitGate** và đừng đặt MonsterGate.

---

## Thêm màn mới (Level7 trở đi)

1. Mở `LevelBase.tscn` → Scene → New Inherited Scene → lưu `scenes/levels/Level7.tscn`
2. Đặt `level_number = 7`
3. Đặt `limit_*` theo kích thước bản đồ
4. Thêm KillZone + ExitGate + Checkpoint + kẻ địch vào node `Objects`
5. Tăng `GameManager.LEVEL_COUNT` trong `autoload/game_manager.gd`
6. Nếu có ải boss: đặt `GameManager.BOSS_LEVEL = 7`

`GameManager.level_path(n)` tự sinh đường dẫn `res://scenes/levels/LevelN.tscn`.

Ảnh thumbnail ở panel chọn màn lấy tự động từ `res://assets/Menu/Levels/NN.png`.

---

## Công cụ reset tiến trình (test / demo)

```
godot --headless --quit-after 600 res://tools/reset_progress.tscn                       # xóa hết
godot --headless --quit-after 600 res://tools/reset_progress.tscn -- --keep-settings   # giữ âm lượng
godot --headless --quit-after 600 res://tools/reset_progress.tscn -- --dry-run         # chỉ xem
```

Lưu ý: tham số phải đặt **sau** `--` và **sau** đường dẫn scene.

---

## Kiểm tra trước khi bàn giao màn

```powershell
godot --headless --editor --quit-after 250 --import
& "C:\Users\thinh\AppData\Local\Temp\opencode\run_tests.ps1"
```

Các test liên quan: `LevelBaseTest`, `Level0Test`, `ExitGateTest`, `PickupTest`,
`TutorialTest`. Chụp UI để soi bằng mắt:

```
godot --rendering-driver opengl3 --resolution 640x360 --position -3000,-3000 --quit-after 900 res://tests/ui_shots.tscn
```

---

## Quy ước khoảng cách (bắt buộc)

- Nút chạm tối thiểu **48×48** trên viewport 640×360
- Chừa safe area (`DisplayServer.get_display_safe_area`)
- UI khai báo node trong `.tscn`, **không** tạo node bằng code
- Giao tiếp giữa scene qua `EventBus` / signal / group, **không** dùng đường dẫn node cứng
- Mọi số cân bằng dùng `@export`