$ ->
	$('.ts').each ->
		$(this).text moment(Number($(this).attr('_ts'))*1000).format('YYYY/MM/DD HH:mm')