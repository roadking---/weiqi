class BasicBoard
	constructor: (@board, @opts)->
		@opts = _.defaults @opts ? {}, size:600, margin:20, NINE_POINTS_RADIUS:3, PAWN_RADIUS: 12
		@LINES = 19
		
		@initial = @board.data('game') ? JSON.parse @board.attr 'game'
		
		@board.data 'data', this
		
	locate: (n)-> Math.round @opts.margin + @interval * n
	on_next_player: (player)->
		@initial.next = player
		@board.attr 'next', player
	redraw: ->
	is_player: -> @board.attr('iam') is 'player'
	uid: -> @board.attr('uid')
	next: -> @board.attr('next')
	seat: -> @board.attr('seat')
class window.CanvasBoard extends BasicBoard
	constructor: (@board, @opts)->
		super @board, @opts
		@opts.click ?= true
		@opts.black ?= '#0f1926'
		@opts.white ?= '#fffcf7'
		@canvas = @board.find('canvas.draw')	
		@canvas.attr width: @opts.size, height: @opts.size
		@canvas.css width: @opts.size, height: @opts.size
		@interval = (@canvas.height() - 2 * @opts.margin)/(@LINES-1)
		@ctx = @canvas[0].getContext("2d")
		@on_next_player @next()
		@show_number = @board.find('#num_btn i').hasClass 'show-number'
		@show_steps_to = null
		
		
		if @opts.click
			@canvas.click (e)=>
				if e.button is 0
					offset = $(e.target).offset()
					x = e.offsetX ? e.pageX - offset.left - .5
					y = e.offsetY ? e.pageY - offset.top - .5
					
					[x, y] = _.map [x, y], (num)=>
						num = (num - @opts.margin) / @interval
					[xx, yy] = _.map [x, y], (num)=>
						num = 0 if num < 0
						num = 18 if num > 18
						if 2* num >= Math.ceil(num) + Math.floor(num) then Math.ceil num else Math.floor num
					if Math.pow(x - xx, 2) + Math.pow(y - yy, 2) < Math.pow(.4, 2)
						@on_click [xx, yy]
					else
						1
		@redraw()

	on_next_player: (player)->
		super player
		if @is_player() and @next() is @seat()
			@canvas.addClass 'your_turn'
		else
			@canvas.removeClass 'your_turn'

	circle: (x, y, radius, fill_color, stroke_color='black')->
		x += .5
		y += .5
		@ctx.fillStyle = fill_color ? 'black'
		@ctx.strokeStyle = stroke_color
		@ctx.lineWidth = 1
		
		@ctx.beginPath()
		@ctx.arc x, y, radius, 0, Math.PI*2, false
		@ctx.closePath()
		@ctx.fill() if fill_color
		@ctx.stroke() if stroke_color
	
	draw_stone: (pos, player, style)->
		@circle @locate(pos[0]), @locate(pos[1]), @opts.PAWN_RADIUS, (if player is 'black' then @opts.black else @opts.white), @opts.black
		if style is 'wreath'
			@circle @locate(pos[0]), @locate(pos[1]), @opts.PAWN_RADIUS*.75, null, (if player is 'black' then @opts.white else @opts.black)
		else if _.isObject(style) and style.text
			@ctx.font = '12px Arial'
			@ctx.strokeStyle = if player is 'black' then @opts.white else @opts.black
			if _.isNumber style.text
				adjust = if style.text < 10
					[-3, 4]
				else
					[-7, 4]
			@ctx.strokeText style.text, @locate(pos[0]) + adjust[0], @locate(pos[1]) + adjust[1]	
		
	place: (move)->
		text = move.n + 1 if @show_num
		if text
			@draw_stone move.pos, move.player, {text:text}
		else if move.n is @status_quo().step
			@draw_stone move.pos, move.player, 'wreath'
		else
			@draw_stone move.pos, move.player
			
	draw_board: ->
		@ctx.lineCap = 'round'
		@ctx.lineJoin = 'round'
		@ctx.lineWidth = .5
		
		@ctx.clearRect 0, 0, @opts.size, @opts.size
		@ctx.fillStyle = @opts.BACKGROUND_COLOR ? 'rgba(0, 0, 0, 0)'
		@ctx.rect 0, 0, @opts.size, @opts.size
		@ctx.fill()
		
		@ctx.fillStyle = @ctx.strokeStyle = @opts.LINE_COLOR ? 'black'
		@ctx.rect @opts.margin, @opts.margin, @opts.size - 2*@opts.margin, @opts.size - 2*@opts.margin
		
		@ctx.beginPath()
		_.each [0..@LINES-1], (n)=>
			@ctx.moveTo @locate(n)+.5, @locate(0)
			@ctx.lineTo @locate(n)+.5, @locate(@LINES-1)
			@ctx.stroke()
			
			#horizontal
			@ctx.moveTo @locate(0), @locate(n)+.5
			@ctx.lineTo @locate(@LINES-1), @locate(n)+.5
			@ctx.stroke()
		
		_.each [
			[3, 3]
			[3, 9]
			[3, 15]
			[9, 9]
			[9, 3]
			[9, 15]
			[15, 3]
			[15, 9]
			[15, 15]
		], (x)=> @circle @locate(x[0]), @locate(x[1]), @opts.NINE_POINTS_RADIUS, @opts.NINE_POINTS_COLOR ? 'black', @opts.NINE_POINTS_COLOR ? 'black'
		
	status_quo: ->
		step: @show_steps_to ? @initial.moves.length - 1
	
	redraw: (opts)->
		@ctx.fillStyle = 'white'
		@ctx.fillRect 0, 0, @opts.size, @opts.size
		@draw_board()
		
		if @initial.moves
			num = @status_quo().step
			_.each @initial.moves, (x)=>
				if x.n <= num and (not x.repealed or x.repealed > num)
					opts?.before_place? x
					@place x
					opts?.after_place? x
			
	on_click: (pos)-> console.log pos

