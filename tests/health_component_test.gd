extends Node
## Scene nghiệm thu HealthComponent: 1 HealthComponent, gọi take_damage 3 lần,
## kiểm tra `died` chỉ phát đúng 1 lần.

var health: HealthComponent
var died_count: int = 0
var damaged_count: int = 0
var changed_count: int = 0
var changed_log: Array[String] = []


func _ready() -> void:
	health = $HealthComponent
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	call_deferred(&"run_test")


func run_test() -> void:
	print("=== HEALTH COMPONENT TEST ===")
	print("max_health=", health.max_health, " current=", health.current)

	# take_damage 3 lần, mỗi lần 1 máu
	health.take_damage(1)
	print("after #1 -> current=", health.current, " is_alive=", health.is_alive())
	health.take_damage(1)
	print("after #2 -> current=", health.current, " is_alive=", health.is_alive())
	health.take_damage(1)
	print("after #3 -> current=", health.current, " is_alive=", health.is_alive())

	# gọi thêm sau khi đã chết -> phải bị bỏ qua
	health.take_damage(1)
	health.take_damage(5)
	print("after extra hits -> current=", health.current, " died_count=", died_count)

	# bất tử
	health.reset()
	health.invincible = true
	health.take_damage(1)
	print("invincible -> current=", health.current)

	# chữa
	health.invincible = false
	health.take_damage(2)
	health.heal(1)
	print("heal -> current=", health.current, " ratio=", "%.2f" % health.health_ratio())

	print("RESULT died_count=%d (expected 1) damaged_count=%d changed_count=%d" % [died_count, damaged_count, changed_count])
	print("health_changed log: ", changed_log)
	print("PASS" if died_count == 1 else "FAIL")
	print("=== TEST DONE ===")
	get_tree().quit()


func _on_died() -> void:
	died_count += 1


func _on_damaged(_amount: int, _from_pos: Vector2) -> void:
	damaged_count += 1


func _on_health_changed(cur: int, maximum: int) -> void:
	changed_count += 1
	changed_log.append("%d/%d" % [cur, maximum])