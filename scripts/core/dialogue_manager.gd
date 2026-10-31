extends Node

# Dialogue Manager (《一口猪在金牌农场》简短有力寓言对话树)
# 核心主旨：语言简短有力，直指人心；围城视角，互助觉醒

signal dialogue_started(node_data: Dictionary)
signal dialogue_advanced(step: int)
signal dialogue_ended()

var dialogue_tree = {
	# --- 序幕：悬崖边的晨风与老岩羊 ---
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
		"content": "农场的金牌是给死肉戴的。顺着这根旧缆绳能滑下万丈绝壁，插销给你。\n不过走之前，大院里那几头傻口子，快被那块金牌压断骨头了。",
		"options": [
			{"text": "【用鼻子拱起插销】“吃饱了，顺路去给他们松松绑。”", "next": ""}
		]
	},

	# --- 节点1：老耕牛 阿牛 (黑土地里的大顽石) ---
	"aniu_interaction": {
		"speaker": "阿牛 (四蹄打滑的老黄牛)",
		"avatar": "🐂",
		"title": "黑土泥垄里的耕作者",
		"content": "（呼哧吐着白沫，眼珠通红）还差两分地……今天翻不完，金牌评优就黄了……",
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
		"title": "黑土泥垄里的耕作者",
		"content": "……石头？！我顶着块大石头犁了两个时辰？！可金牌农场的规矩……",
		"options": [
			{
				"text": "【简短有力】“阿牛，地是翻不完的，但牛会累死。地每年都要歇冬，你比地还硬？”",
				"next": "aniu_finish"
			}
		]
	},
	"aniu_finish": {
		"speaker": "阿牛 (长舒白汽，自己顶开颈套)",
		"avatar": "🐂",
		"title": "觉醒的老黄牛",
		"content": "（看着滚远的巨石，突然笑了）哈！规矩是人定的，命是爹妈给的。老子今天不翻了，喝水去！",
		"options": [
			{"text": "甩甩尾巴，漫步走向羊舍", "next": ""}
		]
	},

	# --- 节点2：小绵羊 绵绵 (草垛里的云彩毛) ---
	"mianmian_interaction": {
		"speaker": "绵绵 (缩在草垛里的小绵羊)",
		"avatar": "🐑",
		"title": "刚被剪毛的小羊",
		"content": "（木栏贴着‘次品羊毛：细软无力，不合标准’，抽泣着）阿猪叔……他们说我的毛织不成厚布，我是最没用的一头羊……",
		"options": [
			{
				"text": "【踢飞木牌，推过去新鲜野胡萝卜】“天上的云硬不硬？”",
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
			{"text": "看着小羊咬下甘甜的胡萝卜", "next": "mianmian_finish"}
		]
	},
	"mianmian_finish": {
		"speaker": "绵绵 (眼珠亮如露水)",
		"avatar": "🐑",
		"title": "重拾自信的绵羊",
		"content": "云彩毛……对！我长的是天上的云彩毛！阿猪叔，有人来抓你，我用羊群给你堵路！",
		"options": [
			{"text": "用鼻子蹭蹭草堆，走向环形跑道", "next": ""}
		]
	},

	# --- 节点3：烈马 追风 (跑圈里的瞎马) ---
	"zhuifeng_interaction": {
		"speaker": "追风 (大汗淋漓的纯血马)",
		"avatar": "🐎",
		"title": "封闭赛道上的飞奔者",
		"content": "（戴着皮眼罩在泥圈疯狂打转）别挡道！我的配速曲线是全庄第一！只要跑完这一万圈，金牌马厩就是我的！",
		"options": [
			{
				"text": "【撞烂看台，咬断眼罩皮带】“睁开眼看四周！”",
				"next": "zhuifeng_awaken"
			}
		]
	},
	"zhuifeng_awaken": {
		"speaker": "追风 (马失前蹄，浑身发抖)",
		"avatar": "🐎",
		"title": "看清真相的烈马",
		"content": "这……只有一条五十米的烂泥圈？！我跑了三年，每天跑一百里，原来一直在原地踩泥槽？！",
		"options": [
			{
				"text": "【简短有力】“迈开腿谁都会，往哪跑才是本事。围栏烂了，悬崖外才是路。”",
				"next": "zhuifeng_finish"
			}
		]
	},
	"zhuifeng_finish": {
		"speaker": "追风 (仰天长嘶，踏碎围栏)",
		"avatar": "🐎",
		"title": "觉醒的千里马",
		"content": "原地打转的金牌，一文不值！阿猪，今天谁敢拦你，我的铁蹄踏碎他们的门！",
		"options": [
			{"text": "点头致意，走向大院石板路", "next": ""}
		]
	},

	# --- 节点4：管家犬 老张 (大院当中的破铜铃) ---
	"laozhang_interaction": {
		"speaker": "管家犬 老张 (死死晃动铜铃)",
		"avatar": "🐕",
		"title": "金牌农庄大统领",
		"content": "阿猪！站住！农场今年评上了特级金牌！只要你留下来，金铃铛给你戴，高蛋白豆饼管饱！你跑去悬崖，连口馊料都没有！",
		"options": [
			{
				"text": "【麦穗微晃，平静反问】“老张，金牌能嚼得动吗？”",
				"next": "laozhang_response"
			}
		]
	},
	"laozhang_response": {
		"speaker": "一口猪",
		"avatar": "🐷",
		"title": "一口猪",
		"content": "嚼不动，咽不下，戴在脖子上还硌得慌。\n槽里的豆饼再甜，也是买你这条命的定金。野地里的草根苦，但嚼碎了是自由的味儿。\n铜铃很响，但外面的山风更大。别替笼子守门了，你也该卸下铃铛，在草地上打个滚了。",
		"options": [
			{"text": "从老张身边坦然走过", "next": "laozhang_finish"}
		]
	},
	"laozhang_finish": {
		"speaker": "老张 (铜铃滑落在泥水里)",
		"avatar": "🐕",
		"title": "失落的守门人",
		"content": "（呆呆看着爪子里的金牌与图纸，眼眶发红）……在草地上打个滚？我当了一条长了四条腿的活狗……我居然忘了怎么打滚了……走吧阿猪，山路慢行。",
		"options": [
			{"text": "走向悬崖缆车站台", "next": ""}
		]
	},

	# --- 终幕：悬崖木缆车，驶向旷野 ---
	"cablecar_final": {
		"speaker": "一口猪 (悬挂于万丈绝壁之上)",
		"avatar": "🐷",
		"title": "一口走出了围城的猪",
		"content": "咔嗒！生锈的插销顶入缆槽，木质吊厢在夕阳熔金的绝壁上徐徐滑出。\n崖下是万顷翻滚的金黄麦浪。阿牛在溪边甩尾，绵绵在草垛顶抖落一朵云，追风在崖坡狂奔，老张把铜铃扔进了水洼。\n金牌是农场的，但命是你自己的。\n世上只有一种特立独行：看清了槽里的把戏，依然坦坦荡荡奔向旷野。",
		"options": [
			{"text": "【迎着晚风滑向原野】天地很大，下山见！", "next": "game_win"}
		]
	}
}

func get_dialogue_node(key: String) -> Dictionary:
	if dialogue_tree.has(key):
		return dialogue_tree[key]
	return {}
