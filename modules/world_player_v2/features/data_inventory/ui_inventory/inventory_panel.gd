extends PanelContainer
class_name InventoryPanelV2
## InventoryPanel - Инвентарь ENDZONE ROLEPLAY
## Слева направо: [6 слотов аксессуаров] -> [Живой 3D-персонаж + Ник/Уровень снизу] -> [Сетка рюкзака]

signal item_dropped_outside(item_data: Dictionary, count: int, world_position: Vector3)
signal equipment_changed(slot_id: String, item_data: Dictionary)

@onready var inventory_grid: GridContainer = $VBox/InventoryGrid

const InventorySlotScene = preload("res://modules/world_player_v2/features/data_inventory/ui_inventory/inventory_slot.tscn")
const ItemDefs = preload("res://modules/world_player_v2/features/data_inventory/item_definitions.gd")

var inventory_slots: Array = []
var inventory_ref: Node = null
var open_tween: Tween = null

var char_name_label: Label
var char_level_label: Label

# 3D-превью персонажа в SubViewport
var preview_viewport: SubViewport
var preview_pivot: Node3D
var preview_camera: Camera3D
var is_rotating_preview: bool = false

# 6 слотов аксессуаров слева от персонажа
var equip_slots: Dictionary = {}
var context_menu: PopupMenu = null
var context_target: Dictionary = {}

const ACCESSORY_SLOTS: Array[Dictionary] = [
	{"id": "hat", "hint": "Голова"},
	{"id": "mask", "hint": "Маска"},
	{"id": "glasses", "hint": "Очки"},
	{"id": "backpack", "hint": "Рюкзак"},
	{"id": "armor", "hint": "Броня"},
	{"id": "watch", "hint": "Аксесс."}
]

func _ready() -> void:
	_build_context_menu()
	_build_endzone_character_inventory()
	
	for i in range(27):
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = i
		slot.item_dropped_outside.connect(_on_slot_item_dropped_outside.bind(slot))
		slot.gui_input.connect(_on_inventory_slot_gui_input.bind(i))
		inventory_grid.add_child(slot)
		_style_ez_inventory_slot(slot)
		inventory_slots.append(slot)
	
	visible = false
	
	if has_node("/root/PlayerSignals"):
		PlayerSignals.inventory_toggled.connect(_on_inventory_toggled)
		PlayerSignals.inventory_changed.connect(refresh_display)

func _build_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.name = "ItemContextMenu"
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	sb.border_color = Color(0.28, 0.82, 1.0, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	context_menu.add_theme_stylebox_override("panel", sb)
	context_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(context_menu)

func _make_card_box(border_col: Color = Color(1, 1, 1, 0.12), bg_alpha: float = 0.86) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, bg_alpha)
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

