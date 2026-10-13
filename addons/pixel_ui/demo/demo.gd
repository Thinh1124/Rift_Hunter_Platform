extends Control
## The kit in use, four screens of plain Controls styled by one Theme: an adventure (a HUD, settings,
## an inventory, dialogue), the hero (equipment slots, stats, a shop with a speech bubble, quests, a
## map with markers, the emotes), the menus (pause, settings with switches and steppers, key
## bindings, save slots, a confirm box) and play (a bag and its item card, toasts, a radial quick
## menu, a hotbar, key prompts, dialogue). The buttons along the bottom swap the theme and the screen.

const KIT := "res://addons/pixel_ui/"
const ALL_THEMES: Array[String] = ["stone", "wood", "sky", "forest", "royal", "ember"]
const ART_HEIGHT := 240.0
const FIRST := "wood"
const SCREENS: Array[String] = ["adventure", "hero", "menus", "play"]
const EMOTES: Array[String] = ["exclaim", "question", "heart", "music", "anger", "sweat", "sleep", "dots",
	"idea", "star", "happy", "sad", "surprise", "coin", "broken", "swirl"]

## Store capture only: switch to the next theme every this many frames.
@export var cycle_frames := 0
## The screen to open on, and the theme to open in when not FIRST.
@export_enum("adventure", "hero", "menus", "play") var screen := "adventure"
@export var first_theme := ""

var frame := 0
var theme_buttons := {}
var pages := {}
var page: Control


## Draws the UI at a whole-number scale so the art pixels stay square: the largest that still
## fits `art_height` pixels of art on screen.
static func pixel_scale(node: Node, art_height: float) -> void:
	var window := node.get_tree().root
	window.content_scale_factor = 1.0
	window.content_scale_factor = maxf(1.0, floorf(window.get_visible_rect().size.y / art_height))


static func themes() -> Array[String]:
	var installed: Array[String] = []
	for n in ALL_THEMES:
		if ResourceLoader.exists(KIT + "themes/%s.tres" % n):
			installed.append(n)
	return installed


## The named theme, or the first one installed.
static func kit_theme(name: String) -> Theme:
	return load(KIT + "themes/%s.tres" % (name if name in themes() else themes()[0]))


## Null when the icon isn't installed.
static func icon_texture(name: String) -> Texture2D:
	var path := KIT + "icons/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null


static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return t


## Null when the emote, slot silhouette or map marker isn't installed.
static func world_texture(folder: String, name: String) -> Texture2D:
	return icon_texture("%s/%s" % [folder, name])


## An equipment slot: the item in it, or the slot's silhouette, faint, when empty.
static func equip_slot(parent: Control, part: String, item := "") -> PanelContainer:
	var s := slot(parent, item)
	if item == "" and world_texture("equip", part):
		var shape := icon("equip/" + part)
		shape.modulate = Color(1, 1, 1, 0.3)
		shape.tooltip_text = part.capitalize()
		s.add_child(shape)
	return s


## A speech bubble: dark Title text on the bubble's paper.
static func bubble(parent: Control, text: String) -> PanelContainer:
	var b := PanelContainer.new()
	b.theme_type_variation = &"SpeechBubble"
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(b)
	label(b, text, &"Title")
	return b


