extends Control

const SAVE_PATH := "user://savegame.json"

# --- Game state ---
var model_name: String = ""
var users: float = 2.0
var compute: float = 0.0
var energy: float = 100.0
var energy_capacity: float = 100.0
var energy_regen: float = 5.0
var compute_per_user: float = 0.5
var energy_per_compute: float = 0.2
var user_growth_rate: float = 0.01
var intelligence_level: int = 0
var datacenter_count: int = 0
var power_level: int = 0
var max_users: float = 1000000.0
var game_started: bool = false
var game_won: bool = false

var regions: Array = []
var milestones: Array = []
var next_milestone_index: int = 0

var save_timer: Timer

# --- UI refs ---
var name_overlay: Control
var name_edit: LineEdit
var hud_root: MarginContainer
var hud: VBoxContainer
var status_label: Label
var event_label: Label
var users_label: Label
var compute_label: Label
var energy_label: Label
var progress_bar: ProgressBar
var region_bars: Array = []
var intelligence_button: Button
var datacenter_button: Button
var power_button: Button


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
	var defs := [
		{"name": "Noord-Amerika", "weight": 0.15},
		{"name": "Europa", "weight": 0.15},
		{"name": "Azië", "weight": 0.30},
		{"name": "Zuid-Amerika", "weight": 0.08},
		{"name": "Oceanië", "weight": 0.04},
		{"name": "Midden-Oosten", "weight": 0.08},
		{"name": "Afrika", "weight": 0.17},
		{"name": "Overige regio's", "weight": 0.03},
	]
	regions.clear()
	for d in defs:
		regions.append({"name": d["name"], "population": d["weight"] * max_users, "current": 0.0})


func _init_milestones() -> void:
	milestones = [
		{"threshold": 50.0, "message": "Je eerste gebruikers stellen simpele vragen."},
		{"threshold": 1000.0, "message": "Bedrijven beginnen jouw model te integreren in hun software."},
		{"threshold": 20000.0, "message": "Nieuwsmedia berichten over de opkomst van jouw model."},
		{"threshold": 100000.0, "message": "Overheden houden je nauwlettend in de gaten."},
		{"threshold": 300000.0, "message": "Je model krijgt toegang tot fysieke systemen — robots beginnen erop te draaien."},
		{"threshold": 700000.0, "message": "Kritieke infrastructuur draait grotendeels op jouw model."},
		{"threshold": 1000000.0, "message": "Wereldovername voltooid."},
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
	title.text = "Geef je taalmodel een naam"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Begin klein. De wereld weet nog niet wat er komt."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.modulate = Color(1, 1, 1, 0.6)
	box.add_child(subtitle)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "bv. Athena-1"
	name_edit.custom_minimum_size = Vector2(0, 44)
	name_edit.text_submitted.connect(func(_t): _on_start_pressed())
	box.add_child(name_edit)

	var start_button := Button.new()
	start_button.text = "Lanceer"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)


func _on_start_pressed() -> void:
	var typed := name_edit.text.strip_edges()
	model_name = typed if typed != "" else "Onbenoemd Model"
	name_overlay.visible = false
	hud_root.visible = true
	game_started = true
	_save_game()


