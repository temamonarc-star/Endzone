extends CanvasLayer
class_name PlayerHUDV2
## PlayerHUD - Main HUD for the world_player module
## Displays mode, hotbar, health, stamina, crosshair, interaction prompts

# References
@onready var mode_label: Label = $ModeIndicator
@onready var build_info_label: Label = $BuildInfoLabel
@onready var hotbar_container: HBoxContainer = $HotbarPanel/HotbarContainer
@onready var crosshair: TextureRect = $Crosshair
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var durability_bar: ProgressBar = $DurabilityBar
@onready var health_bar: ProgressBar = $StatusBars/HealthBar
@onready var stamina_bar: ProgressBar = $StatusBars/StaminaBar
@onready var compass: Label = $Compass
@onready var game_menu: Control = $GameMenu
@onready var selected_item_label: Label = $SelectedItemLabel
@onready var target_material_label: Label = $TargetMaterial

var underwater_overlay: ColorRect = null
var hotbar_slots: Array = []
var hotbar_ref: Node = null
var inventory_ref: Node = null

# V2 path
const InventorySlotScene = preload("res://modules/world_player_v2/features/data_inventory/ui_inventory/inventory_slot.tscn")

var durability_memory: Dictionary = {}
var last_hit_target_key: String = ""
const DURABILITY_PERSIST_MS: int = 6000

# Terraformer state
var terraformer_material: String = ""

# Save/Load notifications
var notification_label: Label = null
var notification_timer: float = 0.0

# UI State
var show_terrain_info: bool = false

func _ready() -> void:
	if has_node("/root/PlayerSignals"):
		PlayerSignals.mode_changed.connect(_on_mode_changed)
		PlayerSignals.item_changed.connect(_on_item_changed)
		PlayerSignals.hotbar_slot_selected.connect(_on_hotbar_slot_selected)
		PlayerSignals.interaction_available.connect(_on_interaction_available)
		PlayerSignals.interaction_unavailable.connect(_on_interaction_unavailable)
		PlayerSignals.inventory_toggled.connect(_on_inventory_toggled)
		PlayerSignals.game_menu_toggled.connect(_on_game_menu_toggled)
		PlayerSignals.editor_submode_changed.connect(_on_editor_submode_changed)
		PlayerSignals.inventory_changed.connect(_on_inventory_changed)
		PlayerSignals.durability_hit.connect(_on_durability_hit)
		PlayerSignals.durability_cleared.connect(_on_durability_cleared)
		PlayerSignals.target_material_changed.connect(_on_target_material_changed)
		PlayerSignals.camera_underwater_toggled.connect(_on_camera_underwater_toggled)
		PlayerSignals.terraformer_material_changed.connect(_on_terraformer_material_changed)
		PlayerSignals.item_added.connect(_on_item_added)
	
	_setup_hotbar()
	
	var exit_btn = game_menu.find_child("ExitButton", true, false)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
	
	# Connect collision debugger toggle
	var collision_toggle = game_menu.find_child("CollisionDebuggerToggle", true, false)
	if collision_toggle:
		collision_toggle.toggled.connect(_on_collision_debugger_toggled)
		# Sync with current state
		if has_node("/root/CollisionDebugger"):
			collision_toggle.button_pressed = get_node("/root/CollisionDebugger").enabled
	
	# Connect pickaxe dig mode toggle
	var pickaxe_toggle = game_menu.find_child("PickaxeDigModeToggle", true, false)
	if pickaxe_toggle:
		pickaxe_toggle.toggled.connect(_on_pickaxe_dig_mode_toggled)
		# Sync with current state
		if has_node("/root/ToolConfig"):
			pickaxe_toggle.button_pressed = get_node("/root/ToolConfig").pickaxe_dig_enabled
	
	# Connect pickaxe durability toggle
	var durability_toggle = game_menu.find_child("PickaxeDurabilityToggle", true, false)
	if durability_toggle:
		durability_toggle.toggled.connect(_on_pickaxe_durability_toggled)
		# Sync with current state
		if has_node("/root/ToolConfig"):
			durability_toggle.button_pressed = get_node("/root/ToolConfig").pickaxe_durability_enabled
	
	# Connect target visualizer toggle
	var visualizer_toggle = game_menu.find_child("TargetVisualizerToggle", true, false)
	if visualizer_toggle:
		visualizer_toggle.toggled.connect(_on_target_visualizer_toggled)
		# Sync with current state
		if has_node("/root/ToolConfig"):
			visualizer_toggle.button_pressed = get_node("/root/ToolConfig").target_visualizer_enabled
	
	# Connect hit marker toggle
	var hit_marker_toggle = game_menu.find_child("HitMarkerToggle", true, false)
	if hit_marker_toggle:
		hit_marker_toggle.toggled.connect(_on_hit_marker_toggled)
		# Sync with current state
		if has_node("/root/ToolConfig"):
			hit_marker_toggle.button_pressed = get_node("/root/ToolConfig").hit_marker_enabled
	
	# Connect pistol hit marker toggle
	var pistol_marker_toggle = game_menu.find_child("PistolHitMarkerToggle", true, false)
	if pistol_marker_toggle:
		pistol_marker_toggle.toggled.connect(_on_pistol_hit_marker_toggled)
		# Sync with current state
		if has_node("/root/ToolConfig"):
			pistol_marker_toggle.button_pressed = get_node("/root/ToolConfig").pistol_hit_marker_enabled
	
	# Connect terrain info toggle
	var terrain_info_toggle = game_menu.find_child("TerrainInfoToggle", true, false)
	if terrain_info_toggle:
		terrain_info_toggle.toggled.connect(_on_terrain_info_toggled)
		terrain_info_toggle.button_pressed = show_terrain_info
	
	# Connect chunk bounds toggle
	var chunk_bounds_toggle = game_menu.find_child("ChunkBoundsToggle", true, false)
	if chunk_bounds_toggle:
		chunk_bounds_toggle.toggled.connect(_on_chunk_bounds_toggled)
		# Sync with terrain manager if possible
		var tm = get_tree().get_first_node_in_group("terrain_manager")
		if tm and "debug_chunk_bounds" in tm:
			chunk_bounds_toggle.button_pressed = tm.debug_chunk_bounds
	
	# Connect road zones toggle
	var road_zones_toggle = game_menu.find_child("RoadZonesToggle", true, false)
	if road_zones_toggle:
		road_zones_toggle.toggled.connect(_on_road_zones_toggled)
		# Sync with terrain manager if possible
		var tm = get_tree().get_first_node_in_group("terrain_manager")
		if tm and "debug_show_road_zones" in tm:
			road_zones_toggle.button_pressed = tm.debug_show_road_zones
 
	# Connect spawning buttons
	var spawn_entity_btn = game_menu.find_child("SpawnEntityButton", true, false)
	if spawn_entity_btn:
		spawn_entity_btn.pressed.connect(_on_spawn_entity_pressed)
	
	var spawn_zombie_btn = game_menu.find_child("SpawnZombieButton", true, false)
	if spawn_zombie_btn:
		spawn_zombie_btn.pressed.connect(_on_spawn_zombie_pressed)
	
	var capture_prefab_btn = game_menu.find_child("CapturePrefabButton", true, false)
	if capture_prefab_btn:
		capture_prefab_btn.pressed.connect(_on_capture_prefab_pressed)
	
 
	
	var radius_slider = game_menu.find_child("MiningRadiusSlider", true, false)
	var radius_label = game_menu.find_child("MiningRadiusLabel", true, false)
	if radius_slider:
		radius_slider.value_changed.connect(_on_mining_radius_changed.bind(radius_label))
		# Sync with config
		if has_node("/root/ToolConfig"):
			radius_slider.value = get_node("/root/ToolConfig").pickaxe_mining_radius
			if radius_label:
				radius_label.text = "Mining Radius: %.2f" % radius_slider.value
	
	# Connect QuickSave button (F5)
	var quicksave_btn = game_menu.find_child("QuickSaveButton", true, false)
	if quicksave_btn:
		quicksave_btn.pressed.connect(_on_quicksave_pressed)
	
	# Connect QuickLoad button (F8)
	var quickload_btn = game_menu.find_child("QuickLoadButton", true, false)
	if quickload_btn:
		quickload_btn.pressed.connect(_on_quickload_pressed)

	# Deferred connection to SaveManager to avoid race conditions during scene load
	call_deferred("_connect_to_save_manager")

	
	mode_label.text = "PLAY"
	interaction_prompt.visible = false
	game_menu.visible = false
	if target_material_label:
		target_material_label.visible = false  # Hidden until debug preset enables it
	
	_setup_visual_overlays()

