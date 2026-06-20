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
const T_CRATE := 5   # разрушаемый ящик (твёрдый, ломается выстрелами/взрывами)
const T_LAVA := 6    # светящаяся лава/кислота на дне ям (урон + поджиг, не твёрдая)

const THEMES := [
	{ "name": "Изумрудные пещеры", "sky0": "#0e1830", "sky1": "#1d3250", "hill_far": "#15233c", "hill_near": "#1b2c4a",
	  "ground": "#2c3a55", "top": "#58c98f", "plat": "#7fdcae", "spike": "#bcd0ff", "weather": "spores", "wcol": "#9ff0c0", "lava": "#37e0c0" },
	{ "name": "Багровые руины", "sky0": "#180d1c", "sky1": "#3a1c33", "hill_far": "#241229", "hill_near": "#301a37",
	  "ground": "#3d2438", "top": "#e0707a", "plat": "#f29a8e", "spike": "#ffd3c0", "weather": "embers", "wcol": "#ff9a5a", "lava": "#ff5a2a" },
	{ "name": "Ледяные шахты", "sky0": "#0b1426", "sky1": "#1d3a55", "hill_far": "#142339", "hill_near": "#1b2f4a",
	  "ground": "#31415f", "top": "#8fd8f2", "plat": "#b5e8fa", "spike": "#e8f6ff", "weather": "snow", "wcol": "#e8f6ff", "lava": "#3aa0ff" },
	{ "name": "Токсичные топи", "sky0": "#0d1612", "sky1": "#1d3328", "hill_far": "#13241b", "hill_near": "#1a3124",
	  "ground": "#2b3d31", "top": "#a8d65c", "plat": "#c6ec85", "spike": "#e9ffc9", "weather": "bubbles", "wcol": "#bff06a", "lava": "#9bff3a" },
	{ "name": "Пустынный форт", "sky0": "#1a1208", "sky1": "#3d2c14", "hill_far": "#291e0e", "hill_near": "#352813",
	  "ground": "#4a3a20", "top": "#e6b566", "plat": "#f4ce8d", "spike": "#ffe9c2", "weather": "sand", "wcol": "#f0d29a", "lava": "#ff7a1a" },
]

const WEAPONS := {
	"pistol":  { "name": "Пистолет", "dmg": 12, "cd": 16, "spd": 12.0, "spread": 0.035, "pellets": 1, "auto": false, "ammo": INF, "color": "#ffd86b", "kick": 1.2, "len": 15 },
	"smg":     { "name": "ПП «Оса»", "dmg": 8, "cd": 6, "spd": 13.0, "spread": 0.10, "pellets": 1, "auto": true, "ammo": 150, "color": "#9be8ff", "kick": 1.6, "len": 17 },
	"shotgun": { "name": "Дробовик", "dmg": 9, "cd": 44, "spd": 11.0, "spread": 0.24, "pellets": 6, "auto": false, "ammo": 32, "color": "#ffb077", "kick": 5.0, "len": 19 },
	"rifle":   { "name": "Винтовка", "dmg": 36, "cd": 34, "spd": 18.0, "spread": 0.012, "pellets": 1, "auto": false, "ammo": 30, "color": "#d3a4ff", "kick": 3.2, "len": 23 },
	"grenade": { "name": "Гранатомёт", "dmg": 34, "cd": 52, "spd": 9.5, "spread": 0.02, "pellets": 1, "auto": false, "ammo": 18, "color": "#9ef07f", "kick": 4.0, "len": 20, "gren": true, "radius": 80, "fuse": 80 },
	"railgun": { "name": "Рельса", "dmg": 55, "cd": 50, "spd": 22.0, "spread": 0.0, "pellets": 1, "auto": false, "ammo": 20, "color": "#7fd4ff", "kick": 3.6, "len": 25, "pierce": true },
	"flame":   { "name": "Огнемёт", "dmg": 4, "cd": 2, "spd": 0.0, "spread": 0.0, "pellets": 0, "auto": true, "ammo": 240, "color": "#ff7a3d", "kick": 0.6, "len": 18, "flame": true, "range": 132.0, "cone": 0.5 },
}
const WEAPON_DROPS := ["smg", "shotgun", "rifle", "grenade", "railgun", "flame"]

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
	{ "id": "shieldup", "icon": "▢", "name": "Энергощит", "desc": "+30 к запасу щита и медленное восстановление щита" },
	{ "id": "dashcd", "icon": "⟫", "name": "Реактивный рывок", "desc": "Перезарядка рывка быстрее на 30%" },
	{ "id": "blast", "icon": "✺", "name": "Сапёр", "desc": "+40% к радиусу и урону ваших взрывов" },
	{ "id": "magnet", "icon": "◈", "name": "Магнит", "desc": "Притягивает монеты и предметы с большего расстояния" },
	{ "id": "berserk", "icon": "⚡", "name": "Берсерк", "desc": "Чем длиннее серия убийств, тем выше урон" },
	{ "id": "incend", "icon": "🔥", "name": "Зажигательные", "desc": "Пули с шансом поджигают врагов (урон по времени)" },
	{ "id": "cryo", "icon": "❄", "name": "Крио-патроны", "desc": "Пули с шансом замораживают врагов (замедление)" },
]

const ACHIEVEMENTS := [
	{ "id": "first_blood", "name": "Первая кровь", "desc": "Убить первого врага" },
	{ "id": "combo_master", "name": "Мастер серий", "desc": "Серия из 10 убийств" },
	{ "id": "boss_slayer", "name": "Победитель боссов", "desc": "Одолеть босса" },
	{ "id": "arsenal", "name": "Арсенал", "desc": "Носить 4 оружия одновременно" },
	{ "id": "deep_diver", "name": "Глубоко", "desc": "Дойти до 10-го уровня" },
	{ "id": "sharpshooter", "name": "Снайпер", "desc": "Точность 90%+ за забег (30+ выстрелов)" },
	{ "id": "high_score", "name": "Богач", "desc": "Набрать 1000 очков за забег" },
	{ "id": "survivor", "name": "Живучий", "desc": "Прожить 3 минуты за один забег" },
]

const ENEMY_BASE := {
	"walker":  { "w": 26, "h": 28, "hp": 30, "spd": 1.1, "dmg": 12, "score": 10, "cd": 0, "fly": false },
	"shooter": { "w": 26, "h": 30, "hp": 42, "spd": 0.0, "dmg": 9, "score": 20, "cd": 105, "fly": false },
	"flyer":   { "w": 24, "h": 20, "hp": 22, "spd": 1.7, "dmg": 10, "score": 15, "cd": 0, "fly": true },
	"tank":    { "w": 36, "h": 38, "hp": 130, "spd": 0.55, "dmg": 11, "score": 45, "cd": 135, "fly": false },
	"exploder": { "w": 22, "h": 24, "hp": 18, "spd": 1.9, "dmg": 24, "score": 18, "cd": 0, "fly": false, "radius": 62 },
	"sniper":  { "w": 26, "h": 30, "hp": 34, "spd": 0.0, "dmg": 26, "score": 30, "cd": 0, "fly": false },
	"splitter": { "w": 30, "h": 30, "hp": 52, "spd": 0.9, "dmg": 12, "score": 25, "cd": 0, "fly": false },
	"shard":   { "w": 14, "h": 16, "hp": 10, "spd": 2.4, "dmg": 8, "score": 5, "cd": 0, "fly": false },
	"boss":    { "w": 70, "h": 74, "hp": 900, "spd": 0.9, "dmg": 18, "score": 300, "cd": 70, "fly": false },
}

# ============================== Состояние ==============================

var state := "menu"  # menu | play | pause | upgrade | shop | dead
var lvl := 1
var score := 0
var coins := 0       # валюта для магазина
var shop_items := [] # товары текущего магазина
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
var combo := 0           # серия убийств
var combo_t := 0         # таймер сброса серии
var max_combo := 0       # лучшая серия за забег
var boss_alive := false  # на уровне есть живой босс
var boss_name := ""      # имя текущего босса
var _eid_counter := 1000000  # счётчик id для врагов, созданных в рантайме
var hitstop := 0         # короткая заморозка при крупных событиях
var volume := 0.8        # громкость (0..1), сохраняется
var shake_on := true     # тряска экрана (опция доступности), сохраняется
var ult := 0.0           # заряд ультимейта (0..ULT_MAX)
const ULT_MAX := 300.0

# статистика забега
var run_ticks := 0       # прожитые кадры (время)
var shots_fired := 0
var shots_hit := 0
var damage_dealt := 0

# достижения
var unlocked := {}       # id -> true (сохраняется)
var toasts := []         # всплывающие уведомления [{text, life}]

var level := {}        # текущая карта
var P := {}            # игрок
var enemies := []
var moving_platforms := []  # движущиеся платформы/лифты
var hazards := []           # ловушки (пилы и т.п.)
var bullets := []
var parts := []
var pickups := []
var texts := []
var muzzles := []        # вспышки выстрела {x,y,ang,life}
var shockwaves := []     # расходящиеся кольца взрывов {x,y,r,max_r,life,col}
var flash := 0.0         # полноэкранная вспышка (0..1)
var flash_color := Color.WHITE
var fade := 0.0          # затемнение перехода уровня (1→0)

# Фон (кэш на уровень)
var th := {}           # цвета темы (Color)
var stars := []        # [Vector3(x,y,size_alpha)]
var hill_far := PackedVector2Array()
var hill_near := PackedVector2Array()
var sky0 := Color.BLACK
var sky1 := Color.BLACK
var sky_tex: GradientTexture2D = null   # кэш градиента неба
var vignette_tex: GradientTexture2D = null  # затемнение по краям экрана
var light_tex: GradientTexture2D = null  # мягкий радиальный «фонарик» для динамического света
var world_env: WorldEnvironment = null   # HDR-bloom (свечение ярких источников)
var bloom_on := true                     # переключатель свечения (в паузе)
var fx_layer: CanvasLayer = null         # слой полноэкранного пост-эффекта (искажения)
var fx_rect: ColorRect = null
var fx_mat: ShaderMaterial = null
var aberration := 0.0                    # хром. аберрация при уроне (затухает)
var ground_tex: ImageTexture = null   # пиксель-текстура камня
var grass_tex: ImageTexture = null    # текстура травянистой кромки
var plat_tex: ImageTexture = null     # текстура односторонней платформы
var crate_tex: ImageTexture = null    # текстура дерева ящика
var _cam_draw := Vector2.ZERO   # текущее смещение камеры в кадре (с тряской)
var afterimages := []  # следы рывка [{x,y,life}]
var ambient := []      # атмосферные частицы по теме (экранное пространство)
var motes := []        # пылинки, ловящие свет (экранное пространство)
var weather := "spores"
var weather_col := Color.WHITE
var hurt_dirs := []    # индикаторы источника урона по краям экрана [{ang, life}]

# Ввод текущего кадра (заполняется gather_input или тестом)
var input := {
	"move": 0, "down": false, "jump_pressed": false, "jump_held": false,
	"shoot_held": false, "shoot_clicked": false, "aim": Vector2.ZERO,
	"switch_to": -1, "wheel": 0, "dash": false, "ult": false,
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
var _music_player: AudioStreamPlayer = null
var _music_cache := {}
var _music_key := ""
var _audio_idx := 0
var _sfx_cache := {}

# ============================== Жизненный цикл ==============================

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	_build_vignette()
	_build_light_tex()
	_build_crate_texture()
	_load_settings()
	if DisplayServer.get_name() != "headless":
		_setup_bloom()
		_setup_fx()
	_apply_volume()
	if not test_mode and DisplayServer.get_name() != "headless":
		_setup_audio()
	else:
		audio_enabled = false
	set_process_unhandled_input(true)
	if "--demo" in OS.get_cmdline_args():
		demo = true
		audio_enabled = "--music" in OS.get_cmdline_args()  # музыку проверяем по флагу
		RenderingServer.frame_post_draw.connect(_on_post_draw)
		if "--menu" in OS.get_cmdline_args():
			return  # остаёмся в меню для проверки его отрисовки
		start_run(12345, "DEMO")
		if "--boss" in OS.get_cmdline_args() or "--airboss" in OS.get_cmdline_args() or "--summoner" in OS.get_cmdline_args():
			# прыжок на боссовый уровень с прокачкой — для проверки рендера босса
			lvl = 5
			if "--airboss" in OS.get_cmdline_args():
				lvl = 10
			elif "--summoner" in OS.get_cmdline_args():
				lvl = 15
			P.weapons.append({ "id": "rifle", "ammo": 999 })
			P.wi = 1
			P.stats.dmg_mul = 3.0
			start_level()
		elif "--guns" in OS.get_cmdline_args():
			# все стволы и уровень с камикадзе — для проверки рендера оружия
			lvl = 4
			for wid in ["smg", "shotgun", "rifle", "grenade", "railgun", "flame"]:
				P.weapons.append({ "id": wid, "ammo": 999 })
			start_level()
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if test_mode:
		return
	if demo:
		_demo_step()
		return
	gather_input()
	sim_step()
	_update_fx()
	queue_redraw()

func _demo_step() -> void:
	# Самоиграющий бот для скриншотов/проверки отрисовки.
	if demo_frame == 100 and "--dead" in OS.get_cmdline_args() and state == "play":
		shots_fired = 40
		shots_hit = 29
		damage_dealt = 1234
		max_combo = 7
		P.inv = 0
		hurt_player(99999, 0)
	if demo_frame == 60 and ("--boss" in OS.get_cmdline_args() or "--airboss" in OS.get_cmdline_args() or "--summoner" in OS.get_cmdline_args()) and state == "play":
		for en in enemies:
			if en.get("boss", false):
				P.x = en.x - 120
				P.y = en.y
	if demo_frame == 88 and "--fx" in OS.get_cmdline_args() and state == "play":
		ult = ULT_MAX
		activate_ult()  # ударная волна + вспышка для скриншота
	if demo_frame == 60 and "--mover" in OS.get_cmdline_args() and state == "play" and moving_platforms.size() > 0:
		var mp = moving_platforms[0]
		P.x = mp.x + mp.w / 2.0 - P.w / 2.0
		P.y = mp.y - P.h
		P.vy = 0.0
	if demo_frame == 86 and "--saw" in OS.get_cmdline_args() and state == "play":
		var sxp: float = P.x + P.w / 2.0 + 60.0
		var syp: float = P.y + P.h / 2.0
		hazards.append({ "type": "saw", "r": 18.0, "cx": sxp, "cy": syp, "ax": 0.0, "ay": 0.0,
			"phase": 0.0, "speed": 0.0, "x": sxp, "y": syp, "spin": 1.0 })
		P.vx = 0.0
		P.inv = 999
	if demo_frame == 70 and "--elite" in OS.get_cmdline_args() and state == "play":
		# делаем ближайших врагов элитными и показываем индикатор урона
		var n := 0
		for en in enemies:
			if en.get("boss", false) or en.type == "shard":
				continue
			en["elite"] = true
			en["mod"] = "swift" if n % 2 == 0 else "armored"
			n += 1
		P.inv = 0
		hurt_player(12, -1, Vector2(P.x - 200, P.y))
	if demo_frame == 5 and "--status" in OS.get_cmdline_args() and state == "play":
		P.stats.burn_chance = 1.0
		P.stats.chill_chance = 1.0
	if demo_frame == 60 and "--pause" in OS.get_cmdline_args() and state == "play":
		_set_state("pause")
	if demo_frame == 50 and "--shop" in OS.get_cmdline_args() and state == "play":
		coins = 50
		open_shop()
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
		input.dash = (demo_frame % 40 == 20)
		input.ult = ult >= ULT_MAX   # бот бьёт ультой по готовности
		input.switch_to = -1
		if "--guns" in OS.get_cmdline_args() and demo_frame % 35 == 0:
			input.switch_to = (P.wi + 1) % P.weapons.size()
	sim_step()
	if state == "upgrade":
		choose_upgrade(offer[0])
	if state == "shop" and not ("--shop" in OS.get_cmdline_args()):
		shop_continue()
	if state == "dead" and not ("--dead" in OS.get_cmdline_args()):
		start_run(12345 + demo_frame, "DEMO")
	_update_fx()
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

func _stick(ax: float, ay: float, dz: float) -> Vector2:
	# вектор стика с мёртвой зоной (нулевой внутри dz)
	var v := Vector2(ax, ay)
	if v.length() < dz:
		return Vector2.ZERO
	return v

func gather_input() -> void:
	# --- геймпад (объединяется с клавиатурой/мышью) ---
	var pad := 0
	var has_pad := Input.get_connected_joypads().size() > 0
	var lstick := _stick(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y), 0.3) if has_pad else Vector2.ZERO
	var rstick := _stick(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y), 0.3) if has_pad else Vector2.ZERO
	var pad_jump := has_pad and Input.is_joy_button_pressed(pad, JOY_BUTTON_A)
	var pad_shoot := has_pad and (Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT) > 0.4 or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER))
	var pad_dash := has_pad and (Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT) > 0.4 or Input.is_joy_button_pressed(pad, JOY_BUTTON_B))
	var pad_ult := has_pad and Input.is_joy_button_pressed(pad, JOY_BUTTON_Y)
	var pad_down := has_pad and (lstick.y > 0.5 or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN))

	var k_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or lstick.x < -0.3 or (has_pad and Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT))
	var k_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or lstick.x > 0.3 or (has_pad and Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT))
	var k_down := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) or pad_down
	var jump_now := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE) or pad_jump
	var shoot_now := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or pad_shoot
	var dash_now := Input.is_key_pressed(KEY_SHIFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or pad_dash
	var ult_now := Input.is_key_pressed(KEY_Q) or pad_ult

	input.move = (1 if k_right else 0) - (1 if k_left else 0)
	input.down = k_down
	input.jump_held = jump_now
	input.jump_pressed = jump_now and not _prev_keys.get("jump", false)
	input.shoot_held = shoot_now
	input.shoot_clicked = shoot_now and not _prev_mouse
	input.dash = dash_now and not _prev_keys.get("dash", false)
	input.ult = ult_now and not _prev_keys.get("ult", false)
	# прицел: правый стик геймпада в приоритете, иначе мышь
	if rstick != Vector2.ZERO:
		input.aim = Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0) + rstick.normalized() * 300.0
	else:
		input.aim = get_local_mouse_position() + cam
	input.switch_to = -1
	for i in range(7):
		if Input.is_key_pressed(KEY_1 + i) and not _prev_keys.get("d%d" % i, false):
			input.switch_to = i
	# смена оружия бамперами геймпада
	if has_pad:
		var lb := Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER)
		if lb and not _prev_keys.get("padlb", false):
			_cycle_weapon(-1)
		_prev_keys["padlb"] = lb

	_prev_keys["jump"] = jump_now
	_prev_keys["dash"] = dash_now
	_prev_keys["ult"] = ult_now
	for i in range(7):
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
				if not audio_enabled:
					_stop_music()
				elif state == "play":
					_play_music((lvl - 1) % 5, boss_alive)
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_volume(volume - 0.1)
			KEY_EQUAL, KEY_KP_ADD:
				set_volume(volume + 0.1)
			KEY_ENTER, KEY_KP_ENTER:
				if state == "menu": start_from_menu()
				elif state == "dead": start_from_menu()
				elif state == "pause": _set_state("play")
				elif state == "shop": shop_continue()
			KEY_SPACE:
				if state == "menu": start_from_menu()
				elif state == "shop": shop_continue()
			KEY_R:
				if state == "menu": start_from_menu()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				var i: int = event.keycode - KEY_1
				if state == "upgrade" and i < offer.size():
					choose_upgrade(offer[i])
				elif state == "shop" and i < shop_items.size():
					buy_shop_item(i)
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
		"shop_continue": shop_continue()
		"toggle_shake": toggle_shake()
		"toggle_bloom": toggle_bloom()
		_:
			if key.begins_with("card"):
				var i := int(key.substr(4))
				if i < offer.size():
					choose_upgrade(offer[i])
			elif key.begins_with("shop"):
				var i := int(key.substr(4))
				if i < shop_items.size():
					buy_shop_item(i)

