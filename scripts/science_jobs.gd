extends RefCounted
## Actual small educational computations; see docs/SCIENCE-V0.7.md.
const BOND_K: float = 12.0 # artificial eV/Angstrom^2
const ANGLE_K: float = 2.0 # artificial eV/radian^2
const ML_MIN: float = 0.55
const ML_MAX: float = 1.35
const BOHR_ANGSTROM: float = 0.529177210903
var methods: Dictionary = {
	"empirical_ho":{"name":"H–O 弹簧势优化","tier":"0.6","kind":"经验势","requires_scientists":1,"cost":100,"catalysts":0,"elements":["H","O"],"max_atoms":3,"duration":0,"note":"有参考的小分子；键长和键角谐振势，刚度为人工教学参数，不预测反应或真实结合能。"},
	"empirical_hc":{"name":"H–C 弹簧势优化","tier":"0.6","kind":"经验势","requires_scientists":1,"cost":130,"catalysts":1,"elements":["H","C"],"max_atoms":5,"duration":0,"note":"有参考的小分子；实际数值梯度优化，刚度为人工教学参数，不预测真实势能面。"},
	"empirical_ionic":{"name":"离子参考几何弹簧","tier":"0.6","kind":"经验势","requires_scientists":2,"cost":180,"catalysts":1,"elements":["Cs","Pb","Br","Cl","Li","Na","F"],"max_atoms":16,"duration":0,"note":"只优化有限展示单元的参考连线；没有周期边界和长程静电，绝不是晶格能计算。"},
	"ml_small":{"name":"H₂ 机器学习势实验","tier":"0.7","kind":"机器学习势","requires_scientists":2,"cost":260,"catalysts":2,"elements":["H"],"max_atoms":2,"duration":0,"note":"实时拟合人工 Morse 数据的高斯核回归；61 个训练点、60 个独立验证点，仅 H₂ 键长 0.55–1.35 Å。不是 DFT 训练模型。"},
	"dft_teaching":{"name":"一维双阱 Kohn–Sham 实验","tier":"0.7","kind":"一维 DFT 模型","requires_scientists":3,"cost":420,"catalysts":3,"elements":["H"],"max_atoms":2,"duration":0,"note":"将 H₂ 间距映射到一维软库仑双阱，真实求解两电子精确交换 KS 自洽；忽略关联。不是三维氢分子的 DFT，不能预测真实物性。"}
}

func ids() -> Array:
	return methods.keys()

func data(id: String) -> Dictionary:
	return methods.get(id,{}).duplicate(true)

func supports(id: String,symbols: Array) -> bool:
	if not methods.has(id) or symbols.is_empty(): return false
	var info: Dictionary = methods[id]
	if symbols.size()>int(info.max_atoms): return false
	for symbol in symbols:
		if symbol not in info.elements: return false
	if id in ["ml_small","dft_teaching"]: return symbols==["H","H"]
	return symbols.size()>=2

func compute(id: String,specimen: Dictionary,reference: Dictionary={}) -> Dictionary:
	var symbols=specimen.get("atoms",[])
	var input=specimen.get("positions",[])
	if not symbols is Array or not input is Array or not supports(id,symbols): return _error(id,"unsupported","当前组成或原子数不在方法适用范围。")
	if input.size()!=symbols.size(): return _error(id,"invalid_input","坐标数量与原子数不一致。")
	for p in input:
		if not p is Array or p.size()!=3: return _error(id,"invalid_input","坐标必须是三维数组。")
		for value in p:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(float(value))>100.0: return _error(id,"invalid_input","坐标无效或超出教学盒子。")
	for i in range(input.size()):
		for j in range(i):
			if _distance(input[i],input[j])<0.15: return _error(id,"invalid_geometry","原子重叠，请先手动分开。")
	if id=="dft_teaching": return _ks_demo(id,input)
	if id=="ml_small": return _ml_optimize(id,input)
	var invalid:=_validate_reference(symbols,reference)
	if not invalid.is_empty(): return _error(id,"unsupported",invalid)
	return _harmonic_optimize(id,input,reference)

