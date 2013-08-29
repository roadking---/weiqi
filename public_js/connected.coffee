return if not gid = /game\/(.+)$/.exec(location.pathname)?[1]

$.get "/json/connected/#{gid}", (data)->
	console.log data
	init_header data
	
	$ ->
		Stone = Backbone.Model.extend
			defaults:
				show_num: false
				last: true
		StoneList = Backbone.Collection.extend
			model: Stone
		
		stone_list = new StoneList
		stone_list.on 'reset', (models)->
			_.each models.initial(), (x)-> x.set 'last', false
		stone_list.on 'add', (model, collection)->
			model.set 'last', true
			collection.at(collection.length-2)?.set 'last', false
		stone_list.on 'remove', (model, collection)->
			collection.at(collection.length-1)?.set 'last', true
		
		Game = Backbone.Model.extend
			idAttribute: 'n'
			defaults: ->
				_.defaults data.game,
					show_num: false
					connected: false
					show_first_n_stones: null
			myself: -> data.user
			is_player: -> data.user and @get('players') and data.user in @get('players')
			my_role: ->
				if @is_player() and @get('seats')
					_.invert(@get('seats'))[data.user]
			opponent: ->
				if @is_player()
					_.without(@get('players'), data.user)[0]
			connect: (cb)->
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
					@socket.on 'move', (next, step, taken)=>
						@move next, step, taken
					
					@socket.on 'retract', (uid)=> 
						console.log 'retract ' + uid
						@retract true
					
					@socket.on 'call_finishing', (msg)=>
						switch msg
							when 'ask'
								@trigger 'call_finishing_ask_received'
							when 'cancel'
								@trigger 'call_finishing_cancel_received'
							when 'reject'
								@trigger 'call_finishing_reject_received'
							when 'accept'
								[msg, analysis] = arguments
								@trigger 'call_finishing_accept_received', analysis
							when 'stop'
								@unset 'calling_finishing'
								@trigger 'call_finishing_stop_received'
							when 'suggest'
								[msg, stone_in_regiment, suggest] = arguments
								@trigger 'call_finishing_suggest_received', stone_in_regiment, suggest
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
						@test_connection (err)=>
							@socket?.emit 'move', step, (res)=>
								console.log 'move: ' + JSON.stringify res
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
					if stone = stone_list.pop()
						stone.trigger 'retract'
						stone_list.chain().filter((x)-> x.get('repealed') is stone.get('n')).each (x)->x.unset 'repealed'
						game.set 'next', stone.get('player'), silent:true
						@trigger 'retract', stone
				else
					if @is_player() and @my_role() is stone_list.last()?.get('player')
						@test_connection =>
							@socket.emit 'retract', (data)=>
								if data is 'success'
									console.log 'retract'
									@retract true
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
			initialize: ->
				@on 'change:show_num', (m, v)-> stone_list.each (x)-> x.set 'show_num', v
				@on 'call_finishing_accept', (analysis)=> @set 'analysis', analysis
				@on 'call_finishing_accept_received', (analysis)=> @set 'analysis', analysis
				@on 'change:show_first_n_stones', (m, v)=>
					v ?= stone_list.last()?.get 'n'
					return if not v?
					stone_list.each (x)->
						if x.get('n') > v
							x.set 'hide', true
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
		game = new Game
		
		###
		game.on 'call_finishing_accept', (analysis)-> game.set 'analysis', analysis
		game.on 'call_finishing_accept_received', (analysis)-> game.set 'analysis', analysis
		game.on 'change:show_first_n_stones', (m, v)->
			v ?= stone_list.last()?.get 'n'
			return if not v?
			stone_list.each (x)->
				if x.get('n') > v
					x.set 'hide', true
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
		###
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
		regiment_list = new RegimentList
		regiment_list.listenTo game, 'call_finishing_accept', tmp =(analysis)->
			regiment_list.reset analysis
		regiment_list.listenTo game, 'call_finishing_accept_received', tmp
		
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
				
			render: ->
				@$el.html(@model.get('n')).addClass(@model.get 'player').attr
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
			el: $('#toolbox #back')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events: 
				click: 'click'
			click: ->
				return if @$el.hasClass 'invalid'
				n = game.get 'show_first_n_stones'
				n ?= stone_list.last()?.get('n')
				if n
					game.set 'show_first_n_stones', n-1
			render: ->
				n = game.get 'show_first_n_stones'
				if n and n > 0 or n is null and stone_list.length > 1
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		back_btn = new BackBtn().render()
		
		ForwardBtn = Backbone.View.extend
			el: $('#toolbox #forward')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events: 
				click: 'click'
			click: ->
				return if @$el.hasClass 'invalid'
				n = game.get 'show_first_n_stones'
				if n >= 0
					if n + 1 < stone_list.last()?.get('n')
						game.set 'show_first_n_stones', n + 1
					else
						game.set 'show_first_n_stones', null
			render: ->
				n = game.get 'show_first_n_stones'
				if n isnt null and n >= 0 and n < stone_list.last()?.get('n')
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		forward_btn = new ForwardBtn().render()
		
		BeginningBtn = Backbone.View.extend
			el: $('#toolbox #beginning')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events:
				click: 'click'
			click: ->
				return if @$el.hasClass 'invalid'
				game.set 'show_first_n_stones', 0
			render: ->
				if stone_list.length > 1 and (game.get('show_first_n_stones') is null or game.get('show_first_n_stones') > 0)
					@$el.removeClass 'invalid'
				else
					@$el.addClass 'invalid'
				this
		beginning_btn = new BeginningBtn().render()
		
		EndingBtn = Backbone.View.extend
			el: $('#toolbox #ending')
			initialize: ->
				@listenTo stone_list, 'reset', @render
				@listenTo game, 'change:show_first_n_stones', @render
			events:
				click: 'click'
			click: ->
				return if @$el.hasClass 'invalid'
				game.set 'show_first_n_stones', null
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
			events:
				'click canvas': 'click_board'
			reset_stones: (stones)->
				_.each stones.models, (s)=> @add_stone s
			add_stone: (stone)->
				view = new StoneView model:stone
				t = view.render().$el
				@stones.append t
				t.css
					left: @board_canvas.locate(stone.get('pos')[0]) + .5 + @$el.offset().left - t.width()/2
					top: @board_canvas.locate(stone.get('pos')[1]) + .5 + @$el.offset().top - t.height()/2
			show_analysis: ->
				stone_list.each (s)->
					if not s.get('repealed')
						tmp = _.find regiment_list.models, (x)-> s.get('n') in x.get('stones')
						s.set 'style', tmp.get('judge') or tmp.get('guess')
				
			click_board: (e)->
				if game.get('show_first_n_stones')
					forward_btn.click()
				else if game.is_player() and game.get('calling_finishing')?.msg is 'accept'
					@show_analysis()
				else if e.button is 0
					offset = $(e.target).offset()
					pos = @board_canvas.position [e.offsetX ? e.pageX - offset.left - .5, e.offsetY ? e.pageY - offset.top - .5]
					return if not pos
					
					if game.get('players') and data.user in game.get('players')
						if game.get('status') is 'started'
							console.log pos
							game.move pos:pos, player:game.my_role()
			next_player: (model, player)->
				if game.my_role() is player
					@canvas.addClass 'your_turn'
				else
					@canvas.removeClass 'your_turn'
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
				'click .guess a': 'guess'
			select_regiment: ->
				stone_list.each (s)=>
					if not s.get('repealed')
						s.set 'style', (if s.get('n') in @model.get('stones') then "selected #{@model.status()}" else false)
			change_judge: (model, v)->
				@render()
				if $("ul.stones li[n='#{@model.get('stones')[0]}']").hasClass('selected')
					@select_regiment()
				else
					board.show_analysis()
			guess: (e)->
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
				@listenTo game, 'call_finishing_ask', @call_finishing_ask
				@listenTo game, 'call_finishing_ask_received', @call_finishing_ask_received
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
					call_finishing_cancel_received: 'call_finishing_cancel_received'
					call_finishing_reject: 'call_finishing_reject'
					call_finishing_reject_received: 'call_finishing_reject_received'
				).pairs().each (x)=>
					@listenTo game, x[0], => @show_tpl x[1]
				
				@listenTo regiment_list, 'change:judge', @show_analysis_confirm
				
			call_finishing_ask: ->
				@show_tpl 'call_finishing_ask'
				@$el.find('#call_finishing_cancel').click => game.call_finishing_cancel()
			call_finishing_ask_received: ->
				@show_tpl 'call_finishing_ask_received'
				@$el.find('#reject_calling_finishing').click => game.call_finishing_reject()
				@$el.find('#accept_calling_finishing').click => game.call_finishing_accept()
			show_analysis: (regiment_list)->
				@show_tpl 'call_finishing_accept'
				@$el.find('#stop_calling_finishing').click => game.call_finishing_stop()
				regiment_tpl =tpl '#bulletin-tpls #regiment-tpl'
				regiment_list.each (x)=>
					new RegimentView(
						model: x
						el: $(regiment_tpl data:x.toJSON(), opponent:game.opponent(), myself:game.myself()).appendTo(@$el.find('#regiments'))
					).render()
				@show_analysis_confirm()
			show_analysis_confirm: ->
				if regiment_list.some((x)-> x.get('judge') is 'disagree')
					@$el.find('#confirm').hide()
				else
					@$el.find('#confirm').show()
					
			find_tpl: (name)->
				@tpls ?= {}
				@tpls[name] ?= tpl "#bulletin-tpls script[name='#{name}']"
			show_tpl: (name)-> 
				#console.log name
				@$el.empty().append @find_tpl(name)() if @find_tpl(name)
			next_player: (model, player)->
				@show_tpl \
				if game.is_player()
					if game.my_role() is player
						'started_please_move'
					else
						'started_please_wait'
			retract: (stone)->
				if game.is_player()
					if game.my_role() is stone.get('player')
						@show_tpl 'started_please_move'
					else
						@show_tpl 'retract_by_opponent'
				console.log 'on retract'
		bulletin = new BulletinView().render()
		
		RetractBtn = Backbone.View.extend
			el: $('#toolbox #retract')
			events:
				click: 'retract'
			initialize: ->
				@listenTo game, 'change:next', @render
				@listenTo game, 'retract', @render
			render: ->
				if game.is_player()
					if game.my_role() is game.get('next')
						@$el.addClass 'invalid'
					else
						@$el.removeClass 'invalid'
				else
					@$el.hide()
			retract: ->
				return if @$el.hasClass 'invalid'
				game.retract()
		retract_btn = new RetractBtn().render()
		
		
		ShowNumBtn = Backbone.View.extend
			el: $('#toolbox #num_btn')
			events:
				click: 'show_num'
			show_num: ->
				@$el.toggleClass 'show_num'
				game.set 'show_num', not @$el.hasClass('show_num')
			render: ->
				@$el.addClass 'show_num'
		show_num_btn = new ShowNumBtn().render()
		
		
		CallFinishingBtn = Backbone.View.extend
			el: $('#toolbox #call-finishing')
			events:
				click: 'call_finishing_ask'
			initialize: ->
				@listenTo game, 'change:next', @render
				@listenTo game, 'call_finishing_reject_received', => @$el.addClass 'invalid'
				@listenTo game, 'call_finishing_stop', => @$el.addClass 'invalid'
				@listenTo game, 'call_finishing_stop_received', => @$el.addClass 'invalid'
				
			call_finishing_ask: ->
				console.log 'call'
				game.call_finishing_ask()
			render: ->
				if game.is_player()
					if game.get('next') is game.my_role()
						@$el.removeClass 'invalid'
					else
						@$el.addClass 'invalid'
				else
					@$el.hide()
		call_finishing_btn = new CallFinishingBtn().render()
		
		stone_list.reset game.get 'moves'
		game.trigger 'change:next', game, game.get('next')
		game.connect (err)->
			return if err
			if game.is_player() and cf = game.get 'calling_finishing'
				switch cf.msg
					when 'ask'
						if cf.uid is data.user
							game.trigger 'call_finishing_ask'
						else
							game.trigger 'call_finishing_ask_received'
					when 'accept'
						if cf.uid is data.user
							game.trigger 'call_finishing_accept', game.get('analysis')
						else
							game.trigger 'call_finishing_accept_received', game.get('analysis')
			
			