func _build_endzone_character_inventory() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var vbox = get_node_or_null("VBox")
	if not vbox:
		return
	
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	vbox.add_child(header_row)
	vbox.move_child(header_row, 0)
	
	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 2)
	header_row.add_child(title_box)
	
	var main_lbl = Label.new()
	main_lbl.text = "Инвентарь"
	main_lbl.add_theme_font_size_override("font_size", 22)
	main_lbl.add_theme_color_override("font_color", Color.WHITE)
	main_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	main_lbl.add_theme_constant_override("outline_size", 3)
	title_box.add_child(main_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Перетащите предмет в слот аксессуара или нажмите ПКМ, чтобы надеть / снять"
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	title_box.add_child(sub_lbl)
	
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.88, 0.30, 0.28)
	close_sb.set_corner_radius_all(16)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_stylebox_override("hover", close_sb)
	close_btn.pressed.connect(func():
		if has_node("/root/PlayerSignals"):
			PlayerSignals.inventory_toggled.emit(false)
		else:
			visible = false
	)
	header_row.add_child(close_btn)
	
	for child in vbox.get_children():
		if child is Label and child.text.strip_edges().to_upper() == "INVENTORY":
			child.visible = false
	var split = HBoxContainer.new()
	split.add_theme_constant_override("separation", 14)
	vbox.add_child(split)
	
	# --- КОЛОНКА 1 (САМАЯ ЛЕВАЯ): 6 ПУСТЫХ СЛОТОВ ДЛЯ АКСЕССУАРОВ ---
	var acc_card = PanelContainer.new()
	acc_card.add_theme_stylebox_override("panel", _make_card_box(Color(1, 1, 1, 0.12), 0.86))
	split.add_child(acc_card)
	
	var acc_col = VBoxContainer.new()
	acc_col.alignment = BoxContainer.ALIGNMENT_CENTER
	acc_col.add_theme_constant_override("separation", 8)
	acc_card.add_child(acc_col)
	
	for s in ACCESSORY_SLOTS:
		acc_col.add_child(_create_empty_equip_slot(s["id"], s["hint"]))
	
	# --- КОЛОНКА 2: ЖИВОЙ 3D-ПЕРСОНАЖ (В ОДЕЖДЕ ИЛИ В ТРУСАХ) + НИК И УРОВЕНЬ СНИЗУ ---
	var char_card = PanelContainer.new()
	char_card.custom_minimum_size = Vector2(240, 0)
	char_card.add_theme_stylebox_override("panel", _make_card_box(Color(0.28, 0.82, 1.0, 0.25), 0.88))
	split.add_child(char_card)
	
	var char_vbox = VBoxContainer.new()
	char_vbox.add_theme_constant_override("separation", 10)
	char_card.add_child(char_vbox)
	
	var vp_container = SubViewportContainer.new()
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.custom_minimum_size = Vector2(215, 340)
	vp_container.stretch = true
	vp_container.tooltip_text = "Зажмите ЛКМ и потяните, чтобы повернуть персонажа"
	vp_container.gui_input.connect(_on_preview_gui_input)
	char_vbox.add_child(vp_container)
	
	preview_viewport = SubViewport.new()
	preview_viewport.transparent_bg = true
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp_container.add_child(preview_viewport)
	
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 0.96)
	env.ambient_light_energy = 1.1
	world_env.environment = env
	preview_viewport.add_child(world_env)
	
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-35, 30, 0)
	dir_light.light_energy = 1.2
	preview_viewport.add_child(dir_light)
	
	preview_camera = Camera3D.new()
	preview_camera.position = Vector3(0, 0.98, 1.55)
	preview_camera.look_at_from_position(Vector3(0, 0.98, 1.55), Vector3(0, 0.95, 0), Vector3.UP)
	preview_viewport.add_child(preview_camera)
	
	preview_pivot = Node3D.new()
	preview_pivot.name = "CharacterPivot"
	preview_viewport.add_child(preview_pivot)
	
	var info_box = PanelContainer.new()
	info_box.add_theme_stylebox_override("panel", _make_card_box(Color(1, 1, 1, 0.10), 0.75))
	char_vbox.add_child(info_box)
	
	var info_row = HBoxContainer.new()
	info_box.add_child(info_row)
	
	char_name_label = Label.new()
	char_name_label.text = "Artem_Kurbanov"
	char_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_name_label.add_theme_font_size_override("font_size", 14)
	char_name_label.add_theme_color_override("font_color", Color.WHITE)
	info_row.add_child(char_name_label)
	
	char_level_label = Label.new()
	char_level_label.text = "1 lvl"
	char_level_label.add_theme_font_size_override("font_size", 14)
	char_level_label.add_theme_color_override("font_color", Color(0.98, 0.80, 0.18))
	info_row.add_child(char_level_label)
	
	# --- КОЛОНКА 3 (СПРАВА): СЕТКА ПРЕДМЕТОВ ИНВЕНТАРЯ ---
	var grid_card = PanelContainer.new()
	grid_card.add_theme_stylebox_override("panel", _make_card_box(Color(1, 1, 1, 0.12), 0.86))
	split.add_child(grid_card)
	
	if inventory_grid:
		inventory_grid.get_parent().remove_child(inventory_grid)
		inventory_grid.columns = 6
		inventory_grid.add_theme_constant_override("h_separation", 8)
		inventory_grid.add_theme_constant_override("v_separation", 8)
		grid_card.add_child(inventory_grid)