class window.Board extends CanvasBoard
	constructor: (@board, @opts)->
		super @board, @opts
		@try_mode = false
		
	go_to_beginning: ->
		num = @show_steps_to ? @initial.moves.length - 1
		return if num < 0
		@show_steps_to = -1
		@redraw()
		@on_show_steps @show_steps_to
	go_to_ending: ->
		num = @show_steps_to ? @initial.moves.length - 1
		return if num >= @initial.moves.length - 1
		@show_steps_to = null
		@redraw()
		@on_show_steps @initial.moves.length - 1
	go_back: ->
		num = @show_steps_to ? @initial.moves.length - 1
		return if num < 0
		@show_steps_to = num - 1
		@redraw()
		@on_show_steps @show_steps_to
	go_forward: ->
		num = @show_steps_to ? @initial.moves.length - 1
		if num >= @initial.moves.length - 1
			@show_steps_to = null
		else
			@show_steps_to = num + 1
			@redraw()
			@show_steps_to = null if num >= @initial.moves.length - 1
			@on_show_steps @show_steps_to ? @initial.moves.length - 1
	toggle_num_shown: ->
		@show_num = not @show_num
		@redraw()
	
	get_moves: ->
		current: @initial.moves
		step: @show_steps_to ? @initial.moves.length - 1
	
	on_show_steps: (step)-> 

class window.PlayBoard extends window.Board
	calc_move: (m)->
		if blocks = move_step @initial.moves, m
			@redraw()
			m.taken = _.pluck blocks, 'block'
	
	on_click: (pos, player)->
		player ?= @next()
		m =
			pos: pos
			player: player
			n: if @initial.moves then @initial.moves.length else 0
		@calc_move m
		@place m
		@on_next_player if player is 'black' then 'white' else 'black'
		@redraw()

