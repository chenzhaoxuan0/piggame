extends Node

# Dialogue Manager with Dual-Narrative System (明暗双线故事与剧本系统)
# 明线：大厂高大上黑话、温馨正能量公关腔、虚伪规训
# 暗线：扎心毒舌、打工人真实内心吐槽、王小波式特立独行反抗精神

signal dialogue_started(data: Dictionary)
signal dialogue_finished()

# 完整主线与支线明暗双线剧本语料库
var dialogue_database = {
	# --- 主线剧本 ---
	"m1_wake_up": {
		"speaker": "特立独行的猪 (醒悟)",
		"surface": "哼哧？（这里充满了我爱吃的大饼香味……）",
		"subtext": "【觉醒时刻】：王小波说得对，别的猪被圈在猪圈里按部就班喂肥待宰。我刚才看到行政的单子，司庆要把我做成烤乳猪！今晚老子必须跑！"
	},
	"m1_broadcast_start": {
		"speaker": "全楼广播 (HR播音腔)",
		"surface": "亲爱的伙伴们，组织扁平化重构正在推进，今晚大家共同奋进，见证业务飞轮！",
		"subtext": "【扎心翻译】：大裁员前夕的死亡冲刺，所有人都装得很忙，谁敢先走就准备进毕业名单。"
	},
	"m2_elevator_locked": {
		"speaker": "电梯闸机系统",
		"surface": "为了守护业务资产安全，高保密加班时段下行电梯已锁定，需P8及以上工牌刷卡鉴权。",
		"subtext": "【扎心现实】：把员工锁在楼里不让走，居然能包装成‘资产安全’。黑金工牌在风暴会议室的总监那儿，得想办法搞到手。"
	},
	"m3_distract_director": {
		"speaker": "风暴会议室 (P8总监)",
		"surface": "我们要跳出舒适区，深挖用户心智，打造端到端的商业闭环！",
		"subtext": "【内心想法】：难的事你们做，领功的事我来。这个季度要是没有爆点，我的期权就全打水漂了！"
	},
	"m4_badge_stolen": {
		"speaker": "特立独行的猪 (得手)",
		"surface": "（叼住闪闪发光的P8黑金工牌，尾巴欢快地摇摆）",
		"subtext": "【内心独白】：白纸黑字写着‘下周司庆菜单：脆皮烤乳猪’！幸好老子跑得快，不然下周这时候我已经在蘸白砂糖了！"
	},
	"m5_hr_barrier": {
		"speaker": "HR政委 (灭绝师太)",
		"surface": "这位同学，请出示你的晚间敏捷攻坚打卡手环，请勿在走廊非必要游荡！",
		"subtext": "【真实目的】：守在通道抓每一个试图溜走的打工人，逼他们回工位继续假装高产出。"
	},
	"m6_elevator_escape": {
		"speaker": "电梯到达提示",
		"surface": "叮！【身份确认：P8总监】欢迎下行，祝您的职场生涯更上一层楼！",
		"subtext": "【成功下行】：再见吧大厂！连猪都不呆的大楼，老子不仅不上楼，老子直接润了！3楼已过，2楼见！"
	},

	# --- 支线搞事清单剧本 ---
	"side_coffee_dev": {
		"speaker": "老黄牛程序员 (键盘冒烟)",
		"surface": "系统检测到异常中断，建议建立更具弹性的敏捷容灾机制……",
		"subtext": "【真实想法】：冰美式正好浇在键盘上！Bug终于不用今晚上线了，我甚至想抱住这只猪亲两口！"
	},
	"side_whiteboard_pen": {
		"speaker": "产品经理 (凌空比划)",
		"surface": "沟通不仅依赖介质，无声对齐更能考验团队的同频心智与底层理解！",
		"subtext": "【内心崩溃】：白板笔全被猪叼走了！画不出闭环大圆圈，我怎么证明我今天加了4个小时的班？！"
	},
	"side_room_fight": {
		"speaker": "抢会议室总监对峙",
		"surface": "跨部门敏捷协同的关键，在于对公共资产的合规化调配与深度拉通！",
		"subtext": "【真实互撕】：你们部门凭什么抢我们的会议室？！没会议室项目推不动，大家今晚正好一起摸鱼！"
	},
	"side_salary_leak": {
		"speaker": "漫天飞舞的薪酬单",
		"surface": "公司坚持透明公正的市场化激励机制，让每一份奉献都清晰可见。",
		"subtext": "【工位集体破防】：干了5年的老员工捡起来一看：刚招进来的应届生工资是自己的两倍！整个办公区弥漫着离职的气息。"
	},
	"side_intern_tears": {
		"speaker": "楼梯间抹眼泪的实习生",
		"surface": "感谢组织的淬炼与压力测试，每一次试错都是赋能成长的阶梯！",
		"subtext": "【破涕为笑】：小猪给我叼来了一块威化饼干……呜呜呜谢谢你，决定了，我今晚就提离职重返校园！"
	},
	"side_pantry_raid": {
		"speaker": "高管专享冷柜",
		"surface": "高级管理层福利系基于长期复合商业价值创造之合规配置。",
		"subtext": "【猪猪狂炫】：普通员工喝速溶粉，这里居然藏着车厘子和山姆瑞士卷！真香啊哼哧哼哧！"
	}
}

func get_dialogue(key: String) -> Dictionary:
	if dialogue_database.has(key):
		return dialogue_database[key]
	return {
		"speaker": "神秘画外音",
		"surface": "我们在拉通对齐，寻找抓手以形成商业闭环。",
		"subtext": "【内心吐槽】：不知道在干嘛，反正大家都装得很忙。"
	}

# GPT6 Astra 动态提示词与生成桥接
func query_astra_dialogue(context_info: Dictionary, callback: Callable) -> void:
	# 预留给外部 GPT6 Astra API 接入
	# 离线时回退到本地精选词库
	var fallback_key = context_info.get("event", "m1_wake_up")
	callback.call(get_dialogue(fallback_key))
