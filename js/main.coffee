'use strict'

class Player
	constructor: ->
		@audio = new Audio()
		@audio.autoplay = true
		@context = new AudioContext()
		@analyser = @context.createAnalyser()
		@analyser.connect(@context.destination)
		@source = null

	play: (path) =>
		@audio.src = path
		@source = @context.createMediaElementSource(@audio)
		@source.connect(@analyser)

	freq: (fftSize) =>
		@analyser.fftSize = fftSize or 2048
		freqArray = new Uint8Array(@analyser.frequencyBinCount)
		@analyser.getByteFrequencyData(freqArray)
		return freqArray

class Compute
	constructor: (player) ->
		@player = player

	total: =>
		freqArray = @player.freq()
		return Math.floor(d3.sum(freqArray) / freqArray.length)

	normalize: (coef, offset, neg) ->
		#https://stackoverflow.com/questions/13368046/how-to-normalize-a-list-of-positive-numbers-in-javascript
		coef = coef or 1
		offset = offset or 0
		numbers = @player.freq()
		numbers2 = []
		ratio = Math.max.apply(Math, numbers)

		for i in [0...numbers.length]
			if numbers[i] == 0
				numbers2[i] = offset
			else
				numbers2[i] = numbers[i] / ratio * coef + offset
			if i % 2 == 0 and neg
				numbers2[i] = -Math.abs(numbers2[i])

		return numbers2

class Render
	constructor: (player, compute)->
		@width = $(document).width()
		@height = $(document).height()
		@player = player
		@compute = compute
		@mode = 'circle'
		@svg = d3.select('svg#viz')
		@cache = {}

		@cacheIcosahedron()
		@cacheHexbin()

	cacheIcosahedron: =>
		@cache.icosahedron = {}
		cache = @cache.icosahedron

		cache.velocity = [0.10, 0.005]
		cache.velocity2 = [-0.10, -0.05]
		cache.velocity3 = [0.10, 0.1]
		cache.t0 = Date.now()

		cache.faces = []
		y = Math.atan2(1, 2) * 180 / Math.PI
		for x in [0...360] by 72
			cache.faces.push(
				[[x +  0, -90], [x +  0,  -y], [x + 72,  -y]],
				[[x + 36,   y], [x + 72,  -y], [x +  0,  -y]],
				[[x + 36,   y], [x +  0,  -y], [x - 36,   y]],
				[[x + 36,   y], [x - 36,   y], [x - 36,  90]]
			)

		# projection1
		cache.projection = d3.geo.orthographic().scale(@height / 2).translate([@width / 2, @height / 2]).center([0, 0])
		cache.svg = d3.select('body').append('svg').attr('class', 'isoco1').attr('width', @width).attr('height', @height)
		cache.face = cache.svg.selectAll('path').data(cache.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(cache.projection))

		# projection2
		cache.projection2 = d3.geo.orthographic().scale(@height / 4).translate([@width / 2, @height / 2]).center([0, 0])
		cache.svg2 = d3.select('body').append('svg').attr('class', 'isoco2').attr('width', @width).attr('height', @height)
		cache.face2 = cache.svg2.selectAll('path').data(cache.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(cache.projection2))

		# projection3
		cache.projection3 = d3.geo.orthographic().scale(@height / 1).translate([@width / 2, @height / 2]).center([0, 0])

		cache.svg3 = d3.select('body').append('svg').attr('class', 'isoco3').attr('width', @width).attr('height', @height)
		cache.face3 = cache.svg3.selectAll('path').data(cache.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(cache.projection3))

	cacheHexbin: =>
		@cache.hexbin = {}
		cache = @cache.hexbin

		randomX = d3.random.normal(@width / 2, 2100)
		cache.ps = d3.range(1024).map ->
			return randomX()

	circle: =>
		freqArray = @player.freq(32)

		bars = @svg.selectAll('circle').data(freqArray)
		bars.enter().append('circle')
			.attr 'cy', '50%'
			.attr 'cx', '50%'
			.attr 'r', (d) ->
				return d

		bars.exit().remove()

	icosahedron: =>
		cache = @cache.icosahedron

		time = Date.now() - cache.t0
		xx = @compute.total() / 100
		$('body > svg path').attr('style', "transform: scale(#{xx}, #{xx})")
		# 1
		cache.projection.rotate([time * cache.velocity[0], time * cache.velocity[1]])
		cache.face.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = cache.projection(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

		# 2
		cache.projection2.rotate([time * cache.velocity2[0], time * cache.velocity2[1]])
		cache.face2.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = cache.projection2(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

		# 3
		cache.projection3.rotate([time * cache.velocity3[0], time * cache.velocity3[1]])
		cache.face3.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = cache.projection3(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

	hexbin: =>
		# http://bl.ocks.org/mbostock/4248145 
		# http://bl.ocks.org/mbostock/4248146

		cache = @cache.hexbin
		points = d3.zip(cache.ps, @compute.normalize(@height, 0))

		color = d3.scale.linear()
			.domain([0, 20])
			.range([$('.dotstyle li.current a').css('background-color'), $('.dotstyle li.current a').css('background-color')])
			.interpolate(d3.interpolateLab);

		hexbin = d3.hexbin()
			.size([@width, @height])
			.radius(50);

		radius = d3.scale.linear()
			.domain([0, 20])
			.range([3, 200])

		@svg.append('g').selectAll('.hexagon')
			.data(hexbin(points))
			.enter()
				.append('path')
				.attr 'class', 'hexagon'
				.attr 'id', 'hexx'
				.attr 'd', (d) ->
					hexbin.hexagon radius(d.length)
				.attr 'transform', (d) ->
					'translate(' + d.x + ',' + d.y + ')'
				.style 'fill', (d) ->
					color(d.length)
				.style 'opacity', (d) ->
					if radius(d.length) / 180 > 0.6
						return 0
					else
						if radius(d.length) / 180 > 0.4
							if Math.random() > 0.1
								return 0
							else
								return 0.25 + radius(d.length) / 100
						else
							return 0.25 + radius(d.length) / 100

	draw: =>
		$('svg#viz').empty()
		@hexbin()

$ ->
	player = new Player()
	player.play('mp3/forgot.mp3')

	compute = new Compute(player)
	render = new Render(player, compute)

	setInterval(render.draw, 40)
