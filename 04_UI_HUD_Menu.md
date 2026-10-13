# 04 · HUD, UI, MENU
Dán CONTEXT (file 00) trước. Mỗi màn là một scene riêng. Mọi UI cập nhật qua **EventBus**, KHÔNG tham chiếu trực tiếp Player.

**Quy cách chung (dán kèm mọi prompt UI):**
```
Control anchor Full Rect, theme pixel dùng chung res://addons/pixel_ui/themes/wood.tres (font pixel cố định 8px, nền nút 9-slice).
Nút chạm tối thiểu 48x48 px trên viewport 640x360. Chừa safe area (DisplayServer.get_display_safe_area).
Chuyển cảnh: fade 0.3s qua autoload SceneTransition (ColorRect đen trong CanvasLayer cao nhất).
Không dùng đường dẫn node cứng; nút dùng signal pressed.
```

---

## PROMPT 4.0 · Theme + SceneTransition

```
[dán CONTEXT + quy cách chung]
Tạo: 1) res://assets/ui/theme.tres (Theme: font pixel đặt sau, font size 8/16/24, Button normal/hover/pressed StyleBoxFlat bo góc 2px màu #2b2d42/#8d99ae/#ef233c, Label màu trắng, ProgressBar).
   [LỊCH SỬ: theme này đã bị xoá. Dùng res://addons/pixel_ui/themes/wood.tres.]
2) Autoload SceneTransition.gd (CanvasLayer layer 100): func change_scene(path:String) fade-out 0.3s -> change_scene_to_file -> fade-in 0.3s. Cập nhật GameManager dùng hàm này.
NGHIỆM THU: đổi cảnh có fade, không nháy hình.
```

## PROMPT 4.1 · Boot + MainMenu + LevelSelect

```
[dán CONTEXT + quy cách chung]
# Boot.tscn (main scene của project)
Control > TextureRect/Label(Logo tên game, export game_title:String làm placeholder), ProgressBar nhỏ (giả loading)
HÀNH VI: logo fade-in 0.5s, giữ 0.5s, fade-out 0.5s (tổng 1.5s); trong lúc đó SaveManager.load_data() và preload scene MainMenu; xong -> SceneTransition.change_scene(MainMenu).

# MainMenu.tscn
Control > Background (parallax đơn giản), Title, VBoxContainer(Chơi, Chọn màn, Cài đặt, Thoát)
| Nút | Kết quả |
| Chơi | GameManager.reset_run(); vào ải unlocked_level mới nhất |
| Chọn màn | LevelSelect |
| Cài đặt | mở Settings (popup) |
| Thoát | get_tree().quit() (ẩn trên mobile) |
Phát nhạc menu bằng AudioManager.

# LevelSelect.tscn
GridContainer 3x2 (6 ô). Mỗi ô: số ải, 0-3 sao (đọc SaveManager.stars). Ô > unlocked_level: mờ + icon khóa, không bấm được. Nút Back góc trên-trái.
Ô 6 hiển thị icon boss.
NGHIỆM THU: Boot -> MainMenu mượt; ải khóa không vào được; sao hiển thị đúng sau khi thắng.
```

## PROMPT 4.2 · HUD

```
[dán CONTEXT + quy cách chung]
# HUD.tscn (CanvasLayer, layer 5)
NODE TREE:
HUD
├─ MarginContainer (safe area)
│   ├─ HBox trên-trái: HeartsBox (HBoxContainer icon tim) + Label "x3" (mạng, icon lấy từ GameManager.selected_character.icon)
│   ├─ Label (Score) giữa-trên: "000000"
│   ├─ Label (Gates) cạnh Score: "Cổng 2/4" (icon cổng)
│   ├─ Label (Fruit) "🍎 12/50" (icon trái cây)
│   ├─ TextureButton (PauseButton) góc trên-phải 40x40
│   └─ BossBar (TextureProgressBar, rộng 300, giữa-dưới-trên, ẩn mặc định, tên "BOSS")
LẮNG NGHE EventBus:
| Signal | Cập nhật |
| player_hp_changed(cur,max) | vẽ lại tim: đầy/nửa/rỗng |
| lives_changed | label mạng |
| score_changed | label điểm (đếm tăng dần 0.3s) |
| gates_changed(rem,total) | "Cổng %d/%d"; rem=0 thì chữ đổi xanh + nhấp nháy "Mở cổng thoát!" |
| fruit_collected | label quả |
| boss_hp_changed | hiện BossBar lần đầu, cập nhật value |
| boss_defeated | ẩn BossBar sau 1s |
PauseButton -> mở PauseMenu.
Đồng bộ trạng thái ban đầu từ GameManager lúc _ready (vì có thể đã bỏ lỡ signal).
NGHIỆM THU: HUD đúng khi đổi level; mất máu tim giảm; HUD không che khu vực nút cảm ứng.
```