func _cycle_weapon(d: int) -> void:
	if state != "play" or P.weapons.size() < 2:
		return
	switch_weapon((P.wi + d + P.weapons.size()) % P.weapons.size())

# ============================== Утилиты ==============================

func _rr(r: RandomNumberGenerator, a: int, b: int) -> int:
	return r.randi_range(a, b)

func _pick(r: RandomNumberGenerator, arr: Array):
	return arr[r.randi_range(0, arr.size() - 1)]

var _col_cache := {}
func _col(hex: String) -> Color:
	# мемоизация: не парсим один и тот же hex каждый кадр
	var c = _col_cache.get(hex)
	if c == null:
		c = Color(hex)
		_col_cache[hex] = c
	return c

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
	var lava_cols := {}   # ямы, залитые лавой/кислотой (подмножество spike_cols)
	var x := 8
	var last_pit_end := -99

	while x < W - 10:
		var rv := r.randf()
		if rv < 0.16 and x - last_pit_end > 7 and h + 3 < max_h:
			var pw := _rr(r, 2, 4)
			var depth := _rr(r, 2, 3)
			# с уровнем растёт шанс, что яма — лавовая (опасная зона со светом)
			var is_lava := r.randf() < minf(0.25 + 0.05 * level_num, 0.6)
			var i := 0
			while i < pw and x < W - 10:
				ground_y[x] = h + depth
				spike_cols[x] = true
				if is_lava:
					lava_cols[x] = true
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

	# заливка земли, лавы и шипов
	var lava_cells := []   # центры тайлов лавы (для динамического света)
	for tx in range(W):
		for ty in range(ground_y[tx], H):
			grid[ty * W + tx] = T_SOLID
		if lava_cols.has(tx):
			# поверхность дна ямы — лава; ниже остаётся твёрдый камень
			_setc(grid, W, H, tx, ground_y[tx], T_LAVA)
			lava_cells.append(Vector2(tx * TILE + TILE / 2.0, ground_y[tx] * TILE + TILE / 2.0))
		elif spike_cols.has(tx):
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

	# --- разрушаемые ящики на ровной земле ---
	var crate_hp := {}
	var crate_tries := 6 + level_num * 2
	for _i in range(crate_tries):
		var cxc := _rr(r, 12, W - 12)
		# не у спавна, не у выхода, не на шипах, ровная клетка над землёй свободна
		if cxc < 8 or cxc > W - 8 or spike_cols.has(cxc):
			continue
		var cyc: int = ground_y[cxc] - 1
		if cyc < 4 or _cell(grid, W, H, cxc, cyc) != T_EMPTY:
			continue
		_setc(grid, W, H, cxc, cyc, T_CRATE)
		crate_hp[cyc * W + cxc] = 24

	# --- движущиеся платформы/лифты в открытых местах ---
	var movers := []
	var mover_tries := 4 + level_num
	for _i in range(mover_tries):
		if movers.size() >= 1 + int(level_num / 2.0):
			break
		var mx := _rr(r, 16, W - 16)
		var my: int = ground_y[mx] - _rr(r, 4, 8)
		if my < 4:
			continue
		var horizontal := r.randf() < 0.6
		var amp_t := _rr(r, 2, 4)   # амплитуда в тайлах
		var plen := _rr(r, 2, 3)    # длина платформы в тайлах
		# проверяем, что коридор движения свободен
		var clear := true
		var lo: int = mx - (amp_t if horizontal else 0) - 1
		var hi: int = mx + (amp_t if horizontal else 0) + plen
		var top: int = my - (amp_t if not horizontal else 0) - 1
		var bot: int = my + (amp_t if not horizontal else 0) + 1
		for ty in range(max(0, top), min(H, bot + 1)):
			for tx in range(max(0, lo), min(W, hi + 1)):
				if _cell(grid, W, H, tx, ty) != T_EMPTY:
					clear = false
					break
			if not clear:
				break
		if not clear:
			continue
		var cx_px := mx * TILE
		var cy_px := my * TILE
		movers.append({
			"w": plen * TILE, "h": 10,
			"cx": float(cx_px), "cy": float(cy_px),
			"ax": (amp_t * TILE if horizontal else 0.0),
			"ay": (0.0 if horizontal else amp_t * TILE),
			"phase": r.randf() * TAU, "speed": 0.018 + r.randf() * 0.018,
			"x": float(cx_px), "y": float(cy_px), "dx": 0.0, "dy": 0.0,
		})

	# --- пилы-ловушки в открытых коридорах (с уровня 2) ---
	var hazards := []
	if level_num >= 2:
		var haz_tries := 5 + level_num
		var haz_max := mini(1 + int(level_num / 3.0), 4)
		for _i in range(haz_tries):
			if hazards.size() >= haz_max:
				break
			var hx := _rr(r, 16, W - 16)
			var hy: int = ground_y[hx] - _rr(r, 1, 5)
			if hy < 4:
				continue
			var horiz := r.randf() < 0.5
			var amp := _rr(r, 2, 5)
			var lo2: int = hx - (amp if horiz else 0) - 1
			var hi2: int = hx + (amp if horiz else 0) + 1
			var top2: int = hy - (amp if not horiz else 0) - 1
			var bot2: int = hy + (amp if not horiz else 0) + 1
			var ok := true
			for ty in range(max(0, top2), min(H, bot2 + 1)):
				for tx in range(max(0, lo2), min(W, hi2 + 1)):
					if _cell(grid, W, H, tx, ty) != T_EMPTY:
						ok = false
						break
				if not ok:
					break
			if not ok:
				continue
			var hcx := hx * TILE + TILE / 2.0
			var hcy := hy * TILE + TILE / 2.0
			hazards.append({
				"type": "saw", "r": 16.0,
				"cx": hcx, "cy": hcy,
				"ax": (amp * TILE if horiz else 0.0),
				"ay": (0.0 if horiz else amp * TILE),
				"phase": r.randf() * TAU, "speed": 0.02 + r.randf() * 0.02,
				"x": hcx, "y": hcy, "spin": r.randf() * TAU,
			})

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
				# ровно, без шипов и без ящика над землёй
				if spike_cols.has(sx + j) or ground_y[sx + j] != ground_y[sx] or _cell(grid, W, H, sx + j, ground_y[sx + j] - 1) == T_CRATE:
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
			"charge": 0, "aimx": 0.0, "aimy": 0.0,
		})

	var is_boss_level := level_num % 5 == 0
	var crowd := 0.5 if is_boss_level else 1.0   # на боссах меньше рядовых
	var counts := {
		"walker": int(mini(4 + level_num, 12) * crowd),
		"shooter": int(mini(1 + int(level_num * 0.8), 8) * crowd),
		"flyer": int((mini(1 + level_num, 9) if level_num >= 2 else 0) * crowd),
		"tank": int((mini(level_num - 2, 5) if level_num >= 3 else 0) * crowd),
		"exploder": int((mini(1 + int((level_num - 1) / 2.0), 5) if level_num >= 2 else 0) * crowd),
		"splitter": int((mini(1 + int((level_num - 1) / 2.0), 4) if level_num >= 2 else 0) * crowd),
		"sniper": int((mini(1 + int((level_num - 2) / 2.0), 4) if level_num >= 3 else 0) * crowd),
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

	# --- босс на каждом 5-м уровне (чередуем наземного и летающего) ---
	if is_boss_level:
		var bb: Dictionary = ENEMY_BASE["boss"]
		# три варианта босса по кругу: наземный (ур.5), летающий (10), призыватель (15)
		var bvi := (int(level_num / 5) - 1) % 3
		var boss_variant: String = ["ground", "air", "summoner"][bvi]
		var bspan := 3
		var bx := -1
		# ровная площадка ближе к выходу
		for cand in range(W - 16, 14, -1):
			var flat := true
			for j in range(bspan):
				if spike_cols.has(cand + j) or ground_y[cand + j] != ground_y[cand] or _cell(grid, W, H, cand + j, ground_y[cand + j] - 1) == T_CRATE:
					flat = false
					break
			if flat:
				bx = cand
				break
		if bx < 0:
			bx = W - 20
		var boss_hp := 500 + 90 * level_num
		var by: float = ground_y[bx] * TILE - bb.h - 1
		if boss_variant == "air" or boss_variant == "summoner":
			# парящие боссы держатся над землёй
			by = max(2 * TILE, ground_y[bx] * TILE - 7 * TILE)
		enemy_list.append({
			"type": "boss", "boss": true, "variant": boss_variant,
			"x": bx * TILE, "y": by, "w": bb.w, "h": bb.h,
			"hp": boss_hp, "maxhp": boss_hp,
			"vx": 0.0, "vy": 0.0, "dir": -1,
			"spd": bb.spd, "dmg": bb.dmg + dmg_add, "score": bb.score,
			"fly": boss_variant != "ground", "cd": 90, "cd_max": bb.cd,
			"hurt_t": 0, "phase": 0.0, "atk": 0, "atk_t": 120,
			"on_ground": false, "hit_wall": false, "drop": 0, "dead": false,
		})

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
	# щит время от времени (чаще на поздних уровнях)
	if r.randf() < 0.4 + 0.06 * level_num:
		var s = spot.call()
		if s != null:
			add_pick.call("shield", s, { "shield": 20.0, "w": 20, "h": 20 })
	# на боссовых уровнях — дополнительные аптечки и патроны
	if is_boss_level:
		for _i in range(2):
			var s = spot.call()
			if s != null:
				add_pick.call("med", s, { "heal": 30 })
		for _i in range(2):
			var s = spot.call()
			if s != null:
				add_pick.call("ammo", s, {})

	# уникальные id врагов — для дедупликации попаданий пробивающего оружия
	for i in range(enemy_list.size()):
		enemy_list[i]["eid"] = i

	# элитные враги с модификаторами (не боссы/осколки)
	var elite_chance := clampf(0.05 + 0.02 * level_num, 0.0, 0.30)
	for en in enemy_list:
		if en.get("boss", false) or en.type == "shard":
			continue
		if r.randf() >= elite_chance:
			continue
		var mod := "swift" if r.randf() < 0.5 else "armored"
		en["elite"] = true
		en["mod"] = mod
		en.hp = int(round(en.hp * 2.2))
		en.maxhp = en.hp
		en.score = int(en.score * 2)
		en.dmg = int(round(en.dmg * 1.2))
		if mod == "swift":
			en.spd *= 1.6
			if en.cd_max > 0:
				en.cd_max = int(en.cd_max * 0.7)

	# нормализуем поля статусов (база скорости — после элитных модификаторов)
	for en in enemy_list:
		en["base_spd"] = en.spd
		en["burn"] = 0
		en["chill"] = 0

	return {
		"W": W, "H": H, "grid": grid, "ground_y": ground_y,
		"theme": THEMES[(level_num - 1) % THEMES.size()],
		"px_w": W * TILE, "px_h": H * TILE,
		"spawn": Vector2(2 * TILE + 6, ground_y[2] * TILE - 31),
		"exit_px": exit_px, "enemies": enemy_list, "pickups": pickup_list,
		"has_boss": is_boss_level, "crate_hp": crate_hp, "movers": movers, "hazards": hazards,
		"lava_cells": lava_cells,
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

func is_blocking(t: int) -> bool:
	# твёрдые для движения тайлы: камень и разрушаемый ящик
	return t == T_SOLID or t == T_CRATE

func solid_px(px: float, py: float) -> bool:
	return is_blocking(tile_at(int(floor(px / TILE)), int(floor(py / TILE))))

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
			if is_blocking(tile_at(tx, ty)):
				e.x = tx * TILE - e.w
				e.vx = 0.0
				e.hit_wall = true
				break
	elif e.vx < 0:
		var tx := int(floor(e.x / TILE))
		for ty in range(y0, y1 + 1):
			if is_blocking(tile_at(tx, ty)):
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
			if is_blocking(t) or (t == T_PLAT and prev_bottom <= ty * TILE + 0.5 and e.drop <= 0):
				e.y = ty * TILE - e.h
				e.vy = 0.0
				e.on_ground = true
				break
	elif e.vy < 0:
		var ty := int(floor(e.y / TILE))
		for tx in range(x0, x1 + 1):
			if is_blocking(tile_at(tx, ty)):
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
		if is_blocking(t):
			return false
		if t == T_PLAT:
			plat = true
	return plat

# ============================== Запуск забега / уровня ==============================

func _next_eid() -> int:
	_eid_counter += 1
	return _eid_counter

func _spawn_enemy(type: String, sx: float, sy: float) -> Dictionary:
	# создание врага в рантайме (осколки делящегося и т.п.)
	var b: Dictionary = ENEMY_BASE[type]
	var hp_mul := 1.0 + 0.25 * (lvl - 1)
	var dmg_add := 2 * (lvl - 1)
	return {
		"type": type, "x": sx, "y": sy, "w": b.w, "h": b.h,
		"hp": roundi(b.hp * hp_mul), "maxhp": roundi(b.hp * hp_mul),
		"vx": 0.0, "vy": 0.0, "dir": (-1 if rng.randf() < 0.5 else 1),
		"spd": b.spd, "base_spd": b.spd, "dmg": b.dmg + dmg_add, "score": b.score,
		"fly": b.fly, "cd": 0, "cd_max": b.get("cd", 0),
		"hurt_t": 0, "phase": rng.randf() * TAU, "burn": 0, "chill": 0,
		"on_ground": false, "hit_wall": false, "drop": 0, "dead": false,
		"charge": 0, "aimx": 0.0, "aimy": 0.0, "eid": _next_eid(),
	}

func make_player() -> Dictionary:
	return {
		"x": 0.0, "y": 0.0, "w": 20, "h": 30, "vx": 0.0, "vy": 0.0,
		"hp": 100.0, "maxhp": 100.0,
		"on_ground": false, "hit_wall": false,
		"coyote": 0, "buffer": 0, "air_jumps": 0, "drop": 0,
		"inv": 0, "cd": 0, "face": 1, "aim": 0.0,
		"dash_cd": 0, "dash_t": 0, "dash_dir": 1.0, "squash": 0.0,
		"shield": 0.0, "max_shield": 0.0, "ride_id": -1,
		"weapons": [{ "id": "pistol", "ammo": INF }], "wi": 0,
		"stats": {
			"dmg_mul": 1.0, "cd_mul": 1.0, "spd_mul": 1.0, "jumps": 1, "lifesteal": 0,
			"armor_mul": 1.0, "crit": 0.0, "jump_mul": 1.0,
			"shield_regen": 0.0, "dash_cd_mul": 1.0, "blast_mul": 1.0, "magnet_range": 90.0, "berserk": 0.0,
			"burn_chance": 0.0, "chill_chance": 0.0,
		},
	}

func start_from_menu() -> void:
	var s := rng.randi() & 0xFFFFFFFF
	start_run(s, str(s))

func start_run(s: int, label: String) -> void:
	run_seed = s & 0xFFFFFFFF
	seed_label = label if label != "" else str(run_seed)
	lvl = 1
	score = 0
	coins = 0
	ult = 0.0
	kills = 0
	max_combo = 0
	run_ticks = 0
	shots_fired = 0
	shots_hit = 0
	damage_dealt = 0
	P = make_player()
	start_level()
	_set_state("play")

func accuracy() -> float:
	return 0.0 if shots_fired == 0 else clampf(float(shots_hit) / shots_fired, 0.0, 1.0)

func start_level() -> void:
	var level_seed := (run_seed ^ ((lvl * 2654435761) & 0xFFFFFFFF)) & 0xFFFFFFFF
	level = generate_level(level_seed, lvl)
	enemies = level.enemies
	pickups = level.pickups
	moving_platforms = level.get("movers", [])
	hazards = level.get("hazards", [])
	bullets = []
	parts = []
	texts = []
	afterimages = []
	hurt_dirs = []
	muzzles = []
	shockwaves = []
	fade = 1.0  # уровень плавно проявляется из затемнения
	P.x = level.spawn.x
	P.y = level.spawn.y
	P.vx = 0.0
	P.vy = 0.0
	P.cd = 0
	P.inv = 90
	P.drop = 0
	P.dash_t = 0
	P.dash_cd = 0
	combo = 0
	combo_t = 0
	hitstop = 0
	if not test_mode:
		Engine.time_scale = 1.0   # на всякий случай снимаем замедление при старте уровня
	boss_alive = level.get("has_boss", false)
	boss_name = ""
	if boss_alive:
		for en in enemies:
			if en.get("boss", false):
				boss_name = { "ground": "СТРАЖ ЗЕМЛИ", "air": "НЕБЕСНЫЙ СТРАЖ", "summoner": "ПРИЗЫВАТЕЛЬ" }.get(en.get("variant", "ground"), "БОСС")
				break
	cam.x = clampf(P.x - VW / 2.0, 0, max(0, level.px_w - VW))
	cam.y = clampf(P.y - VH / 2.0, 0, max(0, level.px_h - VH))
	shake = 0.0
	intro = 150
	if boss_alive:
		intro_text = "Уровень %d — %s" % [lvl, boss_name]
	else:
		intro_text = "Уровень %d — %s" % [lvl, level.theme.name]
	_build_background(level_seed)
	_play_music((lvl - 1) % 5, boss_alive)

func _set_state(s: String) -> void:
	state = s
	if not test_mode and (s == "menu" or s == "dead" or s == "play"):
		Engine.time_scale = 1.0   # снимаем слоу-мо при смене состояния
	if s == "menu":
		_stop_music()
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

func apply_upgrade_stats(u: Dictionary) -> void:
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
		"shieldup":
			P.max_shield += 30
			P.shield = min(P.max_shield, P.shield + 30)
			st.shield_regen += 0.06
		"dashcd": st.dash_cd_mul *= 0.7
		"blast": st.blast_mul *= 1.4
		"magnet": st.magnet_range += 90.0
		"berserk": st.berserk += 0.5
		"incend": st.burn_chance = min(0.9, st.burn_chance + 0.35)
		"cryo": st.chill_chance = min(0.9, st.chill_chance + 0.35)

func choose_upgrade(u: Dictionary) -> void:
	apply_upgrade_stats(u)
	play_sfx("select")
	lvl += 1
	# перед некоторыми уровнями — магазин за монеты
	if is_shop_level(lvl):
		open_shop()
	else:
		start_level()
		_set_state("play")

func is_shop_level(level_num: int) -> bool:
	return level_num % 3 == 0

func open_shop() -> void:
	shop_items = build_shop()
	_set_state("shop")

func build_shop() -> Array:
	var items := [
		{ "id": "heal", "icon": "♥", "name": "Аптечка", "desc": "+50 здоровья", "price": 8, "sold": false },
		{ "id": "ammo", "icon": "▭", "name": "Боезапас", "desc": "Патроны всему оружию", "price": 6, "sold": false },
		{ "id": "shield", "icon": "▢", "name": "Щит", "desc": "+30 к запасу щита", "price": 12, "sold": false },
		{ "id": "weapon", "icon": "▸", "name": "Оружие", "desc": "Случайный новый ствол", "price": 16, "sold": false, "weapon": pick_rng(WEAPON_DROPS) },
		{ "id": "upgrade", "icon": "★", "name": "Улучшение", "desc": "Случайная прокачка", "price": 20, "sold": false, "up": _random_upgrade() },
	]
	return items

func pick_rng(arr: Array):
	return arr[rng.randi_range(0, arr.size() - 1)]

func _random_upgrade() -> Dictionary:
	return UPGRADES[rng.randi_range(0, UPGRADES.size() - 1)]

func buy_shop_item(i: int) -> void:
	if i < 0 or i >= shop_items.size():
		return
	var it: Dictionary = shop_items[i]
	if it.sold or coins < it.price:
		return
	coins -= it.price
	it.sold = true
	match it.id:
		"heal": P.hp = min(P.maxhp, P.hp + 50)
		"ammo": _refill_all_ammo()
		"shield":
			P.max_shield += 30
			P.shield = min(P.max_shield, P.shield + 30)
		"weapon": give_weapon(it.weapon)
		"upgrade": apply_upgrade_stats(it.up)
	play_sfx("pickup")

func _refill_all_ammo() -> void:
	for slot in P.weapons:
		if is_finite(slot.ammo):
			slot.ammo += WEAPONS[slot.id].ammo

func shop_continue() -> void:
	start_level()
	_set_state("play")

func level_clear() -> void:
	score += 100 + lvl * 25
	score += 100 + lvl * 25
	play_sfx("portal")
	offer_upgrades()

# ============================== Урон и смерть ==============================

func hurt_player(dmg: float, from_dir: float, src := Vector2.INF) -> void:
	if P.inv > 0 or state != "play":
		return
	var real: int = max(1, roundi(dmg * P.stats.armor_mul))
	P.inv = 55
	P.vx = clampf(P.vx + from_dir * 4.0, -8, 8)
	P.vy = min(P.vy, -4.0)
	shake = min(14.0, shake + 7.0)
	aberration = min(1.0, aberration + 0.9)
	play_sfx("hurt")
	# индикатор направления источника урона
	var ang: float
	if src.x != INF:
		ang = (src - Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0)).angle()
	else:
		ang = 0.0 if from_dir >= 0 else PI
	hurt_dirs.append({ "ang": ang, "life": 40.0 })
	# щит поглощает урон первым
	if P.shield > 0:
		var absorbed: int = int(min(P.shield, real))
		P.shield -= absorbed
		real -= absorbed
		add_text(P.x + P.w / 2.0, P.y - 14, "щит -%d" % absorbed, Color("#7fd4ff"))
		burst(P.x + P.w / 2.0, P.y + P.h / 2.0, 8, Color("#7fd4ff"))
	if real > 0:
		P.hp -= real
		add_text(P.x + P.w / 2.0, P.y - 6, "-%d" % real, Color("#ff6b5e"))
		burst(P.x + P.w / 2.0, P.y + P.h / 2.0, 8, Color("#ff6b5e"))
	if P.hp <= 0:
		P.hp = 0
		die()

func die() -> void:
	burst(P.x + P.w / 2.0, P.y + P.h / 2.0, 30, Color("#ff6b5e"))
	play_sfx("die")
	check_achievements()  # финальная проверка (точность/время/очки)
	if score > best:
		best = score
		_save_best(best)
	_stop_music()
	_set_state("dead")

func activate_ult() -> void:
	# «Перегрузка»: ударная волна, чистит вражеские пули, даёт i-кадры
	var cx: float = P.x + P.w / 2.0
	var cy: float = P.y + P.h / 2.0
	P.inv = max(P.inv, 40)
	shake = min(24.0, shake + 16.0)
	hitstop = 6
	burst(cx, cy, 50, Color("#9be8ff"))
	burst(cx, cy, 30, Color("#ffffff"))
	shockwaves.append({ "x": cx, "y": cy, "r": 10.0, "max_r": 200.0, "life": 22.0, "col": Color("#9be8ff") })
	flash = 0.6
	flash_color = Color("#9be8ff")
	play_sfx("portal")
	# урон и отбрасывание врагов в радиусе
	var radius := 200.0
	for en in enemies:
		if en.dead:
			continue
		var d := Vector2(en.x + en.w / 2.0 - cx, en.y + en.h / 2.0 - cy)
		if d.length() <= radius:
			hurt_enemy(en, 80, true)
			if not en.dead:
				var dir := d.normalized()
				en.vx += dir.x * 8.0
				en.vy += dir.y * 6.0 - 3.0
	# развеиваем вражеские пули поблизости
	var kept := []
	for b in bullets:
		if b.from == "e" and Vector2(b.x - cx, b.y - cy).length() <= radius:
			continue
		kept.append(b)
	bullets = kept
	ult = 0.0  # сброс после нанесения урона (чтобы урон волны не перезаряжал ульту)

func _roll_bullet_status(en: Dictionary) -> void:
	if en.dead:
		return
	if P.stats.burn_chance > 0 and rng.randf() < P.stats.burn_chance:
		apply_burn(en, 96)
	if P.stats.chill_chance > 0 and rng.randf() < P.stats.chill_chance:
		apply_chill(en, 120)

func apply_burn(en: Dictionary, ticks: int) -> void:
	en["burn"] = max(int(en.get("burn", 0)), ticks)

func apply_chill(en: Dictionary, ticks: int) -> void:
	en["chill"] = max(int(en.get("chill", 0)), ticks)

func hurt_enemy(en: Dictionary, dmg: int, crit: bool, silent := false) -> void:
	# элита-бронежилет снижает входящий урон
	if en.get("mod", "") == "armored":
		dmg = max(1, int(round(dmg * 0.6)))
	en.hp -= dmg
	en.hurt_t = 90
	damage_dealt += dmg
	ult = min(ULT_MAX, ult + dmg)  # урон заряжает ультимейт
	if not silent:
		add_text(en.x + en.w / 2.0, en.y - 4, str(dmg), Color("#ffd86b") if crit else Color.WHITE)
		burst(en.x + en.w / 2.0, en.y + en.h / 2.0, 7 if crit else 4, Color("#ffd1a8"))
		play_sfx("hit")
	if en.hp <= 0:
		en.dead = true
		kills += 1
		# серия убийств наращивает множитель очков
		combo += 1
		combo_t = 150
		max_combo = max(max_combo, combo)
		var mult := combo_mult()
		var gained: int = int(round(en.score * mult))
		score += gained
		if P.stats.lifesteal > 0:
			P.hp = min(P.maxhp, P.hp + P.stats.lifesteal)
		burst(en.x + en.w / 2.0, en.y + en.h / 2.0, 16, Color("#ff9d6b"))
		if not en.get("boss", false):
			shockwaves.append({ "x": en.x + en.w / 2.0, "y": en.y + en.h / 2.0, "r": 4.0, "max_r": en.w * 1.3, "life": 10.0, "col": Color("#ffd1a8") })
		var label := "+%d" % gained
		if mult > 1.0:
			label += " x%.1f" % mult
		add_text(en.x + en.w / 2.0, en.y - 14, label, Color("#9be8ff"))
		play_sfx("kill")
		if en.get("boss", false):
			boss_alive = false
			score += 500
			hitstop = 24
			shake = 16.0
			_start_slowmo(0.32, 0.75)   # эффектное замедление времени при гибели босса
			burst(en.x + en.w / 2.0, en.y + en.h / 2.0, 60, Color("#ffd86b"))
			shockwaves.append({ "x": en.x + en.w / 2.0, "y": en.y + en.h / 2.0, "r": 12.0, "max_r": 160.0, "life": 26.0, "col": Color("#ffd86b") })
			flash = 0.7
			flash_color = Color("#ffe9b0")
			add_text(en.x + en.w / 2.0, en.y - 30, "БОСС ПОВЕРЖЕН! +500", Color("#ffd86b"))
			play_sfx("portal")
			unlock("boss_slayer")
		elif en.get("type", "") == "exploder":
			explode(en.x + en.w / 2.0, en.y + en.h / 2.0, en.get("radius", 62), int(round(en.dmg * 0.8)), "e")
		else:
			drop_loot(en)
			if en.get("type", "") == "splitter":
				_spawn_shards(en)
		# элита всегда роняет дополнительный лут (монеты + гарантированный предмет)
		if en.get("elite", false):
			var ecx: float = en.x + en.w / 2.0
			for _c in range(rng.randi_range(2, 4)):
				pickups.append({ "kind": "coin", "x": ecx - 6, "y": en.y, "w": 12, "h": 12, "vy": -3.0 - rng.randf() * 2.0, "t": 0.0 })
			if rng.randf() < 0.5:
				pickups.append({ "kind": "med", "x": ecx - 11, "y": en.y, "w": 22, "h": 18, "vy": -3.0, "t": 0.0, "heal": 20 })
			else:
				pickups.append({ "kind": "shield", "x": ecx - 10, "y": en.y, "w": 20, "h": 20, "vy": -3.0, "t": 0.0, "shield": 20.0 })

func _spawn_shards(en: Dictionary) -> void:
	# делящийся враг распадается на два быстрых осколка
	var cx: float = en.x + en.w / 2.0
	for s in [-1, 1]:
		var sh := _spawn_enemy("shard", cx + s * 10 - 7, en.y)
		sh.dir = s
		sh.vx = s * 2.0
		sh.vy = -3.0
		enemies.append(sh)
	burst(cx, en.y + en.h / 2.0, 10, Color("#d06be0"))

func explode(x: float, y: float, radius: float, dmg: int, from: String) -> void:
	# улучшение «Сапёр» усиливает взрывы игрока
	if from == "p" and not P.is_empty():
		radius *= P.stats.blast_mul
		dmg = int(round(dmg * P.stats.blast_mul))
	burst(x, y, 26, Color("#ffd06b"))
	burst(x, y, 14, Color("#ff7a4d"))
	shockwaves.append({ "x": x, "y": y, "r": 8.0, "max_r": radius, "life": 16.0, "col": Color("#ffd06b") })
	shake = min(20.0, shake + 9.0)
	play_sfx("boom")
	var c := Vector2(x, y)
	if from == "p":
		for en in enemies:
			if en.dead:
				continue
			if Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0).distance_to(c) <= radius:
				hurt_enemy(en, dmg, false)
				if not en.dead:
					apply_burn(en, 80)  # взрывы поджигают
	else:
		if P.inv <= 0 and state == "play" and Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0).distance_to(c) <= radius:
			hurt_player(dmg, 1 if P.x + P.w / 2.0 > x else -1, c)
	# взрывы крушат ящики в радиусе
	var crates: Dictionary = level.get("crate_hp", {})
	if not crates.is_empty():
		var to_break := []
		for idx in crates.keys():
			var ctx: int = idx % level.W
			var cty: int = idx / level.W
			var cc := Vector2(ctx * TILE + TILE / 2.0, cty * TILE + TILE / 2.0)
			if cc.distance_to(c) <= radius + TILE * 0.5:
				to_break.append(Vector2i(ctx, cty))
		for cell in to_break:
			damage_crate(cell.x, cell.y, dmg)