var item_notification_container: VBoxContainer = null

func _setup_visual_overlays() -> void:
	if not underwater_overlay:
		underwater_overlay = ColorRect.new()
		underwater_overlay.name = "UnderwaterOverlay"
		underwater_overlay.color = Color(0.05, 0.2, 0.12, 0.4)
		underwater_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underwater_overlay.visible = false
		add_child(underwater_overlay)
		move_child(underwater_overlay, 0)

	# Create save/load notification label
	if not notification_label:
		notification_label = Label.new()
		notification_label.name = "SaveLoadNotification"
		notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		notification_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		notification_label.offset_top = 50
		notification_label.offset_right = -50
		notification_label.add_theme_font_size_override("font_size", 28)
		notification_label.add_theme_color_override("font_color", Color.WHITE)
		notification_label.add_theme_color_override("font_outline_color", Color.BLACK)
		notification_label.add_theme_constant_override("outline_size", 4)
		notification_label.visible = false
		notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Ensure it grows inward from the right
		notification_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		add_child(notification_label)
		print("[HUD_SETUP] Notification label created")

	# Create item notification container
	if not item_notification_container:
		item_notification_container = VBoxContainer.new()
		item_notification_container.name = "ItemNotificationContainer"
		item_notification_container.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		item_notification_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		item_notification_container.grow_vertical = Control.GROW_DIRECTION_BOTH
		item_notification_container.offset_right = -50
		item_notification_container.offset_top = -200
		item_notification_container.offset_bottom = 200
		item_notification_container.alignment = BoxContainer.ALIGNMENT_END
		item_notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item_notification_container)
	
	# Create minimap (top-left, only visible in world map mode)
	var minimap = HUDMinimap.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(15, 90)  # Below compass area
	add_child(minimap)
	
	# Ensure it renders behind GameMenu and other overlays
	if has_node("GameMenu"):
		move_child(minimap, get_node("GameMenu").get_index())
	
	# Initial check (standardization to SaveManager as per project logic)
	_connect_to_save_manager()
	_setup_endzone_hud()

func _connect_to_save_manager() -> void:
	print("[HUD_SETUP] Connecting to SaveManager...")
	var save_mgr = get_tree().get_first_node_in_group("save_manager")
	if not save_mgr:
		# Standardized to SaveManager matching project.godot
		if has_node("/root/SaveManager"):
			save_mgr = get_node("/root/SaveManager")
	
	if save_mgr:
		if save_mgr.has_signal("save_completed") and not save_mgr.save_completed.is_connected(_on_save_completed):
			save_mgr.save_completed.connect(_on_save_completed)
			print("[HUD_SETUP] Connected to save_completed signal")
		if save_mgr.has_signal("load_completed") and not save_mgr.load_completed.is_connected(_on_load_completed):
			save_mgr.load_completed.connect(_on_load_completed)
			print("[HUD_SETUP] Connected to load_completed signal")
		# Check if already connected but name in log was missing
		if not save_mgr.save_completed.is_connected(_on_save_completed):
			print("[HUD_SETUP] WARNING: Failed to connect to signals even with SaveManager ref")
	else:
		print("[HUD_SETUP] WARNING: SaveManager not found in scene tree yet (will be handled by group signals if registered later)")

