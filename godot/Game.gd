extends Node2D
## GUNFALL — платформер-рогалик для Godot 4.6.
## Вся игра в одном code-driven Node2D: логика в sim_step(), отрисовка в _draw().
## Каждый забег — новая процедурная карта, огнестрел, враги, улучшения, перма-смерть.

# ============================== Константы ==============================

const TILE := 32
const VW := 960
const VH := 540
const GRAV := 0.55
const MAX_FALL := 15.0

# Типы тайлов
const T_EMPTY := 0
const T_SOLID := 1
const T_PLAT := 2
const T_SPIKE := 3
const T_EXIT := 4

const THEMES := [
	{ "name": "Изумрудные пещеры", "sky0": "#0e1830", "sky1": "#1d3250", "hill_far": "#15233c", "hill_near": "#1b2c4a",
	  "ground": "#2c3a55", "top": "#58c98f", "plat": "#7fdcae", "spike": "#bcd0ff" },
	{ "name": "Багровые руины", "sky0": "#180d1c", "sky1": "#3a1c33", "hill_far": "#241229", "hill_near": "#301a37",
	  "ground": "#3d2438", "top": "#e0707a", "plat": "#f29a8e", "spike": "#ffd3c0" },
	{ "name": "Ледяные шахты", "sky0": "#0b1426", "sky1": "#1d3a55", "hill_far": "#142339", "hill_near": "#1b2f4a",
	  "ground": "#31415f", "top": "#8fd8f2", "plat": "#b5e8fa", "spike": "#e8f6ff" },
	{ "name": "Токсичные топи", "sky0": "#0d1612", "sky1": "#1d3328", "hill_far": "#13241b", "hill_near": "#1a3124",
	  "ground": "#2b3d31", "top": "#a8d65c", "plat": "#c6ec85", "spike": "#e9ffc9" },
	{ "name": "Пустынный форт", "sky0": "#1a1208", "sky1": "#3d2c14", "hill_far": "#291e0e", "hill_near": "#352813",
	  "ground": "#4a3a20", "top": "#e6b566", "plat": "#f4ce8d", "spike": "#ffe9c2" },
]

const WEAPONS := {
	"pistol":  { "name": "Пистолет", "dmg": 12, "cd": 16, "spd": 12.0, "spread": 0.035, "pellets": 1, "auto": false, "ammo": INF, "color": "#ffd86b", "kick": 1.2, "len": 15 },
	"smg":     { "name": "ПП «Оса»", "dmg": 8, "cd": 6, "spd": 13.0, "spread": 0.10, "pellets": 1, "auto": true, "ammo": 150, "color": "#9be8ff", "kick": 1.6, "len": 17 },
	"shotgun": { "name": "Дробовик", "dmg": 9, "cd": 44, "spd": 11.0, "spread": 0.24, "pellets": 6, "auto": false, "ammo": 32, "color": "#ffb077", "kick": 5.0, "len": 19 },
	"rifle":   { "name": "Винтовка", "dmg": 36, "cd": 34, "spd": 18.0, "spread": 0.012, "pellets": 1, "auto": false, "ammo": 30, "color": "#d3a4ff", "kick": 3.2, "len": 23 },
}
const WEAPON_DROPS := ["smg", "shotgun", "rifle"]

const UPGRADES := [
	{ "id": "hp", "icon": "♥", "name": "Живучесть", "desc": "+25 к максимуму здоровья и лечение на 25" },
	{ "id": "dmg", "icon": "✦", "name": "Крупный калибр", "desc": "+15% к урону всего оружия" },
	{ "id": "rate", "icon": "≈", "name": "Скорострельность", "desc": "Оружие стреляет на 12% быстрее" },
	{ "id": "speed", "icon": "»", "name": "Лёгкие ботинки", "desc": "+10% к скорости бега" },
	{ "id": "djump", "icon": "⇈", "name": "Двойной прыжок", "desc": "Дополнительный прыжок в воздухе", "unique": true },
	{ "id": "steal", "icon": "+", "name": "Вампиризм", "desc": "+3 здоровья за каждое убийство" },
	{ "id": "armor", "icon": "▣", "name": "Бронежилет", "desc": "Получаемый урон снижен на 15%" },
	{ "id": "crit", "icon": "◎", "name": "Крит. патроны", "desc": "+10% шанс двойного урона" },
	{ "id": "jump", "icon": "↑", "name": "Пружины", "desc": "+8% к высоте прыжка" },
]

const ENEMY_BASE := {
	"walker":  { "w": 26, "h": 28, "hp": 30, "spd": 1.1, "dmg": 12, "score": 10, "cd": 0, "fly": false },
	"shooter": { "w": 26, "h": 30, "hp": 42, "spd": 0.0, "dmg": 9, "score": 20, "cd": 105, "fly": false },
	"flyer":   { "w": 24, "h": 20, "hp": 22, "spd": 1.7, "dmg": 10, "score": 15, "cd": 0, "fly": true },
	"tank":    { "w": 36, "h": 38, "hp": 130, "spd": 0.55, "dmg": 11, "score": 45, "cd": 135, "fly": false },
}

# ============================== Состояние ==============================

var state := "menu"  # menu | play | pause | upgrade | dead
var lvl := 1
var score := 0
var kills := 0
var run_seed := 0
var seed_label := ""
var tick := 0
var shake := 0.0
var cam := Vector2.ZERO
var intro := 0
var intro_text := ""
var low_ammo_t := 0
var offer := []
var best := 0

var level := {}        # текущая карта
var P := {}            # игрок
var enemies := []
var bullets := []
var parts := []
var pickups := []
var texts := []

# Фон (кэш на уровень)
var th := {}           # цвета темы (Color)
var stars := []        # [Vector3(x,y,size_alpha)]
var hill_far := PackedVector2Array()
var hill_near := PackedVector2Array()
var sky0 := Color.BLACK
var sky1 := Color.BLACK

# Ввод текущего кадра (заполняется gather_input или тестом)
var input := {
	"move": 0, "down": false, "jump_pressed": false, "jump_held": false,
	"shoot_held": false, "shoot_clicked": false, "aim": Vector2.ZERO,
	"switch_to": -1, "wheel": 0,
}
var _prev_keys := {}
var _prev_mouse := false

# Прицел/направление (для отрисовки)
var aim_angle := 0.0

# Тест/служебное
var test_mode := false
var demo := false
var demo_frame := 0
var _want_shot := false
var audio_enabled := true
var font: Font = null
var rng := RandomNumberGenerator.new()      # глобальный (эффекты)

# Прямоугольники кнопок UI (для кликов)
var _ui_rects := {}

# Аудио
var _audio_players := []
var _audio_idx := 0
var _sfx_cache := {}

# ============================== Жизненный цикл ==============================

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	best = _load_best()
	if not test_mode and DisplayServer.get_name() != "headless":
		_setup_audio()
	else:
		audio_enabled = false
	set_process_unhandled_input(true)
	if "--demo" in OS.get_cmdline_args():
		demo = true
		audio_enabled = false
		RenderingServer.frame_post_draw.connect(_on_post_draw)
		start_run(12345, "DEMO")
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if test_mode:
		return
	if demo:
		_demo_step()
		return
	gather_input()
	sim_step()
	queue_redraw()

func _demo_step() -> void:
	# Самоиграющий бот для скриншотов/проверки отрисовки.
	if state == "play":
		input.move = 1
		input.jump_pressed = (demo_frame % 26 == 0)
		input.jump_held = true
		input.down = false
		# целимся в ближайшего врага, иначе вперёд
		var aim := Vector2(P.x + 200, P.y + 10)
		var bestd := 1e9
		for en in enemies:
			var d: float = Vector2(en.x - P.x, en.y - P.y).length()
			if d < bestd:
				bestd = d
				aim = Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
		input.aim = aim
		input.shoot_held = true
		input.shoot_clicked = (demo_frame % 6 == 0)
		input.switch_to = -1
	sim_step()
	if state == "upgrade":
		choose_upgrade(offer[0])
	if state == "dead":
		start_run(12345 + demo_frame, "DEMO")
	queue_redraw()
	demo_frame += 1
	if demo_frame in [90, 150, 210]:
		_want_shot = true
	if demo_frame > 240:
		get_tree().quit()