func damage_crate(tx: int, ty: int, dmg: int) -> void:
	if level.is_empty():
		return
	var crates: Dictionary = level.get("crate_hp", {})
	var idx: int = ty * level.W + tx
	if not crates.has(idx):
		return
	crates[idx] -= dmg
	var px := tx * TILE + TILE / 2.0
	var py := ty * TILE + TILE / 2.0
	burst(px, py, 4, _col(level.theme.top))
	if crates[idx] <= 0:
		crates.erase(idx)
		level.grid[idx] = T_EMPTY
		burst(px, py, 14, Color("#c79a5b"))
		burst(px, py, 8, _col(level.theme.top))
		play_sfx("hit")
		# из ящика выпадает лут
		var rv := rng.randf()
		if rv < 0.4:
			pickups.append({ "kind": "coin", "x": px - 6, "y": py - 6, "w": 12, "h": 12, "vy": -3.0, "t": 0.0 })
		elif rv < 0.7:
			pickups.append({ "kind": "ammo", "x": px - 11, "y": py - 9, "w": 22, "h": 18, "vy": -2.5, "t": 0.0 })
		elif rv < 0.85:
			pickups.append({ "kind": "med", "x": px - 11, "y": py - 9, "w": 22, "h": 18, "vy": -2.5, "t": 0.0, "heal": 20 })

func combo_mult() -> float:
	# x1.0 при серии 0–2, далее растёт до x4.0
	return clampf(1.0 + max(0, combo - 2) * 0.25, 1.0, 4.0)

# ============================== Движущиеся платформы ==============================

func update_moving_platforms() -> void:
	for mp in moving_platforms:
		mp.phase += mp.speed
		var nx: float = mp.cx + sin(mp.phase) * mp.ax
		var ny: float = mp.cy + sin(mp.phase) * mp.ay
		mp.dx = nx - mp.x
		mp.dy = ny - mp.y
		mp.x = nx
		mp.y = ny

func update_hazards() -> void:
	for hz in hazards:
		hz.phase += hz.speed
		hz.spin += 0.3
		hz.x = hz.cx + sin(hz.phase) * hz.ax
		hz.y = hz.cy + sin(hz.phase) * hz.ay

func check_hazards() -> void:
	# пила ранит игрока при касании
	if P.inv > 0 or state != "play":
		return
	var pc := Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0)
	var pr: float = max(P.w, P.h) / 2.0
	for hz in hazards:
		if Vector2(hz.x, hz.y).distance_to(pc) <= hz.r + pr:
			hurt_player(18, 1 if pc.x > hz.x else -1, Vector2(hz.x, hz.y))
			break

