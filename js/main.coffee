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
		@analyser.fftSize = fftSize
		freqArray = new Uint8Array(@analyser.frequencyBinCount)
		@analyser.getByteFrequencyData(freqArray)
		console.log(freqArray)
		return freqArray

class Compute
	constructor: (player) ->
		@player = player

	total: ->
		freqArray = @player.freq(2048)
		return Math.floor(d3.sum(freqArray) / freqArray.length)

class Render
	constructor: (player, compute)->
		@width = $(document).width()
		@height = $(document).height()
		@player = player
		@compute = compute
		@mode = 'circle'
		@svg = d3.select('svg#viz')
		@cache = {}

		## icosahedron
		@cache.icosahedron = {}
		self = @cache.icosahedron

		self.velocity = [0.10, 0.005]
		self.velocity2 = [-0.10, -0.05]
		self.velocity3 = [0.10, 0.1]
		self.t0 = Date.now()

		self.faces = []
		y = Math.atan2(1, 2) * 180 / Math.PI
		for x in [0...360] by 72
			self.faces.push(
				[[x +  0, -90], [x +  0,  -y], [x + 72,  -y]],
				[[x + 36,   y], [x + 72,  -y], [x +  0,  -y]],
				[[x + 36,   y], [x +  0,  -y], [x - 36,   y]],
				[[x + 36,   y], [x - 36,   y], [x - 36,  90]]
			)

		# projection1
		self.projection = d3.geo.orthographic().scale(@height / 2).translate([@width / 2, @height / 2]).center([0, 0])
		self.svg = d3.select('body').append('svg').attr('class', 'isoco1').attr('width', @width).attr('height', @height)
		self.face = self.svg.selectAll('path').data(self.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection))

		# projection2
		self.projection2 = d3.geo.orthographic().scale(@height / 4).translate([@width / 2, @height / 2]).center([0, 0])
		self.svg2 = d3.select('body').append('svg').attr('class', 'isoco2').attr('width', @width).attr('height', @height)
		self.face2 = self.svg2.selectAll('path').data(self.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection2))

		# projection3
		self.projection3 = d3.geo.orthographic().scale(@height / 1).translate([@width / 2, @height / 2]).center([0, 0])

		self.svg3 = d3.select('body').append('svg').attr('class', 'isoco3').attr('width', @width).attr('height', @height)
		self.face3 = self.svg3.selectAll('path').data(self.faces).enter().append('path').attr('class', 'isoco').each (d) ->
			d.polygon = d3.geom.polygon(d.map(self.projection3))

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
		self = @cache.icosahedron

		time = Date.now() - self.t0
		xx = @compute.total() / 100
		$('body > svg path').attr('style', "transform: scale(#{xx}, #{xx})")
		# 1
		self.projection.rotate([time * self.velocity[0], time * self.velocity[1]])
		self.face.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = self.projection(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

		# 2
		self.projection2.rotate([time * self.velocity2[0], time * self.velocity2[1]])
		self.face2.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = self.projection2(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

		# 3
		self.projection3.rotate([time * self.velocity3[0], time * self.velocity3[1]])
		self.face3.each((d) ->
			d.forEach (p, i) ->
				d.polygon[i] = self.projection3(p)
		).style('display', (d) ->
			if d.polygon.area() > 0 then null else 'none'
		).attr 'd', (d) ->
			'M' + d.polygon.join('L') + 'Z'

	draw: =>
		$('svg#viz').empty()
		@icosahedron()

$ ->
	player = new Player()
	player.play('mp3/forgot.mp3')

	compute = new Compute(player)
	render = new Render(player, compute)

	setInterval(render.draw, 40)