func _on_post_draw() -> void:
	if not _want_shot:
		return
	_want_shot = false
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/gunfall_demo_%d.png" % demo_frame)

# ============================== Ввод (реальный) ==============================

func gather_input() -> void:
	var k_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var k_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var k_down := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var jump_now := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
	var shoot_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	input.move = (1 if k_right else 0) - (1 if k_left else 0)
	input.down = k_down
	input.jump_held = jump_now
	input.jump_pressed = jump_now and not _prev_keys.get("jump", false)
	input.shoot_held = shoot_now
	input.shoot_clicked = shoot_now and not _prev_mouse
	input.aim = get_local_mouse_position() + cam
	input.switch_to = -1
	for i in range(4):
		if Input.is_key_pressed(KEY_1 + i) and not _prev_keys.get("d%d" % i, false):
			input.switch_to = i

	_prev_keys["jump"] = jump_now
	for i in range(4):
		_prev_keys["d%d" % i] = Input.is_key_pressed(KEY_1 + i)
	_prev_mouse = shoot_now

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				if state == "play": _set_state("pause")
				elif state == "pause": _set_state("play")
			KEY_M:
				audio_enabled = not audio_enabled
			KEY_ENTER, KEY_KP_ENTER:
				if state == "menu": start_from_menu()
				elif state == "dead": start_from_menu()
				elif state == "pause": _set_state("play")
			KEY_SPACE:
				if state == "menu": start_from_menu()
			KEY_R:
				if state == "menu": start_from_menu()
			KEY_1, KEY_2, KEY_3:
				if state == "upgrade":
					var i: int = event.keycode - KEY_1
					if i < offer.size():
						choose_upgrade(offer[i])
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_ui_click(get_local_mouse_position())
	elif event is InputEventMouseButton and event.pressed and state == "play":
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)

func _handle_ui_click(m: Vector2) -> void:
	for key in _ui_rects.keys():
		var r: Rect2 = _ui_rects[key]
		if r.has_point(m):
			_on_ui(key)
			return

func _on_ui(key: String) -> void:
	match key:
		"play": start_from_menu()
		"retry": start_from_menu()
		"menu": _set_state("menu")
		"resume": _set_state("play")
		"quit": _set_state("menu")
		_:
			if key.begins_with("card"):
				var i := int(key.substr(4))
				if i < offer.size():
					choose_upgrade(offer[i])

func _cycle_weapon(d: int) -> void:
	if state != "play" or P.weapons.size() < 2:
		return
	switch_weapon((P.wi + d + P.weapons.size()) % P.weapons.size())

# ============================== Утилиты ==============================

func _rr(r: RandomNumberGenerator, a: int, b: int) -> int:
	return r.randi_range(a, b)

func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

func _col(hex: String) -> Color:
	return Color(hex)

func _hash_seed(s: String) -> int:
	var h := 2166136261
	for i in range(s.length()):
		h ^= s.unicode_at(i)
		h = (h * 16777619) & 0xFFFFFFFF
	return h & 0xFFFFFFFF

# Безопасный доступ к ячейке строящейся сетки
func _cell(grid: PackedByteArray, W: int, H: int, tx: int, ty: int) -> int:
	if tx < 0 or tx >= W:
		return T_SOLID
	if ty >= H:
		return T_SOLID
	if ty < 0:
		return T_EMPTY
	return grid[ty * W + tx]

func _setc(grid: PackedByteArray, W: int, H: int, tx: int, ty: int, t: int) -> void:
	if tx >= 0 and tx < W and ty >= 0 and ty < H:
		grid[ty * W + tx] = t

# ============================== Генерация уровня ==============================

