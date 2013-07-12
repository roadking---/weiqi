class window.DapuBoard extends window.PlayBoard
	constructor: (@board, @opts)->
		super @board, @opts
		if localStorage.dapu
			@initial = JSON.parse localStorage.dapu
			_.each @initial.moves, (x)=> @place x if not x.repealed
			@change_to_next @initial.next
		else
			@initial = 
				created: new Date().getTime()
				moves: []
				next: 'black'
	new: ->
		delete localStorage.play
	on_click: (pos, player)->
		super pos, player	
		localStorage.dapu = JSON.stringify @initial
	on_show_steps: (step)->
		step ?= @initial.moves?.length - 1
		return if not step?
		
		$('#comments').empty()
		status = @status_quo()
		return if not status or not @initial.comments
		steps = _.chain(@initial.comments).keys().filter((x)-> status.step >= Number x).value().sort()
		recent_comments = []
		while recent_comments.length < 20 and steps.length > 0
			step = steps.pop()
			max_id = @initial.comments[step].next_id
			while recent_comments.length < 20 and max_id >= 0
				max_id--
				if @initial.comments[step][max_id]
					recent_comments.push @initial.comments[step][max_id]
		
		_.chain(recent_comments).sortBy((x)-> x.step + '_' + x.ts).map((x)-> 
			x = _.clone x
			x.ts = moment(x.ts).format('YYYY/MM/DD HH:mm')
			x
		).each update_comment

$ ->
	$('#tabs a').click ->
		if $(this).parent().hasClass('active')
			return
		else
			$('#tabs li').removeClass 'active'
			$(this).parent().addClass('active')
			if $(this).attr('id') is 'gaming'
				$('#gaming-board').show()
				clear_pub_input()
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
			else
				delete $('#trying-board').data 'data'
				delete $('#trying-board').data 'game'
				$('#trying-board').remove()
	
	
	b = new DapuBoard $('#gaming-board')
	
	title = b.board.find('input.title').change -> 
		b.initial.title = $(this).val()
		localStorage.dapu = JSON.stringify b.initial
	if b.initial.title
		title.val b.initial.title
	else
		title.val(title.attr('_text') + ' - ' + moment().format('YYYY/MM/DD HH:mm')).change()
	
	$.each b.board.find('.players input'), ->
		if tmp = b.initial.players?[$(this).attr('_player')]?[$(this).attr('_type')]
			$(this).val tmp
	
	b.on_show_steps()
	
	b.board.find('.players input').change ->
		b.initial.players ?= {}
		b.initial.players[$(this).attr('_player')] ?= {}
		b.initial.players[$(this).attr('_player')][$(this).attr('_type')] = $(this).val()
		localStorage.dapu = JSON.stringify b.initial
	
	$('#undo').click ->
		idx = b.initial.moves.length - 1
		_.each b.initial.moves, (x)-> delete x.repealed if x.repealed is idx
		b.initial.moves.pop()
		b.redraw()
		localStorage.dapu = JSON.stringify b.initial
		
		player = b.board.attr('next')
		b.change_to_next if player is 'black' then 'white' else 'black'
	
	$('#discard').click ->
		delete localStorage.dapu
		location.reload()

	#------------------------------------------
	install_pub 'dapu'
	