func _sync_character_3d_preview() -> void:
	if not preview_pivot:
		return
	for c in preview_pivot.get_children():
		c.queue_free()
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var visual_root: Node3D = null
	for candidate_name in ["CharacterModel", "Model", "Visuals", "Mesh", "Armature", "Body"]:
		var found = player.find_child(candidate_name, true, false)
		if found and found is Node3D:
			visual_root = found
			break
	
	if visual_root:
		var clone = visual_root.duplicate()
		clone.position = Vector3.ZERO
		clone.rotation = Vector3.ZERO
		for mesh in clone.find_children("*", "MeshInstance3D", true, false):
			mesh.visible = true
			mesh.layers = 1
		preview_pivot.add_child(clone)
		for tree in clone.find_children("*", "AnimationTree", true, false):
			tree.active = false
		for skel in clone.find_children("*", "Skeleton3D", true, false):
			skel.reset_bone_poses()
			for bone_idx in range(skel.get_bone_count()):
				var bname = skel.get_bone_name(bone_idx).to_lower()
				if ("upperarm" in bname or "upper_arm" in bname or "arm_l" in bname or "arm_r" in bname or "l_arm" in bname or "r_arm" in bname or "leftarm" in bname or "rightarm" in bname) and not ("fore" in bname or "lower" in bname or "twist" in bname):
					var is_left = ("left" in bname or ".l" in bname or "_l" in bname or bname.begins_with("l_"))
					var children = skel.get_bone_children(bone_idx)
					if children.size() > 0:
						var child_dir = skel.get_bone_rest(children[0]).origin.normalized()
						var down_local = skel.get_bone_global_pose(bone_idx).basis.inverse() * Vector3.DOWN
						var rot_q = Quaternion(child_dir, down_local.lerp(child_dir, 0.15).normalized())
						skel.set_bone_pose_rotation(bone_idx, skel.get_bone_pose_rotation(bone_idx) * rot_q)
					else:
						var sign_dir = 1.0 if is_left else -1.0
						var q = Quaternion.from_euler(Vector3(0.0, 0.0, deg_to_rad(75.0 * sign_dir)))
						skel.set_bone_pose_rotation(bone_idx, skel.get_bone_pose_rotation(bone_idx) * q)

		for anim in clone.find_children("*", "AnimationPlayer", true, false):
			var played = false
			for anim_name in anim.get_animation_list():
				if "idle" in anim_name.to_lower() or "stand" in anim_name.to_lower():
					anim.play(anim_name)
					played = true
					break
			if not played:
				anim.stop()
	else:
		_build_fallback_underwear_mannequin()

func _build_fallback_underwear_mannequin() -> void:
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.86, 0.68, 0.56)
	var underwear_mat = StandardMaterial3D.new()
	underwear_mat.albedo_color = Color(0.14, 0.16, 0.20)
	
	var parts = [
		{"size": Vector3(0.32, 0.32, 0.32), "pos": Vector3(0, 1.56, 0), "mat": skin_mat},
		{"size": Vector3(0.46, 0.52, 0.24), "pos": Vector3(0, 1.12, 0), "mat": skin_mat},
		{"size": Vector3(0.47, 0.22, 0.25), "pos": Vector3(0, 0.76, 0), "mat": underwear_mat},
		{"size": Vector3(0.18, 0.62, 0.18), "pos": Vector3(-0.14, 0.35, 0), "mat": skin_mat},
		{"size": Vector3(0.18, 0.62, 0.18), "pos": Vector3(0.14, 0.35, 0), "mat": skin_mat},
		{"size": Vector3(0.14, 0.56, 0.14), "pos": Vector3(-0.32, 1.08, 0), "mat": skin_mat},
		{"size": Vector3(0.14, 0.56, 0.14), "pos": Vector3(0.32, 1.08, 0), "mat": skin_mat}
	]
	for p in parts:
		var mi = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = p["size"]
		mi.mesh = box
		mi.material_override = p["mat"]
		mi.position = p["pos"]
		preview_pivot.add_child(mi)

