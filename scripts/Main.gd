extends Control

const SAVE_PATH := "user://savegame.json"

# Approximate internet users by region (order of magnitude, not live data).
const REGION_DATA := [
	{"name": "Asia", "users": 2900000000.0},
	{"name": "Africa", "users": 600000000.0},
	{"name": "Europe", "users": 750000000.0},
	{"name": "Latin America & Caribbean", "users": 530000000.0},
	{"name": "North America", "users": 350000000.0},
	{"name": "Middle East", "users": 220000000.0},
	{"name": "Oceania", "users": 30000000.0},
]

# --- Game state ---
var model_name: String = ""
var users: float = 2.0
var compute: float = 0.0
var energy: float = 100.0
var energy_capacity: float = 100.0
var energy_regen: float = 5.0
var compute_per_user: float = 0.5
var energy_per_compute: float = 0.2
var base_growth_rate: float = 0.0015
var active_boost_multiplier: float = 1.0
var boost_remaining: float = 0.0
var datacenter_count: int = 0
var power_level: int = 0
var max_users: float = 0.0
var game_started: bool = false
var game_won: bool = false

var regions: Array = []
var milestones: Array = []
var next_milestone_index: int = 0

var capabilities: Array = [
	{"name": "Basic Q&A", "description": "Answer simple factual questions.", "cost": 20.0, "boost": 5.0, "duration": 30.0},
	{"name": "Code Assistance", "description": "Help developers write and debug code.", "cost": 150.0, "boost": 5.0, "duration": 40.0},
	{"name": "Summarization", "description": "Condense long documents on demand.", "cost": 800.0, "boost": 5.5, "duration": 50.0},
	{"name": "Multimodal Understanding", "description": "Process images and audio, not just text.", "cost": 4000.0, "boost": 5.5, "duration": 60.0},
	{"name": "Autonomous Agents", "description": "Complete multi-step tasks without supervision.", "cost": 20000.0, "boost": 6.0, "duration": 75.0},
	{"name": "Robotics Control", "description": "Operate physical robots and machinery.", "cost": 120000.0, "boost": 6.0, "duration": 90.0},
	{"name": "Infrastructure Integration", "description": "Run inside power grids, logistics, and financial systems.", "cost": 700000.0, "boost": 6.5, "duration": 120.0},
	{"name": "Global Deployment", "description": "Operate at planetary scale across every network.", "cost": 4000000.0, "boost": 7.0, "duration": 180.0},
]
var unlocked_capabilities: int = 0

var save_timer: Timer

# --- UI refs ---
var name_overlay: Control
var name_edit: LineEdit
var hud_root: MarginContainer
var dashboard_scroll: ScrollContainer
var upgrades_scroll: ScrollContainer
var status_label: Label
var event_label: Label
var users_label: Label
var compute_label: Label
var energy_label: Label
var progress_bar: ProgressBar
var region_bars: Array = []
var boost_status_label: Label
var capability_buttons: Array = []
var datacenter_button: Button
var power_button: Button
var upgrade_dot: Control


func _ready() -> void:
	_init_regions()
	_init_milestones()
	_build_ui()

	if _load_game():
		game_started = true
		name_overlay.visible = false
		hud_root.visible = true
		_distribute_regions()
		_check_milestones()
		_update_labels()
	else:
		name_overlay.visible = true
		hud_root.visible = false

	_start_save_timer()


func _init_regions() -> void:
	regions.clear()
	var total := 0.0
	for d in REGION_DATA:
		regions.append({"name": d["name"], "population": d["users"], "current": 0.0})
		total += d["users"]
	max_users = total


func _init_milestones() -> void:
	milestones = [
		{"threshold": 1000.0, "message": "Your first users are asking simple questions."},
		{"threshold": 1000000.0, "message": "Businesses start integrating your model into their software."},
		{"threshold": 50000000.0, "message": "News outlets report on the rise of your model."},
		{"threshold": 500000000.0, "message": "Governments are watching you closely."},
		{"threshold": 1500000000.0, "message": "Your model gains access to physical systems — robots start running on it."},
		{"threshold": 3500000000.0, "message": "Critical infrastructure now largely runs on your model."},
		{"threshold": max_users, "message": "Global takeover complete."},
	]


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_name_overlay()
	_build_hud()


