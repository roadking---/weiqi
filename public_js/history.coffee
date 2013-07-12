$ ->
	data = JSON.parse $('#rate-chart').attr('data')
	data = _.chain(data).sortBy('ts').map((x)-> 
		x.time = moment(x.ts * 1000).format('YYYY-MM-DD HH:mm')
		x
	).value()
	
	new Morris.Line
		element: 'rate-chart'
		data: data
		xkey: 'time'
		ykeys: ['rate']
		labels: ['Rate']
		ymax: 'auto'
		ymin: 'auto'
		