func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_rotating_preview = event.pressed
	elif event is InputEventMouseMotion and is_rotating_preview and preview_pivot:
		preview_pivot.rotate_y(event.relative.x * 0.015)
func _create_empty_equip_slot(slot_id: String, hint_text: String) -> Control:
	var slot_box = EndzoneEquipDropSlot.new()
	slot_box.slot_id = slot_id
	slot_box.custom_minimum_size = Vector2(58, 58)
	slot_box.tooltip_text = hint_text + " (перетащите предмет или ПКМ)"
	slot_box.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(false))
	slot_box.mouse_entered.connect(func(): slot_box.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(true)))
	slot_box.mouse_exited.connect(func(): slot_box.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(false)))
	slot_box.item_dropped_to_equip.connect(_on_item_dropped_to_equip)
	slot_box.gui_input.connect(_on_equip_slot_gui_input.bind(slot_id))
	
	var hint_lbl = Label.new()
	hint_lbl.text = hint_text
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 9)
	hint_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.24))
	slot_box.add_child(hint_lbl)
	
	var icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.visible = false
	slot_box.add_child(icon_rect)
	
	var item_name_lbl = Label.new()
	item_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	item_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_name_lbl.add_theme_font_size_override("font_size", 9)
	item_name_lbl.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	item_name_lbl.visible = false
	slot_box.add_child(item_name_lbl)
	
	equip_slots[slot_id] = {
		"item": {},
		"ui": slot_box,
		"hint": hint_lbl,
		"icon": icon_rect,
		"name_lbl": item_name_lbl
	}
	return slot_box

