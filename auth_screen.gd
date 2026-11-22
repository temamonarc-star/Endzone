extends Control
class_name EndzoneAuthScreen
## Окно авторизации и создания аккаунта ENDZONE RP (без звука и без мелькания заставки)

signal login_submitted(username: String, password: String)
signal register_submitted(data: Dictionary)
signal auth_completed(user_data: Dictionary)

@export_file("*.tscn") var main_world_scene: String = "res://addons/renderer_fallback/compatibility_checker.tscn"

var is_register_mode: bool = true
var bg_video_player: VideoStreamPlayer = null
var video_started_seek: bool = false
var subtitle_lbl: Label
var nick_input: LineEdit
var pass_input: LineEdit
var pass_confirm_block: VBoxContainer
var pass_confirm_input: LineEdit
var error_label: Label
var submit_btn: Button
var switch_btn: Button

const ACCENT_ORANGE := Color(1.0, 0.56, 0.04)
const ACCENT_ORANGE_HOVER := Color(1.0, 0.65, 0.16)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()
	_set_mode(true)
	resized.connect(_update_video_zoom)

func _process(_delta: float) -> void:
	if bg_video_player and bg_video_player.is_playing():
		if not video_started_seek and bg_video_player.stream_position > 0.02:
			bg_video_player.stream_position = 3.8
			video_started_seek = true
			await get_tree().process_frame
			bg_video_player.visible = true
		elif bg_video_player.stream_position >= 26.5:
			bg_video_player.stream_position = 3.8

func _update_video_zoom() -> void:
	if bg_video_player:
		bg_video_player.pivot_offset = get_viewport_rect().size * 0.5
		bg_video_player.scale = Vector2(1.32, 1.32)

