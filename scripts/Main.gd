extends Control

const SAVE_PATH := "user://savegame.json"

# A datacenter is server hardware: it raises how many queries/second you can
# serve (Revenue throughput), not how much energy exists. A power plant is
# the energy source that feeds those datacenters.
const BASE_SERVING_CAPACITY := 5.0
const SERVING_CAPACITY_PER_DATACENTER := 8.0

# Population segments, roughly grounded in real-world figures (order of
# magnitude, not precise) rather than an even split:
# - Developers: ~28-47M professional software developers worldwide (various
#   industry surveys put estimates in that range; we use ~30M).
# - Knowledge workers: ~1B+ knowledge-worker jobs globally (~1/3 of the
#   global workforce).
# - Students: rough figure for globally connected students/researchers.
# - The remaining buckets (enthusiasts, businesses, governments, everyday
#   consumers, skeptics) are rough narrative estimates, not sourced stats.
# Segments are listed in the order they realistically start adopting new AI
# tools (early/technical audiences first, skeptics last), and sum to the
# same ~5.38B total online population used before.
const SEGMENT_DATA := [
	{"name": "AI Enthusiasts", "users": 150000000.0},
	{"name": "Developers", "users": 30000000.0},
	{"name": "Students", "users": 250000000.0},
	{"name": "Knowledge Workers", "users": 1000000000.0},
	{"name": "Businesses", "users": 300000000.0},
	{"name": "Everyday Consumers", "users": 2600000000.0},
	{"name": "Governments", "users": 300000000.0},
	{"name": "Skeptics", "users": 750000000.0},
]

# --- Game state ---
# Users give two distinct things: Revenue (they pay to use the model, funds
# infrastructure) and Data (their interactions are training signal, funds
# new capabilities). Revenue is energy-limited (serving queries at scale
# costs power); Data collection is not. Capabilities are permanent — once
# trained into the model, they stay; they don't fade like a temporary buff.
var model_name: String = ""
var users: float = 2.0
var revenue: float = 0.0
var data: float = 0.0
var energy: float = 100.0
var energy_capacity: float = 100.0
var energy_regen: float = 5.0
var revenue_per_user: float = 0.4
var data_per_user: float = 0.6
var energy_per_revenue: float = 0.2
var base_growth_rate: float = 0.006
var permanent_growth_multiplier: float = 1.0
var datacenter_count: int = 0
var power_level: int = 0
var max_users: float = 0.0
var game_started: bool = false
var game_won: bool = false

var segments: Array = []
var milestones: Array = []
var next_milestone_index: int = 0

var capabilities: Array = [
	{"name": "Basic Q&A", "description": "Answer simple factual questions.", "cost": 15.0, "multiplier": 1.3},
	{"name": "Code Assistance", "description": "Help developers write and debug code.", "cost": 120.0, "multiplier": 1.3},
	{"name": "Summarization", "description": "Condense long documents on demand.", "cost": 600.0, "multiplier": 1.4},
	{"name": "Multimodal Understanding", "description": "Process images and audio, not just text.", "cost": 3000.0, "multiplier": 1.4},
	{"name": "Autonomous Agents", "description": "Complete multi-step tasks without supervision.", "cost": 15000.0, "multiplier": 1.5},
	{"name": "Robotics Control", "description": "Operate physical robots and machinery.", "cost": 90000.0, "multiplier": 1.6},
	{"name": "Infrastructure Integration", "description": "Run inside power grids, logistics, and financial systems.", "cost": 500000.0, "multiplier": 1.7},
	{"name": "Global Deployment", "description": "Operate at planetary scale across every network.", "cost": 3000000.0, "multiplier": 1.8},
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
var revenue_label: Label
var data_label: Label
var energy_label: Label
var capacity_label: Label
var strength_label_dashboard: Label
var progress_bar: ProgressBar
var segment_bars: Array = []
var strength_label_upgrades: Label
var capability_buttons: Array = []
var datacenter_button: Button
var power_button: Button
var upgrade_dot: Control
var notifications_container: VBoxContainer


func _ready() -> void:
	_init_segments()
	_init_milestones()
	_build_ui()

	if _load_game():
		game_started = true
		name_overlay.visible = false
		hud_root.visible = true
		_recompute_growth_multiplier()
		_distribute_segments(false)
		_check_milestones()
		_update_labels()
	else:
		name_overlay.visible = true
		hud_root.visible = false

	_start_save_timer()


func _init_segments() -> void:
	segments.clear()
	var total := 0.0
	for d in SEGMENT_DATA:
		segments.append({"name": d["name"], "population": d["users"], "current": 0.0, "notified": false})
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
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_name_overlay()
	_build_hud()
	_build_notifications_layer()


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


func _new_card(parent: Control) -> VBoxContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.19)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	parent.add_child(card)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	return body


