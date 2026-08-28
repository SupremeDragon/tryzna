extends Node
## Димовий тест ядра. Запускається без вікна:
##   tools\test.bat
##
## Перевіряє те, на чому тримається вся гра:
##   1) Проєктор має ДВІ незалежні осі, і кожен потойбічний світ убиває свою.
##   2) Смерть доводить глибину до нуля; піднесення — висоту.
##   3) SideSolver забирає в персонажа вимір глибини.
##   4) Час стоїть тільки у Висі: світ мертвих іде далі без тебе.
##   5) Реєстр діянь і збереження переживають усе це.

var _failures: int = 0


func _ready() -> void:
	await _run()
	if _failures == 0:
		print("\n[OK] Усі перевірки пройдено.")
		get_tree().quit(0)
	else:
		printerr("\n[FAIL] Провалено перевірок: %d" % _failures)
		get_tree().quit(1)


func _run() -> void:
	_test_projection()
	_test_side_solver_collapses_depth()
	_test_ledger()
	_test_save_roundtrip()
	await _test_fold_death()
	await _test_fold_ascent()
	_test_worlds_are_separate()
	_test_collision_topdown()
	_test_collision_side()
	_test_attack_phases()
	_test_combatant()
	_test_enemy_always_telegraphs()
	_test_input_map()
	_test_deed_ledger()


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		_failures += 1
		printerr("  FAIL %s" % what)


func _test_projection() -> void:
	print("Проєкція:")
	Projector.depth_scale = WorldSpace.DEPTH_PLYN
	var deep: Vector2 = Projector.project(Vector3(0.0, 500.0, 0.0))
	_check(deep.y > 0.0, "у Плині глибина зсуває обʼєкт униз екрана")

	Projector.depth_scale = WorldSpace.DEPTH_NYTS
	Projector.height_scale = WorldSpace.HEIGHT_NYTS
	var flat: Vector2 = Projector.project(Vector3(0.0, 500.0, 0.0))
	_check(is_zero_approx(flat.y), "у Ниці глибина не впливає ні на що")

	var high: Vector2 = Projector.project(Vector3(0.0, 500.0, 300.0))
	_check(high.y < flat.y, "у Ниці висота лишається живою")
	_check(is_equal_approx(Projector.flatness(), 1.0), "силует у Ниці = 100%")
	_check(is_zero_approx(Projector.mapness()), "Ниць — не карта")

	# Дзеркало: у Висі гине висота, а не глибина.
	Projector.depth_scale = WorldSpace.DEPTH_VYS
	Projector.height_scale = WorldSpace.HEIGHT_VYS
	var base: Vector2 = Projector.project(Vector3(0.0, 500.0, 0.0))
	var tower: Vector2 = Projector.project(Vector3(0.0, 500.0, 400.0))
	_check(base.is_equal_approx(tower), "у Висі вежа осіла у власну основу")
	_check(base.y > 0.0, "у Висі глибина живіша, ніж будь-де")
	_check(is_equal_approx(Projector.mapness(), 1.0), "карта у Висі = 100%")
	_check(is_zero_approx(Projector.flatness()), "Висі — не силует")

	Projector.depth_scale = WorldSpace.DEPTH_PLYN
	Projector.height_scale = WorldSpace.HEIGHT_PLYN


func _test_side_solver_collapses_depth() -> void:
	print("Розвʼязувач Ниці:")
	var solver := SideSolver.new(300.0)
	var state := MovementSolver.MoverState.new()
	state.position = Vector3(0.0, 600.0, 0.0)

	for _i: int in range(240):
		solver.step(state, Vector2(0.0, -1.0), false, 1.0 / 60.0)

	_check(is_zero_approx(state.position.y), "глибина притягнута до нуля")
	_check(is_zero_approx(state.velocity.y), "рух углиб неможливий")

	solver.step(state, Vector2.ZERO, true, 1.0 / 60.0)
	_check(state.position.z > 0.0 or state.velocity.z > 0.0, "стрибок підіймає персонажа")


func _test_ledger() -> void:
	print("Реєстр діянь:")
	Ledger.clear()
	Ledger.record(&"test_mercy", "Дав хліб жебраку", [&"милосердя"], 1.0)
	Ledger.record(&"test_blood", "Убив цілителя", [&"насильство"], 2.0)
	_check(Ledger.count() == 2, "записано два вчинки")
	_check(is_equal_approx(Ledger.weight_of(&"насильство"), 2.0), "вага за тегом рахується")
	_check(is_equal_approx(Ledger.weight_of(&"брехня"), 0.0), "невикористаний тег дає нуль")

	Ledger.record_prayer(&"pray_rain", "про дощ", true)
	Ledger.record_prayer(&"pray_daughter", "за доньку", false)
	Ledger.record_prayer(&"pray_self", "про себе", true)
	_check(Ledger.prayer_count() == 3, "молитовний слід пишеться")
	_check(Ledger.prayers_for_self() == 2, "видно, скільки молитов було про себе")
	Ledger.clear()


