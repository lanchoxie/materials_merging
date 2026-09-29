# GitHub 发布记录

2026-09-23，用户要求上传当前游戏到 `lanchoxie` 的 GitHub，包括 APK。

- 仓库：https://github.com/lanchoxie/materials_merging ，公开仓库，默认分支 `main`。
- 预发布标签：`v0.21.0-homestead-11`；不计入正式功能发布或 QQ 交付周期。
- 源码：当前工作区快照，包含数据、场景、脚本、测试、设计与科学说明，以及两张实际游戏截图。
- APK：`builds/AtomAtelier-0.21.0-homestead-11-android.apk`，versionCode 23，SHA-256 `12697863cc0aa51f49847acbc9cdd48adf584cf9c45c3cac64393bad0bd5771d`。
- 验证：签名 v2/v3、ZIP 完整性、源数据库一致性、编译脚本、字体、双 ABI、私有文件排除通过；APK 解包后的模型45项、原生 OpenGL 界面31项、资源11项通过。headless 界面运行出现7项失败，改为真实 OpenGL 输入及投影路径后31项全部通过。Android 真机尚未验收。
- 公共快照不包含本机 Git 历史、存档、签名密钥、开发工具、缓存、个人收件人与本机交付日志；原工作区和版本历史保留。
- 待发布内容放在 `artifacts/github-publish/`；APK 放在 GitHub Release 附件，不加入源码历史。

状态：已发布。用户本人完成 GitHub 官方设备授权后，API 确认登录账号为 `lanchoxie`，创建专用仓库并上传源码。

- 公共源码提交：`3baf286145aaa1e22421a81b6858088f10bf7343`。
- 发布时间：2026-09-23 23:43:39（北京时间）。
- Release ID：`394811734`；`draft=false`，`prerelease=true`。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-homestead-11 。
- APK：https://github.com/lanchoxie/materials_merging/releases/download/v0.21.0-homestead-11/AtomAtelier-0.21.0-homestead-11-android.apk 。
- 5个附件（APK、源码ZIP、校验文件、APK审计JSON、验证说明）全部为 `uploaded`；逐个核对了 GitHub 返回的文件长度及 SHA-256，与本地完全一致。
- 源码ZIP SHA-256：`e2029132b51a1e2da699e8c97cbfaec9c75ace05a8b30eb47a7a57d76eceae90`。

公共源码镜像位于 `artifacts/github-publish/source/`，绑定该仓库 `origin`；本机主项目历史保留原样。准备脚本与发布附件位于 `artifacts/github-publish/`。未来同步应基于这个公共镜像继续提交，不能直接将含私人交付历史的本机主仓库强推到 GitHub。GitHub CLI 与配置均使用项目内目录；不要把 `.runtime/` 的认证配置提交到公共仓库。

## 2026-09-24 · sandbox-12 已发布

用户要求改为面向玩家的 README，补充反应釜截图，并完善树木/采集/挖填/搭建/微缩回岛/第一人称与生命怒气。

- 公共源码提交：`bbfa12f402c6c508019d96b3a45c633844440e5a`。
- 发布标签：`v0.21.0-sandbox-12`，Release ID `394858359`；`draft=false`、`prerelease=true`。
- 发布时间：2026-09-24 00:40:43（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-sandbox-12 。
- APK：`AtomAtelier-0.21.0-sandbox-12-android.apk`，72,920,483字节，versionCode24；SHA-256 `983250327e214d4679c7ee938c3c9f0df22de6adee03d07bc5f142d3e705b7f0`。
- 5个发布附件均已核对为 uploaded，GitHub SHA-256 与本地一致。源码归档校验值 `d56b23d7e6d40c228a28c227891d76bfe031cf25c7d1455cc178368f8afe1ae3`。
- 实际APK解包后：新增模型38项、家园模型45项、资源11项、新界面19项、家园界面31项通过。Android真机未测试。验证详见 `ANDROID-VALIDATION.md`。
- README远端内容SHA `0df3ae630c7c70c79a01dde5a102b65877a60922`；包含五张本次实际渲染截图，反应釜为首页主图。
- 本地浏览器预览已更新至 `sandbox-12`，浮岛入口 `http://127.0.0.1:8771/island.html?preview=sandbox-12`。
- 不计入正式功能版本次数，不触发QQ例行交付；旧包与旧标签保留。
- 新的快照同步脚本为 `artifacts/github-publish/prepare-sandbox12.py`，旧 `prepare.py` 为 homestead-11 发布记录，不应拿来覆盖本次发布。

