$ ->
	console.log data
	init_header data
	$('nav #home').parent().addClass('active')
	
	$('#blogs').append tpl('#blog_tpl') data
	
	if data.myself && data.games.attendings.length
		$(tpl('#attendings_tpl') data, {variable:'data'}).appendTo( $('#attendings') ).find('li').each (i, li)->
			new BoardCanvas($(li).find('.thumb')).render data.refs[data.games.attendings[i]].moves
	
	if data.games.pendings.length
		$(tpl('#pendings_tpl') data, {variable:'data'}).appendTo( $('#pendings') )