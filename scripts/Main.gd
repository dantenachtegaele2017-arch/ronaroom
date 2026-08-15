extends Control

const SAVE_PATH := "user://savegame.json"

# The in-game clock: 1 real second = 1 in-game day, starting on the day
# ChatGPT actually launched. Purely a narrative framing (delta is still real
# seconds under the hood) — it just gives "revenue per day" a concrete
# meaning and a date counter to watch tick forward.
const GAME_START_DATE := "2022-11-30T00:00:00"
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"]

const STARTING_USERS := 120.0

# Free baseline capacity/power before buying any infrastructure — "what a
# laptop in your garage can already handle."
const BASE_SERVING_CAPACITY := 0.5
const BASE_ENERGY_REGEN := 2.0
const BASE_ENERGY_CAPACITY := 20.0

const MAX_GROWTH_DOTS := 60

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
# "lat"/"lon" place each segment's glowing dot on the globe visualization.
# These are flavor (a scattered, visually pleasing spread loosely nodding to
# real tech hubs), not a claim about where each segment's users actually are
# — the segments themselves are demographic, not geographic.
const SEGMENT_DATA := [
	{"name": "AI Enthusiasts", "users": 150000000.0, "lat": 37.0, "lon": -122.0},
	{"name": "Developers", "users": 30000000.0, "lat": 13.0, "lon": 77.0},
	{"name": "Students", "users": 250000000.0, "lat": 51.0, "lon": 0.0},
	{"name": "Knowledge Workers", "users": 1000000000.0, "lat": 40.0, "lon": -74.0},
	{"name": "Businesses", "users": 300000000.0, "lat": 35.0, "lon": 139.0},
	{"name": "Everyday Consumers", "users": 2600000000.0, "lat": -23.0, "lon": -46.0},
	{"name": "Governments", "users": 300000000.0, "lat": 50.0, "lon": 4.0},
	{"name": "Skeptics", "users": 750000000.0, "lat": -33.0, "lon": 151.0},
]

# --- Game state ---
# Users give two distinct things: Revenue (they pay to use the model, funds
# infrastructure) and Data (their interactions are training signal, funds
# new capabilities). Revenue is capped by two independently-built resources:
# compute capacity (server tiers) and energy (power tiers). Data collection
# is not capacity-limited. Capabilities are permanent — once trained into
# the model, they stay; they don't fade like a temporary buff.
var model_name: String = ""
var users: float = STARTING_USERS
var revenue: float = 0.0
var data: float = 0.0
var energy: float = BASE_ENERGY_CAPACITY
# $0.02/user/day: at the 120-user start that's ~$2.40/day — a small,
# believable early-stage number for a brand new product.
var revenue_per_user: float = 0.02
var data_per_user: float = 0.6
var energy_per_revenue: float = 2.0
var base_growth_rate: float = 0.006
var permanent_growth_multiplier: float = 1.0
var max_users: float = 0.0
var game_started: bool = false
var game_won: bool = false
var elapsed_days: float = 0.0
var game_start_unix: int = 0

# Realistic infrastructure progression: you start by buying a cheap unit of
# the cheapest tier, and naturally graduate to pricier/more-efficient tiers
# as revenue allows (same pattern as most idle games' multi-building lists).
# Each tier can be bought many times; "count" is mutated at runtime.
var compute_tiers: Array = [
	{"name": "Personal Server", "description": "A spare machine in your garage.", "base_cost": 0.05, "cost_growth": 1.15, "capacity": 0.01, "count": 0},
	{"name": "Server Rack", "description": "A proper rack of rented servers.", "base_cost": 2.0, "cost_growth": 1.17, "capacity": 0.15, "count": 0},
	{"name": "Server Farm", "description": "A warehouse full of racks.", "base_cost": 80.0, "cost_growth": 1.19, "capacity": 2.0, "count": 0},
	{"name": "Small Datacenter", "description": "A dedicated facility, built for scale.", "base_cost": 3000.0, "cost_growth": 1.22, "capacity": 40.0, "count": 0},
	{"name": "Hyperscale Datacenter", "description": "Planet-scale compute.", "base_cost": 150000.0, "cost_growth": 1.25, "capacity": 900.0, "count": 0},
]
var power_tiers: Array = [
	{"name": "Backup Generator", "description": "A noisy diesel generator out back.", "base_cost": 0.04, "cost_growth": 1.15, "energy": 0.05, "count": 0},
	{"name": "Solar Panels", "description": "A few panels on the roof.", "base_cost": 1.5, "cost_growth": 1.17, "energy": 0.6, "count": 0},
	{"name": "Wind Turbines", "description": "A small wind farm under contract.", "base_cost": 60.0, "cost_growth": 1.19, "energy": 8.0, "count": 0},
	{"name": "Small Power Plant", "description": "Dedicated grid capacity, just for you.", "base_cost": 2500.0, "cost_growth": 1.22, "energy": 150.0, "count": 0},
	{"name": "Grid-Scale Power Plant", "description": "Industrial-scale energy production.", "base_cost": 120000.0, "cost_growth": 1.25, "energy": 3500.0, "count": 0},
]

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