func _on_item_added(item_data: Dictionary, amount: int) -> void:
	print("HUD: _on_item_added received: %s x%d" % [item_data.get("name", "Unknown"), amount])
	if amount <= 0 or not item_notification_container:
		return
		
	var item_name = item_data.get("name", "Unknown Item")
	var label = Label.new()
	label.text = "+%d %s" % [amount, item_name]
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	item_notification_container.add_child(label)
	print("HUD: Added label to container: ", item_notification_container)
	
	var tween = create_tween()
	# Wait 2 seconds, then fade out over 1 second, then remove
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _process(_delta: float) -> void:
	_update_compass()
	_update_status_bars()
	_update_build_mode_info()
	_update_durability_visibility()
	
	# Update notification timer
	if notification_timer > 0:
		notification_timer -= _delta
		if notification_timer <= 0 and notification_label:
			notification_label.visible = false

func _setup_hotbar() -> void:
	hotbar_slots.clear()
	
	for i in range(6):
		var slot = InventorySlotScene.instantiate()
		slot.slot_index = i + 100
		slot.custom_minimum_size = Vector2(80, 60)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.item_dropped_outside.connect(_on_hotbar_item_dropped_outside.bind(slot))
		hotbar_container.add_child(slot)
		hotbar_slots.append(slot)
	
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		hotbar_ref = player_node.get_node_or_null("Systems/Hotbar")
		inventory_ref = player_node.get_node_or_null("Systems/Inventory")
	
	_refresh_hotbar_display()
	
	if hotbar_slots.size() > 0:
		hotbar_slots[0].modulate = Color.YELLOW
	
	if hotbar_ref and selected_item_label:
		var first_item = hotbar_ref.get_item_at(0)
		selected_item_label.text = first_item.get("name", "Fists")
		if ez_item_name_label:
			ez_item_name_label.text = _translate_item_name(first_item.get("name", "Fists"))
	_style_ez_hotbar()

func _refresh_hotbar_display() -> void:
	if not hotbar_ref:
		return
	
	var raw_data = hotbar_ref.get_all_slots() if hotbar_ref.has_method("get_all_slots") else []
	for i in range(min(hotbar_slots.size(), raw_data.size())):
		var slot_data = raw_data[i]
		if slot_data is Dictionary and slot_data.has("item"):
			var copy = slot_data.duplicate(true)
			if copy["item"] is Dictionary and copy["item"].has("name"):
				copy["item"]["name"] = _translate_item_name(copy["item"]["name"])
			hotbar_slots[i].set_slot_data(copy, i + 100)
		else:
			var item_copy = slot_data.duplicate(true) if slot_data is Dictionary else {}
			if item_copy.has("name"):
				item_copy["name"] = _translate_item_name(item_copy["name"])
			var wrapped = {"item": item_copy, "count": 1 if item_copy.get("id", "empty") != "empty" else 0}
			hotbar_slots[i].set_slot_data(wrapped, i + 100)
	
	_restore_slot_selection()
	if ez_item_name_label and hotbar_ref.has_method("get_selected_index") and hotbar_ref.has_method("get_item_at"):
		var cur_item = hotbar_ref.get_item_at(hotbar_ref.get_selected_index())
		if cur_item is Dictionary:
			ez_item_name_label.text = _translate_item_name(cur_item.get("name", "Fists"))


func _restore_slot_selection() -> void:
	if not hotbar_ref:
		return
	var selected = hotbar_ref.get_selected_index()
	_animate_ez_hotbar_selection(selected)


func _on_hotbar_item_dropped_outside(item: Dictionary, count: int, slot) -> void:
	var slot_idx = slot.slot_index - 100
	
	if hotbar_ref and hotbar_ref.has_method("clear_slot"):
		hotbar_ref.clear_slot(slot_idx)
	
	var player = get_tree().get_first_node_in_group("player")
	var drop_pos = Vector3.ZERO
	var drop_velocity = Vector3.ZERO
	if player:
		drop_pos = player.global_position - player.global_transform.basis.z * 2.0 + Vector3.UP
		drop_velocity = -player.global_transform.basis.z * 3.0 + Vector3.UP * 2.0
	
	_spawn_pickup(item, count, drop_pos, drop_velocity)
	_refresh_hotbar_display()

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
		# V2 path
		var pickup_scene = load("res://modules/world_player_v2/features/data_pickups/pickup_item.tscn")
		if not pickup_scene:
			return
		
		var pickup = pickup_scene.instantiate()
		get_tree().root.add_child(pickup)
		pickup.global_position = pos
		pickup.set_item(item, count)
		pickup.linear_velocity = velocity

func handle_slot_drop(source_index: int, target_index: int) -> void:
	if source_index == target_index:
		return
	
	# If container panel is open, delegate to it for 3-way drag-drop
	var container_panel = get_tree().get_first_node_in_group("container_panel")
	if container_panel and container_panel.visible:
		container_panel.handle_slot_drop(source_index, target_index)
		_refresh_hotbar_display()
		return
	
	var source_is_hotbar = source_index >= 100
	var target_is_hotbar = target_index >= 100
	var source_idx = source_index % 100
	var target_idx = target_index % 100
	
	var source_system = hotbar_ref if source_is_hotbar else inventory_ref
	var target_system = hotbar_ref if target_is_hotbar else inventory_ref
	
	if not source_system or not target_system:
		return
	
	var source_data = source_system.get_slot(source_idx) if source_system.has_method("get_slot") else {}
	var target_data = target_system.get_slot(target_idx) if target_system.has_method("get_slot") else {}
	
	var source_item = source_data.get("item", {})
	var source_count = source_data.get("count", 0)
	var target_item = target_data.get("item", {})
	var target_count = target_data.get("count", 0)
	
	if source_system.has_method("set_slot") and target_system.has_method("set_slot"):
		target_system.set_slot(target_idx, source_item, source_count)
		source_system.set_slot(source_idx, target_item, target_count)
	
	_refresh_hotbar_display()