## PROMPT 4.3 · Pause + Game Over + Level Complete

```
[dán CONTEXT + quy cách chung]
# PauseMenu.tscn (CanvasLayer layer 20, process_mode = ALWAYS)
Panel mờ đen 60% + VBox: Tiếp tục / Chơi lại / Cài đặt / Về menu
Hiện: get_tree().paused=true. Tiếp tục: paused=false + đóng.
Phím/action "pause" cũng bật/tắt. Chơi lại: paused=false, GameManager.restart_level(). Về menu: paused=false, GameManager.go_to_menu().
Âm lượng nhạc giảm 50% khi pause.

# GameOver.tscn (CanvasLayer layer 20, process_mode ALWAYS)
Hiện khi nhận EventBus.game_over: tiêu đề "GAME OVER", điểm cuối, nút Chơi lại (GameManager.reset_run + restart) / Về menu. Làm chậm thời gian (Engine.time_scale 0.3) 0.5s rồi dừng.

# LevelComplete.tscn (CanvasLayer layer 20)
Hiện khi nhận EventBus.level_completed: tiêu đề "HOÀN THÀNH!", điểm, 3 sao xuất hiện lần lượt (0.3s/sao, SFX).
Số sao: HP đầy = 3, HP≥2 = 2, còn lại 1. Ghi SaveManager.set_stars + unlock(level+1) + best_score; save().
Nút: Màn tiếp (Level6 xong -> màn Thắng Game: dòng chữ chúc mừng + nút Về menu) / Chơi lại / Về menu.
NGHIỆM THU: pause giữa chừng đóng băng toàn bộ logic (quái, timer); Chơi lại reset đủ mạng/điểm; sao lưu đúng.
```

## PROMPT 4.4 · Settings

```
[dán CONTEXT + quy cách chung]
# Settings.tscn (Control dạng popup, process_mode ALWAYS, dùng được từ MainMenu và PauseMenu)
Thành phần: HSlider Nhạc (0-1), HSlider SFX (0-1), CheckButton Rung, HSlider Độ mờ nút ảo (0.2-1.0), HSlider Kích thước nút ảo (0.8-1.3), nút Đóng.
HÀNH VI: kéo slider áp dụng ngay (AudioManager.set_music_volume/set_sfx_volume, Input.vibrate_handheld khi bật rung khi bị đánh); lưu SaveManager khi đóng. Đọc giá trị hiện tại lúc mở.
NGHIỆM THU: tắt/mở lại game vẫn giữ cài đặt.
KHÔNG LÀM: đa ngôn ngữ, đồ họa nâng cao.
```

---

## NÚT ẢO MOBILE — `scenes/ui/TouchControls.tscn`

`CanvasLayer` layer 10, có sẵn trong `LevelBase.tscn` nên mọi màn đều tự có.
Dùng `TouchScreenButton` → giữ nút phải **và** bấm nhảy cùng lúc vẫn được
(mỗi nút giữ 1 touch index riêng).

### Bố cục

```
┌──────────────────────────────────────────┐
│                                          │   ← HUD (CanvasLayer riêng)
│  ◀ ▶                            ⚔  ▲     │   ← 2 nút trái dưới, 2 nút phải dưới
└──────────────────────────────────────────┘
                                        ⬛   ← Interact, nằm TRÊN nút tấn công
```

| Nút | Vị trí | Màu | Icon |
|---|---|---|---|
| Left | dưới-trái | xanh xám `(0.38,0.50,0.72)` | mũi tên **trái** |
| Right | dưới-trái | xanh xám | mũi tên **phải** |
| Jump | dưới-phải, ngoài cùng | xanh lá `(0.28,0.76,0.36)` | mũi tên **lên** |
| Attack | dưới-phải, trong Jump | đỏ `(0.86,0.30,0.22)` | **thanh kiếm** |
| Interact | trên nút Attack | xanh dương `(0.28,0.56,0.90)` | cổng |

