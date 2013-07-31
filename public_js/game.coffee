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
			if @initial.calling_finishing.msg is 'ask' and @initial.calling_finishing.uid is @board.attr('uid')
				show_notice 'ask_calling_finishing'
			else if @initial.calling_finishing.msg is 'ask' and @initial.calling_finishing.uid isnt @board.attr('uid') and @board.attr('uid') in @initial.players
				show_notice 'ask_calling_finishing2_receiver'
			
	on_reconnect: ->
		super()
		console.log 'reconnected'
		show_notice 'reconnected'
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
		if @board.attr('iam') is 'player'
			if @board.attr('next') is @board.attr('seat')
				show_notice 'started_please_move'
			else
				show_notice 'started_please_wait'
	on_click: (pos)->
		if @board.attr('status') is 'started' and @board.attr('iam') is 'player' and @board.attr('next') is @board.attr('seat')
			super pos
			show_notice 'started_please_wait'
	on_disconnect: => 
		show_notice 'connection_lost'
		console.log 'disconnect'
		super()
	on_move: (moves, next)->
		if @board.attr('status') is 'started' and @board.attr('iam') is 'player' and next is @board.attr('seat')
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
			if not err
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
					if x[1].id is b.board.attr('uid')
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
						
						$('.board').attr 'seat', seat
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
		$('#gaming-board:visible').data('data')?.call_finishing 'cancel', (err)->
			if not err
				show_notice 'started_please_move'
		
	
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
	