func _error(id: String,status: String,message: String) -> Dictionary:
	return {"success":false,"method":id,"kind":str(methods.get(id,{}).get("kind","")),"status":status,"message":message,"notes":message,"history":[],"positions":[],"density":[],"can_apply":false}

func _base_result(id: String,positions: Array) -> Dictionary:
	return {"success":true,"method":id,"kind":str(methods[id].kind),"status":"converged","message":"计算完成","model":str(methods[id].name),"notes":str(methods[id].note),"positions":positions.duplicate(true),"units":"eV","history":[],"density":[],"can_apply":false}

func export_external_input(specimen: Dictionary) -> Dictionary:
	# A real 3D molecular input, intentionally restricted to neutral singlet H2.
	# Does not execute NWChem or claim any result; no toy-model density is reused.
	if specimen.get("atoms",[]) != ["H","H"]: return {"success":false,"message":"当前外部输入模板只支持中性单重态 H₂。"}
	var positions=specimen.get("positions",[])
	if not positions is Array or positions.size()!=2: return {"success":false,"message":"坐标无效。"}
	for p in positions:
		if not p is Array or p.size()!=3: return {"success":false,"message":"坐标无效。"}
		for v in p:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v))>100.0: return {"success":false,"message":"坐标无效。"}
	if _distance(positions[0],positions[1])<0.15: return {"success":false,"message":"原子重叠。"}
	var body: String="# Atom Atelier: actual 3D H2 input; external calculation NOT executed.\nstart atelier_h2\ncharge 0\ngeometry units angstrom noautosym\n"
	for p in positions: body+="  H %.10f %.10f %.10f\n" % [float(p[0]),float(p[1]),float(p[2])]
	body+="end\nbasis\n  * library cc-pvdz\nend\ndft\n  xc xpbe96 cpbe96\n  mult 1\n  iterations 100\nend\ntask dft energy\n"
	return {"success":true,"filename":"atelier-h2.nw","content":body,"engine":"NWChem","executed":false,"message":"PBE/cc-pVDZ 三维 H₂ 单点输入；需外部 NWChem 执行并检查收敛。"}

func _distance(a: Array,b: Array) -> float:
	var squared:=0.0
	for k in range(3): squared+=pow(float(a[k])-float(b[k]),2.0)
	return sqrt(squared)

func _angle(positions: Array,a: int,b: int,c: int) -> float:
	var dot:=0.0
	for k in range(3): dot+=(float(positions[a][k])-float(positions[b][k]))*(float(positions[c][k])-float(positions[b][k]))
	return acos(clampf(dot/maxf(_distance(positions[a],positions[b])*_distance(positions[c],positions[b]),1.0e-12),-1.0,1.0))

func _validate_reference(symbols: Array,reference: Dictionary) -> String:
	if reference.is_empty() or reference.get("known",true)==false: return "没有审核过的参考几何，不能编造优化目标。"
	if reference.get("atoms",[])!=symbols: return "参考的原子次序与样品不一致。"
	var bonds=reference.get("bonds",[])
	if not bonds is Array or bonds.is_empty(): return "参考中没有键长约束。"
	for bond in bonds:
		if not bond is Array or bond.size()<3: return "参考键格式无效。"
		if int(bond[0])<0 or int(bond[1])<0 or int(bond[0])>=symbols.size() or int(bond[1])>=symbols.size() or int(bond[0])==int(bond[1]): return "参考键索引无效。"
		if not is_finite(float(bond[2])) or float(bond[2])<=0.15: return "参考键长无效。"
	for angle in reference.get("angles",[]):
		if not angle is Array or angle.size()<4: return "参考键角格式无效。"
		for k in range(3):
			if int(angle[k])<0 or int(angle[k])>=symbols.size(): return "参考键角索引无效。"
		if not is_finite(float(angle[3])) or float(angle[3])<=0.0 or float(angle[3])>180.0: return "参考键角无效。"
	return ""