### Icon

Vẽ bằng `scripts/ui/pixel_icons.gd`, **không** dùng file ảnh:

| Icon | Hàm |
|---|---|
| mũi tên trái | `PixelIcons.arrow(size, white, PI)` |
| mũi tên phải | `PixelIcons.arrow(size, white, 0.0)` |
| mũi tên lên | `PixelIcons.arrow(size, white, -PI * 0.5)` |
| kiếm | `PixelIcons.sword(size, white)` |
| cổng | `PixelIcons.gate(size, white)` |

Trục Y trong màn hình hướng **xuống** → muốn mũi tên lên phải xoay **ngược**
chiều kim đồng hồ, tức `angle = -PI/2`.

`_circle_texture()` vẽ hình tròn rồi `_blit_centered()` dán icon ở chính giữa,
cỡ icon = 50% cỡ nút. Pixel trong suốt bị bỏ, pixel trượt ra ngoài hình tròn
cũng bị bỏ nên icon không bao giờ lọt ra viền.

### Cỡ & an toàn

Mọi nút bị kẹp ở tối thiểu `UIButton.MIN_TOUCH_SIZE` (48px) bất kể
`button_scale` nhỏ đến đâu — `_layout()` và `_button_size_for()` dùng **cùng
một phép tính**, nếu lệch thì `button_center()` (dùng cho test) sẽ trả về
tâm sai so với vị trí vẽ thật.

### Bật xem trên desktop

`show_on_desktop` / `force_visible` mặc định **false** — chỉ hiện trên mobile.
Muốn xem trên PC:

- Scene `tests/EnemyGalleryTest.tscn` đã bật sẵn (`force_visible = true`,
  `opacity = 1.0`)
- Chụp ảnh: `godot --rendering-driver opengl3 --position -3000,-3000 res://tests/touch_shots.tscn`

---

## KIỂM TRA CUỐI (end-to-end)
- [ ] Boot → MainMenu → Chơi → Level1 → đóng cổng → Exit → LevelComplete → Level2
- [ ] Chết hết mạng → GameOver → Chơi lại
- [ ] Pause/Resume giữa trận không lỗi
- [ ] Level6: boss chết → BigGate → đóng → màn Thắng game
- [ ] Xoay/đổi tỉ lệ màn hình (16:9 đến 20:9) HUD không méo, không bị tai thỏ che

---
---

# PHẦN BỔ SUNG (làm sau khi phần chính chạy ổn)

## QUY TẮC "UI CHỈNH ĐƯỢC BẰNG KÉO THẢ" (dán kèm MỌI prompt UI, kể cả ở trên)

```
Mọi node UI phải được khai báo sẵn trong file .tscn (hiện ra trong Scene dock),
KHÔNG tạo bằng code. Script chỉ lấy tham chiếu bằng @onready / %UniqueName và cập nhật nội dung.
Mọi nút/nhãn đặt tên rõ ràng và bật "Unique Name in Owner".
Bố cục dùng Container (MarginContainer, HBox/VBox/GridContainer), không đặt vị trí cứng bằng pixel
trừ chỗ bắt buộc. Phần lặp lại (ô tim, ô chọn màn, ô nhân vật) là scene con riêng
(HeartIcon.tscn, LevelSlot.tscn, CharacterSlot.tscn); script chỉ nhân bản scene con.
Màu, font, kiểu nút nằm trong theme.tres.
KIỂM TRA: mở .tscn, Scene dock phải thấy đầy đủ cây node. Nếu chỉ thấy node gốc -> làm lại.
```

---