func generate_level(seed_val: int, level_num: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var W: int = clampi(130 + level_num * 12, 130, 260)
	var H := 36
	var grid := PackedByteArray()
	grid.resize(W * H)
	var ground_y := []
	ground_y.resize(W)

	# --- рельеф: блуждание высоты, шаг не больше 1 тайла ---
	var h := 26
	var min_h := 13
	var max_h := 31
	for x in range(8):
		ground_y[x] = h
	var spike_cols := {}
	var x := 8
	var last_pit_end := -99

	while x < W - 10:
		var rv := r.randf()
		if rv < 0.16 and x - last_pit_end > 7 and h + 3 < max_h:
			var pw := _rr(r, 2, 4)
			var depth := _rr(r, 2, 3)
			var i := 0
			while i < pw and x < W - 10:
				ground_y[x] = h + depth
				spike_cols[x] = true
				i += 1
				x += 1
			last_pit_end = x
			continue
		if rv < 0.55:
			h = clampi(h + _pick(r, [-1, -1, 0, 1, 1]), min_h, max_h)
		ground_y[x] = h
		x += 1
	while x < W:
		ground_y[x] = h
		x += 1

	# одиночные шипы на ровных участках
	for sx in range(14, W - 14):
		if r.randf() < 0.018 and not spike_cols.has(sx) and not spike_cols.has(sx - 1) and not spike_cols.has(sx + 1) \
				and ground_y[sx] == ground_y[sx - 1] and ground_y[sx] == ground_y[sx + 1]:
			spike_cols[sx] = true

	# заливка земли и шипов
	for tx in range(W):
		for ty in range(ground_y[tx], H):
			grid[ty * W + tx] = T_SOLID
		if spike_cols.has(tx):
			_setc(grid, W, H, tx, ground_y[tx] - 1, T_SPIKE)

	# --- односторонние платформы ---
	var platforms := []
	var plat_cells := []
	var plat_tries := 14 + level_num * 3
	for _i in range(plat_tries):
		var ln := _rr(r, 3, 6)
		var x0 := _rr(r, 10, W - 14 - ln)
		var base := H
		for j in range(ln):
			base = min(base, ground_y[x0 + j])
		var py := base - _rr(r, 3, 4)
		if py < 6:
			continue
		var ok := true
		for j in range(ln):
			if _cell(grid, W, H, x0 + j, py) != T_EMPTY or _cell(grid, W, H, x0 + j, py - 1) != T_EMPTY or _cell(grid, W, H, x0 + j, py + 1) != T_EMPTY:
				ok = false
				break
		if not ok:
			continue
		for j in range(ln):
			_setc(grid, W, H, x0 + j, py, T_PLAT)
			plat_cells.append(Vector2i(x0 + j, py))
		platforms.append({ "x0": x0, "len": ln, "y": py })

	# второй ярус
	var tier2 := int(platforms.size() / 2.0)
	for _i in range(tier2):
		if platforms.is_empty():
			break
		var p: Dictionary = _pick(r, platforms)
		var ln := _rr(r, 3, 5)
		var x0: int = clampi(p.x0 + _rr(r, -2, 2), 8, W - 12 - ln)
		var py: int = p.y - 3
		if py < 5:
			continue
		var ok := true
		for j in range(ln):
			if _cell(grid, W, H, x0 + j, py) != T_EMPTY or _cell(grid, W, H, x0 + j, py - 1) != T_EMPTY or _cell(grid, W, H, x0 + j, py + 1) != T_EMPTY:
				ok = false
				break
		if not ok:
			continue
		for j in range(ln):
			_setc(grid, W, H, x0 + j, py, T_PLAT)
			plat_cells.append(Vector2i(x0 + j, py))

	# --- выход ---
	var ex := W - 5
	var egy: int = ground_y[ex]
	_setc(grid, W, H, ex, egy - 1, T_EXIT)
	_setc(grid, W, H, ex, egy - 2, T_EXIT)
	var exit_px := Vector2((ex + 0.5) * TILE, (egy - 1) * TILE)

	# --- враги ---
	var hp_mul := 1.0 + 0.25 * (level_num - 1)
	var dmg_add := 2 * (level_num - 1)
	var enemy_list := []
	var used_x := []

	var ground_spot := func(span: int) -> int:
		for _t in range(60):
			var sx := _rr(r, 14, W - 12 - span)
			var ok := true
			for j in range(span):
				if spike_cols.has(sx + j) or ground_y[sx + j] != ground_y[sx]:
					ok = false
					break
			if not ok:
				continue
			var clash := false
			for u in used_x:
				if abs(u - sx) < 3:
					clash = true
					break
			if clash:
				continue
			used_x.append(sx)
			return sx
		return -1

	var add_enemy := func(type: String, sx: float, sy: float) -> void:
		var b: Dictionary = ENEMY_BASE[type]
		enemy_list.append({
			"type": type, "x": sx, "y": sy, "w": b.w, "h": b.h,
			"hp": roundi(b.hp * hp_mul), "maxhp": roundi(b.hp * hp_mul),
			"vx": 0.0, "vy": 0.0, "dir": (-1 if r.randf() < 0.5 else 1),
			"spd": b.spd, "dmg": b.dmg + dmg_add, "score": b.score,
			"fly": b.fly, "cd": (_rr(r, 30, b.cd) if b.cd > 0 else 0), "cd_max": b.cd,
			"hurt_t": 0, "phase": r.randf() * TAU,
			"on_ground": false, "hit_wall": false, "drop": 0, "dead": false,
		})

	var counts := {
		"walker": mini(4 + level_num, 12),
		"shooter": mini(1 + int(level_num * 0.8), 8),
		"flyer": (mini(1 + level_num, 9) if level_num >= 2 else 0),
		"tank": (mini(level_num - 2, 5) if level_num >= 3 else 0),
	}
	for type in counts.keys():
		for _i in range(counts[type]):
			if ENEMY_BASE[type].fly:
				var placed := false
				for _t in range(20):
					if placed:
						break
					var sx := _rr(r, 16, W - 12)
					var sty: int = maxi(2, ground_y[sx] - _rr(r, 4, 8))
					if _cell(grid, W, H, sx, sty) == T_EMPTY and _cell(grid, W, H, sx + 1, sty) == T_EMPTY \
							and _cell(grid, W, H, sx, sty + 1) == T_EMPTY and _cell(grid, W, H, sx + 1, sty + 1) == T_EMPTY:
						add_enemy.call(type, sx * TILE + 4, sty * TILE + 4)
						placed = true
			else:
				var b: Dictionary = ENEMY_BASE[type]
				var span := int(ceil((b.w + 8) / float(TILE)))
				var sx: int = ground_spot.call(span)
				if sx < 0:
					continue
				add_enemy.call(type, sx * TILE + (span * TILE - b.w) / 2.0, ground_y[sx] * TILE - b.h - 1)

	# --- подбираемое ---
	var pickup_list := []
	var spot := func() -> Variant:
		if not plat_cells.is_empty() and r.randf() < 0.6:
			var c: Vector2i = _pick(r, plat_cells)
			return Vector2(c.x * TILE + 5, c.y * TILE - 20)
		var sx: int = ground_spot.call(1)
		if sx < 0:
			return null
		return Vector2(sx * TILE + 5, ground_y[sx] * TILE - 20)

	var add_pick := func(kind: String, pos: Vector2, extra: Dictionary) -> void:
		var d := { "kind": kind, "x": pos.x, "y": pos.y, "w": 22, "h": 18, "vy": 0.0, "t": r.randf() * 6.0 }
		d.merge(extra)
		pickup_list.append(d)

	var n_weapons := (2 if level_num == 1 else _rr(r, 1, 2))
	for _i in range(n_weapons):
		var s = spot.call()
		if s != null:
			add_pick.call("weapon", s, { "weapon": _pick(r, WEAPON_DROPS) })
	for _i in range(_rr(r, 1, 2)):
		var s = spot.call()
		if s != null:
			add_pick.call("med", s, { "heal": 30 })
	for _i in range(_rr(r, 2, 3)):
		var s = spot.call()
		if s != null:
			add_pick.call("ammo", s, {})

	return {
		"W": W, "H": H, "grid": grid, "ground_y": ground_y,
		"theme": THEMES[(level_num - 1) % THEMES.size()],
		"px_w": W * TILE, "px_h": H * TILE,
		"spawn": Vector2(2 * TILE + 6, ground_y[2] * TILE - 31),
		"exit_px": exit_px, "enemies": enemy_list, "pickups": pickup_list,
	}

# ============================== Доступ к карте (рантайм) ==============================

func tile_at(tx: int, ty: int) -> int:
	if level.is_empty():
		return T_EMPTY
	if tx < 0 or tx >= level.W:
		return T_SOLID
	if ty >= level.H:
		return T_SOLID
	if ty < 0:
		return T_EMPTY
	return level.grid[ty * level.W + tx]

func solid_px(px: float, py: float) -> bool:
	return tile_at(int(floor(px / TILE)), int(floor(py / TILE))) == T_SOLID

func line_of_sight(x0: float, y0: float, x1: float, y1: float) -> bool:
	var d := Vector2(x1 - x0, y1 - y0).length()
	var n := maxi(1, int(ceil(d / 12.0)))
	for i in range(1, n):
		var t := float(i) / n
		if solid_px(lerp(x0, x1, t), lerp(y0, y1, t)):
			return false
	return true

# ============================== Физика ==============================

func collide_entity(e: Dictionary) -> void:
	var prev_bottom: float = e.y + e.h
	e.hit_wall = false
	e.on_ground = false

	# по X
	e.x += e.vx
	var y0 := int(floor(e.y / TILE))
	var y1 := int(floor((e.y + e.h - 0.01) / TILE))
	if e.vx > 0:
		var tx := int(floor((e.x + e.w - 0.01) / TILE))
		for ty in range(y0, y1 + 1):
			if tile_at(tx, ty) == T_SOLID:
				e.x = tx * TILE - e.w
				e.vx = 0.0
				e.hit_wall = true
				break
	elif e.vx < 0:
		var tx := int(floor(e.x / TILE))
		for ty in range(y0, y1 + 1):
			if tile_at(tx, ty) == T_SOLID:
				e.x = (tx + 1) * TILE
				e.vx = 0.0
				e.hit_wall = true
				break

	# по Y
	e.y += e.vy
	var x0 := int(floor(e.x / TILE))
	var x1 := int(floor((e.x + e.w - 0.01) / TILE))
	if e.vy > 0:
		var ty := int(floor((e.y + e.h - 0.01) / TILE))
		for tx in range(x0, x1 + 1):
			var t := tile_at(tx, ty)
			if t == T_SOLID or (t == T_PLAT and prev_bottom <= ty * TILE + 0.5 and e.drop <= 0):
				e.y = ty * TILE - e.h
				e.vy = 0.0
				e.on_ground = true
				break
	elif e.vy < 0:
		var ty := int(floor(e.y / TILE))
		for tx in range(x0, x1 + 1):
			if tile_at(tx, ty) == T_SOLID:
				e.y = (ty + 1) * TILE
				e.vy = 0.0
				break

func overlaps_tile(e: Dictionary, type: int) -> bool:
	var x0 := int(floor(e.x / TILE))
	var x1 := int(floor((e.x + e.w - 0.01) / TILE))
	var y0 := int(floor(e.y / TILE))
	var y1 := int(floor((e.y + e.h - 0.01) / TILE))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if tile_at(tx, ty) == type:
				return true
	return false

func aabb(a: Dictionary, b: Dictionary) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

func standing_on_platform(e: Dictionary) -> bool:
	var ty := int(floor((e.y + e.h + 1) / TILE))
	var x0 := int(floor(e.x / TILE))
	var x1 := int(floor((e.x + e.w - 0.01) / TILE))
	var plat := false
	for tx in range(x0, x1 + 1):
		var t := tile_at(tx, ty)
		if t == T_SOLID:
			return false
		if t == T_PLAT:
			plat = true
	return plat

# ============================== Запуск забега / уровня ==============================

func make_player() -> Dictionary:
	return {
		"x": 0.0, "y": 0.0, "w": 20, "h": 30, "vx": 0.0, "vy": 0.0,
		"hp": 100.0, "maxhp": 100.0,
		"on_ground": false, "hit_wall": false,
		"coyote": 0, "buffer": 0, "air_jumps": 0, "drop": 0,
		"inv": 0, "cd": 0, "face": 1, "aim": 0.0,
		"weapons": [{ "id": "pistol", "ammo": INF }], "wi": 0,
		"stats": { "dmg_mul": 1.0, "cd_mul": 1.0, "spd_mul": 1.0, "jumps": 1, "lifesteal": 0, "armor_mul": 1.0, "crit": 0.0, "jump_mul": 1.0 },
	}

func start_from_menu() -> void:
	var s := rng.randi() & 0xFFFFFFFF
	start_run(s, str(s))

func start_run(s: int, label: String) -> void:
	run_seed = s & 0xFFFFFFFF
	seed_label = label if label != "" else str(run_seed)
	lvl = 1
	score = 0
	kills = 0
	P = make_player()
	start_level()
	_set_state("play")

func start_level() -> void:
	var level_seed := (run_seed ^ ((lvl * 2654435761) & 0xFFFFFFFF)) & 0xFFFFFFFF
	level = generate_level(level_seed, lvl)
	enemies = level.enemies
	pickups = level.pickups
	bullets = []
	parts = []
	texts = []
	P.x = level.spawn.x
	P.y = level.spawn.y
	P.vx = 0.0
	P.vy = 0.0
	P.cd = 0
	P.inv = 90
	P.drop = 0
	cam.x = clampf(P.x - VW / 2.0, 0, max(0, level.px_w - VW))
	cam.y = clampf(P.y - VH / 2.0, 0, max(0, level.px_h - VH))
	shake = 0.0
	intro = 150
	intro_text = "Уровень %d — %s" % [lvl, level.theme.name]
	_build_background(level_seed)

func _set_state(s: String) -> void:
	state = s
	queue_redraw()

# ============================== Улучшения ==============================

func offer_upgrades() -> void:
	var pool := []
	for u in UPGRADES:
		if u.get("unique", false) and u.id == "djump" and P.stats.jumps > 1:
			continue
		pool.append(u)
	# перемешивание
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	offer = pool.slice(0, 3)
	_set_state("upgrade")

func choose_upgrade(u: Dictionary) -> void:
	var st: Dictionary = P.stats
	match u.id:
		"hp":
			P.maxhp += 25
			P.hp = min(P.maxhp, P.hp + 25)
		"dmg": st.dmg_mul *= 1.15
		"rate": st.cd_mul *= 0.88
		"speed": st.spd_mul *= 1.10
		"djump": st.jumps = 2
		"steal": st.lifesteal += 3
		"armor": st.armor_mul *= 0.85
		"crit": st.crit = min(0.6, st.crit + 0.10)
		"jump": st.jump_mul *= 1.08
	play_sfx("select")
	lvl += 1
	start_level()
	_set_state("play")

func level_clear() -> void:
	score += 100 + lvl * 25
	play_sfx("portal")
	offer_upgrades()

# ============================== Урон и смерть ==============================

func hurt_player(dmg: float, from_dir: float) -> void:
	if P.inv > 0 or state != "play":
		return
	var real: int = max(1, roundi(dmg * P.stats.armor_mul))
	P.hp -= real
	P.inv = 55
	P.vx = clampf(P.vx + from_dir * 4.0, -8, 8)
	P.vy = min(P.vy, -4.0)
	shake = min(14.0, shake + 7.0)
	play_sfx("hurt")
	add_text(P.x + P.w / 2.0, P.y - 6, "-%d" % real, Color("#ff6b5e"))
	burst(P.x + P.w / 2.0, P.y + P.h / 2.0, 8, Color("#ff6b5e"))
	if P.hp <= 0:
		P.hp = 0
		die()

func die() -> void:
	burst(P.x + P.w / 2.0, P.y + P.h / 2.0, 30, Color("#ff6b5e"))
	play_sfx("die")
	if score > best:
		best = score
		_save_best(best)
	_set_state("dead")

func hurt_enemy(en: Dictionary, dmg: int, crit: bool) -> void:
	en.hp -= dmg
	en.hurt_t = 90
	add_text(en.x + en.w / 2.0, en.y - 4, str(dmg), Color("#ffd86b") if crit else Color.WHITE)
	burst(en.x + en.w / 2.0, en.y + en.h / 2.0, 7 if crit else 4, Color("#ffd1a8"))
	play_sfx("hit")
	if en.hp <= 0:
		en.dead = true
		kills += 1
		score += en.score
		if P.stats.lifesteal > 0:
			P.hp = min(P.maxhp, P.hp + P.stats.lifesteal)
		burst(en.x + en.w / 2.0, en.y + en.h / 2.0, 16, Color("#ff9d6b"))
		add_text(en.x + en.w / 2.0, en.y - 14, "+%d" % en.score, Color("#9be8ff"))
		play_sfx("kill")
		drop_loot(en)

func drop_loot(en: Dictionary) -> void:
	var rv := rng.randf()
	var cx: float = en.x + en.w / 2.0 - 11
	var cy: float = en.y
	if rv < 0.30:
		pickups.append({ "kind": "coin", "x": cx + 4, "y": cy, "w": 12, "h": 12, "vy": -3.0, "t": 0.0 })
	elif rv < 0.38:
		pickups.append({ "kind": "med", "x": cx, "y": cy, "w": 22, "h": 18, "vy": -3.0, "t": 0.0, "heal": 15 })
	elif rv < 0.46:
		pickups.append({ "kind": "ammo", "x": cx, "y": cy, "w": 22, "h": 18, "vy": -3.0, "t": 0.0 })

# ============================== Оружие ==============================

func switch_weapon(i: int) -> void:
	if i == P.wi or i < 0 or i >= P.weapons.size():
		return
	P.wi = i
	P.cd = max(P.cd, 8)
	play_sfx("select")

func try_shoot() -> void:
	var slot: Dictionary = P.weapons[P.wi]
	var w: Dictionary = WEAPONS[slot.id]
	var want: bool = input.shoot_held if w.auto else input.shoot_clicked
	if not want or P.cd > 0:
		return
	if slot.ammo <= 0:
		add_text(P.x + P.w / 2.0, P.y - 8, "Нет патронов!", Color("#ff6b5e"))
		low_ammo_t = 60
		switch_weapon(0)
		return
	if is_finite(slot.ammo):
		slot.ammo -= 1
	P.cd = max(3, roundi(w.cd * P.stats.cd_mul))
	var cx: float = P.x + P.w / 2.0
	var cy: float = P.y + P.h / 2.0 - 2
	var angle: float = (input.aim - Vector2(cx, cy)).angle()
	P.aim = angle
	aim_angle = angle
	for _i in range(w.pellets):
		var a: float = angle + (rng.randf() - 0.5) * 2.0 * w.spread
		var crit: bool = rng.randf() < P.stats.crit
		var dmg: int = max(1, roundi(w.dmg * P.stats.dmg_mul * (2.0 if crit else 1.0)))
		bullets.append({
			"x": cx + cos(a) * 16, "y": cy + sin(a) * 16,
			"vx": cos(a) * w.spd, "vy": sin(a) * w.spd,
			"dmg": dmg, "crit": crit, "from": "p", "life": 90, "color": w.color,
		})
	P.vx = clampf(P.vx - cos(angle) * w.kick * 0.35, -9, 9)
	shake = min(12.0, shake + w.kick * 0.55)
	burst(cx + cos(angle) * 18, cy + sin(angle) * 18, 3, Color("#fff2b0"))
	if slot.id == "shotgun":
		play_sfx("shotgun")
	elif slot.id == "rifle":
		play_sfx("rifle")
	else:
		play_sfx("shoot")

func give_weapon(id: String) -> void:
	for s in P.weapons:
		if s.id == id:
			if is_finite(s.ammo):
				s.ammo += WEAPONS[id].ammo
			add_text(P.x + P.w / 2.0, P.y - 10, "%s: +патроны" % WEAPONS[id].name, Color("#9be8ff"))
			return
	P.weapons.append({ "id": id, "ammo": WEAPONS[id].ammo })
	if P.weapons.size() > 1:
		P.wi = P.weapons.size() - 1
	add_text(P.x + P.w / 2.0, P.y - 10, "%s!" % WEAPONS[id].name, Color("#ffd86b"))

func give_ammo() -> void:
	var slot: Dictionary = P.weapons[P.wi]
	if not is_finite(slot.ammo):
		slot = {}
		for s in P.weapons:
			if is_finite(s.ammo):
				slot = s
				break
	if not slot.is_empty():
		var add: int = roundi(WEAPONS[slot.id].ammo * 0.6)
		slot.ammo += add
		add_text(P.x + P.w / 2.0, P.y - 10, "+%d патронов" % add, Color("#9be8ff"))
	else:
		score += 25
		add_text(P.x + P.w / 2.0, P.y - 10, "+25 очков", Color("#9be8ff"))

# ============================== Эффекты ==============================

func burst(x: float, y: float, n: int, color: Color) -> void:
	for _i in range(n):
		var a := rng.randf() * TAU
		var s := 1.0 + rng.randf() * 3.2
		parts.append({
			"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s - 1,
			"life": 18.0 + rng.randf() * 22.0, "color": color,
			"size": 1.5 + rng.randf() * 2.5, "grav": 0.12,
		})

func add_text(x: float, y: float, s: String, color: Color) -> void:
	texts.append({ "x": x, "y": y, "str": s, "color": color, "life": 55.0, "vy": -0.8 })

# ============================== Шаг симуляции ==============================

func sim_step() -> void:
	tick += 1
	if state == "play":
		update_player()
		if state == "play":
			update_enemies()
			update_bullets()
			update_pickups()
		update_effects()
		update_camera()
		if intro > 0:
			intro -= 1

func update_player() -> void:
	var st: Dictionary = P.stats
	var dir: int = input.move
	var target: float = dir * 4.3 * st.spd_mul
	var accel := 0.8 if P.on_ground else 0.45
	P.vx += clampf(target - P.vx, -accel, accel)
	if abs(P.vx) < 0.05:
		P.vx = 0.0
	P.vy = min(P.vy + GRAV, MAX_FALL)

	if P.on_ground:
		P.coyote = 7
		P.air_jumps = st.jumps - 1
	else:
		P.coyote -= 1

	if input.jump_pressed:
		P.buffer = 7
	else:
		P.buffer -= 1

	if P.buffer > 0:
		if input.down and P.coyote > 0 and standing_on_platform(P):
			P.drop = 12
			P.vy = max(P.vy, 2.0)
			P.buffer = 0
			P.coyote = 0
		elif P.coyote > 0:
			do_jump()
		elif P.air_jumps > 0:
			P.air_jumps -= 1
			do_jump()
			burst(P.x + P.w / 2.0, P.y + P.h, 6, Color("#cfe3ff"))
	if not input.jump_held and P.vy < -4.5:
		P.vy = -4.5
	if P.drop > 0:
		P.drop -= 1

	collide_entity(P)

	P.aim = (input.aim - Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0)).angle()
	aim_angle = P.aim
	P.face = 1 if cos(P.aim) >= 0 else -1

	if P.inv <= 0 and overlaps_tile(P, T_SPIKE):
		P.vy = -9.0
		hurt_player(15, 0)
	if overlaps_tile(P, T_EXIT):
		level_clear()
		return

	if P.inv > 0:
		P.inv -= 1
	if P.cd > 0:
		P.cd -= 1
	if low_ammo_t > 0:
		low_ammo_t -= 1

	if input.switch_to >= 0 and input.switch_to < P.weapons.size():
		switch_weapon(input.switch_to)

	try_shoot()

