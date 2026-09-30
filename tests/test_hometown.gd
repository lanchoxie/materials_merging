extends SceneTree
## v0.27 Hometown: many buildings, decorations and pedestals share one plot's tile grid.
const State=preload("res://scripts/lab_state.gd")
const Town=preload("res://scripts/island_town.gd")
const Miniatures=preload("res://scripts/river_miniatures.gd")
var checks=0
var failures=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)

func _uid(s, plot: int, kind: String) -> int:
	for item in s.plots[plot].items:
		if item.kind==kind: return int(item.uid)
	return -1

func _initialize() -> void:
	var s=State.new()
	s.coins=50000; s.materials=[10000,10000,10000]
	var home=3
	check(s.plots[home].unlocked and s.plots[home].kind=="empty" and s.plots[home].items.is_empty(),"starter plot is open and holds no courtyard items")
	# Two houses and a canteen on one plot.
	var message=s.town_place(home,"engineer_house",0,0)
	check(s.plots[home].kind=="engineer_house" and s.plots[home].at==[0,0],"first building on an empty plot becomes the main building at the chosen tiles: "+message)
	var single=s.layout.capacity(s.plots[home])
	message=s.town_place(home,"engineer_house",6,0)
	var second=_uid(s,home,"engineer_house")
	check(second>0 and s.town_item(home,second).level==1,"second house is an extra building on the same plot: "+message)
	check(s.layout.kind_capacity(s.plots,home,"engineer_house")==single*2,"houses of one kind on a plot pool their beds")
	var entries=s.layout.buildings(s.plots).filter(func(b): return int(b.plot)==home)
	check(entries.size()==1 and int(entries[0].count)==2,"pooled buildings appear once per plot and kind")
	message=s.town_place(home,"canteen",0,6)
	check(_uid(s,home,"canteen")>0 and s.layout.buildings(s.plots).filter(func(b): return int(b.plot)==home).size()==2,"a different building kind on the same plot is listed separately")
	# Occupancy and bounds are atomic.
	var coins=s.coins
	message=s.town_place(home,"bench",1,1)
	check(message=="这里已经被占用了" and s.coins==coins,"overlapping placement is refused without charge")
	message=s.town_place(home,"bench",10,8)
	check(message.contains("超出地块边界") and s.coins==coins,"the road band on the plot edge stays clear")
	check(s.town_place(home,"street_lamp",11,0).contains("超出"),"last tile row belongs to the edge road")
	# Decorations cost coins, store to the toolbox and come back free.
	message=s.town_place(home,"stone_path",6,6)
	var path=_uid(s,home,"stone_path")
	check(path>0 and s.coins==coins-3,"a path tile costs its listed price: "+message)
	message=s.town_store(home,path)
	check(_uid(s,home,"stone_path")==-1 and int(s.storage.decorations.stone_path)==1,"stored decoration goes to the toolbox")
	coins=s.coins
	message=s.town_place(home,"stone_path",6,6)
	check(s.coins==coins and int(s.storage.decorations.stone_path)==0,"toolbox decoration is placed again for free")
	# Rotation changes the footprint.
	check(s.town_place(home,"bench",8,6,1).contains("已摆放"),"rotated bench fits a narrow column")
	var bench=_uid(s,home,"bench")
	check(Town.item_rect(s.town_item(home,bench)).size==Vector2i(1,2),"rotation swaps the footprint")
	# Locked items explain themselves.
	check(not s.town_locked("fountain").is_empty() and s.town_place(home,"fountain",6,6).contains("交付"),"premium items name their unlock condition")
	# Upgrade and sell an extra building.
	coins=s.coins
	message=s.town_upgrade(home,second)
	check(s.town_item(home,second).level==2 and s.coins<coins and message.contains("外观"),"extra building upgrades and names its new look: "+message)
	check(s.layout.kind_capacity(s.plots,home,"engineer_house")>single*2,"upgrade adds pooled beds")
	var info=s.layout.building_info("engineer_house")
	var refund=int(floor((int(info.cost)+int(info.upgrade_cost))*0.5))
	coins=s.coins
	message=s.town_sell(home,second)
	check(_uid(s,home,"engineer_house")==-1 and s.coins==coins+refund,"selling refunds half of build and upgrade spending: "+message)
	check(Town.tier(1,5)==1 and Town.tier(3,5)==2 and Town.tier(5,5)==3 and Town.tier(1,1)==1,"five levels span wood, brick and glass looks")
	# Main building moves inside its plot.
	check(s.town_move(home,0,home,4,4)=="这里已经被占用了" and s.plots[home].at==[0,0],"main building cannot move onto other items")
	message=s.town_move(home,0,home,1,0)
	check(s.plots[home].at==[1,0],"main building slides to free tiles: "+message)
	s.town_move(home,0,home,0,0)
	# Decorations move across plots; buildings do not.
	var other=5
	message=s.town_move(home,bench,other,0,0,0)
	check(_uid(s,other,"bench")==bench and _uid(s,home,"bench")==-1,"decoration moves to another plot: "+message)
	var canteen=_uid(s,home,"canteen")
	check(s.town_move(home,canteen,other,0,2).contains("本地块"),"buildings keep their plot so residents keep their address")
	# campus_build adds a building to an occupied plot.
	message=s.campus_build(home,"doctor_dorm")
	check(_uid(s,home,"doctor_dorm")>0,"campus build uses free tiles on an occupied plot: "+message)
	# The plaza and legacy whole decorations stay whole.
	check(not s.town_place(s.layout.plaza_index,"bench",0,0).contains("已摆放"),"the welcome plaza stays clear")
	# Reactor plots keep the centre for the reactor.
	var reactor_plot=int(s.reactors[0].plot)
	check(s.town_place(reactor_plot,"bench",4,4)=="这里已经被占用了","reactor keeps its central footprint")
	check(s.town_place(reactor_plot,"street_lamp",0,0).contains("已摆放"),"reactor plot rim takes decorations")
	check(s.town_place(reactor_plot,"engineer_house",0,0).contains("反应炉"),"reactor plots hold no extra buildings")
	s.buy_plot(0)
	s.town_place(0,"bush",5,5)
	check(s.place_reactor(0,"water").contains("8×8") and s.plots[0].kind=="empty","a new reactor needs a clear centre")
	# Pedestal with a mined specimen.
	s.town_place(home,"stone_pedestal",6,8)
	var pedestal=_uid(s,home,"stone_pedestal")
	check(s.town_exhibit(home,pedestal,{"type":"mineral","id":"limestone"}).contains("背包"),"exhibits need a mined specimen")
	s.planet.v2.nature.minerals["limestone"]=1
	message=s.town_exhibit(home,pedestal,{"type":"mineral","id":"limestone"})
	check(s.town_item(home,pedestal).show=={"type":"mineral","id":"limestone"} and int(s.planet.v2.nature.minerals.limestone)==0,"specimen leaves the backpack for the pedestal: "+message)
	check(s.town_exhibit(home,pedestal,{"type":"mineral","id":"bedrock"})!="" and s.town_item(home,pedestal).show.id=="limestone","bedrock is not a specimen")
	# A real river miniature on a second pedestal, built from factory-issued material.
	var v=s.planet.v2; v.active=true
	s.planet.command(s,"join"); s.campus_build(7,"workshop"); s.campus_road(7); s.campus_assign_post(s.campus.people[0].id,"workshop")
	v.field.stock.timber=4; s.planet.command(s,"pack",{"recipe":"field_wall","production_mode":"island"}); s.planet.tick(60,1)
	var ground=v.construction.terrain.ground(Vector2(15,14))
	v.actor={"eye":Vector3(15,ground+3,14),"feet":Vector3(15,ground+1.38,14),"direction":Vector3.DOWN}
	s.planet.command(s,"v2_build",{"kind":"block","recipe":"field_wall"})
	s.planet.command(s,"v2_mini_pack")
	var c=v.construction
	check(c.miniatures.size()==1,"fixture packs a real construction into a miniature")
	s.town_place(home,"turntable",8,8)
	var turntable=_uid(s,home,"turntable")
	var mini_id=str(c.miniatures.keys()[0]) if not c.miniatures.is_empty() else ""
	message=s.town_exhibit(home,turntable,{"type":"mini","id":mini_id})
	check(int(c.miniatures[mini_id].plot)==-2 and s.town_item(home,turntable).show.id==mini_id,"miniature stands on a courtyard pedestal: "+message)
	check(Miniatures.unfold(c,mini_id,{}).contains("收回"),"a displayed miniature cannot be unfolded on the planet")
	# Save round trip and cross-plot validation.
	var path_file="res://saves/test-hometown.json"
	check(s.save_game(path_file).begins_with("已保存"),"hometown saves")
	var loaded=State.new()
	check(loaded.load_game(path_file),"hometown reloads")
	check(loaded.plots[home].items==s.plots[home].items and loaded.plots[home].at==s.plots[home].at,"items, anchors and exhibits survive the round trip")
	check(int(loaded.planet.v2.construction.miniatures[mini_id].plot)==-2,"displayed miniature stays on its pedestal after reload")
	check(loaded.town_place(home,"sunflower",10,10).contains("已摆放") and int(loaded.town_item(home,_uid(loaded,home,"sunflower")).uid)>turntable,"new uids continue after reload")
	var data={"plots":s.plots.duplicate(true),"planet":{"v2":{"construction":{"miniatures":c.miniatures.duplicate(true)}}}}
	check(s._valid_town(data),"current town is valid")
	var twice=data.duplicate(true); twice.plots[home].items.append(twice.plots[home].items[0].duplicate())
	check(not s._valid_town(twice),"duplicate uids are rejected")
	var orphan=data.duplicate(true); orphan.planet.v2.construction.miniatures[mini_id].plot=-1
	check(not s._valid_town(orphan),"an exhibit must own its miniature")
	var bad=s.plots[home].duplicate(true); bad.items.append({"uid":999,"kind":"bench","x":0,"z":0,"rot":0})
	check(not Town.valid_plot(bad,s.layout.building_kinds()),"overlapping saved items are rejected")
	# Taking the miniature back.
	message=s.town_unexhibit(home,turntable)
	check(int(c.miniatures[mini_id].plot)==-1 and s.town_item(home,turntable).show.is_empty(),"unexhibit returns the miniature to the backpack")
	message=s.town_sell(home,pedestal)
	check(int(s.planet.v2.nature.minerals.limestone)==1,"selling a pedestal returns its specimen")
	# Legacy plots pin once to a default anchor.
	var legacy={"x":0,"z":0,"unlocked":true,"kind":"institute","rid":-1,"road":false,"building_level":1,"props":[]}
	s.layout.pin(legacy)
	check(legacy.at==[2,2] and legacy.items==[],"legacy large building keeps its centre")
	var cottage={"x":0,"z":0,"unlocked":true,"kind":"engineer_house","rid":-1,"road":false,"building_level":1,"props":[{"slot":0,"kind":"flower"}]}
	s.layout.pin(cottage)
	check(Town.fits(cottage,"engineer_house",Vector2i(cottage.at[0],cottage.at[1]),0,-1,true).is_empty(),"legacy small building avoids its old props")
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(path_file+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path_file+suffix))
	s.close_science(); loaded.close_science()
	print("PASS: ",checks," hometown checks" if failures.is_empty() else " FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
