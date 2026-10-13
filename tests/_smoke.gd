extends Node

var sm: StateMachine
var hb: HitboxComponent
var hub: HurtboxComponent
var hc: HealthComponent
var log_lines: Array[String] = []
var hits: int = 0

func _ready() -> void:
	print("=== COMPONENTS SMOKE TEST ===")
	hb = $Rig/Hitbox
	hub = $Rig/Hurtbox
	hc = $Rig/Hurtbox/HealthComponent
	hub.hit_received.connect(func(h): hits += 1; log_lines.append("hit dmg=" + str(h.damage)))
	sm = $Rig/StateMachine
	sm.state_changed.connect(func(n): print("  state_changed -> ", n))
	print("StateMachine.states=", sm.states.keys(), " current=", sm.current_state.name)
	sm.change_state(&"run")
	print("after change_state(run): current=", sm.current_state.name, " is_current(run)=", sm.is_current(&"run"))
	sm.change_state(&"idle")

	print("Hitbox active=", hb.is_active(), " damage=", hb.damage, " knockback=", hb.knockback)
	hb.set_active(false)
	await get_tree().process_frame
	print("after set_active(false): shape.disabled=", ($Rig/Hitbox/Shape as CollisionShape2D).disabled)
	hb.set_active(true)
	await get_tree().process_frame
	print("after set_active(true): shape.disabled=", ($Rig/Hitbox/Shape as CollisionShape2D).disabled)

	print("Hurtbox one_shot_per_hit_time=", hub.one_shot_per_hit_time, " health=", hub.health)
	hub.one_shot_per_hit_time = 5.0
	hub._on_area_entered(hb)
	print("simulated hit #1 -> hits=", hits, " current=", hc.current)
	hub._on_area_entered(hb)
	print("simulated hit #2 (blocked) -> hits=", hits, " current=", hc.current)
	hub.reset_hit_cooldown()
	hub._on_area_entered(hb)
	print("after cooldown reset -> hits=", hits, " current=", hc.current)
	hub.one_shot_per_hit_time = 0.0
	hc.invincible = true
	hub._on_area_entered(hb)
	print("invincible -> hits=", hits, " current=", hc.current)
	print("=== SMOKE DONE ===")
	get_tree().quit()
