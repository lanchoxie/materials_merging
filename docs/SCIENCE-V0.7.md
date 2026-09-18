# 0.7：真实执行的小规模教学计算

这些计算在设备本地实际执行。没有预置收敛曲线、没有随机误差或把几何匹配度改名为能量。适用范围有意收窄，结果不能当作实验物性或研究级预测。

## 接口

`scripts/science_pipeline.gd` 继承 `scripts/science_jobs.gd`，保留 `ids()`、`data(id)`、`supports(id, atoms)`。`supports` 只做元素/数量初筛；`compute` 还检查坐标、参考和训练域。

`compute(id, specimen, reference={}) -> Dictionary`：`specimen` 是 `{"atoms":["H","H"],"positions":[[x,y,z],...]}`，坐标 Å。经验势的 `reference` 须含同次序的 `atoms`、`bonds:[i,j,r0]`、可选 `angles:[i,j,k,degrees]`，未知参考拒绝计算。

公共结果：`success, method, kind, status, message, model, notes, positions, units, energy, history, density, can_apply`。无效输入不返回能量。未收敛返回 `success=false`、`can_apply=false`，可显示实际历史。调用者负责在线程执行、排队、保存、费用和结构指纹检查。引擎不修改输入或存档。

经验势、ML 历史：`step, energy, max_force`；ML 另含 `distance`。只有成功的经验势/ML 结果 `can_apply=true`。DFT 历史：`step, energy, energy_change, density_residual, eigen_residual`，密度数组 `[[x_bohr,n_electrons_per_bohr],...]`。DFT 永不应用三维原子坐标，`model_only=true`。

