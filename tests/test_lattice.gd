extends SceneTree
## v0.52 (user: 构建复杂晶体的时候需要可以知道一些晶格参数，然后显示周期性位点，包括原子是否放置在
## 周期性边界条件上): the crystal workbench — cell angles, the lattice matrix, fractional
## coordinates, periodic sites with their share of an atom, and snap-to-boundary.
const Sandbox=preload("res://scripts/structure_sandbox.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	var elements: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/elements.json")).elements
	var sb=Sandbox.new(elements)
	# --- A crystal baseline opens as a crystal, with its cell and site weights.
	var perov=sb.from_baseline("perovskite","测试钙钛矿")
	check(not perov.is_empty() and perov.get("periodic",false),"钙钛矿 opens with PBC on")
	check(perov.get("cell",[])==[6.3,6.3,6.3],"and carries its 6.3 Å cell")
	check(perov.get("occupancies",[]).size()==15,"and its 15 site occupancies")
	check(sb.validate(perov),"the structure validates")
	var plain=sb.from_baseline("water","水")
	check(not plain.has("cell") or not plain.get("periodic",false),"a molecule baseline stays a molecule")
	# --- Lattice basis: a = 6.3 x̂, and 90/90/90 is the old orthogonal cell.
	var m=sb.lattice([6.3,6.3,6.3],[90.0,90.0,90.0])
	check((m*Vector3(1,0,0)).is_equal_approx(Vector3(6.3,0,0)),"a lies along x")
	check((m*Vector3(0,1,0)).is_equal_approx(Vector3(0,6.3,0)),"b lies along y at 90°")
	check(absf(absf(m.determinant())-6.3*6.3*6.3)<0.01,"the orthogonal cell volume is abc (%.1f Å³)" % absf(m.determinant()))
	# A non-orthogonal cell: γ=60° makes a hexagonal cell, V = a²c·sin(60°).
	var hex=sb.lattice([4.0,4.0,7.0],[90.0,90.0,60.0])
	check(absf(absf(hex.determinant())-4.0*4.0*7.0*sin(deg_to_rad(60.0)))<0.05,"a γ=60° cell has the hexagonal volume (%.2f)" % absf(hex.determinant()))
	check(not (hex*Vector3(0,1,0)).is_equal_approx(Vector3(0,4.0,0)),"and its b vector is tilted, not axis-aligned")
	# --- Fractional coordinates round-trip, and the perovskite sites read their real weights.
	# The cell is centred on the origin: a +a/2 corner is (0,0,0) ≡ (1,1,1) fractional.
	var frac=sb.fractional(perov,Vector3(3.15,3.15,3.15))
	check(frac.is_equal_approx(Vector3(0.0,0.0,0.0)),"the corner atom is at the cell origin fractionally (%s)" % str(frac))
	var back=sb.cartesian(perov,frac)
	check(back.is_equal_approx(Vector3(-3.15,-3.15,-3.15)),"and converts back to the equivalent corner (%s), one cell away" % str(back))
	check(sb.fractional(perov,sb.cartesian(perov,Vector3(0.25,0.1,0.6))).is_equal_approx(Vector3(0.25,0.1,0.6)),"fractional → Cartesian → fractional round-trips")
	var corner=sb.site(sb.fractional(perov,Vector3(3.15,3.15,3.15)))
	check(corner.name=="角点" and is_equal_approx(float(corner.share),0.125),"a corner atom is 角点 · 等效 1/8 (%s)" % str(corner))
	var body=sb.site(sb.fractional(perov,Vector3(0,0,0)))
	check(body.name=="胞内" and is_equal_approx(float(body.share),1.0),"the body-centre atom is 胞内 · 1 (%s)" % str(body))
	var face=sb.site(sb.fractional(perov,Vector3(3.15,0,0)))
	check(face.name=="面心" and is_equal_approx(float(face.share),0.5),"a face atom is 面心 · 1/2 (%s)" % str(face))
	var edge=sb.site(sb.fractional(perov,Vector3(3.15,3.15,0)))
	check(edge.name=="棱心" and is_equal_approx(float(edge.share),0.25),"an edge atom is 棱心 · 1/4 (%s)" % str(edge))
	# --- PBC: wrapping keeps an atom inside the cell and never duplicates the boundary.
	var wrapped=sb.wrap_frac(Vector3(1.25,-0.25,2.5))
	check(wrapped.is_equal_approx(Vector3(0.25,0.75,0.5)),"fractional coordinates wrap into [0,1) (%s)" % str(wrapped))
	# Just past the +a/2 face plane: it wraps back and snaps onto the face (x = ∓3.15, on 面心).
	var out=sb.snap_to_cell(perov,Vector3(3.2,0.0,0.0))
	check(absf(absf(out.x)-3.15)<0.01 and absf(out.y)<0.01 and sb.site(sb.fractional(perov,out)).name=="面心","an atom just outside a face snaps onto it (%s · %s)" % [str(out),str(sb.site(sb.fractional(perov,out)))])
	# Far outside, wrapping brings it into the cell instead of silently leaving it out of bounds.
	var far=sb.snap_to_cell(perov,Vector3(6.4,0.0,0.0))
	check(absf(far.x)<3.16,"an atom a whole cell out wraps inside (x=%.3f)" % far.x)
	# A near-corner atom lands exactly on a corner — either of the two equivalent ones.
	var near=sb.snap_to_cell(perov,Vector3(3.25,3.25,3.15))
	var corner_ok=near.distance_to(Vector3(3.15,3.15,3.15))<0.01 or near.distance_to(Vector3(-3.15,-3.15,-3.15))<0.01
	check(corner_ok and sb.site(sb.fractional(perov,near)).name=="角点","a near-corner atom snaps onto the corner (%s)" % str(near))
	var middle=sb.snap_to_cell(perov,Vector3(1.0,1.0,1.0))
	check(middle.is_equal_approx(Vector3(1.0,1.0,1.0)),"an atom well inside the cell is left where it is")
	# --- Angles are validated, and old saves without them still load.
	var bad=perov.duplicate(true); bad["cell_angles"]=[90.0,20.0,90.0]
	check(not sb.validate(bad),"an impossible cell angle is rejected")
	var bad2=perov.duplicate(true); bad2["cell"]=[99.0,6.3,6.3]
	check(not sb.validate(bad2),"an impossible cell length is still rejected")
	var legacy=perov.duplicate(true); legacy.erase("cell_angles")
	check(sb.validate(legacy),"a structure saved before angles existed still validates")
	check(sb.lattice(legacy.cell,[]).is_equal_approx(sb.lattice(legacy.cell,[90.0,90.0,90.0])),"and defaults to 90/90/90")
	# --- v0.52: a phase for structures the sourced table does not cover (user: 有些气液固还是没展示出来).
	var Look=preload("res://scripts/reactor_look.gd")
	var crystal=Look.estimate({"atoms":["Cs","Pb","Br","Br","Br"],"periodic":true,"chapter":"晶体"},"")
	check(str(crystal.phase)=="solid" and bool(crystal.exact)==false and str(crystal.text).contains("推测"),"a periodic build reads as solid, labelled as an estimate: "+str(crystal.text))
	var known=Look.estimate({"atoms":["H","O","H"]},"water")
	check(str(known.phase)=="liquid" and bool(known.exact),"a known compound still uses its sourced phase (water = 液态)")
	var small=Look.estimate({"atoms":["H","H","O"]},"")
	check(str(small.phase)=="gas","a three-atom unlisted molecule estimates as gas")
	var salty=Look.estimate({"atoms":["Na","Cl"]},"")
	check(str(salty.phase)=="solid","a metal-bearing molecule estimates as solid")
	var big=Look.estimate({"atoms":["C","C","C","C","C","C","C","C","C","C","C","C","C","H","H"]},"")
	check(str(big.phase)=="solid","a large unlisted molecule estimates as solid (%s)" % str(big.phase))
	check(Look.estimate({"atoms":[]},"").is_empty(),"an empty structure has no phase")
	# --- The editor's own controls agree with the model.
	var editor=preload("res://scripts/sandbox_editor.gd")
	check(editor.new()!=null,"the sandbox editor still loads with the new lattice controls")
	if failures.is_empty(): print("LATTICE OK (%d checks)" % checks); quit(0)
	else: print("LATTICE FAILED: ",failures); quit(1)