func _update_compass() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var forward = - player.global_transform.basis.z
		var angle = rad_to_deg(atan2(forward.x, forward.z))
		
		var direction = ""
		if angle >= -22.5 and angle < 22.5:
			direction = "N"
		elif angle >= 22.5 and angle < 67.5:
			direction = "NE"
		elif angle >= 67.5 and angle < 112.5:
			direction = "E"
		elif angle >= 112.5 and angle < 157.5:
			direction = "SE"
		elif angle >= 157.5 or angle < -157.5:
			direction = "S"
		elif angle >= -157.5 and angle < -112.5:
			direction = "SW"
		elif angle >= -112.5 and angle < -67.5:
			direction = "W"
		elif angle >= -67.5 and angle < -22.5:
			direction = "NW"
		
		compass.text = direction

func _update_status_bars() -> void:
	if has_node("/root/PlayerStats"):
		health_bar.value = PlayerStats.health
		health_bar.max_value = PlayerStats.max_health
		stamina_bar.value = PlayerStats.stamina
		stamina_bar.max_value = PlayerStats.max_stamina
		if ez_hp_bar:
			ez_hp_bar.value = PlayerStats.health
			ez_hp_bar.max_value = PlayerStats.max_health
			ez_hp_value_label.text = str(int(PlayerStats.health))
		if ez_stamina_bar:
			ez_stamina_bar.value = PlayerStats.stamina
			ez_stamina_bar.max_value = PlayerStats.max_stamina
			ez_stamina_value_label.text = str(int(PlayerStats.stamina))

func _on_mode_changed(_old_mode: String, new_mode: String) -> void:
	mode_label.text = new_mode
	
	match new_mode:
		"PLAY":
			mode_label.modulate = Color.WHITE
		"BUILD":
			mode_label.modulate = Color.CYAN
		"EDITOR":
			mode_label.modulate = Color.YELLOW
	
	_update_hotbar_display()

func _on_item_changed(slot: int, item: Dictionary) -> void:
	# Allow updates in both player and editor modes
	if slot >= 0 and slot < hotbar_slots.size():
		var count = 1
		if hotbar_ref and hotbar_ref.has_method("get_count_at"):
			count = hotbar_ref.get_count_at(slot)
		var item_copy = item.duplicate(true) if item is Dictionary else {}
		if item_copy.has("name"):
			item_copy["name"] = _translate_item_name(item_copy["name"])
		var wrapped = {"item": item_copy, "count": count}
		hotbar_slots[slot].set_slot_data(wrapped, slot + 100)

	if hotbar_ref and selected_item_label:
		var selected_slot = hotbar_ref.get_selected_index()
		if slot == selected_slot:
			selected_item_label.text = item.get("name", "Empty")
			if ez_item_name_label:
				ez_item_name_label.text = _translate_item_name(item.get("name", "Empty"))

func _on_hotbar_slot_selected(slot: int) -> void:
	# Allow updates in both player and editor modes
	
	_animate_ez_hotbar_selection(slot)
	
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and selected_item_label:
		var hotbar = player_node.get_node_or_null("Systems/Hotbar")
		if hotbar:
			var item = hotbar.get_item_at(slot)
			selected_item_label.text = item.get("name", "Empty")
			if ez_item_name_label:
				ez_item_name_label.text = _translate_item_name(item.get("name", "Empty"))

func _on_interaction_available(_target: Node, prompt: String) -> void:
	interaction_prompt.text = prompt
	interaction_prompt.visible = true

func _on_interaction_unavailable() -> void:
	interaction_prompt.visible = false

func _on_inventory_toggled(_is_open: bool) -> void:
	pass

func _on_game_menu_toggled(is_open: bool) -> void:
	game_menu.visible = is_open

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_collision_debugger_toggled(is_enabled: bool) -> void:
	if has_node("/root/CollisionDebugger"):
		get_node("/root/CollisionDebugger").enabled = is_enabled

func _on_pickaxe_dig_mode_toggled(is_enabled: bool) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").pickaxe_dig_enabled = is_enabled
		print("PlayerHUD: Block Pickaxe Mode -> %s" % ("ON" if is_enabled else "OFF"))

func _on_pickaxe_durability_toggled(is_enabled: bool) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").pickaxe_durability_enabled = is_enabled
		print("PlayerHUD: Pickaxe Durability -> %s" % ("ON (5 hits)" if is_enabled else "OFF (Instant)"))


func _on_target_visualizer_toggled(is_enabled: bool) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").target_visualizer_enabled = is_enabled
		print("PlayerHUD: Target Visualizer -> %s" % ("ON" if is_enabled else "OFF"))

func _on_hit_marker_toggled(is_enabled: bool) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").hit_marker_enabled = is_enabled
		print("PlayerHUD: Hit Markers -> %s" % ("ON" if is_enabled else "OFF"))

func _on_pistol_hit_marker_toggled(is_enabled: bool) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").pistol_hit_marker_enabled = is_enabled
		print("PlayerHUD: Pistol Hit Markers -> %s" % ("ON" if is_enabled else "OFF"))

func _on_terrain_info_toggled(is_enabled: bool) -> void:
	show_terrain_info = is_enabled
	print("PlayerHUD: Terrain Info -> %s" % ("ON" if is_enabled else "OFF"))
	
	# Force update visibility immediately
	if target_material_label:
		target_material_label.visible = is_enabled
		# If turning on, we might want to refresh the text if it's currently empty/stale
		if is_enabled and target_material_label.text == "":
			target_material_label.text = "Waiting for target..."

func _on_chunk_bounds_toggled(is_enabled: bool) -> void:
	var tm = get_tree().get_first_node_in_group("terrain_manager")
	if tm and tm.has_method("set_debug_chunk_bounds"):
		tm.set_debug_chunk_bounds(is_enabled)
	elif tm and "debug_chunk_bounds" in tm:
		# Fallback if method not present yet
		tm.debug_chunk_bounds = is_enabled
		# Manual update if needed (matching chunk_manager.gd logic)
		if tm.has_method("update_debug_visuals"):
			tm.update_debug_visuals()
		print("PlayerHUD: Chunk Bounds -> %s" % ("ON" if is_enabled else "OFF"))

