_ = require 'underscore'
fs = require 'fs'

###
en:
		hello: 'Hello'
		logout: 'Logout'
		login: 'Sign in'
		please_sign_in: 'Please sign in'
		please_register: 'Please register'
		email_address: 'Email address'
		password: 'Password'
		nickname: 'Pick a name'
		me: 'Me'
###	
all = 
	zh_CN:
		hello: '欢迎'
		new_game: '新开一局'
		dapu: '打谱'
		my_page: '我的主页'
		logout: '注销'
		login: '登陆'
		register: '注册'
		please_sign_in: '请登陆'
		please_register: '请注册'
		email_address: '邮箱地址'
		password: '密码'
		nickname: '您的昵称'
		black: '黑方'
		white: '白方'
		black_short: '黑'
		white_short: '白'
		random: '随机'
		player_name: '棋士大名'
		player_title: '棋士头衔'
		me: '我'
		delete: '舍弃'
		quit: '退出'
		attend: '参与'
		init_waiting: '还没有棋手接受挑战，请稍等……'
		init_attending: '开始对局，请点击此处！'
		taking_seat_waiting_opponent: '等待对方确认黑白'
		taking_seat_please: '请选择黑白'
		taking_seat_waiting: '棋手们尚未确定黑白'
		started_please_move: '请走棋'
		started_please_wait: '等待对手走棋……'
		need_player_wait: '请稍候，正在为您寻找新的棋手接替此局'
		need_player_invite: '马上开始继续这一局'
		start_game: '开始对局'
		view_game: '去看一看'
		challenge_you: '咱俩来一局！'
		status_started: '进行中'
		status_init: '寻找对手'
		status_need_player: '寻找另一位棋手接替此局……'
		status_ended: '已结束'
		seat_black: '执黑'
		seat_white: '执白'
		with: '对'
		notice_take_seat: '选择黑白'
		notice_my_turn: '请走棋'
		pending_head: '几位棋士邀您手谈'
		live_show: '直播间'
		connect_to_live_show: '正在连接……'
		comment: '评论'
		discard: '丢弃重来'
		undo: '回退'
		show_num: '显示数字'
		hide_num: '隐藏数字'
		publish: '发布'
		publish_text: '在这里输入您的意见'
		gaming: '对局'
		tring: '试下'
		add_chart: '截图'
		retract: '悔棋'
		finish_game: '棋局结束'
		finish_game_desc: '先由轮到着手的一方以简洁的语言表明“棋局结束”，“棋已下完”，对方予以回应，终局即告成立。'
		surrender: '认输'
		title_user_page: '{name} {title}的主页'
		title_history: '{name} {title}的光辉战绩！'
		title_invite: '约{name} {title}的手谈一局'
		title_receive_invite: '{name} {title} 约您手谈一局'
		title_home_page: '来吧，手谈一局！'
		total_moves: '共<%= moves %>步'
		fail_vs: '负于'
		win_vs: '胜'
		draw_vs: '平于'
		black_won_without_number: '黑中盘胜'
		white_won_without_number: '白中盘胜'
		view_all_history: '详细战绩'
		rate: '等级分'
		detail: '详情'
		title_origianl_life_master: '神仙'
		title_national_master: '国手'
		title_expert: '八段'
		title_A: '七段'
		title_B: '六段'
		title_C: '五段'
		title_D: '四段'
		title_E: '三段'
		title_F: '二段'
		title_G: '初段'
		title_H: '爱好者'
		title_I: '入门'
		title_J: '初学'
		history: '战绩'
		prev_blogs: '查看更早的帖子'
		win: '胜<%=num%>'
		loss: '负<%=num%>'
		draw: '平<%=num%>'
		total_games: '共<%=num%>局'
		invite_sent: '您送出的手谈约请：'
		invite_received: '约您手谈：'
		connection_lost: '连接断开'
		connected: '连接建立'
		reconnected: '重新连接成功'
		connect_failed: '连接失败'
		connecting: '正在尝试连接…'
		retract_by_opponent: '对方悔棋，请稍候'
		init_and_wait_0_1_blog: '新开一局，赶紧加入吧！'
		init_and_wait_0_1_attached_new_user: '这一局是<%=user%>开设的。<%=user%>是一位新朋友，还没有成绩证明自己 ~~'
		init_and_wait_0_1_attached_less_frequent_user: '这一局是<%=user%>开设的。<%=user%>的过往成绩是 <%=wins%>胜 <%=losses%>负'
		init_and_wait_0_1_attached_frequent_user: '这一局是<%=user%>开设的。<%=user%>的过往成绩是 <%=wins%>胜 <%=losses%>负，胜率<%=win_ratio%>，等级分<%=rate%>'
		init_and_start_0_1_blog: '<%=player1%>与<%=player2%>的对局即将开始，敬请关注 ~~'
		init_and_start_0_1_attached_new_user: '<%=user%>是一位新朋友，还没有成绩证明自己 ~~'
		init_and_start_0_1_attached_less_frequent_user: '<%=user%>的过往成绩是 <%=wins%>胜 <%=losses%>负'
		init_and_start_0_1_attached_frequent_user: '<%=user%>的过往成绩是 <%=wins%>胜 <%=losses%>负，胜率<%=win_ratio%>，等级分<%=rate%>'
		player_attend_blog: '加入游戏中！'
		call_finishing_reject_received: '对方认为棋局尚未结束。<br>请落子吧！'
		call_finishing_reject: '您认为棋局尚未结束。等候对方落子……'
		call_finishing_reject_received_others: '认为本局应当继续'
		call_finishing_cancel_received: '收回结束本局的建议'
		call_finishing_ask: '您已要求结束本局，等待对方回应'
		call_finishing_cancel: '收回请求'
		call_finishing_ask_received: '对方认为此局可以结束，你认为呢？'
		call_finishing_ask_received_others: '认为此局可以结束'
		accept_calling_finishing: '结束'
		reject_calling_finishing: '继续下'
		stop_calling_finishing_btn: '让棋局继续'
		call_finishing_stop_move: '您要求让棋局继续。请落子吧。'
		call_finishing_stop_wait: '您要求让棋局继续。请稍候对方落子。'
		call_finishing_stop_received_move: '对方要求让棋局继续。请落子吧'
		call_finishing_stop_received_wait: '对方取消了结束棋局的请求。请稍候对方落子。'
		call_finishing_accept_received_others: '双方认为本局可以结束，清盘中……'
		confirm_calcing: '确认清盘'
		calcing_confirmed: '您已确认结果，等待对方确认。您也可以继续修改这份清单'
		or1: '或者'
		or2: '还是'
		guess_live: '活棋'
		guess_dead: '死棋'
		guess_共活: '共活'
		trying_and_next: '试摆棋，下一步<%=next_player%>'
		try_btn: '试摆棋'
		try_done_btn: '结束摆棋，回到对局'
		remove_snapshot: '要取消您的评论中添加截图，请点击'
		cancel: '取消'
		home: '首页'
		blog_deleted: '原贴已被删除。'
		previous_comments: '查看更多评论…'
		view_manual: '查看棋谱'
		bulletin_result_draw: '本局已结束，平局。'
		win_in_the_middle: '中盘胜 '
		lose_in_the_middle: '中盘负于'
		about_players: '棋士简介'
		game_title_0: '新建局'
		game_title_1: '<%= player1 %><%= player1_title %>的对局'
		game_title_2: '<%= player1 %><%= player1_title %>与<%= player2 %><%= player2_title %>的对局'
		game_title_3: '<%= player1 %><%= player1_title %>（黑）与<%= player2 %><%= player2_title %>（白）的对局'
		home_new_game_str1: '新建局'
		home_new_game_str2: '尚无对手应战'
		time_str1: '<%= m %>分钟前'
		time_str2: '<%= m %>小时前'
		time_str3: '<%= m %>天前'
		num_of_stones: '<%= n %>子'
		black_win_num_of_stones: '黑胜<%= n %>子'
		white_win_num_of_stones: '白胜<%= n %>子'
		black_win_num_of_mu: '黑胜<%= n %>目'
		white_win_num_of_mu: '白胜<%= n %>目'
		draw_game: '平局'
		num_of_mu: '<%= n %>目'
		tutorials: '教程'
		game_result: '对局结果'
		time: '时间'
		my_attending_games: '我的对局'
		pending_games: '对局邀请'
		rangzi2: '让两子'
		rangzi3: '让三子'
		rangzi4: '让四子'
	zh_TW:
		contact_us: '聯繫我們'

###		
_.chain(all).keys().without('en').each (lang)->
	_.chain(all.en).keys().each (field)->
		all[lang][field] ?= all.en[field]
###

all.zh = all.zh_cn = all.zh_CN

_.chain(all).keys().each (lang)->
	fs.writeFileSync "./public/i18n/#{lang}.json", JSON.stringify(all[lang])