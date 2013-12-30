return if not gid = /game\/(.+)$/.exec(location.pathname)?[1]

tap_enabled = false
check_tap_enabled = (e)->
	return tap_enabled = false if not e
	tap_enabled = true if e.type is 'tap'
	tap_enabled and e.type is 'click'

$.get "/json/connected/#{gid}", (data)->
	console.log data
	$ ->
		init_header data
		
		Stone = Backbone.Model.extend
			defaults:
				show_num: false
				last: true
			initialize: ->
				@on 'remove_from_board', =>
					@clear silent:true
		StoneList = Backbone.Collection.extend
			model: Stone
			initialize: ->
				@on 'reset', (models, options)->
					_.each options.previousModels, (s)->s.trigger 'remove_from_board'
					_.each models.initial(), (x)-> x.set 'last', false
				@on 'add', (model, collection)=>
					model.set 'last', true
					@at(@length-2)?.set 'last', false
				@on 'remove', (model, collection)=>
					@at(@length-1)?.set 'last', true
					model.trigger 'remove_from_board'
				
		stone_list = new StoneList
		
		Game = Backbone.Model.extend
			idAttribute: 'n'
			defaults: ->
				_.defaults data.game,
					show_num: false
					connected: false
					show_first_n_stones: null
			myself: -> data.myself
			is_player: -> @myself() and @get('players') and @myself() in @get('players')
			role_of_player: (some_uid)-> _.invert(@get('seats'))[some_uid]
			my_role: ->
				@role_of_player @myself() if @is_player() and @get('seats')
			opponent: ->
				if @is_player()
					_.without(@get('players'), @myself())[0]
			connect: (cb)->
				#return @socket = null if @get('status') is 'ended'
				@socket = io.connect "http://#{location.hostname}/weiqi"
				_.each 'connect_failed reconnect_failed error connecting reconnecting reconnect disconnect'.split(' '), (x)=>
					@socket.on x, => @trigger x
				init_socket = (cb)=>
					@socket.emit 'auth', cookie.get('auth') ? 'anonymous', (res)=>
						@socket.emit 'room', @get('id')
						console.log res
						@set 'connected', true
						@trigger 'connected'
						cb?()
				@socket.on 'disconnect', => @set 'connected', false
				@socket.on 'reconnect', => init_socket()
				init_socket =>
					@socket.on 'start', (seats, next)=>
						@set 'seats', data.game.seats = seats
						@set 'next', data.game.next = next
						@set 'status', data.game.status = 'started'
					
					@socket.on 'attend', (player, params)=>
						console.log "#{player.name} join the game"
						if data.game.players
							data.game.players.push player.uid
						else
							data.game.players = [player.uid]
						@set 'players', data.game.players
						if params?.start
							@set 'seats', data.game.seats = params.seats
							@set 'status', data.game.status = 'started'
							@set 'next', @get('next')
						else if @get('players').length is @get('player_num')
							@set 'status', 'taking_seat'
						
					#@socket.on 'taking_seat', (msg)=>
					#	@set 'status', 'taking_seat'
					#	@trigger 'taking_seat', msg
					
					@socket.on 'move', (next, step, taken)=>
						data.game.moves.push step
						@move next, step, taken
					
					@socket.on 'retract', (uid)=> 
						console.log 'retract ' + uid
						@retract true
					
					@socket.on 'call_finishing', (msg)=>
						switch msg
							when 'ask'
								[msg, player] = arguments
								@trigger 'call_finishing_ask_received', player
							when 'cancel'
								[msg, player] = arguments
								@trigger 'call_finishing_cancel_received', player
							when 'reject'
								[msg, player] = arguments
								@trigger 'call_finishing_reject_received', player
							when 'accept'
								[msg, analysis] = arguments
								@trigger 'call_finishing_accept_received', analysis
							when 'stop'
								@unset 'calling_finishing'
								@trigger 'call_finishing_stop_received'
							when 'suggest'
								[msg, stone_in_regiment, suggest] = arguments
								@trigger 'call_finishing_suggest_received', stone_in_regiment, suggest
							when 'confirm'
								[msg, player, rlt] = arguments
								if rlt
									@trigger 'player_confirmed_ending', rlt
								
					@socket.on 'comment', (c)=> 
						data.refs[c.author] ?=
							id: c.author
							title: c.author_title
							nickname: c.author_nickname
						@trigger 'comment', c
					cb?()
					
			test_connection: (cb)->
				if @get 'connected'
					cb()
				else
					@connect cb
			move: ->
				switch arguments.length
					when 1
						[step] = arguments
						if @my_role() is @get('next')
							@test_connection (err)=>
								@socket?.emit 'move', step, (res)=>
									data.game.moves.push step
									if res.fail
										console.log 'fail'
									else
										@move res.next, res.step, res.taken
					when 3
						[next, step, taken] = arguments
						@set 'next', next if next
						stone_list.add step
						stone_list.chain().filter((x)->x.get('n') in taken).each (x)->x.set 'repealed', step.n
						stone_list.last().set 'show_num', game.get('show_num')
						
			retract: (direct = false)->
				if direct
					if stone = stone_list.last()?.toJSON()
						#remove the stone and trigger event
						stone_list.pop()
						stone_list.chain().filter((x)-> x.get('repealed') is stone.n).each (x)->x.unset 'repealed'
						game.set 'next', stone.player, silent:true
						@trigger 'retract', stone
				else
					if @is_player() and @my_role() is stone_list.last()?.get('player')
						#retract by myself
						@test_connection =>
							@socket.emit 'retract', (data)=>
								if data is 'success'
									@retract true
			taking_seat: (seat)->
				if 'taking_seat' is @get('status') and @myself() and @myself() in @get('players')
					@test_connection =>
						@socket.emit 'taking_seat', seat, (res)=>
							console.log res
					
			call_finishing_ask: ->
				@test_connection =>
					@socket.emit 'call_finishing', 'ask', =>
						@trigger 'call_finishing_ask'
			call_finishing_cancel: ->
				@test_connection =>
					@socket.emit 'call_finishing', 'cancel', =>
						@trigger 'call_finishing_cancel'
			call_finishing_reject: ->
				@test_connection =>
					@socket.emit 'call_finishing', 'reject', =>
						@trigger 'call_finishing_reject'
			call_finishing_accept: ->
				@test_connection =>
					@socket.emit 'call_finishing', 'accept', (analysis)=>
						@trigger 'call_finishing_accept', analysis
			call_finishing_stop:->
				@test_connection =>
					@socket.emit 'call_finishing', 'stop', (analysis)=>
						@unset 'calling_finishing'
						@trigger 'call_finishing_stop'
			call_finishing_suggest: (stone_in_regiment, suggest, cb)->
				@test_connection =>
					@socket.emit 'call_finishing', 'suggest', stone_in_regiment, suggest, cb
			call_finishing_confirm:(cb)->
				@test_connection =>
					@socket.emit 'call_finishing', 'confirm', cb
			initialize: ->
				@on 'change:show_num', (m, v)-> stone_list.each (x)-> x.set 'show_num', v
				@on 'call_finishing_accept', (analysis)=> @set 'analysis', analysis
				@on 'call_finishing_accept_received', (analysis)=> @set 'analysis', analysis
				@on 'change:show_first_n_stones', (m, v)=>
					v ?= stone_list.last()?.get 'n'
					return if not v?
					stone_list.each (x)->
						if x.get('n') > v
							x.set 'hide', true if not x.get 'hide'
						else if x.get('repealed')
							if x.get('repealed') <= v
								x.set 'hide', true
							else
								x.set 'hide', false
						else
							x.set 'hide', false
						
						if x.get('n') < v
							x.set 'last', false
						else if x.get('n') is v
							x.set 'last', true
				
			send_comment: (c)->
				@test_connection =>
					@socket.emit 'comment', data.game.id, c, => @trigger 'comment', c
			fetch_previous_comments: (tag, step, start, num, cb)->
				@test_connection =>
					@socket.emit 'fetch_comment', data.game.id, tag, step, start, num, (comments)-> cb comments
			snapshot: ->
				_.extend {gid:@get('id')}, \
				if game.get 'try'
					from = _.find( (game.get 'stones_before_try'), (x, i)->	
						not stone_list.at(i) or x.player isnt stone_list.at(i).get('player') or x.pos.join(',') isnt stone_list.at(i).get('pos').join(',')
					)?.n
					if from?
						from: from
						moves: stone_list.chain().filter((s)->s.get('n') >= from or s.get('repealed') >= from).map((s)->_.pick s.toJSON(), 'n', 'player', 'pos', 'repealed').value()
					else
						from: stone_list.length
				else
					from: stone_list.length
				
		game = new Game
		
		Comment = Backbone.Model.extend 
			initialize: ->
		CommentList = Backbone.Collection.extend
			model: Comment
			initialize: ->
				@listenTo game, 'comment', (c)=>
					c.newly_received = true if c.author isnt game.myself()
					@add c
				@listenTo stone_list, 'reset', (stone_list)=>
					@reset_comments n = if stone_list.length then stone_list.last().get('n') else 0
				@listenTo game, 'change:show_first_n_stones', (m, v)=>
					if not game.get 'try'
						v ?= stone_list.last().get 'n'
						@reset_comments v
				@listenTo game, 'change:next', =>
					if not game.get 'try'
						n = if stone_list.length then stone_list.last().get('n') else 0
						@reset_comments n
			comparator: (c)-> - Number c.get('step') + '' + c.get('ts')
			reset_comments: (n)-> 
				if data.comments[n]
					@reset data.comments[n]
				else
					@reset()
		comment_list = new CommentList
		CommentView = Backbone.View.extend
			events:
				'click .del': 'del'
				
			del: -> console.log 'del'
				
			render: ->
				@$el = $( tpl('#comment_tpl') comment:@model.toJSON(), data:data )
				@$el.addClass 'newly_received' if @model.get 'newly_received'
				
				if @model.get('ss')?.length
					_.each @model.get('ss'), (x)=>
						ss_div = @$el.find("[name='#{x.name}']")
						moves = data.refs[x.gid].moves[0...x.from]
						if (not moves or moves.length < x.from) and game.get('id') is ss.gid
							moves = if game.get('try')
								game.get('stones_before_try')
							else
								stone_list.map((s)->s.toJSON())
							moves = moves[0...x.from]
						moves = _.chain(moves).reject((z)->_.find x.moves, (y)-> z.n is y.n ).union(x.moves).value()
						new BoardCanvas(ss_div, size:150).render(moves)
				
				@$el.click -> $(this).removeClass 'newly_received' 
				@$el
		CommentsView = Backbone.View.extend
			el: $('#comments')
			events:
				'click a#previous_comments': 'fetch_previous_comments'
				'focus .comment': 'select_comment'
			initialize: ->
				@listenTo comment_list, 'reset', @render
				@listenTo comment_list, 'add', (model, collection)=>
					if model.get('ts') is collection.first().get('ts')
						@$el.find('ul').prepend new CommentView(model:model).render()
					else
						@$el.find('ul').append new CommentView(model:model).render()
			select_comment: (e)->
				#console.log $(e.target).data('comment')
			render: ->
				@$el.find('.comment').remove()
				comment_list.sort()
				comment_list.each (c)=>
					div = $(new CommentView(model:c).render()).appendTo(@$el.find('ul')).data('comment', c.toJSON())
					return
					if c.get('ss')?.length
						_.each c.get('ss'), (x)->
							ss_div = div.find("[name='#{x.name}']")
							moves = data.refs[x.gid].moves[0...x.from]
							if (not moves or moves.length < x.from) and game.get('id') is ss.gid
								moves = if game.get('try')
									game.get('stones_before_try')
								else
									stone_list.map((s)->s.toJSON())
								moves = moves[0...x.from]
							moves = _.chain(moves).reject((z)->_.find x.moves, (y)-> z.n is y.n ).union(x.moves).value()
							new BoardCanvas(ss_div, size:150).render(moves)
			
			fetch_previous_comments: ->
				step = if stone_list.length then stone_list.last().get('n') else 0
				start = if data.comments[step] then data.comments[step].length else 1
				game.fetch_previous_comments 'comments', step, start, 6, (comments)=>
					comments = comments[step]
					if comments?.length and data.comments[step]
						comments = _.reject comments, (c)->
							_.find data.comments[step], (cc)-> c.author is cc.author and c.ts is cc.ts and c.text is cc.text
					if comments?.length
						if data.comments[step]
							data.comments[step] = _.union data.comments[step], comments
						else
							data.comments[step] = comments
						_.each comments, (c)-> comment_list.add c
					else
						@$el.find('a#previous_comments').addClass('none')
						_.delay (=>@$el.find('a#previous_comments').removeClass('none')), 5000
		comments = new CommentsView
		#comment_list.reset _.chain(data.comments).values().flatten().value()
		
		Regiment = Backbone.Model.extend 
			initialize: ->
				if @get 'suggests'
					if @get('suggests')[game.myself()]
						@set 'my_guess', @get('suggests')[game.myself()]
					if @get('suggests')[game.opponent()]
						@set 'opponent_guess', @get('suggests')[game.opponent()]
					
				
				@on 'change:my_guess', @guess
				@on 'change:opponent_guess', @guess
				@listenTo game, 'call_finishing_suggest_received', (stone_in_regiment, suggest)=>
					if stone_in_regiment in @get('stones')
						@set 'opponent_guess', suggest
			guess: ->
				@set 'judge', \
				if @get('my_guess') is @get('opponent_guess') and @get('my_guess')
					@get('my_guess')
				else if @get('my_guess') isnt @get('opponent_guess') and @get('my_guess') and @get('opponent_guess')
					'disagree'
				else
					@get('my_guess') or @get('opponent_guess')
			status: -> @get('judge') or @get('guess')
					
		RegimentList = Backbone.Collection.extend
			model: Regiment
			initialize: ->
				@listenTo game, 'call_finishing_accept', tmp =(analysis)=> @reset analysis
				@listenTo game, 'call_finishing_accept_received', tmp
		regiment_list = new RegimentList
		
		StoneView = Backbone.View.extend
			tagName: 'li'
			initialize: ->
				fn = (m, v)=>
					if v
						@$el.hide()
					else
						@$el.show()
				@listenTo @model, 'change:repealed', fn
				@listenTo @model, 'change:hide', fn
				@listenTo @model, 'change:show_num', (m, v)=>
					if v
						@$el.addClass 'show_num'
					else
						@$el.removeClass 'show_num'
				@listenTo @model, 'retract', @remove
				@listenTo @model, 'change:last', @change_last
				@listenTo @model, 'change:style', @change_style
				@listenTo @model, 'clear_style', @clear_style
				@listenTo @model, 'remove_from_board', @remove
			render: ->
				@$el.html(@model.get('n') + 1).addClass(@model.get 'player').attr
					n: @model.get('n')
					x: @model.get('pos')[0]
					y: @model.get('pos')[1]
				@$el.addClass 'last' if @model.get 'last'
				
				@$el.hide() if @model.get 'repealed'
				this
			change_last: (m, v)->
				if v
					@$el.addClass 'last'
				else
					@$el.removeClass 'last'
			clear_style: -> @$el.removeClass('dead live disagree selected')
			change_style: (m, v)->
				if v
					@clear_style().addClass(v)
				else
					@clear_style()
						
		BackBtn = Backbone.View.extend
			el: $('#buttons #back')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
				@start_from = if not game.get('contract').rangzi or game.get('contract').rangzi is 'none' then 0 else Number(game.get('contract').rangzi) - 1
			events: 
				click: 'click'
				tap: 'click'
			click: (e)->
				return if check_tap_enabled e
				
				return if @$el.hasClass 'invalid'
				n = game.get 'show_first_n_stones'
				n ?= stone_list.last()?.get('n')
				if n > @start_from
					game.set 'show_first_n_stones', n-1
					if game.get 'try'
						game.set 'next_trying', stone_list.find((x)->x.get('n') is n).get 'player'
			render: ->
				n = game.get 'show_first_n_stones'
				if n and n > @start_from or n is null and stone_list.length > @start_from + 1
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		back_btn = new BackBtn().render()
		
		ForwardBtn = Backbone.View.extend
			el: $('#buttons #forward')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events: 
				click: 'click'
				tap: 'click'
			click: (e)->
				return if check_tap_enabled e
				
				return if @$el.hasClass 'invalid'
				n = game.get 'show_first_n_stones'
				if n >= 0
					if n + 1 < stone_list.last()?.get('n')
						game.set 'show_first_n_stones', n + 1
						if game.get 'try'
							game.set 'next_trying', (if stone_list.find((s)->s.get('n') is n + 1).get('player') is 'black' then 'white' else 'black')
					else
						game.set 'show_first_n_stones', null
						if game.get 'try'
							game.set 'next_trying', (if stone_list.last().get('player') is 'black' then 'white' else 'black')
			render: ->
				n = game.get 'show_first_n_stones'
				if n isnt null and n >= 0 and n < stone_list.last()?.get('n')
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		forward_btn = new ForwardBtn().render()
		
		BeginningBtn = Backbone.View.extend
			el: $('#buttons #beginning')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
				@start_from = if not game.get('contract').rangzi or game.get('contract').rangzi is 'none' then 0 else Number(game.get('contract').rangzi) - 1
			events:
				click: 'click'
				tap: 'click'
			click: (e)->
				return if check_tap_enabled e
				return if @$el.hasClass 'invalid'
				game.set 'show_first_n_stones', @start_from
				if game.get 'try'
					game.set 'next_trying', (if stone_list.at(@start_from).get('player') is 'black' then 'white' else 'black')
					
			render: ->
				if stone_list.length > @start_from + 1 and (game.get('show_first_n_stones') is null or game.get('show_first_n_stones') > @start_from)
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		beginning_btn = new BeginningBtn().render()
		
		EndingBtn = Backbone.View.extend
			el: $('#buttons #ending')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events:
				click: 'click'
				tap: 'click'
			click: (e)->
				return if check_tap_enabled e
				
				return if @$el.hasClass 'invalid'
				game.set 'show_first_n_stones', null
				if game.get 'try'
					game.set 'next_trying', (if stone_list.last().get('player') is 'black' then 'white' else 'black')
			render: ->
				n = game.get 'show_first_n_stones'
				if n isnt null and n >= 0 and n < stone_list.last()?.get('n')
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		ending_btn = new EndingBtn().render()
		
		BoardView = Backbone.View.extend
			el: $('#gaming-board')
			initialize: ->
				@listenTo stone_list, 'add', @add_stone
				@listenTo stone_list, 'reset', @reset_stones
				@listenTo game, 'change:next', @next_player
				@listenTo regiment_list, 'reset', @show_analysis
				@listenTo game, 'call_finishing_stop', @clear_style
				@listenTo game, 'call_finishing_stop_received', @clear_style
				
				@$el.addClass 'gray' if game.get('status') is 'taking_seat'
			events:
				'click canvas': 'click_board'
				'tap canvas': 'click_board'
			reset_stones: (stones, options)->
				_.each stones.models, (s)=> @add_stone s
			add_stone: (stone)->
				view = new StoneView model:stone
				t = view.render().$el
				@stones.append t
				t.css
					left: @board_canvas.locate(stone.get('pos')[0]) + .5 + @$el.offset().left - t.width()/2
					top: @board_canvas.locate(stone.get('pos')[1]) + .5 + @$el.offset().top - t.height()/2
			reposite: -> 
				@$el.find('ul.stones li').each (i, li)=>
					$(li).css
						left: @board_canvas.locate( Number $(li).attr('x') ) + .5 + @$el.offset().left - $(li).width()/2
						top: @board_canvas.locate( Number $(li).attr('y') ) + .5 + @$el.offset().top - $(li).height()/2
			show_analysis: ->
				if game.is_player()
					stone_list.each (s)->
						if not s.get('repealed')
							tmp = _.find regiment_list.models, (x)-> s.get('n') in x.get('stones')
							s.set 'style', tmp.get('judge') or tmp.get('guess')
				
			click_board: (e)->
				return if check_tap_enabled e
				
				if game.get('show_first_n_stones') and not game.get('try')
					forward_btn.click()
				else if game.is_player() and game.get('calling_finishing')?.msg is 'accept'
					@show_analysis()
					$('#finishing #regiments li').removeClass 'selected'
				else if e.button is 0
					offset = $(e.target).offset()
					pos = @board_canvas.position [e.offsetX ? e.pageX - offset.left - .5, e.offsetY ? e.pageY - offset.top - .5]
					return if not pos
					
					if game.get 'try'
						@trying pos
					else if game.get('players') and game.myself() in game.get('players')
						if game.get('status') is 'started'
							game.move pos:pos, player:game.my_role()
			trying: (pos)->
				if (show_first_n_stones = game.get 'show_first_n_stones')? and show_first_n_stones >= 0
					stone_list.pop() while stone_list.last().get('n') > show_first_n_stones
					game.set 'show_first_n_stones', null
					
				step = pos: pos, player: game.get('next_trying') or game.get('next') or 'black'
				try
					rlt = move_step stone_list.map((s)->s.toJSON()), step
				catch e
					return console.log e.message
				
				if rlt
					taken = _.chain(rlt).pluck('block').flatten().pluck('n').value()
					stone_list.chain().filter((s)->s.get('n') in taken).each (s)->s.set 'repealed', step.n
				stone_list.add step
				game.set 'next_trying', (if step.player is 'black' then 'white' else 'black')
				
			next_player: (model, player)->
				if game.my_role() is player
					@$el.addClass 'your_turn'
				else
					@$el.removeClass 'your_turn'
			clear_style: ->
				stone_list.each (s)->
					if not s.get('repealed')
						s.trigger 'clear_style'		
			render: ->
				@$el.height size = @$el.width()
				@canvas = $('<canvas></canvas>').appendTo(@$el).attr(width: size, height: size)
				@board_canvas = new BoardCanvas @canvas, 
					size:size
					MARGIN: 20
					NINE_POINTS_RADIUS: 3
					black: '#0f1926'
					white: '#fffcf7'
				@board_canvas.render()
				@stones = $('<ul class="stones"></ul>').appendTo @$el
				this
		board = new BoardView().render()
		
		RegimentView = Backbone.View.extend
			initialize: ->
				@listenTo @model, 'change:judge', @change_judge
				@listenTo @model, 'change:my_guess', @render
				@listenTo @model, 'change:opponent_guess', @render
			events:
				'click': 'select_regiment'
				'tap': 'select_regiment'
				'click .guess a': 'guess'
				'tap .guess a': 'guess'
			select_regiment: (e)->
				return if check_tap_enabled e
				stone_list.each (s)=>
					if not s.get('repealed')
						s.set 'style', (if s.get('n') in @model.get('stones') then "selected #{@model.status()}" else false)
				@$el.siblings().removeClass 'selected'
				@$el.addClass 'selected'
			change_judge: (model, v)->
				@render()
				if $("ul.stones li[n='#{@model.get('stones')[0]}']").hasClass('selected')
					@select_regiment()
				else
					board.show_analysis()
			guess: (e)->
				return if check_tap_enabled e
				
				return if $(e.target).hasClass 'selected'
				g = $(e.target).attr 'value'
				game.call_finishing_suggest @model.get('stones')[0], g, =>
					@model.set 'my_guess', g
			render: ->
				if not @model.get('suggests')
					@$el.find(".guess a[value='#{@model.get('guess')}']").addClass 'default'
				if @model.get('my_guess')
					@$el.find('.guess a').removeClass('selected default')
					@$el.find(".guess a[value='#{@model.get('my_guess')}']").addClass('selected')
				if @model.get('opponent_guess')
					@$el.find('.guess a').removeClass('opponent-selected default')
					@$el.find(".guess a[value='#{@model.get('opponent_guess')}']").addClass('opponent-selected')
				if @model.get('judge') is 'disagree'
					@$el.addClass 'disagree'
				else
					@$el.removeClass 'disagree'
				this
			
		BulletinView = Backbone.View.extend
			el: $('#bulletin')
			initialize: ->
				@listenTo game, 'change:next', @next_player
				_.chain(
					connect_failed: 'connect_failed'
					reconnect_failed: 'connect_failed'
					error: 'connect_failed'
					connecting: 'connecting'
					reconnecting: 'connecting'
					disconnect: 'disconnect'
					connected: 'connected'
					reconnect: 'reconnect'
				).pairs().each (x)=>
					@listenTo game, x[0], =>
						@$el.find('.conn').remove()
						@$el.children().hide()
						@$el.append @find_tpl(x[1])() if @find_tpl(x[1])
						
						if x[1] in ['connected', 'reconnect']
							_.delay =>
								if @$el.children().length > 1
									@$el.find('.conn').remove()
									@$el.children().show()
							, 3*1000
				
				@listenTo game, 'retract', @retract
				@listenTo game, 'call_finishing_ask', => @show_tpl 'call_finishing_ask'
				@listenTo game, 'player_confirmed_ending', (rlt)=> @show_tpl 'status_ended', result:rlt
				@listenTo game, 'call_finishing_ask_received', @call_finishing_ask_received
				#@listenTo game, 'taking_seat', (msg)=> @show_tpl 'taking_seat' if msg is 'start'
				@listenTo regiment_list, 'reset', @show_analysis
				@listenTo game, 'call_finishing_stop', =>
					if game.is_player()
						if game.my_role() is game.get('next')
							@show_tpl 'call_finishing_stop_move'
						else
							@show_tpl 'call_finishing_stop_wait'
				@listenTo game, 'call_finishing_stop_received', =>
					if game.is_player()
						if game.my_role() is game.get('next')
							@show_tpl 'call_finishing_stop_received_move'
						else
							@show_tpl 'call_finishing_stop_received_wait'
				
				_.chain(
					call_finishing_cancel: 'started_please_move'
					call_finishing_reject: 'call_finishing_reject'
				).pairs().each (x)=>
					@listenTo game, x[0], => @show_tpl x[1]
				
				@listenTo game, 'call_finishing_cancel_received', (player)=> @show_tpl 'call_finishing_cancel_received', player:player
				@listenTo game, 'call_finishing_reject_received', (player)=> 
					if game.is_player()
						@show_tpl 'call_finishing_reject_received'
					else
						@show_tpl 'call_finishing_reject_received_others', player:player
				
				
				@listenTo game, 'change:try', (m, v)=>
					if v
						@$el.hide()
					else
						@$el.show()
				@listenTo game, 'change:status', (m, v)=>
					console.log v
					switch v
						when 'started'
							@next_player game.get('next')
						when 'taking_seat'
							@show_tpl 'taking_seat'
				
				@listenTo regiment_list, 'change:judge', @show_analysis_confirm
				
				if game.get('status') in ['init', 'taking_seat'] and game.get('players')?.length is 1
					if game.myself() is game.get('players')[0]
						@show_tpl 'init_waiting'
					else
						@show_tpl 'init_attending'
				else if game.get('status') is 'taking_seat'
					if game.myself() and game.myself() in game.get('players')
						@show_tpl 'taking_seat'
					else
						@show_tpl 'taking_seat_others'
				else if game.get('status') is 'ended'
					@show_tpl 'status_ended', result:data.game.result
				
			call_finishing_ask_received: (player)->
				if game.is_player()
					@show_tpl 'call_finishing_ask_received'
				else
					@show_tpl 'call_finishing_ask_received_others', player:player
			show_analysis: (regiment_list)->
				if game.is_player()
					@show_tpl 'call_finishing_accept'
					@$el.find('#stop_calling_finishing').click => game.call_finishing_stop()
					regiment_tpl = tpl '#bulletin-tpls #regiment-tpl'
					regiment_list.each (x)=>
						new RegimentView(
							model: x
							el: $(regiment_tpl data:x.toJSON(), opponent:game.opponent(), myself:game.myself()).appendTo(@$el.find('#regiments'))
						).render()
					@show_analysis_confirm()
					
					@$el.find('#confirm').click =>
						game.call_finishing_confirm (rlt)=>
							if rlt
								@show_tpl 'status_ended', result:rlt
							else
								@$el.find('#confirm').hide()
								@$el.find('#confirmed').show()
					
					if game.get('last_action')?.suggest_confirm?[game.my_role()]
						@$el.find('#confirm').hide()
					else
						@$el.find('#confirmed').hide()
				else
					@show_tpl 'call_finishing_accept_received_others'
			show_analysis_confirm: ->
				if regiment_list.some((x)-> x.get('judge') is 'disagree')
					@$el.find('#confirm').hide()
					@$el.find('#confirmed').show()
				else
					@$el.find('#confirm').show()
					@$el.find('#confirmed').hide()
					
			find_tpl: (name)->
				@tpls ?= {}
				@tpls[name] ?= tpl "#bulletin-tpls script[name='#{name}']"
			show_tpl: (name, params)-> 
				@$el.empty().append @find_tpl(name)(_.defaults (params ? {}), data:data) if @find_tpl(name)
				switch name
					when 'started_please_move'
						$('#call-finishing').click -> game.call_finishing_ask()
					when 'started_please_wait'
						$('#retract').click -> game.retract()
					when 'taking_seat'
						$('.taking_seat a').click -> 
							game.taking_seat $(this).attr('_type')
					when 'call_finishing_ask'
						@$el.find('#call_finishing_cancel').click => game.call_finishing_cancel()
					when 'call_finishing_ask_received'
						@$el.find('#reject_calling_finishing').click => game.call_finishing_reject()
						@$el.find('#accept_calling_finishing').click => game.call_finishing_accept()
			next_player: ->
				if arguments.length is 1
					[player] = arguments
				else
					[model, player] = arguments
				
				if game.is_player()
					if game.my_role() is player
						@show_tpl 'started_please_move'
					else
						@show_tpl 'started_please_wait'
				else
					@show_tpl 'next_player', next:player
			retract: (stone)->
				if game.is_player()
					if game.my_role() is stone.player
						@show_tpl 'started_please_move'
					else
						@show_tpl 'retract_by_opponent'
				else
					console.log 'retracted'
				
		bulletin = new BulletinView().render()
		
		BulletinLocalView = Backbone.View.extend
			el: $('#bulletin-local')
			initialize: ->
				if not game.get 'try'
					@$el.hide()
				@listenTo game, 'change:try', (m, v)=>
					if v
						@$el.show()
						@show_tpl 'start_trying', next:game.get('next') or 'black'
					else
						@$el.hide()
				@listenTo game, 'change:next_trying', (m, v)=> @show_tpl 'start_trying', next:v
			show_tpl: (name, params)->
				params = if params
					_.defaults params, data:data
				else
					data:data
				@$el.empty().append tpl("#bulletin-local-tpls script[name='#{name}']")(params)
				
		bulletin_local = new BulletinLocalView
		
		ShowNumBtn = Backbone.View.extend
			el: $('#buttons #num_btn')
			events:
				click: 'show_num'
				tap: 'show_num'
			show_num: (e)->
				return if check_tap_enabled e
				@$el.toggleClass 'show_num'
				game.set 'show_num', not @$el.hasClass('show_num')
			render: ->
				@$el.addClass 'show_num'
		show_num_btn = new ShowNumBtn().render()
		
		TryBtn =  Backbone.View.extend
			el: $('#try')
			events:
				click: 'click'
			click: (e)->
				@$el.toggleClass 'trying'
				game.set 'try', not game.get('try')
				if @$el.hasClass 'trying'
					@$el.find('span').text @$el.attr('try_done_btn')
					game.set 'stones_before_try', stone_list.map((s)->s.toJSON())
				else
					@$el.find('span').text @$el.attr('try_btn')
					stone_list.reset game.get 'stones_before_try'
					game.unset 'next_trying'
				
		try_btn = new TryBtn
		
		stone_list.reset game.get 'moves'
		game.trigger 'change:next', game, game.get('next') if game.get('status') is 'started'
		if game.get('status') isnt 'ended'
			game.connect (err)->
				return if err
				
				if cf = game.get 'calling_finishing'
					switch cf.msg
						when 'ask'
							if not game.is_player()
								bulletin.call_finishing_ask_received (game.role_of_player cf.uid)
							else if cf.uid is game.myself()
								game.trigger 'call_finishing_ask'
							else
								game.trigger 'call_finishing_ask_received'
						when 'accept'
							if game.is_player() and cf.uid is game.myself()
								game.trigger 'call_finishing_accept', game.get('analysis')
							else
								game.trigger 'call_finishing_accept_received', game.get('analysis')
				
		
		$(window).on 'resize', -> board.reposite()
		
		_.each data.game.players, (p)->
			$('#about-players').append tpl('#player_desc_tpl') player:data.refs[p]
			
		if data.myself
			$('aside').append tpl('#publish_tpl')()
			CommentChartList = Backbone.Collection.extend
				model: Backbone.Model
			comment_chart_list = new CommentChartList
			CommentPublishView = Backbone.View.extend
				el: $('#pub')
				initialize: ->
					@listenTo comment_chart_list, 'add', (ss)=> @render_chart ss
					@listenTo comment_chart_list, 'remove', @remove_chart
					@listenTo comment_chart_list, 'reset', => 
						@$el.find('#ss .ss').remove()
						@$el.find('#ss em').hide()
				events:
					'click #submit': 'submit'
					'click #cancel': 'cancel'
					'click #add_chart': 'add_chart'
					'focus textarea': 'start_commenting'
				start_commenting: ->
					return if game.get('step_to_comment')?
					step = \
					if game.get 'try'
						if game.get('stones_before_try').length then game.get('stones_before_try')[game.get('stones_before_try').length-1].n else 0
					else
						game.get('show_first_n_stones') or stone_list.last()?.get('n') or 0
						
					game.set 'step_to_comment', step
				cancel: (e)->
					game.unset 'step_to_comment'
					comment_chart_list.reset()
					@$el.find('textarea').val ''
				submit: (e)->
					return console.log "step_to_comment n/a" if not game.get('step_to_comment')?
					text = @$el.find('textarea').val()
					return if not text || text is ''
					
					comment =
						step: game.get 'step_to_comment'
						text: text
					comment.ss = comment_chart_list.map((x)->x.toJSON()) if comment_chart_list.length
					game.send_comment comment
					@cancel()
				add_chart: (e)->
					ss = game.snapshot()
					idx = @$el.find('#ss .ss').length + 1
					ss.name = "[#{idx}]"
					comment_chart_list.add ss
					@$el.find('textarea').val @$el.find('textarea').val() + ss.name
					@$el.find('#ss em').show()
				render: ->
					@$el.find('#ss em').hide()
					this
				render_chart: (ss)->
					moves = data.refs[ss.get 'gid'].moves[0...ss.get('from')]
					if (not moves or moves.length < ss.get('from')) and game.get('id') is ss.get('gid')
						moves = if game.get('try')
							game.get('stones_before_try')
						else
							stone_list.map((s)->s.toJSON())
						moves = moves[0...ss.get('from')]
					moves = _.chain(moves).reject((x)->
						_.find ss.get('moves'), (y)-> x.n is y.n
					).union(ss.get 'moves').value()
					div = $("<div class='ss'></div>").appendTo(@$el.find('#ss')).data('ss', ss).click ->
						comment_chart_list.remove $(this).data('ss')
						
					new BoardCanvas(div, size:150).render(moves)
				remove_chart: (ss)->
					$(_.find @$el.find('#ss .ss').toArray(), (x)->$(x).data('ss') is ss)?.remove()
					@$el.find('textarea').val @$el.find('textarea').val().replace(ss.get('name'), '')
					if not @$el.find('#ss .ss').length
						@$el.find('#ss em').hide()
					
			comment_publish = new CommentPublishView().render()
			return
			_.delay ->
				$('#back').click()
				$('#back').click()
				
				comment_publish.$el.find('textarea').focus()
				comment_publish.$el.find('textarea').val 'test: '
				$('#try').click()
				board.trying [0, 17]
				board.trying [0, 18]
				$('#add_chart').click()
				
				return
				$('#try').click()
				$('#back').click()
				$('#back').click()
				board.trying [0, 17]
				board.trying [0, 18]
				$('#add_chart').click()
				
				board.trying [1, 18]
				$('#back').click()
				board.trying [1, 17]
				$('#add_chart').click()
				
				$('#ss .ss').first().click()
				console.log comment_publish.$el.find('textarea').val()
				
				comment_publish.$el.find('#submit').click()
				#$('#previous_comments').click()
			, 2000
