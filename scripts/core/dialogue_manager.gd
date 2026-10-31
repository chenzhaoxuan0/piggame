extends Node

# Dialogue Manager (极乐迪斯科式哲学与深度职场叙事系统)
# 核心主旨：成熟自洽、从容处事、游刃有余、重拾力量

signal dialogue_started(node_data: Dictionary)
signal dialogue_advanced(step: int)
signal dialogue_ended()

# 剧情树与节点数据
var dialogue_tree = {
	# --- 开局：工位黄昏 ---
	"intro_reflection": {
		"speaker": "老朱 (内心沉思)",
		"avatar": "🐷",
		"title": "资深业务架构师",
		"content": "时钟指向 19:15，夕阳正透过大厦落地窗斜切进来。\n工位区依旧响着紧绷而焦虑的键盘声，每个人都陷在‘谁也不敢先走’的无形牢笼里。\n尊严是自己给的。今天的工作已经交付了应有的水准，现在，属于生活的钟声敲响了。",
		"options": [
			{"text": "整理风衣，准备走向电梯下班", "next": ""}
		]
	},

	# --- 节点1：老李 (牛系老程序员 - 破除焦虑执念) ---
	"laoli_interaction": {
		"speaker": "老李 (眼圈发黑的工程师)",
		"avatar": "🐂",
		"title": "核心系统开发骨干",
		"content": "（双手抓着头发，喃喃自语）朱哥……我被这个高并发冲突卡了整整四个小时了……今晚要是上不了线，这个季度绩效又完了。我是不是真的跟不上现在的技术了……",
		"options": [
			{
				"text": "【指出盲点】“老李，先把缓存层的无脑重试关了试试。”",
				"next": "laoli_solved"
			},
			{
				"text": "【温和劝慰】“喝口水，放过自己。机器跑久了都得降频，何况是人。”",
				"next": "laoli_comfort"
			}
		]
	},
	"laoli_solved": {
		"speaker": "老李 (惊喜交加)",
		"avatar": "🐂",
		"title": "核心系统开发骨干",
		"content": "……报错全绿了？！天哪，居然只是重试风暴引发的假死！朱哥，你一眼就看出来了……",
		"options": [
			{"text": "【成熟处事】“技术不是死磕出来的，心态松了，眼睛才看得清。”", "next": "laoli_finish"}
		]
	},
	"laoli_comfort": {
		"speaker": "老朱",
		"avatar": "🐷",
		"title": "老朱的职场哲学",
		"content": "老李，你不是跟不上技术，你是太紧绷了，眼睛被焦虑蒙住了。\n世界上没有一个Bug重要到需要用你的健康来换。你女儿不是一直念叨着想让你去接她放学吗？关机吧，周一太阳照常升起。",
		"options": [
			{"text": "拍拍老李的肩膀，让他保存代码", "next": "laoli_finish"}
		]
	},
	"laoli_finish": {
		"speaker": "老李 (释怀长叹)",
		"avatar": "🐂",
		"title": "重获喘息的打工人",
		"content": "你说得对……我把精力都耗在害怕被淘汰的恐惧里了。我现在就保存关机，今晚回去陪女儿吃顿晚饭！朱哥，周一见！",
		"options": [
			{"text": "微笑着道别，向前方继续走去", "next": ""}
		]
	},

	# --- 节点2：小杨 (羊系实习生 - 守护少年棱角) ---
	"xiaoyang_interaction": {
		"speaker": "小杨 (眼角带泪的新人)",
		"avatar": "🐑",
		"title": "新锐产品策划实习生",
		"content": "（擦着眼泪，散落一地的PPT被批注得满江红）朱老师……张总说我的方案‘缺乏底层认知’、‘抓手不够闭环’……我是不是真的很笨，根本不适合留在这里？",
		"options": [
			{
				"text": "【递上纸巾与薄荷糖】“先擦干眼泪，嚼颗糖定定神。”",
				"next": "xiaoyang_advice"
			}
		]
	},
	"xiaoyang_advice": {
		"speaker": "老朱",
		"avatar": "🐷",
		"title": "老朱的职场哲学",
		"content": "小杨，知道他们为什么喜欢用你听不懂的词吗？\n因为当一个人无法在事实本身给出洞见时，就只能用庞大晦涩的辞藻来装点自己的权威。\n你的方案我看过，逻辑很真诚，切中了用户的真实痛点。唯一的缺点，就是没能迎合某些人炫耀PPT的虚荣心。\n别拿别人的尺子量自己的长短。保留你身上这颗敏锐而真诚的心，那才是你最特立独行、最宝贵的东西，千万别让这间屋子里的灰尘把它磨平了。",
		"options": [
			{"text": "看着小杨的眼睛，给予坚定的肯定", "next": "xiaoyang_finish"}
		]
	},
	"xiaoyang_finish": {
		"speaker": "小杨 (破涕为笑)",
		"avatar": "🐑",
		"title": "重拾自信的年轻人",
		"content": "朱老师……谢谢您。这是我入职以来，第一次有人告诉我真诚是有价值的。我把真实的调研数据留着，周一我做好第二套论证！",
		"options": [
			{"text": "点点头，转身走向走廊", "next": ""}
		]
	},

	# --- 节点3：张总 (管理层总监 - 高情商边界感) ---
	"director_interaction": {
		"speaker": "张总 (面露倦容的业务总监)",
		"avatar": "👔",
		"title": "事业群业务总监",
		"content": "老朱，这就准备走了？今晚大客户的Q4规划还要拉通对齐一下，你看大家都在咬牙坚持，咱们核心骨干是不是也再加把劲？",
		"options": [
			{
				"text": "【不卑不亢·以专业对齐】给出明确交付与边界",
				"next": "director_response"
			}
		]
	},
	"director_response": {
		"speaker": "老朱",
		"avatar": "🐷",
		"title": "老朱的高情商处事",
		"content": "张总，核心的框架和三条落地抓手，我下午四点半就已经推送到您的看板里了，标红的是风险点，周一早会半小时就能拍板。\n如果我现在留下来和大家一起熬到凌晨两点，除了消耗彼此的精力，对方案质量没有任何实质提升。\n一支疲惫不堪的队伍是打不了胜仗的。您也是，早点回去休息吧，您这周的偏头痛药吃得比饭都多了。",
		"options": [
			{"text": "直视张总的双眼，言语温和而坚定", "next": "director_finish"}
		]
	},
	"director_finish": {
		"speaker": "张总 (苦笑释怀)",
		"avatar": "👔",
		"title": "事业群业务总监",
		"content": "（张了张嘴，最后叹了口气，苦笑着拍了拍老朱的风衣袖子）行……老朱，整个部门也就你敢这么清醒地跟我说话。方案我收到了，说得对，绷太紧会断。路上慢点，周一见。",
		"options": [
			{"text": "从容致意，踏向电梯间", "next": ""}
		]
	},

	# --- 节点4：电梯落幕 (终章升华) ---
	"elevator_final": {
		"speaker": "老朱 (回望黄昏办公室)",
		"avatar": "🐷",
		"title": "红猪式的从容微笑",
		"content": "叮咚！电梯门在面前徐徐展开。\n夕阳在金色的走廊上拉出长长的倒影。身后，老李关上了电脑背起双肩包，小杨挺直了腰杆正视前路，张总也关掉了办公室刺眼的白炽大灯。\n世间只有一种特立独行，那就是认清生活的规训后，依然选择从容而体面地活出自己。\n不随波逐流，亦不愤世嫉俗；守住内心的火，照亮身边的路。",
		"options": [
			{"text": "【迈入电梯】按下下行键，回家生活！", "next": "game_win"}
		]
	}
}

func get_dialogue_node(key: String) -> Dictionary:
	if dialogue_tree.has(key):
		return dialogue_tree[key]
	return {}