var next_dot_threshold: float = 0.0
var dots_spawned: int = 0

var save_timer: Timer

# --- UI refs ---
var name_overlay: Control
var name_edit: LineEdit
var hud_root: MarginContainer
var dashboard_scroll: ScrollContainer
var upgrades_scroll: ScrollContainer
var date_label: Label
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
var compute_tier_buttons: Array = []
var power_tier_buttons: Array = []
var upgrade_dot: Control
var notifications_container: VBoxContainer
var globe_pivot: Node3D
var globe_dots_root: Node3D


func _ready() -> void:
	game_start_unix = Time.get_unix_time_from_datetime_string(GAME_START_DATE)
	_init_segments()
	_init_milestones()
	_build_ui()

	if _load_game():
		game_started = true
		name_overlay.visible = false
		hud_root.visible = true
		_recompute_growth_multiplier()
		_distribute_segments(false)
		_catch_up_growth_dots()
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
		segments.append({
			"name": d["name"],
			"population": d["users"],
			"current": 0.0,
			"notified": false,
			"lat": d["lat"],
			"lon": d["lon"],
		})
		total += d["users"]
	max_users = total


func _init_milestones() -> void:
	milestones = [
		{"threshold": 1000.0, "message": "Your user base passes 1,000 — word is spreading beyond your first testers."},
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
	_reset_growth_dots()
	_show_notification(
		"%s is live — launched with %d beta users." % [model_name, int(STARTING_USERS)],
		"You and a friend just finished training %s, your first language model. It's rough around the edges, but it works — and it's live. You're starting with a small circle of %d beta testers. Every question they ask teaches the model something, and every answer it gives back builds trust. From here, it's about earning enough revenue to expand your infrastructure, and collecting enough data to make %s genuinely capable. Good luck." % [model_name, int(STARTING_USERS), model_name]
	)
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


func _build_globe_card(panel: VBoxContainer) -> void:
	var globe_card := _new_card(panel)
	_section_title("Global reach", globe_card)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(260, 260)
	viewport_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	viewport_container.stretch = true
	globe_card.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(260, 260)
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)

	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 3.0)
	camera.current = true
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 1.1

	globe_pivot = Node3D.new()
	viewport.add_child(globe_pivot)

	var sphere := MeshInstance3D.new()
	globe_pivot.add_child(sphere)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	sphere.mesh = sphere_mesh
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_texture = _generate_globe_texture()
	sphere_mat.metallic = 0.15
	sphere_mat.roughness = 0.55
	sphere_mat.rim_enabled = true
	sphere_mat.rim = 0.5
	sphere_mat.rim_tint = 0.8
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(0.1, 0.3, 0.6)
	sphere_mat.emission_energy_multiplier = 0.06
	sphere.material_override = sphere_mat

	globe_dots_root = Node3D.new()
	globe_pivot.add_child(globe_dots_root)