func _test_save_roundtrip() -> void:
	print("Збереження:")
	Ledger.clear()
	GameState.mortal_name = "Тиха"
	GameState.year = 41
	GameState.believers = 17
	Ledger.record(&"test_altar", "Побудував вівтар на роздоріжжі", [&"віра"], 1.0)
	Ledger.record_prayer(&"test_pray", "про врожай", true)

	_check(SaveSystem.save_to(0) == OK, "збереження записалося")

	GameState.mortal_name = ""
	GameState.year = 0
	GameState.believers = 0
	Ledger.clear()

	_check(SaveSystem.load_from(0) == OK, "збереження прочиталося")
	_check(GameState.mortal_name == "Тиха", "імʼя відновлено")
	_check(GameState.year == 41, "рік відновлено")
	_check(GameState.believers == 17, "кількість вірян відновлена")
	_check(Ledger.count() == 1, "Реєстр діянь пережив збереження")
	_check(Ledger.prayer_count() == 1, "молитовний слід пережив збереження")

	SaveSystem.erase(0)
	Ledger.clear()


func _test_fold_death() -> void:
	print("Смерть — складання глибини:")
	WorldMode.set_mode(WorldMode.Mode.PLYN)
	_check(WorldMode.solver() is TopDownSolver, "у Плині працює топ-даун розвʼязувач")
	_check(WorldMode.time_flowing, "у Плині час тече")

	WorldMode.fold_to(WorldMode.Mode.NYTS, 0.4)
	_check(WorldMode.is_folding, "складання почалося")
	_check(WorldMode.time_flowing, "світ іде далі без тебе — час НЕ спиняється")

	await get_tree().create_timer(0.2).timeout
	_check(
		Projector.depth_scale < WorldSpace.DEPTH_PLYN and Projector.depth_scale > 0.0,
		"на середині переходу світ частково сплющений"
	)

	await get_tree().create_timer(0.5).timeout
	_check(not WorldMode.is_folding, "складання завершилося")
	_check(WorldMode.current == WorldMode.Mode.NYTS, "світ перемкнувся на Ниць")
	_check(is_zero_approx(Projector.depth_scale), "глибина дійшла до нуля")
	_check(is_equal_approx(Projector.height_scale, 1.0), "висоту смерть не чіпає")
	_check(WorldMode.solver() is SideSolver, "керування перейшло на профільний розвʼязувач")


func _test_fold_ascent() -> void:
	print("Піднесення — осідання висоти:")
	WorldMode.set_mode(WorldMode.Mode.PLYN)
	_check(WorldMode.time_flowing, "перед піднесенням час іще тече")

	WorldMode.fold_to(WorldMode.Mode.VYS, 0.4, 0.25)
	_check(not WorldMode.time_flowing, "час спинився ОДРАЗУ, ще до руху камери")

	await get_tree().create_timer(0.12).timeout
	_check(
		is_equal_approx(Projector.height_scale, 1.0),
		"під час паузи світ іще не рухається — тільки завмер"
	)

	await get_tree().create_timer(0.9).timeout
	_check(not WorldMode.is_folding, "піднесення завершилося")
	_check(WorldMode.current == WorldMode.Mode.VYS, "світ перемкнувся на Висі")
	_check(is_zero_approx(Projector.height_scale), "висота дійшла до нуля — світ став картою")
	_check(Projector.depth_scale > WorldSpace.DEPTH_PLYN, "глибина навпаки зросла")
	_check(not WorldMode.time_flowing, "у Висі час стоїть")

	WorldMode.set_mode(WorldMode.Mode.PLYN)
	_check(WorldMode.time_flowing, "повернення в Плинь знову запускає час")