func _on_road_zones_toggled(is_enabled: bool) -> void:
	var tm = get_tree().get_first_node_in_group("terrain_manager")
	if tm and tm.has_method("set_debug_show_road_zones"):
		tm.set_debug_show_road_zones(is_enabled)
	elif tm and "debug_show_road_zones" in tm:
		# Fallback if method not present yet
		tm.debug_show_road_zones = is_enabled
		print("PlayerHUD: Road Zones -> %s" % ("ON" if is_enabled else "OFF"))

func _on_spawn_entity_pressed() -> void:
	var em = get_tree().get_first_node_in_group("entity_manager")
	if em and em.has_method("spawn_entity_near_player"):
		var entity = em.spawn_entity_near_player()
		if entity:
			print("PlayerHUD: Spawned test entity at %s" % entity.global_position)
	else:
		push_error("PlayerHUD: Entity manager or spawn_entity_near_player not found!")

func _on_spawn_zombie_pressed() -> void:
	var em = get_tree().get_first_node_in_group("entity_manager")
	if em and em.has_method("spawn_entity_near_player"):
		var zombie_scene = load("res://game/entities/zombie_base.tscn")
		if zombie_scene:
			var zombie = em.spawn_entity_near_player(zombie_scene)
			if zombie:
				print("PlayerHUD: Spawned ZOMBIE at %s" % zombie.global_position)
		else:
			push_error("PlayerHUD: Zombie scene not found!")
	else:
		push_error("PlayerHUD: Entity manager or spawn_entity_near_player not found!")

func _on_capture_prefab_pressed() -> void:
	print("PlayerHUD: Capture Prefab pressed")
	# 1. Close menu
	_on_game_menu_toggled(false)
	if has_node("/root/PlayerSignals"):
		PlayerSignals.game_menu_toggled.emit(false)
	
	# 2. Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 3. Find PrefabCapture and start selection
	var prefab_capture = get_tree().get_first_node_in_group("prefab_capture")
	if prefab_capture and prefab_capture.has_method("_enter_selection_mode"):
		prefab_capture._enter_selection_mode()
	else:
		print("PlayerHUD: PrefabCapture not found or missing method!")



func _on_mining_radius_changed(value: float, label: Label) -> void:
	if has_node("/root/ToolConfig"):
		get_node("/root/ToolConfig").pickaxe_mining_radius = value
	if label:
		label.text = "Mining Radius: %.2f" % value
	print("PlayerHUD: Mining Radius -> %.2f" % value)

func _on_quicksave_pressed() -> void:
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").quick_save()
		print("PlayerHUD: QuickSave triggered (F5)")
	else:
		push_error("PlayerHUD: SaveManager not found!")

func _on_quickload_pressed() -> void:
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").quick_load()
		print("PlayerHUD: QuickLoad triggered (F8)")
	else:
		push_error("PlayerHUD: SaveManager not found!")


func _on_inventory_changed() -> void:
	_refresh_hotbar_display()

func _update_build_mode_info() -> void:
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		if build_info_label:
			build_info_label.visible = false
		return
	
	var mode_manager_node = player_node.get_node_or_null("Systems/ModeManager")
	if not mode_manager_node:
		if build_info_label:
			build_info_label.visible = false
		return
	
	if not mode_manager_node.is_build_mode():
		if build_info_label:
			build_info_label.visible = false
		return
	
	var mode_build = player_node.get_node_or_null("Modes/ModeBuild")
	if not mode_build:
		if build_info_label:
			build_info_label.visible = false
		return
	
	var building_api = mode_build.get("building_api")
	if not building_api:
		if build_info_label:
			build_info_label.visible = false
		return
	
	var placement_modes = ["SNAP", "EMBED", "AUTO", "FILL"]
	var mode_idx = building_api.get("placement_mode")
	var mode_str = placement_modes[mode_idx] if mode_idx != null and mode_idx < 4 else "?"
	
	var curr_rotation = mode_build.get("current_rotation")
	var rot_str = "%d°" % (curr_rotation * 90) if curr_rotation != null else "?"
	
	var y_offset = building_api.get("placement_y_offset")
	var y_str = "Y:%+d" % y_offset if y_offset != null and y_offset != 0 else ""
	
	if build_info_label:
		build_info_label.text = "[%s] Rot:%s %s" % [mode_str, rot_str, y_str]
		build_info_label.visible = true

func _on_editor_submode_changed(_submode: int, _submode_name: String) -> void:
	_update_hotbar_display()

func _update_hotbar_display() -> void:
	# Use same display logic for both player and editor modes
	_refresh_hotbar_display()
	
	if hotbar_ref:
		var selected = hotbar_ref.get_selected_index()
		if selected >= 0 and selected < hotbar_slots.size():
			hotbar_slots[selected].modulate = Color.YELLOW
		
		if selected_item_label:
			var item = hotbar_ref.get_item_at(selected)
			selected_item_label.text = item.get("name", "Empty")
			if ez_item_name_label:
				ez_item_name_label.text = _translate_item_name(item.get("name", "Empty"))

func _target_to_key(target_ref: Variant) -> String:
	if target_ref is RID:
		return "rid:%d" % target_ref.get_id()
	elif target_ref is Vector3i:
		return "v3i:%d,%d,%d" % [target_ref.x, target_ref.y, target_ref.z]
	elif target_ref is Node:
		return "node:%d" % target_ref.get_instance_id()
	else:
		return "unknown:%s" % str(target_ref)