func _on_inventory_slot_gui_input(event: InputEvent, inv_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_find_references()
		if not inventory_ref or not inventory_ref.has_method("get_slot"):
			return
		var slot_data = inventory_ref.get_slot(inv_index)
		var item = slot_data.get("item", {})
		if item.is_empty() or item.get("id", "empty") == "empty":
			return
		context_target = {"type": "inv", "index": inv_index, "item": item}
		context_menu.clear()
		context_menu.add_item("Надеть", 1)
		context_menu.add_item("Выбросить", 2)
		context_menu.position = get_viewport().get_mouse_position()
		context_menu.popup()

func _on_equip_slot_gui_input(event: InputEvent, slot_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var eq = equip_slots.get(slot_id, {})
		var item = eq.get("item", {})
		if item.is_empty():
			return
		context_target = {"type": "equip", "slot_id": slot_id, "item": item}
		context_menu.clear()
		context_menu.add_item("Снять", 3)
		context_menu.position = get_viewport().get_mouse_position()
		context_menu.popup()

func _on_context_menu_selected(id: int) -> void:
	if id == 1 and context_target.get("type") == "inv":
		var inv_idx = context_target["index"]
		var item = context_target["item"]
		var target_slot = item.get("equip_slot", _guess_equip_slot(item))
		_equip_from_inventory(inv_idx, target_slot)
	elif id == 2 and context_target.get("type") == "inv":
		var inv_idx = context_target["index"]
		var slot_data = inventory_ref.get_slot(inv_idx)
		_on_slot_item_dropped_outside(slot_data.get("item", {}), slot_data.get("count", 1), inventory_slots[inv_idx])
	elif id == 3 and context_target.get("type") == "equip":
		_unequip_to_inventory(context_target["slot_id"])

func _guess_equip_slot(item: Dictionary) -> String:
	var n = item.get("name", "").to_lower()
	if "шлем" in n or "шапк" in n or "кепк" in n: return "hat"
	if "маск" in n: return "mask"
	if "очк" in n: return "glasses"
	if "рюкзак" in n or "сумк" in n: return "backpack"
	if "брон" in n: return "armor"
	return "watch"

func _on_item_dropped_to_equip(source_index: int, target_slot_id: String) -> void:
	if source_index >= 0 and source_index < 27:
		_equip_from_inventory(source_index, target_slot_id)

func _equip_from_inventory(inv_index: int, target_slot_id: String) -> void:
	_find_references()
	if not inventory_ref or not equip_slots.has(target_slot_id):
		return
	var slot_data = inventory_ref.get_slot(inv_index)
	var item = slot_data.get("item", {})
	if item.is_empty() or item.get("id", "empty") == "empty":
		return
	
	var old_equipped = equip_slots[target_slot_id]["item"]
	if not old_equipped.is_empty():
		inventory_ref.set_slot(inv_index, old_equipped, 1)
	else:
		if slot_data.get("count", 1) > 1:
			inventory_ref.set_slot(inv_index, item, slot_data["count"] - 1)
		else:
			inventory_ref.clear_slot(inv_index)
	
	_set_equip_slot_visual(target_slot_id, item)
	equipment_changed.emit(target_slot_id, item)
	_sync_character_3d_preview()
	refresh_display()
func _unequip_to_inventory(slot_id: String) -> void:
	_find_references()
	if not inventory_ref or not equip_slots.has(slot_id):
		return
	var item = equip_slots[slot_id]["item"]
	if item.is_empty():
		return
	
	var all_slots = inventory_ref.get_all_slots()
	for i in range(all_slots.size()):
		var s_item = all_slots[i].get("item", {})
		if s_item.is_empty() or s_item.get("id", "empty") == "empty":
			inventory_ref.set_slot(i, item, 1)
			_set_equip_slot_visual(slot_id, {})
			equipment_changed.emit(slot_id, {})
			_sync_character_3d_preview()
			refresh_display()
			return

func _set_equip_slot_visual(slot_id: String, item: Dictionary) -> void:
	var eq = equip_slots[slot_id]
	eq["item"] = item
	var has_item = not item.is_empty()
	eq["hint"].visible = not has_item
	eq["name_lbl"].visible = has_item
	if has_item:
		eq["name_lbl"].text = item.get("name", "")
		if item.has("icon") and item["icon"] != "" and ResourceLoader.exists(item["icon"]):
			eq["icon"].texture = load(item["icon"])
			eq["icon"].visible = true
		else:
			eq["icon"].visible = false
	else:
		eq["icon"].visible = false

class EndzoneEquipDropSlot extends PanelContainer:
	signal item_dropped_to_equip(source_index: int, target_slot_id: String)
	var slot_id: String = ""
	
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("source_index")
	
	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if data is Dictionary and data.has("source_index"):
			item_dropped_to_equip.emit(data["source_index"], slot_id)

func _make_ez_inv_slot_box(hovered: bool = false) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.15, 0.92) if hovered else Color(0.09, 0.10, 0.13, 0.82)
	sb.border_color = Color(0.28, 0.82, 1.0, 0.95) if hovered else Color(1.0, 1.0, 1.0, 0.12)
	sb.set_border_width_all(2 if hovered else 1)
	sb.set_corner_radius_all(8)
	return sb

func _style_ez_inventory_slot(slot: Control) -> void:
	slot.custom_minimum_size = Vector2(62, 62)
	if slot is PanelContainer or slot is Panel:
		slot.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(false))
		slot.mouse_entered.connect(func(): slot.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(true)))
		slot.mouse_exited.connect(func(): slot.add_theme_stylebox_override("panel", _make_ez_inv_slot_box(false)))
	for child in slot.find_children("*", "Label", true, false):
		child.add_theme_font_size_override("font_size", 10)
		child.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		child.add_theme_constant_override("outline_size", 2)

