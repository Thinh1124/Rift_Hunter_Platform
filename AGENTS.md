Godot 4.x (4.3+), GDScript static typing. Viewport 640x360, stretch mode viewport,
texture filter Nearest, landscape. Game: 2D pixel platformer kiểu Mario, mobile.
Nhân vật: NHIỀU model nhân vật, đổi được (dữ liệu trong CharacterData Resource, xem prompt 1.5). Asset: Pixel Adventure 1 + Four Seasons tileset.
YÊU CẦU TRẢ LỜI: chỉ trả về (1) cây node, (2) code đầy đủ từng file, (3) các bước
cài đặt thủ công trong editor (nếu có). Không giải thích dài. Không thêm tính năng
ngoài spec. Code phải chạy được ngay, không placeholder "TODO".

THƯ MỤC:
res://autoload/  res://components/  res://scenes/{player,enemies,objects,levels,ui}/
res://scripts/   res://assets/

INPUT MAP: move_left, move_right, jump, attack, interact, pause

COLLISION LAYERS (đặt tên trong Project Settings > Layer Names > 2D Physics):
1 World | 2 Player | 3 Enemy | 4 PlayerHitbox | 5 EnemyHitbox
6 Pickup | 7 Interactable | 8 Hazard
QUY TẮC MASK:
- Player body: layer 2, mask 1
- Enemy body: layer 3, mask 1
- PlayerHitbox (đòn/đạn của player): layer 4, mask 3
- EnemyHitbox (thân quái, đạn quái): layer 5, mask 2
- Hazard (gai, cưa): layer 8, mask 2
- Pickup: layer 6, mask 2
- Interactable (cổng, checkpoint, NPC): layer 7, mask 2

GROUPS: player, enemy, gate, checkpoint, boss, npc

AUTOLOAD (tên singleton): EventBus, GameManager, SaveManager, AudioManager
NHÂN VẬT ĐỔI ĐƯỢC: Player KHÔNG gắn cứng sprite/chỉ số. Mọi nhân vật là 1 file CharacterData (.tres) trong res://data/characters/. GameManager.selected_character:CharacterData quyết định Player dùng model nào.

COMPONENT CÓ SẴN (res://components/):
- HealthComponent (Node): @export max_health:int; var current:int
  signals: health_changed(cur:int, max:int), damaged(amount:int, from_pos:Vector2), died
  func take_damage(n:int, from_pos:=Vector2.ZERO), heal(n:int), reset()
  var invincible:bool (true thì bỏ qua take_damage)
- HitboxComponent (Area2D): @export damage:int=1, knockback:Vector2=Vector2(150,-150)
- HurtboxComponent (Area2D): @export health:HealthComponent
  khi area_entered là HitboxComponent -> health.take_damage(hitbox.damage, hitbox.global_position)
- StateMachine (Node): @export initial_state:State; func change_state(name:StringName)
  State (Node): virtual enter(), exit(), physics_update(delta), handle_input(event)

EVENTBUS SIGNALS (autoload EventBus):
score_changed(score:int), lives_changed(lives:int), player_hp_changed(cur:int,max:int),
gates_changed(remaining:int,total:int), gate_closed(id:StringName), level_completed,
player_died, game_over, boss_hp_changed(cur:int,max:int), boss_defeated,
checkpoint_reached(pos:Vector2), fruit_collected(total:int), request_shake(strength:float,duration:float)

QUY ƯỚC: Scene PascalCase, script snake_case. Mọi số cân bằng dùng @export.
Giao tiếp giữa scene qua EventBus/signal/group, KHÔNG dùng đường dẫn node cứng.

Control anchor Full Rect, theme pixel dùng chung res://addons/pixel_ui/themes/wood.tres (font pixel cố định 8px, nền nút 9-slice).
Nút chạm tối thiểu 48x48 px trên viewport 640x360. Chừa safe area (DisplayServer.get_display_safe_area).
Chuyển cảnh: fade 0.3s qua autoload SceneTransition (ColorRect đen trong CanvasLayer cao nhất).
Không dùng đường dẫn node cứng; nút dùng signal pressed.

Mọi node UI phải được khai báo sẵn trong file .tscn (hiện ra trong Scene dock),
KHÔNG tạo bằng code. Script chỉ lấy tham chiếu bằng @onready / %UniqueName và cập nhật nội dung.
Mọi nút/nhãn đặt tên rõ ràng và bật "Unique Name in Owner".
Bố cục dùng Container (MarginContainer, HBox/VBox/GridContainer), không đặt vị trí cứng bằng pixel
trừ chỗ bắt buộc. Phần lặp lại (ô tim, ô chọn màn, ô nhân vật) là scene con riêng
(HeartIcon.tscn, LevelSlot.tscn, CharacterSlot.tscn); script chỉ nhân bản scene con.
Màu, font, kiểu nút nằm trong theme.tres.
KIỂM TRA: mở .tscn, Scene dock phải thấy đầy đủ cây node. Nếu chỉ thấy node gốc -> làm lại.
