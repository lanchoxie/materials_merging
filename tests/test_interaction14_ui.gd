extends "res://tests/test_ranch13_ui.gd"

func tap(control) -> void:
	var at=control.get_global_rect().get_center()
	await game._test_touch(at,true); await game._test_touch(at,false); await process_frame

func select_item(bag,id: String) -> void:
	for slot in bag.grid.get_children():
		if slot.item.get("id")==id:
			await tap(slot); await process_frame; return
	check(false,"item visible in backpack: "+id)

func point_at(panel,point: Vector3) -> void:
	var d=point-panel.view.walker.eye()
	panel.view.walker.yaw=atan2(-d.x,-d.z); panel.view.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length())
	panel.view._camera(0); panel._aim()

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; var v=s.planet.v2; var t=v.construction.terrain
	game._show_planet_v2(); await process_frame; var panel=game.modal; v.world.paused=true; panel._enter()
	var person={"id":1,"name":"禾苗","health":1.0,"hunger":0.1,"x":30.0,"z":30.0,"task":"安家"}
	v.settlement.era=1; v.settlement.people=[person]
	look(panel,Vector2(30,32),Vector3(30,t.ground(Vector2(30,30))+1,30)); panel._sync(); await process_frame; await process_frame
	panel._equip_item("tool:collect"); panel._aim()
	check(panel.encounter_hud.target.get("entity",{}).get("type")=="resident","crosshair targets a visible resident with default gloves")
	check(panel.aim_label.text.contains("左键/F 攻击") and panel.action_button.text=="查看 E" and panel.attack_button.visible,"attack and inspect are discoverable separate actions")
	await key(KEY_E); check(panel.show_details and person.health==1,"E inspects without attacking")
	panel._toggle_details(); await process_frame
	var at=panel.explore_input.global_position+panel.explore_input.size*0.5
	await game._test_pointer(at,true); await game._test_pointer(at,false); await process_frame
	check(is_equal_approx(person.health,0.76) and not panel.show_details,"left click with default gloves hits exactly once without opening details")
	check(panel.encounter_hud.hit_flash>0 and v.combat.records["resident:1"].anger>0,"successful hit gives crosshair feedback, health and anger")
	var hp=person.health; await key(KEY_F)
	check(person.health==hp,"immediate F cannot bypass attack cooldown")
	await create_timer(0.55).timeout; await tap(panel.attack_button)
	check(is_equal_approx(person.health,hp-0.24) and v.world.paused,"mobile attack works after cooldown even while ecology is paused")
	await capture("interaction14-attack")
	# Visible interpolation differs from the simulation location; target what is drawn.
	var node=panel.view.settlement_view.members[1]; node.position.x+=0.65; node.set_process(false)
	panel.view.settlement_view.set_process(false)
	var body: AABB=node.get_child(0).global_transform*node.get_child(0).mesh.get_aabb()
	point_at(panel,body.get_center())
	check(panel.encounter_hud.target.get("entity",{}).get("key")=="resident:1","aim follows the rendered moving body rather than its next simulation position")
	await create_timer(0.5).timeout; await key(KEY_F)
	check(person.health<hp-0.24,"F damages the visible interpolated resident")
	panel.view.settlement_view.set_process(true)
	# No hit through a constructed wall, even with a cached visible body bound.
	var barrier={"x":30,"y":int(t.ground(Vector2(30,31)))+1,"z":31,"kind":"block","source":"88"}
	var barrier_key=v.construction.key(v.construction.cell(barrier))
	v.construction.blocks[barrier_key]=barrier
	look(panel,Vector2(30,32),Vector3(30,t.ground(Vector2(30,30))+1,30)); hp=person.health
	await create_timer(0.5).timeout; await key(KEY_F)
	check(person.health==hp and not panel.encounter_hud.target.has("entity"),"a solid wall prevents attacks on an occluded visible entity")
	v.construction.blocks.erase(barrier_key); v.construction.revision+=1
	# Visitors and wild animals use a different renderer from residents.
	v.settlement.people=[]
	var site=v.population._site("interaction-test",Vector2(30,30),false,false)
	site.animals=[]; site.visitors=[{"id":901,"name":"阿舟","born":0,"state":"休息","x":0.0,"z":0.0}]
	v.population.sites[site.id]=site; panel._sync(); await process_frame; await process_frame; panel._aim()
	check(panel.encounter_hud.target.get("entity",{}).get("type")=="visitor","a visiting NPC is selected from its rendered body")
	await key(KEY_F)
	check(is_equal_approx(site.visitors[0].get("health",1),0.76),"visiting NPC receives F attack without an equipped weapon")
	site.visitors=[]; site.animals=[{"id":902,"species":"woodland_boar","health":1.0,"age":2.0,"x":0.0,"z":0.0}]
	panel._sync(); await create_timer(0.5).timeout
	point_at(panel,Vector3(30,t.ground(Vector2(30,30))+0.35,30)); await tap(panel.attack_button)
	check(is_equal_approx(site.animals[0].health,0.76) and v.combat.records.get("wild:interaction-test:902",{}).get("mode")=="反击","wild boar receives mobile hit and enters retaliation")
	var player_hp=v.combat.player_health; v.world.paused=false; await create_timer(2.0).timeout
	check(v.combat.player_health<player_hp,"unpaused wild boar approaches and hits the player")
	v.world.paused=true; v.population.sites.erase(site.id); panel._sync()
	# The regional animal mesh is scaled for age, and its full rotated body is aimable.
	var animal=v.world.regions.meadow.animals[0]; animal.age=2; animal.x=0; animal.z=0
	var center: Vector3=t.CENTERS.meadow
	look(panel,Vector2(center.x,center.z+2.2),center+Vector3(0,t.ground(Vector2(center.x,center.z))+0.35,0)); panel._sync(); await create_timer(0.5).timeout; panel._aim()
	check(panel.encounter_hud.target.get("entity",{}).get("key")=="animal:meadow:"+str(int(animal.id)),"crosshair selects the regional deer")
	hp=animal.health; await tap(panel.attack_button)
	check(is_equal_approx(animal.health,hp-0.24),"mobile attack damages an animal once")
	await create_timer(0.5).timeout
	look(panel,Vector2(center.x,center.z+4.3),center+Vector3(0,t.ground(Vector2(center.x,center.z))+0.35,0)); hp=animal.health; await key(KEY_F)
	check(animal.health==hp and panel.message.contains("靠近"),"out-of-reach attacks are rejected with useful feedback")
	# Building workflow: touch-select owned components, equip, see preview and place.
	s.planet.products.append({"id":91,"recipe":"field_planter","recipe_version":1,"source_batch":"interaction-ui"})
	look(panel,Vector2(15,17),Vector3(15,t.ground(Vector2(15,14)),14)); panel._sync(); panel._open_backpack(); await process_frame; await process_frame
	var bag=panel.backpack; await select_item(bag,"recipe:field_planter"); var take=button(bag,"拿在手上")
	check(take!=null and bag.detail_scroll.get_global_rect().encloses(take.get_global_rect()),"primary equip button is visible without scrolling item details")
	await capture("interaction14-place-help"); var products=s.planet.products.duplicate(true); await tap(take)
	check(not is_instance_valid(panel.backpack) and panel.build_mode=="planter" and s.planet.products==products,"taking a component closes backpack without using materials")
	panel._aim(); await process_frame
	check(panel.view.construction_view.ghost.visible and panel.view.construction_view.ghost_material.albedo_color.g>0.9 and panel.aim_label.text.contains("×2"),"green preview displays the selected item and real remaining count")
	await capture("interaction14-placement"); await tap(panel.action_button)
	check(v.construction.count_kind("planter")==1 and v.construction.available("planter",s.planet.products,"field_planter")==1,"touch placement consumes exactly one owned component")
	var k=v.construction.blocks.keys()[0]; var b=v.construction.blocks[k]
	point_at(panel,panel.view.walker.eye()+Vector3(0.3,-1.3,0)); panel._aim()
	var remaining=v.construction.available("planter",s.planet.products,"field_planter")
	await tap(panel.action_button)
	check(v.construction.count_kind("planter")==1 and v.construction.available("planter",s.planet.products,"field_planter")==remaining,"invalid placement does not debit materials")
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,4)
	panel._open_backpack(); await process_frame; await process_frame; bag=panel.backpack
	var component_tab=button(bag,"构件"); var tree_tab=button(bag,"树种")
	check(component_tab.get_global_rect().end.y<bag.scroll.get_global_rect().position.y and tree_tab.get_global_rect().end.y<bag.scroll.get_global_rect().position.y,"all backpack categories remain above the item grid")
	await select_item(bag,"seed:grain"); var seeds=v.world.seeds; await tap(button(bag,"拿在手上"))
	check(not is_instance_valid(panel.backpack) and v.world.seeds==seeds,"taking seeds does not plant invisibly behind inventory")
	point_at(panel,Vector3(b.x,b.y+0.6,b.z)); await tap(panel.action_button)
	check(v.field.gardens.has(k) and v.world.seeds==seeds-1,"equipped seeds plant the aimed physical box")
	panel._open_backpack(); await process_frame; await process_frame; bag=panel.backpack
	await select_item(bag,"sample:"+water.id); var quantity=s.storage.batch(water.id).quantity; await tap(button(bag,"拿在手上"))
	check(not is_instance_valid(panel.backpack) and s.storage.batch(water.id).quantity==quantity,"water's primary action equips without region-wide deployment")
	point_at(panel,Vector3(b.x,b.y+0.6,b.z)); await tap(panel.action_button)
	check(s.storage.batch(water.id).quantity==quantity-1 and v.field.gardens[k].moisture>0.8,"using held water debits one batch and waters this planter")
	panel._open_backpack(); await process_frame; hp=animal.health; await key(KEY_F); await key(KEY_E)
	check(animal.health==hp and s.storage.batch(water.id).quantity==quantity-1,"backpack intercepts attacks and use input")
	panel._close_backpack(); panel.show_details=true; panel._exploration_layout(); await process_frame
	check(panel.play_bar.get_global_rect().end.x<=panel.viewport_box.get_global_rect().end.x and panel.attack_button.get_global_rect().end.x<=panel.viewport_box.get_global_rect().end.x,"all action buttons fit when the world panel is open")
	game.queue_free(); await process_frame
	print("INTERACTION14 UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
