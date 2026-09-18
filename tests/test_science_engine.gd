extends SceneTree
const EngineModel=preload("res://scripts/science_pipeline.gd")
var checks:=0
var failures: Array=[]

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var model=EngineModel.new()
	var refs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/materials.json")).templates
	var water: Dictionary=refs.water
	var distorted: Dictionary={"atoms":water.atoms.duplicate(),"positions":water.positions.duplicate(true)}
	distorted.positions[1][0]=1.12
	distorted.positions[2][1]=0.83
	var original: Dictionary=distorted.duplicate(true)
	var local: Dictionary=model.compute("empirical_ho",distorted,water)
	check(local.success,"water harmonic optimization converges")
	check(local.energy<local.initial_energy*0.001,"water energy falls by three orders")
	check(distorted==original,"engine does not mutate input")
	check(local.can_apply,"converged empirical positions are applicable")
	for i in range(1,local.history.size()): check(local.history[i].energy<=local.history[i-1].energy,"line-search energy monotonically decreases")
	var translated: Dictionary=distorted.duplicate(true)
	for p in translated.positions:
		p[0]+=7.0
		p[1]-=3.0
	var invariant: Dictionary=model.compute("empirical_ho",translated,water)
	check(absf(invariant.initial_energy-local.initial_energy)<1.0e-10,"harmonic translation invariance")
	var equilibrium: Dictionary=model.compute("empirical_ho",water,water)
	check(equilibrium.success and equilibrium.energy<1.0e-8,"reference geometry is minimum of defined model")
	check(not model.compute("empirical_ho",distorted,{}).success,"unknown baseline rejected")
	check(not model.compute("empirical_ho",{"atoms":["H","H"],"positions":[[0,0,0],[0,0,0]]},refs.hydrogen).success,"coincident input rejected")
	check(not model.compute("empirical_ho",{"atoms":["H","H"],"positions":[[0,0,0],[INF,0,0]]},refs.hydrogen).success,"nonfinite input rejected")
	check(not model.compute("missing",water,water).success,"unknown method rejected")
	var methane: Dictionary=refs.methane.duplicate(true)
	methane.positions[1][0]+=0.1
	check(model.compute("empirical_hc",methane,refs.methane).success,"methane bond and angle optimization converges")
	var ionic_ref: Dictionary=refs.perovskite
	check(model.compute("empirical_ionic",ionic_ref,ionic_ref).success,"ionic option solves only declared finite reference springs")
	var hydrogen: Dictionary={"atoms":["H","H"],"positions":[[-0.55,0.0,0.0],[0.55,0.0,0.0]]}
	var exported: Dictionary=model.export_external_input(hydrogen)
	check(exported.success and not exported.executed and "xc xpbe96 cpbe96" in exported.content,"external DFT input exported without claiming execution")
	check("-0.5500000000" in exported.content,"external input preserves actual coordinates")
	check(not model.export_external_input(water).success,"external template rejects unsupported charge/species assumptions")
	var ml: Dictionary=model.compute("ml_small",hydrogen,{})
	check(ml.success,"ML fitted model optimization converges")
	check(ml.training_count==61 and ml.validation_count==60,"ML independent training and heldout split")
	check(ml.validation_rmse>0.0 and ml.validation_rmse<0.001,"ML actual measured heldout error")
	var sum2:=0.0
	for v in ml.validation: sum2+=pow(float(v.predicted_energy)-float(v.reference_energy),2.0)
	check(absf(sqrt(sum2/60.0)-float(ml.validation_rmse))<1.0e-12,"RMSE reproducible from full heldout table")
	check(absf(model._distance(ml.positions[0],ml.positions[1])-0.741)<0.001,"ML optimized bond consistent with training target minimum")
	check(ml.energy<ml.initial_energy,"ML predicted energy drops")
	check(not model.compute("ml_small",{"atoms":["H","H"],"positions":[[0,0,0],[2,0,0]]},{}).success,"ML OOD rejection")
	check(not model.compute("ml_small",water,water).success,"ML rejects untrained species")
	for edge in [0.55,1.35]:
		check(model.compute("ml_small",{"atoms":["H","H"],"positions":[[0,0,0],[edge,0,0]]},{}).success,"ML training-domain boundary converges")
	var fit: Dictionary=model._train_ml()
	var test_r:=0.89
	var difference: float=(model._ml_energy(test_r+0.00001,fit)-model._ml_energy(test_r-0.00001,fit))/0.00002
	check(absf(difference-model._ml_derivative(test_r,fit))<0.00001,"learned force matches finite difference energy derivative")
	var start:=Time.get_ticks_msec()
	var ks: Dictionary=model.compute("dft_teaching",refs.hydrogen,{})
	check(ks.success,"one-dimensional EXX KS SCF converges")
	check(ks.model_only and not ks.can_apply,"toy DFT cannot apply molecular geometry or claim real energy")
	check(absf(float(ks.integrated_electrons)-2.0)<1.0e-10,"density integrates to two electrons")
	check(ks.density_residual<1.0e-6 and ks.eigen_residual<1.0e-6,"density and orbital residuals pass")
	check(ks.energy<0.0 and ks.energy>-3.0,"bound two-electron model energy plausible")
	var component_sum:=0.0
	for value in ks.energy_components.values(): component_sum+=float(value)
	check(absf(component_sum-float(ks.energy))<1.0e-12,"total energy equals component sum")
	var symmetric:=true
	for i in range(ks.density.size()):
		symmetric=symmetric and absf(float(ks.density[i][1])-float(ks.density[ks.density.size()-1-i][1]))<1.0e-9
	check(symmetric,"symmetric wells give symmetric density")
	var shifted: Dictionary=refs.hydrogen.duplicate(true)
	for p in shifted.positions:
		p[0]+=3.0
		p[1]+=2.0
	var ks_shift: Dictionary=model.compute("dft_teaching",shifted,{})
	check(absf(ks_shift.energy-ks.energy)<1.0e-10,"one-dimensional separation mapping is translation invariant")
	var far: Dictionary=model.compute("dft_teaching",hydrogen,{})
	check(far.success and absf(float(far.energy)-float(ks.energy))>0.001,"changing nuclear distance recalculates different energy")
	for bohr in [0.81,3.99]:
		check(model.compute("dft_teaching",{"atoms":["H","H"],"positions":[[0,0,0],[bohr*model.BOHR_ANGSTROM,0,0]]},{}).success,"DFT near declared domain edges converges")
	check(not model.compute("dft_teaching",{"atoms":["H","H"],"positions":[[0,0,0],[3,0,0]]},{}).success,"DFT domain overflow rejected")
	var report: Dictionary={"harmonic":local,"ml":ml,"dft":ks,"dft_second":far,"elapsed_dft_ms":Time.get_ticks_msec()-start,"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://artifacts/science-engine-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("SCIENCE_ENGINE_CHECKS=",checks," FAILURES=",failures.size())
	print("HARMONIC ",local.initial_energy," -> ",local.energy," eV in ",local.history.size()," steps")
	print("ML RMSE=",ml.validation_rmse," eV; optimized r=",model._distance(ml.positions[0],ml.positions[1]))
	print("1D EXX KS ENERGY=",ks.energy," Hartree; SCF=",ks.history.size(),"; DENSITY_ERROR=",ks.density_residual,"; ELECTRONS=",ks.integrated_electrons)
	quit(1 if not failures.is_empty() else 0)
