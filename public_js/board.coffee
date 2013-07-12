class BasicBoard
	constructor: (@board, @opts)->
		@opts = _.defaults @opts ? {}, size:600, margin:20, NINE_POINTS_RADIUS:3, PAWN_RADIUS: 12
		@LINES = 19
		
		@initial = @board.data('game') ? JSON.parse @board.attr 'game'
		@change_to_next @board.attr 'next'
		@board.data 'data', this
		
	locate: (n)-> Math.round @opts.margin + @interval * n
	change_to_next: (player)->
		@initial.next = player
		@board.attr 'next', player
		@board.find(".players .next").removeClass 'next'
		@board.find(".players .#{player}").addClass 'next'
	redraw: ->

class window.CanvasBoard extends BasicBoard
	constructor: (@board, @opts)->
		super @board, @opts
		@opts.click ?= true
		@canvas = @board.find('canvas.draw')	
		@canvas.attr width: @opts.size, height: @opts.size
		@canvas.css width: @opts.size, height: @opts.size
		@interval = (@canvas.height() - 2 * @opts.margin)/(@LINES-1)
		@ctx = @canvas[0].getContext("2d")
		
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
	
	draw_pawn: (pos, player, style)->
		@circle @locate(pos[0]), @locate(pos[1]), @opts.PAWN_RADIUS, player
		if style is 'wreath'
			@circle @locate(pos[0]), @locate(pos[1]), @opts.PAWN_RADIUS*.75, null, (if player is 'black' then 'white' else 'black')
		else if _.isObject(style) and style.text
			@ctx.font = '12px Arial'
			@ctx.strokeStyle = if player is 'black' then 'white' else 'black'
			if _.isNumber style.text
				adjust = if style.text < 10
					[-3, 4]
				else
					[-7, 4]
			@ctx.strokeText style.text, @locate(pos[0]) + adjust[0], @locate(pos[1]) + adjust[1]	
		
	place: (move)->
		text = move.n + 1 if @show_num
		if text
			@draw_pawn move.pos, move.player, {text:text}
		else if move.n is @status_quo().step
			@draw_pawn move.pos, move.player, 'wreath'
		else
			@draw_pawn move.pos, move.player
			
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
		], (x)=> @circle @locate(x[0]), @locate(x[1]), @opts.NINE_POINTS_RADIUS, 'black'
		
	status_quo: ->
		step: @show_steps_to ? @initial.moves.length - 1
	
	redraw: ->
		switch arguments.length
			when 0
				@ctx.fillStyle = 'white'
				@ctx.fillRect 0, 0, @opts.size, @opts.size
				@draw_board()
				
				if @initial.moves
					num = @status_quo().step
					_.each @initial.moves, (x)=>
						if x.n <= num and (not x.repealed or x.repealed > num)
							@place x
			when 2
				[x, y] = arguments
	on_click: (pos)-> console.log pos

class window.Board extends CanvasBoard
	constructor: (@board, @opts)->
		super @board, @opts
		@try_mode = false
		
		@board.find('#num_btn').click =>
			@show_num = @board.find('#num_btn i').hasClass 'show-number'
			@board.find('#num_btn i').toggleClass 'show-number'
			@redraw()
		
		@board.find('#beginning').click => 
			num = @show_steps_to ? @initial.moves.length - 1
			return if num < 0
			@show_steps_to = -1
			@redraw()
			@on_show_steps @show_steps_to
		@board.find('#ending').click => 
			num = @show_steps_to ? @initial.moves.length - 1
			return if num >= @initial.moves.length - 1
			@show_steps_to = null
			@redraw()
			@on_show_steps @initial.moves.length - 1
		@board.find('#back').click => 
			num = @show_steps_to ? @initial.moves.length - 1
			return if num < 0
			@show_steps_to = num - 1
			@redraw()
			@on_show_steps @show_steps_to
		@board.find('#forward').click =>
			num = @show_steps_to ? @initial.moves.length - 1
			if num >= @initial.moves.length - 1
				@show_steps_to = null
			else
				@show_steps_to = num + 1
				@redraw()
				@show_steps_to = null if num >= @initial.moves.length - 1
				@on_show_steps @show_steps_to ? @initial.moves.length - 1
		
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
		console.log player ?= @board.attr('next')
		
		m =
			pos: pos
			player: player
			n: if @initial.moves then @initial.moves.length else 0
		@calc_move m
		@place m
		@change_to_next if player is 'black' then 'white' else 'black'
		@redraw()

