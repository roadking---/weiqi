window.update_comment = (comment)->
	c = $("<div _type='game_comment' class='blog row'/>") \
	.append("<div class='text'>#{comment.text}</div>") \
	.append("<a class='author' href='/u/#{comment.author}'>#{comment.nickname ? $('#blogs').attr('_me')}</span>") \
	.append("<a class='step' _step='#{comment.step}'>#{Number(comment.step)+1}</span>") \
	.append("<span class='ts'>#{comment.ts}</span>") \
	.prependTo('#blogs')

	if comment.snapshots
		text = c.find('.text').text()
		_.each comment.snapshots, (x, i)->
			text = text.replace "[G#{i+1}]", "<a class='snapshot'>[G#{i+1}]</a>"
		c.find('.text').html text
		
		current = $('#gaming-board').data('data').get_moves()?.current
		return if not current
		
		c.find('.text .snapshot').each (i)->
			$(this).data 'snapshot', comment.snapshots[i]
			moves = _.flatten([current[0..comment.snapshots[i].from], comment.snapshots[i].moves], true)
			
			$(this).click show_big_chart = ->
				$('#tabs.nav a#trying').click()
				snapshot = $(this).data 'snapshot'
				b = $('#trying-board').data 'data'
				b.board.data 'final_step', b.show_steps_to = snapshot.from
				b.redraw()
				_.each snapshot.moves, (x)->
					b.on_click x.pos, x.player
				
			thumbnail(moves, focus:[comment.snapshots[i].from+1 .. moves.length-1], title:"G#{i+1}").appendTo(c).data('snapshot', comment.snapshots[i]).click show_big_chart


window.install_pub = (type)->
	$('#pub button#submit').click ->
		snapshot_list = $(this).parent().data 'snapshots'
		$(this).parent().data 'snapshots', null
		
		text = $.trim $(this).parent().find('textarea').val()
		return if not text || text is ''
		
		game = $('#gaming-board').data('data')
		step = if $('#tabs a#trying').parent().hasClass('active')
			$('#trying-board').data 'final_step'
		else
			game.status_quo().step
		
		comments = game.initial.comments ?= {}
		comments[step] ?= next_id:0
		next_id = comments[step].next_id
		comments[step][next_id] = comment = 
			id: next_id
			ts: new Date().getTime()
			text: text
			step: step
			gid: game.id
			author: $(this).parent().attr('uid')
		comment.snapshots = snapshot_list if snapshot_list
		comments[step].next_id++
		$(this).parent().find('textarea').val ''
		switch type
			when 'dapu'
				localStorage.dapu = JSON.stringify game.initial
			when 'connected'
				delete comment.id
				game = $('#gaming-board').data 'data'
				if game.connected
					game.send_comment $('#gaming-board').attr('socket'), comment
				else
					$.post '/comment', comment:comment, game:$('#gaming-board').attr('socket'), (rlt)-> console.log rlt
		
		comment.ts = moment(Number comment.ts).format('YYYY/MM/DD HH:mm')
		update_comment comment	
	
	$('#pub button#add_chart').click ->
		if $('#tabs a#trying').parent().hasClass 'active'
			from = $('#trying-board').data 'final_step'
			snapshot =
				moves: $('#trying-board').data('data').get_moves().current[from+1..]
				from: from
			console.log snapshot_list = $(this).parent().data('snapshots') ? []
			snapshot_list.push snapshot
			$(this).parent().find('textarea').val text = $(this).parent().find('textarea').val() + "[G#{snapshot_list.length}]"
			$(this).parent().data 'snapshots', snapshot_list
		else
			$('#tabs a#trying').click()

window.clear_pub_input = -> 
	$('#pub').data 'snapshots', null
	$('#pub textarea').val ''

