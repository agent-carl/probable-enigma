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
	game.rng.seed = 424242  # детерминированный прогон тестов

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
			var T_LAVA_g := 6
			for x in range(1, W):
				# опасная колонка-яма: шип над землёй ИЛИ лава на поверхности дна
				var spike_here := grid[(gy[x] - 1) * W + x] == T_SPIKE or grid[gy[x] * W + x] == T_LAVA_g
				var spike_prev := grid[(gy[x - 1] - 1) * W + (x - 1)] == T_SPIKE or grid[gy[x - 1] * W + (x - 1)] == T_LAVA_g
				if spike_here and not spike_prev:
					run_start = x
				if not spike_here and spike_prev and run_start > 0:
					var run_len := x - run_start
					_ok(run_len <= 4 or gy[run_start - 1] == gy[x], "s%dl%d pit x=%d len=%d jumpable" % [s, lvl, run_start, run_len])
					_ok(run_len <= 6, "s%dl%d pit len %d <= 6" % [s, lvl, run_len])
					run_start = -1
				if not spike_here and not spike_prev:
					# подъём (земля выше = меньше gy) должен быть запрыгиваемым (≤3);
					# обрывы вниз любой величины — падение всегда проходимо
					_ok(gy[x - 1] - gy[x] <= 3, "s%dl%d up-step at x=%d (%d)" % [s, lvl, x, gy[x - 1] - gy[x]])

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
	# экран итогов проявляется анимацией: сброс в 0 на смерти, затем нарастание к 1
	_ok(game._dead_anim == 0.0, "death summary anim resets to 0 on death")
	for _fk in range(60):
		game._update_fx()   # ~1 с кадров — каскад строк/счётчик доходит до конца
	_ok(game._dead_anim >= 1.0, "death summary anim completes")
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

	# варианты боссов чередуются: ур.5 — наземный, ур.10 — летающий
	var b5 = null
	for en in L5.enemies:
		if en.get("boss", false):
			b5 = en
	var b10 = null
	for en in L10.enemies:
		if en.get("boss", false):
			b10 = en
	_ok(b5 != null and b5.variant == "ground", "level 5 boss is ground variant")
	_ok(b10 != null and b10.variant == "air", "level 10 boss is air variant")
	# летающий босс заспавнен в воздухе (над землёй)
	var gy10: Array = L10.ground_y
	var b10_col := int((b10.x + b10.w / 2.0) / 32)
	b10_col = clampi(b10_col, 0, L10.W - 1)
	_ok(b10.y + b10.h < gy10[b10_col] * 32, "air boss spawns above the ground")
	# третий вариант — кристальный страж (ур.15)
	var L15: Dictionary = game.generate_level(151515, 15)
	var b15 = null
	for en in L15.enemies:
		if en.get("boss", false):
			b15 = en
	_ok(b15 != null and b15.variant == "crystal", "level 15 boss is crystal variant")
	# призыватель теперь на ур.20 — спавнит миньонов
	game.start_run(150, "150")
	game.lvl = 20
	game.start_level()
	var n0: int = game.enemies.size()
	for i in range(260):
		game.input.aim = Vector2(game.P.x + 60, game.P.y)
		game.sim_step()
		if game.state != "play":
			break
	_ok(game.enemies.size() > n0, "summoner adds minions over time (%d -> %d)" % [n0, game.enemies.size()])
	var bs = null
	for en in game.enemies:
		if en.get("boss", false):
			bs = en
	if bs != null:
		_ok(is_finite(bs.x) and is_finite(bs.y), "summoner boss stays finite")

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

	# летающий босс: стабильная симуляция (без падений/NaN, в пределах карты)
	game.start_run(70, "70")
	game.lvl = 10
	game.start_level()
	_ok(game.boss_alive, "air boss level active")
	for i in range(400):
		game.input.move = (1 if (i / 40) % 2 == 0 else -1)
		game.input.jump_pressed = (i % 30 == 0)
		game.input.jump_held = true
		game.input.aim = Vector2(game.P.x + 100, game.P.y)
		game.input.shoot_held = true
		game.input.shoot_clicked = (i % 8 == 0)
		game.sim_step()
		var air = null
		for en in game.enemies:
			if en.get("boss", false):
				air = en
		if air != null:
			_ok(is_finite(air.x) and is_finite(air.y) and is_finite(air.vx) and is_finite(air.vy), "air boss state finite at step %d" % i)
			_ok(air.x >= -64 and air.x <= game.level.px_w + 64, "air boss x in bounds at step %d" % i)
			_ok(air.y >= -64 and air.y <= game.level.px_h + 64, "air boss y in bounds at step %d" % i)
		if game.state != "play":
			break

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
	_ok(game.hitstop >= 2, "kill grants micro-hitstop (got %d)" % game.hitstop)
	game.hitstop = 0   # не тащить заморозку в следующие секции

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
	# лут выпадает не всегда (≈85%); ломаем несколько ящиков, чтобы проверить надёжно
	var loot_drops := 0
	for k in range(20):
		var ci := (1 + k % 4) * WC + (1 + k / 4)
		var g := PackedByteArray()
		g.resize(WC * HC)
		g[ci] = 5
		game.level = { "W": WC, "H": HC, "grid": g, "px_w": WC * 32, "px_h": HC * 32,
			"crate_hp": { ci: 24 }, "theme": { "top": "#58c98f" } }
		game.pickups = []
		game.damage_crate(ci % WC, ci / WC, 99)
		loot_drops += game.pickups.size()
	_ok(loot_drops >= 10, "broken crates drop loot most of the time (got %d/20)" % loot_drops)

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

	# ---------- 18. Новые враги: снайпер и делящийся ----------
	# генерация: делящиеся с ур.2, снайперы с ур.3
	var has_split2 := false
	var has_sniper3 := false
	for s3 in range(1, 41):
		for en in game.generate_level(s3 * 271 + 2, 2).enemies:
			if en.type == "splitter":
				has_split2 = true
		for en in game.generate_level(s3 * 271 + 3, 3).enemies:
			if en.type == "sniper":
				has_sniper3 = true
	_ok(has_split2, "splitters spawn from level 2")
	_ok(has_sniper3, "snipers spawn from level 3")

	# делящийся при смерти распадается на 2 осколка
	game.start_run(81, "81")
	game.enemies.clear()
	var spl: Dictionary = game._spawn_enemy("splitter", 300.0, 200.0)
	game.enemies.append(spl)
	game.hurt_enemy(spl, 9999, false)
	var shards := 0
	for en in game.enemies:
		if en.type == "shard":
			shards += 1
	_ok(shards == 2, "splitter spawns 2 shards on death (got %d)" % shards)

	# снайпер: телеграф лучом, затем выстрел
	var WS := 24
	var HS := 12
	var grids := PackedByteArray()
	grids.resize(WS * HS)
	for ty in range(10, HS):
		for tx in range(WS):
			grids[ty * WS + tx] = 1  # пол
	game.level = { "W": WS, "H": HS, "grid": grids, "px_w": WS * 32, "px_h": HS * 32,
		"crate_hp": {}, "theme": { "top": "#58c98f" } }
	game.P.x = 120.0
	game.P.y = 10 * 32 - 30
	game.P.inv = 999
	game.enemies = [game._spawn_enemy("sniper", 400.0, 10 * 32 - 30)]
	game.bullets = []
	var fired_at := -1
	for i in range(90):
		game.update_enemies()
		if fired_at < 0 and game.bullets.size() > 0:
			fired_at = i
	_ok(fired_at > 10, "sniper telegraphs before firing (fired at frame %d)" % fired_at)
	_ok(fired_at >= 0, "sniper eventually fires")

	# ---------- 19. Движущиеся платформы ----------
	# генерация создаёт платформы
	var total_movers := 0
	for s4 in range(1, 41):
		for lv in range(1, 6):
			total_movers += game.generate_level(s4 * 53 + lv, lv).movers.size()
	_ok(total_movers > 0, "moving platforms are generated (total %d)" % total_movers)

	# горизонтальная платформа переносит стоящего игрока
	game.start_run(91, "91")
	game.level = { "W": 20, "H": 12, "grid": _empty_grid(20, 12), "px_w": 20 * 32, "px_h": 12 * 32,
		"crate_hp": {}, "theme": { "top": "#58c98f" } }
	var mp := { "w": 96.0, "h": 10.0, "cx": 300.0, "cy": 200.0, "ax": 64.0, "ay": 0.0,
		"phase": 0.0, "speed": 0.05, "x": 300.0, "y": 200.0, "dx": 0.0, "dy": 0.0 }
	game.moving_platforms = [mp]
	# ставим игрока на платформу
	game.P.x = 320.0
	game.P.y = mp.y - game.P.h
	game.P.vy = 0.0
	game.P.ride_id = -1
	game.update_moving_platforms()  # платформа сдвигается
	var px_before: float = game.P.x
	var dx_step: float = mp.dx
	game.ride_moving_platforms()
	_ok(game.P.ride_id == 0, "player is riding the platform")
	_ok(abs((game.P.x - px_before) - dx_step) < 0.001, "player is carried by platform dx")
	_ok(game.P.on_ground, "riding grants on_ground")
	_ok(abs((game.P.y + game.P.h) - mp.y) < 0.001, "player snapped to platform top")

	# приземление сверху на платформу (кадр, когда ноги пробивают верх)
	game.P.ride_id = -1
	game.P.x = 320.0
	game.P.y = mp.y - game.P.h + 3   # ноги только что зашли за верх
	game.P.vy = 8.0                   # падал
	game.ride_moving_platforms()
	_ok(game.P.ride_id == 0 and game.P.vy == 0.0, "player lands on platform from above")

	# ---------- 20. Атмосфера (погода по теме) ----------
	# у каждой темы задан тип погоды
	var weathers := {}
	for thm in game.THEMES:
		_ok(thm.has("weather") and thm.has("wcol"), "theme '%s' has weather" % thm.name)
		weathers[thm.weather] = true
	_ok(weathers.size() >= 4, "themes use several distinct weathers (%d)" % weathers.size())

	# инициализация частиц заполняет до предела и держит их на экране
	game.start_run(95, "95")  # уровень 1 -> spores
	game._init_ambient()
	_ok(game.ambient.size() == game._ambient_cap(), "ambient filled to cap")
	for p in game.ambient:
		_ok(p.x >= -16 and p.x <= 960 + 16 and p.y >= -16 and p.y <= 540 + 16, "ambient particle within screen")
	# обновление сохраняет количество и конечность координат, зацикливает за краями
	for _i in range(400):
		game.update_ambient()
	_ok(game.ambient.size() == game._ambient_cap(), "ambient count stable after updates")
	for p in game.ambient:
		_ok(is_finite(p.x) and is_finite(p.y), "ambient stays finite")
		_ok(p.x >= -16 and p.x <= 960 + 16 and p.y >= -16 and p.y <= 540 + 16, "ambient wraps within bounds")

	# ---------- 21. Элитные враги ----------
	var elites := 0
	for s5 in range(1, 41):
		for lv in range(1, 7):
			for en in game.generate_level(s5 * 311 + lv, lv).enemies:
				if en.get("elite", false):
					elites += 1
					_ok(en.mod in ["swift", "armored", "volatile", "regen"], "elite has a valid modifier")
					_ok(not en.get("boss", false) and en.type != "shard", "elite is not boss/shard")
	_ok(elites > 0, "elite enemies are generated (total %d)" % elites)

	# бронежилет снижает входящий урон (×0.6)
	game.start_run(41, "41")
	var armored := { "type": "walker", "x": 100.0, "y": 100.0, "w": 20, "h": 20, "hp": 100, "maxhp": 100, "score": 10, "dead": false, "hurt_t": 0, "eid": 1, "elite": true, "mod": "armored" }
	game.enemies = [armored]
	game.hurt_enemy(armored, 50, false)
	_ok(armored.hp == 100 - int(round(50 * 0.6)), "armored elite takes reduced damage (hp=%d)" % armored.hp)

	# элита роняет дополнительный лут при гибели
	game.start_run(42, "42")
	game.pickups = []
	var rich := { "type": "walker", "x": 200.0, "y": 200.0, "w": 20, "h": 20, "hp": 1, "maxhp": 40, "score": 20, "dead": false, "hurt_t": 0, "eid": 2, "elite": true, "mod": "swift" }
	game.enemies = [rich]
	game.hurt_enemy(rich, 50, false)
	_ok(rich.dead, "elite dies")
	_ok(game.pickups.size() >= 3, "elite drops extra loot (%d pickups)" % game.pickups.size())

	# ---------- 22. Индикатор направления урона ----------
	game.start_run(43, "43")
	game.hurt_dirs = []
	game.P.inv = 0
	game.hurt_player(10, 1, Vector2(game.P.x + 200, game.P.y))
	_ok(game.hurt_dirs.size() == 1, "hurt records a direction indicator")
	_ok(abs(game.hurt_dirs[0].ang) < 0.2, "damage from the right -> angle ~0")
	game.P.inv = 0
	game.hurt_player(10, -1, Vector2(game.P.x - 200, game.P.y))
	_ok(abs(abs(game.hurt_dirs[1].ang) - PI) < 0.2, "damage from the left -> angle ~PI")

	# ---------- 23. Магазин и монеты ----------
	# монеты — отдельная валюта, копятся с подбора
	game.start_run(51, "51")
	_ok(game.coins == 0, "coins reset on run start")
	game.pickups = [{ "kind": "coin", "x": game.P.x, "y": game.P.y, "w": 12, "h": 12, "vy": 0.0, "t": 0.0 }]
	game.update_pickups()
	_ok(game.coins == 1, "coin pickup grants a coin")

	# магазин появляется перед уровнями, кратными 3
	_ok(game.is_shop_level(3) and game.is_shop_level(6) and not game.is_shop_level(4), "shop levels are every 3rd")
	# после улучшения на переходе к ур.3 открывается магазин
	game.start_run(52, "52")
	game.lvl = 2
	game.choose_upgrade({ "id": "dmg" })  # lvl -> 3 -> магазин
	_ok(game.state == "shop", "shop opens before a shop level")
	_ok(game.shop_items.size() >= 4, "shop offers items")

	# покупка: хватает монет — списывает и применяет; не хватает — нет
	game.coins = 100
	var hp_shop: float = game.P.hp
	game.P.hp = max(1.0, game.P.maxhp - 60)
	var c0: int = game.coins
	# найдём аптечку
	var heal_idx := -1
	for i in range(game.shop_items.size()):
		if game.shop_items[i].id == "heal":
			heal_idx = i
	_ok(heal_idx >= 0, "shop has a heal item")
	game.buy_shop_item(heal_idx)
	_ok(game.coins == c0 - game.shop_items[heal_idx].price, "buying deducts coins")
	_ok(game.shop_items[heal_idx].sold, "item marked sold")
	_ok(game.P.hp > game.P.maxhp - 60, "heal applied")
	# повторная покупка проданного — без эффекта
	var c1: int = game.coins
	game.buy_shop_item(heal_idx)
	_ok(game.coins == c1, "cannot rebuy a sold item")
	# нехватка монет — покупка не проходит
	game.coins = 0
	var weapon_idx := -1
	for i in range(game.shop_items.size()):
		if game.shop_items[i].id == "weapon":
			weapon_idx = i
	game.buy_shop_item(weapon_idx)
	_ok(not game.shop_items[weapon_idx].sold, "cannot afford -> no purchase")
	# выход из магазина запускает уровень
	game.shop_continue()
	_ok(game.state == "play" and game.lvl == 3, "shop_continue starts the level")

	# ---------- 24. Статусы, ульта ----------
	game.start_run(61, "61")
	# заморозка замедляет, потом скорость восстанавливается
	game.P.x = 50.0
	game.cam = Vector2.ZERO   # враги в кадре (иначе отсекаются как «спящие»)
	var fr: Dictionary = game._spawn_enemy("walker", 600.0, 200.0)
	var base_spd: float = fr.base_spd
	game.enemies = [fr]
	game.apply_chill(fr, 8)
	game.update_enemies()
	_ok(abs(fr.spd - base_spd * 0.45) < 1e-6, "chill slows enemy speed")
	_ok(int(fr.chill) == 7, "chill ticks down")
	fr.chill = 0
	game.update_enemies()
	_ok(abs(fr.spd - base_spd) < 1e-6, "speed restores after chill ends")

	# горение наносит урон по времени и заряжает ульту/статы
	game.start_run(62, "62")
	game.P.x = 50.0
	game.cam = Vector2.ZERO
	var bn: Dictionary = game._spawn_enemy("tank", 600.0, 200.0)
	bn.hp = 200
	game.enemies = [bn]
	game.apply_burn(bn, 96)
	var hp_b: int = bn.hp
	for _i in range(60):
		game.update_enemies()
	_ok(bn.hp < hp_b, "burning deals damage over time (%d -> %d)" % [hp_b, bn.hp])

	# улучшения incend/cryo задают шансы и применяют статус (шанс=1 для теста)
	game.start_run(63, "63")
	game.apply_upgrade_stats({ "id": "incend" })
	game.apply_upgrade_stats({ "id": "cryo" })
	_ok(game.P.stats.burn_chance > 0 and game.P.stats.chill_chance > 0, "incend/cryo set chances")
	game.P.stats.burn_chance = 1.0
	game.P.stats.chill_chance = 1.0
	var tgt: Dictionary = game._spawn_enemy("walker", 400.0, 200.0)
	game._roll_bullet_status(tgt)
	_ok(int(tgt.burn) > 0 and int(tgt.chill) > 0, "bullet status applies at 100% chance")

	# ультимейт: заряжается уроном, активируется на максимуме
	game.start_run(64, "64")
	game.ult = 0.0
	var due: Dictionary = game._spawn_enemy("walker", 400.0, 200.0)
	due.hp = 1000
	game.enemies = [due]
	game.hurt_enemy(due, 50, false)
	_ok(abs(game.ult - 50.0) < 1e-6, "ult charges from damage")
	# не на максимуме — активация через update_player не срабатывает
	game.ult = 10.0
	game.input.ult = true
	game.P.inv = 999
	game.update_player()
	_ok(abs(game.ult - 10.0) < 1e-6, "ult does not fire below max")
	# на максимуме — срабатывает (урон по площади, чистит вражеские пули, сброс)
	game.ult = game.ULT_MAX
	var ult_e: Dictionary = game._spawn_enemy("walker", game.P.x + 40, game.P.y)
	ult_e.hp = 1000
	game.enemies = [ult_e]
	game.bullets = [{ "x": game.P.x + 10, "y": game.P.y, "vx": 0.0, "vy": 0.0, "dmg": 5, "from": "e", "life": 100, "color": "#f00" }]
	var nh: int = ult_e.hp
	game.input.ult = true
	game.update_player()
	_ok(game.ult == 0.0, "ult resets after use")
	_ok(ult_e.hp < nh, "ult damages nearby enemies")
	_ok(game.bullets.size() == 0, "ult clears nearby enemy bullets")

	# ---------- 25. Доступность: стик геймпада и опция тряски ----------
	# мёртвая зона стика
	_ok(game._stick(0.1, 0.1, 0.3) == Vector2.ZERO, "stick within deadzone -> zero")
	var sv: Vector2 = game._stick(0.6, 0.0, 0.3)
	_ok(sv.length() > 0.3, "stick beyond deadzone -> non-zero")
	# опция тряски управляет смещением экрана
	game.shake = 12.0
	game.shake_on = false
	_ok(game._shake_offset() == Vector2.ZERO, "shake off -> no offset")
	game.shake_on = true
	var off: Vector2 = game._shake_offset()
	_ok(abs(off.x) <= 12.0 and abs(off.y) <= 12.0, "shake offset within amplitude")
	game.shake = 0.0
	_ok(game._shake_offset() == Vector2.ZERO, "no shake -> no offset")
	# переключение и сохранение опции
	game.shake_on = true
	game.toggle_shake()
	_ok(not game.shake_on, "toggle flips shake option")
	game._save_settings()
	game.shake_on = true
	game._load_settings()
	_ok(not game.shake_on, "shake option persists across save/load")
	game.shake_on = true
	game._save_settings()  # вернуть значение по умолчанию

	# ---------- 26. Ловушки-пилы ----------
	# генерация размещает пилы (с уровня 2)
	var total_haz := 0
	for s6 in range(1, 41):
		for lv in range(2, 7):
			total_haz += game.generate_level(s6 * 71 + lv, lv).hazards.size()
	_ok(total_haz > 0, "saw hazards are generated (total %d)" % total_haz)

	# пила колеблется в пределах амплитуды и остаётся конечной
	game.hazards = [{ "type": "saw", "r": 16.0, "cx": 300.0, "cy": 200.0, "ax": 64.0, "ay": 0.0,
		"phase": 0.0, "speed": 0.07, "x": 300.0, "y": 200.0, "spin": 0.0 }]
	for _i in range(400):
		game.update_hazards()
		var hz: Dictionary = game.hazards[0]
		_ok(is_finite(hz.x) and is_finite(hz.y), "saw stays finite")
		_ok(hz.x >= 300.0 - 64.0 - 1 and hz.x <= 300.0 + 64.0 + 1, "saw x within amplitude")

	# контакт с пилой ранит игрока; вдали — нет
	game.start_run(81, "81")
	game.P.inv = 0
	game.hazards = [{ "type": "saw", "r": 16.0, "cx": game.P.x, "cy": game.P.y, "ax": 0.0, "ay": 0.0,
		"phase": 0.0, "speed": 0.0, "x": game.P.x + game.P.w / 2.0, "y": game.P.y + game.P.h / 2.0, "spin": 0.0 }]
	var hpb: float = game.P.hp
	game.check_hazards()
	_ok(game.P.hp < hpb, "saw contact damages player")
	game.P.inv = 0
	game.hazards[0].x = game.P.x + 5000.0
	game.hazards[0].y = game.P.y
	var hpb2: float = game.P.hp
	game.check_hazards()
	_ok(game.P.hp == hpb2, "distant saw does not damage player")

	# ---------- 27. Процедурная музыка ----------
	var m0: AudioStreamWAV = Synth.build_music(0, false)
	_ok(m0 != null and m0.data.size() > 0, "music track has audio data")
	_ok(m0.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music track loops")
	_ok(m0.loop_end == m0.data.size() / 2, "loop end at track end (s16 samples)")
	# детерминизм
	var m0b: AudioStreamWAV = Synth.build_music(0, false)
	_ok(m0.data == m0b.data, "music is deterministic per theme")
	# разные темы и боссовый вариант звучат иначе
	var m1: AudioStreamWAV = Synth.build_music(1, false)
	_ok(m0.data != m1.data, "different themes -> different music")
	var m0i: AudioStreamWAV = Synth.build_music(0, true)
	_ok(m0.data != m0i.data, "boss (intense) variant differs")

	# ---------- 28. Лимит частиц (производительность) ----------
	game.start_run(201, "201")
	game.parts = []
	for _i in range(2000):
		game.burst(100.0, 100.0, 1, Color.WHITE)
	game.update_effects()
	_ok(game.parts.size() <= 600, "particle count capped (%d)" % game.parts.size())

	# ---------- 29. Огнемёт (конусный урон + поджог) ----------
	game.start_run(202, "202")
	game.P.weapons = [{ "id": "flame", "ammo": 240 }]
	game.P.wi = 0
	game.P.cd = 0
	var fcx: float = game.P.x + game.P.w / 2.0
	var fcy: float = game.P.y + game.P.h / 2.0 - 2
	game.input.aim = Vector2(fcx + 200, fcy)  # целимся вправо
	game.input.shoot_held = true
	var front := { "type": "walker", "x": fcx + 70, "y": fcy - 10, "w": 20, "h": 20, "hp": 100, "maxhp": 100, "score": 10, "dead": false, "hurt_t": 0, "burn": 0, "eid": 1 }
	var behind := { "type": "walker", "x": fcx - 90, "y": fcy - 10, "w": 20, "h": 20, "hp": 100, "maxhp": 100, "score": 10, "dead": false, "hurt_t": 0, "burn": 0, "eid": 2 }
	game.enemies = [front, behind]
	game.try_shoot()
	_ok(front.hp < 100, "flamethrower damages enemy in cone")
	_ok(int(front.burn) > 0, "flamethrower ignites enemy in cone")
	_ok(behind.hp == 100, "flamethrower spares enemy outside cone")

	# ---------- 30. Лава/кислота (генерация + свойства тайла + урон) ----------
	var T_LAVA := 6
	var T_SOLID_l := 1
	var lava_levels := 0
	var lava_cell_ok := true
	var sample_level: Dictionary = {}
	for s in range(1, 121):
		var L: Dictionary = game.generate_level(s * 6311 + 3, 3 + (s % 4))
		var lc: Array = L.get("lava_cells", [])
		if lc.size() > 0:
			lava_levels += 1
			if sample_level.is_empty():
				sample_level = L
			# каждый записанный центр лавы реально является тайлом лавы,
			# не твёрдый, и под ним камень (нельзя провалиться насквозь)
			for p in lc:
				var tx := int(p.x / 32)
				var ty := int(p.y / 32)
				var W: int = L.W
				if L.grid[ty * W + tx] != T_LAVA:
					lava_cell_ok = false
				if L.grid[(ty + 1) * W + tx] != T_SOLID_l:
					lava_cell_ok = false
	_ok(lava_levels > 0, "lava pits generate across seeds (%d/120 levels)" % lava_levels)
	_ok(lava_cell_ok, "every lava cell is T_LAVA with solid floor below")
	_ok(not game.is_blocking(T_LAVA), "lava is not a blocking tile (player can fall in)")
	# определение пересечения игрока с лавой
	if not sample_level.is_empty():
		game.level = sample_level
		var lp0: Vector2 = sample_level.lava_cells[0]
		var pl: Dictionary = game.make_player()
		pl.x = lp0.x - pl.w / 2.0
		pl.y = lp0.y - pl.h / 2.0
		_ok(game.overlaps_tile(pl, T_LAVA), "overlaps_tile detects player in lava")
		var pl2: Dictionary = game.make_player()
		pl2.x = lp0.x + 4000.0
		pl2.y = lp0.y
		_ok(not game.overlaps_tile(pl2, T_LAVA), "player far from lava does not overlap")
	# детерминизм лавы
	var La: Dictionary = game.generate_level(987654, 4)
	var Lb: Dictionary = game.generate_level(987654, 4)
	_ok(La.lava_cells.size() == Lb.lava_cells.size(), "lava generation is deterministic")

	# ---------- 31. Динамические тени (геометрия света) ----------
	var ro := Vector2(0, 0)
	_ok(absf(game._ray_seg(ro, Vector2(1, 0), Vector2(10, -5), Vector2(10, 5)) - 10.0) < 0.001, "ray hits perpendicular segment at correct distance")
	_ok(game._ray_seg(ro, Vector2(1, 0), Vector2(-10, -5), Vector2(-10, 5)) < 0.0, "ray misses segment behind origin")
	_ok(game._ray_seg(ro, Vector2(0, 1), Vector2(10, -5), Vector2(10, 5)) < 0.0, "ray away from segment misses")
	# мини-уровень: сплошная стена в столбце справа от света
	var Wt := 20
	var Ht := 10
	var g2 := PackedByteArray()
	g2.resize(Wt * Ht)
	for yy in range(Ht):
		g2[yy * Wt + 5] = 1   # T_SOLID
	game.level = { "W": Wt, "H": Ht, "grid": g2 }
	var Lp := Vector2(2 * 32 + 16, 5 * 32 + 16)   # свет слева от стены
	var segs2: Array = game._occluder_segments(Lp, 220.0)
	_ok(segs2.size() > 0, "occluder segments found near wall (%d)" % segs2.size())
	var vpoly: PackedVector2Array = game._visibility_polygon(Lp, 400.0, segs2)
	_ok(vpoly.size() >= 3, "visibility polygon built (%d pts)" % vpoly.size())
	var wall_x := 5 * 32.0
	var maxx := -1.0e9
	for p in vpoly:
		if absf(p.y - Lp.y) < 8.0:
			maxx = maxf(maxx, p.x)
	_ok(maxx <= wall_x + 1.0, "light blocked by wall on +x (reach=%.1f wall=%.1f)" % [maxx, wall_x])
	# без преград свет достаёт до радиуса
	var vopen: PackedVector2Array = game._visibility_polygon(Vector2(0, 0), 100.0, [])
	var far_reach := 0.0
	for p in vopen:
		far_reach = maxf(far_reach, p.length())
	_ok(absf(far_reach - 100.0) < 0.5, "open light reaches full radius")
	game.level = {}   # сброс, чтобы пост-тестовая отрисовка не падала

	# ---------- 32. Новые враги: таран и лекарь ----------
	var has_charger := false
	var has_healer := false
	for s in range(1, 70):
		var Lc: Dictionary = game.generate_level(s * 101 + 6, 6)   # ур.6 — не боссовый
		for en in Lc.enemies:
			if en.type == "charger":
				has_charger = true
			elif en.type == "healer":
				has_healer = true
	_ok(has_charger, "charger spawns in generated levels")
	_ok(has_healer, "healer spawns in generated levels")
	# лекарь восстанавливает HP ближнему раненому врагу
	game.start_run(8801, "heal")
	var heal_e: Dictionary = game._spawn_enemy("healer", game.P.x + 320.0, game.P.y)
	var hurt_e: Dictionary = game._spawn_enemy("walker", game.P.x + 336.0, game.P.y)
	hurt_e.hp = 8
	var hhp0: int = hurt_e.hp
	game.enemies = [heal_e, hurt_e]
	game.update_enemies()
	_ok(hurt_e.hp > hhp0, "healer heals a nearby damaged enemy (%d -> %d)" % [hhp0, hurt_e.hp])
	# таран разгоняется и устремляется к игроку
	game.start_run(8802, "charge")
	var chg: Dictionary = game._spawn_enemy("charger", game.P.x + 130.0, game.P.y)
	game.enemies = [chg]
	var chx0: float = chg.x
	for _i in range(64):
		game.update_enemies()
	_ok(absf(chg.x - chx0) > 40.0, "charger winds up and rushes (dx=%.0f)" % (chg.x - chx0))

	# ---------- 33. Реликвии ----------
	game.start_run(9001, "relic")
	_ok(not game.has_relic("glass"), "no relics at run start")
	var rlc_dm0: float = game.P.stats.dmg_mul
	var rlc_mh0: int = game.P.maxhp
	game.grant_relic("glass")
	_ok(game.has_relic("glass"), "grant_relic adds the relic")
	_ok(absf(game.P.stats.dmg_mul - rlc_dm0 * 1.6) < 1e-4, "glass cannon boosts damage +60%")
	_ok(game.P.maxhp < rlc_mh0, "glass cannon reduces max HP")
	_ok(not game.grant_relic("glass"), "duplicate relic rejected")
	# вампиризм-реликвия лечит при убийстве
	game.start_run(9002, "vmp")
	game.grant_relic("vampire")
	game.P.hp = 40.0
	var rlc_ve: Dictionary = game._spawn_enemy("walker", game.P.x + 60.0, game.P.y)
	rlc_ve.hp = 1
	game.enemies = [rlc_ve]
	var rlc_vhp0: float = game.P.hp
	game.hurt_enemy(rlc_ve, 50, false)
	_ok(rlc_ve.dead and game.P.hp > rlc_vhp0, "vampire relic heals on kill (%.0f -> %.0f)" % [rlc_vhp0, game.P.hp])
	# Мидас даёт лишнюю монету
	game.start_run(9003, "mid")
	game.grant_relic("midas")
	var rlc_me: Dictionary = game._spawn_enemy("walker", game.P.x + 60.0, game.P.y)
	rlc_me.hp = 1
	game.enemies = [rlc_me]
	var rlc_c0: int = game.coins
	game.hurt_enemy(rlc_me, 50, false)
	_ok(game.coins >= rlc_c0 + 1, "midas grants an extra coin on kill")
	# детонатор бьёт соседнего врага
	game.start_run(9004, "det")
	game.grant_relic("detonate")
	var rlc_da: Dictionary = game._spawn_enemy("walker", 400.0, 300.0)
	rlc_da.hp = 1
	var rlc_db: Dictionary = game._spawn_enemy("walker", 422.0, 300.0)
	rlc_db.hp = 300
	game.enemies = [rlc_da, rlc_db]
	var rlc_db0: int = rlc_db.hp
	game.hurt_enemy(rlc_da, 50, false)
	_ok(rlc_db.hp < rlc_db0, "detonate explosion damages a nearby enemy")
	# «Второе дыхание» переживает смертельный удар
	game.start_run(9005, "sw")
	game.grant_relic("second")
	game.P.hp = 5.0
	game.P.inv = 0
	game.hurt_player(999, 0)
	_ok(game.state == "play" and int(game.P.hp) == 1, "second wind survives a lethal hit at 1 HP")
	game.P.inv = 0
	game.hurt_player(999, 0)
	_ok(game.state == "dead", "second wind consumed -> next lethal hit kills")
	game.level = {}

	# ---------- 34. Контент-дроп: рикошет, пружина, босс-артиллерист ----------
	# рикошет отражается от стены и не исчезает
	game.start_run(7100, "ric")
	var rgrid := PackedByteArray()
	rgrid.resize(20 * 10)
	for yy in range(10):
		rgrid[yy * 20 + 8] = 1   # стена в колонке 8
	game.level = { "W": 20, "H": 10, "grid": rgrid, "px_w": 20 * 32, "px_h": 10 * 32 }
	game.enemies = []
	game.P.x = -9999.0
	game.P.y = -9999.0
	game.bullets = [{ "x": 250.0, "y": 165.0, "vx": 8.0, "vy": 0.0, "dmg": 10, "crit": false, "from": "p", "life": 150, "color": Color.WHITE, "bounce": 3 }]
	game.update_bullets()
	var rb: Dictionary = game.bullets[0] if game.bullets.size() > 0 else {}
	_ok(not rb.is_empty() and rb.vx < 0.0, "ricochet bullet bounces off a wall (vx reversed)")
	_ok(not rb.is_empty() and int(rb.get("bounce", 9)) == 2, "ricochet decrements bounce count")
	# пружины генерируются и стоят на камне; тайл твёрдый
	var spring_found := false
	var spring_solid := true
	for s in range(1, 60):
		var Ls: Dictionary = game.generate_level(s * 131 + 4, 4)
		var Wl: int = Ls.W
		for idx in range(Ls.grid.size()):
			if Ls.grid[idx] == 7:   # T_SPRING
				spring_found = true
				if Ls.grid[idx + Wl] != 1:
					spring_solid = false
	_ok(spring_found, "spring tiles generate in levels")
	_ok(spring_solid, "springs sit on solid ground")
	_ok(game.is_blocking(7), "spring is a solid tile")
	# артиллерист теперь на ур.25 и ведёт огонь
	var L20: Dictionary = game.generate_level(25 * 7 + 1, 25)
	var bossv := ""
	var boss20 = null
	for en in L20.enemies:
		if en.get("boss", false):
			bossv = en.variant
			boss20 = en
	_ok(bossv == "artillery", "artillery boss appears on level 25 (got '%s')" % bossv)
	if boss20 != null:
		game.level = L20
		game.P = game.make_player()
		game.P.x = boss20.x
		game.P.y = boss20.y + 200.0
		boss20.cd = 0
		game.enemies = [boss20]
		game.bullets = []
		game.update_enemies()
		_ok(game.bullets.size() > 0, "artillery boss fires a volley")
	game.level = {}

	# ---------- 52. Кристальный босс (ур.15): телепорт + спираль ----------
	var L15c: Dictionary = game.generate_level(15 * 7 + 3, 15)
	var bc = null
	for en in L15c.enemies:
		if en.get("boss", false):
			bc = en
	_ok(bc != null and bc.variant == "crystal", "level 15 boss is crystal")
	if bc != null:
		game.level = L15c
		game.P = game.make_player()
		game.P.x = bc.x + 30.0
		game.P.y = bc.y + 160.0
		game.cam = Vector2.ZERO
		bc.cd = 0
		game.enemies = [bc]
		game.bullets = []
		var bx0: float = bc.x
		var by0: float = bc.y
		var fired := false
		var blinked := false
		for i in range(260):
			game.update_enemies()
			if game.bullets.size() > 0:
				fired = true
			if absf(bc.x - bx0) > 100.0 or absf(bc.y - by0) > 100.0:
				blinked = true
		_ok(fired, "crystal boss fires crystal shards")
		_ok(blinked, "crystal boss teleports")
	game.enemies = []
	game.bullets = []
	game.level = {}

	# ---------- 35. Мета-прогрессия ----------
	game.meta = {}
	game.meta_cores = 0
	_ok(game.meta_level("vitality") == 0, "meta level starts at 0")
	_ok(game.meta_cost("vitality") == 4, "meta cost from catalog")
	_ok(not game.buy_meta("vitality"), "cannot buy meta without cores")
	game.meta_cores = 100
	_ok(game.buy_meta("vitality"), "buy meta with enough cores")
	_ok(game.meta_level("vitality") == 1, "meta level increments after buy")
	_ok(game.meta_cores == 96, "cores deducted on buy (100-4)")
	# apply_meta влияет на старт забега
	game.meta = { "vitality": 2, "power": 1, "fortune": 2 }
	game.start_run(7700, "meta")
	_ok(game.P.maxhp >= 140, "vitality raises starting max HP (%d)" % game.P.maxhp)
	_ok(game.coins == 10, "fortune grants starting coins")
	_ok(game.P.stats.dmg_mul > 1.0, "power raises starting damage")
	# заработок ядер при смерти
	game.meta = {}
	game.meta_cores = 0
	game.start_run(7701, "die")
	game.score = 1000
	game.lvl = 3
	game.P.hp = 1.0
	game.P.inv = 0
	game.hurt_player(999, 0)
	_ok(game.state == "dead", "player dies")
	_ok(game.run_cores >= 1 and game.meta_cores == game.run_cores, "cores earned on death (%d)" % game.run_cores)
	game.level = {}

	# ---------- 36. Настройки: раздельная громкость музыки/звуков ----------
	game.music_vol = 0.5
	game.sfx_vol = 0.5
	game.adjust_music(0.2)
	_ok(absf(game.music_vol - 0.7) < 1e-4, "music volume adjusts up")
	game.adjust_music(1.0)
	_ok(game.music_vol == 1.0, "music volume clamps at 1.0")
	game.adjust_sfx(-0.9)
	_ok(absf(game.sfx_vol) < 1e-4, "sfx volume clamps at 0.0")

	# ---------- 37. Сложность (Ascension) ----------
	game.difficulty = 0
	var asc_L0: Dictionary = game.generate_level(555, 3)
	var asc_hp0 := 0
	for en in asc_L0.enemies:
		asc_hp0 += int(en.maxhp)
	game.difficulty = 2
	var asc_L2: Dictionary = game.generate_level(555, 3)
	var asc_hp2 := 0
	for en in asc_L2.enemies:
		asc_hp2 += int(en.maxhp)
	_ok(asc_hp2 > asc_hp0, "higher difficulty = tougher enemies (%d -> %d total HP)" % [asc_hp0, asc_hp2])
	_ok(game._diff_name(0) == "Норма" and game._diff_name(3) == "Преисподняя", "difficulty names map")
	game.difficulty = 0

	# ---------- 38. Активные предметы ----------
	game.start_run(8800, "act")
	_ok(game.P.active == "bomb", "starts with an active item")
	game.give_active("medkit")
	_ok(game.P.active == "medkit", "give_active swaps the active item")
	game.P.hp = 50.0
	game.P.active_cd = 0
	game.use_active()
	_ok(game.P.hp > 50.0, "medkit active heals the player")
	_ok(game.P.active_cd > 0, "active goes on cooldown after use")
	var act_hp: float = game.P.hp
	game.use_active()   # на кулдауне — не срабатывает
	_ok(absf(game.P.hp - act_hp) < 1e-6, "active does nothing while on cooldown")
	game.level = {}

	# ---------- 39. Классы персонажей ----------
	game.meta = {}
	game.difficulty = 0
	game.classes_unlocked = { "soldier": true }
	game.class_sel = 0
	game.meta_cores = 0
	game._pick_class(1)   # берсерк заблокирован, ядер нет
	_ok(game.class_sel == 0 and not game.classes_unlocked.has("berserk"), "locked class not selected without cores")
	game.meta_cores = 50
	game._pick_class(1)
	_ok(game.classes_unlocked.has("berserk") and game.class_sel == 1, "class unlocked and selected with cores")
	_ok(game.meta_cores == 38, "cores spent on class unlock (50-12)")
	game.start_run(9100, "cls")
	_ok(game.P.weapons[0].id == "shotgun", "berserk class starts with shotgun")
	_ok(game.P.stats.dmg_mul > 1.0, "berserk class boosts damage")
	game.classes_unlocked["tank"] = true
	game.class_sel = 4
	game.start_run(9101, "tank")
	_ok(game.P.maxhp > 100, "tank class has more max HP (%d)" % game.P.maxhp)
	game.class_sel = 0
	game.level = {}

	# ---------- 40. Оптимизация: отсечение далёких врагов ----------
	game.start_run(9200, "cull")
	game.cam = Vector2.ZERO
	var cull_far: Dictionary = game._spawn_enemy("walker", 5000.0, 200.0)
	cull_far.vx = 3.0
	var cull_fx0: float = cull_far.x
	game.enemies = [cull_far]
	game.update_enemies()
	_ok(absf(cull_far.x - cull_fx0) < 0.001, "off-screen enemy is skipped (asleep)")
	var cull_near: Dictionary = game._spawn_enemy("walker", 300.0, 100.0)
	cull_near.vy = 0.0
	game.enemies = [cull_near]
	game.update_enemies()
	_ok(cull_near.vy != 0.0, "on-screen enemy still updates (gravity applied)")
	game.level = {}

	# ---------- 41. Сохранение забега (Continue) ----------
	game.start_run(4242, "save")
	game.lvl = 3
	game.score = 777
	game.coins = 9
	game.P.hp = 42.0
	game.grant_relic("vampire")
	game._save_run()
	_ok(game.has_run_save(), "run autosave exists")
	game.lvl = 1
	game.score = 0
	game.P.hp = 100.0
	game.relics = {}
	game.continue_run()
	_ok(game.lvl == 3, "continue restores level")
	_ok(game.score == 777, "continue restores score")
	_ok(int(game.P.hp) == 42, "continue restores HP")
	_ok(game.has_relic("vampire"), "continue restores relics")
	_ok(game.state == "play", "continue enters play")
	game._clear_run_save()
	_ok(not game.has_run_save(), "clear removes the save")
	game.level = {}

	# ---------- 42. Объёмный свет: ресурсы и переключатель ----------
	game._build_ground_normal()
	_ok(game.ground_norm != null, "ground normal map built")
	_ok(game.ground_ctex != null and game.ground_ctex.normal_texture != null, "ground CanvasTexture has normal")
	var el0: bool = game.engine_light
	game.toggle_englight()
	_ok(game.engine_light != el0, "toggle_englight flips flag")
	game.toggle_englight()
	_ok(game.engine_light == el0, "toggle_englight restores flag")

	# ---------- 43. Локализация (RU/EN) ----------
	game.lang = "ru"
	_ok(game.T("Играть") == "Играть", "RU: T() returns source unchanged")
	game.lang = "en"
	_ok(game.T("Играть") == "Play", "EN: known key translated")
	_ok(game.T("Дробовик") == "Shotgun", "EN: weapon name translated")
	_ok(game.T("no_such_key_xyz") == "no_such_key_xyz", "EN: unknown key falls back to source")
	_ok((game.T("Уровень %d — %s") % [3, game.T("Норма")]) == "Level 3 — Normal", "EN: format template + value")
	var lg0: String = game.lang
	game.toggle_lang()
	_ok(game.lang != lg0, "toggle_lang switches language")
	game.toggle_lang()
	_ok(game.lang == lg0, "toggle_lang switches back")
	game.lang = "ru"
	game._save_settings()   # не оставляем EN в конфиге после тестов

	# ---------- 44. Биомы (Аметистовая бездна, Обсидиановая кузница) ----------
	_ok(game.THEMES.size() == 7, "seven biomes present")
	_ok(game.THEMES[5].name == "Аметистовая бездна", "6th biome is Amethyst Abyss")
	_ok(game.THEMES[5].weather == "rain", "6th biome uses rain weather")
	_ok(game.THEMES[6].name == "Обсидиановая кузница", "7th biome is Obsidian Forge")
	_ok(game.THEMES[6].weather == "ash", "7th biome uses ash weather")
	var SynthScript = load("res://Synth.gd")
	var m5 = SynthScript.build_music(6, false)
	_ok(m5 != null and m5.data.size() > 0, "music builds for 7th biome index")

	# ---------- 45. Враг-сфера (orbiter) ----------
	var oWS := 24
	var oHS := 12
	var ogrid := PackedByteArray()
	ogrid.resize(oWS * oHS)
	for ty in range(10, oHS):
		for tx in range(oWS):
			ogrid[ty * oWS + tx] = 1
	game.level = { "W": oWS, "H": oHS, "grid": ogrid, "px_w": oWS * 32, "px_h": oHS * 32,
		"crate_hp": {}, "theme": { "top": "#58c98f" } }
	game.cam = Vector2.ZERO
	game.P.x = 120.0
	game.P.y = 10 * 32 - 30
	game.P.inv = 999
	var orb: Dictionary = game._spawn_enemy("orbiter", 400.0, 9 * 32 - 30)
	game.enemies = [orb]
	game.bullets = []
	var ox0: float = orb.x
	var oy0: float = orb.y
	var orb_fired := false
	for i in range(160):
		game.update_enemies()
		if game.bullets.size() > 0:
			orb_fired = true
	_ok(orb_fired, "orbiter fires aimed bolts")
	_ok(orb.x != ox0 or orb.y != oy0, "orbiter orbits (moves)")
	var orb_count := 0
	for lv in range(5, 11):
		for en in game.generate_level(lv * 101 + 7, lv).enemies:
			if en.type == "orbiter":
				orb_count += 1
	_ok(orb_count > 0, "orbiter spawns at higher levels (%d)" % orb_count)
	game.enemies = []
	game.bullets = []
	game.level = {}

	# ---------- 46. Сундуки с сокровищами ----------
	var chest_total := 0
	for lv in range(1, 6):
		for s in range(1, 9):
			chest_total += game.generate_level(s * 71 + lv, lv).chests.size()
	_ok(chest_total > 0, "chests are generated (%d across 40 levels)" % chest_total)
	# открытие сундука выдаёт лут
	var cWS := 24
	var cHS := 12
	var cgrid := PackedByteArray()
	cgrid.resize(cWS * cHS)
	for ty in range(10, cHS):
		for tx in range(cWS):
			cgrid[ty * cWS + tx] = 1
	var chest := { "x": 120.0, "y": 9 * 32 - 18.0, "w": 26.0, "h": 18.0, "opened": false }
	game.level = { "W": cWS, "H": cHS, "grid": cgrid, "px_w": cWS * 32, "px_h": cHS * 32,
		"crate_hp": {}, "theme": { "top": "#58c98f" }, "chests": [chest] }
	game.P.x = 118.0
	game.P.y = 9 * 32 - 30
	game.pickups = []
	game.update_chests()
	_ok(chest.opened, "chest opens on player contact")
	_ok(game.pickups.size() > 0, "opened chest spawns loot (%d items)" % game.pickups.size())
	var coins_before: int = game.pickups.size()
	game.update_chests()   # повторно — уже открыт, новых предметов нет
	_ok(game.pickups.size() == coins_before, "opened chest does not re-trigger")
	game.pickups = []
	game.level = {}

	# ---------- 47. Разблокировки контента ----------
	game.unlocks = {}
	game.prog = { "kills": 0, "bosses": 0, "chests": 0, "deep": 0, "runs": 0, "deaths": 0 }
	_ok(game.is_unlocked("pistol"), "default weapon unlocked")
	_ok(not game.is_unlocked("railgun"), "railgun locked initially")
	_ok(not game.unlocked_weapon_drops().has("railgun"), "locked weapon excluded from drop pool")
	_ok(game.unlocked_weapon_drops().has("smg"), "default weapon in drop pool")
	game.prog.bosses = 1
	game.check_unlocks()
	_ok(game.is_unlocked("railgun"), "railgun unlocks after a boss")
	_ok(game.unlocked_weapon_drops().has("railgun"), "unlocked weapon enters drop pool")
	_ok(not game.is_unlocked("chain"), "chain relic still locked (needs 3 bosses)")
	game.prog.kills = 250
	game.check_unlocks()
	_ok(game.is_unlocked("detonate"), "detonate relic unlocks at 250 kills")
	game.relics = {}
	var offered_locked := false
	for _i in range(200):
		if game.random_unowned_relic() == "bulwark":   # заперта (deep 10)
			offered_locked = true
	_ok(not offered_locked, "locked relic never offered")
	# персистентность
	game.unlocks = { "railgun": true }
	game.prog.kills = 321
	game._save_settings()
	game.unlocks = {}
	game.prog.kills = 0
	game._load_settings()
	_ok(game.unlocks.has("railgun"), "unlocks persist across save/load")
	_ok(int(game.prog.kills) >= 321, "lifetime stats persist across save/load")
	game.relics = {}

	# ---------- 48. Алтари-события ----------
	var shr_total := 0
	for lv in [1, 2, 3, 4, 6, 7, 8, 9]:   # небоссовые уровни
		for s in range(1, 13):
			shr_total += game.generate_level(s * 37 + lv, lv).shrines.size()
	_ok(shr_total > 0, "shrines are generated on non-boss levels (%d)" % shr_total)
	# боссовые уровни — без алтарей
	var shr_boss := 0
	for s in range(1, 13):
		shr_boss += game.generate_level(s * 91, 5).shrines.size()
	_ok(shr_boss == 0, "no shrines on boss levels")
	# взаимодействие: подход открывает оверлей, решение помечает алтарь
	var sWS := 24
	var sHS := 12
	var sgrid := PackedByteArray()
	sgrid.resize(sWS * sHS)
	for ty in range(10, sHS):
		for tx in range(sWS):
			sgrid[ty * sWS + tx] = 1
	var shrine := { "x": 118.0, "y": 9 * 32 - 30.0, "w": 36.0, "h": 30.0, "type": "spring", "used": false }
	game.level = { "W": sWS, "H": sHS, "grid": sgrid, "px_w": sWS * 32, "px_h": sHS * 32,
		"crate_hp": {}, "theme": { "top": "#58c98f" }, "shrines": [shrine] }
	game.P.x = 118.0
	game.P.y = 9 * 32 - 30
	game.state = "play"
	game.update_shrines()
	_ok(game.state == "shrine", "approaching a shrine opens the choice overlay")
	_ok(not game.pending_shrine.is_empty(), "pending shrine set")
	# приём «целебного источника»: лечит и снижает макс. HP
	game.P.maxhp = 100.0
	game.P.hp = 40.0
	game.resolve_shrine(true)
	_ok(game.state == "play", "resolving shrine resumes play")
	_ok(shrine.used, "shrine marked used after decision")
	_ok(game.P.maxhp == 90 and game.P.hp == 90, "spring heals to (reduced) max")
	game.update_shrines()
	_ok(game.state == "play", "used shrine does not re-trigger")
	# кровавый алтарь: −25% макс. HP + реликвия
	game.relics = {}
	game.unlocks = { "detonate": true }   # есть что выдать
	game.prog = { "kills": 0, "bosses": 0, "chests": 0, "deep": 0, "runs": 0, "deaths": 0 }
	var blood := { "x": 0.0, "y": 0.0, "w": 36.0, "h": 30.0, "type": "blood", "used": false }
	game.pending_shrine = blood
	game.P.maxhp = 100.0
	game.P.hp = 100.0
	game.resolve_shrine(true)
	_ok(game.P.maxhp == 75, "blood altar reduces max HP by 25%")
	_ok(game.relics.size() >= 1, "blood altar grants a relic")
	game.level = {}

	# ---------- 49. Регресс: переключатели настроек реагируют ----------
	var el_before: bool = game.engine_light
	game._on_ui("toggle_englight")
	_ok(game.engine_light != el_before, "settings button toggles engine light")
	game._on_ui("toggle_englight")
	var lang_before: String = game.lang
	game._on_ui("toggle_lang")
	_ok(game.lang != lang_before, "settings button toggles language")
	game.lang = "ru"
	game._save_settings()

	# ---------- 50. Башни-награды и широкие пропасти ----------
	var elevated := 0
	for s in range(1, 40):
		for lv in [3, 4, 6, 7, 8]:
			var L3 = game.generate_level(s * 13 + lv, lv)
			for c in L3.chests:
				var ccx := int(c.x / 32)
				if ccx >= 0 and ccx < L3.W and (L3.ground_y[ccx] * 32 - c.y) > 60:
					elevated += 1   # сундук заметно выше уровня земли = на башне-платформе
	_ok(elevated > 0, "reward towers place elevated chests (%d)" % elevated)

	# ---------- 51. Новые реликвии ----------
	game.state = "play"
	game.P = game.make_player()
	game.P.maxhp = 100.0
	game.P.hp = 100.0
	game.bullets = []
	game._detonating = false
	# hunter: +урон по «свежим» врагам
	game.relics = { "hunter": true }
	var eh: Dictionary = game._spawn_enemy("walker", 0, 0)
	eh.hp = 100; eh.maxhp = 100
	game.hurt_enemy(eh, 10, false, true)
	_ok(eh.hp <= 87, "hunter boosts damage on full-HP enemy (hp=%d)" % int(eh.hp))
	# bloodlust: +урон при низком HP
	game.relics = { "bloodlust": true }
	game.P.hp = 10.0
	var eb: Dictionary = game._spawn_enemy("walker", 0, 0)
	eb.hp = 100; eb.maxhp = 100
	game.hurt_enemy(eb, 10, false, true)
	_ok(eb.hp <= 86, "bloodlust boosts damage at low HP (hp=%d)" % int(eb.hp))
	game.P.hp = 100.0
	# siphon: урон даёт щит
	game.relics = { "siphon": true }
	game.P.shield = 0.0; game.P.max_shield = 0.0
	var es: Dictionary = game._spawn_enemy("walker", 0, 0)
	es.hp = 100; es.maxhp = 100
	game.hurt_enemy(es, 30, false, false)
	_ok(game.P.shield > 0.0, "siphon grants shield on hit (%.1f)" % game.P.shield)
	# vengeance: следующий удар ×2 и расходуется
	game.relics = { "vengeance": true }
	game.P.vengeance = true
	var ev: Dictionary = game._spawn_enemy("walker", 0, 0)
	ev.hp = 100; ev.maxhp = 100
	game.hurt_enemy(ev, 10, false, false)
	_ok(ev.hp <= 80, "vengeance doubles next hit (hp=%d)" % int(ev.hp))
	_ok(not game.P.vengeance, "vengeance consumed after hit")
	# splinter: убийство выпускает осколки
	game.relics = { "splinter": true }
	game.bullets = []
	var ek: Dictionary = game._spawn_enemy("walker", 100, 100)
	ek.hp = 1; ek.maxhp = 100
	game.hurt_enemy(ek, 50, false, true)
	_ok(game.bullets.size() >= 5, "splinter spawns shrapnel (%d)" % game.bullets.size())
	# momentum: убийство даёт разгон
	game.relics = { "momentum": true }
	var em: Dictionary = game._spawn_enemy("walker", 0, 0)
	em.hp = 1; em.maxhp = 100
	game.hurt_enemy(em, 50, false, true)
	_ok(game.P.momentum_t > 0.0, "momentum set on kill")
	game.relics = {}
	game.bullets = []

	# ---------- 53. Редкость предметов ----------
	_ok(game._rar("hp") == 1, "common upgrade tier")
	_ok(game._rar("djump") == 3, "legendary upgrade tier")
	_ok(game._rar("vampire") == 1 and game._rar("chain") == 3, "relic tiers")
	game.lvl = 1
	game.P = game.make_player()
	game.offer_upgrades()
	_ok(game.offer.size() == 3, "offer has 3 cards")
	_ok(game.offer[0].id != game.offer[1].id and game.offer[1].id != game.offer[2].id, "offer cards distinct")
	# взвешивание: обычные выпадают чаще легендарных
	var commons := 0
	var legends := 0
	var two := [{ "id": "hp" }, { "id": "djump" }]   # обычная vs легендарная
	for i in range(400):
		if game._weighted_pick(two).id == "hp":
			commons += 1
		else:
			legends += 1
	_ok(commons > legends * 2, "common picked far more than legendary (%d vs %d)" % [commons, legends])
	game.state = "menu"

	# ---------- 54. Синергии-наборы реликвий ----------
	game.relics = {}
	_ok(game._synergy_off() == 1.0, "no offense synergy with 0 relics")
	game.relics = { "hunter": true, "chain": true, "splinter": true }   # 3 атакующие
	_ok(game._synergy_tier("off") == 1, "3 offense relics -> tier 1")
	_ok(game._synergy_off() > 1.0, "offense synergy boosts damage")
	game.relics = { "vampire": true, "thorns": true, "regen": true, "siphon": true, "bulwark": true }  # 5 защитных
	_ok(game._synergy_tier("def") == 2, "5 defense relics -> tier 2")
	_ok(game._synergy_def() < 0.8, "defense synergy reduces incoming damage")
	game.relics = { "midas": true, "frost": true, "overcharge": true }   # 3 поддержки
	_ok(game._synergy_util_coins() >= 1, "utility synergy grants bonus coins")
	# защита реально снижает урон игроку
	game.state = "play"
	game.P = game.make_player()
	game.P.maxhp = 100.0
	game.P.hp = 100.0
	game.P.inv = 0
	game.P.shield = 0.0
	game.level = { "W": 4, "H": 4, "grid": PackedByteArray([0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]), "px_w": 128, "px_h": 128 }
	game.relics = {}
	game.hurt_player(20, 0)
	var dmg_plain: float = 100.0 - game.P.hp
	game.P.hp = 100.0
	game.P.inv = 0
	game.relics = { "vampire": true, "thorns": true, "regen": true, "siphon": true, "bulwark": true }
	game.hurt_player(20, 0)
	var dmg_def: float = 100.0 - game.P.hp
	_ok(dmg_def < dmg_plain, "defense synergy: less damage taken (%d < %d)" % [int(dmg_def), int(dmg_plain)])
	game.relics = {}
	game.level = {}
	game.state = "menu"

	# ---------- 55. Новое оружие: миниган и магнум ----------
	_ok(game.WEAPONS.has("minigun") and game.WEAPONS.has("magnum"), "new weapons defined")
	game.unlocks = {}
	_ok(not game.is_unlocked("minigun"), "minigun locked initially")
	game.prog = { "kills": 500, "bosses": 0, "chests": 0, "deep": 0, "runs": 0, "deaths": 0 }
	game.check_unlocks()
	_ok(game.is_unlocked("minigun"), "minigun unlocks at 500 kills")
	game.state = "play"
	game.P = game.make_player()
	game.P.weapons = [{ "id": "magnum", "ammo": 14 }]
	game.P.wi = 0
	game.P.cd = 0
	game.P.x = 100.0
	game.P.y = 100.0
	game.bullets = []
	game.input.shoot_clicked = true
	game.input.shoot_held = true
	game.input.aim = Vector2(300, 100)
	game.try_shoot()
	_ok(game.bullets.size() > 0, "magnum fires a bullet")
	_ok(int(game.P.weapons[0].ammo) == 13, "magnum consumes ammo")
	game.bullets = []
	game.unlocks = {}
	game.state = "menu"

	# ---------- 56. Активный предмет: турель ----------
	_ok(game.ACTIVES.has("turret"), "turret active defined")
	var tWS := 24
	var tHS := 12
	var tgrid := PackedByteArray()
	tgrid.resize(tWS * tHS)
	for ty in range(10, tHS):
		for tx in range(tWS):
			tgrid[ty * tWS + tx] = 1
	game.level = { "W": tWS, "H": tHS, "grid": tgrid, "px_w": tWS * 32, "px_h": tHS * 32, "crate_hp": {} }
	game.state = "play"
	game.P = game.make_player()
	game.P.x = 100.0
	game.P.y = 9 * 32 - 30
	game.give_active("turret")
	game.P.active_cd = 0
	game.turrets = []
	game.use_active()
	_ok(game.turrets.size() == 1, "turret deployed on use")
	game.enemies = [game._spawn_enemy("walker", 240.0, 9 * 32 - 30)]
	game.bullets = []
	for i in range(40):
		game.update_turrets()
	_ok(game.bullets.size() > 0, "turret fires at a nearby enemy")
	# истечение срока: турель исчезает
	for t in game.turrets:
		t.life = 1.0
	game.update_turrets()
	_ok(game.turrets.size() == 0, "turret expires after its lifetime")
	game.enemies = []
	game.bullets = []
	game.turrets = []
	game.level = {}
	game.state = "menu"

	# ---------- 57. Визуал: декор и небесное тело генерируются ----------
	var dec_total := 0
	for lv in range(1, 8):
		dec_total += game.generate_level(lv * 31 + 5, lv).decor.size()
	_ok(dec_total > 0, "biome decor generated (%d across 7 levels)" % dec_total)
	game.level = game.generate_level(777, 1)
	game._build_background(777)
	_ok(not game.moon.is_empty() and game.moon.r > 0, "celestial body built")
	_ok(game.fog_bands.size() > 0, "fog bands built")
	game.level = {}

	# ---------- 58. Надёжность: версия сейва, active_cd, дейли-пул ----------
	game._save_settings()
	var vcfg := ConfigFile.new()
	vcfg.load(game._cfg_path())
	_ok(int(vcfg.get_value("meta_info", "version", -1)) == game.SAVE_VERSION, "save file carries format version")
	# active_cd переживает сейв/загрузку забега
	game.start_run(555, "cd")
	game.give_active("bomb")
	game.P.active_cd = 123
	game._save_run()
	game.P.active_cd = 0
	game.continue_run()
	_ok(int(game.P.active_cd) == 123, "continue restores active cooldown (%d)" % int(game.P.active_cd))
	game._clear_run_save()
	# дейли: пул оружия/реликвий полный независимо от разблокировок
	game.unlocks = {}
	game.daily_run = true
	_ok(game.unlocked_weapon_drops().size() == game.WEAPON_DROPS.size(), "daily uses full weapon pool")
	game.relics = {}
	var saw_locked := false
	for _i in range(300):
		if game.random_unowned_relic() == "bulwark":   # заперта вне дейли
			saw_locked = true
	_ok(saw_locked, "daily relic pool includes locked relics")
	game.daily_run = false
	_ok(not game.unlocked_weapon_drops().has("railgun"), "non-daily pool still gated")
	game.level = {}
	game.state = "menu"

	# ---------- 59. UI: литеральные подписи кнопок помещаются в их ширину (RU/EN) ----------
	# скрейпим исходник по вызовам _btn(Rect2(...), "литерал", ...) и меряем реальным шрифтом
	game._load_fonts()
	var btn_rex := RegEx.new()
	btn_rex.compile("_btn\\(Rect2\\([^,]+,[^,]+,\\s*([0-9.]+)\\s*,[^)]+\\)\\s*,\\s*\"([^\"]+)\"")
	var fsrc := FileAccess.get_file_as_string("res://Game.gd")
	var checked := 0
	for bm in btn_rex.search_all(fsrc):
		var bw := float(bm.get_string(1))
		var lbl := bm.get_string(2)
		for lng in ["ru", "en"]:
			game.lang = lng
			var tw: float = game.font.get_string_size(game.T(lbl), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_ok(tw <= bw - 8.0, "btn '%s' fits %dpx [%s] (text %.0fpx)" % [lbl, int(bw), lng, tw])
		checked += 1
	_ok(checked >= 15, "button-fit scraper found enough buttons (%d)" % checked)
	game.lang = "ru"

	# ---------- 60. Фузз: случайные действия + инварианты ----------
	# случайный бот: движение/прыжки/стрельба/рывки/активы/магазин/алтари/смерти;
	# на каждом шаге проверяются инварианты состояния
	var fuzz_viol := 0
	for fseed in [77, 424242]:
		game.start_run(fseed, "fuzz")
		var frng := RandomNumberGenerator.new()
		frng.seed = fseed
		for i in range(5000):
			if game.state == "play":
				game.input.move = [-1, 0, 1, 1][frng.randi_range(0, 3)]
				game.input.jump_pressed = frng.randf() < 0.06
				game.input.jump_held = frng.randf() < 0.5
				game.input.down = frng.randf() < 0.02
				game.input.aim = Vector2(game.P.x + frng.randf_range(-300, 300), game.P.y + frng.randf_range(-200, 200))
				game.input.shoot_held = true
				game.input.shoot_clicked = i % 5 == 0
				game.input.dash = frng.randf() < 0.03
				game.input.ult = game.ult >= game.ULT_MAX
				game.input.switch_to = (frng.randi_range(0, game.P.weapons.size() - 1)) if frng.randf() < 0.01 else -1
				if frng.randf() < 0.005:
					game.use_active()
			game.sim_step()
			match game.state:
				"upgrade": game.choose_upgrade(game.offer[frng.randi_range(0, game.offer.size() - 1)])
				"shop":
					if frng.randf() < 0.5 and game.shop_items.size() > 0:
						game.buy_shop_item(frng.randi_range(0, game.shop_items.size() - 1))
					game.shop_continue()
				"shrine": game.resolve_shrine(frng.randf() < 0.7)
				"dead": game.start_run(fseed + i, "fuzz2")
			if game.state == "play":
				if game.P.hp > game.P.maxhp + 0.01: fuzz_viol += 1
				if game.coins < 0: fuzz_viol += 1
				if not (is_finite(game.P.x) and is_finite(game.P.y)): fuzz_viol += 1
				if game.P.shield > game.P.max_shield + 0.01: fuzz_viol += 1
				if game.enemies.size() > 400: fuzz_viol += 1
	_ok(fuzz_viol == 0, "fuzz: no invariant violations (%d)" % fuzz_viol)
	game.level = {}
	game.state = "menu"
	game.lang = "ru"
	game._save_settings()

	# ---------- 61. Новый контент: тотем, лазер, алтари, хроно, удача, мимик ----------
	# тотем баффает соседей хастом
	var tWS2 := 24
	var tgrid2 := PackedByteArray(); tgrid2.resize(tWS2 * 12)
	for tx in range(tWS2): tgrid2[10 * tWS2 + tx] = 1
	game.level = { "W": tWS2, "H": 12, "grid": tgrid2, "px_w": tWS2 * 32, "px_h": 12 * 32, "crate_hp": {} }
	game.cam = Vector2.ZERO
	game.P = game.make_player(); game.P.x = 600.0; game.P.y = 9 * 32 - 30
	var tot: Dictionary = game._spawn_enemy("totem", 200.0, 9 * 32 - 34)
	var ally: Dictionary = game._spawn_enemy("walker", 240.0, 9 * 32 - 28)
	game.enemies = [tot, ally]
	for i in range(40):
		game.tick += 1
		game.update_enemies()
	_ok(int(ally.get("haste", 0)) > 0, "totem hastes nearby ally")
	_ok(ally.spd > ally.base_spd, "hasted ally moves faster")
	# лазер: фазы и урон
	var lz := { "type": "laser", "x": game.P.x + game.P.w / 2.0, "y1": 0.0, "y2": 320.0, "phase": 0 }
	game.hazards = [lz]
	_ok(game._laser_on({ "phase": (180 - (game.tick % 180)) % 180 }) == 0, "laser off-phase")
	var lz_hp0: float = game.P.hp
	game.P.inv = 0
	game.state = "play"
	var hurt_by_laser := false
	for i in range(200):
		game.tick += 1
		game.update_hazards()
		if game.P.hp < lz_hp0: hurt_by_laser = true; break
	_ok(hurt_by_laser, "active laser damages player standing in beam")
	game.hazards = []
	# алтари: жадность и хронос
	game.P = game.make_player()
	game.pending_shrine = { "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0, "type": "greed", "used": false }
	game.resolve_shrine(true)
	_ok(int(game.P.stats.coin_bonus) == 1 and game.P.stats.armor_mul > 1.0, "greed altar applies")
	game.pending_shrine = { "x": 0.0, "y": 0.0, "w": 1.0, "h": 1.0, "type": "chrono", "used": false }
	var mh0: int = int(game.P.maxhp)
	game.resolve_shrine(true)
	_ok(game.P.stats.dash_cd_mul < 1.0 and float(game.P.stats.active_cd_mul) < 1.0 and int(game.P.maxhp) == mh0 - 10, "chrono altar applies")
	# хроно-актив уважает active_cd_mul
	game.give_active("slowmo")
	game.P.active_cd = 0
	game.use_active()
	_ok(game.P.active_cd < game.P.active_max, "active cooldown reduced by chrono")
	# удача: множитель дропа растёт
	game.P = game.make_player()
	game.apply_upgrade_stats({ "id": "luck" })
	_ok(game.P.stats.drop_mul > 1.0, "luck upgrade raises drop_mul")
	# мимик: на 4+ уровне срабатывает и зовёт волну
	game.lvl = 5
	game.enemies = []
	game.pickups = []
	var mimic_seen := false
	for i in range(200):
		var mch := { "x": 300.0, "y": 260.0, "w": 26.0, "h": 18.0, "opened": false }
		game.open_chest(mch)
		if game.enemies.size() > 0: mimic_seen = true; break
	_ok(mimic_seen, "mimic chest eventually triggers ambush")
	game.enemies = []
	game.pickups = []
	game.hazards = []
	game.level = {}
	game.state = "menu"

	# ---------- 62. Модификаторы уровня и щитоносец ----------
	# моды выпадают на 3+ небоссовых уровнях
	var mods_seen := {}
	for s in range(1, 60):
		for lv in [3, 4, 6, 7]:
			var Lm = game.generate_level(s * 17 + lv, lv)
			if Lm.mod != "":
				mods_seen[Lm.mod] = true
	_ok(mods_seen.size() >= 3, "all level mods occur (%s)" % str(mods_seen.keys()))
	# кровавая луна ускоряет врагов; рой — больше и слабее
	var found_bm := false
	for s in range(1, 200):
		var Lbm = game.generate_level(s * 13 + 4, 4)
		if Lbm.mod == "bloodmoon":
			found_bm = true
			var ok_spd := true
			for en in Lbm.enemies:
				if en.type == "walker" and not en.get("elite", false) and absf(en.spd - 1.1 * 1.2) > 0.25:
					ok_spd = false
			_ok(ok_spd, "bloodmoon walkers are faster")
			break
	_ok(found_bm, "bloodmoon reachable")
	# щитоносец: фронтальная пуля гасится, тыловая — нет
	var sWS3 := 24
	var sg3 := PackedByteArray(); sg3.resize(sWS3 * 12)
	for tx in range(sWS3): sg3[10 * sWS3 + tx] = 1
	game.level = { "W": sWS3, "H": 12, "grid": sg3, "px_w": sWS3 * 32, "px_h": 12 * 32, "crate_hp": {} }
	game.state = "play"
	game.P = game.make_player(); game.P.x = 60.0; game.P.y = 9 * 32 - 30
	var sb: Dictionary = game._spawn_enemy("shieldbearer", 300.0, 9 * 32 - 33)
	sb.hp = 1000; sb.maxhp = 1000; sb.dir = -1   # щит влево, к игроку
	game.enemies = [sb]
	game.bullets = [{ "x": sb.x - 6, "y": sb.y + 10, "vx": 8.0, "vy": 0.0, "dmg": 50, "crit": false, "from": "p", "life": 30, "color": Color.WHITE }]
	game.update_bullets()
	var front_dmg: int = 1000 - int(sb.hp)
	sb.hp = 1000
	game.bullets = [{ "x": sb.x + sb.w + 6, "y": sb.y + 10, "vx": -8.0, "vy": 0.0, "dmg": 50, "crit": false, "from": "p", "life": 30, "color": Color.WHITE }]
	game.update_bullets()
	var back_dmg: int = 1000 - int(sb.hp)
	_ok(front_dmg < back_dmg and front_dmg <= 15, "shield blocks frontal (%d) vs rear (%d)" % [front_dmg, back_dmg])
	game.enemies = []; game.bullets = []; game.level = {}; game.state = "menu"

	# ---------- 63. Зелья, бомбардир, «Золотая лихорадка» ----------
	# зелье применяется при подборе и даёт эффект
	var pWS := 24
	var pg4 := PackedByteArray(); pg4.resize(pWS * 12)
	for tx in range(pWS): pg4[10 * pWS + tx] = 1
	game.level = { "W": pWS, "H": 12, "grid": pg4, "px_w": pWS * 32, "px_h": 12 * 32, "crate_hp": {} }
	game.state = "play"
	game.P = game.make_player(); game.P.x = 100.0; game.P.y = 9 * 32 - 30
	game.pickups = [{ "kind": "potion", "pot": "stone", "x": game.P.x, "y": game.P.y, "w": 14, "h": 18, "vy": 0.0, "t": 0.0 }]
	game.update_pickups()
	_ok(game.P.pot_stone_t > 0.0, "stone potion applies on pickup")
	game.P.inv = 0
	game.P.hp = 100.0; game.P.maxhp = 100.0
	game.hurt_player(40, 0)
	var stone_dmg: float = 100.0 - game.P.hp
	game.P.pot_stone_t = 0.0
	game.P.hp = 100.0; game.P.inv = 0
	game.hurt_player(40, 0)
	var plain_dmg: float = 100.0 - game.P.hp
	_ok(stone_dmg < plain_dmg, "stoneskin halves damage (%d < %d)" % [int(stone_dmg), int(plain_dmg)])
	# бомбардир сбрасывает навесную бомбу
	game.P = game.make_player(); game.P.x = 300.0; game.P.y = 9 * 32 - 30
	game.cam = Vector2.ZERO
	var bmr: Dictionary = game._spawn_enemy("bomber", 300.0, 100.0)
	bmr.cd = 0
	game.enemies = [bmr]
	game.bullets = []
	var dropped := false
	for i in range(200):
		game.update_enemies()
		for b in game.bullets:
			if b.get("grenade", false) and b.from == "e":
				dropped = true
		if dropped: break
	_ok(dropped, "bomber drops arcing bombs")
	# золотая лихорадка: больше сундуков, враги крепче
	var found_gr := false
	for s in range(1, 250):
		var Lg = game.generate_level(s * 19 + 4, 4)
		if Lg.mod == "goldrush":
			found_gr = true
			_ok(Lg.chests.size() >= 3, "goldrush spawns extra chests (%d)" % Lg.chests.size())
			break
	_ok(found_gr, "goldrush reachable")
	# монета за убийство при лихорадке
	game.level = { "W": pWS, "H": 12, "grid": pg4, "px_w": pWS * 32, "px_h": 12 * 32, "crate_hp": {}, "mod": "goldrush" }
	game.relics = {}
	game.coins = 0
	var vic: Dictionary = game._spawn_enemy("walker", 200.0, 200.0)
	vic.hp = 1
	game.enemies = [vic]
	game.hurt_enemy(vic, 50, false, true)
	_ok(game.coins >= 1, "goldrush grants kill coin (%d)" % game.coins)
	game.enemies = []; game.bullets = []; game.pickups = []; game.level = {}; game.state = "menu"

	if failures == 0:
		print("\nALL TESTS PASSED")
	else:
		print("\n%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

func _empty_grid(w: int, h: int) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(w * h)  # заполняется нулями (T_EMPTY)
	return g

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
		if game.state == "shop":
			game.shop_continue()
		if game.state == "shrine":
			game.resolve_shrine(i % 2 == 0)   # бот то принимает, то отказывается
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