func ride_moving_platforms() -> void:
	# односторонние платформы: приземление сверху + перенос игрока
	var was: int = P.ride_id
	P.ride_id = -1
	for i in range(moving_platforms.size()):
		var mp: Dictionary = moving_platforms[i]
		if P.x + P.w <= mp.x or P.x >= mp.x + mp.w:
			continue
		var feet: float = P.y + P.h
		var prev_feet: float = feet - P.vy
		var landing: bool = P.vy >= 0.0 and feet >= mp.y - 2.0 and prev_feet <= mp.y + 6.0
		var continuing: bool = was == i and feet >= mp.y - 8.0 and feet <= mp.y + mp.h
		if landing or continuing:
			P.y = mp.y - P.h
			if P.vy > 0.0:
				P.vy = 0.0
			P.on_ground = true
			P.coyote = 7
			P.air_jumps = P.stats.jumps - 1
			P.x += mp.dx
			P.ride_id = i
			break

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
	elif rv < 0.50:
		pickups.append({ "kind": "shield", "x": cx, "y": cy, "w": 20, "h": 20, "vy": -3.0, "t": 0.0, "shield": 20.0 })

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
	# огнемёт: конусный урон + поджог + частицы пламени (без пуль)
	if w.get("flame", false):
		var fdmg: int = max(1, roundi(w.dmg * P.stats.dmg_mul))
		var hit_any := false
		for en in enemies:
			if en.dead:
				continue
			var ev := Vector2(en.x + en.w / 2.0 - cx, en.y + en.h / 2.0 - cy)
			if ev.length() <= w.range and absf(wrapf(ev.angle() - angle, -PI, PI)) <= w.cone:
				hurt_enemy(en, fdmg, false, true)
				if not en.dead:
					apply_burn(en, 64)
				hit_any = true
		for _f in range(4):
			var fa: float = angle + (rng.randf() - 0.5) * w.cone * 2.0
			var fs := 3.0 + rng.randf() * 5.0
			var fc := Color("#ffd86b") if rng.randf() < 0.4 else Color("#ff6a2d")
			parts.append({ "x": cx + cos(angle) * 14, "y": cy + sin(angle) * 14,
				"vx": cos(fa) * fs + P.vx * 0.3, "vy": sin(fa) * fs, "life": 7.0 + rng.randf() * 8.0,
				"color": fc, "size": 2.0 + rng.randf() * 2.5, "grav": -0.04 })
		shots_fired += 1
		if hit_any:
			shots_hit += 1
		P.vx = clampf(P.vx - cos(angle) * 0.2, -9, 9)
		if tick % 4 == 0:
			play_sfx("flame")
		return
	var is_gren: bool = w.get("gren", false)
	var is_pierce: bool = w.get("pierce", false)
	# «Берсерк»: бонус к урону растёт с серией убийств (до +40% при серии 20)
	var berserk_bonus: float = 1.0 + P.stats.berserk * mini(combo, 20) * 0.02
	for _i in range(w.pellets):
		var a: float = angle + (rng.randf() - 0.5) * 2.0 * w.spread
		var crit: bool = rng.randf() < P.stats.crit
		var dmg: int = max(1, roundi(w.dmg * P.stats.dmg_mul * berserk_bonus * (2.0 if crit else 1.0)))
		var b := {
			"x": cx + cos(a) * 16, "y": cy + sin(a) * 16,
			"vx": cos(a) * w.spd, "vy": sin(a) * w.spd,
			"dmg": dmg, "crit": crit, "from": "p", "life": 90, "color": _col(w.color),
		}
		if is_gren:
			b["grenade"] = true
			b["radius"] = w.radius
			b["life"] = w.fuse
		if is_pierce:
			b["pierce"] = true
			b["hit_ids"] = []
		bullets.append(b)
		shots_fired += 1
	P.vx = clampf(P.vx - cos(angle) * w.kick * 0.35, -9, 9)
	shake = min(12.0, shake + w.kick * 0.55)
	burst(cx + cos(angle) * 18, cy + sin(angle) * 18, 3, Color("#fff2b0"))
	muzzles.append({ "x": cx + cos(angle) * 17, "y": cy + sin(angle) * 17, "ang": angle, "life": 5.0, "len": w.len })
	if slot.id == "shotgun" or is_gren:
		play_sfx("shotgun")
	elif slot.id == "rifle" or is_pierce:
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

func spark(x: float, y: float, vx: float, vy: float, n: int) -> void:
	# искры от удара пули: летят назад от поверхности с разбросом
	var base := atan2(-vy, -vx)
	for _i in range(n):
		var a := base + (rng.randf() - 0.5) * 1.4
		var s := 2.0 + rng.randf() * 4.0
		var bright := Color("#fff0c0") if rng.randf() < 0.5 else Color("#ffc24d")
		parts.append({
			"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s,
			"life": 8.0 + rng.randf() * 12.0, "color": bright,
			"size": 1.0 + rng.randf() * 1.8, "grav": 0.22,
		})

func add_text(x: float, y: float, s: String, color: Color) -> void:
	texts.append({ "x": x, "y": y, "str": s, "color": color, "life": 55.0, "vy": -0.8 })

# ============================== Шаг симуляции ==============================

func sim_step() -> void:
	tick += 1
	if state == "play":
		if hitstop > 0:
			hitstop -= 1
			update_effects()
			return
		run_ticks += 1
		update_moving_platforms()
		update_hazards()
		update_player()
		if state == "play":
			update_enemies()
			update_bullets()
			update_pickups()
		update_effects()
		update_ambient()
		update_camera()
		# затухание серии убийств
		if combo_t > 0:
			combo_t -= 1
			if combo_t == 0:
				combo = 0
		if intro > 0:
			intro -= 1
		if state == "play":
			check_achievements()

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

	# рывок: быстрый рывок с i-кадрами и следами
	if P.dash_cd > 0:
		P.dash_cd -= 1
	if P.dash_t > 0:
		P.dash_t -= 1
		P.vx = P.dash_dir * 9.5
		P.vy = 0.0
		P.inv = max(P.inv, 2)
		afterimages.append({ "x": P.x, "y": P.y, "life": 12.0 })
	elif input.dash and P.dash_cd <= 0:
		P.dash_t = 11
		P.dash_cd = int(round(55 * st.dash_cd_mul))
		P.dash_dir = float(input.move) if input.move != 0 else float(P.face)
		P.inv = max(P.inv, 12)
		play_sfx("dash")
		afterimages.append({ "x": P.x, "y": P.y, "life": 12.0 })

	# восстановление щита (если есть улучшение)
	if st.shield_regen > 0 and P.max_shield > 0 and P.shield < P.max_shield:
		P.shield = min(P.max_shield, P.shield + st.shield_regen)

	var was_grounded: bool = P.on_ground
	var pre_vy: float = P.vy
	collide_entity(P)
	ride_moving_platforms()
	check_hazards()
	# пыль при приземлении после падения
	if P.on_ground and not was_grounded and pre_vy > 4.5:
		P.squash = minf(1.0, pre_vy / 13.0)   # присед тем сильнее, чем жёстче падение
		for _i in range(5):
			var sx := (rng.randf() - 0.5) * 4.0
			parts.append({ "x": P.x + P.w / 2.0 + (rng.randf() - 0.5) * P.w, "y": P.y + P.h,
				"vx": sx, "vy": -rng.randf() * 1.2, "life": 12.0 + rng.randf() * 8.0,
				"color": Color(0.8, 0.82, 0.7, 0.5), "size": 1.5 + rng.randf() * 2.0, "grav": 0.05 })

	P.aim = (input.aim - Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0)).angle()
	aim_angle = P.aim
	P.face = 1 if cos(P.aim) >= 0 else -1

	if P.inv <= 0 and overlaps_tile(P, T_SPIKE):
		P.vy = -9.0
		hurt_player(15, 0)
	if P.inv <= 0 and overlaps_tile(P, T_LAVA):
		P.vy = -8.0   # выталкивает наверх, чтобы можно было выбраться
		hurt_player(12, 0)
		var lcol: Color = th.get("lava", Color("#ff5a2a"))
		for _i in range(6):
			parts.append({ "x": P.x + P.w / 2.0 + (rng.randf() - 0.5) * P.w, "y": P.y + P.h,
				"vx": (rng.randf() - 0.5) * 1.5, "vy": -1.5 - rng.randf() * 2.0,
				"life": 16.0 + rng.randf() * 8.0, "color": lcol, "size": 2.0 + rng.randf() * 2.0, "grav": 0.06 })
	if overlaps_tile(P, T_EXIT):
		if boss_alive:
			if tick % 45 == 0:
				add_text(P.x + P.w / 2.0, P.y - 12, "Сначала победите босса!", Color("#ff6b5e"))
		else:
			level_clear()
			return

	if P.inv > 0:
		P.inv -= 1
	if P.cd > 0:
		P.cd -= 1
	if P.squash > 0.0:
		P.squash = maxf(0.0, P.squash - 0.12)
	if low_ammo_t > 0:
		low_ammo_t -= 1

	if input.switch_to >= 0 and input.switch_to < P.weapons.size():
		switch_weapon(input.switch_to)

	if input.ult and ult >= ULT_MAX:
		activate_ult()

	try_shoot()

func do_jump() -> void:
	P.vy = -12.2 * P.stats.jump_mul
	P.coyote = 0
	P.buffer = 0
	play_sfx("jump")
	burst(P.x + P.w / 2.0, P.y + P.h, 4, Color("#aab8d8"))

func _eshot(x: float, y: float, a: float, spd: float, dmg: int, color: String) -> void:
	bullets.append({
		"x": x + cos(a) * 8, "y": y + sin(a) * 8,
		"vx": cos(a) * spd, "vy": sin(a) * spd,
		"dmg": dmg, "crit": false, "from": "e", "life": 320, "color": _col(color),
	})

func update_enemies() -> void:
	var pcx: float = P.x + P.w / 2.0
	var pcy: float = P.y + P.h / 2.0
	for en in enemies:
		if en.dead:
			continue
		var ecx: float = en.x + en.w / 2.0
		var ecy: float = en.y + en.h / 2.0
		var dist := Vector2(pcx - ecx, pcy - ecy).length()

		# статусы: заморозка замедляет, горение наносит урон по времени
		if int(en.get("chill", 0)) > 0:
			en.chill -= 1
			en.spd = en.get("base_spd", en.spd) * 0.45
		else:
			en.spd = en.get("base_spd", en.spd)
		if int(en.get("burn", 0)) > 0:
			en.burn -= 1
			if int(en.burn) % 12 == 0:
				burst(ecx, en.y, 2, Color("#ff8a3d"))
				hurt_enemy(en, 4, false, true)
				if en.dead:
					continue

		if en.type == "walker" or en.type == "splitter" or en.type == "shard":
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
				if (not is_blocking(below) and below != T_PLAT) or at_feet == T_SPIKE:
					en.dir *= -1
		elif en.type == "sniper":
			en.vy = min(en.vy + GRAV, MAX_FALL)
			en.vx = 0.0
			en.dir = 1 if pcx > ecx else -1
			collide_entity(en)
			var can_see := dist < 540 and line_of_sight(ecx, ecy, pcx, pcy)
			if en.charge == 0:
				if can_see:
					en.charge = 1
					en.aimx = pcx   # фиксируем цель — игрок успевает увернуться
					en.aimy = pcy
			elif en.charge > 0:
				en.charge += 1
				if en.charge >= 54:
					var a := atan2(en.aimy - ecy, en.aimx - ecx)
					_eshot(ecx, ecy, a, 11.5, en.dmg, "#ff3b3b")
					play_sfx("rifle")
					shake = max(shake, 4.0)
					en.charge = -110   # перезарядка
			else:
				en.charge += 1
		elif en.type == "exploder":
			en.vy = min(en.vy + GRAV, MAX_FALL)
			var chase: bool = dist < 360 and line_of_sight(ecx, ecy, pcx, pcy)
			if chase:
				en.dir = 1 if pcx > ecx else -1
			en.vx = en.dir * en.spd * (1.0 if chase else 0.6)
			# мигание-телеграф учащается с близостью
			en.phase += 0.2 + clampf((200.0 - dist) / 200.0, 0.0, 1.0) * 0.5
			collide_entity(en)
			if en.hit_wall:
				en.dir *= -1
			elif en.on_ground:
				var ahead_x: float = en.x + en.w + 2 if en.dir > 0 else en.x - 2
				var foot_tx := int(floor(ahead_x / TILE))
				var foot_ty := int(floor((en.y + en.h + 4) / TILE))
				var below := tile_at(foot_tx, foot_ty)
				if not is_blocking(below) and below != T_PLAT:
					en.dir *= -1
			# подрыв при касании игрока
			if not en.dead and dist < 34 and P.inv <= 0:
				en.dead = true
				kills += 1
				score += en.score
				explode(ecx, ecy, en.get("radius", 62), en.dmg, "e")
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
							"dmg": en.dmg, "crit": false, "from": "e", "life": 240, "color": _col("#ff7a6b"),
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
		elif en.type == "boss" and en.get("variant", "ground") == "summoner":
			# босс-призыватель: парит, призывает миньонов и стреляет
			en.phase += 0.05
			en.dir = 1 if pcx > ecx else -1
			var hover_y2 := clampf(pcy - 150, 2 * TILE, level.px_h - 6 * TILE)
			en.vx += clampf(pcx - ecx, -1, 1) * 0.10
			en.vy += clampf(hover_y2 - ecy, -1, 1) * 0.14 + sin(en.phase * 1.7) * 0.05
			var sp2 := Vector2(en.vx, en.vy).length()
			if sp2 > 2.4:
				en.vx *= 2.4 / sp2
				en.vy *= 2.4 / sp2
			collide_entity(en)
			en.atk_t -= 1
			if en.atk_t <= 0:
				en.atk_t = 200
				# считаем СВОИХ призванных миньонов и докидываем, если их мало
				var minions := 0
				for e2 in enemies:
					if not e2.dead and e2.get("summoned", false):
						minions += 1
				if minions < 5:
					shake = max(shake, 6.0)
					burst(ecx, ecy, 18, Color("#c08bff"))
					for s in [-1, 1]:
						var mtype := "flyer" if rng.randf() < 0.5 else "walker"
						var m := _spawn_enemy(mtype, ecx + s * 28 - 12, ecy + 10)
						m["summoned"] = true
						enemies.append(m)
			en.cd -= 1
			if en.cd <= 0 and line_of_sight(ecx, ecy, pcx, pcy):
				en.cd = 30
				var ba := (Vector2(pcx, pcy) - Vector2(ecx, ecy)).angle()
				for k in range(-1, 2):
					_eshot(ecx, ecy, ba + k * 0.18, 5.5, en.dmg, "#c08bff")
		elif en.type == "boss" and en.get("variant", "ground") == "air":
			en.phase += 0.05
			en.dir = 1 if pcx > ecx else -1
			en.atk_t -= 1
			if en.atk_t <= 0:
				en.atk = (en.atk + 1) % 3
				en.atk_t = 150
			if en.atk == 2:
				# пикирование к игроку
				en.vx += clampf(pcx - ecx, -1, 1) * 0.5
				en.vy += clampf(pcy - ecy, -1, 1) * 0.5
			else:
				# парение к точке над игроком
				var hover_y := clampf(pcy - 130, 2 * TILE, level.px_h - 5 * TILE)
				en.vx += clampf(pcx - ecx, -1, 1) * 0.18
				en.vy += clampf(hover_y - ecy, -1, 1) * 0.18 + sin(en.phase * 2.0) * 0.06
			var maxsp := 7.0 if en.atk == 2 else 3.2
			var sp := Vector2(en.vx, en.vy).length()
			if sp > maxsp:
				en.vx *= maxsp / sp
				en.vy *= maxsp / sp
			collide_entity(en)
			en.cd -= 1
			if en.cd <= 0 and en.atk != 2 and line_of_sight(ecx, ecy, pcx, pcy):
				var base_a := (Vector2(pcx, pcy) - Vector2(ecx, ecy)).angle()
				if en.atk == 0:
					en.cd = 22
					for k in range(-1, 2):
						_eshot(ecx, ecy, base_a + k * 0.13, 6.2, en.dmg, "#7fd4ff")
				else:
					en.cd = 66
					for k in range(14):
						_eshot(ecx, ecy, k * TAU / 14.0 + en.phase, 4.4, en.dmg, "#7fd4ff")
					shake = max(shake, 5.0)
		elif en.type == "boss":
			en.vy = min(en.vy + GRAV, MAX_FALL)
			en.dir = 1 if pcx > ecx else -1
			en.phase += 0.05
			# медленное преследование по земле
			if en.on_ground and dist > 100:
				en.vx = en.dir * en.spd
			else:
				en.vx = lerp(en.vx, 0.0, 0.2)
			# смена фазы атаки
			en.atk_t -= 1
			if en.atk_t <= 0:
				en.atk = (en.atk + 1) % 3
				en.atk_t = 160
				if en.atk == 2 and en.on_ground:
					en.vy = -11.5   # рывок-прыжок к игроку
					en.vx = en.dir * 5.0
			collide_entity(en)
			en.cd -= 1
			if en.cd <= 0:
				if line_of_sight(ecx, ecy, pcx, pcy):
					var base_a := (Vector2(pcx, pcy) - Vector2(ecx, ecy)).angle()
					if en.atk == 0:
						en.cd = 18
						for k in range(-1, 2):
							_eshot(ecx, ecy, base_a + k * 0.10, 6.8, en.dmg, "#ff5ec4")
					elif en.atk == 1:
						en.cd = 60
						for k in range(12):
							_eshot(ecx, ecy, k * TAU / 12.0 + en.phase, 4.6, en.dmg, "#ff5ec4")
						shake = max(shake, 5.0)
					else:
						en.cd = 42
						for k in range(-2, 3):
							_eshot(ecx, ecy, base_a + k * 0.18, 5.6, en.dmg, "#ff7a6b")
				else:
					en.cd = 20

		if en.hurt_t > 0:
			en.hurt_t -= 1

		if P.inv <= 0 and not en.dead and en.type != "exploder" and aabb(en, P):
			hurt_player(en.dmg, 1 if P.x + P.w / 2.0 > ecx else -1, Vector2(ecx, ecy))

	var alive := []
	for en in enemies:
		if not en.dead:
			alive.append(en)
	enemies = alive