`export_external_input(specimen)` 另生成中性单重态 H₂ 的 NWChem PBE/cc-pVDZ 三维单点输入：返回 `success, filename, content, engine, executed=false, message`。它不执行外部程序；输入采用实际三维坐标，绝不复用一维模型的能量/密度。其余元素、荷电态和自旋需后续明确支持。NWChem 输入语法依据其[官方 DFT 文档](https://nwchemgit.github.io/Density-Functional-Theory-for-Molecules.html)和[基组文档](https://nwchemgit.github.io/Basis.html)。

## 经验势

`empirical_ho`、`empirical_hc`、`empirical_ionic` 实际最小化

`E = Σbond ½ kb (r-r0)² + Σangle ½ ka (θ-θ0)²`。

人工教学刚度 `kb=12 eV/Å²`、`ka=2 eV/rad²`，零点是参考几何，参数没有拟合实验或量子计算。中心差分步长 `0.0005 Å`；最速下降带回溯，每次原子位移限幅约 `0.08 Å`；最多 160 步，最大原子力小于 `0.001 eV/Å` 才成功。起始键长须在参考的 50%–150%；重叠、非有限坐标、缺参考都会拒绝。几何能量不依赖整体平移/旋转。

此法不含非键作用、电荷、扭转、反应成键断键或熵。离子选项也只是有限显示单元的参考连线弹簧，没有周期边界、Ewald 求和或晶格能。不允许把它描述为真实稳定性。

## 机器学习势

只支持两 H 原子，键长域 `0.55 ≤ r ≤ 1.35 Å`。输入域外直接拒绝外推。

教师模型采用 Morse 形式 `Eteacher(r)=4.5[1-exp(-1.9(r-0.741))]² eV`。4.5 和 1.9 是人工教学参数，0.741 Å 与现有 H₂ 参考一致，但这不是拟合后的真实 H₂ 势。Morse 函数形式出处为 [Morse 1929 原始论文](https://journals.aps.org/pr/abstract/10.1103/PhysRev.34.57)。

每次实际生成 61 个等距训练点，构造高斯核 `Kij=exp[-(ri-rj)²/(2×0.09²)]`，用带主元消元求解 `(K+10⁻⁷ I)w=y`。预测 `E(r)=Σ wi K(r,ri)`，力使用此预测函数的解析导数，优化期间不直接使用教师函数。高斯核和正则化回归形式见作者提供的 [Rasmussen 与 Williams，2006，第 2 章](https://gaussianprocess.org/gpml/chapters/RW2.pdf)。本项目没有声称贝叶斯不确定度。

另有 60 个位于相邻训练点中间的验证点，从未用于拟合权重。返回全部真实/预测值、RMSE 与最大误差，不把训练误差称为验证误差。它验证的是人工势插值误差，并非真实物理误差。局部优化同样带回溯和力阈值，不在训练域外采样。

## 一维 Kohn–Sham 教学实验

选择维度一致、公式透明的**两电子单重态精确交换 EXX**，而不是把三维 LDA 公式套到一维密度。此处不是 LDA，也没有关联能。两粒子双阱可用于学习自洽迭代；不可把结果称为三维 H₂、分子或晶体的 DFT 结果。

将样品的 H–H 距离转为核间距 `R`（bohr），两个一维核位于 `±R/2`。其余三维方向丢弃，仅输入距离参与模型。接受 `0.8 ≤ R ≤ 4 bohr`。

全部一维模型量使用原子单位：

- 软相互作用 `w(x-x') = 1/sqrt((x-x')²+1)`，软化长度为 1 bohr。
- 外势 `vext(x)=-w(x-R/2)-w(x+R/2)`。
- 密度 `n(x)=2|φ(x)|²`，`∫n dx=2`。
- `EH=½∫n(x)n(x')w(x-x') dx dx'`。
- 两电子闭壳层精确交换 `Ex=-EH/2`，故 `vx=-vH/2`。`Ec=0`。
- 实际解 `[-½d²/dx² + vext + vH/2]φ=εφ`。
- 总能量 `E=Ts+∫n vext dx+EH/2+1/sqrt(R²+1)`，包括一致的软核核排斥。

KS 自洽框架见 [Kohn 与 Sham 1965](https://doi.org/10.1103/PhysRev.140.A1133)。一维软库仑模型形式见 [Phys. Rev. A 101, 012510 (2020)，式 8](https://link.aps.org/accepted/10.1103/PhysRevA.101.012510)；本项目自主选择软化长度 1，其参数不与论文混同。二电子 `vx=-vH/2` 和 `Ex` 公式见 [作者稿，式 10–11](https://dft.uci.edu/pubs/LCB98.pdf)。

离散：盒子 `[-12,12] bohr`，两端 Dirichlet 零边界，119 个内部点，`dx=0.2 bohr`；中心二阶差分。最低轨道由带安全下移位的逆迭代求解，内部三对角系统用 Thomas 法；正初猜取得无节点基态。SCF 使用 35% 新密度混合，最多 100 步。

成功需同时满足：密度 L1 残差 `<10⁻⁶ electrons`，相邻总能量差 `<10⁻⁸ Hartree`，本征方程残差 `<10⁻⁶ Hartree`。密度归一化、全部能量分项和真实迭代历史均返回。数值收敛只表示这个有限网格、这个近似泛函的自洽方程收敛，不表示精确量子解或真实物性。

## 验证记录

运行 `tests/test_science_engine.gd`，包括能量下降、平移不变性、已知几何极小点、输入不变、非法输入/未知参考/域外拒绝、独立验证误差重算、ML 力与中心差分一致、密度归一化/对称性、能量分项求和、距离改变导致重新计算。结果保存于 `artifacts/science-engine-results.json`。

本次实际数值：扰动水的弹簧能从 `0.21131886354237` 降为 `1.4713615×10⁻⁷ eV`，22 个历史点；H₂ 核回归验证 RMSE `3.013534838×10⁻⁵ eV`，优化键长 `0.74102525174705 Å`。

H₂ 参考距离映射的一维 KS 模型 27 次 SCF 收敛，`E=-1.42556882738022 Hartree`，密度 L1 残差 `7.3786215×10⁻⁷`，积分电子数 2。

额外使用独立 NumPy 稠密矩阵本征分解重算，未使用 Godot 逆迭代算法：相同网格能量 `-1.4255688273802245 Hartree`，与 Godot 差 `4.44×10⁻¹⁵`。细化到 `dx=0.1 bohr`、盒子 `[-16,16]` 得 `-1.4252143454343633 Hartree`，与默认网格差约 `3.54×10⁻⁴ Hartree`。这说明 SCF 残差不等于网格误差。独立记录在 `artifacts/science-independent-check.json`。这些数值仅为回归验证记录，程序不读取或回放它们。