## 2026-09-24 · ranch-13 已发布

- 公共源码提交：`f05780b07c0019e9df784dac398dae0a4fd53a1c`。
- 发布标签：`v0.21.0-ranch-13`，Release ID `394925596`；draft=false、prerelease=true。发布时间2026-09-24 02:04:49（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-ranch-13 。
- APK：`AtomAtelier-0.21.0-ranch-13-android.apk`，72,957,920字节，versionCode25；SHA-256 `954426f19f4499f311972953405a1edd19876cbef88b22c36d242b6c9b6a4159`。
- 五个发布附件均为uploaded，GitHub返回的长度和SHA-256与本地匹配；源码ZIP SHA-256 `03dd15da9b062e80bd96de4d0c0a491d443a098ef842ea9daa317ab7c506accd`。
- 从实际APK解包后280项检查通过，Android真机未测试。签名与sandbox-12一致，旧包和旧标签保留。
- 网页预览清单revision=ranch-13；入口 http://127.0.0.1:8771/?preview=ranch-13 。README保留反应釜等五张原截图，新增村庄实机图。
- 新增动物需求/记忆、两种材料设施、公共仓库、村民农务搬运和维修、有限旅行商人；有机物/水溶解度/生态毒性仅纳入后续方案。
- 不计正式版本或QQ交付次数；无QQ发送操作。
- 本版准备脚本 `artifacts/github-publish/prepare-ranch13.py`；发布API记录 `ranch13-published.json` 与附件验证 `ranch13-draft-verified.json`。

## 2026-09-24 · ranch-13.1 已发布

- 修复浮岛第一人称打开反应釜后丢失漫步场景：保留位置与朝向，保存/取消/Esc/Android返回均能恢复；普通与自由造物编辑共用返回逻辑。后台输入和绘制暂停，跳转其他页面释放旧场景。
- 公共源码提交：`83bb8177d8ba5162ea886b721fdfa89c8be102c6`；标签 `v0.21.0-ranch-13.1`，Release ID `394942892`，draft=false、prerelease=true。发布时间2026-09-24 02:27:16（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-ranch-13.1 。
- APK：`AtomAtelier-0.21.0-ranch-13.1-android.apk`，72,957,920字节，versionCode26；SHA-256 `66f4e263aca875fe93c814a9422fd96a005adbb18ac5a27f3fa4ad6f33eaeaa1`。
- 五个附件均核对uploaded、长度及SHA-256；源码ZIP SHA-256 `5b8d6f079617734b280b9b0c89234dd8cb2a77c5e5d89e0bf22850bdf4822fa6`。签名证书与上一版相同，v2/v3通过。
- 源码35项导航界面检查通过；实际APK解包99项通过（导航35、沙盒界面19、滑动15、浮岛场景30），截图已核对。未测试Android真机。
- Web预览revision=ranch-13.1；已有页面刷新即可使用。旧包与标签保留，不计正式功能版本或QQ交付次数，无QQ发送操作。
- 准备脚本 `artifacts/github-publish/prepare-ranch13-1.py`，公共发布记录 `ranch13-1-published.json`。

## 2026-09-24 · ranch-13.2 已发布

- 修复动物/NPC交互：F和触屏直接攻击，手套左键攻击/E查看，命中采用渲染身体边界，生态暂停后冷却不再卡死。保留伤害/怒气/反击/遮挡和距离约束。
- 背包先装备后使用；构件预览显示名称数量，详情增加放置步骤，第二行分类不再被网格遮挡。新增带图操作指南 `INTERACTION-13.2.md`。
- 公共源码提交：`9d8ee06ba8f872e01ce2dd11df0fe34132b304ec`；标签 `v0.21.0-ranch-13.2`；Release ID `394970853`；draft=false、prerelease=true。发布时间2026-09-24 03:03:19（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-ranch-13.2 。
- APK：`AtomAtelier-0.21.0-ranch-13.2-android.apk`，72,962,195字节，versionCode27；SHA-256 `ece4ad67d48e7c9da3ac300323f4d772de14bf3ba35e2456d2f9734b31e822ca`。
- 五个发布附件均核对uploaded、长度和SHA-256；源码ZIP SHA-256 `a63e77abf881531c0613dda632a9119c9c0eaedb126f160147a922ab7dc5ae7e`。v2/v3签名通过，证书与前版一致。
- 实际APK解包后225项通过（新交互29、沙盒界面19、背包20、农牧界面18、反应釜返回35、田园界面31、沙盒模型38、农牧模型35）。源码新交互29项通过，截图已核对。Android真机未测试。
- 本地Web预览revision=ranch-13.2，现有页面刷新即可。旧包与标签保留，不增加正式版本或QQ交付计数，无QQ发送操作。
- 准备脚本 `artifacts/github-publish/prepare-ranch13-2.py`，API记录 `ranch13-2-published.json`。

