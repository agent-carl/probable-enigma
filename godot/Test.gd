extends SceneTree
## Headless-тест GUNFALL: генерация уровней и симуляция геймплея без рендера.
## Запуск: godot --headless --path godot --script res://Test.gd

var failures := 0

func _ok(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)
		print("FAIL: ", msg)

func _init() -> void:
	var GameScript = load("res://Game.gd")
	var game = GameScript.new()
	game.test_mode = true
	get_root().add_child(game)

	# ---------- 1. Генерация уровней ----------
	var T_SOLID := 1
	var T_SPIKE := 3
	var T_EXIT := 4
	var total_enemies := 0
	var total_pickups := 0
	for s in range(1, 81):
		for lvl in range(1, 7):
			var L: Dictionary = game.generate_level(s * 7919 + lvl, lvl)
			var W: int = L.W
			var H: int = L.H
			var grid: PackedByteArray = L.grid
			var gy: Array = L.ground_y

			# спавн на твёрдой опоре, без шипов рядом
			var sx := int(L.spawn.x / 32)
			_ok(grid[gy[sx] * W + sx] == T_SOLID, "s%dl%d spawn ground solid" % [s, lvl])

			# ровно два тайла выхода
			var exits := 0
			for v in grid:
				if v == T_EXIT:
					exits += 1
			_ok(exits == 2, "s%dl%d exit==2 got %d" % [s, lvl, exits])

			# проходимость: перепады и ямы
			var run_start := -1
			for x in range(1, W):
				var spike_here := grid[(gy[x] - 1) * W + x] == T_SPIKE
				var spike_prev := grid[(gy[x - 1] - 1) * W + (x - 1)] == T_SPIKE
				if spike_here and not spike_prev:
					run_start = x
				if not spike_here and spike_prev and run_start > 0:
					var run_len := x - run_start
					_ok(run_len <= 4 or gy[run_start - 1] == gy[x], "s%dl%d pit x=%d len=%d jumpable" % [s, lvl, run_start, run_len])
					_ok(run_len <= 6, "s%dl%d pit len %d <= 6" % [s, lvl, run_len])
					run_start = -1
				if not spike_here and not spike_prev:
					_ok(abs(gy[x] - gy[x - 1]) <= 1, "s%dl%d step at x=%d" % [s, lvl, x])

			# враги не в стенах, не у спавна
			for en in L.enemies:
				var ex0 := int(en.x / 32)
				var ey0 := int(en.y / 32)
				var ex1 := int((en.x + en.w - 0.01) / 32)
				var ey1 := int((en.y + en.h - 0.01) / 32)
				for ty in range(ey0, ey1 + 1):
					for tx in range(ex0, ex1 + 1):
						if tx >= 0 and tx < W and ty >= 0 and ty < H:
							_ok(grid[ty * W + tx] != T_SOLID, "s%dl%d enemy %s inside solid" % [s, lvl, en.type])
				_ok(en.x > 10 * 32, "s%dl%d enemy %s far from spawn" % [s, lvl, en.type])
				_ok(en.hp > 0, "s%dl%d enemy hp sane" % [s, lvl])
			total_enemies += L.enemies.size()
			total_pickups += L.pickups.size()
			_ok(L.enemies.size() >= 5, "s%dl%d enough enemies %d" % [s, lvl, L.enemies.size()])
			_ok(L.pickups.size() >= 3, "s%dl%d enough pickups %d" % [s, lvl, L.pickups.size()])

			# детерминированность
			var L2: Dictionary = game.generate_level(s * 7919 + lvl, lvl)
			_ok(L2.grid == grid, "s%dl%d deterministic grid" % [s, lvl])
			_ok(L2.enemies.size() == L.enemies.size(), "s%dl%d deterministic enemies" % [s, lvl])
	print("levelgen: 480 levels checked, avg enemies=%.1f pickups=%.1f" % [total_enemies / 480.0, total_pickups / 480.0])

	# ---------- 2. Симуляция геймплея ----------
	for seed_v in [1, 42, 777, 123456789]:
		var r := simulate(game, seed_v, 5000)
		print("sim seed=%d: cleared=%d deaths=%d final_lvl=%d score=%d" % [seed_v, r.cleared, r.deaths, r.final_lvl, r.score])
		_ok(r.cleared >= 3, "seed %d cleared several levels (%d)" % [seed_v, r.cleared])

	# ---------- 3. Смерть и рестарт ----------
	game.start_run(99, "99")
	game.P.inv = 0
	game.hurt_player(99999, 1)
	_ok(game.state == "dead", "lethal -> dead")
	_ok(game.P.hp == 0, "hp clamped 0")
	game.start_run(100, "100")
	_ok(game.state == "play" and game.P.hp == game.P.maxhp, "restart resets")

	# ---------- 4. Улучшения ----------
	var before: float = game.P.stats.dmg_mul
	game.choose_upgrade({ "id": "dmg" })
	_ok(abs(game.P.stats.dmg_mul - before * 1.15) < 1e-6, "dmg upgrade applied")
	_ok(game.lvl == 2, "upgrade advances level")
	game.choose_upgrade({ "id": "djump" })
	_ok(game.P.stats.jumps == 2, "double jump applied")

	# ---------- 5. Боссы ----------
	var L5: Dictionary = game.generate_level(555, 5)
	_ok(L5.has_boss, "level 5 has boss flag")
	var bosses := 0
	for en in L5.enemies:
		if en.get("boss", false):
			bosses += 1
			_ok(en.hp > 0, "boss hp > 0")
	_ok(bosses == 1, "exactly one boss on level 5 (got %d)" % bosses)
	var L4: Dictionary = game.generate_level(444, 4)
	_ok(not L4.has_boss, "level 4 has no boss")
	var L10: Dictionary = game.generate_level(101010, 10)
	_ok(L10.has_boss, "level 10 has boss flag")

	# гейтинг портала и убийство босса
	game.start_run(7, "7")
	game.lvl = 5
	game.start_level()
	_ok(game.boss_alive, "boss_alive on boss level")
	game.input.move = 0
	game.input.shoot_held = false
	game.input.shoot_clicked = false
	game.input.jump_pressed = false
	game.input.dash = false
	game.P.x = game.level.exit_px.x - 8
	game.P.y = game.level.exit_px.y
	game.sim_step()
	_ok(game.state == "play", "portal gated while boss alive")
	var boss = null
	for en in game.enemies:
		if en.get("boss", false):
			boss = en
			break
	_ok(boss != null, "boss present in enemies")
	if boss != null:
		var sc_before: int = game.score
		game.hurt_enemy(boss, 99999, false)
		_ok(not game.boss_alive, "boss death clears gate")
		_ok(game.score > sc_before, "boss kill grants score")
	for _i in range(30):
		game.sim_step()  # переждать hitstop
	game.P.x = game.level.exit_px.x - 8
	game.P.y = game.level.exit_px.y
	game.sim_step()
	_ok(game.state == "upgrade", "portal opens after boss dead")
	game.choose_upgrade(game.offer[0])

	# ---------- 6. Серия убийств (комбо) ----------
	game.start_run(8, "8")
	game.combo = 0
	game.combo_t = 0
	for _i in range(4):
		var e := { "type": "walker", "x": 100.0, "y": 100.0, "w": 20, "h": 20, "hp": 1, "maxhp": 10, "score": 10, "dead": false, "hurt_t": 0 }
		game.enemies.append(e)
		game.hurt_enemy(e, 50, false)
	_ok(game.combo == 4, "combo increments per kill (got %d)" % game.combo)
	_ok(game.combo_mult() > 1.0, "combo multiplier rises above 1")

	# ---------- 7. Рывок ----------
	game.start_run(9, "9")
	game.input.move = 1
	game.input.dash = true
	game.sim_step()
	_ok(game.P.dash_t > 0, "dash activates (dash_t > 0)")
	_ok(game.P.dash_cd > 0, "dash sets cooldown")

	# ---------- 8. Взрыв бьёт по площади ----------
	game.start_run(11, "11")
	game.enemies.clear()
	var targets := []
	for k in range(3):
		var e := { "type": "walker", "x": 200.0 + k * 20, "y": 200.0, "w": 20, "h": 20, "hp": 30, "maxhp": 30, "score": 10, "dead": false, "hurt_t": 0, "eid": 1000 + k }
		game.enemies.append(e)
		targets.append(e)
	game.explode(210, 210, 80, 40, "p")
	var dead_count := 0
	for e in targets:
		if e.dead:
			dead_count += 1
	_ok(dead_count == 3, "explosion hits all enemies in radius (got %d)" % dead_count)
	# враг вне радиуса не задет
	var far := { "type": "walker", "x": 900.0, "y": 200.0, "w": 20, "h": 20, "hp": 30, "maxhp": 30, "score": 10, "dead": false, "hurt_t": 0, "eid": 2000 }
	game.enemies.append(far)
	game.explode(210, 210, 80, 40, "p")
	_ok(not far.dead, "explosion spares enemies out of radius")

	# ---------- 9. Граната подрывается ----------
	game.start_run(12, "12")
	game.bullets.clear()
	game.enemies.clear()
	var ge := { "type": "walker", "x": 300.0, "y": 200.0, "w": 24, "h": 24, "hp": 30, "maxhp": 30, "score": 10, "dead": false, "hurt_t": 0, "eid": 5 }
	game.enemies.append(ge)
	# граната летит прямо в цель
	game.bullets.append({ "x": 280.0, "y": 210.0, "vx": 8.0, "vy": 0.0, "dmg": 34, "crit": false, "from": "p", "life": 80, "color": "#9ef07f", "grenade": true, "radius": 80 })
	for _i in range(20):
		game.update_bullets()
		if ge.dead:
			break
	_ok(ge.dead, "grenade detonates and kills nearby enemy")

	# ---------- 10. Рельса пробивает несколько целей ----------
	game.bullets.clear()
	game.enemies.clear()
	var line := []
	for k in range(3):
		var e := { "type": "walker", "x": 400.0 + k * 30, "y": 200.0, "w": 20, "h": 30, "hp": 40, "maxhp": 40, "score": 10, "dead": false, "hurt_t": 0, "eid": 700 + k }
		game.enemies.append(e)
		line.append(e)
	game.bullets.append({ "x": 395.0, "y": 210.0, "vx": 22.0, "vy": 0.0, "dmg": 55, "crit": false, "from": "p", "life": 60, "color": "#7fd4ff", "pierce": true, "hit_ids": [] })
	for _i in range(30):
		game.update_bullets()
	var pierced := 0
	for e in line:
		if e.dead:
			pierced += 1
	_ok(pierced == 3, "railgun pierces multiple enemies (got %d)" % pierced)

	# ---------- 11. Камикадзе подрывается при гибели и бьёт по игроку ----------
	game.start_run(13, "13")
	game.enemies.clear()
	var bomber := { "type": "exploder", "x": 500.0, "y": 200.0, "w": 22, "h": 24, "hp": 18, "maxhp": 18, "score": 18, "dmg": 24, "radius": 62, "dead": false, "hurt_t": 0, "eid": 9 }
	game.P.x = 500.0
	game.P.y = 200.0
	game.P.inv = 0
	var hp0: float = game.P.hp
	game.enemies.append(bomber)
	game.hurt_enemy(bomber, 999, false)
	_ok(bomber.dead, "exploder dies")
	_ok(game.P.hp < hp0, "exploder death explosion damages nearby player")

	# в боссовой генерации появляются камикадзе на поздних уровнях
	var has_exploder := false
	var L7: Dictionary = game.generate_level(7777, 7)
	for en in L7.enemies:
		if en.type == "exploder":
			has_exploder = true
	_ok(has_exploder, "exploders spawn on level 7")

	# ---------- 12. Щит поглощает урон раньше HP ----------
	game.start_run(21, "21")
	game.P.inv = 0
	game.P.shield = 30.0
	game.P.max_shield = 30.0
	var hp_before: float = game.P.hp
	game.hurt_player(20, 0)
	_ok(game.P.shield == 10.0, "shield absorbs damage first (shield=%s)" % str(game.P.shield))
	_ok(game.P.hp == hp_before, "hp untouched while shield holds")
	game.P.inv = 0
	game.hurt_player(25, 0)  # 10 щита + 15 в HP
	_ok(game.P.shield == 0.0, "shield depleted")
	_ok(game.P.hp == hp_before - 15, "overflow damage hits hp (hp=%s)" % str(game.P.hp))

	# ---------- 13. Статистика забега ----------
	game.start_run(22, "22")
	_ok(game.shots_fired == 0 and game.shots_hit == 0 and game.damage_dealt == 0, "stats reset on run start")
	game.enemies.clear()
	var dummy := { "type": "walker", "x": 300.0, "y": 200.0, "w": 20, "h": 30, "hp": 100, "maxhp": 100, "score": 10, "dead": false, "hurt_t": 0, "eid": 1 }
	game.enemies.append(dummy)
	game.bullets.clear()
	game.bullets.append({ "x": 295.0, "y": 210.0, "vx": 18.0, "vy": 0.0, "dmg": 30, "crit": false, "from": "p", "life": 30, "color": "#fff" })
	for _i in range(5):
		game.update_bullets()
	_ok(game.shots_hit >= 1, "hit registered for stats")
	_ok(game.damage_dealt >= 30, "damage tracked (got %d)" % game.damage_dealt)
	# точность в разумных пределах
	game.shots_fired = 10
	game.shots_hit = 5
	_ok(abs(game.accuracy() - 0.5) < 1e-6, "accuracy computed correctly")

	# ---------- 14. Громкость: установка, кламп, сохранение ----------
	game.set_volume(0.5)
	_ok(abs(game.volume - 0.5) < 1e-6, "volume set")
	game.set_volume(1.5)
	_ok(game.volume == 1.0, "volume clamped to 1.0")
	game.set_volume(-1.0)
	_ok(game.volume == 0.0, "volume clamped to 0.0")
	game.set_volume(0.3)
	game.best = 4242
	game._save_settings()
	game.volume = 0.0
	game.best = 0
	game._load_settings()
	_ok(abs(game.volume - 0.3) < 1e-6, "volume persists across save/load (got %s)" % str(game.volume))
	_ok(game.best == 4242, "best persists across save/load")

	# ---------- 15. Новые улучшения ----------
	# Энергощит: запас + регенерация
	game.start_run(31, "31")
	game.choose_upgrade({ "id": "shieldup" })
	_ok(game.P.max_shield >= 30, "shieldup grants max shield")
	_ok(game.P.stats.shield_regen > 0, "shieldup enables regen")
	game.P.shield = 5.0
	game.input.move = 0
	game.input.dash = false
	game.sim_step()
	_ok(game.P.shield > 5.0 and game.P.shield <= game.P.max_shield, "shield regenerates over time")

	# Реактивный рывок: меньше кулдаун
	game.start_run(32, "32")
	game.choose_upgrade({ "id": "dashcd" })
	game.input.move = 1
	game.input.dash = true
	game.sim_step()
	_ok(game.P.dash_cd == int(round(55 * 0.7)), "dashcd shortens dash cooldown (got %d)" % game.P.dash_cd)

	# Сапёр: больший радиус взрыва
	game.start_run(33, "33")
	game.choose_upgrade({ "id": "blast" })
	game.enemies.clear()
	var near_e := { "type": "walker", "x": 490.0, "y": 290.0, "w": 20, "h": 20, "hp": 30, "maxhp": 30, "score": 10, "dead": false, "hurt_t": 0, "eid": 1 }
	var far_e := { "type": "walker", "x": 525.0, "y": 290.0, "w": 20, "h": 20, "hp": 30, "maxhp": 30, "score": 10, "dead": false, "hurt_t": 0, "eid": 2 }
	game.enemies.append(near_e)
	game.enemies.append(far_e)
	game.explode(400, 300, 80, 40, "p")  # базовый радиус 80 -> 112 с x1.4
	_ok(near_e.dead, "blast upgrade extends radius to hit enemy at 100px")
	_ok(not far_e.dead, "enemy beyond extended radius survives")

	# Магнит: притягивает не-монеты
	game.start_run(34, "34")
	game.choose_upgrade({ "id": "magnet" })
	_ok(game.P.stats.magnet_range >= 180, "magnet increases range")
	game.P.x = 100.0
	game.P.y = 300.0
	var med_pk := { "kind": "med", "x": 240.0, "y": 300.0, "w": 22, "h": 18, "vy": 0.0, "t": 0.0, "heal": 30 }
	game.pickups = [med_pk]
	var px0: float = med_pk.x
	game.update_pickups()
	_ok(med_pk.x < px0, "magnet pulls non-coin pickup toward player")

	# Берсерк: урон растёт с серией
	game.start_run(35, "35")
	game.choose_upgrade({ "id": "berserk" })
	game.P.weapons = [{ "id": "pistol", "ammo": INF }]
	game.P.wi = 0
	game.P.stats.crit = 0.0
	game.input.shoot_held = true
	game.input.shoot_clicked = true
	game.input.aim = Vector2(game.P.x + 100, game.P.y)
	game.combo = 20
	game.P.cd = 0
	game.bullets.clear()
	game.try_shoot()
	var d_hi: int = game.bullets[0].dmg
	game.combo = 0
	game.P.cd = 0
	game.bullets.clear()
	game.input.shoot_clicked = true
	game.try_shoot()
	var d_lo: int = game.bullets[0].dmg
	_ok(d_hi > d_lo, "berserk raises damage with combo (%d vs %d)" % [d_hi, d_lo])

	# ---------- 16. Достижения ----------
	game.unlocked.clear()
	game.toasts.clear()
	game.unlock("first_blood")
	_ok(game.unlocked.has("first_blood"), "unlock registers achievement")
	_ok(game.toasts.size() == 1, "unlock shows a toast")
	game.unlock("first_blood")
	_ok(game.toasts.size() == 1, "re-unlock is idempotent (no extra toast)")

	game.start_run(36, "36")
	game.unlocked.clear()
	game.kills = 5
	game.max_combo = 12
	game.lvl = 11
	game.score = 1500
	game.shots_fired = 40
	game.shots_hit = 39
	game.check_achievements()
	_ok(game.unlocked.has("first_blood"), "achievement: first kill")
	_ok(game.unlocked.has("combo_master"), "achievement: combo 10")
	_ok(game.unlocked.has("deep_diver"), "achievement: level 10")
	_ok(game.unlocked.has("high_score"), "achievement: 1000 score")
	_ok(game.unlocked.has("sharpshooter"), "achievement: 90% accuracy")

	# достижения сохраняются
	game.unlocked.clear()
	game.unlock("boss_slayer")
	game._save_settings()
	game.unlocked.clear()
	game._load_settings()
	_ok(game.unlocked.has("boss_slayer"), "achievements persist across save/load")

	# ---------- 17. Разрушаемые ящики ----------
	# генерация размещает ящики
	var total_crates := 0
	for s2 in range(1, 31):
		for lv in range(1, 5):
			var LL: Dictionary = game.generate_level(s2 * 131 + lv, lv)
			total_crates += LL.crate_hp.size()
			# каждый ящик — действительно тайл T_CRATE на сетке
			for idx in LL.crate_hp.keys():
				_ok(LL.grid[idx] == 5, "crate tile present at stored index")
	_ok(total_crates > 0, "crates are generated (total %d)" % total_crates)

	# ящик ломается выстрелом и роняет лут; тайл становится пустым
	var WC := 6
	var HC := 6
	var gridc := PackedByteArray()
	gridc.resize(WC * HC)
	var crate_idx := 2 * WC + 2
	gridc[crate_idx] = 5  # T_CRATE
	game.level = { "W": WC, "H": HC, "grid": gridc, "px_w": WC * 32, "px_h": HC * 32,
		"crate_hp": { crate_idx: 24 }, "theme": { "top": "#58c98f" } }
	game.pickups = []
	game.damage_crate(2, 2, 10)
	_ok(game.level.grid[crate_idx] == 5, "crate survives partial damage")
	game.damage_crate(2, 2, 20)
	_ok(game.level.grid[crate_idx] == 0, "crate breaks at 0 hp (tile cleared)")
	_ok(not game.level.crate_hp.has(crate_idx), "crate hp entry removed")
	_ok(game.pickups.size() >= 1, "broken crate drops loot")

	# взрыв ломает ящик в радиусе
	var gridc2 := PackedByteArray()
	gridc2.resize(WC * HC)
	gridc2[crate_idx] = 5
	game.level = { "W": WC, "H": HC, "grid": gridc2, "px_w": WC * 32, "px_h": HC * 32,
		"crate_hp": { crate_idx: 24 }, "theme": { "top": "#58c98f" } }
	game.enemies = []
	game.explode(2 * 32 + 16, 2 * 32 + 16, 40, 100, "p")
	_ok(game.level.grid[crate_idx] == 0, "explosion destroys crate in radius")

	# ящик твёрдый: останавливает движение сущности
	var gridc3 := PackedByteArray()
	gridc3.resize(WC * HC)
	gridc3[crate_idx] = 5
	game.level = { "W": WC, "H": HC, "grid": gridc3, "px_w": WC * 32, "px_h": HC * 32,
		"crate_hp": { crate_idx: 24 }, "theme": { "top": "#58c98f" } }
	var mover := { "x": 44.0, "y": 64.0, "w": 20, "h": 28, "vx": 5.0, "vy": 0.0, "drop": 0, "on_ground": false, "hit_wall": false }
	game.collide_entity(mover)
	_ok(mover.hit_wall and mover.vx == 0.0, "crate blocks entity movement (solid)")

	if failures == 0:
		print("\nALL TESTS PASSED")
	else:
		print("\n%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

func simulate(game, seed_v: int, max_steps: int) -> Dictionary:
	game.start_run(seed_v, str(seed_v))
	var cleared := 0
	var deaths := 0
	for i in range(max_steps):
		if game.state == "play":
			game.input.move = 1
			game.input.jump_pressed = (i % 23 == 0)
			game.input.jump_held = true
			game.input.down = false
			game.input.aim = Vector2(game.P.x + 200, game.P.y)
			game.input.shoot_held = true
			game.input.shoot_clicked = (i % 7 == 0)
			game.input.dash = (i % 50 == 0)
			game.input.switch_to = -1
			if i > 0 and i % 600 == 0 and not game.boss_alive:
				game.P.x = game.level.exit_px.x - 8
				game.P.y = game.level.exit_px.y
		game.sim_step()
		if game.state == "upgrade":
			cleared += 1
			game.choose_upgrade(game.offer[i % game.offer.size()])
		if game.state == "dead":
			deaths += 1
			game.start_run(seed_v + deaths, str(seed_v + deaths))
		# инварианты
		_ok(is_finite(game.P.x) and is_finite(game.P.y) and is_finite(game.P.hp), "step %d player finite" % i)
		_ok(game.P.hp <= game.P.maxhp, "step %d hp<=maxhp" % i)
		if game.state == "play":
			_ok(game.P.x >= -32 and game.P.x <= game.level.px_w + 32, "step %d x in bounds" % i)
			_ok(game.P.y <= game.level.px_h, "step %d above bedrock" % i)
	return { "cleared": cleared, "deaths": deaths, "final_lvl": game.lvl, "score": game.score }
