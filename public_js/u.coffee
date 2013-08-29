uid = /u\/(.+)$/.exec(location.pathname)?[1]

$.get "/json/u/#{uid}", (data)->
	console.log data
	init_header data
	$('nav #mine').parent().addClass('active')
	
	$('#heading').append tpl('#heading_tpl') data
	$('#profile').append tpl('#profile_tpl') data
	$('#invites #received').append tpl('#received_invites_tpl') data
	$('#invites #sent').append tpl('#sent_invites_tpl') data
	$('#current').append tpl('#current_game_tpl') _.defaults(data, current:data.query.current)
	$('#recent_history').append tpl('#recent_history_tpl') _.defaults(data, recent_history:data.query.recent_history)
	
	$('#current ul li').each (i, li)->
		gid = $(li).attr 'gid'
		new BoardCanvas($(li).find('.thumb')).render data.refs[gid].moves
		
	$('a.follow, a.unfollow').click ->
		if $(this).hasClass 'follow'
			$.get "/unfollow/#{data.uid}", (rlt)=>
				$(this).addClass('unfollow').removeClass('follow') if rlt.success
		else
			$.get "/unfollow/#{data.uid}", (rlt)=>
				$(this).addClass('follow').removeClass('unfollow') if rlt.success