class window.ConnectedBoard extends window.PlayBoard
	constructor: (@board, @opts)->
		super @board, @opts
		
		@socket = io.connect "http://#{location.hostname}/weiqi/#{@board.attr('socket')}"
		
		@socket.emit 'auth', $.cookie('auth') ? 'anonymous', (res)=>
			console.log res
			@on_connect?()
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
					console.log res
					@on_seats_update? res
			@socket.on 'start', (seats, next)=>
				console.log 'start: ' + JSON.stringify [seats, next]
				@board.attr 'status', 'started'
				@board.find('.players .black .name').text(seats.black.nickname).attr 'href', "/u/#{seats.black.id}"
				@board.find('.players .black .title').text seats.black.title
				@board.find('.players .white .name').text(seats.white.nickname).attr 'href', "/u/#{seats.black.id}"
				@board.find('.players .white .title').text seats.white.title
				@change_to_next next
				@on_start?()
			@socket.on 'move', (moves, next)=>
				console.log 'move: ' + JSON.stringify(moves)
				_.each moves, (x)=> 
					@calc_move x
					@place x
				@change_to_next next
				@redraw()
				@canvas.addClass 'your_turn' if @board.attr('iam') is 'player'
				@on_move? moves, next
			@socket.on 'disconnect', @on_disconnect if @on_disconnect
			@socket.on 'player_disconnect', => console.log 'player_disconnect'
			@socket.on 'comment', @on_comment
			@socket.on 'retract', (uid)=> 
				console.log 'retract ' + uid
				@initial.moves.pop()
				@change_to_next if @board.attr('next') is 'black' then 'white' else 'black'
				@redraw()
				@canvas.removeClass 'your_turn'
				@on_retract? uid
			@socket.on 'surrender', (uid)->
				console.log 'surrender ' + uid
				@on_surrender? uid
			
			@board.find('#retract').click =>
				if @board.attr('iam') is 'player' and @initial.moves.length and @board.attr('next') isnt @board.attr('seat')
					#$.get "/retract/#{@initial.id}", (data)->console.log data
					@socket.emit 'retract', (data)=> 
						if data is 'success'
							@initial.moves.pop()
							@change_to_next if @board.attr('next') is 'black' then 'white' else 'black'
							@redraw()
							@canvas.addClass 'your_turn'
						
			
			if @board.attr('status') is 'taking_seat' and @board.attr('iam') is 'player'
				$('#seats').show()
				$('#seats .item a').click =>
					if $(this).hasClass 'none'
						$('#seats .item a.mine').removeClass('mine').addClass('none').text 'none'
						@board.attr 'seat', $(this).attr('seat')
						@socket.emit 'taking_seat', $(this).attr('seat'), (res)=> console.log 'taking_seat: ' + JSON.stringify res
						$(this).removeClass('none').addClass('mine').text 'Me'
			
			if @board.attr('iam') is 'player' and @board.attr('next') is @board.attr('seat')
				@canvas.addClass 'your_turn'
			
			@board.find('.discuss input[type=submit]').click =>
				if text = @board.find('.discuss input[type=text]').val()
					@add_discuss
						step: game.initial.moves?.length + 1
						text: text
	taking_seat: (seat, cb)->
		@socket?.emit 'taking_seat', seat, (res)=>
			console.log 'taking_seat: ' + JSON.stringify res
			cb? res
	withdraw: (pos, player)->
		console.log @option
		@redraw()
	move: (pos, player)->
		move={pos:pos, player:player}
		sent = false
		
		@socket?.emit 'move', move, (res)=>
			console.log 'move: ' + JSON.stringify res
			sent = true
			if res.fail
				@withdraw pos, player
			else
				@change_to_next res.next if res.next
		
	on_connect: ->
		@connected = true
	on_disconnect: ->
		@connected = false
		console.log 'disconnect'
	on_start_taking_seat: null
	on_seats_update: null
	on_quit: null
	on_start: null
	on_resume: null
	on_move: null
	on_retract: null
	on_surrender: null
	on_click: (pos, player)->
		if @board.attr('status') is 'started' and @board.attr('iam') is 'player' and @board.attr('next') is @board.attr('seat')
			super pos, player
			@move pos, @board.attr('seat')
			@canvas.removeClass 'your_turn'
			
	send_comment: (gid, comment, cb)->
		console.log comment
		@socket?.emit 'comment', gid, comment, cb
	on_comment: (comment)-> console.log comment