## 2026-09-24 · organic-14.1 已发布

- 首个有机物切片：尿素教学结构、真实车间配料罐、共享样品配水、有限分装瓶、第一人称局部施肥、对照生长与过量伤苗；读档与材料去向守恒。
- 公共源码提交：`e00989f38b6b439b3cbd6ea8218d9030bd9d60dd`；标签 `v0.21.0-organic-14.1`；Release ID `395009920`；draft=false、prerelease=true。发布时间2026-09-24 03:57:49（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-organic-14.1 。
- APK：`AtomAtelier-0.21.0-organic-14.1-android.apk`，72,987,535字节，versionCode29；SHA-256 `c089875eed0ce2ab660f3a3c839d9465cb32a92e90aeef6a3d9f1a5f64983731`。
- 五个发布附件已核对uploaded、长度与SHA-256。源码ZIP SHA-256 `865f339d65f98bbba74b4a624f0fad554856a2434069a8a4e8afd88e4d8acd2b`；v2/v3签名通过，证书与前版相同。
- 实际APK解包316项全部通过：有机39+27、农牧35、沙盒38、攻击放置29、沙盒界面19、背包20、农牧界面19、反应釜返回35、田园31、星球24。Android真机未验收。
- Web预览revision=organic-14.1；README与两张有机物截图已上传。旧包和标签保留，不增加正式版本或QQ计数，无QQ发送。
- 本地未发布的organic-14/versionCode28包保留归档；最终版14.1修正尿素背包用途文案，没有向用户交付旧包。
- 准备脚本 `artifacts/github-publish/prepare-organic14.py`；上传核对与公开API记录为 `organic14-1-draft-verified.json`、`organic14-1-published.json`。

## 2026-09-24 · organic-15 已发布

- 有机物从实际反应釜合成：选择自有炉子、补齐元素、博士安装、定时生产、收获到共享背包，再由配料罐使用同一批尿素；各入口显示真实进度与受阻原因。
- 公共源码提交：`abafa757ae96e665caca2fa2a6d4703b104c13a7`；标签 `v0.21.0-organic-15`；Release ID `395034231`；draft=false、prerelease=true。发布时间2026-09-24 04:32:07（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-organic-15 。
- APK：`AtomAtelier-0.21.0-organic-15-android.apk`，73,008,536字节，versionCode30；SHA-256 `23629d96fd84f93efb8f8504cc73c14bf534e7d0451419f293df8275c8443260`。
- 五个发布附件均已核对uploaded、长度与SHA-256。源码ZIP SHA-256 `a72edaefcb8294181b51a56c46c635847c3a344d4bdef50dac728d612f120902`；v2/v3签名通过，证书与前版相同。
- 从实际APK解包验证278项全部通过：合成23+20、有机39+27、第一人称返回35、交互29、浮岛循环55、沙盒界面19、田园界面31。真实装炉生产后收获并流入配料罐；Android真机未测试。
- Web预览revision=organic-15；README、新合成指南和实际反应釜截图已上传。旧包和标签保留，不增加正式版本或QQ计数，无QQ发送。
- 准备脚本 `artifacts/github-publish/prepare-organic15.py`；上传核对与公开API记录 `organic15-draft-verified.json`、`organic15-published.json`。


## 2026-09-24 · organic-16 已发布