func do_jump() -> void:
	P.vy = -12.2 * P.stats.jump_mul
	P.coyote = 0
	P.buffer = 0
	play_sfx("jump")
	burst(P.x + P.w / 2.0, P.y + P.h, 4, Color("#aab8d8"))

func update_enemies() -> void:
	var pcx: float = P.x + P.w / 2.0
	var pcy: float = P.y + P.h / 2.0
	for en in enemies:
		if en.dead:
			continue
		var ecx: float = en.x + en.w / 2.0
		var ecy: float = en.y + en.h / 2.0
		var dist := Vector2(pcx - ecx, pcy - ecy).length()

		if en.type == "walker":
			en.vy = min(en.vy + GRAV, MAX_FALL)
			var sees: bool = dist < 280 and abs(pcy - ecy) < 80 and line_of_sight(ecx, ecy, pcx, pcy)
			if sees:
				en.dir = 1 if pcx > ecx else -1
			en.vx = en.dir * en.spd * (1.7 if sees else 1.0)
			collide_entity(en)
			if en.hit_wall:
				en.dir *= -1
			elif en.on_ground:
				var ahead_x: float = en.x + en.w + 2 if en.dir > 0 else en.x - 2
				var foot_tx := int(floor(ahead_x / TILE))
				var foot_ty := int(floor((en.y + en.h + 4) / TILE))
				var below := tile_at(foot_tx, foot_ty)
				var at_feet := tile_at(foot_tx, foot_ty - 1)
				if (below != T_SOLID and below != T_PLAT) or at_feet == T_SPIKE:
					en.dir *= -1
		elif en.type == "shooter" or en.type == "tank":
			en.vy = min(en.vy + GRAV, MAX_FALL)
			en.vx = 0.0
			if en.type == "tank" and dist < 240 and en.on_ground:
				en.vx = (1 if pcx > ecx else -1) * en.spd
			en.dir = 1 if pcx > ecx else -1
			collide_entity(en)
			var range_d := 460.0 if en.type == "tank" else 420.0
			if dist < range_d and line_of_sight(ecx, ecy, pcx, pcy):
				en.cd -= 1
				if en.cd <= 0:
					en.cd = en.cd_max
					var base_a := (Vector2(pcx, pcy) - Vector2(ecx, ecy)).angle()
					var pellets := 3 if en.type == "tank" else 1
					var spread := 0.16 if en.type == "tank" else 0.06
					var spd := 5.5 if en.type == "tank" else 6.5
					for i in range(pellets):
						var a: float
						if pellets > 1:
							a = base_a + (i - (pellets - 1) / 2.0) * spread
						else:
							a = base_a + (rng.randf() - 0.5) * spread * 2.0
						bullets.append({
							"x": ecx + cos(a) * (en.w / 2.0 + 4), "y": ecy + sin(a) * (en.w / 2.0 + 4),
							"vx": cos(a) * spd, "vy": sin(a) * spd,
							"dmg": en.dmg, "crit": false, "from": "e", "life": 240, "color": "#ff7a6b",
						})
					burst(ecx + en.dir * (en.w / 2.0 + 6), ecy, 3, Color("#ffb0a0"))
			else:
				en.cd = max(en.cd, 25)
		elif en.type == "flyer":
			en.phase += 0.06
			if dist < 340 and line_of_sight(ecx, ecy, pcx, pcy):
				en.vx += clampf(pcx - ecx, -1, 1) * 0.08
				en.vy += clampf(pcy - ecy, -1, 1) * 0.08
			else:
				en.vx += cos(en.phase) * 0.05
				en.vy += sin(en.phase * 1.3) * 0.05
			var sp := Vector2(en.vx, en.vy).length()
			if sp > en.spd:
				en.vx *= en.spd / sp
				en.vy *= en.spd / sp
			var pvx: float = en.vx
			var pvy: float = en.vy
			collide_entity(en)
			if en.vx == 0 and pvx != 0:
				en.vx = -pvx * 0.5
			if en.vy == 0 and pvy != 0:
				en.vy = -pvy * 0.5
			en.dir = 1 if pcx > ecx else -1

		if en.hurt_t > 0:
			en.hurt_t -= 1

		if P.inv <= 0 and aabb(en, P):
			hurt_player(en.dmg, 1 if P.x + P.w / 2.0 > ecx else -1)

	var alive := []
	for en in enemies:
		if not en.dead:
			alive.append(en)
	enemies = alive