func _harmonic_energy(positions: Array,reference: Dictionary) -> float:
	var energy:=0.0
	for bond in reference.bonds:
		var dr:=_distance(positions[int(bond[0])],positions[int(bond[1])])-float(bond[2])
		energy+=0.5*BOND_K*dr*dr
	for angle in reference.get("angles",[]):
		var dt:=_angle(positions,int(angle[0]),int(angle[1]),int(angle[2]))-deg_to_rad(float(angle[3]))
		energy+=0.5*ANGLE_K*dt*dt
	return energy

func _harmonic_gradient(positions: Array,reference: Dictionary) -> Array:
	var gradient: Array=[]
	var h:=0.0005
	for i in range(positions.size()):
		var row: Array=[]
		for axis in range(3):
			var center:=float(positions[i][axis])
			positions[i][axis]=center+h
			var plus:=_harmonic_energy(positions,reference)
			positions[i][axis]=center-h
			var minus:=_harmonic_energy(positions,reference)
			positions[i][axis]=center
			row.append((plus-minus)/(2.0*h))
		gradient.append(row)
	return gradient

func _harmonic_optimize(id: String,input: Array,reference: Dictionary) -> Dictionary:
	var positions: Array=input.duplicate(true)
	for bond in reference.bonds:
		var ratio:=_distance(positions[int(bond[0])],positions[int(bond[1])])/float(bond[2])
		if ratio<0.5 or ratio>1.5: return _error(id,"out_of_domain","弹簧势只适用于参考键长的 50%–150%；请先把原子移近参考位置。")
	var result:=_base_result(id,positions)
	result["parameters"]={"bond_k_ev_a2":BOND_K,"angle_k_ev_rad2":ANGLE_K,"finite_difference_a":0.0005,"max_steps":160}
	var history: Array=[]
	var converged:=false
	for iteration in range(161):
		var energy:=_harmonic_energy(positions,reference)
		var gradient:=_harmonic_gradient(positions,reference)
		var max_force:=0.0
		for row in gradient:
			max_force=maxf(max_force,sqrt(pow(float(row[0]),2.0)+pow(float(row[1]),2.0)+pow(float(row[2]),2.0)))
		history.append({"step":iteration,"energy":energy,"max_force":max_force})
		if max_force<0.001:
			converged=true
			break
		if iteration==160: break
		var step:=minf(0.035,0.08/maxf(max_force,0.0001))
		var accepted:=false
		for trial in range(16):
			var next: Array=positions.duplicate(true)
			for i in range(next.size()):
				for axis in range(3): next[i][axis]=float(positions[i][axis])-step*float(gradient[i][axis])
			if _harmonic_energy(next,reference)<energy:
				positions=next
				accepted=true
				break
			step*=0.5
		if not accepted: break
	result.success=converged
	result.status="converged" if converged else "not_converged"
	result.message="参考几何弹簧势已收敛" if converged else "达到迭代或步长限制，未收敛；不应用坐标"
	result.positions=positions
	result.history=history
	result["energy"]=_harmonic_energy(positions,reference)
	result["initial_energy"]=float(history[0].energy)
	result["force_units"]="eV/Å"
	result.can_apply=converged
	return result

func _morse(r: float) -> float:
	return 4.5*pow(1.0-exp(-1.9*(r-0.741)),2.0)

func _kernel(a: float,b: float) -> float:
	return exp(-0.5*pow((a-b)/0.09,2.0))

