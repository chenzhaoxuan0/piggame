extends SceneTree
## UI 翻新视觉审查：逐屏截图到 artifacts/ui_refresh/（窗口化运行，非 headless）。
const OUTPUT := "res://artifacts/ui_refresh/"

func _initialize() -> void: call_deferred("_run")

func _shot(name: String) -> void:
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + name + ".png"))
	print("UI_SHOT %s" % name)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var office: Node = load("res://scenes/levels/office_level_1.tscn").instantiate()
	root.add_child(office)
	await create_timer(0.8).timeout
	await _shot("01_start_menu")

	office._open_settings(true)
	await create_timer(0.3).timeout
	await _shot("02_settings")
	office._close_settings()
	await process_frame

	office.start_game()
	await create_timer(0.3).timeout
	office._show_pause_menu()
	await create_timer(0.3).timeout
	await _shot("03_pause")
	office._resume()
	await process_frame

	office.player.reset_at(Vector3(-1.8, 32.1, 91.2))
	office.camera.snap_to_target()
	office._show_toast("挣脱成功！", "借老牛之力震退恶犬，继续闯关！")
	await create_timer(0.5).timeout
	await _shot("04_farm_hud_toast_prompt")

	office.open_dialogue(root.get_node("DialogueManager").get_entry_for("goat"))
	await create_timer(0.4).timeout
	await _shot("05_dialogue")
	office.close_dialogue()
	await process_frame

	office._show_skill_unlock(
		"【 坚 韧 挣 脱 】",
		"借老牛坚忍不屈的硬骨气 · 挣脱命运的死锁",
		"【核心按键】 被咬住时狂按 [ 空格键 / SPACE ] 或 [ E ]",
		"被恶犬扑咬纠缠时，在 3.5 秒内猛敲空格 5 次，即可爆发巨力震退恶犬 6 米并使其眩晕！"
	)
	await create_timer(0.4).timeout
	await _shot("06_skill_card")
	office._dismiss_skill_card()
	await process_frame

	office.qte_panel.visible = true
	office.qte_bar.value = 3
	office.qte_counter_label.text = "3 / 5"
	office.qte_timer_bar.value = 2.1
	await create_timer(0.3).timeout
	await _shot("07_qte")
	office.qte_panel.visible = false

	office.pokemon_battle.start_battle(office)
	await create_timer(0.4).timeout
	await _shot("08_battle")
	office.pokemon_battle.battle_active = false
	office.pokemon_battle.visible = false
	office.dialogue_open = false

	office._show_overlay("旷野归途", "金牌是农场的，但命是你自己的。\n\n风从麦浪上吹来。前面没有围栏与食槽。", [{"text": "重新出发", "call": office._restart}])
	await create_timer(0.3).timeout
	await _shot("09_ending_overlay")
	office.overlay.visible = false

	office._select_level_from_settings("course_1")
	await create_timer(0.7).timeout
	await _shot("10_course1_hud")

	office._select_level_from_settings("course_4")
	await create_timer(1.2).timeout
	await _shot("11_course4_countdown")

	office.queue_free()
	await process_frame
	var cs: Node = load("res://scenes/ui/character_selection.tscn").instantiate()
	root.add_child(cs)
	await create_timer(0.5).timeout
	await _shot("12_character_selection")
	quit()