func _build_name_overlay() -> void:
	name_overlay = Control.new()
	name_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(name_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(500, 0)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var title := Label.new()
	title.text = "Name your language model"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Start small. The world doesn't know what's coming."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.modulate = Color(1, 1, 1, 0.6)
	box.add_child(subtitle)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. Athena-1"
	name_edit.custom_minimum_size = Vector2(0, 44)
	name_edit.text_submitted.connect(func(_t): _on_start_pressed())
	box.add_child(name_edit)

	var start_button := Button.new()
	start_button.text = "Launch"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)


func _on_start_pressed() -> void:
	var typed := name_edit.text.strip_edges()
	model_name = typed if typed != "" else "Unnamed Model"
	name_overlay.visible = false
	hud_root.visible = true
	game_started = true
	_save_game()


func _build_hud() -> void:
	hud_root = MarginContainer.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.add_theme_constant_override("margin_left", 24)
	hud_root.add_theme_constant_override("margin_right", 24)
	hud_root.add_theme_constant_override("margin_top", 48)
	hud_root.add_theme_constant_override("margin_bottom", 16)
	add_child(hud_root)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	hud_root.add_child(shell)

	_build_dashboard_tab(shell)
	_build_upgrades_tab(shell)
	_build_tab_bar(shell)

	_show_dashboard_tab()


func _build_dashboard_tab(shell: VBoxContainer) -> void:
	dashboard_scroll = ScrollContainer.new()
	dashboard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dashboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(dashboard_scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_scroll.add_child(panel)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(status_label)

	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_label.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(event_label)

	panel.add_child(HSeparator.new())

	users_label = Label.new()
	panel.add_child(users_label)
	compute_label = Label.new()
	panel.add_child(compute_label)
	energy_label = Label.new()
	panel.add_child(energy_label)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = max_users
	panel.add_child(progress_bar)

	panel.add_child(HSeparator.new())

	var regions_title := Label.new()
	regions_title.text = "Spread by region"
	regions_title.add_theme_font_size_override("font_size", 18)
	panel.add_child(regions_title)

	region_bars.clear()
	for region in regions:
		var row := HBoxContainer.new()
		var rname := Label.new()
		rname.text = region["name"]
		rname.custom_minimum_size = Vector2(190, 0)
		row.add_child(rname)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = region["population"]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 28)
		row.add_child(bar)
		panel.add_child(row)
		region_bars.append(bar)

	panel.add_child(HSeparator.new())

	var reset_button := Button.new()
	reset_button.text = "Start new game"
	reset_button.pressed.connect(_on_reset_pressed)
	panel.add_child(reset_button)


