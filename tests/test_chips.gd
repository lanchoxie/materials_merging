extends SceneTree
## v0.38 "Chips & Light": lithography laws (Rayleigh limit, Stapper defects, Poisson yield, Dennard
## clock), perovskite LED colour by alloy bowing and brightness by V(λ), the chip fab and packaging
## plant chain, factory control boards, the headlamp and its save.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Model=preload("res://scripts/material_model.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	# --- Laws.
	var coarse=Model.props("lithography",{"L":1.5}); var fine=Model.props("lithography",{"L":0.36})
	check(absf(float(coarse.transistors)-111111.0)<1.0,"1.5 µm on 25 mm² holds about 11 万 transistors (100 F² per cell)")
	check(float(fine.transistors)>float(coarse.transistors) and float(fine["yield"])<0.2 and float(coarse["yield"])>0.85,"finer lines pack more but print and yield worse near the Rayleigh limit")
	check(float(Model.props("lithography",{"L":0.5}).clock)>float(coarse.clock),"Dennard: finer lines clock faster")
	var best=[0.0,0.0]
	for l in [0.36,0.4,0.45,0.5,0.6,0.8,1.0,1.5,3.0,5.0]:
		var good=float(Model.props("lithography",{"L":l}).good)
		if good>best[0]: best=[good,l]
	check(best[1]>0.36 and best[1]<1.0,"good transistors peak at an interior linewidth (%.2f µm)" % best[1])
	var br=Model.props("perovskite_led",{"x":0.0}); var cl=Model.props("perovskite_led",{"x":1.0}); var mid=Model.props("perovskite_led",{"x":0.5})
	check(absf(float(br.wavelength)-521.0)<2.0 and absf(float(cl.wavelength)-410.5)<2.0,"CsPbBr₃ glows green at ~521 nm and CsPbCl₃ violet at ~410 nm")
	check(float(mid.eg)<0.5*(float(br.eg)+float(cl.eg)),"bowing pulls the mixed gap below the straight line")
	check(float(br.efficacy)>50.0*float(cl.efficacy),"green is far brighter to the eye than violet (V(λ) and EQE)")
	check(Model.color_name(521)=="绿" and Model.color_name(410)=="紫" and Model.wavelength_color(521).g>0.9,"wavelengths have colour names and swatches")
	check(absf(Model.luminosity(555)-1.0)<0.02 and Model.luminosity(410)<0.01,"V(λ) peaks at 555 nm")
	# --- Factory chain.
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); s.coins=900000; ind.plots=10; ind.solar=[0.3,0.3,0.3,0.3,0.3,0.3]
	check(ind.build(s,0,"polymer_works").contains("建成") and ind.build(s,1,"chip_fab").contains("建成") and ind.build(s,2,"packaging_plant").contains("建成") and ind.build(s,3,"metal_works").contains("建成"),"chip fab and packaging plant are built")
	preload("res://scripts/test_mode.gd").chip_kit(s)
	check(ind.quote(s,0,"photoresist").ready,"photoresist unlocks after making phenol")
	ind.start(s,0,"photoresist"); ind.start(s,0,"epoxy"); ind.tick(s,200.0)
	ind.start(s,0,"photoresist"); ind.start(s,0,"epoxy"); ind.tick(s,200.0)
	check(int(ind.items.get("photoresist",0))>=3 and int(ind.items.get("epoxy",0))>=3,"photoresist and epoxy come out")
	ind.set_knob("logic_chip","L",0.5)
	check(ind.start(s,1,"logic_chip").contains("线宽 0.5"),"the chip job remembers its linewidth")
	ind.tick(s,200.0)
	ind.start(s,1,"power_diode")
	ind.set_knob("led_chip","x",0.0)
	check(not ind.inputs("led_chip").has("el:Cl") and int(ind.inputs("led_chip")["el:Br"])==3,"pure bromide LEDs use only Br")
	ind.set_knob("led_chip","x",1.0)
	check(not ind.inputs("led_chip").has("el:Br") and int(ind.inputs("led_chip")["el:Cl"])==3,"pure chloride LEDs use only Cl")
	ind.set_knob("led_chip","x",0.0)
	ind.tick(s,200.0)
	check(ind.start(s,1,"led_chip").begins_with("已投料"),"LED chips start")
	ind.tick(s,200.0)
	check(int(ind.items.get("logic_chip",0))==4 and int(ind.items.get("power_diode",0))==6 and int(ind.items.get("led_chip",0))==4,"chips, diodes and LEDs come out")
	ind.set_knob("led_chip","x",0.6); ind.start(s,1,"led_chip"); ind.tick(s,200.0)
	check(ind.lots_of("led_chip").size()==2,"a second, bluer LED lot is made")
	check(ind.start(s,2,"fr4_board").begins_with("已投料") and ind.start(s,2,"ic_package").begins_with("已投料"),"boards and IC packaging start")
	ind.tick(s,200.0)
	var ic_lot=ind.lots_of("ic")[0]
	check(absf(float(ic_lot.k.L)-0.5)<0.01,"a packaged IC inherits its die's linewidth")
	check(ind.start(s,2,"control_board").begins_with("已投料") and ind.start(s,2,"headlamp").begins_with("已投料"),"control board and headlamp start")
	ind.tick(s,200.0)
	check(int(ind.items.get("control_board",0))==1 and int(ind.items.get("headlamp",0))==1,"a control board and a headlamp come out")
	# --- Automation.
	var before=ind.speed(ind.buildings["3"],3)
	check(ind.install_board(3).contains("+25%") and absf(ind.speed(ind.buildings["3"],3)-before*1.25)<0.0001,"a control board speeds a factory up by 25 %")
	check(ind.install_board(3).contains("已经") or ind.install_board(3).contains("需要"),"one board per factory")
	# --- Headlamp.
	check(ind.equip_lamp("headlamp").contains("绿光"),"the headlamp is built from the best (green) LED lot and shines its colour")
	check(int(ind.items.led_chip)==6 and ind.lots_of("led_chip").any(func(l): return is_equal_approx(float(l.k.x),0.6) and int(l.n)==4),"the bluer LEDs stay in stock")
	var spec=ind.lamp_spec()
	check(float(spec.range)>15.0 and Color(spec.color).g>0.9,"a green perovskite lamp reaches far (%.0f m)" % float(spec.range))
	ind.build(s,4,"trade_hub")
	check(ind.sell(s,"headlamp",1).contains("不能卖"),"the worn headlamp cannot be sold")
	ind.items["headlamp"]=2; ind.lots.headlamp.append({"n":1,"k":{"x":1.0},"q":1.0,"m":false})
	check(ind.lamp_spec().range==spec.range,"the brightest lot is the one worn")
	var data=JSON.parse_string(JSON.stringify(ind.serialize()))
	var again=Industry.new()
	check(again.restore(data) and again.lamp=="headlamp" and again.buildings["3"].get("board",false),"lamp and control board survive a save")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.lamp="pe"
	check(not Industry.new().restore(bad),"a non-lamp item cannot be worn as a lamp")
	bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.buildings["1"]["board"]="yes"
	check(not Industry.new().restore(bad),"a malformed control board flag is rejected")
	if failures.is_empty(): print("CHIPS OK (%d checks)" % checks); quit(0)
	else: print("CHIPS FAILED: ",failures); quit(1)
