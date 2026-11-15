extends Node

# Compact whitebox dialogue. Events run only when an option is confirmed.
# Main routes the event, waits for the world action, and then follows `next`.
var dialogue_tree: Dictionary = {
	"cliff_goat_intro": {
		"speaker": "老岩羊", "title": "山顶猪圈", "avatar": "",
		"content": "别人都在抢甜料，你倒在这里看天。天上有什么？",
		"options": [{"text": "天上没有栏杆，也没有食槽。", "next": "cliff_goat_choice"}]
	},
	"cliff_goat_choice": {
		"speaker": "老岩羊", "title": "两条路", "avatar": "",
		"content": "明早六点，运牲车来装猪。你可以回槽边吃个饱，也可以叼起这枚铜插销，闯过农场，去后山索道。\n山路很冷，猎犬很凶。选吧。",
		"options": [
			{"text": "【红色之路】叼起插销，撞开木栓。", "event": "choose_red", "next": "cliff_goat_escape_start"},
			{"text": "【蓝色之路】回到泥窝。", "next": "ending_stay_in_sty"}
		]
	},
	"cliff_goat_escape_start": {
		"speaker": "老岩羊", "title": "第一步 · 斩断过去", "avatar": "",
		"content": "木栓已断！但记住：迈出第一步后，紧追你不放的是你身后的过去——对温饱泥槽的依恋、对未知的恐惧。\n别回头，沿下山小路一直跑！按空格跃过倒木与障碍，冲进牛耕地！",
		"options": [{"text": "不回头，向前冲！", "next": ""}]
	},
	"ending_stay_in_sty": {
		"speaker": "旁白", "title": "安稳的肉馅", "avatar": "",
		"content": "猪没有碰那枚插销。它回到温热的泥窝，把嘴埋进甜料。\n远处传来柴油车的低鸣。",
		"options": [{"text": "在温饱里，等到天明。", "event": "choose_blue", "next": ""}]
	},
	"goat_after_choice": {
		"speaker": "老岩羊", "title": "路已经选了", "avatar": "",
		"content": "插销拿稳。往农场深处走，铁门后面就是索道。你不必等所有人都想明白。",
		"options": [{"text": "点头，继续走。", "next": ""}]
	},
	"aniu_interaction": {
		"speaker": "阿牛", "title": "黑土垄", "avatar": "",
		"content": "滚开，别挡我的犁沟！……你是哪来的猪？今天还有两亩地，咬紧牙总能拉过去！",
		"options": [
			{"text": "我从山顶破圈来的。大叔，看看你的犁尖。", "next": "aniu_solved"},
			{"text": "你先忙，我不打扰了。", "next": "aniu_leave"}
		]
	},
	"aniu_leave": {
		"speaker": "阿牛", "title": "还在使劲", "avatar": "",
		"content": "别踩坏地。……嘿！再使一把劲！",
		"options": [{"text": "离开。", "next": ""}]
	},
	"aniu_revisit": {
		"speaker": "阿牛", "title": "仍未拉动的犁", "avatar": "",
		"content": "你怎么又回来了？这块硬泥，今天非翻过去不可。",
		"options": [
			{"text": "不是硬泥，看看下面。", "next": "aniu_solved"},
			{"text": "先离开。", "next": ""}
		]
	},
	"aniu_solved": {
		"speaker": "一口猪", "title": "泥下的顽石", "avatar": "",
		"content": "猪拱开一层泥。犁尖卡在花岗岩下面，刃已经卷了。\n\n大叔，你拉的是石头。再使劲，先断的会是你的脖子。",
		"options": [{"text": "看看阿牛的反应。", "next": "aniu_reply"}]
	},
	"aniu_reply": {
		"speaker": "阿牛", "title": "停下来", "avatar": "",
		"content": "……花岗岩？我拉的是石头？\n难怪怎么使劲都没用。……我先喝口水。",
		"options": [{"text": "看他卸下轭，走向水渠。", "event": "complete_ox", "next": "aniu_drink_water"}]
	},
	"aniu_drink_water": {
		"speaker": "阿牛", "title": "水渠边 · 伙伴的力量", "avatar": "",
		"content": "卸下了沉重木轭，我才发现脖子原来可以这么轻松！\n小白猪，既然你在勇敢往前走，我这身硬骨气就传给你！",
		"options": [{"text": "【领悟伙伴之力 · 坚韧挣脱】多谢阿牛哥！", "next": ""}]
	},
	"aniu_post_idle": {
		"speaker": "阿牛", "title": "卸下重负", "avatar": "",
		"content": "去吧！前面下山的溪流路里有恶犬巡逻。记住：一旦被咬住，立刻狂按空格挣脱，别放弃！",
		"options": [{"text": "放心，我会一直跑！", "next": ""}]
	},
	"mianmian_interaction": {
		"speaker": "绵绵", "title": "木棚阴影里", "avatar": "",
		"content": "你是谁……？我的毛太细太软，压不成机床下面的硬毡垫。大家都说我是废羊。",
		"options": [
			{"text": "我从山顶来的。软毛做不了硬垫，就一定没用吗？", "next": "mianmian_advice"},
			{"text": "我先不打扰你。", "next": ""}
		]
	},
	"mianmian_revisit": {
		"speaker": "绵绵", "title": "还在阴影里", "avatar": "",
		"content": "你又回来了……别看我的毛了。",
		"options": [
			{"text": "想跟你说两句。", "next": "mianmian_advice"},
			{"text": "先离开。", "next": ""}
		]
	},
	"mianmian_advice": {
		"speaker": "一口猪", "title": "一把不合适的尺", "avatar": "",
		"content": "我也说不上来这身软毛能做什么，但肯定不只垫机床这一种用处。\n这里的粗尺子量不出你的用处，你不用把自己当成一个错。",
		"options": [{"text": "等绵绵回话。", "next": "mianmian_reply"}]
	},
	"mianmian_reply": {
		"speaker": "绵绵", "title": "阳光下 · 伙伴的力量", "avatar": "",
		"content": "……原来，不是我的毛是错的，只是量我的尺子不合适！\n小白猪，谢谢你点醒我。",
		"options": [{"text": "【领悟伙伴之力 · 破妄明眸】接纳真实的自己！", "event": "complete_sheep", "next": "mianmian_post_idle"}]
	},
	"mianmian_post_idle": {
		"speaker": "绵绵", "title": "阳光下的软毛", "avatar": "",
		"content": "这身软毛晒得暖洋洋的。去吧小白猪！幻影碰触不到你，穿过它们，冲进马场！",
		"options": [{"text": "借你明澈双眸，我去冲破迷雾！", "next": ""}]
	},
	"inspect_record_board": {
		"speaker": "纪录榜", "title": "新旧纪录", "avatar": "",
		"content": "旧字：追风，41 秒，三年前冠军。\n新牌：闪电，35 秒，去年春天。\n\n旁边的小字：老马追风已退出竞赛梯队。",
		"options": [{"text": "记下 35 秒的新纪录。", "event": "read_record", "next": ""}]
	},
	"zhuifeng_interaction": {
		"speaker": "追风", "title": "泥地跑道", "avatar": "",
		"content": "闪开！别挡道！我还要保持 41 秒的配速。只要跑下去，金牌就是我的！",
		"options": [
			{"text": "我从山顶来的。大叔，你在追哪一块金牌？", "next": "zhuifeng_record_check"},
			{"text": "先退开。", "next": ""}
		]
	},
	"zhuifeng_revisit": {
		"speaker": "追风", "title": "又绕了一圈", "avatar": "",
		"content": "又是你！别让我分心，我还在跑配速！",
		"options": [
			{"text": "看一眼入口的纪录牌。", "next": "zhuifeng_record_check"},
			{"text": "先离开。", "next": ""}
		]
	},
	"zhuifeng_observe_record": {
		"speaker": "一口猪", "title": "先看清木牌", "avatar": "",
		"content": "猪转头望向路口。旧的 41 秒被划去，新木牌写着：闪电，35 秒。",
		"options": [{"text": "把看到的新纪录告诉追风。", "event": "read_record", "next": "zhuifeng_awaken"}]
	},
	"zhuifeng_awaken": {
		"speaker": "一口猪", "title": "35 秒", "avatar": "",
		"content": "牌子上的纪录去年就换了，现在是 35 秒。\n农场已经不排你的比赛。你不用向往什么旷野，但何必非得追着三年前的自己？",
		"options": [{"text": "等追风停下。", "next": "zhuifeng_reply"}]
	},
	"zhuifeng_reply": {
		"speaker": "追风", "title": "停步 · 伙伴的力量", "avatar": "",
		"content": "……35 秒？原来农场早就换了纪录，我一直在跑道里追着一个三年前的空影……\n小白猪，你说得对！奔跑不是为了向栅栏里的人讨要金牌，奔跑是为了感受迎面而来的山风！把我的速度带到旷野里去吧！",
		"options": [{"text": "【领悟伙伴之力 · 疾风冲刺】向旷野奔腾！", "event": "complete_horse", "next": "learn_horse_will"}]
	},
	"learn_horse_will": {
		"speaker": "一口猪", "title": "疾风之步", "avatar": "",
		"content": "速度，终于只为自己的脚步而奔流。",
		"options": [{"text": "发起终极突围，冲向大铁门！", "next": ""}]
	},
	"zhuifeng_post_idle": {
		"speaker": "追风", "title": "风吹鬃毛", "avatar": "",
		"content": "冲吧小白猪！有我们大家的支持，前面没有围栏能挡住你！用疾风冲刺跨越终点！",
		"options": [{"text": "出发，绝不停歇！", "next": ""}]
	},
	"ordeal_encounter": {
		"speaker": "农场主", "title": "第一回合 · 甜料", "avatar": "",
		"content": "047 号！明早车就来了。老实回圈，今晚给你加满甜麦麸！",
		"options": [{"text": "甜料再甜也是饵。你养我，是为了按斤称肉。", "next": "ordeal_turn_2"}]
	},
	"ordeal_turn_2": {
		"speaker": "农场主", "title": "第二回合 · 电棍", "avatar": "",
		"content": "肉猪的天职就是长肉！走出这道门，你什么都不是！\n他举起电击棍，逼近一步。",
		"options": [{"text": "你订的标准，绑不住我想去的地方。", "next": "ordeal_turn_3"}]
	},
	"ordeal_turn_3": {
		"speaker": "一口猪", "title": "第三回合 · 冲撞", "avatar": "",
		"content": "猪低下头。铁门就在农场主身后。\n趁电棍挥空，它向门锁冲去。",
		"options": [{"text": "撞开铁门！", "event": "complete_showdown", "next": "ordeal_aftermath"}]
	},
	"ordeal_aftermath": {
		"speaker": "农场主", "title": "门开了", "avatar": "",
		"content": "农场主跌坐在地，拍了拍裤腿。\n“跑了一头，亏了千把块……算了，圈里还有几百头。”",
		"options": [{"text": "走向索道。", "next": ""}]
	},
	"farmer_wait": {
		"speaker": "农场主", "title": "铁门前", "avatar": "",
		"content": "想从这里出去？先过了大院里的犬队再说。",
		"options": [{"text": "离开。", "next": ""}]
	},
	"cablecar_locked": {
		"speaker": "索道", "title": "尚未就绪", "avatar": "",
		"content": "去往索道的路还没有打通。你需要带着铜插销，穿过犬队并打开铁门。",
		"options": [{"text": "回去看看。", "next": ""}]
	},
	"cablecar_climax": {
		"speaker": "一口猪", "title": "最后一步", "avatar": "",
		"content": "木吊厢悬在山风里。猪把一路叼着的铜插销对准卡槽。\n\n咔嗒。前面没有食槽，只有旷野。",
		"options": [{"text": "插入铜插销，出发。", "event": "launch_cablecar", "next": ""}]
	}
}

func get_dialogue_node(key: String) -> Dictionary:
	if key == "zhuifeng_record_check":
		key = "zhuifeng_awaken" if GameManager.has_read_record else "zhuifeng_observe_record"
	return dialogue_tree.get(key, {}).duplicate(true)

func get_entry_for(interaction_id: String) -> String:
	match interaction_id:
		"goat":
			return "cliff_goat_intro" if GameManager.stage == "prologue" else "goat_after_choice"
		"record_board": return "inspect_record_board"
		"farmer":
			if GameManager.stage == "showdown": return "ordeal_encounter"
			if GameManager.stage == "cablecar_ready": return "ordeal_aftermath"
			return "farmer_wait"
		"cablecar":
			return "cablecar_climax" if GameManager.can_launch_cablecar() else "cablecar_locked"
		"ox", "sheep", "horse":
			var prefix: String = {"ox": "aniu", "sheep": "mianmian", "horse": "zhuifeng"}[interaction_id]
			if GameManager.npc_completed.get(interaction_id, false): return prefix + "_post_idle"
			if GameManager.npc_met.get(interaction_id, false): return prefix + "_revisit"
			return prefix + "_interaction"
	return ""