func _test_worlds_are_separate() -> void:
	print("Три окремі світи:")
	var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	add_child(main)

	var shape := {}
	for mode: int in [0, 1, 2]:
		WorldMode.set_mode(mode as WorldMode.Mode)
		main.call("_load_world", mode)
		var plates: Array = main.get("_plates") as Array
		var props: Array = main.get("_props") as Array
		shape[mode] = [plates.size(), props.size()]

	_check(shape[1] != shape[2], "Плинь і Ниць — різні локації, а не той самий майдан")
	_check(shape[1] != shape[0], "Плинь і Висі — різні локації")
	_check(int(shape[0][0]) > 1, "Висі — архіпелаг плато, а не одна плита")
	_check(int(shape[2][0]) == 1, "Ниць — один вузький коридор")

	var hint_plyn: String = main.call("_hint_for", 1) as String
	var hint_nyts: String = main.call("_hint_for", 2) as String
	var hint_vys: String = main.call("_hint_for", 0) as String
	# Перевіряємо саме СТРИБОК, а не клавішу: пробіл є і в Плині, але там
	# він робить ухилення. Стрибок існує лише там, де є висота під ногами.
	_check("стрибок" in hint_nyts, "у Ниці підказка про стрибок є")
	_check(not ("стрибок" in hint_plyn), "у Плині про стрибок не згадуємо")
	_check(not ("стрибок" in hint_vys), "у Висі про стрибок не згадуємо")
	_check("ухилення" in hint_plyn, "у Плині пробіл — це ухилення")
	_check("удар" in hint_plyn, "у Плині є підказка про удар")

	main.queue_free()
	WorldMode.set_mode(WorldMode.Mode.PLYN)


func _make_solver_world() -> SolidWorld:
	var world := SolidWorld.new()
	# Стіна: від x=200 до x=400. Глибока навмисно — щоб ковзання вздовж неї
	# лишалося ковзанням, а не перетворилося на обхід її краю.
	world.add_box(Vector3(300.0, 0.0, 0.0), Vector2(200.0, 4000.0), 200.0)
	return world


func _test_collision_topdown() -> void:
	print("Зіткнення в Плині (x, глибина):")
	var solver := TopDownSolver.new(330.0, false)
	solver.world = _make_solver_world()

	var state := MovementSolver.MoverState.new()
	state.position = Vector3(0.0, 0.0, 0.0)

	# Ідемо просто в стіну дві секунди.
	for _i: int in range(120):
		solver.step(state, Vector2(1.0, 0.0), false, 1.0 / 60.0)

	var wall_left: float = 200.0 - solver.half_width
	_check(state.position.x <= wall_left + 1.0, "тіло зупинилося перед стіною, а не в ній")
	_check(state.position.x > 150.0, "тіло дійшло до стіни, а не застрягло раніше")

	# Ковзання вздовж стіни: тиснемо в стіну І вбік одночасно.
	var before_y: float = state.position.y
	for _i: int in range(60):
		solver.step(state, Vector2(1.0, 1.0), false, 1.0 / 60.0)
	_check(state.position.y > before_y + 50.0, "вздовж стіни тіло ковзає, а не залипає")
	_check(state.position.x <= wall_left + 1.0, "під час ковзання стіна тримає")

	# Без перешкод — проходимо наскрізь.
	var free_solver := TopDownSolver.new(330.0, false)
	var free_state := MovementSolver.MoverState.new()
	for _i: int in range(120):
		free_solver.step(free_state, Vector2(1.0, 0.0), false, 1.0 / 60.0)
	_check(free_state.position.x > 500.0, "без перешкод рух нічим не обмежений")