- 用户要求增加有机物并打包上传GitHub；新增乙醇和甘油，从反应釜真实装炉、生产、收获到共用背包；有机目录切换、单物质配水、分装倒回、稀释和物质身份守恒。
- 公共源码提交：`00ae17a4ce95dbf836ead632e0623bce49b57310`；标签 `v0.21.0-organic-16`；Release ID `395051343`；draft=false、prerelease=true。发布时间2026-09-24 04:56:38（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-organic-16 。
- APK：`AtomAtelier-0.21.0-organic-16-android.apk`，73,012,632字节，versionCode31；SHA-256 `8b61c3a4ed8a5c133c297c773e40c2493b42a3c0bac4fb694e90d8fb1d16e187`。
- 五个附件全部核对uploaded、长度及SHA-256；源码ZIP SHA-256 `07797b659582e59adfa22a54efd2c5fc3db2f9cdc76d65b4a3e83e9dc7777c0e`；v2/v3签名通过，证书与上一版相同。
- 实际APK解包339项全部通过，截图已查看；旧尿素存档迁移和原施肥流程回归通过。Android真机未测试。
- Web实测preview.json revision=organic-16；README、玩法指南、甘油反应釜截图已发布。保留已有包与标签，不增加正式功能版本或QQ计数，无QQ发送。
- 准备脚本 `prepare-organic16.py`；发布脚本 `publish-organic16.py`；API记录 `organic16-draft-verified.json`、`organic16-published.json`。


## 2026-09-24 · frontier-17 已发布

- 用户要求星球尽可能大、核查时代切换条件。探索半径改为8192米，49个附近地形块、局部栖地/动物历史查询；新增远征入口、24个持久路标，修正远坐标树木/战斗存档边界。
- 时代条件统一显示与判定，公共仓库食物计入建村，现代增加住房、补给、健康、真实太阳能积蓄；居民外形即时切换，空缺岗位可用有限安家物资招新旅人。
- 公共源码提交：`39affaf7178e31849899af442abbdb912e7b3b7f`；标签 `v0.21.0-frontier-17`；Release ID `395075682`；draft=false、prerelease=true。发布时间2026-09-24 05:32:29（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-frontier-17 。
- APK：`AtomAtelier-0.21.0-frontier-17-android.apk`，73,025,081字节，versionCode32；SHA-256 `68b8913b22cd24c39dd560dd662f326157c41843502f34e58c12266cf02d42d0`。
- 5个附件核对uploaded、长度及SHA-256；源码ZIP SHA-256 `cb985aa6ae546be9d3769d2517fddca0b7694d4ef1e672ed87ae4c4a7e09c5ab`。v2/v3签名通过，证书与前版一致。
- 实际APK解包458项通过，远征和时代截图已查看；原有有机物、农牧、沙盒、第一人称回归通过。Android真机未测试。
- Web实测revision=frontier-17，已请求Codex右侧打开新版入口，工具状态queued；未声称已经在用户屏幕完成显示。
- 保留既有包和标签，不增加正式功能版本或QQ计数；无QQ发送。准备/上传脚本和API记录位于 `artifacts/github-publish/`，前缀frontier17。

## 2026-09-24 · interiors-18 已发布

- 公共源码提交：`1500fa58008974a542431a8b24fb9dfd80c92b58`。
- 发布标签：`v0.21.0-interiors-18`，Release ID `395106273`；draft=false、prerelease=true。发布时间 2026-09-24 06:18:31（北京时间）。
- 下载页：https://github.com/lanchoxie/materials_merging/releases/tag/v0.21.0-interiors-18 。
- APK：`AtomAtelier-0.21.0-interiors-18-android.apk`，73,050,749 字节，versionCode33；SHA-256 `3338e8bcb6587358e264e7349e3143213c093e71fd08c0413a00c30c4d1561b9`。
- 五个附件均核对为 uploaded，GitHub 返回的长度和 SHA-256 与本地一致。
- 从实际 APK 解包检查 741 项通过，含住宅布局/碰撞/可达性 205 项、真实键鼠与模拟触屏住宅 UI 78 项，以及前版全部回归。Android 真机未验收。
- README 新增工程师小窝、博士公寓和院士别墅实际内景截图，反应釜主图保留。
- 本地试玩已导出并核对为 interiors-18： http://127.0.0.1:8771/island.html?preview=interiors-18 。
- 首次内部构建未通过完整入口验收，归档为不可交付；只发布上述最终哈希。
- 不计入正式功能版本和 QQ 交付周期，未向 QQ 重复发送。