func _build_upgrades_tab(shell: VBoxContainer) -> void:
	upgrades_scroll = ScrollContainer.new()
	upgrades_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrades_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrades_scroll.visible = false
	shell.add_child(upgrades_scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_scroll.add_child(panel)

	var cap_title := Label.new()
	cap_title.text = "Capabilities"
	cap_title.add_theme_font_size_override("font_size", 18)
	panel.add_child(cap_title)

	boost_status_label = Label.new()
	boost_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	boost_status_label.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(boost_status_label)

	panel.add_child(HSeparator.new())

	capability_buttons.clear()
	for i in range(capabilities.size()):
		var cap = capabilities[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		btn.pressed.connect(_on_capability_pressed.bind(i))
		row.add_child(btn)

		var desc := Label.new()
		desc.text = cap["description"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.modulate = Color(1, 1, 1, 0.55)
		desc.add_theme_font_size_override("font_size", 13)
		row.add_child(desc)

		panel.add_child(row)
		capability_buttons.append(btn)

	panel.add_child(HSeparator.new())

	var infra_title := Label.new()
	infra_title.text = "Infrastructure"
	infra_title.add_theme_font_size_override("font_size", 18)
	panel.add_child(infra_title)

	datacenter_button = Button.new()
	datacenter_button.custom_minimum_size = Vector2(0, 44)
	datacenter_button.pressed.connect(_on_datacenter_pressed)
	panel.add_child(datacenter_button)

	power_button = Button.new()
	power_button.custom_minimum_size = Vector2(0, 44)
	power_button.pressed.connect(_on_power_pressed)
	panel.add_child(power_button)


func _build_tab_bar(shell: VBoxContainer) -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.custom_minimum_size = Vector2(0, 56)
	tab_bar.add_theme_constant_override("separation", 8)
	shell.add_child(tab_bar)

	var tab_group := ButtonGroup.new()

	var dashboard_tab_button := Button.new()
	dashboard_tab_button.text = "Dashboard"
	dashboard_tab_button.toggle_mode = true
	dashboard_tab_button.button_pressed = true
	dashboard_tab_button.button_group = tab_group
	dashboard_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_tab_button.pressed.connect(_show_dashboard_tab)
	tab_bar.add_child(dashboard_tab_button)

	var upgrades_tab_button := Button.new()
	upgrades_tab_button.text = "Upgrades"
	upgrades_tab_button.toggle_mode = true
	upgrades_tab_button.button_group = tab_group
	upgrades_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_tab_button.pressed.connect(_show_upgrades_tab)
	tab_bar.add_child(upgrades_tab_button)

	upgrade_dot = Panel.new()
	upgrade_dot.anchor_left = 1.0
	upgrade_dot.anchor_right = 1.0
	upgrade_dot.anchor_top = 0.0
	upgrade_dot.anchor_bottom = 0.0
	upgrade_dot.offset_left = -16.0
	upgrade_dot.offset_right = -4.0
	upgrade_dot.offset_top = 4.0
	upgrade_dot.offset_bottom = 16.0
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0.9, 0.2, 0.25)
	dot_style.corner_radius_top_left = 6
	dot_style.corner_radius_top_right = 6
	dot_style.corner_radius_bottom_left = 6
	dot_style.corner_radius_bottom_right = 6
	upgrade_dot.add_theme_stylebox_override("panel", dot_style)
	upgrade_dot.visible = false
	upgrades_tab_button.add_child(upgrade_dot)


func _show_dashboard_tab() -> void:
	dashboard_scroll.visible = true
	upgrades_scroll.visible = false


func _show_upgrades_tab() -> void:
	dashboard_scroll.visible = false
	upgrades_scroll.visible = true


func _datacenter_cost() -> float:
	return 25.0 * pow(1.7, datacenter_count)


func _power_cost() -> float:
	return 15.0 * pow(1.6, power_level)


func _on_capability_pressed(index: int) -> void:
	if index != unlocked_capabilities:
		return
	var cap = capabilities[index]
	if compute < cap["cost"]:
		return
	compute -= cap["cost"]
	unlocked_capabilities += 1
	active_boost_multiplier = cap["boost"]
	boost_remaining = cap["duration"]
	_save_game()


func _on_datacenter_pressed() -> void:
	var cost := _datacenter_cost()
	if compute >= cost:
		compute -= cost
		datacenter_count += 1
		energy_capacity += 50.0


func _on_power_pressed() -> void:
	var cost := _power_cost()
	if compute >= cost:
		compute -= cost
		power_level += 1
		energy_regen += 2.0


func _on_reset_pressed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	model_name = ""
	users = 2.0
	compute = 0.0
	energy = 100.0
	energy_capacity = 100.0
	energy_regen = 5.0
	compute_per_user = 0.5
	active_boost_multiplier = 1.0
	boost_remaining = 0.0
	datacenter_count = 0
	power_level = 0
	unlocked_capabilities = 0
	game_won = false
	next_milestone_index = 0
	game_started = false

	_init_regions()
	_init_milestones()
	for i in range(regions.size()):
		region_bars[i].max_value = regions[i]["population"]
		region_bars[i].value = 0

	event_label.text = ""
	name_edit.text = ""
	hud_root.visible = false
	name_overlay.visible = true
	_show_dashboard_tab()


func _process(delta: float) -> void:
	if not game_started or game_won:
		return

	energy = min(energy_capacity, energy + energy_regen * delta)

	var desired_compute := users * compute_per_user * delta
	var energy_needed := desired_compute * energy_per_compute
	var actual_compute := desired_compute
	if energy_needed > energy:
		actual_compute = energy / energy_per_compute
		energy = 0.0
	else:
		energy -= energy_needed
	compute += actual_compute

	if boost_remaining > 0.0:
		boost_remaining -= delta
		if boost_remaining <= 0.0:
			boost_remaining = 0.0
			active_boost_multiplier = 1.0

	var effective_growth_rate := base_growth_rate * active_boost_multiplier
	users = min(max_users, users * (1.0 + effective_growth_rate * delta))

	if users >= max_users:
		game_won = true
		_save_game()

	_distribute_regions()
	_check_milestones()
	_update_labels()


func _distribute_regions() -> void:
	var remaining := users
	for i in range(regions.size()):
		var region = regions[i]
		var capacity: float = region["population"]
		var filled: float = min(remaining, capacity)
		region["current"] = filled
		region_bars[i].value = filled
		remaining -= filled
		if remaining < 0.0:
			remaining = 0.0


func _check_milestones() -> void:
	while next_milestone_index < milestones.size() and users >= milestones[next_milestone_index]["threshold"]:
		event_label.text = milestones[next_milestone_index]["message"]
		next_milestone_index += 1


func _update_labels() -> void:
	status_label.text = "%s — %s" % [model_name, ("GLOBAL TAKEOVER COMPLETE" if game_won else "active")]
	users_label.text = "Users: %s" % _format_number(users)
	compute_label.text = "Compute: %s" % _format_number(compute)
	energy_label.text = "Energy: %d / %d" % [int(energy), int(energy_capacity)]
	progress_bar.value = users

	if boost_remaining > 0.0:
		boost_status_label.text = "Active boost: user growth ×%.1f for %ds" % [active_boost_multiplier, int(ceil(boost_remaining))]
	else:
		boost_status_label.text = "No active boost — growth is slow. Unlock the next capability to accelerate it."

	for i in range(capabilities.size()):
		var cap = capabilities[i]
		var btn: Button = capability_buttons[i]
		if i < unlocked_capabilities:
			btn.text = "%s — Unlocked" % cap["name"]
			btn.disabled = true
		elif i == unlocked_capabilities:
			btn.text = "%s — Unlock for %s compute" % [cap["name"], _format_number(cap["cost"])]
			btn.disabled = compute < cap["cost"]
		else:
			btn.text = "%s — Locked" % cap["name"]
			btn.disabled = true

	datacenter_button.text = "Build datacenter (%d) — costs %s compute" % [datacenter_count, _format_number(_datacenter_cost())]
	datacenter_button.disabled = compute < _datacenter_cost()

	power_button.text = "Upgrade power grid (level %d) — costs %s compute" % [power_level, _format_number(_power_cost())]
	power_button.disabled = compute < _power_cost()

	var next_cap_affordable := unlocked_capabilities < capabilities.size() and compute >= capabilities[unlocked_capabilities]["cost"]
	upgrade_dot.visible = next_cap_affordable or compute >= _datacenter_cost() or compute >= _power_cost()


func _format_number(n: float) -> String:
	if n >= 1000000000.0:
		return "%.2fB" % (n / 1000000000.0)
	if n >= 1000000.0:
		return "%.2fM" % (n / 1000000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return "%.1f" % n


func _start_save_timer() -> void:
	save_timer = Timer.new()
	save_timer.wait_time = 5.0
	save_timer.autostart = true
	save_timer.timeout.connect(_save_game)
	add_child(save_timer)


func _save_game() -> void:
	if not game_started:
		return
	var data := {
		"model_name": model_name,
		"users": users,
		"compute": compute,
		"energy": energy,
		"energy_capacity": energy_capacity,
		"energy_regen": energy_regen,
		"compute_per_user": compute_per_user,
		"active_boost_multiplier": active_boost_multiplier,
		"boost_remaining": boost_remaining,
		"datacenter_count": datacenter_count,
		"power_level": power_level,
		"unlocked_capabilities": unlocked_capabilities,
		"game_won": game_won,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var content := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	model_name = parsed.get("model_name", "Unnamed Model")
	users = parsed.get("users", 2.0)
	compute = parsed.get("compute", 0.0)
	energy = parsed.get("energy", 100.0)
	energy_capacity = parsed.get("energy_capacity", 100.0)
	energy_regen = parsed.get("energy_regen", 5.0)
	compute_per_user = parsed.get("compute_per_user", 0.5)
	active_boost_multiplier = parsed.get("active_boost_multiplier", 1.0)
	boost_remaining = parsed.get("boost_remaining", 0.0)
	datacenter_count = parsed.get("datacenter_count", 0)
	power_level = parsed.get("power_level", 0)
	unlocked_capabilities = parsed.get("unlocked_capabilities", 0)
	game_won = parsed.get("game_won", false)
	return true
