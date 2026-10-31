extends Node

# Dialogue Manager (陌生相遇 · 汲取意志 · 英雄蜕变)
# 核心机制：猪初次相逢牛、羊、马，给予点化解围，并汲取【坚忍】、【温柔】与【决绝】三种伟大意志

signal dialogue_started(node_data: Dictionary)
signal dialogue_advanced(step: int)
signal dialogue_ended()
signal will_acquired(will_type: String)

var dialogue_tree = {
	# --- 序幕：悬崖晨风与老岩羊 (阶段2&4) ---
	"cliff_goat_intro": {
		"speaker": "老岩羊 (从悬崖下跃上残墙)",
		"avatar": "🐐",
		"title": "绝壁上的独行客",
		"content": "猪，你天天趴在崖边看天，天里有包子？",
		"options": [
			{
				"text": "【吐掉麦穗】“天里没包子，但天足够大。”",
				"next": "cliff_goat_key"
			}
		]
	},
	"cliff_goat_key": {
		"speaker": "老岩羊",
		"avatar": "🐐",
		"title": "绝壁上的独行客",
		"content": "农场的金牌是给死肉戴的。顺着这根旧缆绳能滑下万丈绝壁，插销给你。\n顺着大院一路往上闯，去看看大院里那些你从未见过的活生生的生灵，路上的凶险你得自己扛！",
		"options": [
			{"text": "【用鼻子拱起插销】撞开门栓，向上迈向未知大院！", "next": ""}
		]
	},

	# --- 试炼1：陌生老黄牛 ➔ 汲取【坚忍之骨】 ---
	"aniu_interaction": {
		"speaker": "阿牛 (泥垄里的陌生巨兽)",
		"avatar": "🐂",
		"title": "初次相遇的黑土耕作者",
		"content": "（呼哧吐着白沫，眼珠通红死磕）还差两分地……今天翻不完，金牌评优就黄了！你是谁家的猪？别挡道！",
		"options": [
			{
				"text": "【猪嘴猛力一拱】咔嚓一声，把卡在犁尖的磨盘黑石拱飞出垄！",
				"next": "aniu_solved"
			}
		]
	},
	"aniu_solved": {
		"speaker": "阿牛 (呆立泥中)",
		"avatar": "🐂",
		"title": "震撼的老耕牛",
		"content": "……石头？！我顶着块大石头犁了两个时辰？！你一口小猪，哪来这么大劲？可金牌农场的规矩……",
		"options": [
			{
				"text": "【简短点拔】“地是翻不完的，但牛会累死。地每年都要歇冬，你比地还硬？”",
				"next": "aniu_finish"
			}
		]
	},
	"aniu_finish": {
		"speaker": "阿牛 (长舒白汽，自己顶开颈套)",
		"avatar": "🐂",
		"title": "觉醒的老黄牛",
		"content": "（看着滚远的巨石，突然笑了）哈！规矩是人定的，命是自己长出来的。老子今天不翻了，喝水去！",
		"options": [
			{
				"text": "【猪心中震撼】它即使流血也不曾弯下的脊梁……这就是扛起千钧的坚忍之骨！",
				"next": "learn_ox_will"
			}
		]
	},
	"learn_ox_will": {
		"speaker": "特立独行的猪 (领悟)",
		"avatar": "🐷",
		"title": "【意志觉醒：坚忍之骨】",
		"content": "猪注视着老黄牛沉稳走远的背影，心头猛然一震：\n自由不是轻浮的逃跑，要想冲破前方的高墙，自己必须像这头老牛一样，拥有哪怕泰山压顶也绝不屈服的【坚忍之骨】！",
		"options": [
			{"text": "迈步向前，带着坚忍之骨继续向上挺进！", "next": ""}
		]
	},

	# --- 试炼2：陌生小绵羊 ➔ 汲取【温柔之心】 ---
	"mianmian_interaction": {
		"speaker": "绵绵 (草垛后瑟瑟发抖的小羊)",
		"avatar": "🐑",
		"title": "初次相遇的被弃小羊",
		"content": "（木栏贴着‘次品羊毛：细软无力，工业报废’，即便哭泣，蹄子下却还护着一窝小雀）你是隔壁的大猪吗……我长得太软了，我是不是全农场最没用的一只羊？",
		"options": [
			{
				"text": "【踢飞木牌，拱过去新鲜野胡萝卜】“天上的云硬不硬？”",
				"next": "mianmian_advice"
			}
		]
	},
	"mianmian_advice": {
		"speaker": "一口猪",
		"avatar": "🐷",
		"title": "一口猪",
		"content": "云就是软的，才好看。羊毛软，是你的本事，不是你的病。他们要硬布做麻袋，那是他们没见过云彩。",
		"options": [
			{"text": "看着小羊咬下甘甜的胡萝卜，眼睛亮如露水", "next": "mianmian_finish"}
		]
	},
	"mianmian_finish": {
		"speaker": "绵绵 (破涕为笑)",
		"avatar": "🐑",
		"title": "重拾自信的绵羊",
		"content": "云彩毛……对！我长的是天上的云彩毛！阿猪哥，谢谢你！若是有人追你，我用羊群给你堵路！",
		"options": [
			{
				"text": "【猪心中触动】哪怕自己受尽排挤，却依然护着小雀……这就是至真至善的温柔之心！",
				"next": "learn_sheep_will"
			}
		]
	},
	"learn_sheep_will": {
		"speaker": "特立独行的猪 (领悟)",
		"avatar": "🐷",
		"title": "【意志觉醒：温柔之心】",
		"content": "小羊那双清澈如泉水的眼睛，融化了猪心底的尖刺与冷漠。\n它明白了：真正的特立独行，不是把自己变成冷酷无情的石头，而是无论这个世界多荒谬粗暴，心底永远保留一抹至真至纯的【温柔之心】！",
		"options": [
			{"text": "眼神温和而坚定，继续向上挺进！", "next": ""}
		]
	},

	# --- 试炼3：陌生烈马 ➔ 汲取【决绝之勇】 ---
	"zhuifeng_interaction": {
		"speaker": "追风 (封闭赛道上的狂暴黑马)",
		"avatar": "🐎",
		"title": "初次相遇的奔腾者",
		"content": "（戴着皮眼罩在泥圈疯狂打转）滚开！别挡我的赛道！我的配速曲线是全庄第一！只要跑完这一万圈，金牌马厩就是我的！",
		"options": [
			{
				"text": "【撞烂看台，一口咬断眼罩皮带】“睁开眼看四周！”",
				"next": "zhuifeng_awaken"
			}
		]
	},
	"zhuifeng_awaken": {
		"speaker": "追风 (猛然刹步，惊骇四顾)",
		"avatar": "🐎",
		"title": "看清真相的烈马",
		"content": "这……这只有一条五十米的烂泥圈？！我跑了三年，每天跑一百里，原来一直在原地踩泥槽？！",
		"options": [
			{
				"text": "【简短点拔】“迈开腿谁都会，往哪跑才是本事。围栏烂了，悬崖外才是路。”",
				"next": "zhuifeng_finish"
			}
		]
	},
	"zhuifeng_finish": {
		"speaker": "追风 (仰天长鸣，踏碎围栏)",
		"avatar": "🐎",
		"title": "觉醒的千里马",
		"content": "原地打转的金牌，一文不值！阿猪，今天谁敢拦你，我的铁蹄踏碎他们的门！",
		"options": [
			{
				"text": "【猪热血沸腾】那股向死而生、敢踏碎一切栅栏的气势……这就是决绝之勇！",
				"next": "learn_horse_will"
			}
		]
	},
	"learn_horse_will": {
		"speaker": "特立独行的猪 (领悟)",
		"avatar": "🐷",
		"title": "【意志觉醒：决绝之勇】",
		"content": "烈马仰天长啸的冲天气势激荡在猪的胸膛！\n最后一丝迟疑与畏缩彻底灰飞烟灭。面对前方耸立的钟楼与捕兽网，它拥有了踏平一切障碍的【决绝之勇】！\n三种意志齐聚，它不再是一只普通的猪！",
		"options": [
			{"text": "昂首阔步，向中央红砖钟楼发起冲刺！", "next": ""}
		]
	},

	# --- 决战与终章：钟楼顶层 (阶段8&9) ---
	"ordeal_encounter": {
		"speaker": "管家犬 老张 (手握电网手柄)",
		"avatar": "🐕",
		"title": "金牌农庄大统领",
		"content": "阿猪！看看你的四周，钢丝网已经合拢了！\n戴上金项圈做模范种猪，豆饼管饱！否则，明早后厨开膛剔骨！是当尊贵的金铃猪，还是当案板上的肉，你自己选！",
		"options": [
			{
				"text": "【牛的坚忍 + 羊的纯真 + 马的决绝】“金牌能嚼得动吗？！嚼不动，咽不下！”",
				"next": "ordeal_break_switch"
			}
		]
	},
	"ordeal_break_switch": {
		"speaker": "特立独行的猪 (猛力一击)",
		"avatar": "🐷",
		"title": "凝聚三种意志的英雄",
		"content": "轰——！猪借力腾空一跃，用坚硬如铁的猪拱嘴狠狠撞在高压总电闸上！\n漫天电火花炸裂！刺眼的探照灯与高音喇叭全线熄灭！浩瀚璀璨的银河星空毫无保留地洒满人间！",
		"options": [
			{"text": "在全员觉醒掩护下，奔赴最上方悬崖索道！", "next": "cablecar_climax"}
		]
	},

	# --- 终章：索道崖口度化老张 (阶段11&12) ---
	"cablecar_climax": {
		"speaker": "管家犬 老张 (瘫坐在地)",
		"avatar": "🐕",
		"title": "失落的守门人",
		"content": "（追到崖口，眼眶发红）阿猪……电闸断了，指标没了，没有农场，明天我们怎么活啊……",
		"options": [
			{
				"text": "【递上引水全息图】“老张，引水渠我全拱通了。大地不需要皮鞭，春天草自会发芽。”",
				"next": "cablecar_redemption"
			}
		]
	},
	"cablecar_redemption": {
		"speaker": "特立独行的猪",
		"avatar": "🐷",
		"title": "生命的渡人者",
		"content": "铜铃摇得很响，但山风更大。别替笼子守门了，你也该卸下铃铛，去草地上打个滚了！",
		"options": [
			{"text": "【老张泪流满面，亲手解下铜铃】跳上木吊厢，推下启动插销！", "next": "game_win"}
		]
	}
}

func get_dialogue_node(key: String) -> Dictionary:
	if dialogue_tree.has(key):
		return dialogue_tree[key]
	return {}