func update_bullets() -> void:
	var alive := []
	for b in bullets:
		b.life -= 1
		var hit: bool = b.life <= 0
		var steps := 2
		var s := 0
		while s < steps and not hit:
			b.x += b.vx / steps
			b.y += b.vy / steps
			if solid_px(b.x, b.y):
				burst(b.x, b.y, 3, Color("#cdd6f0"))
				hit = true
				break
			if b.from == "p":
				for en in enemies:
					if en.dead:
						continue
					if b.x > en.x - 2 and b.x < en.x + en.w + 2 and b.y > en.y - 2 and b.y < en.y + en.h + 2:
						hurt_enemy(en, b.dmg, b.crit)
						hit = true
						break
			elif P.inv <= 0 and state == "play" \
					and b.x > P.x - 2 and b.x < P.x + P.w + 2 and b.y > P.y - 2 and b.y < P.y + P.h + 2:
				hurt_player(b.dmg, 1 if b.vx > 0 else -1)
				hit = true
			if b.y < -200 or b.y > level.px_h + 200 or b.x < -200 or b.x > level.px_w + 200:
				hit = true
			s += 1
		if not hit:
			alive.append(b)
	bullets = alive

func update_pickups() -> void:
	var alive := []
	for pk in pickups:
		pk.t += 0.08
		pk.vy = min(pk.vy + 0.4, 10.0)
		var ny: float = pk.y + pk.vy
		var ty := int(floor((ny + pk.h) / TILE))
		var tx0 := int(floor(pk.x / TILE))
		var tx1 := int(floor((pk.x + pk.w - 0.01) / TILE))
		var landed := false
		for tx in range(tx0, tx1 + 1):
			var t := tile_at(tx, ty)
			if t == T_SOLID or (t == T_PLAT and pk.y + pk.h <= ty * TILE + 0.5):
				landed = true
				break
		if landed:
			pk.y = ty * TILE - pk.h
			pk.vy = -pk.vy * 0.4 if pk.kind == "coin" else 0.0
			if abs(pk.vy) < 1:
				pk.vy = 0.0
		else:
			pk.y = ny

		if pk.kind == "coin":
			var dx: float = P.x + P.w / 2.0 - (pk.x + pk.w / 2.0)
			var dy: float = P.y + P.h / 2.0 - (pk.y + pk.h / 2.0)
			var d := Vector2(dx, dy).length()
			if d < 90 and d > 1:
				pk.x += dx / d * 3.4
				pk.y += dy / d * 3.4

		if aabb(pk, P):
			if pk.kind == "weapon":
				give_weapon(pk.weapon)
			elif pk.kind == "med":
				P.hp = min(P.maxhp, P.hp + pk.heal)
				add_text(P.x + P.w / 2.0, P.y - 10, "+%d HP" % pk.heal, Color("#7df2a5"))
			elif pk.kind == "ammo":
				give_ammo()
			elif pk.kind == "coin":
				score += 5
				add_text(pk.x, pk.y - 6, "+5", Color("#ffd86b"))
			play_sfx("pickup")
			continue
		alive.append(pk)
	pickups = alive

