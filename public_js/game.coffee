set_seat = (seat, player)->
	s = $("#seats ##{seat}").addClass('taken').removeClass('vacant')
	s.find('.nickname').text player.nickname
	s.find('.title').text player.title ? ''
		
reset_seat = (seat, player)->
	s = $("#seats ##{seat}").removeClass('taken').addClass('vacant')
	s.find('.nickname').text '?'
	s.find('.title').text ''

show_notice = (msg, style)->
	text = JSON.parse $('#game-notice').attr('_text')
	$('#game-notice').empty().append "<p class='#{style} offset3'>#{text[msg]}</p>"
	
class Weiqi extends ConnectedBoard
	on_connect: -> 
		#show_notice 'connected', 'text-warning'
		super()
		console.log 'connected'
	on_next_player: (player)->
		$("#players .next").removeClass 'next'
		$("#players .#{player}").addClass 'next'
	on_start_taking_seat: -> 
		location.reload()
	on_seats_update: (seats)->
		_.each ['black', 'white'], (s)->
			if seats[s]
				set_seat s, seats[s]
			else
				reset_seat s
	on_quit: (res)-> location.reload()
	on_resume: (res)-> location.reload()
	on_start: -> 
		_.delay (->$('#seats').hide()), 5000
		if $('.board').attr('iam') is 'player'
			if $('.board').attr('next') is $('.board').attr('seat')
				show_notice 'started_please_move', 'text-warning'
			else
				show_notice 'started_please_wait', 'text-success'
	on_click: (pos)->
		if @board.attr('status') is 'started' and @board.attr('iam') is 'player' and @board.attr('next') is @board.attr('seat')
			super pos
			show_notice 'started_please_wait', 'text-success'
	on_disconnect: => 
		show_notice 'connection_lost', 'text-warning'
		console.log 'disconnect'
		@connect()
	on_move: (moves, next)->
		if @board.attr('status') is 'started' and @board.attr('iam') is 'player' and next is @board.attr('seat')
			show_notice 'started_please_move', 'text-warning'
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
		players = JSON.parse b.board.attr('players')
		if players
			_.chain(players).pairs().each (x)->
				if x[1].id is b.board.attr('uid')
					set_seat x[0], nickname:$('#seats').attr('_text')
				else
					set_seat x[0], x[1]
		
		$('#seats #black, #white').click ->
			if $(this).hasClass 'vacant'
				b.taking_seat seat = $(this).attr('id'), (res)->
					if res isnt 'fail'
						$('.board').attr 'seat', seat
						set_seat seat, nickname:$('#seats').attr('_text')
						$(this).addClass 'me'
						_.chain($('#seats #black, #white')).difference([this]).each (x)-> 
							if $(x).hasClass 'me'
								$(x).removeClass 'me'
								reset_seat $(x).attr('id')
			
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
	