func _linear_solve(matrix: Array,rhs: Array) -> Array:
	var a: Array=matrix.duplicate(true)
	var b: Array=rhs.duplicate()
	var n:=b.size()
	for k in range(n):
		var pivot:=k
		for i in range(k+1,n):
			if absf(float(a[i][k]))>absf(float(a[pivot][k])): pivot=i
		if absf(float(a[pivot][k]))<1.0e-14: return []
		var swap=a[k]
		a[k]=a[pivot]
		a[pivot]=swap
		var scalar:=float(b[k])
		b[k]=b[pivot]
		b[pivot]=scalar
		for i in range(k+1,n):
			var factor:=float(a[i][k])/float(a[k][k])
			for j in range(k,n): a[i][j]=float(a[i][j])-factor*float(a[k][j])
			b[i]=float(b[i])-factor*float(b[k])
	var x: Array=[]
	x.resize(n)
	x.fill(0.0)
	for i in range(n-1,-1,-1):
		var value:=float(b[i])
		for j in range(i+1,n): value-=float(a[i][j])*float(x[j])
		x[i]=value/float(a[i][i])
	return x

func _train_ml() -> Dictionary:
	var centers: Array=[]
	var labels: Array=[]
	for i in range(61):
		var r:=lerpf(ML_MIN,ML_MAX,float(i)/60.0)
		centers.append(r)
		labels.append(_morse(r))
	var matrix: Array=[]
	for i in range(61):
		var row: Array=[]
		for j in range(61): row.append(_kernel(float(centers[i]),float(centers[j]))+(1.0e-7 if i==j else 0.0))
		matrix.append(row)
	var weights:=_linear_solve(matrix,labels)
	if weights.is_empty(): return {}
	var model: Dictionary={"centers":centers,"weights":weights,"train_count":61,"validation_count":60,"source":"人工 Morse 势；不是量子化学或实验训练标签"}
	var error2:=0.0
	var max_error:=0.0
	var validation: Array=[]
	for i in range(60):
		var r:=lerpf(ML_MIN,ML_MAX,(float(i)+0.5)/60.0)
		var predicted:=_ml_energy(r,model)
		var truth:=_morse(r)
		var error:=predicted-truth
		error2+=error*error
		max_error=maxf(max_error,absf(error))
		validation.append({"distance":r,"reference_energy":truth,"predicted_energy":predicted})
	model["rmse_ev"]=sqrt(error2/60.0)
	model["max_error_ev"]=max_error
	model["validation"]=validation
	return model

func _ml_energy(r: float,model: Dictionary) -> float:
	var energy:=0.0
	for i in range(model.centers.size()): energy+=float(model.weights[i])*_kernel(r,float(model.centers[i]))
	return energy

func _ml_derivative(r: float,model: Dictionary) -> float:
	var gradient:=0.0
	for i in range(model.centers.size()):
		var center:=float(model.centers[i])
		gradient+=float(model.weights[i])*_kernel(r,center)*(-(r-center)/(0.09*0.09))
	return gradient

func _ml_optimize(id: String,input: Array) -> Dictionary:
	var r:=_distance(input[0],input[1])
	if r<ML_MIN or r>ML_MAX: return _error(id,"out_of_domain","H₂ 键长超出训练域 0.55–1.35 Å；拒绝外推。")
	var model:=_train_ml()
	if model.is_empty(): return _error(id,"training_failed","核回归线性方程求解失败。")
	var result:=_base_result(id,input)
	var history: Array=[]
	var converged:=false
	for iteration in range(101):
		var energy:=_ml_energy(r,model)
		var derivative:=_ml_derivative(r,model)
		history.append({"step":iteration,"energy":energy,"max_force":absf(derivative),"distance":r})
		if absf(derivative)<0.001:
			converged=true
			break
		if iteration==100: break
		var step:=0.025
		var accepted:=false
		for trial in range(16):
			var next:=clampf(r-step*derivative,ML_MIN,ML_MAX)
			if _ml_energy(next,model)<energy:
				r=next
				accepted=true
				break
			step*=0.5
		if not accepted: break
	var initial_r:=_distance(input[0],input[1])
	var positions: Array=[[],[]]
	for k in range(3):
		var midpoint: float=0.5*(float(input[0][k])+float(input[1][k]))
		var half: float=0.5*r*(float(input[1][k])-float(input[0][k]))/initial_r
		positions[0].append(midpoint-half)
		positions[1].append(midpoint+half)
	result.positions=positions
	result.history=history
	result["energy"]=_ml_energy(r,model)
	result["initial_energy"]=float(history[0].energy)
	result["validation_rmse"]=model.rmse_ev
	result["validation_max_error"]=model.max_error_ev
	result["validation"]=model.validation
	result["training_count"]=model.train_count
	result["validation_count"]=model.validation_count
	result["training_source"]=model.source
	result["domain_angstrom"]=[ML_MIN,ML_MAX]
	result["force_units"]="eV/Å"
	result.success=converged
	result.can_apply=converged
	result.status="converged" if converged else "not_converged"
	result.message="核回归训练、独立验证和局部优化完成" if converged else "模型已训练，但局部优化未收敛"
	return result