func update_effects() -> void:
	var pa := []
	for p in parts:
		p.life -= 1
		if p.life <= 0:
			continue
		p.vy += p.grav
		p.x += p.vx
		p.y += p.vy
		pa.append(p)
	parts = pa
	var ta := []
	for t in texts:
		t.life -= 1
		if t.life <= 0:
			continue
		t.y += t.vy
		ta.append(t)
	texts = ta

func update_camera() -> void:
	var tx := clampf(P.x + P.w / 2.0 - VW / 2.0 + P.face * 40, 0, max(0, level.px_w - VW))
	var ty := clampf(P.y + P.h / 2.0 - VH / 2.0, 0, max(0, level.px_h - VH))
	cam.x = lerp(cam.x, tx, 0.12)
	cam.y = lerp(cam.y, ty, 0.14)
	shake *= 0.86
	if shake < 0.3:
		shake = 0.0

# ============================== Фон ==============================

func _build_background(seed_val: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = (seed_val ^ 0xBADA55) & 0xFFFFFFFF
	th = {
		"ground": _col(level.theme.ground), "top": _col(level.theme.top),
		"plat": _col(level.theme.plat), "spike": _col(level.theme.spike),
		"hill_far": _col(level.theme.hill_far), "hill_near": _col(level.theme.hill_near),
	}
	sky0 = _col(level.theme.sky0)
	sky1 = _col(level.theme.sky1)
	stars = []
	for _i in range(70):
		stars.append(Vector3(r.randf() * VW, r.randf() * VH * 0.7, 0.4 + r.randf() * 1.2))
	hill_far = _make_hills(r, 330, 26)
	hill_near = _make_hills(r, 420, 34)

func _make_hills(r: RandomNumberGenerator, base_y: float, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 760))
	var y := base_y
	var hx := 0
	while hx <= 1920:
		y = clampf(y + (r.randf() - 0.5) * amp, base_y - 90, base_y + 60)
		pts.append(Vector2(hx, y))
		hx += 24
	pts.append(Vector2(1920, 760))
	return pts

# ============================== Отрисовка ==============================

func _draw() -> void:
	_ui_rects.clear()
	if level.is_empty():
		draw_rect(Rect2(0, 0, VW, VH), Color("#0d1020"))
	else:
		var sh := Vector2.ZERO
		if shake > 0:
			sh = Vector2((rng.randf() - 0.5) * shake, (rng.randf() - 0.5) * shake)
		var c := cam + sh

		_draw_sky()
		_draw_hills(hill_far, th.hill_far, c, 0.25)
		_draw_hills(hill_near, th.hill_near, c, 0.45)

		draw_set_transform(-c)
		_draw_tiles(c)
		_draw_portal()
		_draw_pickups()
		_draw_enemies()
		_draw_player()
		_draw_bullets()
		_draw_particles()
		_draw_texts()
		draw_set_transform(Vector2.ZERO)

		_draw_hud()

	_draw_overlays()

func _draw_sky() -> void:
	var bands := 36
	for i in range(bands):
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, i * VH / float(bands), VW, VH / float(bands) + 1), sky0.lerp(sky1, t))
	for sv in stars:
		draw_rect(Rect2(sv.x, sv.y, sv.z, sv.z), Color(1, 1, 1, 0.5))

func _draw_hills(pts: PackedVector2Array, color: Color, c: Vector2, par: float) -> void:
	if pts.size() < 3:
		return
	var ox: float = -fmod(c.x * par, 1920.0)
	var oy: float = -c.y * 0.12 - 120
	for k in [-1, 0, 1]:
		var off := Vector2(ox + k * 1920, oy)
		var shifted := PackedVector2Array()
		for p in pts:
			shifted.append(p + off)
		draw_colored_polygon(shifted, color)

func _draw_tiles(c: Vector2) -> void:
	var x0 := maxi(0, int(floor(c.x / TILE)))
	var x1 := mini(level.W - 1, int(floor((c.x + VW) / TILE)) + 1)
	var y0 := maxi(0, int(floor(c.y / TILE)))
	var y1 := mini(level.H - 1, int(floor((c.y + VH) / TILE)) + 1)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			var t: int = level.grid[ty * level.W + tx]
			var px := tx * TILE
			var py := ty * TILE
			if t == T_SOLID:
				draw_rect(Rect2(px, py, TILE, TILE), th.ground)
				if ((tx * 7 + ty * 13) & 3) == 0:
					draw_rect(Rect2(px, py, TILE, TILE), Color(0, 0, 0, 0.08))
				if tile_at(tx, ty - 1) != T_SOLID:
					draw_rect(Rect2(px, py, TILE, 6), th.top)
			elif t == T_PLAT:
				draw_rect(Rect2(px, py, TILE, 8), th.plat)
				draw_rect(Rect2(px, py + 6, TILE, 2), Color(0, 0, 0, 0.25))
			elif t == T_SPIKE:
				var poly := PackedVector2Array([
					Vector2(px, py + TILE), Vector2(px + 8, py + 6),
					Vector2(px + 16, py + TILE), Vector2(px + 24, py + 6),
					Vector2(px + TILE, py + TILE),
				])
				draw_colored_polygon(poly, th.spike)

func _draw_portal() -> void:
	var e: Vector2 = level.exit_px
	var cxp: float = e.x
	var cyp: float = e.y + TILE / 2.0
	var pulse := 1.0 + sin(tick * 0.07) * 0.12
	for i in range(5, 0, -1):
		var rr := 9.0 * i * pulse
		draw_circle(Vector2(cxp, cyp), rr, Color(0.47, 0.63, 1.0, 0.06))
	draw_arc(Vector2(cxp, cyp), 20 * pulse, 0, TAU, 32, Color(0.78, 0.94, 1.0, 0.85), 3.0)
	draw_arc(Vector2(cxp, cyp), 28 * pulse, 0, TAU, 32, Color(0.55, 0.74, 1.0, 0.5), 2.0)