func _generate_globe_texture() -> ImageTexture:
	# Procedurally painted continents (stylized approximations, not accurate
	# coastlines — we have no map asset to draw from) on an equirectangular
	# image, so the sphere reads as "a globe" rather than a flat colored ball.
	var width := 480
	var height := 240
	var ocean := Color(0.04, 0.14, 0.32)
	var land := Color(0.14, 0.32, 0.18)
	var blobs := [
		{"lat": 15.0, "lon": 15.0, "r_lat": 38.0, "r_lon": 22.0},   # Africa
		{"lat": 50.0, "lon": 15.0, "r_lat": 18.0, "r_lon": 25.0},   # Europe
		{"lat": 45.0, "lon": 90.0, "r_lat": 28.0, "r_lon": 48.0},   # Asia
		{"lat": 8.0, "lon": 105.0, "r_lat": 15.0, "r_lon": 15.0},   # SE Asia
		{"lat": 48.0, "lon": -100.0, "r_lat": 22.0, "r_lon": 28.0}, # North America
		{"lat": -15.0, "lon": -60.0, "r_lat": 25.0, "r_lon": 18.0}, # South America
		{"lat": -25.0, "lon": 135.0, "r_lat": 13.0, "r_lon": 17.0}, # Australia
	]

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		var lat: float = 90.0 - (float(y) / float(height)) * 180.0
		for x in range(width):
			var lon: float = (float(x) / float(width)) * 360.0 - 180.0
			var land_factor := 0.0
			for blob in blobs:
				var dx: float = (lon - blob["lon"]) / blob["r_lon"]
				var dy: float = (lat - blob["lat"]) / blob["r_lat"]
				var dist: float = sqrt(dx * dx + dy * dy)
				var factor: float = clamp((1.0 - dist) * 3.0, 0.0, 1.0)
				land_factor = max(land_factor, factor)
			image.set_pixel(x, y, ocean.lerp(land, land_factor))

	return ImageTexture.create_from_image(image)


func _lat_lon_to_vec3(lat_deg: float, lon_deg: float, r: float) -> Vector3:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	var x := r * cos(lat) * cos(lon)
	var y := r * sin(lat)
	var z := r * cos(lat) * sin(lon)
	return Vector3(x, y, z)


func _spawn_globe_dot(lat: float, lon: float) -> void:
	if globe_dots_root == null:
		return
	var dot := MeshInstance3D.new()
	globe_dots_root.add_child(dot)
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	dot.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	dot.material_override = mat
	dot.position = _lat_lon_to_vec3(lat, lon, 1.03)


func _reset_growth_dots() -> void:
	next_dot_threshold = STARTING_USERS * 1.5
	dots_spawned = 0


func _catch_up_growth_dots() -> void:
	# After loading a save, spawn however many growth dots "should" already
	# exist for the current user count, without spamming one-per-frame.
	while dots_spawned < MAX_GROWTH_DOTS and users >= next_dot_threshold:
		_spawn_growth_dot()


func _check_growth_dots() -> void:
	if dots_spawned >= MAX_GROWTH_DOTS:
		return
	if users >= next_dot_threshold:
		_spawn_growth_dot()


func _spawn_growth_dot() -> void:
	var lat := randf_range(-60.0, 75.0)
	var lon := randf_range(-180.0, 180.0)
	_spawn_globe_dot(lat, lon)
	dots_spawned += 1
	next_dot_threshold *= 1.6