class window.ConnectedBoard extends window.PlayBoard
	constructor: (@board, @opts)->
		super @board, @opts
		@connect()
		
		if @board.attr('status') is 'taking_seat' and @is_player()
			$('#seats').show()
			$('#seats .item a').click =>
				if $(this).hasClass 'none'
					$('#seats .item a.mine').removeClass('mine').addClass('none').text 'none'
					@board.attr 'seat', $(this).attr('seat')
					@socket.emit 'taking_seat', $(this).attr('seat'), (res)=> console.log 'taking_seat: ' + JSON.stringify res
					$(this).removeClass('none').addClass('mine').text 'Me'
		
	init_socket: (cb)->
		@socket.emit 'auth', $.cookie('auth') ? 'anonymous', (res)=>
			@socket.emit 'room', @board.attr('socket')
			cb? console.log res
		_.delay =>
			if not @connected
				cb? new Error 'fail to connect'
		, 20*1000
		
	connect: (cb)->
		console.log 'try connect'
		@socket = io.connect "http://#{location.hostname}/weiqi"
		@socket.on 'connect_failed', =>@on_connect_failed()
		@socket.on 'reconnect_failed', =>@on_connect_failed()
		@socket.on 'error', => console.log arguments
		@socket.on 'connecting', =>@on_connecting()
		@socket.on 'reconnecting', =>@on_connecting()
		@socket.on 'reconnect', =>@on_reconnect()
		@socket.on 'disconnect', =>@on_disconnect() if @on_disconnect
		@socket.on 'attend', (res)=>
			console.log 'attend: ' + JSON.stringify res
			if @initial.status is 'need_player'
				@board.attr 'status', 'started'
				@on_resume?()
		@socket.on 'quit', @on_quit if @on_quit
		@socket.on 'taking_seat', (res)=>
			console.log 'taking_seat'
			if res is 'start'
				@board.attr 'status', 'taking_seat'
				@on_start_taking_seat?()
			else
				@on_seats_update? res
		@socket.on 'start', (seats, next)=>
			console.log 'start: ' + JSON.stringify [seats, next]
			@board.attr 'status', 'started'
			
			@on_next_player next
			@on_start? seats, next
		@socket.on 'move', (moves, next)=>
			console.log 'move: ' + JSON.stringify(moves)
			_.each moves, (x)=> 
				@calc_move x
				@place x
			@on_next_player next
			@redraw()
			@on_move? moves, next
		@socket.on 'player_disconnect', (player)=> console.log 'player_disconnect ' + player
		@socket.on 'comment', =>@on_comment()
		@socket.on 'retract', (uid)=> 
			console.log 'retract ' + uid
			retract @initial.moves
			@on_next_player if @next() is 'black' then 'white' else 'black'
			@redraw()
			@on_retract? uid
		@socket.on 'surrender', (uid)->
			console.log 'surrender ' + uid
			@on_surrender? uid
		@socket.on 'call_finishing', @on_call_finishing
		
		@init_socket =>
			@on_connect?()
	taking_seat: (seat, cb)->
		@test_connection =>
			@socket?.emit 'taking_seat', seat, (res)=>
				console.log 'taking_seat: ' + JSON.stringify res
				cb? res
	withdraw: ->
		return if not @initial.moves?.length
		
		last_player = @initial.moves[@initial.moves.length-1].player
		retract @initial.moves
		@on_next_player last_player
		@redraw()
		
	move: (pos, player)->
		move={pos:pos, player:player}
		sent = false
		
		@socket?.emit 'move', move, (res)=>
			console.log 'move: ' + JSON.stringify res
			sent = true
			if res.fail
				@withdraw()
			else
				@on_next_player res.next if res.next
		
	on_connect: ->
		@connected = true
		
	on_reconnect: ->
		@connected = true
		@init_socket()
		#console.log @socket.$events
		#@socket.emit 'room', @board.attr('socket')
	on_disconnect: ->
		@connected = false
	on_connect_failed: ->
		@connected = false
		console.log 'connect_failed'
	on_connecting: ->
	on_start_taking_seat: null
	on_seats_update: null
	on_quit: null
	on_start: null
	on_resume: null
	on_move: null
	on_retract: ->
	retract: ->
		if @is_player() and @initial.moves.length and @next() isnt @seat()
			@test_connection =>
				@socket.emit 'retract', (data)=>
					if data is 'success'
						@withdraw()
						@mine_retract?()
	mine_retract: null
	on_surrender: null
	test_connection: (cb)->
		((cb)=>
			if @connected
				cb()
			else
				@connect cb
		) cb
	on_click: (pos, player)->
		if @board.attr('status') is 'started' and @is_player() and @next() is @seat()
			try
				super pos, player
				@test_connection (err)=>
					if err
						console.log err
					else
						@move pos, @seat()
			catch	e
				console.log e
				
	send_comment: (gid, comment, cb)->
		console.log comment
		@socket?.emit 'comment', gid, comment, cb
	on_comment: (comment)-> console.log comment
	call_finishing: (msg)->
		switch msg
			when 'ask', 'cancel'
				[msg, cb] = arguments
				if @is_player() and @next() is @seat()
					@test_connection (err)=>
						return console.log err if err
						@socket.emit 'call_finishing', msg, cb
				else
					cb 'not your turn'
			when 'reject', 'accept', 'stop'
				[msg, cb] = arguments
				@test_connection (err)=>
					return console.log err if err
					@socket.emit 'call_finishing', msg, cb
			when 'suggest'
				console.log [msg, stone, suggest, cb] = arguments
				@test_connection (err)=>
					return console.log err if err
					@socket.emit 'call_finishing', msg, stone, suggest, cb
	on_call_finishing: (msg)->
		console.log msg
		