## PROMPT 4.5 · ConfirmDialog (hộp xác nhận dùng chung)

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# ConfirmDialog.tscn (CanvasLayer layer 30, process_mode = ALWAYS)
NODE: ColorRect(nền mờ 60%) > CenterContainer > PanelContainer > VBox(Label Title, Label Message, HBox(Button Yes, Button No))
Autoload hoặc static helper: ConfirmDialog.ask(title:String, message:String, yes_text:="Đồng ý", no_text:="Hủy") -> trả về await bool.
HÀNH VI: hiện với animation scale 0.9->1 trong 0.15s; bấm ngoài vùng = No; khi mở thì get_tree().paused giữ nguyên trạng thái trước đó.
DÙNG TẠI: Pause > Về menu ("Thoát ải? Tiến độ ải này sẽ mất"), MainMenu > Thoát, Settings > Xóa dữ liệu (nếu có).
NGHIỆM THU: 3 chỗ dùng đều gọi cùng một scene; bấm Yes/No trả về đúng giá trị.
KHÔNG LÀM: hộp thoại nhiều nút, nhập văn bản.
```

## PROMPT 4.6 · LevelBanner + BossWarning

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# LevelBanner.tscn (CanvasLayer layer 6)
NODE: Control > PanelContainer (giữa-trên) > VBox(Label LevelName "LEVEL 3", Label Subtitle "Mùa thu")
EXPORT: show_time=2.0
HÀNH VI: tự chạy khi level load: trượt từ trên xuống 0.3s, giữ show_time, trượt lên 0.3s, queue_free. Đọc level_number và season từ LevelBase.
Level6: LevelName="BOSS", Subtitle tự đặt.

# BossWarning.tscn (CanvasLayer layer 6)
NODE: Control > Label "CẢNH BÁO: BOSS!" + 2 dải đỏ trên-dưới (ColorRect)
HÀNH VI: kích hoạt khi player vào vùng Arena (EventBus thêm signal boss_arena_entered): nhấp nháy đỏ 3 lần trong 1.5s + request_shake(2,0.5) + SFX cảnh báo, rồi biến mất; boss chỉ bắt đầu hành động sau khi cảnh báo kết thúc (boss lắng nghe signal boss_warning_finished).
NGHIỆM THU: banner không chặn input; cảnh báo chỉ hiện 1 lần mỗi lần vào ải boss.
```

## PROMPT 4.7 · Biểu tượng khiên + chữ nổi

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# ShieldIndicator (thêm vào HUD.tscn)
NODE: HBox(TextureRect Icon khiên 16x16, TextureProgressBar dạng vòng hoặc Label giây còn lại), mặc định ẩn
EventBus thêm signals: shield_started(duration:float), shield_ended
HÀNH VI: shield_started -> hiện và đếm ngược mượt; khi còn 2s thì nhấp nháy; shield_ended -> ẩn. Player.add_shield phát 2 signal này.

# FloatingText.tscn (Node2D > Label)
Hàm static FloatingText.spawn(parent, global_pos, text:String, color:=Color.WHITE)
HÀNH VI: bay lên 24px trong 0.6s, mờ dần, tự queue_free. Font pixel size 8, outline đen 1px.
DÙNG TẠI: Pickup (+100), Enemy chết (+200), Boss (+2000), heal ("+1 HP" màu xanh lá).
NGHIỆM THU: nhặt 10 quả liên tiếp không tạo rò rỉ node; chữ luôn nằm trên cùng (z_index cao).
```

## PROMPT 4.8 · Mũi tên chỉ cổng (GateCompass)

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# GateCompass.tscn (thêm vào HUD, CanvasLayer)
NODE: Control (Full Rect, mouse_filter=ignore) > TextureRect (Arrow, 16x16, pivot ở giữa)
HÀNH VI:
| Điều kiện | Kết quả |
| Còn cổng chưa đóng (group "gate", chưa Closed) | tìm cổng gần player nhất; nếu cổng NGOÀI màn hình: mũi tên bám mép màn hình (clamp 16px, tôn trọng safe area), xoay chỉ về cổng, kèm khoảng cách (m) nhỏ |
| Cổng đang trong màn hình | ẩn mũi tên |
| Hết cổng (remaining=0) | chỉ về ExitGate (group "exit") |
| Đang đánh boss | ẩn |
Cập nhật mỗi 0.2s (không mỗi frame), dùng Camera2D.get_screen_center_position + viewport rect để tính ngoài màn hình.
EXPORT: enabled:bool=true (có công tắc trong Settings), update_interval=0.2
NGHIỆM THU: mũi tên đổi sang cổng kế tiếp ngay khi đóng xong; không đè lên nút cảm ứng.
```