func update_bullets() -> void:
	var alive := []
	for b in bullets:
		var is_gren: bool = b.get("grenade", false)
		var is_pierce: bool = b.get("pierce", false)
		if is_gren:
			b.vy = min(b.vy + 0.32, MAX_FALL)  # граната летит по дуге
		b.life -= 1
		var hit: bool = b.life <= 0
		var steps := 2
		var s := 0
		while s < steps and not hit:
			b.x += b.vx / steps
			b.y += b.vy / steps
			if solid_px(b.x, b.y):
				# попадание по разрушаемому ящику — наносим ему урон
				var htx := int(floor(b.x / TILE))
				var hty := int(floor(b.y / TILE))
				if tile_at(htx, hty) == T_CRATE:
					damage_crate(htx, hty, b.dmg)
				if not is_gren:
					burst(b.x, b.y, 2, Color("#cdd6f0"))
					spark(b.x, b.y, b.vx, b.vy, 5)
				hit = true
				break
			if b.from == "p":
				for en in enemies:
					if en.dead:
						continue
					if b.x > en.x - 2 and b.x < en.x + en.w + 2 and b.y > en.y - 2 and b.y < en.y + en.h + 2:
						if is_gren:
							shots_hit += 1  # прямое попадание гранатой
							hit = true  # граната подрывается, урон от взрыва
							break
						if is_pierce:
							if not (en.eid in b.hit_ids):
								hurt_enemy(en, b.dmg, b.crit)
								_roll_bullet_status(en)
								b.hit_ids.append(en.eid)
								shots_hit += 1
							# рельса проходит насквозь — не останавливаемся
						else:
							hurt_enemy(en, b.dmg, b.crit)
							_roll_bullet_status(en)
							shots_hit += 1
							hit = true
							break
			elif P.inv <= 0 and state == "play" \
					and b.x > P.x - 2 and b.x < P.x + P.w + 2 and b.y > P.y - 2 and b.y < P.y + P.h + 2:
				hurt_player(b.dmg, 1 if b.vx > 0 else -1, Vector2(b.x, b.y))
				hit = true
			if b.y < -200 or b.y > level.px_h + 200 or b.x < -200 or b.x > level.px_w + 200:
				hit = true
			s += 1
		if hit and is_gren:
			explode(b.x, b.y, b.radius, b.dmg, b.from)
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

		# магнит: монеты всегда, прочие предметы — с улучшением «Магнит»
		var mrange: float = P.stats.magnet_range
		if pk.kind == "coin" or mrange > 90.0:
			var dx: float = P.x + P.w / 2.0 - (pk.x + pk.w / 2.0)
			var dy: float = P.y + P.h / 2.0 - (pk.y + pk.h / 2.0)
			var d := Vector2(dx, dy).length()
			if d < mrange and d > 1:
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
			elif pk.kind == "shield":
				P.max_shield = max(P.max_shield, pk.shield)
				P.shield = min(P.max_shield, P.shield + pk.shield)
				add_text(P.x + P.w / 2.0, P.y - 10, "+%d щит" % int(pk.shield), Color("#7fd4ff"))
			elif pk.kind == "coin":
				score += 5
				coins += 1
				add_text(pk.x, pk.y - 6, "+1●", Color("#ffd86b"))
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
	# страховка производительности: ограничиваем число частиц в пике
	if pa.size() > 600:
		pa = pa.slice(pa.size() - 600)
	parts = pa
	var ta := []
	for t in texts:
		t.life -= 1
		if t.life <= 0:
			continue
		t.y += t.vy
		ta.append(t)
	texts = ta
	var ai := []
	for a in afterimages:
		a.life -= 1
		if a.life > 0:
			ai.append(a)
	afterimages = ai
	var to := []
	for t in toasts:
		t.life -= 1
		if t.life > 0:
			to.append(t)
	toasts = to
	var hd := []
	for h in hurt_dirs:
		h.life -= 1
		if h.life > 0:
			hd.append(h)
	hurt_dirs = hd
	var mz := []
	for m in muzzles:
		m.life -= 1
		if m.life > 0:
			mz.append(m)
	muzzles = mz
	var sw := []
	for s in shockwaves:
		s.life -= 1
		s.r = lerp(s.r, s.max_r, 0.35)
		if s.life > 0:
			sw.append(s)
	shockwaves = sw
	if flash > 0.0:
		flash = max(0.0, flash - 0.08)
	if fade > 0.0:
		fade = max(0.0, fade - 0.06)

func update_camera() -> void:
	# лёгкий look-ahead в сторону прицела
	var look := clampf(cos(P.aim) * 90.0, -90, 90)
	var tx := clampf(P.x + P.w / 2.0 - VW / 2.0 + look, 0, max(0, level.px_w - VW))
	var ty := clampf(P.y + P.h / 2.0 - VH / 2.0 + clampf(sin(P.aim) * 40.0, -40, 40), 0, max(0, level.px_h - VH))
	cam.x = lerp(cam.x, tx, 0.10)
	cam.y = lerp(cam.y, ty, 0.12)
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
		"amb": _col(level.theme.sky0).darkened(0.3),  # тёмный тон для атмосферного света
	}
	sky0 = _col(level.theme.sky0)
	sky1 = _col(level.theme.sky1)
	# градиент неба кэшируем в текстуру — один вызов отрисовки вместо десятков
	var grad := Gradient.new()
	grad.set_color(0, sky0)
	grad.set_color(1, sky1)
	sky_tex = GradientTexture2D.new()
	sky_tex.gradient = grad
	sky_tex.width = 1
	sky_tex.height = VH
	sky_tex.fill_from = Vector2(0, 0)
	sky_tex.fill_to = Vector2(0, 1)
	stars = []
	for _i in range(70):
		stars.append(Vector3(r.randf() * VW, r.randf() * VH * 0.7, 0.4 + r.randf() * 1.2))
	hill_far = _make_hills(r, 330, 26)
	hill_near = _make_hills(r, 420, 34)
	_build_tile_textures(seed_val)
	weather = level.theme.get("weather", "spores")
	weather_col = _col(level.theme.get("wcol", "#ffffff"))
	_init_ambient()

func _build_tile_textures(seed_val: int) -> void:
	# пиксель-текстуры тайлов: камень (дизеринг + бевел) и трава для кромки
	var g: Color = th.ground
	var tg: Color = th.top
	var tr := RandomNumberGenerator.new()
	tr.seed = (seed_val ^ 0x5A17) & 0xFFFFFFFF
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in range(TILE):
		for x in range(TILE):
			var c := g
			if y < 2:
				c = g.lightened(0.16)        # верхний блик
			elif y >= TILE - 3:
				c = g.darkened(0.22)         # нижняя тень (AO)
			if x < 1:
				c = c.lightened(0.06)
			elif x >= TILE - 1:
				c = c.darkened(0.10)
			var n := tr.randf()
			if n < 0.10:
				c = c.darkened(0.14)         # тёмные крапины-камешки
			elif n < 0.16:
				c = c.lightened(0.08)
			img.set_pixel(x, y, c)
	ground_tex = ImageTexture.create_from_image(img)
	# текстура травянистой кромки (верхние ~7px ярче + редкие «травинки»)
	var top := Image.create(TILE, 7, false, Image.FORMAT_RGBA8)
	for x in range(TILE):
		for y in range(7):
			top.set_pixel(x, y, tg if y < 5 else tg.darkened(0.25))
		if tr.randf() < 0.4:
			var h := tr.randi_range(1, 3)
			for y in range(h):
				top.set_pixel(x, max(0, y), tg.lightened(0.2))
	grass_tex = ImageTexture.create_from_image(top)
	# текстура односторонней платформы (доска: светлый верх, тёмный низ, швы)
	var pc: Color = th.plat
	var pimg := Image.create(TILE, 8, false, Image.FORMAT_RGBA8)
	for x in range(TILE):
		for y in range(8):
			var c := pc
			if y < 2:
				c = pc.lightened(0.18)
			elif y >= 6:
				c = pc.darkened(0.32)
			if x % 8 == 0:
				c = c.darkened(0.16)  # шов между досками
			pimg.set_pixel(x, y, c)
	plat_tex = ImageTexture.create_from_image(pimg)

# ============================== Атмосфера (погода по теме) ==============================

func _ambient_cap() -> int:
	return 70

func _new_ambient_particle(at_random_y: bool) -> Dictionary:
	# частица в экранном пространстве; стартовая кромка зависит от типа погоды
	var x := rng.randf() * VW
	var y := rng.randf() * VH
	match weather:
		"snow", "sand", "spores":
			if not at_random_y:
				y = -8.0  # появляются сверху
		"embers", "bubbles":
			if not at_random_y:
				y = VH + 8.0  # поднимаются снизу
	var sz := 1.0 + rng.randf() * 2.2
	var vx := 0.0
	var vy := 0.0
	match weather:
		"snow":
			vx = (rng.randf() - 0.3) * 0.6
			vy = 0.5 + rng.randf() * 0.8
		"sand":
			vx = 1.6 + rng.randf() * 2.2
			vy = (rng.randf() - 0.5) * 0.5
			sz = 1.0 + rng.randf() * 1.6
		"embers":
			vx = (rng.randf() - 0.5) * 0.5
			vy = -(0.6 + rng.randf() * 1.1)
		"bubbles":
			vx = (rng.randf() - 0.5) * 0.3
			vy = -(0.4 + rng.randf() * 0.9)
			sz = 1.5 + rng.randf() * 2.5
		_:  # spores — мягкое парение
			vx = (rng.randf() - 0.5) * 0.5
			vy = (rng.randf() - 0.5) * 0.4
	return { "x": x, "y": y, "vx": vx, "vy": vy, "size": sz, "phase": rng.randf() * TAU,
		"alpha": 0.25 + rng.randf() * 0.45 }

func _init_ambient() -> void:
	ambient = []
	for _i in range(_ambient_cap()):
		ambient.append(_new_ambient_particle(true))
	motes = []
	for _i in range(46):
		motes.append({
			"x": rng.randf() * VW, "y": rng.randf() * VH,
			"vx": (rng.randf() - 0.5) * 0.25, "vy": -0.08 - rng.randf() * 0.18,
			"phase": rng.randf() * TAU, "size": 1.0 + rng.randf() * 1.4 })

func update_ambient() -> void:
	for p in ambient:
		p.phase += 0.03
		p.x += p.vx + sin(p.phase) * 0.35
		p.y += p.vy
		# зацикливание по краям экрана
		if p.x < -10:
			p.x = VW + 8
		elif p.x > VW + 10:
			p.x = -8
		if p.y < -10 or p.y > VH + 10:
			var np := _new_ambient_particle(false)
			p.x = np.x
			p.y = np.y
			p.vx = np.vx
			p.vy = np.vy
			p.size = np.size
			p.alpha = np.alpha
	for m in motes:
		m.phase += 0.04
		m.x += m.vx + sin(m.phase) * 0.18
		m.y += m.vy
		if m.x < -4: m.x = VW + 4
		elif m.x > VW + 4: m.x = -4
		if m.y < -4: m.y = VH + 4
		elif m.y > VH + 4: m.y = -4

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
		var c := cam + _shake_offset()
		_cam_draw = c

		_draw_sky()
		_draw_hills(hill_far, th.hill_far, c, 0.25)
		_draw_hills(hill_near, th.hill_near, c, 0.45)

		draw_set_transform(-c)
		_draw_tiles(c)
		_draw_movers()
		_draw_hazards()
		_draw_portal()
		_draw_pickups()
		_draw_enemies()
		_draw_player()
		_draw_bullets()
		_draw_fx()
		_draw_particles()
		_draw_texts()
		draw_set_transform(Vector2.ZERO)

		_draw_lighting(c)
		if vignette_tex:
			draw_texture_rect(vignette_tex, Rect2(0, 0, VW, VH), false)
		if flash > 0.0:
			draw_rect(Rect2(0, 0, VW, VH), Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.6))
		_draw_ambient()
		_draw_hurt_dirs()
		_draw_hud()
		if fade > 0.0:
			_draw_iris(fade)   # круговой ирис-переход (открывается на игроке)
	# меню/пауза/смерть/магазин рисуются всегда (в т.ч. когда уровня ещё нет)
	_draw_overlays()

func _draw_iris(f: float) -> void:
	# чёрный экран с растущим круглым «окном» на игроке: f=1 закрыто, f=0 открыто
	draw_set_transform(Vector2.ZERO)
	var center := Vector2(VW / 2.0, VH / 2.0)
	if not level.is_empty() and state != "dead":
		center = Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0) - _cam_draw
	var hole := (1.0 - f) * 860.0
	var outer := 980.0
	if hole >= outer:
		return
	var n := 56
	var black := Color(0, 0, 0, 1)
	for i in range(n):
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		# кольцевой сегмент-четырёхугольник (надёжно через draw_colored_polygon)
		draw_colored_polygon(PackedVector2Array([
			center + d0 * hole, center + d0 * outer,
			center + d1 * outer, center + d1 * hole]), black)

func _draw_fx() -> void:
	# расходящиеся кольца взрывов
	for s in shockwaves:
		var a := clampf(s.life / 16.0, 0.0, 1.0)
		draw_arc(Vector2(s.x, s.y), s.r, 0, TAU, 28, Color(s.col.r, s.col.g, s.col.b, 0.6 * a), 3.0 * a + 1.0)
	# вспышки выстрела
	for m in muzzles:
		var a := clampf(m.life / 5.0, 0.0, 1.0)
		var base := Vector2(m.x, m.y)
		var dir := Vector2(cos(m.ang), sin(m.ang))
		var perp := Vector2(-dir.y, dir.x)
		var tip := base + dir * (8.0 + a * 8.0)
		draw_colored_polygon(PackedVector2Array([
			base + perp * 4.0 * a, tip, base - perp * 4.0 * a]), Color(2.2, 2.0, 1.4, 0.9 * a))
		draw_circle(base, 4.0 * a, Color(3.0, 2.9, 2.4, 0.8 * a))

func _draw_hurt_dirs() -> void:
	# дуга-вспышка у края экрана в сторону источника урона
	var ctr := Vector2(VW / 2.0, VH / 2.0)
	for h in hurt_dirs:
		var a := clampf(h.life / 40.0, 0.0, 1.0)
		var ang: float = h.ang
		var rad := 250.0
		var pos := ctr + Vector2(cos(ang), sin(ang)) * rad
		draw_arc(pos, 60.0, ang + PI - 0.5, ang + PI + 0.5, 12, Color(1, 0.3, 0.3, 0.55 * a), 8.0)

func _draw_ambient() -> void:
	for p in ambient:
		var col := weather_col
		col.a = p.alpha
		if weather == "snow" or weather == "bubbles":
			draw_circle(Vector2(p.x, p.y), p.size, col)
		else:
			draw_rect(Rect2(p.x - p.size / 2.0, p.y - p.size / 2.0, p.size, p.size), col)

func _build_crate_texture() -> void:
	# деревянный ящик: горизонтальная текстура волокон + тёмная рамка
	var base := Color("#b07c3e")
	var tr := RandomNumberGenerator.new()
	tr.seed = 0xC0FFEE
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in range(TILE):
		var band := base.darkened(0.10) if (y % 6 < 1) else base
		for x in range(TILE):
			var c := band
			if x < 2 or x >= TILE - 2 or y < 2 or y >= TILE - 2:
				c = base.darkened(0.38)        # рамка
			elif tr.randf() < 0.12:
				c = c.darkened(0.10)           # волокна
			img.set_pixel(x, y, c)
	crate_tex = ImageTexture.create_from_image(img)

func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(0, 0, 0, 0))
	g.add_point(0.62, Color(0, 0, 0, 0))
	g.set_offset(g.get_point_count() - 1, 1.0)
	g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0.42))
	vignette_tex = GradientTexture2D.new()
	vignette_tex.gradient = g
	vignette_tex.width = 256
	vignette_tex.height = 144
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(0.5, 0.5)
	vignette_tex.fill_to = Vector2(1.0, 1.0)

func _setup_bloom() -> void:
	# HDR-свечение: яркие (>1.0) пиксели — свет, лава, вспышки, криты — «цветут».
	# Работает и на Forward+ (десктоп), и на совместимом рендере.
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0   # цветёт только то, что ярче белого
	env.glow_hdr_scale = 2.0
	# многоуровневое размытие — мягкий ореол
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.5)
	env.set_glow_level(5, 0.0)
	# AgX-тонмаппинг: мягкий «киношный» спад ярких пятен (bloom не выжигает)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	# лёгкая кинематографичная цветокоррекция (контраст + насыщенность)
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.18
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_apply_bloom()

func _apply_bloom() -> void:
	if world_env and world_env.environment:
		world_env.environment.glow_enabled = bloom_on