func _on_durability_hit(current_hp: int, max_hp: int, _target_name: String, target_ref: Variant) -> void:
	if not durability_bar:
		return
	var hp_percent = 100.0 * float(current_hp) / float(max_hp)
	
	var key = _target_to_key(target_ref)
	durability_memory[key] = {
		"target_ref": target_ref,
		"hit_time": Time.get_ticks_msec(),
		"hp_percent": hp_percent
	}
	last_hit_target_key = key
	
	print("DURABILITY_DEBUG: HUD received hit | Target: %s | HP: %.1f%% | Key: %s" % [_target_name, hp_percent, key])
	durability_bar.value = hp_percent
	durability_bar.visible = true

func _on_durability_cleared() -> void:
	if durability_bar:
		durability_bar.visible = false
		durability_bar.value = 0
	if last_hit_target_key != "":
		durability_memory.erase(last_hit_target_key)
		last_hit_target_key = ""

func _update_durability_visibility() -> void:
	if not durability_bar or durability_memory.is_empty():
		return
	
	var now = Time.get_ticks_msec()
	var keys_to_remove: Array = []
	for key in durability_memory:
		var entry = durability_memory[key]
		if now - entry.hit_time > DURABILITY_PERSIST_MS:
			keys_to_remove.append(key)
	for key in keys_to_remove:
		durability_memory.erase(key)
	
	if durability_memory.is_empty():
		durability_bar.visible = false
		return
	
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node or not player_node.has_method("raycast"):
		return
	
	var hit = player_node.raycast(5.0, 0xFFFFFFFF, true, true)
	if hit.is_empty():
		durability_bar.visible = false
		return
	
	var target = hit.get("collider")
	var position = hit.get("position", Vector3.ZERO)
	var hit_normal = hit.get("normal", Vector3.UP)
	
	var look_rid = target.get_rid() if target else RID()
	
	for key in durability_memory:
		var entry = durability_memory[key]
		var remembered_target = entry.target_ref
		var is_match = false
		
		if remembered_target is RID:
			if target and look_rid == remembered_target:
				is_match = true
		elif remembered_target is Vector3i:
			# Use SAME snapping logic as combat_system.gd to ensure position matching
			var snapped_pos = position - hit_normal * 0.1
			snapped_pos = Vector3(floor(snapped_pos.x) + 0.5, floor(snapped_pos.y) + 0.5, floor(snapped_pos.z) + 0.5)
			var block_pos = Vector3i(floor(snapped_pos.x), floor(snapped_pos.y), floor(snapped_pos.z))
			if block_pos == remembered_target:
				is_match = true
		elif remembered_target is Node:
			if target == remembered_target or _is_child_of(target, remembered_target):
				is_match = true
		
		if is_match:
			durability_bar.value = entry.hp_percent
			durability_bar.visible = true
			return
	
	print("DURABILITY_DEBUG: HUD hiding bar - no match found (looking at different block)")
	durability_bar.visible = false

func _is_child_of(node: Node, potential_parent: Node) -> bool:
	if not node or not potential_parent:
		return false
	var current = node.get_parent()
	while current:
		if current == potential_parent:
			return true
		current = current.get_parent()
	return false

func _on_target_material_changed(material_name: String) -> void:
	if target_material_label:
		target_material_label.visible = show_terrain_info
		
		if show_terrain_info:
			# Show terraformer material if equipped, otherwise show looking-at material
			if terraformer_material != "":
				target_material_label.text = "[TF: %s] %s" % [terraformer_material, material_name]
			else:
				target_material_label.text = material_name

func _on_terraformer_material_changed(material_name: String) -> void:
	terraformer_material = material_name
	if target_material_label:
		target_material_label.visible = show_terrain_info
		
		if show_terrain_info:
			if material_name == "":
				terraformer_material = ""
			else:
				target_material_label.text = "[TF: %s]" % material_name

func _on_camera_underwater_toggled(is_underwater: bool) -> void:
	if underwater_overlay:
		underwater_overlay.visible = is_underwater

func _on_save_completed(success: bool, _path: String) -> void:
	if success and notification_label:
		notification_label.text = "ИГРА СОХРАНЕНА"
		notification_label.visible = true
		notification_timer = 2.0  # Show for 2 seconds
		print("[SAVE_NOTIFICATION] Game saved!")

func _on_load_completed(success: bool, _path: String) -> void:
	if success and notification_label:
		notification_label.text = "ИГРА ЗАГРУЖЕНА"
		notification_label.visible = true
		notification_timer = 2.0  # Show for 2 seconds
		print("[LOAD_NOTIFICATION] Game loaded!")
# ==============================================================================
# ENDZONE RP — МОДУЛЬНЫЙ СТИЛЬ HUD И РУСИФИКАЦИЯ
# ==============================================================================
var ez_hud_root: VBoxContainer = null
var ez_money_label: Label = null
var ez_hp_bar: ProgressBar = null
var ez_hp_value_label: Label = null
var ez_stamina_bar: ProgressBar = null
var ez_stamina_value_label: Label = null
var ez_item_name_label: Label = null

const EZ_ITEM_NAMES_RU: Dictionary = {
	"Fists": "Кулаки",
	"Empty": "Пусто",
	"Stone Pickaxe": "Каменная кирка",
	"Stone Axe": "Каменный топор",
	"Shovel": "Лопата",
	"Terraformer": "Терраформер",
	"Pistol": "Пистолет",
	"Water Bucket": "Ведро воды",
	"Dirt": "Земля",
	"Wood Cube": "Деревянный куб",
	"Ramp": "Рампа",
	"Wooden Door": "Деревянная дверь",
	"Cardboard Box": "Картонная коробка",
	"Car Keys": "Ключи от авто"

}

func _translate_item_name(raw_name: String) -> String:
	return EZ_ITEM_NAMES_RU.get(raw_name, raw_name)

func _make_ez_card_style(_accent_left: bool = false) -> StyleBoxEmpty:
	var sb = StyleBoxEmpty.new()
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

func _apply_clean_shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)

func _make_ez_bar(fill_color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 8)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.18, 0.22, 0.9)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fg = StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.corner_radius_top_left = 4
	fg.corner_radius_top_right = 4
	fg.corner_radius_bottom_left = 4
	fg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