## A titled window; add its content to the returned VBox.
static func window(parent: Control, title: String, at: Vector2, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.position = at
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"Title"
	box.add_child(label)
	return box


static func row(parent: Control, separation := 3) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	parent.add_child(h)
	return h


static func bar(parent: Control, colour: String, value: float, width: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.theme_type_variation = StringName(colour + "Bar")
	b.show_percentage = false
	b.value = value
	b.custom_minimum_size = Vector2(width, 8)
	parent.add_child(b)
	return b


static func slider(parent: Control, label: String, value: float, width := 34.0) -> void:
	var r := row(parent)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = width
	r.add_child(l)
	var s := HSlider.new()
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(s)


static func label(parent: Control, text: String, variation := &"") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


## Whether the theme has the game pieces (MenuItem, ItemSlot, KeyCap ...): the free sampler's hasn't.
static func has_game_pieces(t: Theme) -> bool:
	return t.get_type_variation_base(&"KeyCap") == &"Label"


## A line of a menu: the band and pointer show on the one picked (pressed in its ButtonGroup).
static func menu_item(parent: Control, text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"MenuItem"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_group = group
	parent.add_child(b)
	return b


## A toggle switch, its text on the left and the switch at the right end.
static func switch(parent: Control, text: String, on: bool) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	parent.add_child(c)
	return c


## A label, then < value > stepping through the options.
static func stepper(parent: Control, text: String, options: Array, index: int, width := 34.0) -> Label:
	var r := row(parent, 2)
	label(r, text).custom_minimum_size.x = width
	var left := Button.new()
	left.theme_type_variation = &"StepLeft"
	r.add_child(left)
	var value := label(r, options[index])
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := Button.new()
	right.theme_type_variation = &"StepRight"
	r.add_child(right)
	var step := func(by: int) -> void:
		value.text = options[(options.find(value.text) + by + options.size()) % options.size()]
	left.pressed.connect(step.bind(-1))
	right.pressed.connect(step.bind(1))
	return value


## Keys on their caps, then what they do.
static func prompt(parent: Control, keys: Array, text: String) -> HBoxContainer:
	var r := row(parent, 2)
	for k in keys:
		label(r, k, &"KeyCap")
	if text != "":
		label(r, text).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## A 24x24 item slot (ItemSlot, or ItemSlotSelected when `picked`) with the item's icon and its count
## above 1 in the corner.
static func slot(parent: Control, item: String, count := 1, picked := false) -> PanelContainer:
	var s := PanelContainer.new()
	s.theme_type_variation = &"ItemSlotSelected" if picked else &"ItemSlot"
	s.custom_minimum_size = Vector2(24, 24)
	parent.add_child(s)
	if item == "" or icon_texture(item) == null:
		return s
	var art := icon(item)
	art.tooltip_text = item.capitalize()
	s.add_child(art)
	if count > 1:
		var n := label(art, str(count), &"Count")
		n.position = Vector2(19, 10) - Vector2(n.get_minimum_size().x, 0)
	return s


## A notice: an icon and a line in a ToastPanel.
static func toast(parent: Control, item: String, text: String) -> PanelContainer:
	var t := PanelContainer.new()
	t.theme_type_variation = &"ToastPanel"
	parent.add_child(t)
	var r := row(t, 4)
	r.add_child(icon(item))
	label(r, text).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## An icon at twice its size in a PortraitPanel.
static func portrait(parent: Control, item: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"PortraitPanel"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := icon(item)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(32, 32)
	p.add_child(face)
	parent.add_child(p)
	return p


func _ready() -> void:
	get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST  # project.godot's, for a project without it
	pixel_scale(self, ART_HEIGHT)
	var first := first_theme if first_theme != "" else FIRST
	theme = kit_theme(first)
	var shown: Array[String] = ["adventure", "hero"]
	if has_game_pieces(theme):
		shown = SCREENS.duplicate()
	for s in shown:
		pages[s] = Control.new()
		pages[s].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages[s].mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pages[s])
	page = pages["adventure"]
	_hud()
	_settings()
	_inventory()
	_dialog()
	page = pages["hero"]
	_hero()
	_shop()
	_quests()
	_map()
	_emotes()
	if "menus" in pages:
		page = pages["menus"]
		_menus()
		page = pages["play"]
		_play()
	var switcher := row(self, 2)
	switcher.position = Vector2(6, 220)
	var group := ButtonGroup.new()
	for name in themes():
		var b := Button.new()
		b.text = name.capitalize()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = name == theme.resource_path.get_file().get_basename()
		b.toggled.connect(func(on: bool) -> void: if on: theme = kit_theme(name))
		switcher.add_child(b)
		theme_buttons[name] = b
	if shown.size() > 1:
		var screens := row(self, 2)
		var screen_group := ButtonGroup.new()
		for s in shown:
			var b := Button.new()
			b.text = s.capitalize()
			b.toggle_mode = true
			b.button_group = screen_group
			b.button_pressed = s == screen
			b.toggled.connect(func(on: bool) -> void: if on: _show(s))
			screens.add_child(b)
		screens.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		screens.position.y = switcher.position.y
	_show(screen if screen in pages else "adventure")


func _show(which: String) -> void:
	for s in pages:
		pages[s].visible = s == which


func _process(_delta: float) -> void:
	if cycle_frames <= 0:
		return
	frame += 1
	if frame % cycle_frames == 0:
		var names := themes()
		var start := first_theme if first_theme != "" else FIRST
		var next: String = names[(maxi(0, names.find(start)) + frame / cycle_frames) % names.size()]
		theme_buttons[next].button_pressed = true


func _hud() -> void:
	var hearts := row(page, 0)
	hearts.position = Vector2(6, 5)
	for name in ["heart", "heart", "heart", "heart_half", "heart_empty"]:
		hearts.add_child(icon(name))
	var bars := VBoxContainer.new()
	bars.position = Vector2(92, 5)
	bars.add_theme_constant_override("separation", 2)
	page.add_child(bars)
	bar(bars, "Red", 70, 90)
	bar(bars, "Blue", 45, 90)
	var money := row(page, 1)
	money.position = Vector2(300, 5)
	for pair in [["coin", "1250"], ["gem", "12"], ["key", "3"]]:
		money.add_child(icon(pair[0]))
		var l := Label.new()
		l.text = pair[1]
		money.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size.x = 4
		money.add_child(gap)


func _settings() -> void:
	var box := window(page, "SETTINGS", Vector2(6, 28), 148)
	slider(box, "Music", 70)
	slider(box, "Sound", 40)
	var full := CheckBox.new()
	full.text = "Fullscreen"
	full.button_pressed = true
	box.add_child(full)
	var hints := CheckBox.new()
	hints.text = "Show hints"
	box.add_child(hints)
	var mode := OptionButton.new()
	for m in ["Easy", "Normal", "Hard"]:
		mode.add_item(m)
	mode.select(1)
	box.add_child(mode)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Hero name"
	box.add_child(name_edit)
	var buttons := row(box)
	for t in ["Back", "Apply"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)


func _inventory() -> void:
	var box := window(page, "INVENTORY", Vector2(162, 28), 258)
	var tabs := TabContainer.new()
	box.add_child(tabs)
	var items := GridContainer.new()
	items.name = "Items"
	items.columns = 9
	items.add_theme_constant_override("h_separation", 2)
	items.add_theme_constant_override("v_separation", 2)
	tabs.add_child(items)
	var stock := [["potion", 3], ["potion_blue", 2], ["potion_green", 1], ["apple", 5], ["bomb", 4],
		["key", 1], ["gem", 12], ["gem_red", 2], ["gem_green", 0], ["coin_silver", 30], ["star", 0],
		["leaf", 7], ["flame", 0], ["lightning", 0], ["chest", 0], ["bag", 0], ["sword", 0], ["shield", 0]]
	stock = stock.filter(func(pair: Array) -> bool: return icon_texture(pair[0]) != null).slice(0, 16)
	for i in 18:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"InsetPanel"
		slot.custom_minimum_size = Vector2(24, 24)
		items.add_child(slot)
		if i >= stock.size():
			continue
		var pair: Array = stock[i]
		var art := icon(pair[0])
		art.tooltip_text = String(pair[0]).capitalize()
		slot.add_child(art)
		if pair[1] > 1:
			var count := Label.new()
			count.text = str(pair[1])
			count.add_theme_color_override("font_shadow_color", Color.BLACK)
			art.add_child(count)
			count.position = Vector2(19, 10) - Vector2(count.get_minimum_size().x, 0)
	var gear := VBoxContainer.new()
	gear.name = "Gear"
	tabs.add_child(gear)
	for pair in [["sword", "Iron sword"], ["shield", "Oak shield"]]:
		var r := row(gear)
		r.add_child(icon(pair[0]))
		var l := Label.new()
		l.text = pair[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var b := Button.new()
		b.text = "Equip"
		r.add_child(b)
	var quest := row(box)
	quest.add_child(icon("trophy"))
	var l := Label.new()
	l.text = "Level 7"
	quest.add_child(l)
	var xp := bar(quest, "Gold", 60, 0)
	xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var actions := row(box)
	for pair in [["check", "Use"], ["trash", "Drop"], ["info", "Info"]]:
		var b := Button.new()
		b.text = pair[1]
		b.icon = icon_texture(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)


func _dialog() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(6, 176)
	panel.custom_minimum_size.x = 414
	page.add_child(panel)
	var r := row(panel, 6)
	var face := PanelContainer.new()
	face.theme_type_variation = &"InsetPanel"
	face.add_child(icon("user"))
	r.add_child(face)
	var text := Label.new()
	text.text = "Welcome, traveller! The shop opens at dawn.\nBring coins, and mind the bombs."
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(text)
	var next := Button.new()
	next.icon = icon_texture("arrow_right")
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(next)


func _hero() -> void:
	var box := window(page, "HERO", Vector2(6, 6), 0)
	var body := row(box, 4)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	body.add_child(left)
	for part in ["head", "neck", "body", "back"]:
		equip_slot(left, part, "gem_red" if part == "neck" else "")
	var middle := VBoxContainer.new()
	middle.add_theme_constant_override("separation", 2)
	body.add_child(middle)
	portrait(middle, "user").size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label(middle, "Ayla", &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var hands := row(middle, 2)
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_slot(hands, "weapon", "sword")
	equip_slot(hands, "shield", "shield")
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	body.add_child(right)
	for part in ["hands", "legs", "feet", "ring"]:
		equip_slot(right, part)
	var stats := GridContainer.new()
	stats.columns = 6 if has_game_pieces(theme) else 4  # the sampler's theme has no StepRight
	stats.add_theme_constant_override("h_separation", 3)
	stats.add_theme_constant_override("v_separation", 1)
	box.add_child(stats)
	var points := 3
	for pair in [["STR", 12], ["DEX", 9], ["INT", 7], ["VIT", 10]]:
		label(stats, pair[0])
		var value := label(stats, str(pair[1]))
		value.custom_minimum_size.x = 12
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if stats.columns == 6:
			var up := Button.new()
			up.theme_type_variation = &"StepRight"
			up.tooltip_text = "Spend a point"
			stats.add_child(up)
	var left_over := row(box, 2)
	left_over.add_child(icon("star"))
	label(left_over, "%d points" % points).size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _shop() -> void:
	var box := window(page, "SHOP", Vector2(134, 6), 152)
	var merchant := row(box, 3)
	var face := portrait(merchant, "user")
	var mood := icon("emotes/heart")
	mood.position = Vector2(22, -8)
	face.get_child(0).add_child(mood)
	bubble(merchant, "Fresh potions,\ncheap as dirt!")
	var tabs := TabContainer.new()
	box.add_child(tabs)
	for page_ in [["Buy", [["potion", "Red potion", 15], ["potion_blue", "Blue potion", 20], ["bomb", "Bomb", 30],
			["key", "Old key", 50]]], ["Sell", [["gem", "Blue gem", 40], ["apple", "Apple", 2]]]]:
		var list := VBoxContainer.new()
		list.name = page_[0]
		list.add_theme_constant_override("separation", 1)
		tabs.add_child(list)
		var group := ButtonGroup.new()
		for ware in page_[1]:
			var r := row(list, 2)
			r.add_child(icon(ware[0]))
			(r.get_child(0) as Control).custom_minimum_size = Vector2(16, 16)
			if has_game_pieces(theme):
				var b := menu_item(r, ware[1], group)
				b.icon = null
				b.button_pressed = ware[1] == "Blue potion"
			else:  # the sampler's theme has no MenuItem
				label(r, ware[1])
			(r.get_child(-1) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(icon("coin"))
			var price := label(r, str(ware[2]))
			price.custom_minimum_size.x = 12
			price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pay := row(box, 2)
	pay.add_child(icon("coin"))
	label(pay, "1250").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var buy := Button.new()
	buy.text = "Buy"
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pay.add_child(buy)


func _quests() -> void:
	var box := window(page, "QUESTS", Vector2(292, 6), 129)
	label(box, "The east tunnel", &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for pair in [["Find the old mine", true], ["Bring 3 bombs  1/3", false]]:
		var c := CheckBox.new()
		c.text = pair[0]
		c.button_pressed = pair[1]
		box.add_child(c)
	var reward := row(box, 2)
	label(reward, "Reward").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.add_child(icon("coin"))
	label(reward, "50").size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A map in a MapFrame: a meadow with a river, a road and a wood, and the markers on it.
func _map() -> void:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"MapFrame"
	frame.position = Vector2(292, 96)
	page.add_child(frame)
	var area := Vector2i(121, 74)
	var land := Image.create(area.x, area.y, false, Image.FORMAT_RGBA8)
	land.fill(Color8(92, 156, 76))
	for i in 60:  # tufts
		land.set_pixel((i * 37) % area.x, (i * 23 + i % 3) % area.y, Color8(72, 132, 64))
	for y in area.y:  # the river, the road across it
		var x := 78 + int(round(6.0 * sin(y / 9.0)))
		land.fill_rect(Rect2i(x, y, 7, 1), Color8(64, 128, 212))
		land.set_pixel(x, y, Color8(150, 200, 240))
	land.fill_rect(Rect2i(0, 40, area.x, 4), Color8(204, 170, 110))
	land.fill_rect(Rect2i(70, 39, 22, 6), Color8(140, 96, 60))
	for i in 14:  # the wood
		var at := Vector2i(8 + (i % 5) * 9 + floori(i / 5.0) * 3, 6 + floori(i / 5.0) * 9)
		land.fill_rect(Rect2i(at, Vector2i(6, 6)), Color8(36, 96, 52))
		land.fill_rect(Rect2i(at + Vector2i(1, 1), Vector2i(3, 2)), Color8(60, 130, 70))
	var map := TextureRect.new()
	map.texture = ImageTexture.create_from_image(land)
	frame.add_child(map)
	for pair in [["player", Vector2(40, 42)], ["quest", Vector2(104, 18)], ["shop", Vector2(18, 48)],
			["home", Vector2(8, 34)], ["chest", Vector2(58, 8)], ["enemy", Vector2(104, 58)],
			["flag", Vector2(62, 56)], ["npc", Vector2(30, 56)], ["door", Vector2(112, 30)]]:
		if world_texture("markers", pair[0]):
			var m := icon("markers/" + pair[0])
			m.tooltip_text = String(pair[0]).capitalize()
			m.position = pair[1] - Vector2(5, 5)
			map.add_child(m)
	var north := label(map, "N", &"Title")
	north.add_theme_color_override("font_color", Color.WHITE)
	north.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	north.position = Vector2(area.x - 9, 1)


## Every emote installed, each in its slot with the one picked.
func _emotes() -> void:
	var strip := PanelContainer.new()
	strip.position = Vector2(6, 188)
	page.add_child(strip)
	var r := row(strip, 2)
	label(r, "Emotes").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for e in EMOTES:
		if world_texture("emotes", e):
			var t := icon("emotes/" + e)
			t.tooltip_text = e.capitalize()
			r.add_child(t)
	if not has_game_pieces(theme):
		return
	var keys := VBoxContainer.new()
	keys.add_theme_constant_override("separation", 2)
	keys.position = Vector2(352, 186)
	page.add_child(keys)
	prompt(keys, ["M"], "Map")
	prompt(keys, ["J"], "Quests")


func _menus() -> void:
	var pause := window(page, "PAUSED", Vector2(6, 6), 84)
	var group := ButtonGroup.new()
	for t in ["Resume", "Save", "Load", "Settings", "Controls", "Quit"]:
		menu_item(pause, t, group).button_pressed = t == "Settings"
	var quit := window(page, "QUIT?", Vector2(6, 118), 84)
	label(quit, "Progress since\nthe last save\nwill be lost.")
	var answer := row(quit)
	for t in ["Yes", "No"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		answer.add_child(b)

	var box := window(page, "SETTINGS", Vector2(96, 6), 160)
	slider(box, "Music", 70, 44)
	slider(box, "Sound", 40, 44)
	switch(box, "Vsync", true)
	switch(box, "Subtitles", false)
	stepper(box, "Difficulty", ["Easy", "Normal", "Hard"], 1, 44)
	stepper(box, "Window", ["Windowed", "Fullscreen", "Borderless"], 1, 44)
	box.add_child(HSeparator.new())
	var buttons := row(box)
	for t in ["Back", "Apply"]:
		var b := Button.new()
		b.text = t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)

	var keys := window(page, "CONTROLS", Vector2(262, 6), 159)
	for pair in [["Move", ["W", "A", "S", "D"]], ["Jump", ["Space"]], ["Use", ["E"]], ["Pause", ["Esc"]]]:
		var r := row(keys, 2)
		label(r, pair[0]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prompt(r, pair[1], "")

	var rebind := window(page, "PRESS A KEY", Vector2(96, 150), 160)
	label(rebind, "Press a key for Jump").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cancel := prompt(rebind, ["Esc"], "Cancel")
	cancel.alignment = BoxContainer.ALIGNMENT_CENTER

	var saves := window(page, "LOAD GAME", Vector2(262, 100), 159)
	var picked := ButtonGroup.new()
	for s in [["home", "Green Hills", "Lv 7   2h 14m"], ["skull", "Old Crypt", "Lv 4   1h 02m"], ["plus", "New game", ""]]:
		var b := Button.new()
		b.theme_type_variation = &"SaveSlot"
		b.text = s[1] + "\n" + s[2]
		b.icon = icon_texture(s[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_group = picked
		b.button_pressed = s[1] == "Green Hills"
		saves.add_child(b)


func _play() -> void:
	var bag := window(page, "BAG", Vector2(6, 6), 0)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	bag.add_child(grid)
	var stock := [["sword", 1], ["potion_blue", 3], ["shield", 1], ["apple", 5], ["bomb", 4], ["key", 2],
		["gem", 12], ["potion", 2], ["coin_silver", 30], ["leaf", 7]]
	for i in 18:
		slot(grid, stock[i][0] if i < stock.size() else "", stock[i][1] if i < stock.size() else 0, i == 1)

	var card := PanelContainer.new()
	card.theme_type_variation = &"TooltipPanel"
	card.position = Vector2(176, 6)
	card.custom_minimum_size.x = 110
	page.add_child(card)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	card.add_child(lines)
	var top := row(lines, 3)
	top.add_child(icon("potion_blue"))
	label(top, "Blue potion", &"Nameplate").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var about := label(lines, "Restores 40 mana over five seconds.")
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size.x = 100
	var worth := row(lines, 2)
	worth.add_child(icon("coin"))
	label(worth, "15").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var use := row(lines, 6)
	prompt(use, ["E"], "Use")
	prompt(use, ["Q"], "Drop")

	var toasts := VBoxContainer.new()
	toasts.add_theme_constant_override("separation", 2)
	page.add_child(toasts)
	for pair in [["star", "Quest updated"], ["coin", "+50 coins"], ["save", "Game saved"]]:
		toast(toasts, pair[0], pair[1])
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)

	_radial(Vector2(362, 146), 44)

	var talk := PanelContainer.new()
	talk.position = Vector2(6, 112)
	talk.custom_minimum_size.x = 290
	page.add_child(talk)
	var r := row(talk, 6)
	portrait(r, "user")
	var said := VBoxContainer.new()
	said.add_theme_constant_override("separation", 2)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(said)
	label(said, "Old Miner", &"Nameplate").size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label(said, "The east tunnel caved in. Bring me\nthree bombs and I will clear it.")
	prompt(said, ["E"], "Next").size_flags_horizontal = Control.SIZE_SHRINK_END

	var hotbar := PanelContainer.new()
	hotbar.position = Vector2(6, 176)
	page.add_child(hotbar)
	var keys := row(hotbar, 2)
	var items := ["sword", "shield", "bomb", "potion", "potion_blue", "apple", "key", "gem"]
	for i in items.size():
		var s := slot(keys, items[i], 1, i == 2)
		label(s.get_child(0), str(i + 1), &"Count").position = Vector2(-2, -3)

	var hints := VBoxContainer.new()
	hints.add_theme_constant_override("separation", 2)
	hints.position = Vector2(232, 180)
	page.add_child(hints)
	prompt(hints, ["Tab"], "Bag")
	prompt(hints, ["Esc"], "Menu")


## A quick-pick wheel: slots round a centre naming the one picked.
func _radial(centre: Vector2, radius: float) -> void:
	var items := ["sword", "shield", "bomb", "potion", "potion_blue", "apple", "key", "gem"]
	for i in items.size():
		var a := -PI / 2 + TAU * i / items.size()
		var s := slot(page, items[i], 1, i == 3)
		s.position = (centre + Vector2(cos(a), sin(a)) * radius - Vector2(12, 12)).round()
	var name := label(page, "Red potion")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.custom_minimum_size.x = 60
	name.position = centre - Vector2(30, 12)
	prompt(page, ["Q"], "").position = centre - Vector2(5, -1)