func _on_inventory_toggled(is_open: bool) -> void:
	if open_tween and open_tween.is_valid():
		open_tween.kill()
	
	if is_open:
		_find_references()
		refresh_display()
		_sync_character_3d_preview()
		visible = true
		modulate.a = 0.0
		pivot_offset = size * 0.5
		scale = Vector2(0.96, 0.96)
		open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		open_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		open_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	else:
		if context_menu:
			context_menu.hide()
		visible = false

func _find_references() -> void:
	if inventory_ref:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		inventory_ref = player.get_node_or_null("Systems/Inventory")

func refresh_display() -> void:
	_find_references()
	if inventory_ref and inventory_ref.has_method("get_all_slots"):
		var data = inventory_ref.get_all_slots()
		for i in range(min(inventory_slots.size(), data.size())):
			inventory_slots[i].set_slot_data(data[i], i)

func handle_slot_drop(source_index: int, target_index: int) -> void:
	if source_index == target_index:
		return
	var source_is_hotbar = source_index >= 100
	var target_is_hotbar = target_index >= 100
	if source_is_hotbar or target_is_hotbar:
		var hud = get_parent()
		if hud and hud.has_method("handle_slot_drop"):
			hud.handle_slot_drop(source_index, target_index)
			refresh_display()
		return
	_find_references()
	if not inventory_ref:
		return
	var source_data = inventory_ref.get_slot(source_index) if inventory_ref.has_method("get_slot") else {}
	var target_data = inventory_ref.get_slot(target_index) if inventory_ref.has_method("get_slot") else {}
	var source_item = source_data.get("item", {})
	var source_count = source_data.get("count", 0)
	var target_item = target_data.get("item", {})
	var target_count = target_data.get("count", 0)
	if inventory_ref.has_method("set_slot"):
		if source_item.get("id") == target_item.get("id") and source_item.get("id") != "empty":
			var stack_size = source_item.get("stack_size", 64)
			var space = stack_size - target_count
			var to_move = min(source_count, space)
			inventory_ref.set_slot(target_index, target_item, target_count + to_move)
			if source_count - to_move > 0:
				inventory_ref.set_slot(source_index, source_item, source_count - to_move)
			else:
				inventory_ref.clear_slot(source_index)
		else:
			inventory_ref.set_slot(target_index, source_item, source_count)
			inventory_ref.set_slot(source_index, target_item, target_count)
	refresh_display()

func _on_slot_item_dropped_outside(item: Dictionary, count: int, slot) -> void:
	var slot_idx = slot.slot_index
	if inventory_ref and inventory_ref.has_method("clear_slot"):
		inventory_ref.clear_slot(slot_idx)
	var player = get_tree().get_first_node_in_group("player")
	var drop_pos = Vector3.ZERO
	var drop_velocity = Vector3.ZERO
	if player:
		drop_pos = player.global_position - player.global_transform.basis.z * 2.0 + Vector3.UP
		drop_velocity = -player.global_transform.basis.z * 3.0 + Vector3.UP * 2.0
	_spawn_pickup(item, count, drop_pos, drop_velocity)
	item_dropped_outside.emit(item, count, drop_pos)
	refresh_display()

func _spawn_pickup(item: Dictionary, count: int, pos: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	var scene_path = item.get("scene", "")
	var spawned_directly = false
	if scene_path != "":
		var item_scene = load(scene_path)
		if item_scene:
			var temp_instance = item_scene.instantiate()
			if temp_instance is RigidBody3D:
				get_tree().root.add_child(temp_instance)
				temp_instance.global_position = pos
				if not temp_instance.is_in_group("interactable"):
					temp_instance.add_to_group("interactable")
				temp_instance.set_meta("item_data", item.duplicate())
				temp_instance.linear_velocity = velocity
				spawned_directly = true
			else:
				temp_instance.queue_free()
	if not spawned_directly:
		var pickup_scene = load("res://modules/world_player_v2/features/data_pickups/pickup_item.tscn")
		if not pickup_scene:
			return
		var pickup = pickup_scene.instantiate()
		get_tree().root.add_child(pickup)
		pickup.global_position = pos
		pickup.set_item(item, count)
		pickup.linear_velocity = velocity
