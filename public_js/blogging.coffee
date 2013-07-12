show_big_chart = ->
	game = $(this).data('ss')
	game.title = 'xxx'
	if not game.next
		game.next = \
		if game.moves.length
			if game.moves[game.moves.length-1].player is 'black' then 'white' else 'black'
		else
			'black'
	show_trying_board game
	
	
###
below deals with commeting
###

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
			$(this).data 'ss', comment.snapshots[i]
			moves = _.flatten([current[0..comment.snapshots[i].from], comment.snapshots[i].moves], true)
			
			$(this).click show_big_chart
			thumbnail(moves, focus:[comment.snapshots[i].from+1 .. moves.length-1], title:"G#{i+1}").appendTo(c).data('ss', {moves:moves}).click show_big_chart


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

###
below deals with blogs
###
$ ->
	$('#pub_blog button').click ->
		text = $('#pub_blog textarea').val()
		return if text is ''
		$.post '/blog', text:text, (res)->
			$('#pub_blog textarea').val ''
	
	make_up_blog = (blog, refs)->
		b = $("<div _type='#{blog.type}' id='#{blog.id}' class='blog row'/>")
		b.append "<div class='text'>#{blog.text}</div>" if blog.text
		b.append "<a href='/u/#{blog.author}' class='author'>#{refs[blog.author]?.nickname}</a>" if blog.author
		b.append "<a _step=#{blog.step} class='step'>#{Number(blog.step)+1}</a>" if blog.step
		b.append "<span _ts='#{blog.ts}' class='ts'>#{moment(Number(blog.ts)*1000).format('YYYY/MM/DD HH:mm')}</span>" if blog.ts
	
	(render_blogs = ->
		$('.ts').each (i)->
			$(this).text moment(Number($(this).attr('_ts'))*1000).format('YYYY/MM/DD HH:mm')
		$('.blog .snapshots').each (i)->
			game_moves = \
			if $(this).attr('game_moves')
				JSON.parse $(this).attr('game_moves')
			else
				null
				
			_.each JSON.parse($(this).attr('_ss')), (ss, i)=>
				gid = $(this).attr 'gid'
				cid = $(this).parent().attr 'id'
				ss.moves = _.chain([game_moves?[0..ss.from], ss.moves]).flatten().compact().value()
				thumbnail(ss.moves, focus:[ss.from+1 .. ss.moves.length-1], title:"G#{i+1}").appendTo($(this)).data('ss', ss).wrap("<a href='/game/weiqi/#{gid}?c=#{cid}&ss=#{i}'/>")
	)()
	
	$('#recent_blogs_btn').click ->
		blog_id = $('#blogs').attr 'blog_id'
		$.get '/blog', {blog_id:blog_id, tag:'recent'}, (data)->
			if data and data isnt 'error'
				recents = _.toArray $('<div/>').append(data).children().filter(->
					id = $(this).attr('id')
					not $("#blogs #blogs_list .blog[id='#{id}']").length
				)
				console.log recents.length
				_.each recents.reverse(), (x)->
					$(x).detach().prependTo $('#blogs #blogs_list')
				render_blogs()
	
	$('#prev_blogs_btn').click ->
		blog_id = $('#blogs').attr 'blog_id'
		$.get '/blog', {blog_id:blog_id, tag:'next'}, (data)->
			if data and data isnt 'error'
				$('#blogs #blogs_list').append data
				render_blogs()

	$('.blog .del').click ->
		$.get "/delete_blog/" + $(this).parent().attr('id'), (data)=>
			if data?.success
				$(this).parent().remove()