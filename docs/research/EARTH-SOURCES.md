# 地球系统：来源登记与数据准入

核对日期：2026-09-19。这里登记支持设计方向或少量属性值的公开资料，不是已完成的全材料数据库。官方教育页面可支持概念，不能替代特定物种、材料牌号和工艺条件的实验论文。

## 已核对的来源

|ID|出处与链接|支持内容|使用边界|
|---|---|---|---|
|nist_metals_295k|[NIST NCNR Reference Tables](https://www.nist.gov/ncnr/neutron-instruments/sample-environment/sample-mounting/reference-tables)|295 K 下 Al/Cu/304 不锈钢的密度与导热；表中原单位 g/ml 与 W/(m·K)|原网页列 White 1979 与 CRC 1975 为汇编依据；不是每种现代牌号的实测保证，未列误差则保持未知|
|nbs_copper_1914|[Bureau of Standards Circular 31, 2nd ed.](https://nvlpubs.nist.gov/nistpubs/Legacy/circ/nbscircular31e2.pdf)|印刷页 61、PDF 第 65 页给出标准退火铜 20°C 体积电阻率 1.7241 μΩ·cm|历史标准参考，记录材料状态与温度；不与其他铜牌号数据冒充同一试样|
|doe_hydrogen_storage|[DOE Hydrogen Storage](https://www.energy.gov/cmei/fuels/hydrogen-storage)|低位热值比较：氢 120 MJ/kg；质量比能与体积能量密度的区别|不是储氢系统整体比能；不把液态氢体积数值配给室温气体|
|doe_electrolysis|[DOE Hydrogen Production: Electrolysis](https://www.energy.gov/cmei/fuels/hydrogen-production-electrolysis)|电解需要电能和设备，水分解为氢与氧|仅做工艺概念；游戏时间与效率独立配置|
|doe_fuel_cells|[DOE Fuel Cells](https://www.energy.gov/cmei/fuels/fuel-cells)|氢与氧在相应器件中提供电，产生水与热|不能解释为任意氢结构自动发电；不同系统效率不混用|
|epa_water_treatment|[EPA Overview of Drinking Water Treatment Technologies](https://www.epa.gov/sdwa/overview-drinking-water-treatment-technologies)|活性炭目标污染物与容量、饱和再生，膜和离子交换等不同流程|没有万能净水率；具体吸附容量、截留率、压力和水质必须另找对应证据|
|smithsonian_early_life|[Smithsonian Early Life on Earth](https://naturalhistory.si.edu/education/teaching-resources/life-science/early-life-earth-animal-origins)|早期氧增加与不耐氧微生物的环境压力，早期生命背景|不沿用页面所有年代作为最新地层边界；不把所有古代生物设成厌氧；不用灭绝百分比|
|noaa_nutrients|[NOAA What is nutrient pollution?](https://oceanservice.noaa.gov/facts/nutpollution.html)|过量营养、藻类、分解耗氧与动物影响的方向|没有提供本游戏古生态阈值或时间参数|
|ics_2026|[ICS 2026/06 更新](https://stratigraphy.org/news/156)|地质年代图版本入口|实施时代卡时逐项核对该版本；本次不从旧科普页面抄年代边界|
|nps_devonian|[NPS Devonian Period](https://www.nps.gov/articles/000/devonian-period.htm)|鱼类、早期森林等场景灵感|示意场景不是同一地点所有物种真实共存；精确年代以 ICS 为准|
|nasa_flammability|[NASA JSC 29353D](https://standards.nasa.gov/system/files/tmp/JSC%2029353D%20Flammability%20Configuration%20Analysis%20for%20Spacecraft%20Applications.pdf)|氧条件、材料配置与点火对可燃性的作用|航天材料测试不是石炭纪野火率模型；只支持多条件思路，不借用具体阈值|
|doe_perovskite|[DOE Perovskite Research Directions](https://www.energy.gov/cmei/systems/perovskite-research-directions)|湿、热、光、氧与器件层/封装、耐久验证的重要性|页面有历史效率和市场状态叙述；不采用它们作为 2026 最新商业结论；不赋值给任意 ABX₃|
|iea_energy_ai|[IEA Energy and AI](https://www.iea.org/reports/energy-and-ai)|数据中心、电力与能源系统的联系|不把预测当事实，不照搬全球需求到一座游戏城市|
|gchq_1916|[GCHQ Communications Security in 1916](https://www.gchq.gov.uk/information/communications-security-in-1916-the-la-boisselle-find)|一战通信基础设施与历史背景|材料选择改变游戏中后勤，不由此推断真实历史胜负|
|mp_electronic_structure|[Materials Project 电子结构方法](https://docs.materialsproject.org/methodology/materials-methodology/electronic-structure)|计算方法与带隙误差的边界|需单独满足 API、具体数据和再分发条款；当前不自动下载数据库|

## 单条属性必须保存

- 材料实体与状态：成分、相、牌号/处理方式、结构签名（若与具体结构绑定）；不要只用化学式充当全部身份。
- 属性、原值、原单位、归一化值、单位转换、温度/压力/测试方法、方向与频率（相关时）。来源没写就标 null，不擅自补“常温常压”。
- 出处、表号或页码、读取日期、来源版本；计算派生值需指向上游记录并保存公式。
- 证据类型、数据质量、误差/区间及其来源。未知误差不写成 0，不展示虚假 95% 置信区间。
- 适用范围、排除条件、发布资格和许可核验状态。一个值通过文献核对，不代表已测出玩家样品的属性。

`property_seed.json` 中有 9 条设计用记录：6 条金属热导/密度、1 条铜参考电阻率、1 条其倒数派生的电导率、1 条氢低位热值。导热与电阻率来自不同条件和材料描述，不拼成同一真实试样的“全属性卡”。参考值只做相应条件的比较。

## 许可与内容政策

只保存必要的数值、原创摘要与来源链接；本次没有下载整库、复用来源图片或模型。来源页面可读不等于全部文本、第三方表格和插图都可随 APK 再分发。各记录目前标 `redistribution_review_required`，运行版导入前逐项复核；官方网页的第三方汇编数据尤其不能直接一律标公有领域。

科普卡图像优先自制/程序化；若用馆藏或科研图，单独保存作者、授权与署名文本。版本化记录来源变更，更新参考库不改变已存样品与历史实验结果。

## 仍需补证据的项目

具体聚合物的热、电和机械性能；材料牌号的强度/韧性与加工条件；膜的目标离子截留与耗能；活性炭对指定污染物的容量；具体光伏器件的效率—耐久条件；生物耐受范围；代表恐龙群落的地区/时段；中世纪建筑与工艺的地区参照。

以上缺口不靠自动线性插值填平。先将用途做成可配置的教学场景，在面向玩家的档案里标明证据状态，再分批引入真实参考。

0.12实现核对（2026-09-19）：[NOAA What is a dead zone?](https://oceanservice.noaa.gov/facts/deadzone.html) 支持低氧时可移动动物离开或发生损失的方向；[Smithsonian 早期生命](https://naturalhistory.si.edu/education/teaching-resources/life-science/early-life-earth-animal-origins) 支持氧敏感微生物受到环境压力。运行配置只采用定性方向，没有采纳其地质年代或任何真实物种致死浓度；生态阈值和动力单位是游戏规则。

## 0.12.1实际接入复核 · 2026-09-19

[NIST NCNR Reference Tables](https://www.nist.gov/ncnr/neutron-instruments/sample-environment/sample-mounting/reference-tables)：仅选铜/铝295 K密度、导热率四个数值，密度换算为SI，自有JSON模式与中文说明。原表引用White 1979和CRC 1975；未复制整表或图像，不声称第三方书籍获得开放许可。电导率、比热、毒性与误差不在本次运行数据中。

[NASA TFAWS 2012课件](https://tfaws.nasa.gov/TFAWS12/Proceedings/Form%20Factors%20Grey%20Bodies%20and%20Radks%20Course.pdf)，第25页：核对一维热流与构件热导关系。几何、边界温度、接触/外部热阻均是本项目夹具条件；不将295 K资料外推到高温，不把热流光点当瞬态温度求解。设备负载与保护阈值在独立游戏规则中配置。