func _section_title(text: String, parent: Control) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)
	return label


func _build_dashboard_tab(shell: VBoxContainer) -> void:
	dashboard_scroll = ScrollContainer.new()
	dashboard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dashboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(dashboard_scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_scroll.add_child(panel)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(status_label)

	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_label.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(event_label)

	var resources_card := _new_card(panel)
	_section_title("Resources", resources_card)

	users_label = Label.new()
	users_label.add_theme_font_size_override("font_size", 17)
	resources_card.add_child(users_label)

	revenue_label = Label.new()
	revenue_label.modulate = Color(0.55, 0.85, 0.55)
	resources_card.add_child(revenue_label)

	data_label = Label.new()
	data_label.modulate = Color(0.65, 0.75, 1.0)
	resources_card.add_child(data_label)

	energy_label = Label.new()
	energy_label.modulate = Color(1.0, 0.75, 0.35)
	resources_card.add_child(energy_label)

	capacity_label = Label.new()
	capacity_label.modulate = Color(0.55, 0.85, 0.55)
	resources_card.add_child(capacity_label)

	strength_label_dashboard = Label.new()
	strength_label_dashboard.modulate = Color(0.9, 0.7, 1.0)
	resources_card.add_child(strength_label_dashboard)

	var spread_caption := Label.new()
	spread_caption.text = "World adoption"
	spread_caption.modulate = Color(1, 1, 1, 0.55)
	spread_caption.add_theme_font_size_override("font_size", 13)
	resources_card.add_child(spread_caption)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = max_users
	resources_card.add_child(progress_bar)

	var segments_card := _new_card(panel)
	_section_title("Adoption by segment", segments_card)

	segment_bars.clear()
	for segment in segments:
		var row := HBoxContainer.new()
		var sname := Label.new()
		sname.text = segment["name"]
		sname.custom_minimum_size = Vector2(170, 0)
		sname.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(sname)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = segment["population"]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 26)
		row.add_child(bar)
		segments_card.add_child(row)
		segment_bars.append(bar)

	var reset_button := Button.new()
	reset_button.text = "Start new game"
	reset_button.modulate = Color(1, 1, 1, 0.6)
	reset_button.pressed.connect(_on_reset_pressed)
	panel.add_child(reset_button)


func _build_upgrades_tab(shell: VBoxContainer) -> void:
	upgrades_scroll = ScrollContainer.new()
	upgrades_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrades_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrades_scroll.visible = false
	shell.add_child(upgrades_scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_scroll.add_child(panel)

	var cap_card := _new_card(panel)
	_section_title("Capabilities — permanent, trained on Data", cap_card)

	strength_label_upgrades = Label.new()
	strength_label_upgrades.autowrap_mode = TextServer.AUTOWRAP_WORD
	strength_label_upgrades.modulate = Color(0.9, 0.7, 1.0)
	cap_card.add_child(strength_label_upgrades)

	cap_card.add_child(HSeparator.new())

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

		cap_card.add_child(row)
		capability_buttons.append(btn)

	var infra_card := _new_card(panel)
	_section_title("Infrastructure — funded by Revenue", infra_card)

	var datacenter_row := VBoxContainer.new()
	datacenter_row.add_theme_constant_override("separation", 2)
	datacenter_button = Button.new()
	datacenter_button.custom_minimum_size = Vector2(0, 44)
	datacenter_button.pressed.connect(_on_datacenter_pressed)
	datacenter_row.add_child(datacenter_button)
	var datacenter_desc := Label.new()
	datacenter_desc.text = "Server hardware. Raises how many users you can serve at once — needs energy to run."
	datacenter_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	datacenter_desc.modulate = Color(1, 1, 1, 0.55)
	datacenter_desc.add_theme_font_size_override("font_size", 13)
	datacenter_row.add_child(datacenter_desc)
	infra_card.add_child(datacenter_row)

	var power_row := VBoxContainer.new()
	power_row.add_theme_constant_override("separation", 2)
	power_button = Button.new()
	power_button.custom_minimum_size = Vector2(0, 44)
	power_button.pressed.connect(_on_power_pressed)
	power_row.add_child(power_button)
	var power_desc := Label.new()
	power_desc.text = "Energy source. Generates and stores more power to keep your datacenters running."
	power_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	power_desc.modulate = Color(1, 1, 1, 0.55)
	power_desc.add_theme_font_size_override("font_size", 13)
	power_row.add_child(power_desc)
	infra_card.add_child(power_row)


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


func _build_notifications_layer() -> void:
	notifications_container = VBoxContainer.new()
	notifications_container.anchor_left = 1.0
	notifications_container.anchor_right = 1.0
	notifications_container.anchor_top = 0.0
	notifications_container.anchor_bottom = 0.0
	notifications_container.offset_left = -360.0
	notifications_container.offset_right = -16.0
	notifications_container.offset_top = 16.0
	notifications_container.offset_bottom = 600.0
	notifications_container.add_theme_constant_override("separation", 8)
	add_child(notifications_container)


func _show_notification(text: String) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.19, 0.27)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var label := Label.new()
	label.text = "📰 " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(260, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28, 28)
	close_button.pressed.connect(func(): card.queue_free())
	row.add_child(close_button)

	notifications_container.add_child(card)

	var timer := get_tree().create_timer(8.0)
	timer.timeout.connect(func():
		if is_instance_valid(card):
			card.queue_free()
	)


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