## PROMPT 4.9 · Credits

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# Credits.tscn
NODE: Control > VBox(Title, ScrollContainer > Label (RichTextLabel) nội dung, Button Back)
NỘI DUNG (@export_multiline credits_text, chỉnh trong Inspector):
- Tên game / tác giả
- Pixel Adventure 1 by Pixel Frog (itch.io) – ghi đúng giấy phép trên trang asset
- Four Seasons Platformer Sprites by Kevin's Mom's House – ghi đúng giấy phép
- Âm thanh/Nhạc: (điền nguồn khi chọn)
- Công cụ: Godot Engine
HÀNH VI: tự cuộn lên chậm (có thể chạm để dừng), Back về MainMenu. Nút Credits thêm ở MainMenu hoặc Settings.
LƯU Ý: mở trang asset đọc kỹ giấy phép (có yêu cầu ghi nguồn không, dùng thương mại không) trước khi phát hành.
NGHIỆM THU: đọc được toàn bộ nội dung trên màn hình 640x360.
```

## PROMPT 4.10 · Tutorial overlay lần đầu

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# TutorialOverlay.tscn (CanvasLayer layer 8)
NODE: Control > Panel hướng dẫn (Label, TextureRect mũi tên) + vùng "highlight" quanh nút đang nói tới
KỊCH BẢN (chỉ ở Level1, lần chơi đầu; SaveManager lưu cờ tutorial_done):
| Bước | Hiển thị | Chuyển bước khi |
| 1 | "Chạm trái/phải để di chuyển" (viền sáng nút Left/Right) | player di chuyển >= 50px |
| 2 | "Bấm Nhảy" (viền sáng nút Jump) | player nhảy 1 lần |
| 3 | "Nhảy lên đầu kẻ thù để hạ gục" | hạ 1 quái bằng đạp đầu |
| 4 | "Bấm Tấn công để ném" | player tấn công 1 lần |
| 5 | "Đứng gần cổng, GIỮ nút Tương tác để đóng" | đóng cổng đầu tiên |
HÀNH VI: không pause game, chỉ gợi ý; có nút "Bỏ qua" nhỏ; hoàn thành -> tutorial_done=true và không hiện lại.
Có thể tắt/bật lại trong Settings ("Xem lại hướng dẫn").
NGHIỆM THU: bỏ qua giữa chừng cũng được đánh dấu xong; không hiện lại ở Level2.
KHÔNG LÀM: hội thoại dài, tutorial cho từng vật phẩm.
```

## PROMPT 4.11 · Toast (thông báo nhỏ)

```
[dán CONTEXT + quy cách chung + quy tắc kéo thả]
# Toast.tscn (autoload hoặc CanvasLayer layer 40)
API: Toast.show_message(text:String, duration:=1.5)
NODE: Control > MarginContainer (giữa-dưới, trên nút cảm ứng) > PanelContainer > Label
HÀNH VI: hiện fade-in 0.15s, giữ, fade-out; hàng đợi nếu nhiều thông báo (hiện lần lượt).
DÙNG TẠI: Checkpoint ("Đã lưu điểm"), mở khóa ải mới, nhặt đủ 50 quả ("+1 mạng!").
NGHIỆM THU: 3 thông báo liên tiếp hiện đúng thứ tự, không chồng lên nhau.
```

---

## THỨ TỰ LÀM PHẦN BỔ SUNG (theo giá trị / thời gian)

| Thứ tự | Prompt | Thời gian ước tính |
|---|---|---|
| 1 | 4.5 ConfirmDialog | 20 phút |
| 2 | 4.8 GateCompass | 30 phút |
| 3 | 4.7 Khiên + chữ nổi | 30 phút |
| 4 | 4.6 Banner + cảnh báo Boss | 20 phút |
| 5 | 4.11 Toast | 15 phút |
| 6 | 4.10 Tutorial | 40 phút |
| 7 | 4.9 Credits | 15 phút |

**Để sau phát hành:** cửa hàng, thành tựu, bảng điểm, đa ngôn ngữ, tay cầm, quảng cáo/IAP, màn chọn ngôn ngữ/chính sách quyền riêng tư (bắt buộc nếu có quảng cáo hoặc analytics).
