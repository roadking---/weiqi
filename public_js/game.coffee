set_seat = (seat, player)->
	s = $("#seats .#{seat}").addClass('taken')
	s.find('.nickname').text player.nickname
	

show_notice = (msg)->
	$('#game-notice > *').hide()
	$("#game-notice *[msg='#{msg}']").show()
	
class Weiqi extends ConnectedBoard
	on_connect: -> 
		super()
		console.log 'connected'
		show_notice 'connected'
		if @initial.calling_finishing
			if @initial.calling_finishing.msg is 'ask' and @initial.calling_finishing.uid is @uid()
				show_notice 'ask_calling_finishing'
			else if @is_player() and @initial.calling_finishing.msg is 'ask' and @initial.calling_finishing.uid isnt @uid()
				show_notice 'ask_calling_finishing_receiver'
			else if @is_player() and @initial.calling_finishing.msg is 'reject' and @initial.calling_finishing.uid isnt @uid()
				show_notice 'reject_calling_finishing_receiver'
			else if @is_player() and @initial.calling_finishing.msg is 'accept' 
				if @initial.calling_finishing.uid is @uid()
					show_notice 'accept_calling_finishing'
				else
					show_notice 'accept_calling_finishing_receiver'
				if @initial.analysis
					@show_finishing_view @initial.analysis
			
	show_finishing_view: (analysis)->
		_.each analysis, (x)=>
			item = $('.finishing:visible li').first().clone().appendTo $('.finishing:visible ul')
			item.data 'regiment', x
			item.data 'stones', x.stones = _.chain(x.domains).pluck('stone_blocks').flatten().pluck('block').flatten().value()
			item.find('.player').text x.player
			item.find('.stones').text item.data('stones').length
			item.find(".guess option[value='#{x.judge or x.guess}']").attr 'selected', true
			item.find("select.guess").change (e)=>
				console.log $(e.target).val()
				@call_finishing 'suggest', item.data('stones')[0].n, $(e.target).val(), =>
					console.log 333
			#$(item)?.find(".opponent_guess").text suggest
			item.removeClass('hide').show().hover =>
				@redraw 
					before_place: (stone)=>
						if _.find(item.data('stones'), (x)-> x.n is stone.n)
							@ctx.shadowOffSetX = 0
							@ctx.shadowOffSetY = 0
							@ctx.shadowColor = 'rgba(255,0,0,.8)'
							@ctx.shadowBlur = 13
					after_place: (stone)=>
						@ctx.shadowBlur = 0
		
		redraw_modified = =>
			@redraw 
				before_place: (stone)=>
					regiment = _.find analysis, (r)->
						_.find r.stones, (x)-> x.n is stone.n
					@ctx.shadowOffSetX = 0
					@ctx.shadowOffSetY = 0
					@ctx.shadowBlur = 13
					switch regiment.judge or regiment.guess
						when 'live'
							@ctx.shadowBlur = 0
						when 'dead'
							@ctx.shadowColor = 'rgba(0,255,255,1)'
						else
							@ctx.shadowColor = 'rgba(255,0,0,.8)'
				after_place: (stone)=>
					@ctx.shadowBlur = 0
		redraw_modified()
		
		$('.finishing:visible').mouseout => 
			redraw_modified()
		
	on_disconnect: -> 
		super()
		@last_game_notice = $('#game-notice > *:visible').attr 'msg'
		show_notice 'connection_lost'
		console.log 'disconnect'
	on_reconnect: ->
		super()
		console.log 'reconnected'
		show_notice 'reconnected'
		if @last_game_notice
			_.delay (=> show_notice @last_game_notice), 5000
		
	on_connect_failed: ->
		super()
		show_notice 'connect_failed'
	on_connecting: ->
		super()
		show_notice 'connecting'
	on_next_player: (player)->
		super player
		$("#players .next").removeClass 'next'
		$("#players .#{player}").addClass 'next'
	on_start_taking_seat: -> 
		location.reload()
	on_seats_update: (seats)->
		_.each ['black', 'white'], (s)->
			if seats[s]
				$("#seats .#{s}").addClass('taken')
				$("#seats .#{s} .nickname").text seats[s].nickname
			else
				$("#seats .#{s}").removeClass('me').removeClass('taken')
	on_quit: (res)-> location.reload()
	on_resume: (res)-> location.reload()
	on_start: (seats, next)-> 
		$('#players .black .name').text(seats.black.nickname).attr 'href', "/u/#{seats.black.id}"
		$('#players .black .title').text seats.black.title
		$('#players .white .name').text(seats.white.nickname).attr 'href', "/u/#{seats.black.id}"
		$('#players .white .title').text seats.white.title
		_.delay (->$('#seats').hide()), 5000
		if @is_player()
			if @next() is @seat()
				show_notice 'started_please_move'
			else
				show_notice 'started_please_wait'
	on_click: (pos)->
		if @board.attr('status') is 'started' and @is_player() and @next() is @seat()
			super pos
			show_notice 'started_please_wait'
	on_move: (moves, next)->
		if @board.attr('status') is 'started' and @is_player() and next is @seat()
			show_notice 'started_please_move'
	on_show_steps: (step)->
		step ?= @initial.moves?.length - 1
		return if not step?
		$('#blogs .blog').each (i)->
			blog_step = $(this).find('.step').attr('_step')
			if not step or not blog_step or step >= Number(blog_step)
				$(this).show()
			else
				$(this).hide()
	on_comment: (comment)-> 
		comment.ts = moment(Number comment.ts).format('YYYY/MM/DD HH:mm')
		update_comment comment
	on_retract: ->
		super()
		show_notice 'retract_by_opponent'
		console.log 'retract'
	mine_retract: ->
		show_notice 'started_please_move'
	on_call_finishing: (msg)->
		super msg
		switch msg
			when 'ask'
				show_notice 'ask_calling_finishing_receiver'
			when 'cancel'
				show_notice 'ask_calling_finishing_cancelled'
			when 'reject'
				show_notice 'reject_calling_finishing_receiver'
			when 'accept'
				[msg, analysis] = arguments
				show_notice 'accept_calling_finishing_receiver'
				@show_finishing_view analysis 
			when 'stop'
				if @next() is @seat()
					show_notice 'stop_calling_finishing_receiver_move'
				else
					show_notice 'stop_calling_finishing_receiver_wait'
			when 'suggest'
				[msg, stone, suggest] = arguments
				console.log arguments
				item = _.find $('.finishing:visible ul li').toArray(), (x)->
					_.find $(x).data('stones'), (y)-> y.n is stone
				$(item)?.find(".opponent_guess").text suggest
	
