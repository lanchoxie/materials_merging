extends RefCounted
## v0.37 material property model v1 (notes/20-material-model.md). Continuous properties of an
## industry lot from its knobs (composition, processing) through simplified textbook laws; the
## laws, constants and sources live in data/material_model.json. Pure and static.
##
## Property keys: hv (Vickers), gpa (hardness in GPa), tough (0..1, game scale), rho (g/cm³),
## E (GPa), specific (E/ρ), edge (usable cutting hardness in GPa after chipping), plus the
## silicon and glass ones added in stage C (eff, rho_ohm, n, durab).

static var _rules: Dictionary={}

static func rules() -> Dictionary:
	if _rules.is_empty(): _rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/material_model.json"))
	return _rules

static func family(id: String) -> Dictionary:
	return rules().families.get(id,{})

## Knob values for a family, filled with defaults and clamped to the allowed range.
static func knobs(id: String,given: Dictionary={}) -> Dictionary:
	var f=family(id); var out={}
	for k in f.get("knobs",{}):
		var spec: Dictionary=f.knobs[k]
		out[k]=clampf(float(given.get(k,spec.default)),float(spec.min),float(spec.max))
	for k in f.get("inherit",{}):
		out[k]=float(given.get(k,f.get("inherit_default",{}).get(k,0.0)))
	return out

static func _interp(table: Array,x: float) -> float:
	if x<=float(table[0][0]): return float(table[0][1])
	for i in range(1,table.size()):
		if x<=float(table[i][0]):
			var a: Array=table[i-1]; var b: Array=table[i]
			return lerpf(float(a[1]),float(b[1]),(x-float(a[0]))/(float(b[0])-float(a[0])))
	return float(table[-1][1])

static func _smooth(a: float,b: float,x: float) -> float:
	return smoothstep(a,b,x)

## Properties at quality q (lot scatter, 1.0 = the model's prediction).
static func props(id: String,given: Dictionary={},q: float=1.0) -> Dictionary:
	var f=family(id); var k=knobs(id,given); var p={}
	match id:
		"carbon_steel":
			var c=float(k.C); var pearl=minf(c/float(f.eutectoid),1.0); var excess=maxf(0.0,c-float(f.eutectoid))
			p.hv=(lerpf(float(f.ferrite_hv),float(f.pearlite_hv),pearl)+float(f.cementite_hv_per_wt)*excess)*q
			p.tough=clampf(1.0-0.55*pearl-1.2*excess,0.05,1.0)
			var w=c/6.67
			p.rho=1.0/(w/7.69+(1.0-w)/7.874)
		"steel_tool":
			var c=float(k.C); var t=float(k.T); var hq=_interp(f.martensite,c)
			var h: Dictionary=f.hollomon
			var param=(t+273.15)*(float(h.constant)+log(float(h.hours))/log(10.0))
			var relief=_smooth(float(h.start),float(h.end),param)
			var floor_hv=200.0+150.0*minf(c,0.8)
			p.hv=(hq-(hq-floor_hv)*relief)*q
			var brittle=1.0-0.6*_smooth(0.6,1.2,c)*(1.0-relief)
			var tme: Dictionary=f.tme
			var dip=1.0-float(tme.depth)*exp(-pow((t-float(tme.center))/float(tme.width),2.0))
			p.tough=clampf(1.0/(1.0+pow(float(p.hv)/450.0,2.0))*brittle*(1.0+0.6*relief)*dip,0.03,1.0)
			p.rho=7.85
		"tin_bronze":
			var sn=float(k.Sn); var sol=float(f.solubility)
			p.hv=(float(f.base_hv)+float(f.ss_k)*sqrt(minf(sn,sol))+float(f.delta_hv_per_wt)*maxf(0.0,sn-sol))*q
			p.tough=clampf(1.0-0.015*minf(sn,sol)-0.09*maxf(0.0,sn-sol),0.05,1.0)
			var w=sn/100.0
			p.rho=1.0/(w/7.29+(1.0-w)/8.96)
		"duralumin":
			var x=log(float(k.t)/float(f.peak_hours))/float(f.width)
			var rise=exp(-x*x) if x<=0.0 else float(f.overaged_keep)+(1.0-float(f.overaged_keep))*exp(-x*x)
			p.hv=(float(f.ss_hv)+(float(f.peak_hv)-float(f.ss_hv))*rise)*q
			p.tough=clampf(0.9-0.45*rise,0.05,1.0)
			p.rho=float(f.rho)
		"al_li":
			var li=float(k.Li)
			p.rho=float(f.base_rho)*(1.0-float(f.rho_per_wt)*li)
			p.E=float(f.base_E)*(1.0+float(f.E_per_wt)*li)*q
			p.specific=float(p.E)/float(p.rho)
			p.tough=clampf(0.85-0.6*_smooth(float(f.li_limit)-0.2,float(f.li_limit)+0.6,li),0.05,1.0)
		"soda_lime_glass":
			var na=float(k.Na2O); var ca=float(f.cao); var si=100.0-na-ca; var a: Dictionary=f.appen
			p.n=(si*float(a.SiO2)+na*float(a.Na2O)+ca*float(a.CaO))/100.0
			p.T_work=1040.0-25.0*(na-15.0)
			p.durab=clampf((1.0-0.07*(na-12.0))*q,0.05,1.0)
		"n_wafer","solar_panel":
			var w: Dictionary=family("n_wafer"); var mob: Dictionary=w.mobility; var n=pow(10.0,float(k.N))
			p.mu=float(mob.min)+(float(mob.max)-float(mob.min))/(1.0+pow(n/float(mob.nref),float(mob.alpha)))
			p.rho_ohm=1.0/(1.602e-19*n*float(p.mu))
			var x=(float(k.N)-float(w.eff_best))/float(w.eff_width)
			p.eff=maxf(float(w.eff_floor),float(w.eff_peak)*(1.0-0.35*x*x))*q
			if id=="solar_panel":
				p.eff=float(p.eff)*float(f.module_loss)
				p.watt=float(p.eff)*1000.0*float(f.area_m2)
	if p.has("hv"):
		p.gpa=float(p.hv)*0.009807
		# A blade below the chipping toughness loses its edge: usable hardness falls as √(tough/limit).
		p.edge=float(p.gpa)*sqrt(minf(1.0,float(p.tough)/float(f.get("chip_tough",0.25))))
	return p