func _draw_pickups() -> void:
	for pk in pickups:
		var bob := sin(pk.t * 2) * 2.5
		var x: float = pk.x
		var y: float = pk.y + bob
		if pk.kind == "weapon":
			var w: Dictionary = WEAPONS[pk.weapon]
			draw_rect(Rect2(x - 3, y - 3, pk.w + 6, pk.h + 6), Color(1, 1, 1, 0.10))
			draw_rect(Rect2(x, y, pk.w, pk.h), Color("#1e2740"))
			draw_rect(Rect2(x + 4, y + pk.h / 2.0 - 2, pk.w - 8, 4), _col(w.color))
		elif pk.kind == "med":
			draw_rect(Rect2(x, y, pk.w, pk.h), Color("#f2f5ff"))
			draw_rect(Rect2(x + pk.w / 2.0 - 2, y + 4, 4, pk.h - 8), Color("#ff5e57"))
			draw_rect(Rect2(x + 5, y + pk.h / 2.0 - 2, pk.w - 10, 4), Color("#ff5e57"))
		elif pk.kind == "ammo":
			draw_rect(Rect2(x, y, pk.w, pk.h), Color("#caa64a"))
			draw_rect(Rect2(x, y + 5, pk.w, 3), Color("#8a6f2c"))
		elif pk.kind == "coin":
			draw_circle(Vector2(x + 6, y + 6), 6, Color("#ffd86b"))
			draw_circle(Vector2(x + 6, y + 6), 3, Color("#b88f2e"))

func _draw_enemies() -> void:
	for en in enemies:
		var flash: bool = en.hurt_t > 84
		if en.type == "walker":
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else Color("#e2554f"))
			var exx: float = en.x + en.w / 2.0 + en.dir * 5
			draw_rect(Rect2(exx - 3, en.y + 8, 3, 5), Color("#2a0f0e"))
			draw_rect(Rect2(exx + 2, en.y + 8, 3, 5), Color("#2a0f0e"))
		elif en.type == "shooter":
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else Color("#b06ee8"))
			draw_rect(Rect2(en.x + en.w / 2.0 - 2 + en.dir * 4, en.y + 9, 5, 5), Color("#34204a"))
			draw_rect(Rect2(en.x + en.w / 2.0 + (4 if en.dir > 0 else -16), en.y + en.h / 2.0 - 2, 12, 4), Color.WHITE if flash else Color("#7a4aa8"))
		elif en.type == "flyer":
			var flap := sin(tick * 0.3 + en.phase) * 5
			var ec := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
			draw_circle(ec, en.w / 2.0, Color.WHITE if flash else Color("#5fb0e8"))
			var wing := Color.WHITE if flash else Color("#3d7eb0")
			draw_colored_polygon(PackedVector2Array([
				Vector2(en.x + 2, ec.y), Vector2(en.x - 7, ec.y - 6 + flap), Vector2(en.x + 4, ec.y + 4)]), wing)
			draw_colored_polygon(PackedVector2Array([
				Vector2(en.x + en.w - 2, ec.y), Vector2(en.x + en.w + 7, ec.y - 6 + flap), Vector2(en.x + en.w - 4, ec.y + 4)]), wing)
			draw_rect(Rect2(ec.x + en.dir * 4 - 2, ec.y - 3, 4, 4), Color("#10243a"))
		elif en.type == "tank":
			draw_rect(Rect2(en.x, en.y + 8, en.w, en.h - 8), Color.WHITE if flash else Color("#c8893a"))
			draw_circle(Vector2(en.x + en.w / 2.0, en.y + 12), en.w / 2.0 - 4, Color.WHITE if flash else Color("#9c6a28"))
			draw_rect(Rect2(en.x + en.w / 2.0 + (6 if en.dir > 0 else -22), en.y + en.h / 2.0, 16, 5), Color("#3a2810"))

		if en.hurt_t > 0 and en.hp < en.maxhp:
			var bw: float = en.w + 8
			draw_rect(Rect2(en.x - 4, en.y - 9, bw, 4), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(en.x - 4, en.y - 9, bw * clampf(float(en.hp) / en.maxhp, 0, 1), 4), Color("#ff5e57"))

func _draw_player() -> void:
	if state == "dead":
		return
	if P.inv > 0 and (tick & 4) != 0:
		return
	draw_rect(Rect2(P.x, P.y + 4, P.w, P.h - 4), Color("#3ec6a8"))
	draw_rect(Rect2(P.x, P.y + P.h - 7, P.w, 7), Color("#2c917b"))
	draw_rect(Rect2(P.x + (8 if P.face > 0 else 2), P.y + 8, 10, 5), Color("#e9f4ff"))
	draw_rect(Rect2(P.x + (13 if P.face > 0 else 3), P.y + 9, 4, 3), Color("#1c3a4a"))
	# оружие, повёрнутое к прицелу
	var w: Dictionary = WEAPONS[P.weapons[P.wi].id]
	var gx: float = P.x + P.w / 2.0 - cam.x
	var gy: float = P.y + P.h / 2.0 - 2 - cam.y
	draw_set_transform(Vector2(gx, gy), P.aim)
	draw_rect(Rect2(2, -3, w.len, 6), Color("#222b3d"))
	draw_rect(Rect2(w.len - 3, -2, 4, 4), _col(w.color))
	draw_set_transform(-cam)

func _draw_bullets() -> void:
	for b in bullets:
		var col := _col(b.color)
		var from := Vector2(b.x - b.vx * 1.4, b.y - b.vy * 1.4)
		draw_line(from, Vector2(b.x, b.y), col, 3.5 if b.crit else 2.5)

func _draw_particles() -> void:
	for p in parts:
		var a := clampf(p.life / 24.0, 0, 1)
		var col: Color = p.color
		col.a = a
		draw_rect(Rect2(p.x - p.size / 2.0, p.y - p.size / 2.0, p.size, p.size), col)