const FX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 screen_size;
uniform float t;
uniform float aberration;
uniform int heat_count;
uniform vec4 heat_pts[16];   // xy=пиксель, z=радиус, w=сила
uniform int ripple_count;
uniform vec4 ripples[8];     // xy=центр, z=радиус, w=сила
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = uv * screen_size;
	vec2 off = vec2(0.0);
	for (int i = 0; i < heat_count; i++) {
		vec4 h = heat_pts[i];
		float d = distance(px, h.xy);
		if (d < h.z) {
			float f = 1.0 - d / h.z;
			off.x += sin(px.y * 0.13 + t * 4.2) * f * h.w;
			off.y += cos(px.x * 0.11 + t * 3.1) * f * h.w * 0.6;
		}
	}
	for (int i = 0; i < ripple_count; i++) {
		vec4 r = ripples[i];
		float d = distance(px, r.xy);
		float ring = abs(d - r.z);
		if (ring < 22.0 && d > 0.001) {
			vec2 dir = (px - r.xy) / d;
			float amp = (1.0 - ring / 22.0) * r.w;
			off += dir * amp * sin((d - r.z) * 0.35);
		}
	}
	vec2 duv = off / screen_size;
	float ab = aberration * 0.005 + length(off) * 0.0006;
	vec3 col;
	col.r = texture(screen_tex, uv + duv + vec2(ab, 0.0)).r;
	col.g = texture(screen_tex, uv + duv).g;
	col.b = texture(screen_tex, uv + duv - vec2(ab, 0.0)).b;
	COLOR = vec4(col, 1.0);
}
"""

func _setup_fx() -> void:
	# полноэкранный экранный пост-эффект: марево, рябь взрывов, аберрация урона
	var sh := Shader.new()
	sh.code = FX_SHADER
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = sh
	fx_mat.set_shader_parameter("screen_size", Vector2(VW, VH))
	fx_rect = ColorRect.new()
	fx_rect.material = fx_mat
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.size = Vector2(VW, VH)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 3   # выше мира, ниже... (HUD пока в _draw мира — допустимо)
	fx_layer.add_child(fx_rect)
	add_child(fx_layer)

func _update_fx() -> void:
	# обновляем параметры искажения каждый кадр (источники → uniform-массивы)
	if fx_mat == null:
		return
	aberration = maxf(0.0, aberration - 0.04)
	fx_mat.set_shader_parameter("t", tick * 0.05)
	fx_mat.set_shader_parameter("aberration", aberration)
	# тепловое марево над видимыми тайлами лавы
	var heat := PackedVector4Array()
	if not level.is_empty():
		for lp in level.get("lava_cells", []):
			var sp: Vector2 = lp - _cam_draw
			if sp.x > -40.0 and sp.x < VW + 40.0 and sp.y > -40.0 and sp.y < VH + 40.0:
				heat.append(Vector4(sp.x, sp.y - 6.0, 70.0, 1.6))
				if heat.size() >= 16:
					break
	fx_mat.set_shader_parameter("heat_count", heat.size())
	if heat.size() > 0:
		fx_mat.set_shader_parameter("heat_pts", heat)
	# рябь от ударных волн взрывов
	var rip := PackedVector4Array()
	for s in shockwaves:
		var sp2: Vector2 = Vector2(s.x, s.y) - _cam_draw
		var stren: float = clampf(s.life / 16.0, 0.0, 1.0) * 6.0
		rip.append(Vector4(sp2.x, sp2.y, s.r, stren))
		if rip.size() >= 8:
			break
	fx_mat.set_shader_parameter("ripple_count", rip.size())
	if rip.size() > 0:
		fx_mat.set_shader_parameter("ripples", rip)

func _build_light_tex() -> void:
	# мягкий радиальный «фонарик»: яркое ядро → плавное затухание в прозрачность.
	# Накладывается обычным блендом, осветляя сцену под источником (свет-пятно).
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1.0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	g.add_point(0.7, Color(1, 1, 1, 0.16))
	g.set_offset(g.get_point_count() - 1, 1.0)
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	light_tex = GradientTexture2D.new()
	light_tex.gradient = g
	light_tex.width = 128
	light_tex.height = 128
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)

func _light(world_pos: Vector2, radius: float, col: Color, intensity: float, energy := 1.0) -> void:
	# свет-пятно в мировых координатах (рисуется в экранном пространстве).
	# energy>1 делает ядро HDR-ярким → оно «цветёт» через bloom.
	if light_tex == null or intensity <= 0.0 or radius <= 0.0:
		return
	var sp := world_pos - _cam_draw
	if sp.x + radius < 0.0 or sp.x - radius > VW or sp.y + radius < 0.0 or sp.y - radius > VH:
		return  # за экраном — пропускаем
	var e := energy if bloom_on else 1.0
	var d := radius * 2.0
	draw_texture_rect(light_tex, Rect2(sp.x - radius, sp.y - radius, d, d), false,
		Color(col.r * e, col.g * e, col.b * e, clampf(intensity, 0.0, 1.0)))

func _ray_seg(o: Vector2, dir: Vector2, a: Vector2, b: Vector2) -> float:
	# расстояние вдоль луча o+dir*t до пересечения с отрезком a-b (>0), иначе -1
	var s := b - a
	var denom := dir.x * s.y - dir.y * s.x
	if absf(denom) < 0.00001:
		return -1.0  # параллельны
	var diff := a - o
	var t := (diff.x * s.y - diff.y * s.x) / denom            # вдоль луча
	var u := (diff.x * dir.y - diff.y * dir.x) / denom         # вдоль отрезка
	if t > 0.0 and u >= 0.0 and u <= 1.0:
		return t
	return -1.0

func _occluder_segments(c: Vector2, R: float) -> Array:
	# силуэтные рёбра твёрдых тайлов/ящиков в радиусе R вокруг точки c
	var segs := []
	if level.is_empty():
		return segs
	var tx0 := int(floor((c.x - R) / TILE))
	var tx1 := int(floor((c.x + R) / TILE))
	var ty0 := int(floor((c.y - R) / TILE))
	var ty1 := int(floor((c.y + R) / TILE))
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if not is_blocking(tile_at(tx, ty)):
				continue
			var px := tx * TILE
			var py := ty * TILE
			# ребро добавляем только если соседний тайл с этой стороны — пустой
			if not is_blocking(tile_at(tx - 1, ty)):
				segs.append([Vector2(px, py), Vector2(px, py + TILE)])
			if not is_blocking(tile_at(tx + 1, ty)):
				segs.append([Vector2(px + TILE, py), Vector2(px + TILE, py + TILE)])
			if not is_blocking(tile_at(tx, ty - 1)):
				segs.append([Vector2(px, py), Vector2(px + TILE, py)])
			if not is_blocking(tile_at(tx, ty + 1)):
				segs.append([Vector2(px, py + TILE), Vector2(px + TILE, py + TILE)])
	return segs

func _visibility_polygon(L: Vector2, R: float, segs: Array) -> PackedVector2Array:
	# полигон видимости: лучи к углам преград (+ опорная окружность), обрезка стенами
	var angles := []
	for i in range(24):
		angles.append(i * TAU / 24.0)            # опорная окружность для открытых направлений
	for s in segs:
		for p in [s[0], s[1]]:
			var base := atan2(p.y - L.y, p.x - L.x)
			angles.append(base - 0.0003)
			angles.append(base)
			angles.append(base + 0.0003)
	angles.sort()
	var poly := PackedVector2Array()
	for ang in angles:
		var dir := Vector2(cos(ang), sin(ang))
		var nearest := R
		for s in segs:
			var t := _ray_seg(L, dir, s[0], s[1])
			if t > 0.0 and t < nearest:
				nearest = t
		poly.append(L + dir * nearest)
	return poly

func _light_shadowed(world_pos: Vector2, radius: float, col: Color, intensity: float, energy := 1.0) -> void:
	# мягкое свет-пятно с динамическими тенями: рисуем полигон видимости,
	# текстурированный «фонариком» (мягкое затухание + резкие края теней).
	if light_tex == null or intensity <= 0.0:
		return
	var segs := _occluder_segments(world_pos, radius)
	if segs.is_empty():
		_light(world_pos, radius, col, intensity, energy)   # нет преград — обычное пятно
		return
	var poly := _visibility_polygon(world_pos, radius, segs)
	var n := poly.size()
	if n < 3:
		return
	var e := energy if bloom_on else 1.0
	var lcolor := Color(col.r * e, col.g * e, col.b * e, clampf(intensity, 0.0, 1.0))
	# веер треугольников от центра: явные индексы (без триангуляции — надёжно)
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	pts.append(world_pos - _cam_draw)                        # центр (индекс 0)
	uvs.append(Vector2(0.5, 0.5))
	cols.append(lcolor)
	for p in poly:
		pts.append(p - _cam_draw)
		uvs.append((p - world_pos) / (radius * 2.0) + Vector2(0.5, 0.5))
		cols.append(lcolor)
	var idx := PackedInt32Array()
	for i in range(n):
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % n)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), light_tex.get_rid())

func _draw_lighting(_c: Vector2) -> void:
	# Динамический свет: лёгкое атмосферное затемнение мира + светящиеся пятна
	# от игрока, пуль, вспышек, взрывов, портала, предметов и горящих врагов.
	# Рисуется в экранном пространстве ПОСЛЕ мира и ДО HUD — интерфейс не тускнеет.
	if light_tex == null:
		return
	# атмосферный тон: чуть приглушаем мир в холодный/тёмный оттенок темы,
	# чтобы свет-пятна читались как настоящее освещение (не размывая HUD)
	var amb: Color = th.get("amb", Color(0.04, 0.05, 0.10))
	draw_rect(Rect2(0, 0, VW, VH), Color(amb.r, amb.g, amb.b, 0.16))
	# лава/кислота — тёплый свет от каждого тайла (с отсечением за экраном)
	if not level.is_empty():
		var lcol: Color = th.get("lava", Color(1, 0.45, 0.2))
		var lflick := 0.42 + 0.08 * sin(tick * 0.2)
		for lp in level.get("lava_cells", []):
			_light(lp, 44.0, lcol, lflick, 1.8)
	# портал — крупный пульсирующий маяк
	if not level.is_empty():
		var ep: Vector2 = level.exit_px
		var ppulse := 0.85 + sin(tick * 0.07) * 0.15
		_light(Vector2(ep.x, ep.y + TILE / 2.0), 110.0 * ppulse, Color(0.55, 0.74, 1.0), 0.6, 2.0)
		_draw_godrays(Vector2(ep.x, ep.y + TILE / 2.0), 150.0 * ppulse, Color(0.6, 0.8, 1.0))
	# игрок — мягкая аура, ярче в рывке
	if state != "dead":
		var pdash := 0.0
		if P.get("dash_t", 0) > 0:
			pdash = 0.35
		_light_shadowed(Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0), 128.0 + pdash * 60.0,
			Color(0.46, 0.92, 0.86), 0.52 + pdash, 1.6 + pdash)
	# взрывы — крупная оранжевая вспышка, затухающая по жизни кольца
	for s in shockwaves:
		var sa := clampf(s.life / 16.0, 0.0, 1.0)
		_light(Vector2(s.x, s.y), s.r + 40.0, Color(s.col.r, s.col.g, s.col.b), 0.7 * sa, 2.6)
	# дульные вспышки — короткий яркий свет
	for m in muzzles:
		var ma := clampf(m.life / 5.0, 0.0, 1.0)
		_light(Vector2(m.x, m.y), 70.0 * ma + 10.0, Color(1.0, 0.93, 0.7), 0.85 * ma, 2.8)
	# пули — небольшие огоньки своим цветом (без перебора — их и так немного)
	for b in bullets:
		var br := 30.0
		if b.get("pierce", false):
			br = 46.0
		elif b.get("grenade", false):
			br = 40.0
		_light(Vector2(b.x, b.y), br, b.color, 0.5, 2.0 if b.get("crit", false) else 1.6)
	# горящие враги — мерцающий огонёк
	for en in enemies:
		if en.get("burn", 0) > 0:
			var flick := 0.4 + 0.2 * sin(tick * 0.5 + float(en.get("eid", 0)))
			_light(Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0), 46.0, Color(1.0, 0.5, 0.2), flick, 2.0)
	# предметы — нежный блик по типу
	for pk in pickups:
		var pcol: Color = { "weapon": Color(1, 0.85, 0.42), "med": Color(1, 0.42, 0.48), "ammo": Color(0.79, 0.65, 0.29), "coin": Color(1, 0.85, 0.42), "shield": Color(0.5, 0.83, 1.0) }.get(pk.kind, Color(1, 1, 1))
		_light(Vector2(pk.x + pk.w / 2.0, pk.y + pk.h / 2.0), 34.0, pcol, 0.4, 1.5)
	_draw_motes()

func _draw_godrays(world_pos: Vector2, length: float, col: Color) -> void:
	# объёмные лучи: вращающиеся аддитивные HDR-шафты из яркого источника
	var c := world_pos - _cam_draw
	if c.x + length < 0.0 or c.x - length > VW or c.y + length < 0.0 or c.y - length > VH:
		return
	var e := 1.6 if bloom_on else 1.0
	var rot := tick * 0.006
	var n := 9
	for i in range(n):
		var a := rot + i * TAU / n
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		var beat := 0.5 + 0.5 * sin(tick * 0.05 + i * 1.7)   # мерцание длины
		var ln := length * (0.55 + 0.45 * beat)
		var w := 5.0 + 3.0 * beat
		var base := Color(col.r * e, col.g * e, col.b * e, 0.16 + 0.10 * beat)
		var tip := Color(col.r, col.g, col.b, 0.0)
		var pts := PackedVector2Array([c - perp * w, c + perp * w, c + dir * ln])
		var cls := PackedColorArray([base, base, tip])   # градиент: ярко у основания → прозрачно у конца
		var idx := PackedInt32Array([0, 1, 2])
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cls)

func _draw_motes() -> void:
	# пылинки, ловящие свет: ярче рядом с игроком/источниками
	if motes.is_empty():
		return
	var pc := Vector2(-9999, -9999)
	if state != "dead" and not level.is_empty():
		pc = Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0) - _cam_draw
	for m in motes:
		var mp := Vector2(m.x, m.y)
		var lit := clampf(1.0 - mp.distance_to(pc) / 150.0, 0.0, 1.0)
		var tw := 0.10 + 0.06 * sin(m.phase * 1.7)
		var a := tw + lit * 0.5
		var br := 1.0 + lit * 1.6 if bloom_on else 1.0   # ловят свет → HDR-искорка
		draw_circle(mp, m.size, Color(0.85 * br, 0.92 * br, 1.0 * br, a))

func _glow(c: Vector2, r: float, col: Color) -> void:
	# мягкое свечение из нескольких полупрозрачных кругов
	draw_circle(c, r, Color(col.r, col.g, col.b, 0.10))
	draw_circle(c, r * 0.6, Color(col.r, col.g, col.b, 0.16))
	draw_circle(c, r * 0.3, Color(col.r, col.g, col.b, 0.22))

func _shadow(cx: float, by: float, w: float) -> void:
	# контактная тень-эллипс под сущностью (полигон, без смены трансформа)
	var pts := PackedVector2Array()
	var rx: float = w * 0.55
	var ry: float = rx * 0.34
	for i in range(12):
		var a := i * TAU / 12.0
		pts.append(Vector2(cx + cos(a) * rx, by + sin(a) * ry))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.26))

func _draw_sky() -> void:
	if sky_tex:
		draw_texture_rect(sky_tex, Rect2(0, 0, VW, VH), false)
	for sv in stars:
		var tw := 0.45 + 0.35 * sin(tick * 0.05 + sv.x * 0.3)  # мерцание
		draw_rect(Rect2(sv.x, sv.y, sv.z, sv.z), Color(1, 1, 1, tw))

func _draw_hills(pts: PackedVector2Array, color: Color, c: Vector2, par: float) -> void:
	if pts.size() < 3:
		return
	var ox: float = -fmod(c.x * par, 1920.0)
	var oy: float = -c.y * 0.12 - 120
	# вертикальный градиент по вершинам: светлее у силуэта, темнее у низа
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in range(pts.size()):
		var t := clampf((760.0 - pts[i].y) / 480.0, 0.0, 1.0)
		var sh := lerpf(-0.12, 0.20, t)
		cols[i] = color.lightened(sh) if sh >= 0.0 else color.darkened(-sh)
	# смещаем через трансформ, не пересобирая массив точек каждый кадр
	for k in [-1, 0, 1]:
		draw_set_transform(Vector2(ox + k * 1920, oy))
		draw_polygon(pts, cols)
	draw_set_transform(Vector2.ZERO)

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
				if ground_tex:
					draw_texture_rect(ground_tex, Rect2(px, py, TILE, TILE), false)
				else:
					draw_rect(Rect2(px, py, TILE, TILE), th.ground)
				# травянистая кромка на открытой сверху земле
				if tile_at(tx, ty - 1) != T_SOLID:
					if grass_tex:
						draw_texture_rect(grass_tex, Rect2(px, py, TILE, 7), false)
					else:
						draw_rect(Rect2(px, py, TILE, 6), th.top)
			elif t == T_PLAT:
				if plat_tex:
					draw_texture_rect(plat_tex, Rect2(px, py, TILE, 8), false)
				else:
					draw_rect(Rect2(px, py, TILE, 8), th.plat)
			elif t == T_SPIKE:
				var poly := PackedVector2Array([
					Vector2(px, py + TILE), Vector2(px + 8, py + 6),
					Vector2(px + 16, py + TILE), Vector2(px + 24, py + 6),
					Vector2(px + TILE, py + TILE),
				])
				draw_colored_polygon(poly, th.spike.darkened(0.18))
				# подсветка освещённых левых граней + тёмное основание (металл)
				var lit: Color = th.spike.lightened(0.25)
				draw_line(Vector2(px, py + TILE), Vector2(px + 8, py + 6), lit, 1.5)
				draw_line(Vector2(px + 16, py + TILE), Vector2(px + 24, py + 6), lit, 1.5)
				draw_rect(Rect2(px, py + TILE - 3, TILE, 3), th.ground.darkened(0.12))
			elif t == T_LAVA:
				var lc: Color = th.get("lava", Color("#ff5a2a"))
				# тело лавы (тёмное снизу → яркое сверху)
				draw_rect(Rect2(px, py, TILE, TILE), lc.darkened(0.45))
				draw_rect(Rect2(px, py + 6, TILE, TILE - 6), lc.darkened(0.25))
				# волнистая светящаяся поверхность
				var wob := sin(tick * 0.12 + tx * 0.9) * 2.0
				draw_rect(Rect2(px, py + 4 + wob, TILE, 4), lc)
				var lcr: Color = lc.lightened(0.4)
				draw_rect(Rect2(px, py + 3 + wob, TILE, 2), Color(lcr.r * 1.7, lcr.g * 1.7, lcr.b * 1.7))
				# пузырьки
				var bx := px + 6 + fmod(tx * 11 + tick * 0.2, TILE - 12)
				var bb := 2.0 + sin(tick * 0.18 + tx) * 1.2
				if bb > 1.6:
					draw_circle(Vector2(bx, py + 9 + wob), bb, lc.lightened(0.5))
			elif t == T_CRATE:
				var idx: int = ty * level.W + tx
				var chp: float = level.crate_hp.get(idx, 24)
				var dmgf := 1.0 - clampf(chp / 24.0, 0.0, 1.0)  # больше урона — заметнее трещины
				if crate_tex:
					draw_texture_rect(crate_tex, Rect2(px, py, TILE, TILE), false)
				else:
					draw_rect(Rect2(px + 1, py + 1, TILE - 2, TILE - 2), Color("#b07c3e"))
				# доски-крест
				draw_line(Vector2(px + 3, py + 3), Vector2(px + TILE - 3, py + TILE - 3), Color("#6b4420"), 2.0)
				draw_line(Vector2(px + TILE - 3, py + 3), Vector2(px + 3, py + TILE - 3), Color("#6b4420"), 2.0)
				if dmgf > 0.25:
					draw_line(Vector2(px + 8, py + 4), Vector2(px + 12, py + TILE - 5), Color(0, 0, 0, 0.45), 1.5)
				if dmgf > 0.6:
					draw_line(Vector2(px + TILE - 7, py + 6), Vector2(px + 16, py + TILE - 4), Color(0, 0, 0, 0.5), 1.5)

func _draw_hazards() -> void:
	for hz in hazards:
		var c := Vector2(hz.x, hz.y)
		# зубчатое лезвие
		var teeth := 10
		var pts := PackedVector2Array()
		for i in range(teeth * 2):
			var a: float = hz.spin + i * PI / teeth
			var rad: float = hz.r if (i % 2 == 0) else hz.r * 0.66
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, Color("#c9d2e0"))
		draw_circle(c, hz.r * 0.4, Color("#5a6478"))
		draw_circle(c, hz.r * 0.15, Color("#2a3040"))

func _draw_movers() -> void:
	for mp in moving_platforms:
		draw_rect(Rect2(mp.x, mp.y, mp.w, mp.h), Color("#8d97bd"))
		draw_rect(Rect2(mp.x, mp.y, mp.w, 3), Color("#cfd6f5"))
		draw_rect(Rect2(mp.x, mp.y + mp.h - 2, mp.w, 2), Color(0, 0, 0, 0.35))
		# индикатор направления движения
		var horiz: bool = mp.ax > 0.0
		var cxm: float = mp.x + mp.w / 2.0
		var cym: float = mp.y + mp.h / 2.0
		var col := Color(1, 1, 1, 0.5)
		if horiz:
			draw_colored_polygon(PackedVector2Array([Vector2(mp.x + 4, cym), Vector2(mp.x + 10, cym - 3), Vector2(mp.x + 10, cym + 3)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(mp.x + mp.w - 4, cym), Vector2(mp.x + mp.w - 10, cym - 3), Vector2(mp.x + mp.w - 10, cym + 3)]), col)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(cxm, mp.y - 4), Vector2(cxm - 3, mp.y + 2), Vector2(cxm + 3, mp.y + 2)]), col)

func _draw_portal() -> void:
	var e: Vector2 = level.exit_px
	var cxp: float = e.x
	var cyp: float = e.y + TILE / 2.0
	var pulse := 1.0 + sin(tick * 0.07) * 0.12
	for i in range(5, 0, -1):
		var rr := 9.0 * i * pulse
		draw_circle(Vector2(cxp, cyp), rr, Color(0.47, 0.63, 1.0, 0.06))
	draw_arc(Vector2(cxp, cyp), 20 * pulse, 0, TAU, 32, Color(1.6, 1.9, 2.2, 0.9), 3.0)
	draw_arc(Vector2(cxp, cyp), 28 * pulse, 0, TAU, 32, Color(0.55, 0.74, 1.0, 0.5), 2.0)

func _draw_pickups() -> void:
	for pk in pickups:
		var bob := sin(pk.t * 2) * 2.5
		var x: float = pk.x
		var y: float = pk.y + bob
		# свечение-ореол по типу предмета
		var gcol: Color = { "weapon": Color("#ffd86b"), "med": Color("#ff6b7a"), "ammo": Color("#caa64a"), "coin": Color("#ffd86b"), "shield": Color("#7fd4ff") }.get(pk.kind, Color("#ffffff"))
		_glow(Vector2(x + pk.w / 2.0, y + pk.h / 2.0), 16.0 + sin(pk.t * 3) * 2.0, gcol)
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
			# вращающаяся блестящая монета (ширина меняется → эффект спина)
			var cc := Vector2(x + 6, y + 6)
			var rxw: float = maxf(6.0 * absf(cos(pk.t * 4.0)), 1.0)
			var ell := PackedVector2Array()
			for i in range(14):
				var aa := i * TAU / 14.0
				ell.append(cc + Vector2(cos(aa) * rxw, sin(aa) * 6.0))
			draw_colored_polygon(ell, Color("#ffd86b"))
			draw_line(cc + Vector2(0, -6), cc + Vector2(0, 6), Color("#b88f2e"), 1.5)
			if rxw > 3.0:
				draw_circle(cc + Vector2(-rxw * 0.4, -2), 1.4, Color(1, 1, 1, 0.8))
		elif pk.kind == "shield":
			var sc := Vector2(x + pk.w / 2.0, y + pk.h / 2.0)
			draw_circle(sc, pk.w / 2.0 + 2, Color(0.5, 0.83, 1.0, 0.18))
			# щит-герб
			draw_colored_polygon(PackedVector2Array([
				Vector2(sc.x, y), Vector2(x + pk.w, y + 4), Vector2(x + pk.w, y + pk.h * 0.6),
				Vector2(sc.x, y + pk.h), Vector2(x, y + pk.h * 0.6), Vector2(x, y + 4)]), Color("#7fd4ff"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(sc.x, y + 4), Vector2(x + pk.w - 4, y + 6), Vector2(sc.x, y + pk.h - 4), Vector2(x + 4, y + 6)]), Color("#2b4a63"))

func _draw_enemies() -> void:
	for en in enemies:
		if not en.has("dir"):
			en["dir"] = 1  # защита отрисовки (на случай неполной записи врага)
		var flash: bool = en.hurt_t > 84
		# контактная тень для наземных врагов
		if not en.get("fly", false) and en.type != "boss":
			_shadow(en.x + en.w / 2.0, en.y + en.h, en.w)
		# аура элитного врага
		if en.get("elite", false):
			var ec := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
			var acol := Color(1, 0.84, 0.3, 0.22) if en.mod == "swift" else Color(0.6, 0.78, 1.0, 0.22)
			var rr := maxf(en.w, en.h) * 0.7 + sin(tick * 0.12 + float(en.eid)) * 3.0
			draw_circle(ec, rr, acol)
			draw_arc(ec, rr, 0, TAU, 20, Color(acol.r, acol.g, acol.b, 0.7), 1.5)
		# тёмный контур для читаемости (кроме босса и летунов-кругов)
		if en.type != "boss" and not en.get("fly", false):
			draw_rect(Rect2(en.x - 1.5, en.y - 1.5, en.w + 3, en.h + 3), Color(0, 0, 0, 0.5))
		if en.type == "walker":
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else Color("#e2554f"))
			var exx: float = en.x + en.w / 2.0 + en.dir * 5
			draw_rect(Rect2(exx - 3, en.y + 8, 3, 5), Color("#2a0f0e"))
			draw_rect(Rect2(exx + 2, en.y + 8, 3, 5), Color("#2a0f0e"))
		elif en.type == "splitter" or en.type == "shard":
			var base_c := Color("#b85ad0") if en.type == "splitter" else Color("#d98ae8")
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else base_c)
			# линия раскола
			draw_line(Vector2(en.x + en.w / 2.0, en.y + 2), Vector2(en.x + en.w / 2.0, en.y + en.h - 2), Color(0, 0, 0, 0.3), 2.0)
			var sxx: float = en.x + en.w / 2.0 + en.dir * (3 if en.type == "shard" else 5)
			draw_rect(Rect2(sxx - 3, en.y + en.h * 0.3, 2, 4), Color("#2a0f2e"))
			draw_rect(Rect2(sxx + 2, en.y + en.h * 0.3, 2, 4), Color("#2a0f2e"))
		elif en.type == "sniper":
			# луч-прицел во время зарядки выстрела
			if en.charge > 0:
				var a := atan2(en.aimy - (en.y + en.h / 2.0), en.aimx - (en.x + en.w / 2.0))
				var beam := clampf(en.charge / 54.0, 0, 1)
				var origin := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
				draw_line(origin, origin + Vector2(cos(a), sin(a)) * 600, Color(1, 0.23, 0.23, 0.25 + beam * 0.55), 1.0 + beam * 2.0)
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else Color("#5a6b3a"))
			draw_rect(Rect2(en.x + 4, en.y + 4, en.w - 8, 6), Color("#2a3018"))
			# «глаз-прицел»
			draw_circle(Vector2(en.x + en.w / 2.0 + en.dir * 4, en.y + 16), 4, Color("#ff3b3b") if en.charge > 0 else Color("#9bb05a"))
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
		elif en.type == "exploder":
			# пульсирующий телеграф подрыва
			var blink := (sin(en.phase) * 0.5 + 0.5)
			var body := Color("#ff7a3d").lerp(Color("#fff0b0"), blink)
			draw_circle(Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0), en.w / 2.0 + 1, Color(1, 0.5, 0.2, 0.18 + blink * 0.2))
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color.WHITE if flash else body)
			draw_rect(Rect2(en.x + en.w / 2.0 - 2, en.y - 4, 4, 4), Color("#ffe14d"))  # фитиль
			draw_rect(Rect2(en.x + 4, en.y + 8, 4, 4), Color("#2a0f0e"))
			draw_rect(Rect2(en.x + en.w - 8, en.y + 8, 4, 4), Color("#2a0f0e"))
		elif en.type == "boss" and en.get("variant", "ground") == "summoner":
			var ecs := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
			draw_circle(ecs, en.w * 0.85 + sin(tick * 0.1) * 5, Color(0.75, 0.55, 1.0, 0.18))
			for oi in range(5):
				var oa: float = en.phase * 1.5 + oi * TAU / 5.0
				draw_circle(ecs + Vector2(cos(oa), sin(oa)) * (en.w * 0.7), 3.0, Color("#d9b3ff"))
			var rcol := Color.WHITE if flash else Color("#8a4fd0")
			draw_colored_polygon(PackedVector2Array([
				ecs + Vector2(0, -en.h / 2.0), ecs + Vector2(en.w / 2.0, 0),
				ecs + Vector2(0, en.h / 2.0), ecs + Vector2(-en.w / 2.0, 0)]), rcol)
			draw_colored_polygon(PackedVector2Array([
				ecs + Vector2(0, -en.h / 3.0), ecs + Vector2(en.w / 3.0, 0),
				ecs + Vector2(0, en.h / 3.0), ecs + Vector2(-en.w / 3.0, 0)]), Color.WHITE if flash else Color("#c9a0f5"))
			draw_circle(ecs, 5, Color("#2a1244"))
		elif en.type == "boss" and en.get("variant", "ground") == "air":
			var ecb := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
			var aura: Color = [Color(0.5, 0.83, 1.0, 0.18), Color(0.5, 0.83, 1.0, 0.18), Color(1.0, 0.5, 0.4, 0.22)][en.atk]
			draw_circle(ecb, en.w * 0.8 + sin(tick * 0.12) * 5, aura)
			# крылья
			var flap := sin(tick * 0.25 + en.phase) * 8
			var wing := Color.WHITE if flash else Color("#3f7fb0")
			draw_colored_polygon(PackedVector2Array([
				Vector2(en.x + 6, ecb.y), Vector2(en.x - 22, ecb.y - 14 + flap), Vector2(en.x + 8, ecb.y + 12)]), wing)
			draw_colored_polygon(PackedVector2Array([
				Vector2(en.x + en.w - 6, ecb.y), Vector2(en.x + en.w + 22, ecb.y - 14 + flap), Vector2(en.x + en.w - 8, ecb.y + 12)]), wing)
			# ядро-глаз
			draw_circle(ecb, en.w / 2.0, Color.WHITE if flash else Color("#2c5f8a"))
			draw_circle(ecb, en.w / 2.0 - 6, Color.WHITE if flash else Color("#7fd4ff"))
			draw_circle(Vector2(ecb.x + en.dir * 6, ecb.y), 7, Color("#11314a"))
		elif en.type == "boss":
			var ecb := Vector2(en.x + en.w / 2.0, en.y + en.h / 2.0)
			# аура по фазе атаки
			var aura: Color = [Color(1, 0.37, 0.77, 0.18), Color(1, 0.5, 0.3, 0.18), Color(0.6, 0.4, 1.0, 0.18)][en.atk]
			draw_circle(ecb, en.w * 0.75 + sin(tick * 0.1) * 4, aura)
			draw_rect(Rect2(en.x, en.y + 10, en.w, en.h - 10), Color.WHITE if flash else Color("#7a2e6e"))
			draw_circle(Vector2(ecb.x, en.y + 16), en.w / 2.0 - 6, Color.WHITE if flash else Color("#9c3a8c"))
			# глаза
			draw_rect(Rect2(ecb.x + en.dir * 8 - 10, en.y + 22, 8, 8), Color("#ffe14d"))
			draw_rect(Rect2(ecb.x + en.dir * 8 + 2, en.y + 22, 8, 8), Color("#ffe14d"))
			# пушки
			draw_rect(Rect2(en.x - 6, ecb.y + 6, en.w + 12, 8), Color("#3a2440"))

		# верхний блик (объём), кроме босса и летунов
		if en.type != "boss" and not en.get("fly", false) and not flash:
			draw_rect(Rect2(en.x + 2, en.y + 1, en.w - 4, 2), Color(1, 1, 1, 0.16))
		# наложение статуса
		if int(en.get("chill", 0)) > 0:
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color(0.5, 0.83, 1.0, 0.30))
		if int(en.get("burn", 0)) > 0:
			draw_rect(Rect2(en.x, en.y, en.w, en.h), Color(1.0, 0.45, 0.2, 0.22))
			draw_circle(Vector2(en.x + en.w / 2.0 + sin(tick * 0.5 + float(en.eid)) * 4, en.y - 2), 2.5, Color("#ff8a3d"))

		if en.type != "boss" and en.hurt_t > 0 and en.hp < en.maxhp:
			var bw: float = en.w + 8
			draw_rect(Rect2(en.x - 4, en.y - 9, bw, 4), Color(0, 0, 0, 0.55))
			draw_rect(Rect2(en.x - 4, en.y - 9, bw * clampf(float(en.hp) / en.maxhp, 0, 1), 4), Color("#ff5e57"))

func _draw_player() -> void:
	if state == "dead":
		return
	# следы рывка
	for a in afterimages:
		var al := clampf(a.life / 12.0, 0, 1) * 0.5
		draw_rect(Rect2(a.x, a.y + 4, P.w, P.h - 4), Color(0.4, 0.95, 0.8, al))
	_shadow(P.x + P.w / 2.0, P.y + P.h, P.w)
	if P.inv > 0 and (tick & 4) != 0:
		return
	var pcx: float = P.x + P.w / 2.0
	_glow(Vector2(pcx, P.y + P.h / 2.0), P.w * 1.05, Color("#3ec6a8"))
	# squash & stretch: сжатие при приземлении, вытягивание в полёте
	var sqx := 1.0
	var sqy := 1.0
	if P.squash > 0.0:
		sqy = 1.0 - 0.26 * P.squash
		sqx = 1.0 + 0.22 * P.squash
	elif not P.on_ground:
		var sp := clampf(absf(P.vy) / 14.0, 0.0, 1.0)
		sqy = 1.0 + 0.22 * sp
		sqx = 1.0 - 0.14 * sp
	var piv := Vector2(pcx, P.y + P.h)   # опора — ноги
	draw_set_transform(Vector2(piv.x - _cam_draw.x - sqx * piv.x, piv.y - _cam_draw.y - sqy * piv.y), 0.0, Vector2(sqx, sqy))
	# анимированные ноги при беге
	var moving: bool = P.on_ground and absf(P.vx) > 0.4
	var ph := tick * 0.45
	var l1: float = (sin(ph) * 2.5) if moving else 0.0
	var l2: float = (sin(ph + PI) * 2.5) if moving else 0.0
	draw_rect(Rect2(P.x + 2 + l1, P.y + P.h - 4, 6, 4), Color("#226b5c"))
	draw_rect(Rect2(P.x + P.w - 8 + l2, P.y + P.h - 4, 6, 4), Color("#226b5c"))
	draw_rect(Rect2(P.x - 1.5, P.y + 2.5, P.w + 3, P.h - 2.5), Color("#10302a"))  # контур
	draw_rect(Rect2(P.x, P.y + 4, P.w, P.h - 4), Color("#3ec6a8"))
	draw_rect(Rect2(P.x + 2, P.y + 5, P.w - 4, 3), Color("#5fe0c2"))  # верхний блик
	draw_rect(Rect2(P.x, P.y + P.h - 7, P.w, 7), Color("#2c917b"))
	draw_rect(Rect2(P.x + (8 if P.face > 0 else 2), P.y + 8, 10, 5), Color("#e9f4ff"))
	draw_rect(Rect2(P.x + (13 if P.face > 0 else 3), P.y + 9, 4, 3), Color("#1c3a4a"))
	draw_set_transform(-_cam_draw)   # сброс squash перед оружием
	# оружие, повёрнутое к прицелу
	var w: Dictionary = WEAPONS[P.weapons[P.wi].id]
	var gx: float = P.x + P.w / 2.0 - _cam_draw.x
	var gy: float = P.y + P.h / 2.0 - 2 - _cam_draw.y
	draw_set_transform(Vector2(gx, gy), P.aim)
	draw_rect(Rect2(2, -3, w.len, 6), Color("#222b3d"))
	draw_rect(Rect2(w.len - 3, -2, 4, 4), _col(w.color))
	draw_set_transform(-_cam_draw)
	# кольцо щита
	if P.shield > 0:
		var pc := Vector2(P.x + P.w / 2.0, P.y + P.h / 2.0)
		var sa := clampf(P.shield / max(1.0, P.max_shield), 0.0, 1.0)
		draw_arc(pc, P.w * 0.9, -PI / 2, -PI / 2 + TAU * sa, 24, Color(0.5, 0.83, 1.0, 0.85), 2.5)
		draw_circle(pc, P.w * 0.9, Color(0.5, 0.83, 1.0, 0.08))

func _draw_bullets() -> void:
	for b in bullets:
		var col: Color = b.color
		if b.get("grenade", false):
			# граната — вращающийся снаряд со светящимся следом
			draw_circle(Vector2(b.x, b.y), 6, col)
			draw_circle(Vector2(b.x, b.y), 3, Color(1, 1, 1, 0.6))
			draw_circle(Vector2(b.x - b.vx * 0.6, b.y - b.vy * 0.6), 3, Color(col.r, col.g, col.b, 0.35))
		elif b.get("pierce", false):
			# рельса — толстый яркий луч
			var from := Vector2(b.x - b.vx * 1.8, b.y - b.vy * 1.8)
			draw_line(from, Vector2(b.x, b.y), Color(2.4, 2.4, 2.6, 0.5), 5.0)
			draw_line(from, Vector2(b.x, b.y), Color(col.r * 1.6, col.g * 1.6, col.b * 1.6, 1.0), 3.0)
		else:
			var from := Vector2(b.x - b.vx * 1.4, b.y - b.vy * 1.4)
			# мягкое свечение + яркое ядро
			draw_line(from, Vector2(b.x, b.y), Color(col.r, col.g, col.b, 0.25), (7.0 if b.crit else 5.0))
			draw_line(from, Vector2(b.x, b.y), col, 3.5 if b.crit else 2.5)
			draw_circle(Vector2(b.x, b.y), 1.6 if b.crit else 1.2, Color(2.6, 2.6, 2.6, 0.85) if b.crit else Color(1.4, 1.4, 1.4, 0.85))

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
	# полоса щита поверх верхнего края HP
	if P.shield > 0:
		var sw := hpw * clampf(P.shield / P.maxhp, 0, 1)
		draw_rect(Rect2(14, 12, sw, 4), Color("#7fd4ff"))
	_text(Vector2(20, 27), "%d / %d" % [ceili(P.hp), int(P.maxhp)], 12, Color("#eaf0ff"))

	# индикатор рывка
	var dy := 38.0
	draw_rect(Rect2(12, dy, 120, 8), Color(0, 0, 0, 0.45))
	var dfrac := 1.0 - clampf(float(P.dash_cd) / 55.0, 0, 1)
	draw_rect(Rect2(13, dy + 1, 118 * dfrac, 6), Color("#7fdcff") if dfrac >= 1.0 else Color("#3a6c8c"))
	_text(Vector2(136, dy + 8), "рывок (Shift/ПКМ)", 10, Color("#8d97bd"))

	# заряд ультимейта
	var uy := 50.0
	draw_rect(Rect2(12, uy, 120, 8), Color(0, 0, 0, 0.45))
	var ufrac := clampf(ult / ULT_MAX, 0, 1)
	var ready := ufrac >= 1.0
	var ucol := Color("#ffd86b") if (ready and (tick % 20 < 10)) else (Color("#ff9e4d") if ready else Color("#7a5a2c"))
	draw_rect(Rect2(13, uy + 1, 118 * ufrac, 6), ucol)
	_text(Vector2(136, uy + 8), "ПЕРЕГРУЗКА (Q)" if ready else "перегрузка (Q)", 10, Color("#ffd86b") if ready else Color("#8d97bd"))

	# серия убийств
	if combo >= 3:
		var m := combo_mult()
		var alpha := clampf(combo_t / 40.0, 0.35, 1.0)
		_text(Vector2(VW / 2.0, 70), "СЕРИЯ x%d  (очки x%.1f)" % [combo, m], 18, Color(1, 0.85, 0.42, alpha), true)

	# уровень/тема
	var title := "Уровень %d · %s" % [lvl, level.theme.name]
	if boss_alive:
		title = "Уровень %d · %s" % [lvl, boss_name if boss_name != "" else "БОСС"]
	_text(Vector2(VW / 2.0, 24), title, 14, Color("#dfe5ff"), true)

	# полоса здоровья босса
	if boss_alive:
		var boss = null
		for en in enemies:
			if en.get("boss", false) and not en.dead:
				boss = en
				break
		if boss != null:
			var bw := 520.0
			var bx := VW / 2.0 - bw / 2.0
			draw_rect(Rect2(bx - 3, VH - 86, bw + 6, 22), Color(0, 0, 0, 0.55))
			var bfrac := clampf(float(boss.hp) / boss.maxhp, 0, 1)
			draw_rect(Rect2(bx, VH - 83, bw * bfrac, 16), Color("#ff4db0"))
			_text(Vector2(VW / 2.0, VH - 70), boss_name if boss_name != "" else "БОСС", 12, Color("#ffe9b0"), true)
			_draw_offscreen_arrow(Vector2(boss.x + boss.w / 2.0, boss.y + boss.h / 2.0), Color("#ff4db0"))
	else:
		# указатель на портал, если он за краем экрана
		_draw_offscreen_arrow(Vector2(level.exit_px.x, level.exit_px.y + TILE / 2.0), Color("#9be8ff"))

	# очки
	var score_str := str(score)
	var ssz := font.get_string_size(score_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	_text(Vector2(VW - 16 - ssz.x, 26), score_str, 16, Color("#ffd86b"))
	var sub := "● %d · убийств: %d · сид: %s" % [coins, kills, seed_label]
	var subsz := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	_text(Vector2(VW - 16 - subsz.x, 44), sub, 11, Color("#8d97bd"))

	# часы забега под заголовком
	_text(Vector2(VW / 2.0, 40), _fmt_time(run_ticks), 11, Color("#6f7aa3"), true)

	_draw_minimap()

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

	# пульс при низком здоровье
	if state == "play":
		var hpr: float = P.hp / maxf(1.0, P.maxhp)
		if hpr < 0.3:
			var pulse := 0.18 + 0.16 * (0.5 + 0.5 * sin(tick * 0.18))
			var dang := (1.0 - hpr / 0.3)   # чем меньше HP, тем сильнее
			draw_rect(Rect2(0, 0, VW, VH), Color(0.9, 0.05, 0.08, pulse * dang * 0.6))
			if vignette_tex:
				draw_texture_rect(vignette_tex, Rect2(0, 0, VW, VH), false, Color(1.0, 0.2, 0.2, pulse * dang * 2.0))

	# интро
	if intro > 0:
		var a := clampf((150 - intro) / 30.0 if intro > 120 else intro / 60.0, 0, 1)
		# кинематографичный леттербокс на боссовых уровнях
		if boss_alive:
			var bar := 46.0 * a
			draw_rect(Rect2(0, 0, VW, bar), Color(0, 0, 0, 0.9))
			draw_rect(Rect2(0, VH - bar, VW, bar), Color(0, 0, 0, 0.9))
		_text(Vector2(VW / 2.0, VH / 2.0 - 60), intro_text, 30, Color(1, 0.91, 0.69, a), true)
		_text(Vector2(VW / 2.0, VH / 2.0 - 30), "Доберитесь до портала →", 15, Color(0.67, 0.70, 0.84, a), true)

	_draw_toasts()

	# прицел
	if state == "play":
		var m := get_local_mouse_position()
		draw_arc(m, 7, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
		draw_rect(Rect2(m.x - 1, m.y - 1, 2, 2), Color(1, 1, 1, 0.9))

func _draw_toasts() -> void:
	var ty := 100.0
	for t in toasts:
		var a := clampf(t.life / 40.0, 0, 1)
		var tw := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 28
		var tx := VW / 2.0 - tw / 2.0
		draw_rect(Rect2(tx, ty, tw, 26), Color(0.1, 0.12, 0.2, 0.85 * a))
		draw_rect(Rect2(tx, ty, 4, 26), Color(1, 0.85, 0.42, a))
		_text(Vector2(VW / 2.0, ty + 18), t.text, 15, Color(1, 0.92, 0.7, a), true)
		ty += 32

func _fmt_time(ticks: int) -> String:
	var sec := int(ticks / 60.0)
	return "%d:%02d" % [int(sec / 60.0), sec % 60]

func _draw_minimap() -> void:
	var mw := 168.0
	var mh := 50.0
	var ox := VW - 12 - mw
	var oy := 58.0
	draw_rect(Rect2(ox - 2, oy - 2, mw + 4, mh + 4), Color(0, 0, 0, 0.5))
	var sx := mw / float(level.px_w)
	var sy := mh / float(level.px_h)
	var W: int = level.W
	# силуэт рельефа
	var col_ground: Color = th.ground
	for i in range(int(mw)):
		var c := clampi(int(i / mw * W), 0, W - 1)
		var py: float = level.ground_y[c] * TILE * sy
		draw_rect(Rect2(ox + i, oy + py, 1, mh - py), Color(col_ground.r, col_ground.g, col_ground.b, 0.75))
	# портал
	var ex: Vector2 = level.exit_px
	draw_rect(Rect2(ox + ex.x * sx - 1, oy + ex.y * sy - 2, 3, 4), Color("#9be8ff"))
	# враги
	for en in enemies:
		if en.dead:
			continue
		var ec := Color("#ff6b5e")
		if en.get("boss", false):
			ec = Color("#ff4db0")
		elif en.type == "flyer":
			ec = Color("#5fb0e8")
		var sz := 3.0 if en.get("boss", false) else 2.0
		draw_rect(Rect2(ox + (en.x + en.w / 2.0) * sx - sz / 2, oy + (en.y + en.h / 2.0) * sy - sz / 2, sz, sz), ec)
	# игрок
	draw_rect(Rect2(ox + (P.x + P.w / 2.0) * sx - 1.5, oy + (P.y + P.h / 2.0) * sy - 1.5, 3, 3), Color("#3ec6a8"))

func _draw_offscreen_arrow(world_pos: Vector2, color: Color) -> void:
	var sp := world_pos - cam
	var margin := 28.0
	if sp.x > margin and sp.x < VW - margin and sp.y > margin and sp.y < VH - margin:
		return  # цель на экране — стрелка не нужна
	var pos := Vector2(clampf(sp.x, margin, VW - margin), clampf(sp.y, margin, VH - margin))
	var ang := (sp - pos).angle()
	draw_set_transform(pos, ang)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-7, -8), Vector2(-7, 8)]), color)
	draw_set_transform(Vector2.ZERO)

func _btn(rect: Rect2, label: String, key: String, primary := true) -> void:
	var bg := Color("#ffc24d") if primary else Color(1, 1, 1, 0.10)
	draw_rect(rect, bg)
	var tc := Color("#2a1c04") if primary else Color("#cfd6f5")
	_text(Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y / 2.0 + 6), label, 16, tc, true)
	_ui_rects[key] = rect

func _shake_offset() -> Vector2:
	if shake <= 0 or not shake_on:
		return Vector2.ZERO
	return Vector2((rng.randf() - 0.5) * shake, (rng.randf() - 0.5) * shake)

func toggle_shake() -> void:
	shake_on = not shake_on
	_save_settings()

func toggle_bloom() -> void:
	bloom_on = not bloom_on
	_apply_bloom()
	_save_settings()

func _start_slowmo(factor: float, real_secs: float) -> void:
	# кратковременное замедление времени; восстановление по реальному времени
	if test_mode:
		return
	Engine.time_scale = factor
	var tmr := get_tree().create_timer(real_secs, true, false, true)  # ignore_time_scale
	tmr.timeout.connect(func() -> void: Engine.time_scale = 1.0)

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
			_text(Vector2(cx, 274), "Мышь — прицел · ЛКМ — огонь · 1–7/колесо — оружие", 14, Color("#8d97bd"), true)
			_text(Vector2(cx, 298), "Shift/ПКМ — рывок · Q — перегрузка · Esc — пауза · M — звук", 14, Color("#8d97bd"), true)
			_text(Vector2(cx, 322), "Каждый 5-й уровень — БОСС", 13, Color("#ff8fc4"), true)
			_btn(Rect2(cx - 90, 344, 180, 50), "Играть", "play")
			var bl := "Рекорд: %d очков" % best if best > 0 else "Удачного первого забега!"
			_text(Vector2(cx, 410), bl, 14, Color("#6f7aa3"), true)
			_text(Vector2(cx, 430), "Достижения: %d / %d  ·  Enter / клик — старт" % [unlocked.size(), ACHIEVEMENTS.size()], 13, Color("#6f7aa3"), true)
			_draw_volume(cx, 458)
		"pause":
			_text(Vector2(cx, 150), "Пауза", 40, Color("#eaf0ff"), true)
			_btn(Rect2(cx - 90, 196, 180, 46), "Продолжить", "resume")
			_btn(Rect2(cx - 130, 252, 260, 38), "Тряска экрана: %s" % ("Вкл" if shake_on else "Выкл"), "toggle_shake", false)
			_btn(Rect2(cx - 130, 298, 260, 38), "Свечение (bloom): %s" % ("Вкл" if bloom_on else "Выкл"), "toggle_bloom", false)
			_btn(Rect2(cx - 90, 344, 180, 40), "В меню", "quit", false)
			_text(Vector2(cx, 404), "Геймпад поддерживается", 12, Color("#6f7aa3"), true)
			_draw_volume(cx, 424)
		"dead":
			_text(Vector2(cx, 120), "Вы погибли", 44, Color("#ff6b5e"), true)
			var is_record := score >= best and score > 0
			if is_record:
				_text(Vector2(cx, 156), "★ НОВЫЙ РЕКОРД ★", 16, Color("#ffd86b"), true)
			_text(Vector2(cx, 196), "Очки: %d" % score, 22, Color("#ffd86b"), true)
			# таблица статистики забега
			var rows := [
				["Уровень", "%d" % lvl],
				["Убийств", "%d" % kills],
				["Лучшая серия", "x%d" % max_combo],
				["Точность", "%d%% (%d/%d)" % [int(round(accuracy() * 100)), shots_hit, shots_fired]],
				["Урон нанесён", "%d" % damage_dealt],
				["Время", _fmt_time(run_ticks)],
				["Рекорд", "%d" % best],
			]
			var ry := 226.0
			for row in rows:
				var lbl: String = row[0]
				var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				_text(Vector2(cx - 14 - lw, ry), lbl, 14, Color("#8d97bd"))
				_text(Vector2(cx + 14, ry), row[1], 14, Color("#dfe5ff"))
				ry += 22
			_btn(Rect2(cx - 190, 420, 180, 50), "Новый забег", "retry")
			_btn(Rect2(cx + 10, 420, 180, 50), "В меню", "menu", false)
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
		"shop":
			_text(Vector2(cx, 80), "Магазин", 36, Color("#ffe9b0"), true)
			_text(Vector2(cx, 116), "Монеты: ● %d   (цифры 1–5 или клик — купить)" % coins, 16, Color("#ffd86b"), true)
			var n := shop_items.size()
			var cw := 165.0
			var gap := 14.0
			var total := n * cw + (n - 1) * gap
			var sx := cx - total / 2.0
			for i in range(n):
				var it: Dictionary = shop_items[i]
				var rect := Rect2(sx + i * (cw + gap), 160, cw, 210)
				var affordable: bool = coins >= it.price and not it.sold
				draw_rect(rect, Color(1, 1, 1, 0.05) if not it.sold else Color(0, 0, 0, 0.25))
				draw_rect(rect, Color(1, 0.85, 0.42, 0.6) if affordable else Color(1, 1, 1, 0.15), false, 2.0)
				_ui_rects["shop%d" % i] = rect
				var ccx := rect.position.x + cw / 2.0
				var fade := 0.4 if it.sold else 1.0
				_text(Vector2(ccx, rect.position.y + 56), it.icon, 40, Color(1, 0.91, 0.69, fade), true)
				_text(Vector2(ccx, rect.position.y + 92), it.name, 17, Color(1, 0.91, 0.69, fade), true)
				_draw_wrapped(it.desc, rect.position.x + 12, rect.position.y + 118, cw - 24, 13, Color(0.67, 0.70, 0.84, fade))
				if it.sold:
					_text(Vector2(ccx, rect.position.y + 176), "куплено", 14, Color("#7df2a5"), true)
				else:
					var pc := Color("#ffd86b") if affordable else Color("#ff6b5e")
					_text(Vector2(ccx, rect.position.y + 176), "● %d" % it.price, 16, pc, true)
				_text(Vector2(ccx, rect.position.y + 198), "[%d]" % (i + 1), 13, Color("#8d97bd"), true)
			_btn(Rect2(cx - 110, 396, 220, 48), "Дальше →", "shop_continue")

func _draw_volume(cx: float, y: float) -> void:
	var bw := 160.0
	var bx := cx - bw / 2.0
	_text(Vector2(cx, y - 10), "Громкость  ( − / + )", 12, Color("#8d97bd"), true)
	draw_rect(Rect2(bx, y, bw, 10), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bx + 1, y + 1, (bw - 2) * volume, 8), Color("#ffc24d"))
	_text(Vector2(cx, y + 28), "%d%%" % int(round(volume * 100)), 12, Color("#cfd6f5"), true)

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
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -9.0  # музыка тише эффектов
	add_child(_music_player)
	_sfx_cache = {
		"shoot": Synth.tone(320, 90, 0.09, "square", 0.30),
		"shotgun": Synth.noise(0.22, 0.55, false),
		"rifle": Synth.tone(520, 120, 0.12, "square", 0.32),
		"hit": Synth.tone(210, 140, 0.06, "triangle", 0.40),
		"kill": Synth.noise(0.18, 0.5, true),
		"hurt": Synth.tone(160, 55, 0.22, "saw", 0.45),
		"jump": Synth.tone(240, 480, 0.10, "square", 0.22),
		"pickup": Synth.tone(520, 880, 0.12, "square", 0.30),
		"portal": Synth.tone(330, 760, 0.30, "sine", 0.40),
		"select": Synth.tone(600, 900, 0.08, "square", 0.24),
		"dash": Synth.tone(180, 520, 0.16, "sine", 0.30),
		"flame": Synth.noise(0.14, 0.22, false),
		"boom": Synth.noise(0.35, 0.6, true),
		"die": Synth.noise(0.4, 0.55, true),
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

func _play_music(theme_idx: int, intense: bool) -> void:
	if _music_player == null:
		return
	var key := "%d_%s" % [theme_idx % 5, intense]
	if key == _music_key and _music_player.playing:
		return
	_music_key = key
	if not _music_cache.has(key):
		_music_cache[key] = Synth.build_music(theme_idx, intense)
	if not audio_enabled:
		return
	_music_player.stream = _music_cache[key]
	_music_player.play()

func _stop_music() -> void:
	_music_key = ""
	if _music_player != null:
		_music_player.stop()

# ============================== Сохранения и настройки ==============================
# Рекорд и громкость хранятся в ConfigFile (user://gunfall.cfg).

func _cfg_path() -> String:
	return "user://gunfall.cfg"

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_cfg_path()) == OK:
		best = int(cfg.get_value("progress", "best", 0))
		volume = clampf(float(cfg.get_value("settings", "volume", 0.8)), 0.0, 1.0)
		shake_on = bool(cfg.get_value("settings", "shake", true))
		bloom_on = bool(cfg.get_value("settings", "bloom", true))
		unlocked.clear()
		if cfg.has_section("achievements"):
			for k in cfg.get_section_keys("achievements"):
				unlocked[k] = true
	else:
		# совместимость со старым форматом рекорда
		var old := "user://gunfall_best.save"
		if FileAccess.file_exists(old):
			var f := FileAccess.open(old, FileAccess.READ)
			if f:
				best = f.get_32()
				f.close()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "shake", shake_on)
	cfg.set_value("settings", "bloom", bloom_on)
	for id in unlocked.keys():
		cfg.set_value("achievements", id, true)
	cfg.save(_cfg_path())

# ============================== Достижения ==============================

func _ach_name(id: String) -> String:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a.name
	return id

func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	toasts.append({ "text": "Достижение: " + _ach_name(id), "life": 200.0 })
	play_sfx("portal")
	_save_settings()

func check_achievements() -> void:
	if kills >= 1:
		unlock("first_blood")
	if max_combo >= 10:
		unlock("combo_master")
	if P.weapons.size() >= 4:
		unlock("arsenal")
	if lvl >= 10:
		unlock("deep_diver")
	if score >= 1000:
		unlock("high_score")
	if run_ticks >= 60 * 180:
		unlock("survivor")
	if shots_fired >= 30 and accuracy() >= 0.9:
		unlock("sharpshooter")

func _save_best(v: int) -> void:
	best = v
	_save_settings()

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	_save_settings()

func _apply_volume() -> void:
	# мастер-шина 0; в headless AudioServer-заглушка просто игнорирует
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