## Recipe time factor from a knob (glass: more soda melts faster).
static func seconds_factor(id: String,given: Dictionary) -> float:
	var s: Dictionary=family(id).get("seconds_by_knob",{})
	if s.is_empty(): return 1.0
	return _interp(s.at,float(knobs(id,given).get(s.knob,0.0)))

## One number for pricing: weighted property ratios against the default lot.
static func score(id: String,given: Dictionary={},q: float=1.0) -> float:
	var f=family(id); var p=props(id,given,q); var ref=props(id,{},1.0)
	var total=0.0; var weight=0.0
	for key in f.get("score",{}):
		var w=float(f.score[key])
		total+=w*float(p.get(key,0.0))/maxf(float(ref.get(key,1.0)),0.0001); weight+=w
	return total/maxf(weight,0.0001)

static func price_factor(id: String,given: Dictionary,q: float,measured: bool) -> float:
	var r: Dictionary=rules().price
	var f=clampf(pow(maxf(score(id,given,q),0.0),float(r.power)),float(r.min),float(r.max))
	return f*(float(rules().measure.report_bonus) if measured else 1.0)

## Seeded lot scatter in [1−s, 1+s].
static func quality(serial: int) -> float:
	var h=hash([serial,"lot"])
	return 1.0+float(rules().scatter)*(float(h%2001)/1000.0-1.0)

# --- Text -----------------------------------------------------------------------------------
const NAMES={"hv":"硬度","gpa":"硬度","tough":"韧性","rho":"密度","E":"弹性模量","specific":"比刚度","edge":"刃口硬度",
	"eff":"转换效率","rho_ohm":"电阻率","n":"折射率","durab":"耐候性","mu":"电子迁移率","T_work":"工作温度","watt":"组件功率"}

static func value_text(key: String,v: float) -> String:
	match key:
		"hv": return "HV %d" % int(round(v))
		"gpa","edge": return "%.2f GPa" % v
		"tough","durab": return "%d%%" % int(round(v*100))
		"rho": return "%.2f g/cm³" % v
		"E": return "%.0f GPa" % v
		"specific": return "%.1f" % v
		"eff": return "%.1f%%" % (v*100)
		"rho_ohm": return "%s Ω·cm" % sci(v)
		"mu": return "%d cm²/V·s" % int(round(v))
		"T_work": return "%d °C" % int(round(v))
		"watt": return "%d W" % int(round(v))
		"n": return "%.3f" % v
	return String.num(v,3)

## 3.2e-2 style text for values spanning decades.
static func sci(v: float) -> String:
	if v<=0.0: return "0"
	var e=floori(log(v)/log(10.0)); var m=v/pow(10.0,e)
	if e>=-1 and e<=2: return String.num(v,2)
	return "%.1f×10^%d" % [m,e]

## "HV 664 ±53 · 韧性 33%" for a prediction, or the exact values once measured.
static func describe(id: String,given: Dictionary,q: float,measured: bool) -> String:
	var f=family(id); var shown=[]
	var p=props(id,given,q if measured else 1.0); var u=float(rules().model_uncertainty)
	for key in f.get("show",[]):
		var v=float(p.get(key,0.0))
		if measured or key in ["rho","tough","n","T_work","mu","rho_ohm"]: shown.append("%s %s" % [NAMES.get(key,key),value_text(key,v)])
		else: shown.append("%s %s ±%d%%" % [NAMES.get(key,key),value_text(key,v),int(round(u*100))])
	return " · ".join(shown)

static func knob_text(id: String,given: Dictionary) -> String:
	var f=family(id); var k=knobs(id,given); var parts=[]
	for key in k:
		var spec: Dictionary=f.get("knobs",{}).get(key,f.get("inherit_knobs",{}).get(key,{"label":key,"unit":""}))
		var v=float(k[key])
		parts.append("%s %s%s" % [spec.get("label",key),String.num(v,2) if v<10.0 else str(int(round(v))),str(spec.get("unit",""))])
	return "，".join(parts)