func _test_collision_side() -> void:
	print("Зіткнення в Ниці (x, висота):")
	var world := SolidWorld.new()
	# Уступ заввишки 120 — нижче за висоту стрибка (~184), отже береться.
	world.add_box(Vector3(400.0, 0.0, 0.0), Vector2(300.0, 60.0), 120.0)
	# Стіна заввишки 600 — не береться ніяк.
	world.add_box(Vector3(1200.0, 0.0, 0.0), Vector2(120.0, 60.0), 600.0)

	var solver := SideSolver.new(300.0)
	solver.world = world
	var state := MovementSolver.MoverState.new()
	state.position = Vector3(0.0, 0.0, 0.0)

	# Дійти до уступу — має впертися.
	for _i: int in range(90):
		solver.step(state, Vector2(1.0, 0.0), false, 1.0 / 60.0)
	var ledge_left: float = 250.0 - solver.half_width
	_check(state.position.x <= ledge_left + 1.0, "уступ зупиняє того, хто йде по землі")
	_check(is_zero_approx(state.position.z), "поки не стрибнув — стоїть на нулі")
	_check(state.on_ground, "на землі")

	# Стрибнути й зайти на уступ.
	solver.step(state, Vector2(1.0, 0.0), true, 1.0 / 60.0)
	var peak: float = 0.0
	var landed_at: float = -1.0
	for _i: int in range(90):
		solver.step(state, Vector2(1.0, 0.0), false, 1.0 / 60.0)
		peak = maxf(peak, state.position.z)
		# Ловимо саме мить приземлення: далі персонаж піде до краю уступу
		# й зійде з нього, і перевіряти висоту буде вже пізно.
		if landed_at < 0.0 and state.on_ground and state.position.z > 0.0:
			landed_at = state.position.z
			break
	_check(peak > 120.0, "стрибок перевищує уступ (пік %.0f)" % peak)
	_check(is_equal_approx(landed_at, 120.0), "приземлився саме на уступ, не провалився")
	_check(state.on_ground, "на уступі рахується як на землі")
	_check(state.position.x > 250.0, "зайшов на уступ, а не відскочив")

	# Пройти уступ до кінця й зійти — тоді знову земля.
	for _i: int in range(120):
		solver.step(state, Vector2(1.0, 0.0), false, 1.0 / 60.0)
	_check(is_zero_approx(state.position.z), "дійшовши до краю уступу, зійшов на землю")

	# Висока стіна не береться навіть зі стрибком.
	for _i: int in range(400):
		solver.step(state, Vector2(1.0, 0.0), state.on_ground, 1.0 / 60.0)
	var wall_left: float = 1140.0 - solver.half_width
	_check(state.position.x <= wall_left + 1.0, "висока стіна не береться стрибком")

	# Зійти з уступу — впасти на землю.
	var faller := SideSolver.new(300.0)
	faller.world = world
	var fall_state := MovementSolver.MoverState.new()
	fall_state.position = Vector3(400.0, 0.0, 120.0)
	for _i: int in range(90):
		faller.step(fall_state, Vector2(-1.0, 0.0), false, 1.0 / 60.0)
	_check(is_zero_approx(fall_state.position.z), "зійшовши з уступу, тіло падає на землю")


func _test_attack_phases() -> void:
	print("Замах:")
	var swing := AttackState.new(0.10, 0.10, 0.20)
	_check(not swing.is_busy(), "спокійний замах нікого не бʼє")
	_check(not swing.consume(), "поки не натиснув — удару немає")

	_check(swing.press(), "перше натискання починає замах")
	_check(not swing.press(), "повторне натискання посеред замаху ігнорується")
	_check(not swing.is_active(), "у фазі замаху удару ще немає")

	for _i: int in range(7):
		swing.tick(1.0 / 60.0)
	_check(swing.is_active(), "після замаху настає удар")
	_check(swing.consume(), "удар зараховується")
	_check(not swing.consume(), "один замах бʼє РІВНО один раз")

	for _i: int in range(24):
		swing.tick(1.0 / 60.0)
	_check(not swing.is_busy(), "після віддиху тіло знову вільне")
	_check(swing.press(), "і може бити знову")


func _test_combatant() -> void:
	print("Тіло в бою:")
	var body := Combatant.new(3)
	_check(body.is_alive() and body.hp == 3, "починає живим і цілим")

	_check(body.take_hit(1), "перший удар заходить")
	_check(body.hp == 2, "життя зменшилось на одиницю")
	_check(not body.take_hit(1), "другий удар одразу — не заходить, є невразливість")
	_check(body.hp == 2, "життя не впало двічі за один замах")

	for _i: int in range(40):
		body.tick(1.0 / 60.0)
	_check(body.take_hit(1), "коли невразливість минула — удар знову заходить")

	body.invuln_left = 0.0
	_check(body.take_hit(5), "смертельний удар заходить")
	_check(not body.is_alive() and body.hp == 0, "життя не йде в мінус")
	_check(not body.take_hit(1), "мертвого не бʼють")

	body.revive()
	_check(body.is_alive() and body.hp == 3, "оживлення повертає повне життя")


func _test_enemy_always_telegraphs() -> void:
	print("Чесність ворога:")
	var brain := EnemyBrain.new()
	var here := Vector2.ZERO
	var far := Vector2(2000.0, 0.0)

	brain.tick(1.0 / 60.0, here, far, false)
	_check(brain.state == EnemyBrain.State.IDLE, "здалеку ворог спить")

	# Ставимо гравця впритул і крутимо симуляцію.
	var saw_windup: bool = false
	var struck_without_warning: bool = false
	var close := Vector2(60.0, 0.0)
	for _i: int in range(240):
		var previous: EnemyBrain.State = brain.state
		brain.tick(1.0 / 60.0, here, close, false)
		if brain.state == EnemyBrain.State.WINDUP:
			saw_windup = true
		# ГОЛОВНА ГАРАНТІЯ: у STRIKE можна ввійти тільки з WINDUP.
		if brain.state == EnemyBrain.State.STRIKE and previous != EnemyBrain.State.STRIKE \
				and previous != EnemyBrain.State.WINDUP:
			struck_without_warning = true

	_check(saw_windup, "перед ударом ворог замахується")
	_check(not struck_without_warning, "ворог НІКОЛИ не бʼє без замаху")

	var strikes: int = 0
	brain.state = EnemyBrain.State.STRIKE
	for _i: int in range(5):
		if brain.consume_strike():
			strikes += 1
	_check(strikes == 1, "один замах ворога бʼє рівно один раз")

	# Приголомшений ворог не діє.
	brain.tick(1.0 / 60.0, here, close, true)
	_check(brain.state == EnemyBrain.State.IDLE, "приголомшення збиває замах")