func _make_field_style(focused: bool = false) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.12, 0.14, 0.85)
	sb.border_color = ACCENT_ORANGE if focused else Color(1.0, 1.0, 1.0, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 13
	sb.content_margin_bottom = 13
	return sb

func _create_labeled_field(parent: Control, label_text: String, placeholder: String, is_secret: bool = false) -> LineEdit:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	parent.add_child(box)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", ACCENT_ORANGE)
	box.add_child(lbl)

	var le = LineEdit.new()
	le.placeholder_text = placeholder
	le.secret = is_secret
	le.custom_minimum_size = Vector2(0, 50)
	le.add_theme_font_size_override("font_size", 15)
	le.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	le.add_theme_color_override("font_placeholder_color", Color(0.50, 0.52, 0.56))
	le.add_theme_stylebox_override("normal", _make_field_style(false))
	le.add_theme_stylebox_override("focus", _make_field_style(true))
	box.add_child(le)
	return le

func _build_video_background() -> void:
	var video_path = "res://assets/ui/10425372510877.ogv"
	if ResourceLoader.exists(video_path):
		bg_video_player = VideoStreamPlayer.new()
		bg_video_player.name = "BgVideoPlayer"
		bg_video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_video_player.expand = true
		bg_video_player.loop = true
		bg_video_player.volume_db = -80.0
		bg_video_player.visible = false
		bg_video_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bg_video_player.stream = load(video_path)
		add_child(bg_video_player)
		bg_video_player.play()
		call_deferred("_update_video_zoom")
func _build_ui() -> void:
	_build_video_background()

	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.45)
	add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.04, 0.04, 0.05, 0.88)
	card_sb.border_color = Color(1.0, 1.0, 1.0, 0.14)
	card_sb.set_border_width_all(1)
	card_sb.set_corner_radius_all(16)
	card_sb.content_margin_left = 42
	card_sb.content_margin_right = 42
	card_sb.content_margin_top = 40
	card_sb.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 6)
	vbox.add_child(title_box)

	var brand = Label.new()
	brand.text = "ENDZONE RP"
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 34)
	brand.add_theme_color_override("font_color", ACCENT_ORANGE)
	brand.add_theme_color_override("font_outline_color", Color(1.0, 0.45, 0.0, 0.25))
	brand.add_theme_constant_override("outline_size", 4)
	title_box.add_child(brand)

	subtitle_lbl = Label.new()
	subtitle_lbl.text = "Создание аккаунта"
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.add_theme_font_size_override("font_size", 15)
	subtitle_lbl.add_theme_color_override("font_color", Color(0.86, 0.88, 0.90))
	title_box.add_child(subtitle_lbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(1.0, 1.0, 1.0, 0.08)
	vbox.add_child(sep)

	nick_input = _create_labeled_field(vbox, "Игрок", "Введите игровой никнейм", false)
	pass_input = _create_labeled_field(vbox, "Пароль", "Придумайте пароль", true)

	pass_confirm_block = VBoxContainer.new()
	vbox.add_child(pass_confirm_block)
	pass_confirm_input = _create_labeled_field(pass_confirm_block, "Повторите пароль", "Повторите пароль", true)

	error_label = Label.new()
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_font_size_override("font_size", 13)
	error_label.add_theme_color_override("font_color", Color(0.96, 0.34, 0.34))
	error_label.visible = false
	vbox.add_child(error_label)

	submit_btn = Button.new()
	submit_btn.text = "ДАЛЕЕ →"
	submit_btn.custom_minimum_size = Vector2(0, 52)
	submit_btn.add_theme_font_size_override("font_size", 15)
	submit_btn.add_theme_color_override("font_color", Color.WHITE)
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = ACCENT_ORANGE
	btn_sb.set_corner_radius_all(8)
	submit_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_hover = btn_sb.duplicate()
	btn_hover.bg_color = ACCENT_ORANGE_HOVER
	submit_btn.add_theme_stylebox_override("hover", btn_hover)
	submit_btn.add_theme_stylebox_override("pressed", btn_sb)
	submit_btn.pressed.connect(_on_submit_pressed)
	vbox.add_child(submit_btn)

	switch_btn = Button.new()
	switch_btn.flat = true
	switch_btn.add_theme_font_size_override("font_size", 13)
	switch_btn.add_theme_color_override("font_color", Color(0.62, 0.65, 0.70))
	switch_btn.add_theme_color_override("font_hover_color", ACCENT_ORANGE)
	switch_btn.pressed.connect(func(): _set_mode(not is_register_mode))
	vbox.add_child(switch_btn)

	var copy_lbl = Label.new()
	copy_lbl.text = "© 2026 ENDZONE Role Play | Все права защищены"
	copy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy_lbl.add_theme_font_size_override("font_size", 11)
	copy_lbl.add_theme_color_override("font_color", Color(0.45, 0.47, 0.52))
	vbox.add_child(copy_lbl)

func _set_mode(register: bool) -> void:
	is_register_mode = register
	pass_confirm_block.visible = register
	error_label.visible = false
	subtitle_lbl.text = "Создание аккаунта" if register else "Авторизация"
	pass_input.placeholder_text = "Придумайте пароль" if register else "Введите пароль"
	submit_btn.text = "ДАЛЕЕ →" if register else "ВОЙТИ →"
	switch_btn.text = "Уже есть аккаунт? Войти" if register else "Нет аккаунта? Создать аккаунт"

func _show_error(msg: String) -> void:
	error_label.text = msg
	error_label.visible = true

func _on_submit_pressed() -> void:
	error_label.visible = false
	var nick = nick_input.text.strip_edges()
	var pwd = pass_input.text

	if nick.length() < 4:
		_show_error("Никнейм должен содержать минимум 4 символа")
		return
	if pwd.length() < 6:
		_show_error("Пароль должен содержать минимум 6 символов")
		return

	if is_register_mode:
		if pwd != pass_confirm_input.text:
			_show_error("Введённые пароли не совпадают")
			return
		var data = {"username": nick, "password": pwd}
		register_submitted.emit(data)
		auth_completed.emit(data)
	else:
		login_submitted.emit(nick, pwd)
		auth_completed.emit({"username": nick})

	if main_world_scene != "" and ResourceLoader.exists(main_world_scene):
		get_tree().change_scene_to_file(main_world_scene)
