# 08 · NHÂN VẬT — NĂNG KỸ ĐẶC & MỞ KHOÁ

Mọi nhân vật là **1 file `.tres`** trong `res://data/characters/`. Thêm nhân vật
mới = thêm file, **không sửa Player**.

---

## 1. Năng kỹ đặc (Special Ability)

`CharacterData.ability_id` là mã **đọc bằng máy**. `ability` (chuỗi mô tả) chỉ
để hiện lên UI — **không bao giờ parse chuỗi này**.

| `ability_id` | Nhân vật | Hiệu ứng |
|---|---|---|
| `&""` | Pink Man, Virtual Guy, Mask Dude | không có |
| `&"double_jump"` | Ninja Frog | nhảy 2 lần trên không |

### Double Jump

| Thành phần | Ở đâu |
|---|---|
| Clip `double_jump` (6 frame, 32×32) | `assets/frames/ninja_frog_frames.tres` ← `Double Jump (32x32).png` |
| Cờ `_can_double_jump` | `Player.apply_character()` đọc từ `data.ability_id` |
| Cờ `_air_jump_used` | reset trong `notify_landed()` |
| Lực nhảy | `Player.air_jump_mult` (mặc định 0.88) × `jump_mult` của nhân vật |
| Kiểm tra | `Player.can_air_jump()` |

**Luồng:** `do_jump()` đọc cửa sổ coyote **trước khi dừng timer** → nhảy từ mặt
đất thì trả lại toàn bộ lực, nhảy giữa không thì nhân `air_jump_mult`.

**Bẫy đã gặp — đừng lặp lại:**

1. Dừng `coyote_timer` **rồi mới** hỏi `is_stopped()` → luôn `true` → mọi cú
   nhảy thành nhảy trên không, nhảy thấp hơn 12%.
2. Chỉ cho `fall_state` gọi `do_jump()` → bấm jump lúc **đang bay lên** (state
   `Jump`) sẽ không có tác dụng. Phải xử lý trong **cả** `jump_state`.

**Animation:** cú thứ 2 xảy ra khi đã ở sẵn state `Jump` nên `change_state()`
là no-op, `enter()` không chạy → `do_jump()` gọi `apply_jump_animation()` tay.
`JumpState.enter()` cũng gọi chính hàm đó, nên chỗ quyết định clip chỉ có 1.

Nhân vật không có clip `double_jump` → `play_animation_or()` tự về `jump`.

---

## 2. Mở khoá nhân vật

| Nhân vật | File | Mở khoá khi |
|---|---|---|
| Pink Man | `default.tres` | mặc định, không cần vượt màn |
| Virtual Guy | `virtual_guy.tres` | vượt màn **2** |
| Mask Dude | `mask_dude.tres` | vượt màn **3** |
| Ninja Frog | `ninja_frog.tres` | vượt màn **4** |

### Hai trường trong `.tres`

```gdscript
unlocked_by_default = false   # true = mở sẵn, unlock_level bị bỏ qua
unlock_level = 4              # 0 = không cần vượt màn nào
```

`CharacterData.required_level()` gộp 2 trường thành 1 con số (0 = đã mở).

### API

```gdscript
GameManager.is_character_unlocked(data)      # -> bool
GameManager.character_lock_label(data)       # -> "UNLOCK LEVEL 4" hoặc ""
SaveManager.is_level_completed(n)            # đã vượt màn N chưa
SaveManager.mark_level_completed(n)          # GameManager gọi khi hoàn thành màn
```

### `unlocked_level` vs `levels_completed`

Hai biến khác nhau, **đừng lẫn**:

| | Ý nghĩa | Dùng để |
|---|---|---|
| `unlocked_level` | màn lớn nhất được **mở khoá** (1..6) | khoá ô trong LevelSelect |
| `levels_completed` | màn cao nhất đã **vượt qua** (0..6) | mở khoá nhân vật |

`unlocked_level = N+1` sau khi vượt màn N — nên hỏi "đã vượt màn 2 chưa" bằng
`levels_completed >= 2`, **không** dùng `unlocked_level >= 3`.

Save cũ không có `levels_completed` → suy ra từ `unlocked_level - 1` khi nạp,
người đã chơi không bị mất nhân vật.

### ⚠️ Thứ tự dòng trong `.tres`

```ini
[resource]
script = ExtResource("1_script")     ; ← PHẢI ĐỨNG ĐẦU
unlock_level = 4                     ; ← mọi thuộc tính khác đặt sau nó
```

Thuộc tính đặt **trước** dòng `script` sẽ **bị bỏ qua âm thầm** — Resource lúc
đó chưa có script nên không biết property nào tồn tại. Không có cảnh báo.

---

## 3. Giao diện khi chưa mở khoá

`CharacterSelect.tscn`:

```
Stage (HBoxContainer)
├─ PrevButton
├─ Center (VBoxContainer, rộng 96)
│  ├─ LockLabel          ← "UNLOCK LEVEL 4", ẩn khi đã mở
│  └─ Preview (SubViewport 64x64)
└─ NextButton
```

| Khi **đã mở** | Khi **chưa mở** |
|---|---|
| `LockLabel` ẩn | hiện chữ màu hổ phách, **ngay trên đầu** |
| sprite sáng | `modulate = (0.26, 0.26, 0.32)` |
| tên + bảng chỉ số sáng | tên + bảng chỉ số mờ `(0.62, 0.62, 0.68)` |
| chọn được | **không chọn được** |

Menu vẫn liệt kê **tất cả** nhân vật kể cả nhân vật khoá, để người chơi biết
trước có gì để mở.

Dùng `modulate` chứ không dùng stylebox: `SubViewport` nền trong suốt, ô bo góc
bo sẽ trông như hỏng hình.

**Chọn nhân vật khoá:** `_show_current()` không gọi `select_character()`. Nếu
nhân vật **đang chọn** bị khoá (save cũ), `_sync_selection_to_unlocked()` trả về
một nhân vật đã mở — không bao giờ chơi bằng nhân vật khoá.

---

## 4. Kiểm thử

```powershell
& "C:\Users\thinh\AppData\Local\Temp\opencode\run_tests.ps1"
```

`tests/character_ability_test.gd` — 0 failure:

- Frog có `ability_id = double_jump` + clip 6 frame không loop
- Nhảy 1 từ đất = lực đầy; nhảy 2 giữa không = `air_jump_mult` và phát clip
  `double_jump`; nhảy 3 bị chặn; chạm đất thì nạp lại
- 3 nhân vật còn lại **không** nhảy được lần 2, không phát clip `double_jump`
- Bảng mở khoá 0/2/3/4 đúng; dòng nhắc đúng số màn

Chụp ảnh kiểm tra giao diện:

```powershell
godot --rendering-driver opengl3 --position -3000,-3000 res://tests/char_shots.tscn
```

> `char_shots.tscn` ghi đè `SaveManager.levels_completed` rồi **khôi phục lại** khi
> xong — chạy song song với save thật vẫn an toàn.