func _build_dashboard_tab(shell: VBoxContainer) -> void:
	dashboard_scroll = ScrollContainer.new()
	dashboard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dashboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(dashboard_scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dashboard_scroll.add_child(panel)

	date_label = Label.new()
	date_label.modulate = Color(1, 1, 1, 0.6)
	date_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(date_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(status_label)

	event_label = Label.new()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	event_label.modulate = Color(0.6, 0.85, 1.0)
	panel.add_child(event_label)

	_build_globe_card(panel)

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


func _build_tier_row(parent: Control, tier: Dictionary, index: int, callback: Callable) -> Button:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(callback.bind(index))
	row.add_child(btn)

	var desc := Label.new()
	desc.text = tier["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.modulate = Color(1, 1, 1, 0.55)
	desc.add_theme_font_size_override("font_size", 13)
	row.add_child(desc)

	parent.add_child(row)
	return btn


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

	var compute_card := _new_card(panel)
	_section_title("Compute — funded by Revenue", compute_card)
	var compute_hint := Label.new()
	compute_hint.text = "Server hardware. Raises how many users you can serve at once."
	compute_hint.modulate = Color(1, 1, 1, 0.55)
	compute_hint.add_theme_font_size_override("font_size", 13)
	compute_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	compute_card.add_child(compute_hint)
	compute_card.add_child(HSeparator.new())

	compute_tier_buttons.clear()
	for i in range(compute_tiers.size()):
		var btn := _build_tier_row(compute_card, compute_tiers[i], i, _on_buy_compute_tier)
		compute_tier_buttons.append(btn)

	var power_card := _new_card(panel)
	_section_title("Power — funded by Revenue", power_card)
	var power_hint := Label.new()
	power_hint.text = "Energy source. Keeps your compute infrastructure running."
	power_hint.modulate = Color(1, 1, 1, 0.55)
	power_hint.add_theme_font_size_override("font_size", 13)
	power_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	power_card.add_child(power_hint)
	power_card.add_child(HSeparator.new())

	power_tier_buttons.clear()
	for i in range(power_tiers.size()):
		var btn := _build_tier_row(power_card, power_tiers[i], i, _on_buy_power_tier)
		power_tier_buttons.append(btn)


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


func _show_notification(headline: String, body: String = "") -> void:
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

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)

	var headline_label := Label.new()
	headline_label.text = "📰 " + headline
	headline_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	headline_label.custom_minimum_size = Vector2(260, 0)
	content.add_child(headline_label)

	if body != "":
		var body_label := Label.new()
		body_label.text = body
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		body_label.modulate = Color(1, 1, 1, 0.75)
		body_label.add_theme_font_size_override("font_size", 13)
		body_label.visible = false
		content.add_child(body_label)

		var toggle_button := Button.new()
		toggle_button.text = "Read more"
		toggle_button.flat = true
		toggle_button.pressed.connect(func():
			body_label.visible = not body_label.visible
			toggle_button.text = "Show less" if body_label.visible else "Read more"
		)
		content.add_child(toggle_button)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(28, 28)
	close_button.pressed.connect(func(): card.queue_free())
	row.add_child(close_button)

	notifications_container.add_child(card)

	# Short toasts auto-fade; announcements with more to read stay until closed.
	if body == "":
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


func _tier_cost(tier: Dictionary) -> float:
	return tier["base_cost"] * pow(tier["cost_growth"], tier["count"])


func _serving_capacity() -> float:
	var total := BASE_SERVING_CAPACITY
	for tier in compute_tiers:
		total += tier["count"] * tier["capacity"]
	return total


func _energy_regen() -> float:
	var total := BASE_ENERGY_REGEN
	for tier in power_tiers:
		total += tier["count"] * tier["energy"]
	return total


func _energy_capacity() -> float:
	var total := BASE_ENERGY_CAPACITY
	for tier in power_tiers:
		total += tier["count"] * tier["energy"] * 4.0
	return total


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


func _on_buy_compute_tier(index: int) -> void:
	var tier = compute_tiers[index]
	var cost := _tier_cost(tier)
	if revenue >= cost:
		revenue -= cost
		tier["count"] += 1
		_save_game()


func _on_buy_power_tier(index: int) -> void:
	var tier = power_tiers[index]
	var cost := _tier_cost(tier)
	if revenue >= cost:
		revenue -= cost
		tier["count"] += 1
		_save_game()


func _on_reset_pressed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	model_name = ""
	users = STARTING_USERS
	revenue = 0.0
	data = 0.0
	energy = BASE_ENERGY_CAPACITY
	permanent_growth_multiplier = 1.0
	unlocked_capabilities = 0
	game_won = false
	next_milestone_index = 0
	game_started = false
	elapsed_days = 0.0

	for tier in compute_tiers:
		tier["count"] = 0
	for tier in power_tiers:
		tier["count"] = 0

	_init_segments()
	_init_milestones()
	for i in range(segments.size()):
		segment_bars[i].max_value = segments[i]["population"]
		segment_bars[i].value = 0

	_reset_growth_dots()

	for child in notifications_container.get_children():
		child.queue_free()

	if globe_dots_root != null:
		for child in globe_dots_root.get_children():
			child.queue_free()

	event_label.text = ""
	name_edit.text = ""
	hud_root.visible = false
	name_overlay.visible = true
	_show_dashboard_tab()


func _process(delta: float) -> void:
	if globe_pivot != null:
		globe_pivot.rotate_y(delta * 0.35)

	if not game_started or game_won:
		return

	elapsed_days += delta

	var cap_energy := _energy_capacity()
	energy = min(cap_energy, energy + _energy_regen() * delta)

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

	_check_growth_dots()
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
			_spawn_globe_dot(segment["lat"], segment["lon"])
			if notify and was_empty:
				_show_notification("%s are becoming fans of %s." % [segment["name"], model_name])

		remaining -= filled
		if remaining < 0.0:
			remaining = 0.0


func _check_milestones() -> void:
	while next_milestone_index < milestones.size() and users >= milestones[next_milestone_index]["threshold"]:
		event_label.text = milestones[next_milestone_index]["message"]
		next_milestone_index += 1


func _current_date_string() -> String:
	var unix := game_start_unix + int(elapsed_days) * 86400
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%s %d, %d" % [MONTH_NAMES[d["month"] - 1], d["day"], d["year"]]


func _update_labels() -> void:
	date_label.text = _current_date_string()
	status_label.text = "%s — %s" % [model_name, ("GLOBAL TAKEOVER COMPLETE" if game_won else "active")]
	users_label.text = "Users: %s" % _format_number(floor(users))

	var sustainable_rate: float = _energy_regen() / energy_per_revenue
	var revenue_rate: float = min(users * revenue_per_user, _serving_capacity(), sustainable_rate)
	revenue_label.text = "Revenue: $%s  (+$%s/day)" % [_format_number(revenue), _format_number(revenue_rate)]

	var data_rate: float = users * data_per_user
	data_label.text = "Data: %s  (+%s/day)" % [_format_number(data), _format_number(data_rate)]

	energy_label.text = "Energy: %d / %d" % [int(energy), int(_energy_capacity())]
	capacity_label.text = "Server capacity: %s/day" % _format_number(_serving_capacity())
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

	for i in range(compute_tiers.size()):
		var tier = compute_tiers[i]
		var btn: Button = compute_tier_buttons[i]
		var cost := _tier_cost(tier)
		btn.text = "%s — owned %d — $%s (+%s/day capacity)" % [tier["name"], tier["count"], _format_number(cost), _format_number(tier["capacity"])]
		btn.disabled = revenue < cost

	for i in range(power_tiers.size()):
		var tier = power_tiers[i]
		var btn: Button = power_tier_buttons[i]
		var cost := _tier_cost(tier)
		btn.text = "%s — owned %d — $%s (+%s energy/day)" % [tier["name"], tier["count"], _format_number(cost), _format_number(tier["energy"])]
		btn.disabled = revenue < cost

	upgrade_dot.visible = _is_any_upgrade_available()


func _is_any_upgrade_available() -> bool:
	if unlocked_capabilities < capabilities.size():
		var next_cap = capabilities[unlocked_capabilities]
		if data >= next_cap["cost"]:
			return true
	for tier in compute_tiers:
		if revenue >= _tier_cost(tier):
			return true
	for tier in power_tiers:
		if revenue >= _tier_cost(tier):
			return true
	return false


func _format_number(n: float) -> String:
	if n >= 1000000000.0:
		return "%.2fB" % (n / 1000000000.0)
	if n >= 1000000.0:
		return "%.2fM" % (n / 1000000.0)
	if n >= 1000.0:
		return "%.1fK" % (n / 1000.0)
	if n == floor(n):
		return "%d" % int(n)
	if n >= 1.0:
		return "%.2f" % n
	return "%.3f" % n


func _start_save_timer() -> void:
	save_timer = Timer.new()
	save_timer.wait_time = 5.0
	save_timer.autostart = true
	save_timer.timeout.connect(_save_game)
	add_child(save_timer)


func _save_game() -> void:
	if not game_started:
		return
	var compute_counts: Array = []
	for tier in compute_tiers:
		compute_counts.append(tier["count"])
	var power_counts: Array = []
	for tier in power_tiers:
		power_counts.append(tier["count"])

	var save_data := {
		"model_name": model_name,
		"users": users,
		"revenue": revenue,
		"data": data,
		"energy": energy,
		"compute_tier_counts": compute_counts,
		"power_tier_counts": power_counts,
		"unlocked_capabilities": unlocked_capabilities,
		"game_won": game_won,
		"elapsed_days": elapsed_days,
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
	if not parsed.has("compute_tier_counts"):
		# Save from an older version of the game (pre tiered infrastructure).
		return false

	model_name = parsed.get("model_name", "Unnamed Model")
	users = parsed.get("users", STARTING_USERS)
	revenue = parsed.get("revenue", 0.0)
	data = parsed.get("data", 0.0)
	energy = parsed.get("energy", BASE_ENERGY_CAPACITY)
	unlocked_capabilities = parsed.get("unlocked_capabilities", 0)
	game_won = parsed.get("game_won", false)
	elapsed_days = parsed.get("elapsed_days", 0.0)

	var compute_counts: Array = parsed.get("compute_tier_counts", [])
	for i in range(min(compute_counts.size(), compute_tiers.size())):
		compute_tiers[i]["count"] = int(compute_counts[i])

	var power_counts: Array = parsed.get("power_tier_counts", [])
	for i in range(min(power_counts.size(), power_tiers.size())):
		power_tiers[i]["count"] = int(power_counts[i])

	_reset_growth_dots()
	return true
