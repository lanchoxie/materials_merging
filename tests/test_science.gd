extends SceneTree
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures: Array=[]
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	_run.call_deferred()
func _wait_job(s) -> void:
	for n in range(3000):
		s.poll_science()
		if s.science_pending.is_empty(): return
		await create_timer(0.01).timeout
	assert(false,"threaded computation timed out")
func _run() -> void:
	var s=State.new()
	s.engineers=3
	s.coins=10000
	s.upgrades=20
	s.campus.setup(3,3)
	s._sync_campus_counts()
	check(s.scientists==3,"scientist progression")
	s.change_template(0,"hydrogen")
	preload("res://tests/fixtures_v09.gd").install(s)
	s.reactors[0].positions[1][0]+=0.20
	s.unlock_science_method("ml_small")
	s.unlock_science_method("dft_teaching")
	var before=s.coins
	var original=s.reactors[0].positions.duplicate(true)
	s.run_science_task("ml_small",0)
	await _wait_job(s)
	var result: Dictionary=s.science_runs[0].result
	check(result.success and result.validation_count==60,"ML fitted and independently validated")
	check(s.coins==before and s.reactors[0].positions==original,"ML computed without automatic charge or apply")
	s.apply_science_result(0)
	check(s.coins==before-12 and s.reactors[0].positions!=original,"confirmed ML result applies and charges one fee")
	before=s.coins
	s.apply_science_result(0)
	check(s.coins==before,"old result cannot charge twice")
	s.run_science_task("dft_teaching",0)
	await _wait_job(s)
	result=s.science_runs[0].result
	check(result.success and result.history.size()>1 and result.density.size()>50,"DFT completed actual SCF and density")
	check(not result.can_apply and absf(float(result.integrated_electrons)-2)<0.0001,"1D result has two electrons and cannot apply")
	check(s.apply_science_result(0).contains("不能") and s.coins==before,"DFT never overwrites 3D atoms")
	check(s.save_game("res://saves/science-integration-test.json").contains("已保存"),"persist full scientific results")
	var restored=State.new()
	check(restored.load_game("res://saves/science-integration-test.json") and restored.science_runs.size()==2,"full density and training metrics restored")
	var corrupt=s.science_runs[0].duplicate(true)
	corrupt.result.can_apply=true
	check(not s._valid_science_record(corrupt),"DFT apply flag rejected in save validation")
	s.close_science()
	print("PASS: %d science integration checks" % checks)
	quit(0 if failures.is_empty() else 1)
