extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _run() -> void:
	game=Main.new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.state.coins=10000
	game.state.engineers=3
	game.state.scientists=3
	game.state.upgrades=20
	game.state.deliveries=3
	game.state.place_decoration(3,"sculpture")
	game.state.place_decoration(7,"house")
	game.state.place_reactor(5,"hydrogen")
	game.state.reactors[1].build_left=0
	game.state.reactors[1].positions[1][0]+=0.20
	game.state.reactors[1].stock=10
	game._sync_world()
	await create_timer(3.2).timeout
	await capture("island-v07")
	game._show_market()
	assert(game.modal.mode=="mail")
	await capture("market-v07")
	game._close_modal()
	game._select_plot(5)
	game.state.unlock_science_method("ml_small")
	game.state.run_science_task("ml_small",1)
	for n in range(1000):
		if game.state.science_pending.is_empty(): break
		await create_timer(0.01).timeout
	assert(game.state.science_runs.size()==1)
	game._show_science_result(0)
	await capture("ml-result-v07")
	game._confirm_science_apply(0)
	await capture("science-confirm-v07")
	game.state.unlock_science_method("dft_teaching")
	game.state.run_science_task("dft_teaching",1)
	for n in range(1000):
		if game.state.science_pending.is_empty(): break
		await create_timer(0.01).timeout
	assert(game.state.science_runs.size()==2)
	game._show_science_result(0)
	await capture("dft-result-v07")
	game._show_research()
	await capture("research-v07")
	game._close_modal()
	game._open_sandbox_editor(game.state.sandbox_from_baseline("water"))
	await capture("sandbox-integrated-v07")
	game._close_modal()
	game.state.close_science()
	print("PASS: integrated v0.7 screens, real research results and editor")
	quit()