func _has_event(action: StringName, type_name: String) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event.get_class() == type_name:
			return true
	return false


func _test_input_map() -> void:
	print("Мапа керування:")
	# Серіалізацію подій у project.godot ми пишемо руками, тож єдиний спосіб
	# упевнитися, що вона розібралася, — спитати саму гру.
	var required: Array[StringName] = [
		&"move_left", &"move_right", &"move_up", &"move_down",
		&"jump", &"attack", &"ability", &"interact",
		&"debug_die", &"debug_live", &"debug_ascend", &"quit_game",
	]
	var missing: Array[String] = []
	for action: StringName in required:
		if not InputMap.has_action(action):
			missing.append(String(action))
	_check(missing.is_empty(), "усі дії на місці (немає: %s)" % ", ".join(missing))

	_check(_has_event(&"move_left", "InputEventKey"), "рух ліворуч є на клавіатурі")
	_check(_has_event(&"move_left", "InputEventJoypadMotion"), "рух ліворуч є на стіку")
	_check(_has_event(&"move_left", "InputEventJoypadButton"), "рух ліворуч є на хрестовині")

	_check(_has_event(&"attack", "InputEventKey"), "удар є на клавіатурі")
	_check(_has_event(&"attack", "InputEventMouseButton"), "удар є на миші")
	_check(_has_event(&"attack", "InputEventJoypadButton"), "удар є на геймпаді")

	_check(_has_event(&"jump", "InputEventJoypadButton"), "пробіл продубльовано на геймпаді")
	_check(_has_event(&"ability", "InputEventJoypadButton"), "відштовх є на геймпаді")
	_check(_has_event(&"interact", "InputEventJoypadButton"), "взаємодія є на геймпаді")


func _test_deed_ledger() -> void:
	print("Реєстр як окрема душа:")
	# Головне, заради чого робився винос: реєстрів має бути БАГАТО.
	var gnat := DeedLedger.new()
	var oksana := DeedLedger.new()

	gnat.record(&"bread", "Дав хліб жебраку", 19, [&"милосердя"], 1.0)
	gnat.record(&"beat", "Побив наймита", 31, [&"насильство"], 2.0)
	oksana.record(&"lie", "Збрехала матері", 21, [&"брехня"], 1.0)

	_check(gnat.count() == 2 and oksana.count() == 1, "у кожної душі свій список")
	_check(is_equal_approx(gnat.weight_of(&"насильство"), 2.0), "ваги рахуються окремо")
	_check(is_zero_approx(oksana.weight_of(&"насильство"), ), "чужі вчинки не протікають")

	# Молитовний слід — те, за чим бог відрізняє прохача від людини.
	gnat.record_prayer(&"p1", "про дощ", 33, true)
	gnat.record_prayer(&"p2", "про дощ", 34, true)
	gnat.record_prayer(&"p3", "за доньку", 35, false)
	_check(gnat.prayer_count() == 3, "молитви пишуться")
	_check(gnat.prayers_for_self() == 2, "видно, скільки було про себе")
	_check(gnat.prayers_for_others() == 1, "і скільки за інших")

	# Сторінку душі можна перенести цілком — це знадобиться Акту III.
	var copy := DeedLedger.new()
	copy.from_dict(gnat.to_dict())
	_check(copy.count() == 2 and copy.prayer_count() == 3, "сторінка переноситься цілком")
	_check(is_equal_approx(copy.weight_of(&"милосердя"), 1.0), "теги переносяться теж")

	# Ядро не знає ні про GameState, ні про EventBus: рік приходить ззовні.
	var deed: Dictionary = copy.record(&"x", "Щось зробив", 99, [], 1.0)
	_check(int(deed.get("year", 0)) == 99, "рік передається ззовні, а не береться з автолоада")