func _serving_capacity() -> float:
	return BASE_SERVING_CAPACITY + datacenter_count * SERVING_CAPACITY_PER_DATACENTER


func _recompute_growth_multiplier() -> void:
	permanent_growth_multiplier = 1.0
	for i in range(unlocked_capabilities):
		permanent_growth_multiplier *= capabilities[i]["multiplier"]


func _on_capability_pressed(index: int) -> void:
	if index != unlocked_capabilities:
		return
	var cap = capabilities[index]
	if data < cap["cost"]:
		return
	data -= cap["cost"]
	unlocked_capabilities += 1
	permanent_growth_multiplier *= cap["multiplier"]
	_save_game()


func _on_datacenter_pressed() -> void:
	var cost := _datacenter_cost()
	if revenue >= cost:
		revenue -= cost
		datacenter_count += 1


func _on_power_pressed() -> void:
	var cost := _power_cost()
	if revenue >= cost:
		revenue -= cost
		power_level += 1
		energy_regen += 2.0
		energy_capacity += 20.0


func _on_reset_pressed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	model_name = ""
	users = 2.0
	revenue = 0.0
	data = 0.0
	energy = 100.0
	energy_capacity = 100.0
	energy_regen = 5.0
	permanent_growth_multiplier = 1.0
	datacenter_count = 0
	power_level = 0
	unlocked_capabilities = 0
	game_won = false
	next_milestone_index = 0
	game_started = false

	_init_segments()
	_init_milestones()
	for i in range(segments.size()):
		segment_bars[i].max_value = segments[i]["population"]
		segment_bars[i].value = 0

	for child in notifications_container.get_children():
		child.queue_free()

	event_label.text = ""
	name_edit.text = ""
	hud_root.visible = false
	name_overlay.visible = true
	_show_dashboard_tab()


func _process(delta: float) -> void:
	if not game_started or game_won:
		return

	energy = min(energy_capacity, energy + energy_regen * delta)

	var capacity_limited_rate: float = min(users * revenue_per_user, _serving_capacity())
	var desired_revenue := capacity_limited_rate * delta
	var energy_needed := desired_revenue * energy_per_revenue
	var actual_revenue := desired_revenue
	if energy_needed > energy:
		actual_revenue = energy / energy_per_revenue
		energy = 0.0
	else:
		energy -= energy_needed
	revenue += actual_revenue

	data += users * data_per_user * delta

	var effective_growth_rate := base_growth_rate * permanent_growth_multiplier
	users = min(max_users, users * (1.0 + effective_growth_rate * delta))

	if users >= max_users:
		game_won = true
		_save_game()

	_distribute_segments(true)
	_check_milestones()
	_update_labels()


func _distribute_segments(notify: bool) -> void:
	var remaining := users
	for i in range(segments.size()):
		var segment = segments[i]
		var capacity: float = segment["population"]
		var filled: float = min(remaining, capacity)
		var was_empty: bool = segment["current"] <= 0.0
		segment["current"] = filled
		segment_bars[i].value = filled

		if filled > 0.0 and not segment["notified"]:
			segment["notified"] = true
			if notify and was_empty:
				_show_notification("%s are becoming fans of %s." % [segment["name"], model_name])

		remaining -= filled
		if remaining < 0.0:
			remaining = 0.0


