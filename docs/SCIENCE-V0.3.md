# v0.3 元素替换与科学数据

本版把“元素种类”和“元素在结构中的半径环境”分开。氯在 HCl 分子中使用共价半径，在 CsPbCl₃ 教学晶胞中使用 Cl⁻ 有效离子半径；不能因为元素符号相同就混用这两种半径。

## 本版新增

| 模板 ID | 原子顺序 | 结构族 family | 参考几何 | 来源性质 |
|---|---|---|---|---|
| hydrogen_sulfide | S, H, H | bent_triatomic | S–H 1.336 Å，H–S–H 92.11° | 中性 H₂S 实验参考，键长取整 |
| hydrogen_chloride | H, Cl | diatomic | H–Cl 1.275 Å | 中性 ¹H³⁵Cl 的实验平衡键长 re，取整 |
| perovskite_chloride | 前 8 个 Cs，随后 Pb，最后 6 个 Cl | perovskite_abx3 | Pb–Cl 3.00 Å，立方晶格常数 6.00 Å | 按离子半径之和构造的教学假设 |

三个新增模板均设置 `substitution_only: true`。现有 water / hydrogen / methane / perovskite 保留，`substitution_only: false`。它们的结构族依次为 bent_triatomic / diatomic / tetrahedral / perovskite_abx3。

H₂O 的 O 位可替换为 S，形成可识别的 H₂S；H₂ 的一个 H 位可替换为 Cl，形成可识别的 HCl；CsPbBr₃ 的所有卤素位替换为 Cl 后对应 CsPbCl₃ 教学模板。替换后保留玩家坐标，几何匹配应转向新模板的参考键长和键角。双原子顺序反转代表同一种已收录物质，应在匹配逻辑中处理，而非重复建立一条 HCl 记录。

局部 Br/Cl 混合、未收录组合或不匹配的连接方式不能自动套用某个纯物质参考，也不能宣称已预测其稳定性或带隙。当前模板匹配和收益只是受支持范围内的游戏反馈。

## 半径与结构语境

`data/elements.json` 中 8 种元素均有 `atomic_number`、`radius`、`radius_type`、`oxidation_state`、`coordination`、`source`。`radius` 是默认展示值；Cl 额外提供 `radius_contexts`，列出两种语境。元素库存记录元素符号即可，不应把 Cl 和 Cl⁻ 分裂为两个元素种类。

`data/materials.json` 的每个模板都有与 `atoms` 等长、同顺序的 `atom_contexts`：

```json
{
  "radius": 1.81,
  "radius_type": "Cl- 有效离子半径，配位数6",
  "oxidation_state": -1,
  "coordination": 6,
  "source": "Shannon 1976, Table 1, effective ionic radius (IR); https://doi.org/10.1107/S0567739476001551"
}
```

其中半径单位为 Å。分子中的共价半径采用 `oxidation_state: null`、`coordination: null`，表示该半径展示未指派形式氧化态或特定配位数，并非将原子判定为零价、无邻居或孤立原子。晶体的配位数字段是所选 Shannon 半径的表格语境，不是有限球棍模型中屏幕上能数到的连线数量。

| 元素 / 使用环境 | 原子序数 | 半径 / Å | 半径来源 |
|---|---:|---:|---|
| H / 分子 | 1 | 0.31 | Cordero Table 2，共价 |
| C / CH₄ | 6 | 0.76 | Cordero Table 2，sp³ 共价 |
| O / H₂O | 8 | 0.66 | Cordero Table 2，共价 |
| S / H₂S | 16 | 1.05 | Cordero Table 2，共价 |
| Cl / HCl | 17 | 1.02 | Cordero Table 2，共价 |
| Cs⁺ / 教学晶胞 | 55 | 1.88 | Shannon Table 1，CN12，IR |
| Pb²⁺ / 教学晶胞 | 82 | 1.19 | Shannon Table 1，CN6，IR |
| Br⁻ / 教学晶胞 | 35 | 1.96 | Shannon Table 1，CN6，IR |
| Cl⁻ / 教学晶胞 | 17 | 1.81 | Shannon Table 1，CN6，IR |

Shannon 的有效离子半径 IR 和晶体半径 CR 是不同的约定，本数据库使用 IR 列。原子的显示球体允许统一缩放以保持可读性，但实际参考键长不能由显示球的大小反推。

## 教学单胞的边界

CsPbCl₃ 单胞沿用 CsPbBr₃ 的 15 个可见球布局及 `occupancies`：8 个角点各计 1/8，1 个体心计 1，6 个面心各计 1/2；加权后的化学计量是 Cs:Pb:Cl = 1:1:3。此字段表示边界球对当前单胞的计数贡献，不是晶体精修中的随机部分占据率。

Pb–Cl 参考距离的构造式为 1.19 + 1.81 = 3.00 Å，晶格常数取其两倍 6.00 Å。这是独立于实验晶格的理想立方教学选择，忽略畸变、温度、压力、电子结构及有限尺寸效应。Cs 半径没有参与该边长构造。不能称此单胞为室温基态、实际低能结构或理论优化结果。

所有模板的收益匹配仅衡量预设几何的接近程度。实验几何本身也不能提供未收录组合的势能面。势函数、机器学习势与 DFT 仍属于后续独立模块。

## 数据核验和来源

核验日期：2026-09-18。对 7 个模板完成 50 项原子数、上下文数组、键长、键角及单胞计数检查；参考坐标与键长的容差为 0.0001 Å，键角容差为 0.01°，旧版参考坐标保持原值。

- [NIST CCCBDB，中性 H₂S 实验数据](https://cccbdb.nist.gov/exp2x.asp?casno=7783064&charge=0)：采用内部坐标表的 1.336 Å 和 92.11°。NIST 引用 Cook, De Lucia & Helminger, *J. Mol. Struct.* 28 (1975), 237–246，[原始文献 DOI](https://doi.org/10.1016/0022-2860(75)80094-9)。按这些取整后的内部坐标重新生成本游戏坐标，并非宣称坐标精度高于实验记录。
- [NIST CCCBDB，中性 HCl 实验数据](https://cccbdb.nist.gov/exp2x.asp?casno=7647010&charge=0)：采用内部坐标表的 1.275 Å，表明为 ¹H³⁵Cl 的 re。其 Cartesian 表为更细位数的 1.2746 Å，游戏统一使用前者。
- [Cordero et al., *Covalent radii revisited* (2008)](https://doi.org/10.1039/B801115J)，Table 2；本次也核对了[作者上传的原文副本](https://www.researchgate.net/profile/Veronica_Gomez3/publication/5373706_Covalent_radii_revisited/links/0a85e536e362fca749000000.pdf)中的 S 1.05 Å、Cl 1.02 Å。
- [Shannon, *Revised effective ionic radii and systematic studies of interatomic distances in halides and chalcogenides* (1976)](https://doi.org/10.1107/S0567739476001551)，Table 1；[原文副本](https://www.physchemgeo.com/downloads/downloads/page60/files/ShannonRevisedIonicRadii1976.pdf)中 Cl(-I), VI 的 IR 为 1.81 Å、CR 为 1.67 Å。两列不可混淆。

JSON 仅整理本版所需的小量数值与自行撰写的教学说明，并附溯源链接，不打包文献全文。