func _normalize_orbital(phi: PackedFloat64Array,dx: float) -> PackedFloat64Array:
	var norm:=0.0
	for value in phi: norm+=value*value*dx
	if norm<=0.0: return phi
	var factor:=1.0/sqrt(norm)
	for i in range(phi.size()): phi[i]*=factor
	return phi

func _ground_orbital(potential: PackedFloat64Array,dx: float,seed: PackedFloat64Array) -> Dictionary:
	var n:=potential.size()
	var off:=-0.5/(dx*dx)
	var shift:=potential[0]-1.0
	for value in potential: shift=minf(shift,value-1.0)
	var phi:=_normalize_orbital(seed.duplicate(),dx)
	var diagonal:=PackedFloat64Array()
	diagonal.resize(n)
	var c:=PackedFloat64Array()
	var d:=PackedFloat64Array()
	c.resize(n)
	d.resize(n)
	for i in range(n): diagonal[i]=1.0/(dx*dx)+potential[i]-shift
	for iteration in range(160):
		c[0]=off/diagonal[0]
		d[0]=phi[0]/diagonal[0]
		for i in range(1,n):
			var denominator:=diagonal[i]-off*c[i-1]
			c[i]=off/denominator
			d[i]=(phi[i]-off*d[i-1])/denominator
		var next:=PackedFloat64Array()
		next.resize(n)
		next[n-1]=d[n-1]
		for i in range(n-2,-1,-1): next[i]=d[i]-c[i]*next[i+1]
		next=_normalize_orbital(next,dx)
		var delta:=0.0
		for i in range(n): delta+=pow(next[i]-phi[i],2.0)*dx
		phi=next
		if sqrt(delta)<1.0e-9: break
	var eigenvalue:=0.0
	var hphi:=PackedFloat64Array()
	hphi.resize(n)
	for i in range(n):
		hphi[i]=(1.0/(dx*dx)+potential[i])*phi[i]
		if i>0: hphi[i]+=off*phi[i-1]
		if i<n-1: hphi[i]+=off*phi[i+1]
		eigenvalue+=phi[i]*hphi[i]*dx
	var residual:=0.0
	for i in range(n): residual+=pow(hphi[i]-eigenvalue*phi[i],2.0)*dx
	return {"orbital":phi,"eigenvalue":eigenvalue,"residual":sqrt(residual)}

func _hartree(density: PackedFloat64Array,kernel: Array,dx: float) -> PackedFloat64Array:
	var potential:=PackedFloat64Array()
	potential.resize(density.size())
	for i in range(density.size()):
		var value:=0.0
		for j in range(density.size()): value+=density[j]*float(kernel[i][j])*dx
		potential[i]=value
	return potential

