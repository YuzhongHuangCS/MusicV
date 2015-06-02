'use strict'

class Player
	constructor: ->
		@audio = new Audio()
		@audio.autoplay = true
		@context = new AudioContext()
		@analyser = @context.createAnalyser()
		@analyser.connect(@context.destination)
		@source = null
		@playlist = ['mp3/forgot.mp3', 'mp3/Go.mp3', 'mp3/Johann_Strauss.mp3', 'mp3/Let_Me_Hit_It.mp3', 'mp3/Sunrise.mp3', 'mp3/The_Mass.mp3']
		@index = 0

	play: (path) =>
		@audio.src = path
		@source = @context.createMediaElementSource(@audio)
		@source.connect(@analyser)

	playIndex: (index)=>
		@index = index
		@play(@playlist[index])

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
		@mode = 1
		@last = 1
		@visual = [@circle, @icosahedron, @hexbin, @grid, @spin]

		@svg = d3.select('svg#viz')
		@cache = {}

		@cacheIcosahedron()
		@cacheHexbin()
		@cacheGrid()
		@cacheSpin()

	draw: =>
		if @last == 1 and @mode != 1
			$('body > svg').empty()
		else
			$('svg#viz').empty()

		if @mode == 1 and @last != 1
			@cacheIcosahedron()

		@last = @mode
		@visual[@mode]()

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

	cacheGrid: =>
		@cache.grid = {}
		cache = @cache.grid

		cache.p = 0
		cache.projection = d3.geo.gnomonic()
			.clipAngle(80)
			.scale(500)
		cache.path = d3.geo.path().projection(cache.projection)
		cache.graticule = d3.geo.graticule()
			.minorStep([5, 5])
			.minorExtent([[-180, -90], [180, 90 + 1e-4]])

		# lamda / longitude
		cache.λ = d3.scale.linear().domain([0, @width]).range([-180, 180])

		# phi / latitude
		cache.φ = d3.scale.linear()
			.domain([0, @height])
			.range([90, -90])

	cacheSpin: =>
		@cache.spin = {}
		cache = @cache.spin

		cache.elems = [
			{
				id: 'c1'
				radius: 300
			}
			{
				id: 'c4'
				radius: 10
			}
			{
				id: 'c2'
				radius: 100
			}
			{
				id: 'c3'
				radius: 50
			}
		]

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

	grid: =>
		cache = @cache.grid

		xx = @compute.total() / 100 + 1
		if xx < 1 then xx = 1
		if xx > 1.1 then xx = 1.1
		$('body > svg path').attr('style', "transform: scale(#{xx}, #{xx})")

		cache.projection.rotate([cache.λ(cache.p), cache.φ(cache.p)])
		@svg.selectAll('path').attr 'd', cache.path

		cache.p += 5

		cache.step = Math.floor(@compute.total() / 100 * 60)
		if cache.step < 5 then cache.step = 5

		cache.graticule = d3.geo.graticule()
			.minorStep([cache.step, cache.step])
			.minorExtent([[-180, -90], [180, 90 + 1e-4]])

		cache.grat = @svg.append('path')
			.datum(cache.graticule)
			.attr('class', 'graticule')
			.attr('d', cache.path)

	spin: =>
		cache = @cache.spin

		bars = @svg.selectAll('circle').data cache.elems, (d,i)->
			return i

		bars.enter()
			.append('circle')
				.attr 'class', 'spin'
				.attr 'cy', '50%'
				.attr 'cx', '50%'
				.attr 'id', (d) ->
					d.id
				.attr 'r', (d) ->
					d.radius
		bars.exit().remove()

		waveData = @compute.total() * 2
		d3.selectAll('body > svg circle')
			.attr 'style', 'stroke-width: ' + waveData * 4 + 'px'
			.attr 'stroke-dashoffset', waveData + 'px'
			.attr 'stroke-dasharray', waveData / 6 + 'px'
			.attr 'opacity', waveData / 2200