func _check_milestones() -> void:
	while next_milestone_index < milestones.size() and users >= milestones[next_milestone_index]["threshold"]:
		event_label.text = milestones[next_milestone_index]["message"]
		next_milestone_index += 1


func _update_labels() -> void:
	status_label.text = "%s — %s" % [model_name, ("GLOBAL TAKEOVER COMPLETE" if game_won else "active")]
	users_label.text = "Users: %s" % _format_number(floor(users))

	var sustainable_rate: float = energy_regen / energy_per_revenue
	var revenue_rate: float = min(users * revenue_per_user, _serving_capacity(), sustainable_rate)
	revenue_label.text = "Revenue: $%s  (+$%s/s)" % [_format_number(revenue), _format_number(revenue_rate)]

	var data_rate: float = users * data_per_user
	data_label.text = "Data: %s  (+%s/s)" % [_format_number(data), _format_number(data_rate)]

	energy_label.text = "Energy: %d / %d" % [int(energy), int(energy_capacity)]
	capacity_label.text = "Server capacity: %s/s (%d datacenters)" % [_format_number(_serving_capacity()), datacenter_count]
	progress_bar.value = users

	var strength_short := "Model strength: ×%.2f growth" % permanent_growth_multiplier
	strength_label_dashboard.text = strength_short

	var strength_long := strength_short
	if unlocked_capabilities < capabilities.size():
		var next_cap = capabilities[unlocked_capabilities]
		strength_long += "  —  next capability adds ×%.1f, permanently." % next_cap["multiplier"]
	else:
		strength_long += "  —  all capabilities unlocked."
	strength_label_upgrades.text = strength_long

	for i in range(capabilities.size()):
		var cap = capabilities[i]
		var btn: Button = capability_buttons[i]
		if i < unlocked_capabilities:
			btn.text = "%s — Unlocked (×%.1f)" % [cap["name"], cap["multiplier"]]
			btn.disabled = true
		elif i == unlocked_capabilities:
			btn.text = "%s — Unlock for %s data (×%.1f growth, permanent)" % [cap["name"], _format_number(cap["cost"]), cap["multiplier"]]
			btn.disabled = data < cap["cost"]
		else:
			btn.text = "%s — Locked" % cap["name"]
			btn.disabled = true

	datacenter_button.text = "Build datacenter (%d) — costs $%s" % [datacenter_count, _format_number(_datacenter_cost())]
	datacenter_button.disabled = revenue < _datacenter_cost()

	power_button.text = "Build power plant (level %d) — costs $%s" % [power_level, _format_number(_power_cost())]
	power_button.disabled = revenue < _power_cost()

	upgrade_dot.visible = _is_any_upgrade_available()


func _is_any_upgrade_available() -> bool:
	if unlocked_capabilities < capabilities.size():
		var next_cap = capabilities[unlocked_capabilities]
		if data >= next_cap["cost"]:
			return true
	if revenue >= _datacenter_cost():
		return true
	if revenue >= _power_cost():
		return true
	return false


func _format_number(n: float) -> String:
	if n >= 1000000000.0:
		return "%.2fB" % (n / 1000000000.0)
	if n >= 1000000.0:
		return "%.2fM" % (n / 1000000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	return "%d" % int(round(n))


func _start_save_timer() -> void:
	save_timer = Timer.new()
	save_timer.wait_time = 5.0
	save_timer.autostart = true
	save_timer.timeout.connect(_save_game)
	add_child(save_timer)


func _save_game() -> void:
	if not game_started:
		return
	var save_data := {
		"model_name": model_name,
		"users": users,
		"revenue": revenue,
		"data": data,
		"energy": energy,
		"energy_capacity": energy_capacity,
		"energy_regen": energy_regen,
		"datacenter_count": datacenter_count,
		"power_level": power_level,
		"unlocked_capabilities": unlocked_capabilities,
		"game_won": game_won,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
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
	if not parsed.has("revenue"):
		# Save from an older version of the game (pre Revenue/Data split).
		return false

	model_name = parsed.get("model_name", "Unnamed Model")
	users = parsed.get("users", 2.0)
	revenue = parsed.get("revenue", 0.0)
	data = parsed.get("data", 0.0)
	energy = parsed.get("energy", 100.0)
	energy_capacity = parsed.get("energy_capacity", 100.0)
	energy_regen = parsed.get("energy_regen", 5.0)
	datacenter_count = parsed.get("datacenter_count", 0)
	power_level = parsed.get("power_level", 0)
	unlocked_capabilities = parsed.get("unlocked_capabilities", 0)
	game_won = parsed.get("game_won", false)
	return true