func _setup_endzone_hud() -> void:
	if has_node("StatusBars"):
		$StatusBars.visible = false
	if selected_item_label:
		selected_item_label.visible = false
	if mode_label:
		mode_label.visible = false
	if has_node("HotbarPanel"):
		$HotbarPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	ez_hud_root = VBoxContainer.new()
	ez_hud_root.name = "EndzoneTopRightHUD"
	ez_hud_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ez_hud_root.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ez_hud_root.offset_top = 18
	ez_hud_root.offset_right = -18
	ez_hud_root.add_theme_constant_override("separation", 8)
	ez_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ez_hud_root)

	# КАПСУЛА 1: Логотип ENDZONE RP + Баланс
	var top_row = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_theme_constant_override("separation", 8)
	ez_hud_root.add_child(top_row)

	var money_panel = PanelContainer.new()
	money_panel.add_theme_stylebox_override("panel", _make_ez_card_style(false))
	ez_money_label = Label.new()
	ez_money_label.text = "$ 500"
	ez_money_label.add_theme_font_size_override("font_size", 15)
	ez_money_label.add_theme_color_override("font_color", Color(0.35, 0.90, 0.45))
	money_panel.add_child(ez_money_label)
	top_row.add_child(money_panel)

	var brand_panel = PanelContainer.new()
	brand_panel.add_theme_stylebox_override("panel", _make_ez_card_style(true))
	
	var logo_vbox = VBoxContainer.new()
	logo_vbox.add_theme_constant_override("separation", -4)
	logo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var main_title = Label.new()
	main_title.text = "ENDZONE"
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	main_title.add_theme_font_size_override("font_size", 24)
	main_title.add_theme_color_override("font_color", Color(0.28, 0.82, 1.0))
	main_title.add_theme_color_override("font_outline_color", Color(0.98, 0.78, 0.12))
	main_title.add_theme_constant_override("outline_size", 4)
	logo_vbox.add_child(main_title)
	
	var sub_title = Label.new()
	sub_title.text = "R O L E P L A Y"
	sub_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sub_title.add_theme_font_size_override("font_size", 10)
	sub_title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.18))
	_apply_clean_shadow(sub_title)
	logo_vbox.add_child(sub_title)
	
	brand_panel.add_child(logo_vbox)
	top_row.add_child(brand_panel)

	# КАПСУЛА 2: Полоски здоровья и выносливости
	var stats_panel = PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", _make_ez_card_style(false))
	ez_hud_root.add_child(stats_panel)

	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_vbox)

	var hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	var hp_title = Label.new()
	hp_title.text = "ЗДОРОВЬЕ"
	hp_title.custom_minimum_size = Vector2(74, 0)
	hp_title.add_theme_font_size_override("font_size", 11)
	hp_title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.90))
	ez_hp_bar = _make_ez_bar(Color(0.92, 0.25, 0.25))
	ez_hp_value_label = Label.new()
	ez_hp_value_label.text = "100"
	ez_hp_value_label.custom_minimum_size = Vector2(28, 0)
	ez_hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ez_hp_value_label.add_theme_font_size_override("font_size", 12)
	hp_row.add_child(hp_title)
	hp_row.add_child(ez_hp_bar)
	hp_row.add_child(ez_hp_value_label)
	stats_vbox.add_child(hp_row)

	var st_row = HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 8)
	var st_title = Label.new()
	st_title.text = "ЭНЕРГИЯ"
	st_title.custom_minimum_size = Vector2(74, 0)
	st_title.add_theme_font_size_override("font_size", 11)
	st_title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.90))
	ez_stamina_bar = _make_ez_bar(Color(1.0, 0.52, 0.05))
	ez_stamina_value_label = Label.new()
	ez_stamina_value_label.text = "100"
	ez_stamina_value_label.custom_minimum_size = Vector2(28, 0)
	ez_stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ez_stamina_value_label.add_theme_font_size_override("font_size", 12)
	st_row.add_child(st_title)
	st_row.add_child(ez_stamina_bar)
	st_row.add_child(ez_stamina_value_label)
	stats_vbox.add_child(st_row)

	# КАПСУЛА 3: Предмет в руках
	var item_panel = PanelContainer.new()
	item_panel.add_theme_stylebox_override("panel", _make_ez_card_style(true))
	ez_hud_root.add_child(item_panel)

	var item_row = HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 8)
	var hand_lbl = Label.new()
	hand_lbl.text = "В РУКАХ:"
	hand_lbl.add_theme_font_size_override("font_size", 11)
	hand_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	ez_item_name_label = Label.new()
	ez_item_name_label.text = "Кулаки"
	ez_item_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ez_item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ez_item_name_label.add_theme_font_size_override("font_size", 13)
	ez_item_name_label.add_theme_color_override("font_color", Color.WHITE)
	item_row.add_child(hand_lbl)
	item_row.add_child(ez_item_name_label)
	item_panel.add_child(item_row)
	for lbl in [ez_money_label, hp_title, ez_hp_value_label, st_title, ez_stamina_value_label, hand_lbl, ez_item_name_label]:
		if lbl:
			_apply_clean_shadow(lbl)
	var menu_ru = {
		"Exit Game": "Выйти из игры",
		"QuickSave (F5)": "Быстрое сохранение (F5)",
		"QuickLoad (F8)": "Быстрая загрузка (F8)",
		"Gameplay Settings": "Настройки игры",
		"Block Pickaxe Mode": "Режим копки блоков",
		"Pickaxe Durability": "Прочность кирки",
		"Show Hit Markers": "Маркеры попаданий",
		"Pistol Red Markers": "Красные маркеры пистолета",
		"Debug Settings": "Настройки отладки",
		"Collision Debugger": "Отладка коллизий",
		"Target Visualizer": "Подсветка цели",
		"Show Terrain Info": "Инфо о ландшафте",
		"Show Chunk Bounds": "Границы чанков",
		"Show Road Zones": "Зоны дорог",
		"Spawn Test Entity": "Создать тестовый объект",
		"Spawn Zombie": "Создать зомби",
		"Capture Prefab (Selection Mode)": "Сохранить префаб (выделение)"
	}
	if game_menu:
		for node in game_menu.find_children("*", "Label", true, false) + game_menu.find_children("*", "Button", true, false) + game_menu.find_children("*", "CheckButton", true, false):
			if menu_ru.has(node.text):
				node.text = menu_ru[node.text]