class Helper
	constructor: (render, player)->
		@render = render
		@player = player

	bindMouse: =>
		self = this
		$('.icon-expand').on('click', @toggleFullScreen)
			
		$('.menu, .icon-menu').on 'mouseenter touchstart', =>
			@toggleMenu('open')

		$('.menu').on 'mouseleave', =>
			@toggleMenu('close')

		$('.wrapper').on 'click', =>
			@toggleMenu('close')

		$('.menu li').on 'click', ->
			self.visual(Number($(this).attr('viz-num')))

		$('.icon-question').on 'click', =>
			@showModal('#modal-about')

		$('.icon-keyboard2').on 'click', =>
			@showModal('#modal-keyboard')

		$('.md-close').on('click', @hideModals)

		$('#slider').on 'input change', (event)=>
			@player.analyser.smoothingTimeConstant = 1 - event.target.value / 100

		$('.icon-pause').on('click', @togglePlay)
		$('.icon-play').on('click', @togglePlay)

		$('.icon-forward2').on 'click', =>
			@changeSong(1)

		$('.icon-backward2').on 'click', =>
			@changeSong(-1)

		$('.dotstyle li').on 'click', ->
			self.themeChange(Number($(this).find('a').text()))

		dragenter = (e)->
			e.stopPropagation();
			e.preventDefault();


		dragover = (e)->
			e.stopPropagation()
			e.preventDefault()

		drop = (e)->
			e.stopPropagation()
			e.preventDefault()
			self.handleDrop(e.dataTransfer.files)

		document.addEventListener("dragenter", dragenter, false);
		document.addEventListener("dragover", dragover, false);
		document.addEventListener("drop", drop, false);

	visual: (n)=>
		if n < 0 then n = 6
		if n > 6 then n = 0
		@render.mode = n
		$('.menu li.active').removeClass 'active'
		$('.menu li[viz-num="' + n + '"]').addClass 'active'

	toggleMenu: (action)=>
		if action == 'toggle'
			action = if $('.menu').hasClass('menu-open') then 'close' else 'open'
		if action == 'open'
			$('.menu').addClass 'menu-open'
		else
			$('.menu').removeClass 'menu-open'

	toggleFullScreen: =>
		if !document.fullscreenElement and !document.mozFullScreenElement and !document.webkitFullscreenElement and !document.msFullscreenElement
			# current working methods
			$('.icon-expand').addClass 'icon-contract'
			if document.documentElement.requestFullscreen
				document.documentElement.requestFullscreen()
			else if document.documentElement.msRequestFullscreen
				document.documentElement.msRequestFullscreen()
			else if document.documentElement.mozRequestFullScreen
				document.documentElement.mozRequestFullScreen()
			else if document.documentElement.webkitRequestFullscreen
				document.documentElement.webkitRequestFullscreen Element.ALLOW_KEYBOARD_INPUT
		else
			$('.icon-expand').removeClass 'icon-contract'
			if document.exitFullscreen
				document.exitFullscreen()
			else if document.msExitFullscreen
				document.msExitFullscreen()
			else if document.mozCancelFullScreen
				document.mozCancelFullScreen()
			else if document.webkitExitFullscreen
				document.webkitExitFullscreen()

	showModal: (id) =>
		if $(id).hasClass('md-show')
			@hideModals()
		if $('.md-show').length > 0
			@hideModals()
		$(id).addClass('md-show')

	hideModals: =>
		$('.md-modal').removeClass('md-show')

	togglePlay: =>
		audio = @player.audio
		if audio.paused then audio.play() else audio.pause()
		$('.icon-pause').toggleClass('icon-play')

	changeSong: (diff) =>
		current = @player.index + diff
		max = @player.playlist.length - 1
		if current > max then current = 0
		if current < 0 then current = max
		@player.playIndex(current)
		$('.icon-pause').removeClass 'icon-play'

	themeChange: (n)=>
		if n < 0 then n = 5
		if n > 5 then n = 0

		name = 'theme_' + n
		$('html').attr 'class', name
		$('.dotstyle li.current').removeClass 'current'
		$('.dotstyle li:eq(' + n + ')').addClass 'current'

	stop: (event)->
		event.stopPropagation()
		event.preventDefault()

	handleDrop: (files)=>
		if files.length > 0
			urls = []
			for file in files
				urls.push(window.URL.createObjectURL(file))
			@player.playlist = urls
			@player.playIndex(0)

$ ->
	player = new Player()
	player.playIndex(0)

	compute = new Compute(player)
	render = new Render(player, compute)

	setInterval(render.draw, 40)

	helper = new Helper(render, player)
	helper.bindMouse()
	helper.themeChange(5)