func _draw_texts() -> void:
	for t in texts:
		var a := clampf(t.life / 30.0, 0, 1)
		var col: Color = t.color
		col.a = a
		var sz := font.get_string_size(t.str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var pos := Vector2(t.x - sz.x / 2.0, t.y)
		draw_string(font, pos + Vector2(1, 1), t.str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, a * 0.6))
		draw_string(font, pos, t.str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

# ============================== HUD и оверлеи ==============================

func _text(pos: Vector2, s: String, size: int, color: Color, center := false) -> void:
	var px := pos
	if center:
		var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		px.x -= sz.x / 2.0
	draw_string(font, px, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_hud() -> void:
	# здоровье
	var hpw := 190.0
	draw_rect(Rect2(12, 12, hpw + 4, 20), Color(0, 0, 0, 0.45))
	var frac := clampf(P.hp / P.maxhp, 0, 1)
	var hpcol := Color("#56d98b")
	if frac <= 0.35:
		hpcol = Color("#ff5e57") if (tick % 30 < 15) else Color("#c93a34")
	draw_rect(Rect2(14, 14, hpw * frac, 16), hpcol)
	_text(Vector2(20, 27), "%d / %d" % [ceili(P.hp), int(P.maxhp)], 12, Color("#eaf0ff"))

	# уровень/тема
	_text(Vector2(VW / 2.0, 24), "Уровень %d · %s" % [lvl, level.theme.name], 14, Color("#dfe5ff"), true)

	# очки
	var score_str := str(score)
	var ssz := font.get_string_size(score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_text(Vector2(VW - 16 - ssz.x, 26), score_str, 16, Color("#ffd86b"))
	var sub := "убийств: %d · сид: %s" % [kills, seed_label]
	var subsz := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	_text(Vector2(VW - 16 - subsz.x, 44), sub, 11, Color("#8d97bd"))

	# оружие
	var slot: Dictionary = P.weapons[P.wi]
	var w: Dictionary = WEAPONS[slot.id]
	draw_rect(Rect2(12, VH - 46, 210, 34), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(22, VH - 32, 18, 6), _col(w.color))
	var ammo_str := "∞" if not is_finite(slot.ammo) else str(int(slot.ammo))
	var acol := Color("#eaf0ff")
	if low_ammo_t > 0 or (is_finite(slot.ammo) and slot.ammo <= 5):
		acol = Color("#ff5e57")
	_text(Vector2(50, VH - 22), "%s · %s" % [w.name, ammo_str], 13, acol)
	for i in range(P.weapons.size()):
		var sx := 232 + i * 26
		draw_rect(Rect2(sx, VH - 42, 22, 22), Color(1, 0.85, 0.42, 0.85) if i == P.wi else Color(1, 1, 1, 0.15))
		_text(Vector2(sx + 7, VH - 26), str(i + 1), 12, Color("#2a1c04") if i == P.wi else Color("#cfd6f5"))

	# интро
	if intro > 0:
		var a := clampf((150 - intro) / 30.0 if intro > 120 else intro / 60.0, 0, 1)
		_text(Vector2(VW / 2.0, VH / 2.0 - 60), intro_text, 30, Color(1, 0.91, 0.69, a), true)
		_text(Vector2(VW / 2.0, VH / 2.0 - 30), "Доберитесь до портала →", 15, Color(0.67, 0.70, 0.84, a), true)

	# прицел
	if state == "play":
		var m := get_local_mouse_position()
		draw_arc(m, 7, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
		draw_rect(Rect2(m.x - 1, m.y - 1, 2, 2), Color(1, 1, 1, 0.9))

func _btn(rect: Rect2, label: String, key: String, primary := true) -> void:
	var bg := Color("#ffc24d") if primary else Color(1, 1, 1, 0.10)
	draw_rect(rect, bg)
	var tc := Color("#2a1c04") if primary else Color("#cfd6f5")
	_text(Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0 + 6), label, 16, tc, true)
	_ui_rects[key] = rect

func _draw_overlays() -> void:
	if state == "play":
		return
	draw_rect(Rect2(0, 0, VW, VH), Color(0.027, 0.031, 0.059, 0.80))
	var cx := VW / 2.0
	match state:
		"menu":
			_text(Vector2(cx, 150), "GUNFALL", 72, Color("#ffce5a"), true)
			_text(Vector2(cx, 190), "Платформер-рогалик: каждый забег — новая карта", 16, Color("#aab3d6"), true)
			_text(Vector2(cx, 250), "A/D — бег · W/Пробел — прыжок · S+прыжок — вниз", 14, Color("#8d97bd"), true)
			_text(Vector2(cx, 274), "Мышь — прицел · ЛКМ — огонь · 1–4/колесо — оружие", 14, Color("#8d97bd"), true)
			_text(Vector2(cx, 298), "Esc — пауза · M — звук", 14, Color("#8d97bd"), true)
			_btn(Rect2(cx - 90, 330, 180, 52), "Играть", "play")
			var bl := "Рекорд: %d очков" % best if best > 0 else "Удачного первого забега!"
			_text(Vector2(cx, 420), bl, 14, Color("#6f7aa3"), true)
			_text(Vector2(cx, 450), "Enter / Пробел / клик — старт", 13, Color("#6f7aa3"), true)
		"pause":
			_text(Vector2(cx, 200), "Пауза", 40, Color("#eaf0ff"), true)
			_btn(Rect2(cx - 90, 250, 180, 50), "Продолжить", "resume")
			_btn(Rect2(cx - 90, 312, 180, 46), "В меню", "quit", false)
		"dead":
			_text(Vector2(cx, 150), "Вы погибли", 44, Color("#ff6b5e"), true)
			_text(Vector2(cx, 210), "Очки: %d" % score, 20, Color("#cfd6f5"), true)
			_text(Vector2(cx, 240), "Уровень: %d · Убийств: %d" % [lvl, kills], 16, Color("#cfd6f5"), true)
			_text(Vector2(cx, 266), "Сид: %s · Рекорд: %d" % [seed_label, best], 16, Color("#cfd6f5"), true)
			_btn(Rect2(cx - 190, 310, 180, 50), "Новый забег", "retry")
			_btn(Rect2(cx + 10, 310, 180, 50), "В меню", "menu", false)
		"upgrade":
			_text(Vector2(cx, 110), "Уровень пройден!", 36, Color("#eaf0ff"), true)
			_text(Vector2(cx, 150), "Выберите улучшение (1 / 2 / 3 или клик):", 16, Color("#aab3d6"), true)
			var cw := 230.0
			var gap := 24.0
			var total := offer.size() * cw + (offer.size() - 1) * gap
			var sx := cx - total / 2.0
			for i in range(offer.size()):
				var u: Dictionary = offer[i]
				var rect := Rect2(sx + i * (cw + gap), 200, cw, 200)
				draw_rect(rect, Color(1, 1, 1, 0.05))
				draw_rect(rect, Color(1, 0.85, 0.42, 0.5), false, 2.0)
				_ui_rects["card%d" % i] = rect
				var ccx := rect.position.x + cw / 2.0
				_text(Vector2(ccx, rect.position.y + 60), u.icon, 48, Color("#ffe9b0"), true)
				_text(Vector2(ccx, rect.position.y + 100), u.name, 18, Color("#ffe9b0"), true)
				_draw_wrapped(u.desc, rect.position.x + 16, rect.position.y + 130, cw - 32, 14, Color("#aab3d6"))
				_text(Vector2(ccx, rect.position.y + 188), "[%d]" % (i + 1), 14, Color("#8d97bd"), true)

func _draw_wrapped(s: String, x: float, y: float, w: float, size: int, color: Color) -> void:
	var words := s.split(" ")
	var line := ""
	var ly := y
	for word in words:
		var test := line + (" " if line != "" else "") + word
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w and line != "":
			_text(Vector2(x + w / 2.0, ly), line, size, color, true)
			line = word
			ly += size + 6
		else:
			line = test
	if line != "":
		_text(Vector2(x + w / 2.0, ly), line, size, color, true)

# ============================== Аудио ==============================

func _setup_audio() -> void:
	for _i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_audio_players.append(p)
	_sfx_cache = {
		"shoot": _tone(320, 90, 0.09, "square", 0.30),
		"shotgun": _noise(0.22, 0.55, false),
		"rifle": _tone(520, 120, 0.12, "square", 0.32),
		"hit": _tone(210, 140, 0.06, "triangle", 0.40),
		"kill": _noise(0.18, 0.5, true),
		"hurt": _tone(160, 55, 0.22, "saw", 0.45),
		"jump": _tone(240, 480, 0.10, "square", 0.22),
		"pickup": _tone(520, 880, 0.12, "square", 0.30),
		"portal": _tone(330, 760, 0.30, "sine", 0.40),
		"select": _tone(600, 900, 0.08, "square", 0.24),
		"die": _noise(0.4, 0.55, true),
	}

func play_sfx(name: String) -> void:
	if not audio_enabled or _sfx_cache.is_empty():
		return
	if not _sfx_cache.has(name):
		return
	var p: AudioStreamPlayer = _audio_players[_audio_idx]
	_audio_idx = (_audio_idx + 1) % _audio_players.size()
	p.stream = _sfx_cache[name]
	p.play()

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = data
	return wav

func _tone(f0: float, f1: float, dur: float, type: String, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / n
		var f: float = f0 * pow(max(1.0, f1) / f0, t)
		phase += TAU * f / rate
		var s := 0.0
		match type:
			"square": s = 1.0 if sin(phase) >= 0 else -1.0
			"saw": s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"triangle": s = asin(sin(phase)) * (2.0 / PI)
			_: s = sin(phase)
		var env := (1.0 - t)
		samples[i] = s * env * vol
	return _make_wav(samples)

func _noise(dur: float, vol: float, low: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var v := 0.0
	var nr := RandomNumberGenerator.new()
	nr.seed = 1234
	for i in range(n):
		var w := nr.randf() * 2.0 - 1.0
		if low:
			v = v * 0.92 + w * 0.08
		else:
			v = w
		var t := float(i) / n
		samples[i] = v * (1.0 - t) * vol
	return _make_wav(samples)

# ============================== Сохранение рекорда ==============================

func _save_path() -> String:
	return "user://gunfall_best.save"

func _load_best() -> int:
	if FileAccess.file_exists(_save_path()):
		var f := FileAccess.open(_save_path(), FileAccess.READ)
		if f:
			var v := f.get_32()
			f.close()
			return v
	return 0

func _save_best(v: int) -> void:
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_32(v)
		f.close()
