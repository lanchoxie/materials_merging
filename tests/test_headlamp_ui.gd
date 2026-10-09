extends SceneTree
## v0.38 headlamp on Earth: worn and dark → the spotlight is on, in the LED's colour and reach;
## by day or without a lamp it stays off; a storm sky turns it on.
const Main=preload("res://scripts/main.gd")
const Industry=preload("res://scripts/industry.gd")
var checks=0
var failures=[]
var game

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(120).timeout.connect(func(): push_error("headlamp ui timeout"); quit(2))

func frames(n: int) -> void:
	for i in range(n): await process_frame

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry; var v=s.planet.v2
	await frames(5)
	ind.items["headlamp"]=1; ind.lots["headlamp"]=[{"n":1,"k":{"x":0.0},"q":1.0,"m":false}]
	ind.equip_lamp("headlamp")
	v.world.elapsed=60.0*3   # midnight
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); await frames(40)
	panel._sync(); await frames(5)
	var view=panel.view
	check(view.lamp_on and view.lamp.visible,"at night the worn headlamp lights up")
	check(view.lamp.light_color.g>0.9 and view.lamp.light_color.b<0.3 and absf(view.lamp.spot_range-float(ind.lamp_spec().range))<0.01,"its light is the green of a CsPbBr₃ LED, with the modelled reach")
	ind.lamp=""; panel._sync(); await frames(3)
	check(not view.lamp_on,"without a lamp nothing lights up")
	ind.lamp="headlamp"; v.world.elapsed=60.0*3+30.0; panel._sync(); await frames(3)
	check(not view.lamp_on,"at noon the lamp stays off")
	view.weather={"dark":1.0,"rain":1.0,"haze":0.0}; view.weather_now=Vector3(1,1,0); await frames(2)
	check(view.lamp_needed(1.0),"a storm sky turns it on in daylight")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("HEADLAMP UI OK (%d checks)" % checks); quit(0)
	else: print("HEADLAMP UI FAILED: ",failures); quit(1)