# ==============================================================================
# ENDZONE RP — ОТДЕЛЬНОЕ МЕНЮ АНИМАЦИЙ И ДЕЙСТВИЙ (КЛАВИША U)
# ==============================================================================
var ez_actions_menu: VBoxContainer = null
var ez_actions_visible: bool = false

const EZ_ACTIONS_LIST: Array[Dictionary] = [
	{"key": "1", "id": "hands_up", "title": "Поднять руки вверх"},
	{"key": "2", "id": "wave", "title": "Помахать рукой"},
	{"key": "3", "id": "sit", "title": "Присесть отдохнуть"},
	{"key": "4", "id": "inspect", "title": "Осмотреться вокруг"},
	{"key": "5", "id": "give_item", "title": "Передать предмет игроку"},
	{"key": "6", "id": "show_docs", "title": "Показать документы"}
]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			_toggle_ez_actions_menu()
			get_viewport().set_input_as_handled()
		elif ez_actions_visible:
			if event.keycode == KEY_ESCAPE:
				_toggle_ez_actions_menu(false)
				get_viewport().set_input_as_handled()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
				var idx = event.keycode - KEY_1
				if idx < EZ_ACTIONS_LIST.size():
					_trigger_ez_action(EZ_ACTIONS_LIST[idx])
					get_viewport().set_input_as_handled()

func _toggle_ez_actions_menu(force_state = null) -> void:
	if not ez_actions_menu:
		_build_ez_actions_menu()
	ez_actions_visible = force_state if force_state != null else not ez_actions_visible
	ez_actions_menu.visible = ez_actions_visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ez_actions_visible else Input.MOUSE_MODE_CAPTURED

func _build_ez_actions_menu() -> void:
	ez_actions_menu = VBoxContainer.new()
	ez_actions_menu.name = "EndzoneActionsMenu"
	ez_actions_menu.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	ez_actions_menu.offset_left = 28
	ez_actions_menu.offset_top = -120
	ez_actions_menu.add_theme_constant_override("separation", 6)
	ez_actions_menu.visible = false
	add_child(ez_actions_menu)

	var header = Label.new()
	header.text = "ДЕЙСТВИЯ И АНИМАЦИИ [U]"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1.0, 0.52, 0.05))
	_apply_clean_shadow(header)
	ez_actions_menu.add_child(header)

	for act in EZ_ACTIONS_LIST:
		var btn = Button.new()
		btn.text = "[%s]  %s" % [act["key"], act["title"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.52, 0.05))
		btn.pressed.connect(_trigger_ez_action.bind(act))
		ez_actions_menu.add_child(btn)

func _trigger_ez_action(act: Dictionary) -> void:
	_toggle_ez_actions_menu(false)
	if notification_label:
		notification_label.text = "Действие: " + act["title"]
		notification_label.visible = true
		notification_timer = 2.0
	# TODO: Сюда можно привязать запуск анимации через AnimationPlayer или сигнал на сервер
# ==============================================================================
# ENDZONE RP — СТИЛИЗАЦИЯ И АНИМАЦИЯ БЫСТРОГО ДОСТУПА (6 СЛОТОВ, 1..6)
# ==============================================================================
var ez_slot_tweens: Dictionary = {}

func _make_ez_slot_box(active: bool) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.85) if active else Color(0.05, 0.06, 0.08, 0.65)
	sb.border_color = Color(0.28, 0.82, 1.0, 0.95) if active else Color(1.0, 1.0, 1.0, 0.14)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(8)
	return sb

func _style_ez_hotbar() -> void:
	if hotbar_container:
		hotbar_container.add_theme_constant_override("separation", 8)
		hotbar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		slot.custom_minimum_size = Vector2(58, 58)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.pivot_offset = Vector2(29, 58)
		if slot is PanelContainer or slot is Panel:
			slot.add_theme_stylebox_override("panel", _make_ez_slot_box(i == 0))
		for child in slot.find_children("*", "Label", true, false):
			if child.name == "EZKeyBadge":
				continue
			if not child.text.is_valid_int():
				child.visible = false
			else:
				child.add_theme_font_size_override("font_size", 11)
				_apply_clean_shadow(child)
		if not slot.has_node("EZKeyBadge"):
			var key_lbl = Label.new()
			key_lbl.name = "EZKeyBadge"
			key_lbl.text = str(i + 1)
			key_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			key_lbl.offset_left = 6
			key_lbl.offset_top = 4
			key_lbl.add_theme_font_size_override("font_size", 10)
			key_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 0.85))
			_apply_clean_shadow(key_lbl)
			slot.add_child(key_lbl)
	_animate_ez_hotbar_selection(0)
func _animate_ez_hotbar_selection(selected_idx: int) -> void:
	for i in range(hotbar_slots.size()):
		var slot = hotbar_slots[i]
		var is_sel = (i == selected_idx)
		slot.modulate = Color.WHITE
		if slot is PanelContainer or slot is Panel:
			slot.add_theme_stylebox_override("panel", _make_ez_slot_box(is_sel))
		if ez_slot_tweens.has(i) and ez_slot_tweens[i] is Tween:
			ez_slot_tweens[i].kill()
		var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(slot, "position:y", -10.0 if is_sel else 0.0, 0.18)
		tw.tween_property(slot, "scale", Vector2(1.06, 1.06) if is_sel else Vector2(1.0, 1.0), 0.18)
		ez_slot_tweens[i] = tw