$ ->
	b = new Weiqi $('#gaming-board'), {LINE_COLOR: '#53595e', NINE_POINTS_COLOR: '#53595e', size: 600}
	
	$('#toolbox #num_btn').click -> 
		$(this).toggleClass 'show-number'
		$('#gaming-board:visible, #trying-board:visible').data('data')?.toggle_num_shown()
	$('#toolbox #beginning').click -> 
		$('#gaming-board:visible, #trying-board:visible').data('data')?.go_to_beginning()
	$('#toolbox #ending').click -> 
		$('#gaming-board:visible, #trying-board:visible').data('data')?.go_to_ending()
	$('#toolbox #back').click -> 
		$('#gaming-board:visible, #trying-board:visible').data('data')?.go_back()
	$('#toolbox #forward').click -> 
		$('#gaming-board:visible, #trying-board:visible').data('data')?.go_forward()
	$('#toolbox #retract').click ->
		$('#gaming-board:visible').data('data')?.retract()
	$('#toolbox #call-finishing').click ->
		$('#gaming-board:visible').data('data')?.call_finishing 'ask', (err)->
			if err
				console.log err
			else
				show_notice 'ask_calling_finishing'
	
	refresh_view = ->
		show_num = $('#gaming-board:visible, #trying-board:visible').data('data')?.show_num
		if show_num
			$('#toolbox #num_btn').removeClass 'show-number'
		else
			$('#toolbox #num_btn').addClass 'show-number'
	
	$('#tabs a').click ->
		if $(this).parent().hasClass('active')
			return
		else
			$('#tabs li').removeClass 'active'
			$(this).parent().addClass('active')
			if $(this).attr('id') is 'gaming'
				$('#gaming-board').show()
				clear_pub_input()
				refresh_view()
			else
				$('#gaming-board').hide()
			
			if $(this).attr('id') is 'trying'
				final_step = $('#gaming-board').data('data').get_moves().step
				game = _.clone $('#gaming-board').data('data').initial
				game.moves = _.chain(game.moves).filter((x, i)-> i <= final_step).map((x)-> _.clone x).value()
				board = $('#gaming-board').clone().insertAfter($('#gaming-board')).attr('id', 'trying-board').show().data('game', game)
				board.data 'final_step', final_step
				game.title = 'Snapshot - ' + (final_step + 1)
				$('input.title').val game.title
				new PlayBoard board
				refresh_view()
			else
				delete $('#trying-board').data 'data'
				delete $('#trying-board').data 'game'
				$('#trying-board').remove()
	
			if $(this).attr('id') is 'surrender'
				$('#surrender-view').show()
			else
				$('#surrender-view').hide()
	
			if $(this).attr('id') is 'detail'
				$('#detail-view').show()
			else
				$('#detail-view').hide()
	
	
	
	if b.board.attr('status') is 'taking_seat'
		if b.board.attr('players')
			if players = JSON.parse b.board.attr('players')
				_.chain(players).pairs().each (x)->
					if x[1].id is b.uid()
						$("#seats .#{x[0]}").addClass('taken').addClass('me')
						$("#seats .#{x[0]} .nickname").text $('#seats').attr('_text')
					else
						$("#seats .#{x[0]}").addClass('taken')
						$("#seats .#{x[0]} .nickname").text x[1].nickname
		
		$('#seats .black, #seats .white').click ->
			if not $(this).hasClass 'taken'
				seat = if $(this).hasClass('black') then 'black' else 'white'
				b.taking_seat seat, (res)=>
					if res is 'fail'
						console.log 'fail'
					else
						if not $('#seats .me').hasClass(seat)
							$('#seats .me').removeClass('me').removeClass('taken')
						
						b.board.attr 'seat', seat
						set_seat seat, nickname:$('#seats').attr('_text')
						$(this).addClass 'me'
						
	
	
	install_pub 'connected'
	
	m = /step=(\d+)/.exec location.search
	if m
		b.show_steps_to = m[1]
		b.redraw()
		b.on_show_steps m[1]
	else
		b.on_show_steps()
	

	$('#aside-tabs a').click ->
		if $(this).parent().hasClass('active')
			return
		else
			$('#aside-tabs li').removeClass 'active'
			$(this).parent().addClass('active')
			if $(this).attr('id') is 'aside-game'
				$('#game-controls').show()
			else
				$('#game-controls').hide()
			
			if $(this).attr('id') is 'aside-comments'
				$('#blogs-view').show()
			else
				$('#blogs-view').hide()
	
	$('#game-notice a#cancel_calling_finishing').click ->
		$('#gaming-board:visible').data('data')?.call_finishing 'cancel', ->
			show_notice 'started_please_move'
	$('#game-notice a#reject_calling_finishing').click ->	
		$('#gaming-board:visible').data('data')?.call_finishing 'reject', ->
			show_notice 'reject_calling_finishing'
	$('#game-notice a#accept_calling_finishing').click ->
		$('#gaming-board:visible').data('data')?.call_finishing 'accept', (analysis)->
			show_notice 'accept_calling_finishing'
			@show_finishing_view analysis
	$('#game-notice a#stop_calling_finishing').click ->
		$('#gaming-board:visible').data('data')?.call_finishing 'stop', ->
			if b.next() is b.seat()
				show_notice 'stop_calling_finishing_move'
			else
				show_notice 'stop_calling_finishing_wait'
			
window.show_trying_board = (game)->
	delete $('#trying-board').data 'data'
	delete $('#trying-board').data 'game'
	$('#trying-board').remove()
	$('#tabs li').removeClass 'active'
	$('#tabs li a#trying').parent().addClass('active')
	$('#gaming-board').hide()
	next = game.next
	board = $('#gaming-board').clone().insertAfter($('#gaming-board')).attr('id', 'trying-board').show().data('game', game)
	tb = new PlayBoard board
	tb.change_to_next next
	
