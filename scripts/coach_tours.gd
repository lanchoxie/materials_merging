extends RefCounted
## v0.28 first-time tours, one per screen. Targets are looked up when a step shows,
## so a missing control only centres the caption instead of breaking the tour.

static func find_button(root: Node, prefix: String) -> Control:
	if root == null: return null
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and str(b.text).strip_edges().begins_with(prefix): return b
	return null

static func steps(game, id: String) -> Array:
	var m = game.modal
	match id:
		"island":
			return [
				{"target": func(): return game.world_box, "title": "这是你的小岛",
					"text": "中间的玻璃圆柱就是反应釜，原子在腔里转。点一下选中它，右边会显示产率、物态和升级后的新外观。"},
				{"target": func(): return find_button(game.side, "进入原子工作台"), "title": "调结构，赚更多",
					"text": "进入原子工作台，拖动原子让键长和键角接近参考结构。几何匹配越高，每秒金币越多。"},
				{"target": func(): return find_button(game, "↓  收获全部"), "title": "收获",
					"text": "炉子会一直产出金币和产物。攒一会儿点这里，一次收完。"},
				{"target": func(): return game.quest_label.get_parent().get_parent(), "title": "跟着目标走",
					"text": "不知道下一步做什么，就看这条目标。完成后点「领取」拿奖励。"},
				{"target": func(): return find_button(game, "精炼厂"), "title": "元素从精炼厂来",
					"text": "换元素、合成有机物都要元素库存。空气和海水在精炼厂自动产出；金属要先去星球采矿，再回精炼厂提炼。"},
			]
		"editor":
			return [
				{"target": func(): return m.viewbox, "title": "拖动原子",
					"text": "按住彩球拖动就能改位置；旁边的按钮或右键、滚轮可以旋转和缩放视角。"},
				{"target": func(): return m.preview_bar, "title": "几何匹配",
					"text": "这条进度表示你的结构离参考结构有多近。第一个目标是把它拖到 80% 以上。"},
				{"target": func(): return m.apply_button, "title": "提交修改",
					"text": "满意了就点这里。只改坐标马上生效；换元素要等博士走来装炉，旧批次不会丢。"},
				{"target": func(): return m.return_button, "title": "随时返回",
					"text": "没提交的修改不会扣费，放心试。"},
			]
		"refinery":
			return [
				{"target": func(): return m.guide, "title": "三步拿到元素",
					"text": "① 去星球挖矿 → ② 在这里精炼 → ③ 拿元素去替换或合成。亮起的是你现在该做的一步。"},
				{"target": func(): return m.stock_grid, "title": "元素库存",
					"text": "点任意元素，底部会告诉你它从哪里来：自动产出，还是要用哪种矿去炼。"},
				{"target": func(): return m.extractors, "title": "自动产出",
					"text": "空气分离、电解水、盐田……这些不用管，会自己慢慢产出，存满了就暂停。"},
				{"target": func(): return m.processes, "title": "矿石精炼",
					"text": "有矿就点「开始精炼」。按钮是灰的时候，会写明还缺哪种矿、在星球哪一层能挖到。"},
				{"target": func(): return find_button(m, "进入星球采矿"), "title": "缺矿就去挖",
					"text": "星球地下不同深度有不同矿物。挖到后回来精炼即可。"},
			]
		"organic":
			return [
				{"target": func(): return m.reference_menu, "title": "选择要合成的有机物",
					"text": "尿素、乙醇、甘油，每种都写明了用途和来源。"},
				{"target": func(): return m.requirements, "title": "看清要什么",
					"text": "所需元素逐项列出：✓ 表示够了，✗ 表示还差多少、去哪里弄。"},
				{"target": func(): return m.refinery_button if m.refinery_button.visible else null, "title": "缺元素？",
					"text": "一键跳到精炼厂补齐，补完按返回就回到这里。"},
				{"target": func(): return m.start_button, "title": "请博士装炉",
					"text": "元素齐了点开始。博士会沿小路走来，元素小球先在炉口旋转，装完再落进腔体；化合物变了，腔里的固体、液体或气体也会跟着变。"},
			]
		"index":
			return [
				{"target": func(): return game.index_tabs, "title": "两个真实数据库",
					"text": "分子来自 PubChem，晶体来自 Materials Project。这里的每一条都是真实存在或被计算预测过的物质。"},
				{"target": func(): return game.index_chips, "title": "按元素筛选",
					"text": "点几个元素，只看同时含有它们的物质。先挑精炼厂里已经有的元素，更容易做出来。"},
				{"target": func(): return game.index_grid.get_child(0) if game.index_grid != null and game.index_grid.get_child_count() > 0 else null, "title": "做出来就收录",
					"text": "点卡片看真实性质和会转的三维结构。在工作台换元素或在结构工坊画出同样的东西，收获一次就收录，第一次还有金币。"},
				{"target": func(): return game.index_credits_button, "title": "有据可查",
					"text": "每个数字都标了来源编号；数据库里没有的写「未测」。自己搭的新结构保持「假说」，不会编造性质。"},
			]
		"sandbox":
			return [
				{"target": func(): return find_button(m, "＋ 新建空白探索作品"), "title": "结构工坊",
					"text": "这里可以从空白开始自由搭原子和连接，作品能保存，也能装进反应釜。"},
				{"target": func(): return find_button(m, "开始调节"), "title": "从初始配方开始",
					"text": "不想从零开始？挑一个初始配方点「开始调节」，在它的基础上调键长和角度。"},
			]
	return []
