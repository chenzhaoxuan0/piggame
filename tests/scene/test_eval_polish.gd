extends SceneTree
## 2026-11-17 评测增强验证：NPC 骨夹生活感 / 真水池视觉 / 宝可梦式对战演出。
## 位移契约由 test_farm_playground 钉住，这里钉「看起来在干什么」。

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("EVAL_POLISH_TEST PASS: %s" % message)
	else:
		_failures += 1
		printerr("EVAL_POLISH_TEST FAIL: %s" % message)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	var level = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root_node.add_child(level)
	await process_frame
	await process_frame
	level.start_game()
	await process_frame
	var game: Node = root.get_node("GameManager")
	game.choose_red()
	await process_frame
	var farm = level.farm
	var pig = level.player

	# 1. 老牛耕地：运行时 plow 骨夹 + 挂骨木犁。
	var ox_actor = farm._actor_of("ox")
	_check(ox_actor != null and ox_actor.has_clip("plow"), "Ox registers the runtime plow clip")
	await create_timer(0.4).timeout
	_check(ox_actor.current_clip() == "plow", "Ox plays the plow loop (head down, diagonal gait)")
	var ox_visual = farm._visual_of("ox")
	_check(ox_visual != null and ox_visual.find_child("OxPlow", true, false) != null,
		"Ox pulls a visible plow attached to its body bone")

	# 2. 小羊闷闷不乐：mope 循环 + sigh 单次。
	var sheep_actor = farm._actor_of("sheep")
	_check(sheep_actor != null and sheep_actor.has_clip("mope") and sheep_actor.has_clip("sigh"),
		"Sheep registers mope + sigh clips")
	_check(sheep_actor.current_clip() == "mope", "Sheep mopes with a drooped head")

	# 3. 农场主拄棍警戒。
	var farmer_actor = farm._actor_of("farmer")
	_check(farmer_actor != null and farmer_actor.current_clip() == "guard",
		"Farmer guards with baton sway instead of freezing")

	# 4. 追风自主跑圈：猪贴在身边也照跑（与猪零绑定）+ run 骨夹 + 蹄尘。
	var horse_actor = farm._actor_of("horse")
	var horse_visual = farm._visual_of("horse")
	pig.global_position = farm._npcs.horse.global_position + Vector3(1.5, 0.4, 1.5)
	await create_timer(0.6).timeout
	_check(horse_actor != null and horse_actor.current_clip() == "run",
		"Horse keeps galloping with the pig right beside it (no pig binding)")
	var dust = horse_visual.get_node_or_null("HoofDust") if horse_visual != null else null
	_check(dust != null and dust.emitting, "Galloping horse kicks up hoof dust")

	# 5. 截停只认对话：halted+dialogue 站定刨蹄；解除后从原地继续跑。
	farm.set_horse_halted(true)
	pig.set_control_mode("dialogue")
	var halted_pos: Vector3 = farm._npcs.horse.global_position
	await create_timer(0.7).timeout
	_check(farm._npcs.horse.global_position.distance_to(halted_pos) < 0.3,
		"F-dialogue intercepts the horse mid-lap")
	_check(horse_actor.has_clip("stamp"), "Horse owns the hoof-stamp idle gesture")
	_check(horse_actor.current_clip() != "run", "Halted horse idles instead of galloping in place")
	farm.set_horse_halted(false)
	pig.set_control_mode("explore")
	await create_timer(0.8).timeout
	_check(farm._npcs.horse.global_position.distance_to(halted_pos) > 0.8,
		"Dialogue over, the lap resumes from where the horse stood")
	_check(farm.get_node_or_null("SafeSignHorse") != null,
		"Pasture entrance wears the dog-stop safe-zone sign")

	# 6. 对话完成：解除工作循环，当场欢呼（拒绝僵立）。
	farm.set_npc_completed("sheep")
	await create_timer(0.3).timeout
	_check(sheep_actor.current_clip() == "celebrate", "Sheep celebrates after the truth")

	# 7. 真水池：水 shader + 下沉池底 + 沙岸 + 睡莲。
	var water = farm.get_node("PondWater")
	_check(water.material_override is ShaderMaterial, "Pond water wears the animated wave shader")
	_check(farm.get_node_or_null("PondBed") != null and farm.get_node_or_null("PondBank") != null,
		"Pond has a sunken bed and a sandy bank")
	_check(farm.get_node_or_null("LilyPad0") != null, "Lily pads float on the pond")

	# 8. 入水溅水花与涟漪。
	pig.global_position = farm.POND_CENTRE + Vector3(0, 0.5, 0)
	await physics_frame
	await physics_frame
	await create_timer(0.15).timeout
	var splash_found := false
	for child in farm.get_children():
		if child.name.begins_with("PondSplash") or child.name.begins_with("PondRipple"):
			splash_found = true
	_check(splash_found, "Entering the pond spawns splash droplets and ripples")

	# 9. 对战演出：开场 → 出招 3D 火花 → 胜利瘫倒 → 再战恢复站姿。
	game.stage = "showdown"
	level._start_farmer_showdown()
	await process_frame
	await create_timer(0.3).timeout
	_check(level.pokemon_battle.battle_active, "Showdown starts for the staging check")
	# 指挥台布局钉子：autowrap 旁白曾把面板撑到屏幕外，技能格全不可点。
	var console_rect: Rect2 = level.pokemon_battle.console_panel.get_global_rect()
	_check(console_rect.size.y <= 300.0, "Battle console keeps its design height (no autowrap blowup)")
	var btn0_rect: Rect2 = level.pokemon_battle.move_buttons[0].get_global_rect()
	_check(btn0_rect.position.y >= console_rect.position.y
		and btn0_rect.position.y + btn0_rect.size.y <= console_rect.position.y + console_rect.size.y + 1.0,
		"Move buttons stay inside the console (clickable, on screen)")
	# 出招前轮询 busy 释放：固定间隔在套件负载下会落进 busy 窗口，
	# 克制回合错位导致"没赢"——轮询消除一切时序假设。
	for move_index in [2, 1, 3]:
		for i in 40:
			if not level.pokemon_battle.is_busy and level.pokemon_battle.battle_active:
				break
			await create_timer(0.1).timeout
		level.pokemon_battle.execute_move(move_index)
		printerr("EVALDBG after move %d: turn=%d farmer_hp=%.1f pig_hp=%.1f" % [
			move_index, level.pokemon_battle.current_turn,
			level.pokemon_battle.farmer_hp, level.pokemon_battle.pig_hp])
		if move_index == 2:
			await create_timer(0.2).timeout
			var vfx_found := false
			for child in level.get_children():
				if child is Label3D or child.get_script() == preload("res://scripts/art/puff_emitter.gd"):
					vfx_found = true
			_check(vfx_found, "Pig attack spawns 3D sparks/shout staging")
		await create_timer(0.3).timeout
	# 先钉战斗结果（排除"没赢"），再轮询瘫倒演出（排除固定窗口擦边）。
	var farmer_visual = farm._visual_of("farmer")
	var won := false
	for i in 20:
		await create_timer(0.15).timeout
		if level.pokemon_battle.farmer_hp <= 0.0:
			won = true
			break
	_check(won, "Counter sequence defeats the farmer (hp reaches 0)")
	var collapsed := false
	for i in 30:
		await create_timer(0.15).timeout
		if farmer_visual != null and farmer_visual.rotation.x < -0.8:
			collapsed = true
			break
	_check(collapsed, "Defeated farmer collapses (staged fall)")
	game.stage = "showdown"
	level._retry_farmer_showdown()
	await process_frame
	await create_timer(0.2).timeout
	_check(farmer_visual != null and absf(farmer_visual.rotation.x) < 0.1,
		"Rematch restores the farmer's stance")

	root_node.queue_free()
	await process_frame
	print("\nEVAL POLISH TESTS FINISHED: failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)