func _ks_demo(id: String,input: Array) -> Dictionary:
	var separation:=_distance(input[0],input[1])/BOHR_ANGSTROM
	if separation<0.8 or separation>4.0: return _error(id,"out_of_domain","一维双阱只接受 0.8–4.0 bohr（约 0.423–2.117 Å）核间距。")
	var n:=119
	var dx:=0.2
	var external:=PackedFloat64Array()
	var density:=PackedFloat64Array()
	var phi:=PackedFloat64Array()
	var xgrid:=PackedFloat64Array()
	external.resize(n)
	density.resize(n)
	phi.resize(n)
	xgrid.resize(n)
	var kernel: Array=[]
	for i in range(n):
		var x:=-12.0+dx*float(i+1)
		xgrid[i]=x
		external[i]=-1.0/sqrt(pow(x-separation*0.5,2.0)+1.0)-1.0/sqrt(pow(x+separation*0.5,2.0)+1.0)
		phi[i]=exp(-0.35*x*x)
		var row:=PackedFloat64Array()
		row.resize(n)
		for j in range(n): row[j]=1.0/sqrt(pow(dx*float(i-j),2.0)+1.0)
		kernel.append(row)
	phi=_normalize_orbital(phi,dx)
	for i in range(n): density[i]=2.0*phi[i]*phi[i]
	var history: Array=[]
	var energy:=0.0
	var previous_energy:=1.0e12
	var converged:=false
	var eigen_residual:=0.0
	var density_error:=0.0
	var components: Dictionary={}
	for iteration in range(100):
		var hartree:=_hartree(density,kernel,dx)
		var effective:=external.duplicate()
		for i in range(n): effective[i]+=0.5*hartree[i] # exact exchange for 2e singlet: vx=-vH/2
		var orbital:=_ground_orbital(effective,dx,phi)
		phi=orbital.orbital
		eigen_residual=float(orbital.residual)
		var output:=PackedFloat64Array()
		output.resize(n)
		density_error=0.0
		for i in range(n):
			output[i]=2.0*phi[i]*phi[i]
			density_error+=absf(output[i]-density[i])*dx
		var output_hartree:=_hartree(output,kernel,dx)
		var kinetic:=0.0
		var vext:=0.0
		var hartree_energy:=0.0
		for i in range(n):
			var left:=phi[i-1] if i>0 else 0.0
			var right:=phi[i+1] if i<n-1 else 0.0
			kinetic+=-phi[i]*(left-2.0*phi[i]+right)/dx
			vext+=output[i]*external[i]*dx
			hartree_energy+=0.5*output[i]*output_hartree[i]*dx
		var nuclear:=1.0/sqrt(separation*separation+1.0)
		energy=kinetic+vext+0.5*hartree_energy+nuclear
		components={"kinetic":kinetic,"external":vext,"hartree":hartree_energy,"exchange":-0.5*hartree_energy,"correlation":0.0,"nuclear":nuclear}
		history.append({"step":iteration+1,"energy":energy,"density_residual":density_error,"energy_change":absf(energy-previous_energy) if iteration>0 else 0.0,"eigen_residual":eigen_residual})
		if iteration>1 and density_error<1.0e-6 and absf(energy-previous_energy)<1.0e-8 and eigen_residual<1.0e-6:
			converged=true
			density=output
			break
		for i in range(n): density[i]=0.65*density[i]+0.35*output[i]
		previous_energy=energy
	var result:=_base_result(id,input)
	result.success=converged
	result.status="converged" if converged else "not_converged"
	result.message="一维模型自洽收敛；不代表真实三维 H₂ 能量" if converged else "一维模型未收敛，不作为有效结果"
	result.units="Hartree（仅一维模型）"
	result["energy"]=energy
	result["energy_components"]=components
	result.history=history
	result["grid_spacing_bohr"]=dx
	result["box_bohr"]=[-12.0,12.0]
	result["nuclear_separation_bohr"]=separation
	result["electrons"]=2
	result["exchange_functional"]="2-electron singlet exact exchange, Ex=-EH/2; Ec=0"
	result["density_residual"]=density_error
	result["eigen_residual"]=eigen_residual
	result["model_only"]=true
	result["density_units"]="electrons/bohr"
	var points: Array=[]
	var electron_count:=0.0
	for i in range(n):
		points.append([xgrid[i],density[i]])
		electron_count+=density[i]*dx
	result.density=points
	result["integrated_electrons"]=electron_count
	return result
