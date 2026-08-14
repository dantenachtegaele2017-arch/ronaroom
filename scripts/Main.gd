extends Control

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

# --- UI refs ---
var name_overlay: Control
var name_edit: LineEdit
var hud: VBoxContainer
var status_label: Label
var users_label: Label
var compute_label: Label
var energy_label: Label
var progress_bar: ProgressBar
var intelligence_button: Button
var datacenter_button: Button
var power_button: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_name_overlay()
	_build_hud()
	hud.visible = false


func _build_name_overlay() -> void:
	name_overlay = Control.new()
	name_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(name_overlay)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(500, 0)
	box.add_theme_constant_override("separation", 16)
	name_overlay.add_child(box)

	var title := Label.new()
	title.text = "Geef je taalmodel een naam"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "bv. Athena-1"
	box.add_child(name_edit)

	var start_button := Button.new()
	start_button.text = "Lanceer"
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)


func _on_start_pressed() -> void:
	var typed := name_edit.text.strip_edges()
	model_name = typed if typed != "" else "Onbenoemd Model"
	name_overlay.visible = false
	hud.visible = true
	game_started = true


func _build_hud() -> void:
	hud = VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_theme_constant_override("separation", 10)
	add_child(hud)

	status_label = Label.new()
	hud.add_child(status_label)

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

	var upgrades_title := Label.new()
	upgrades_title.text = "Upgrades"
	hud.add_child(upgrades_title)

	intelligence_button = Button.new()
	intelligence_button.pressed.connect(_on_train_pressed)
	hud.add_child(intelligence_button)

	datacenter_button = Button.new()
	datacenter_button.pressed.connect(_on_datacenter_pressed)
	hud.add_child(datacenter_button)

	power_button = Button.new()
	power_button.pressed.connect(_on_power_pressed)
	hud.add_child(power_button)


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

	_update_labels()


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
