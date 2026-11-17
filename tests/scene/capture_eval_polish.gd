extends SceneTree
## 2026-11-17 评测增强截图：NPC 生活感 / 真水池 / 宝可梦对战演出 / 画质档位。
##   Godot_v4.3-stable_win64.exe --path . -s tests/scene/capture_eval_polish.gd

const OUT := "res://builds/zone_screens/"

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + "eval_%s.png" % name)
	print("saved eval_", name)

func _free_cam(cam: Camera3D) -> void:
	cam.queue_free()

func _run() -> void:
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.8).timeout
	office.start_game()
	await create_timer(0.3).timeout
	var game: Node = root.get_node("GameManager")
	game.choose_red()
	await create_timer(0.3).timeout
	var farm = office.farm
	var pig = office.player
	pig.set_control_mode("cinematic")
	office.hud.visible = false
	office.in_start_menu = false
	if is_instance_valid(office.start_menu):
		office.start_menu.visible = false
	var gm = root.get_node("GraphicsManager")
	gm.set_tier("high")

	# 1. 老牛耕地（等它走到犁沟中段，犁刃扬土）。
	pig.global_position = Vector3(40, 8.6, -147.4)
	await create_timer(2.5).timeout
	var ox_pos: Vector3 = farm._npcs.ox.global_position
	var cam := Camera3D.new()
	root.add_child(cam)
	# 后侧 3/4 机位：犁挂在牛身后，正面机位会被牛身挡住。
	cam.global_position = ox_pos + Vector3(-5.5, 3.0, -6.0)
	cam.look_at(ox_pos + Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	await _shot("ox_plow")
	_free_cam(cam)

	# 2. 小羊在矮棚边闷闷不乐（耷拉脑袋）。
	var sheep_pos: Vector3 = farm._npcs.sheep.global_position
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = sheep_pos + Vector3(4.5, 2.6, 5.5)
	cam.look_at(sheep_pos + Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await _shot("sheep_mope")
	_free_cam(cam)

	# 3. 追风跑圈（奔跑骨夹 + 蹄尘）。
	await create_timer(0.5).timeout
	var horse_pos: Vector3 = farm._npcs.horse.global_position
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = horse_pos + Vector3(7, 4, 7)
	cam.look_at(horse_pos + Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await _shot("horse_gallop")
	_free_cam(cam)

	# 3b. 猪站在跑道边，马照跑不误（零绑定）。
	pig.global_position = farm._npcs.horse.global_position + Vector3(2.0, 0.4, 2.0)
	await create_timer(0.5).timeout
	var horse_pos2: Vector3 = farm._npcs.horse.global_position
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = horse_pos2 + Vector3(6, 3.5, 6)
	cam.look_at(horse_pos2 + Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	await _shot("horse_autonomous")
	_free_cam(cam)

	# 3c. 牛耕地入口安全门 + 恶犬止步标识。
	var gate_pos: Vector3 = farm.L.GATE_OX
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = gate_pos + Vector3(6, 3.2, 9)
	cam.look_at(gate_pos + Vector3(0, 1.6, 0), Vector3.UP)
	cam.current = true
	await _shot("safe_gate")
	_free_cam(cam)

	# 4. 真水池：猪刚跳进去，水花 + 涟漪 + 波光。
	pig.global_position = farm.POND_CENTRE + Vector3(1.5, 0.5, 1.0)
	await create_timer(0.3).timeout
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = farm.POND_CENTRE + Vector3(9, 5.5, 9)
	cam.look_at(farm.POND_CENTRE, Vector3.UP)
	cam.current = true
	await _shot("pond_water")
	_free_cam(cam)

	# 5. 画质对比：同一广角，低档 vs 高档。
	cam = Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(58, 46, 62)
	cam.look_at(Vector3(0, 20, 0), Vector3.UP)
	cam.current = true
	gm.set_tier("low")
	await create_timer(0.3).timeout
	await _shot("farm_low")
	gm.set_tier("high")
	await create_timer(0.3).timeout
	await _shot("farm_high")
	_free_cam(cam)

	# 6. 设置菜单的画质档位行。
	office.hud.visible = true
	office._open_settings(true)
	await create_timer(0.3).timeout
	await _shot("settings_quality")
	office._close_settings()
	await create_timer(0.2).timeout
	# _close_settings 会按「从主菜单来」的假设恢复主菜单；截图要干净战场。
	office.in_start_menu = false
	if is_instance_valid(office.start_menu):
		office.start_menu.visible = false

	# 7. 宝可梦式对战：开场 UI → 出招演出。
	pig.global_position = farm._gate.global_position + Vector3(0, 0.4, 7)
	pig.set_control_mode("explore")
	await create_timer(0.4).timeout
	game.stage = "showdown"
	office._start_farmer_showdown()
	await create_timer(0.7).timeout
	await _shot("battle_intro")
	office.pokemon_battle.execute_move(2)
	await create_timer(0.22).timeout
	await _shot("battle_attack")
	await create_timer(0.6).timeout

	office.queue_free()
	quit(0)