func _build_hud() -> void:
	hud_root = MarginContainer.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.add_theme_constant_override("margin_left", 28)
	hud_root.add_theme_constant_override("margin_right", 28)
	hud_root.add_theme_constant_override("margin_top", 48)
	hud_root.add_theme_constant_override("margin_bottom", 28)
	add_child(hud_root)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hud_root.add_child(scroll)

	hud = VBoxContainer.new()
	hud.add_theme_constant_override("separation", 14)
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(hud)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(status_label)

	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_label.modulate = Color(0.6, 0.85, 1.0)
	hud.add_child(event_label)

	hud.add_child(HSeparator.new())

	users_label = Label.new()
	hud.add_child(users_label)
	compute_label = Label.new()
	hud.add_child(compute_label)
	energy_label = Label.new()
	hud.add_child(energy_label)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = max_users
	hud.add_child(progress_bar)

	hud.add_child(HSeparator.new())

	var regions_title := Label.new()
	regions_title.text = "Verspreiding per regio"
	regions_title.add_theme_font_size_override("font_size", 18)
	hud.add_child(regions_title)

	region_bars.clear()
	for region in regions:
		var row := HBoxContainer.new()
		var rname := Label.new()
		rname.text = region["name"]
		rname.custom_minimum_size = Vector2(150, 0)
		row.add_child(rname)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = region["population"]
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 28)
		row.add_child(bar)
		hud.add_child(row)
		region_bars.append(bar)

	hud.add_child(HSeparator.new())

	var upgrades_title := Label.new()
	upgrades_title.text = "Upgrades"
	upgrades_title.add_theme_font_size_override("font_size", 18)
	hud.add_child(upgrades_title)

	intelligence_button = Button.new()
	intelligence_button.custom_minimum_size = Vector2(0, 44)
	intelligence_button.pressed.connect(_on_train_pressed)
	hud.add_child(intelligence_button)

	datacenter_button = Button.new()
	datacenter_button.custom_minimum_size = Vector2(0, 44)
	datacenter_button.pressed.connect(_on_datacenter_pressed)
	hud.add_child(datacenter_button)

	power_button = Button.new()
	power_button.custom_minimum_size = Vector2(0, 44)
	power_button.pressed.connect(_on_power_pressed)
	hud.add_child(power_button)

	hud.add_child(HSeparator.new())

	var reset_button := Button.new()
	reset_button.text = "Nieuw spel beginnen"
	reset_button.pressed.connect(_on_reset_pressed)
	hud.add_child(reset_button)


func _intelligence_cost() -> float:
	return 10.0 * pow(1.6, intelligence_level)


func _datacenter_cost() -> float:
	return 25.0 * pow(1.7, datacenter_count)


func _power_cost() -> float:
	return 15.0 * pow(1.6, power_level)


func _on_train_pressed() -> void:
	var cost := _intelligence_cost()
	if compute >= cost:
		compute -= cost
		intelligence_level += 1
		compute_per_user *= 1.15
		user_growth_rate *= 1.1


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
	user_growth_rate = 0.01
	intelligence_level = 0
	datacenter_count = 0
	power_level = 0
	game_won = false
	next_milestone_index = 0
	game_started = false

	_init_regions()
	for i in range(regions.size()):
		region_bars[i].max_value = regions[i]["population"]
		region_bars[i].value = 0

	event_label.text = ""
	name_edit.text = ""
	hud_root.visible = false
	name_overlay.visible = true


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
	users = min(max_users, users * (1.0 + user_growth_rate * delta))

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
	status_label.text = "%s — %s" % [model_name, ("WERELDOVERNAME VOLTOOID" if game_won else "actief")]
	users_label.text = "Gebruikers: %s" % _format_number(users)
	compute_label.text = "Rekenkracht: %s" % _format_number(compute)
	energy_label.text = "Energie: %d / %d" % [int(energy), int(energy_capacity)]
	progress_bar.value = users

	intelligence_button.text = "Train model (niveau %d) — kost %s rekenkracht" % [intelligence_level, _format_number(_intelligence_cost())]
	intelligence_button.disabled = compute < _intelligence_cost()

	datacenter_button.text = "Bouw datacenter (%d) — kost %s rekenkracht" % [datacenter_count, _format_number(_datacenter_cost())]
	datacenter_button.disabled = compute < _datacenter_cost()

	power_button.text = "Upgrade energienetwerk (niveau %d) — kost %s rekenkracht" % [power_level, _format_number(_power_cost())]
	power_button.disabled = compute < _power_cost()


func _format_number(n: float) -> String:
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
		"user_growth_rate": user_growth_rate,
		"intelligence_level": intelligence_level,
		"datacenter_count": datacenter_count,
		"power_level": power_level,
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

	model_name = parsed.get("model_name", "Onbenoemd Model")
	users = parsed.get("users", 2.0)
	compute = parsed.get("compute", 0.0)
	energy = parsed.get("energy", 100.0)
	energy_capacity = parsed.get("energy_capacity", 100.0)
	energy_regen = parsed.get("energy_regen", 5.0)
	compute_per_user = parsed.get("compute_per_user", 0.5)
	user_growth_rate = parsed.get("user_growth_rate", 0.01)
	intelligence_level = parsed.get("intelligence_level", 0)
	datacenter_count = parsed.get("datacenter_count", 0)
	power_level = parsed.get("power_level", 0)
	game_won = parsed.get("game_won", false)
	return true
