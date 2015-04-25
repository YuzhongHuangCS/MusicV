(->
	self = this
	# use global context rather than window object
	waveform_array = undefined
	old_waveform = undefined
	objectUrl = undefined
	metaHide = undefined
	micStream = undefined
	# raw waveform data from web audio api
	WAVE_DATA = []
	# normalized waveform data used in visualizations

	# main app/init stuff //////////////////////////////////////////////////////////////////////////
	a = {}

	a.init = ->
		console.log 'a.init fired'
		# globals & state
		self.State = 
			playlist: ['dawn.mp3', 'forgot.mp3']
			width: $(document).width()
			height: $(document).height()
			sliderVal: 50
			canKick: true
			metaLock: false
			vendors: ['-webkit-', '-moz-', '-o-', '']
			drawInterval: 1000 / 24
			then: Date.now()
			trigger: 'circle'
			hud: 1
			active: null
			vizNum: 0
			thumbs_init: [0, 0, 0, 0, 0, 0, 0, 0]
			theme: 0
			currentSong: 0

		self.context = new (window.AudioContext || window.webkitAudioContext)()

		# append main svg element
		self.svg = d3.select('body').append('svg').attr('id', 'viz').attr('width', State.width).attr('height', State.height)

		a.bind()

		a.keyboard()

		a.loadSound()

		# build svg
		canvas = document.getElementById('canvas-blended')
		ctx = canvas.getContext('2d')
		ctx.fillStyle = '#FF0000'
		ctx.strokeStyle = '#00FF00'
		ctx.lineWidth = 5
		console.log 'Inintializing'
		camMotion = CamMotion.Engine()
		console.log camMotion
		camMotion.on 'error', (e) ->
			console.log 'error', e

		console.log camMotion
		camMotion.on 'streamInit', (e) ->
			console.log 'webcam stream initialized', e

		camMotion.on 'frame', ->
			ctx.clearRect 0, 0, 640, 480
			point = camMotion.getMovementPoint(true)
			console.log point
			# draw a circle
			ctx.beginPath()
			ctx.arc point.x, point.y, point.r, 0, Math.PI * 2, true
			ctx.closePath()
			if camMotion.getAverageMovement(point.x - point.r / 2, point.y - point.r / 2, point.r, point.r) > 4
				ctx.fill()
				str = 'rotateX(' + point.x / 10 + 'deg)' + 'rotateY(' + point.y / 10 + 'deg)'
				$('svg').css 'transform', str
			else
				ctx.stroke()

		camMotion.start()

	a.bind = ->
		console.log 'a.bind fired'
		click = if Helper.isMobile() then 'touchstart' else 'click'
		$('.menu, .icon-menu').on 'mouseenter touchstart', ->
			h.toggleMenu 'open'

		$('.menu').on 'mouseleave', ->
			h.toggleMenu 'close'

		$('.menu').on click, 'li', ->
			h.vizChange +$(this).attr('viz-num')

		$('.menu').on click, '.clicker', ->
			h.vizChange +$(this).closest('li').attr('viz-num')

		$('.song-metadata').on click, h.songGo
		$('.wrapper').on click, ->
			h.toggleMenu 'close'

		$('.icon-pause').on click, h.togglePlay
		$('.icon-play').on click, h.togglePlay
		$('.icon-forward2').on click, ->
			h.changeSong 'n'

		$('.icon-backward2').on click, ->
			h.changeSong 'p'

		$('.icon-expand').on click, h.toggleFullScreen
		$('.icon-microphone').on click, a.microphone
		$('.sc_import').on click, a.soundCloud
		$('.icon-question').on click, ->
			h.showModal '#modal-about'

		$('.icon-keyboard2').on click, ->
			h.showModal '#modal-keyboard'

		$('.icon-volume-medium').on click, ->
			audio.muted = if `audio.muted == true` then false else true

		$('.icon-loop-on').on click, ->
			$(this).find('b').text State.loopText[State.loop % 4]
			h.infiniteChange State.loopDelay[State.loop++ % 4]

		$('.md-close').on click, h.hideModals
		$('.dotstyle').on click, 'li', ->
			h.themeChange $(this).find('a').text()

		$('#slider').on 'input change', ->
			analyser.smoothingTimeConstant = 1 - @value / 100

		$('#slider').on 'change', ->
			$('#slider').blur()

		$('.i').on 'mouseenter', h.tooltipReplace
		$('.i').on 'mouseleave', h.tooltipUnReplace
		$(document).on 'dragenter', h.stop
		$(document).on 'dragover', h.stop
		$(document).on 'drop', h.handleDrop
		document.addEventListener 'waveform', (e) ->
			#console.log(e.detail);
			waveform_array = e.detail
			#audio = this;
		, false

		# hide HUD on idle mouse
		hide = setTimeout ->
			h.hideHUD()
		, 2000

		$('body').on 'touchstart mousemove', ->
			h.showHUD()
			clearTimeout(hide)
			hide = setTimeout ->
				h.hideHUD()
			, 2000


		# update state on window resize
		window.onresize = (event) ->
			h.resize()

		$(document).on 'webkitfullscreenchange mozfullscreenchange fullscreenchange', h.resize
		#http://stackoverflow.com/a/9775411

	a.keyboard = ->
		console.log 'a.keyboard fired'
		Mousetrap.bind 'esc', h.hideModals
		Mousetrap.bind 'space', h.togglePlay
		Mousetrap.bind 'f', h.toggleFullScreen
		Mousetrap.bind 'm', ->
			h.toggleMenu 'toggle'

		Mousetrap.bind 'c', ->
			h.changeSong()

		Mousetrap.bind 'l', ->
			$('.icon-loop-on').trigger 'click'

		Mousetrap.bind 'k', ->
			$('.icon-keyboard2').trigger 'click'

		Mousetrap.bind 'v', ->
			h.changeSong 'n'

		Mousetrap.bind 'x', ->
			h.changeSong 'p'

		Mousetrap.bind '1', ->
			State.trigger = 'circle'

		Mousetrap.bind '3', ->
			State.trigger = 'icosahedron'

		Mousetrap.bind '4', ->
			State.trigger = 'grid'

		Mousetrap.bind '6', ->
			State.trigger = 'spin'

		Mousetrap.bind '7', ->
			State.trigger = 'hexbin'

		Mousetrap.bind '8', ->
			State.trigger = 'voronoi'

		Mousetrap.bind 'up', ->
			h.vizChange State.vizNum - 1

		Mousetrap.bind 'down', ->
			h.vizChange State.vizNum + 1

		Mousetrap.bind 'left', ->
			h.themeChange State.theme - 1

		Mousetrap.bind 'right', ->
			h.themeChange State.theme + 1


	a.loadSound = ->
		console.log 'a.loadSound fired'
		if navigator.userAgent.search('Safari') >= 0 and navigator.userAgent.search('Chrome') < 0
			console.log ' -- sound loaded via ajax request'
			$('.menu-controls').hide()
			a.loadSoundAJAX()
		else
			console.log ' -- sound loaded via html5 audio'
			path = 'mp3/' + State.playlist[0]
			a.loadSoundHTML5 path
			h.readID3 path
		return

	a.loadSoundAJAX = ->
		console.log 'a.loadSoundAJAX fired'
		audio = null
		request = new XMLHttpRequest
		request.open 'GET', 'mp3/' + State.playlist[0], true
		request.responseType = 'arraybuffer'

		request.onload = (event) ->
			data = event.target.response
			a.audioBullshit data


		request.send()

	a.loadSoundHTML5 = (f) ->
		console.log 'a.loadSoundHTML5 fired'
		`audio = new Audio()`
		#audio.remove();
		audio.src = f
		#audio.controls = true;
		#audio.loop = true;
		audio.autoplay = true
		audio.addEventListener 'ended', (->
			h.songEnded()
			return
		), false
		$('#audio_box').empty()
		document.getElementById('audio_box').appendChild audio
		a.audioBullshit()
		return

	a.microphone = ->
		console.log 'a.microphone fired'
		navigator.getUserMedia = navigator.getUserMedia or navigator.webkitGetUserMedia or navigator.mozGetUserMedia or navigator.msGetUserMedia
		if `micStream == null`
			if navigator.getUserMedia
				navigator.getUserMedia {
					audio: true
					video: false
				}, ((stream) ->
					console.log ' --> audio being captured'
					micStream = stream
					console.log micStream
					src = window.URL.createObjectURL(micStream)
					self.source = context.createMediaStreamSource(micStream)
					source.connect analyser
					analyser.connect context.destination
					audio.pause()
					#audio.src = null;
					return
				), h.microphoneError
			else
				# fallback.
		else
			console.log ' --> turning off'
			micStream.stop()
			micStream = null
			audio.play()
		return

	a.audioBullshit = (data) ->
		# uses web audio api to expose waveform data
		console.log 'a.audioBullshit fired'
		self.analyser = context.createAnalyser()
		#analyser.smoothingTimeConstant = .4; // .8 default
		if navigator.userAgent.search('Safari') >= 0 and navigator.userAgent.search('Chrome') < 0
			self.source = context.createBufferSource()
			source.buffer = context.createBuffer(data, false)
			source.loop = true
			source.noteOn 0
		else
			# https://developer.mozilla.org/en-US/docs/Web/API/AudioContext.createScriptProcessor
			self.source = context.createMediaElementSource(audio)
			# doesn't seem to be implemented in safari :(
			#self.source = context.createMediaStreamSource()
			#self.source = context.createScriptProcessor(4096, 1, 1);  
		source.connect analyser
		analyser.connect context.destination
		a.frameLooper()
		return

	a.findAudio = ->
		# unused.
		console.log 'a.findAudio fired'
		$('video, audio').each ->
			#h.loadSoundHTML5(this.src);
			# if .src?  if playing?
			`audio = this`
			a.audioBullshit()
			return
		#$('object')
		#swf?  SWFObject?
		# can use soundmanager2 -- > http://schillmania.com/projects/soundmanager2/
		# waveformData in sound object gives 256 array.  just multiply by 4?
		return

	a.frameLooper = ->
		#console.log("a.frameLooper fired");
		# recursive function used to update audio waveform data and redraw visualization
		window.requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or window.webkitRequestAnimationFrame or window.msRequestAnimationFrame
		window.requestAnimationFrame a.frameLooper
		`now = Date.now()`
		`delta = now - State.then`
		if audio
			$('#progressBar').attr 'style', 'width: ' + audio.currentTime / audio.duration * 100 + '%'
		# some framerate limiting logic -- http://codetheory.in/controlling-the-frame-rate-with-requestanimationframe/
		if delta > State.drawInterval
			State.then = now - delta % State.drawInterval
			# update waveform data
			if `h.detectEnvironment() != 'chrome-extension'`
				waveform_array = new Uint8Array(analyser.frequencyBinCount)
				analyser.getByteFrequencyData waveform_array
				#analyser.getByteTimeDomainData(waveform_array);
			# if (c.kickDetect(95)) {
			# 	h.themeChange(Math.floor(Math.random() * 6));
			#  	h.vizChange(Math.floor(Math.random() * 7));
			# }
			# draw all thumbnails
			r.circle_thumb()
			r.icosahedron_thumb()
			r.grid_thumb()
			r.spin_thumb()
			r.hexbin_thumb()
			# draw active visualizer
			switch State.trigger
				when 'circle', 0
					State.vizNum = 0
					r.circle()
				when 'icosahedron', 2
					State.vizNum = 2
					r.icosahedron()
				when 'grid', 3
					State.vizNum = 3
					r.grid()
				when 'spin', 5
					State.vizNum = 5
					r.spin()
				when 'hexbin', 6
					State.vizNum = 6
					r.hexbin()
				when 'voronoi', 7
					State.vizNum = 7
					r.voronoi()
				else
					State.vizNum = 0
					r.circle()
					break
		return

	self.App = a
	# manipulating/normalizing waveform data ///////////////////////////////////////////////////////
	c = {}

	c.kickDetect = (threshold) ->
		kick = false
		deltas = $(waveform_array).each((n, i) ->
			if !old_waveform
				0
			else
				old_waveform[i] - n
		)
		s = d3.sum(deltas) / 1024
		if s > threshold and State.canKick
			kick = true
			State.canKick = false
			setTimeout (->
				State.canKick = true
				return
			), 5000
		self.old_waveform = waveform_array
		kick

	c.normalize = (coef, offset, neg) ->
		`var offset`
		`var coef`
		#https://stackoverflow.com/questions/13368046/how-to-normalize-a-list-of-positive-numbers-in-javascript
		coef = coef or 1
		offset = offset or 0
		numbers = waveform_array
		numbers2 = []
		ratio = Math.max.apply(Math, numbers)
		l = numbers.length
		i = 0
		while i < l
			if `numbers[i] == 0`
				numbers2[i] = 0 + offset
			else
				numbers2[i] = numbers[i] / ratio * coef + offset
			if `i % 2 == 0` and neg
				numbers2[i] = -Math.abs(numbers2[i])
			i++
		numbers2

	c.normalize_binned = (binsize, coef, offset, neg) ->
		numbers = []
		temp = 0
		i = 0
		while i < waveform_array.length
			temp += waveform_array[i]
			if `i % binsize == 0`
				numbers.push temp / binsize
				temp = 0
			i++
		coef = coef or 1
		offset = offset or 0
		numbers2 = []
		ratio = Math.max.apply(Math, numbers)
		l = numbers.length
		while i < l
			if `numbers[i] == 0`
				numbers2[i] = 0 + offset
			else
				numbers2[i] = numbers[i] / ratio * coef + offset
			if `i % 2 == 0` and neg
				numbers2[i] = -Math.abs(numbers2[i])
			i++
		numbers2

	c.total = ->
		Math.floor d3.sum(waveform_array) / waveform_array.length

	c.total_normalized = ->

	c.bins_select = (binsize) ->
		copy = []
		i = 0
		while i < 500
			if `i % binsize == 0`
				copy.push waveform_array[i]
			i++
		copy

	c.bins_avg = (binsize) ->
		`var binsize`
		binsize = binsize or 100
		copy = []
		temp = 0
		while i < waveform_array.length
			temp += waveform_array[i]
			if `i % binsize == 0`
				copy.push temp / binsize
				temp = 0
			i++
		#console.log(copy);
		copy

	self.Compute = c
	# rendering svg based on normalized waveform data //////////////////////////////////////////////
	r = {}

	r.circle = ->
		if `State.active != 'circle'`
			State.active = 'circle'
			$('body > svg').empty()
		WAVE_DATA = c.bins_select(70)
		x = d3.scale.linear().domain([
			0
			d3.max(WAVE_DATA)
		]).range([
			0
			420
		])
		slideScale = d3.scale.linear().domain([
			1
			100
		]).range([
			0
			2
		])
		self.bars = svg.selectAll('circle').data(WAVE_DATA, (d) ->
			d
		)
		# bars.attr("r", function(d) { return x(d) + ""; })
		# 	.attr('transform', "scale("+slideScale(State.sliderVal)+")")
		# 	.attr("cy", function(d, i) { return '50%'; })
		# 	.attr("cx", function(d, i) { return '50%'; });
		bars.enter().append('circle').attr('transform', 'scale(' + slideScale(State.sliderVal) + ')').attr('cy', (d, i) ->
			'50%'
		).attr('cx', (d, i) ->
			'50%'
		).attr 'r', (d) ->
			x(d) + ''
		bars.exit().remove()
		return

	r.circle_thumb = ->
		if `State.thumbs_init[0] != 'init'`
			State.thumbs_init[0] = 'init'
			self.svg_thumb_one = d3.select('#circle').append('svg').attr('width', '100%').attr('height', '100%')
		WAVE_DATA = c.bins_select(200)
		x_t1 = d3.scale.linear().domain([
			0
			d3.max(WAVE_DATA)
		]).range([
			0
			80
		])
		bars_t1 = svg_thumb_one.selectAll('circle').data(WAVE_DATA, (d) ->
			d
		)
		# bars_t1.attr("r", function(d) { return x_t1(d) + ""; })
		# 	.attr("cy", function(d, i) { return '50%'; })
		# 	.attr("cx", function(d, i) { return '50%'; });
		bars_t1.enter().append('circle').attr('cy', (d, i) ->
			'50%'
		).attr('cx', (d, i) ->
			'50%'
		).attr 'r', (d) ->
			x_t1(d) + ''
		bars_t1.exit().remove()
		return

	r.icosahedron = ->
		# http://bl.ocks.org/mbostock/7782500
		if `State.active == 'icosahedron'`
			time = Date.now() - t0
			xx = c.total() / 100
			style = ''
			i = 0
			while i < State.vendors.length
				style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('body > svg path').attr 'style', style
			#$('body > svg path').attr("style", "transform: skew("+xx+"deg,"+xx+"deg)");
			# 1
			projection.rotate [
				time * velocity[0]
				time * velocity[1]
			]
			face.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = projection(p)
					return
				return
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			# 2
			projection2.rotate [
				time * velocity2[0]
				time * velocity2[1]
			]
			face2.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = projection2(p)
					return
				return
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			# 3
			projection3.rotate [
				time * velocity3[0]
				time * velocity3[1]
			]
			face3.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = projection3(p)
					return
				return
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			return
		State.active = 'icosahedron'
		$('body > svg').empty()
		width = State.width
		height = State.height
		self.velocity = [0.10, 0.005]
		self.velocity2 = [-0.10, -0.05]
		self.velocity3 = [0.10, 0.1]
		t0 = Date.now()
		
		# 1
		self.projection = d3.geo.orthographic().scale(height / 2).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg = d3.select('body').append('svg').attr('class', 'isoco1').attr('width', width).attr('height', height)
		self.face = svg.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(projection))
			return
		)
		# 2
		self.projection2 = d3.geo.orthographic().scale(height / 4).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg2 = d3.select('body').append('svg').attr('class', 'isoco2').attr('width', width).attr('height', height)
		self.face2 = svg2.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(projection2))
			return
		)
		# 3
		self.projection3 = d3.geo.orthographic().scale(height / 1).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])
		
		svg3 = d3.select('body').append('svg').attr('class', 'isoco3').attr('width', width).attr('height', height)
		self.face3 = svg3.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each((d) ->
			d.polygon = d3.geom.polygon(d.map(projection3))
			return
		)
		return

	r.icosahedron_thumb = ->
		if `State.thumbs_init[2] == 'init'`
			xx_t0 = c.total() / 100
			time_t0 = Date.now() - t0_thumb
			style = ''
			i = 0
			while i < State.vendors.length
				style += State.vendors[i] + 'transform: scale(' + xx_t0 + ',' + xx_t0 + '); '
				i++
			$('#icosahedron svg path').attr 'style', style
			projection_thumb.rotate [
				time_t0 * velocity_thumb[0]
				time_t0 * velocity_thumb[1]
			]
			'''
			self.face_thumb.each((d) ->
				d.forEach (p, i) ->
					d.polygon[i] = projection_thumb(p)
					return
				return
			).style('display', (d) ->
				if d.polygon.area() > 0 then null else 'none'
			).attr 'd', (d) ->
				'M' + d.polygon.join('L') + 'Z'
			'''
		State.thumbs_init[2] = 'init'
		width = $('#icosahedron').width()
		height = $('#icosahedron').height()
		self.velocity_thumb = [
			.01
			.05
		]
		self.t0_thumb = Date.now()
		self.projection_thumb = d3.geo.orthographic().scale(height * 1.5).translate([
			width / 2
			height / 2
		]).center([
			0
			0
		])

		self.svg_thumb_three = d3.select('#icosahedron').append('svg').attr('width', width).attr('height', height)
		self.face_thumb = svg_thumb_three.selectAll('path').data(h.icosahedronFaces).enter().append('path').each((d) ->
			d.polygon = d3.geom.polygon(d.map(projection_thumb))
			return
		)

	r.grid2 = (data) ->
		# http://bl.ocks.org/mbostock/5731578
		if `State.active == 'grid'`
			dt = Date.now() - time
			projection.rotate [
				rotate[0] + velocity[0] * dt
				rotate[1] + velocity[1] * dt
			]
			feature.attr 'd', path
			return
		$('body > svg').empty()
		State.active = 'grid'
		self.rotate = [
			10
			-10
		]
		self.velocity = [
			.03
			-.01
		]
		self.time = Date.now()
		self.projection = d3.geo.orthographic().scale(240).translate([
			State.width / 2
			State.height / 2
		]).clipAngle(90 + 1e-6).precision(.3)
		self.path = d3.geo.path().projection(projection)
		`graticule = d3.geo.graticule().minorExtent([
	[
		-180,
		-89
	],
	[
		180,
		89 + 0.0001
	]
])`
		svg.append('path').datum(type: 'Sphere').attr('class', 'sphere').attr 'd', path
		svg.append('path').datum(graticule).attr('class', 'graticule').attr 'd', path
		# svg.append("path")
		#     .datum({type: "LineString", coordinates: [[-180, 0], [-90, 0], [0, 0], [90, 0], [180, 0]]})
		#     .attr("class", "equator")
		#     .attr("d", path);
		self.feature = svg.selectAll('path')
		return

	r.grid = (data) ->
		if `State.active == 'grid'`
			xx = c.total() / 100 + 1
			xx = if xx < 1 then 1 else xx
			xx = if xx > 1.1 then 1.1 else xx
			style = ''
			i = 0
			while i < State.vendors.length
				style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('body > svg path').attr 'style', style
			projection.rotate [
				λ(p)
				φ(p)
			]
			#projection.rotate([λ(p), 0]);
			svg.selectAll('path').attr 'd', path
			`p = p + 5`
			#((c.total()/100)*10);
			`step = Math.floor(c.total() / 100 * 60)`
			`step = step < 5 ? 5 : step`
			`graticule = d3.geo.graticule().minorStep([
	step,
	step
]).minorExtent([
	[
		-180,
		-90
	],
	[
		180,
		90 + 0.0001
	]
])`
			grat.datum(graticule).attr('class', 'graticule').attr 'd', path
			return
		`p = 0`
		State.active = 'grid'
		$('body > svg').empty()
		`projection = d3.geo.gnomonic().clipAngle(80).scale(500)`
		`path = d3.geo.path().projection(projection)`
		`graticule = d3.geo.graticule().minorStep([
	5,
	5
]).minorExtent([
	[
		-180,
		-90
	],
	[
		180,
		90 + 0.0001
	]
])`
		# lamda / longitude
		`λ = d3.scale.linear().domain([
	0,
	State.width
]).range([
	-180,
	180
])`
		# phi / latitude
		`φ = d3.scale.linear().domain([
	0,
	State.height
]).range([
	90,
	-90
])`
		`grat = svg.append('path').datum(graticule).attr('class', 'graticule').attr('d', path)`
		return

	r.grid_thumb = (data) ->
		width = $('#grid').width()
		height = $('#grid').height()
		if `State.thumbs_init[3] == 'init'`
			xx = c.total() / 100 + 1
			xx = if `xx == 1` then 0 else xx
			#	xx = (xx>1.4) ? 1.4 : xx;
			style = ''
			i = 0
			while i < State.vendors.length
				style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); '
				i++
			$('#grid svg path').attr 'style', style
			# step = Math.floor((c.total()/100)*5);
			# step = (step<1) ? 1 : step;
			# graticule = d3.geo.graticule()
			# 	.minorStep([step, step])
			# 	.minorExtent([[-180, -90], [180, 90 + 1e-4]]);
			# grat.datum(graticule)
			# 	.attr("class", "graticule")
			# 	.attr("d", path);
			return
		State.thumbs_init[3] = 'init'
		$('#grid svg').empty()
		`projection = d3.geo.gnomonic().clipAngle(80)`
		#.scale(50)
		`path = d3.geo.path().projection(projection)`
		`graticule = d3.geo.graticule().minorStep([
	2,
	2
]).minorExtent([
	[
		-180,
		-90
	],
	[
		180,
		90 + 0.0001
	]
])`
		`svg_thumb_four = d3.select('#grid').append('svg').attr('width', width).attr('height', height)`
		`grat = svg_thumb_four.append('path').datum(graticule).attr('class', 'graticule').attr('d', path)`
		return

	r.spin = ->
		if `State.active == 'spin'`
			WAVE_DATA = c.total() * 2
			#WAVE_DATA = c.normalize_binned(200,1000,10);
			$c = $('body > svg circle')
			$c.attr 'style', 'stroke-width: ' + WAVE_DATA * 4 + 'px'
			$c.attr 'stroke-dashoffset', WAVE_DATA + 'px'
			$c.attr 'stroke-dasharray', WAVE_DATA / 6 + 'px'
			$c.attr 'opacity', WAVE_DATA / 2200
			return
		State.active = 'spin'
		$('body > svg').empty()
		elems = [
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
		`bars = svg.selectAll('circle').data(elems, function (d, i) {
	return i;
})`
		bars.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', (d) ->
			d.id
		).attr 'r', (d) ->
			d.radius + ''
		bars.exit().remove()
		return

	r.spin_thumb = ->
		if `State.thumbs_init[5] == 'init'`
			WAVE_DATA = c.total() * 2
			#WAVE_DATA = c.normalize_binned(200,1000,10);
			$c = $('#spin svg circle')
			$c.attr 'style', 'stroke-width: ' + WAVE_DATA * 4 + 'px'
			$c.attr 'stroke-dashoffset', WAVE_DATA + 'px'
			$c.attr 'stroke-dasharray', WAVE_DATA / 6 + 'px'
			$c.attr 'opacity', WAVE_DATA / 2200
			return
		$('#spin svg').empty()
		State.thumbs_init[5] = 'init'
		self.svg_thumb_six = d3.select('#spin').append('svg').attr('width', '100%').attr('height', '100%')
		elems = [
			{
				id: 'c4'
				radius: 10
			}
			{
				id: 'c3'
				radius: 50
			}
		]
		`bars_t6 = svg_thumb_six.selectAll('circle').data(elems, function (d, i) {
	return i;
})`
		bars_t6.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', (d) ->
			d.id
		).attr 'r', (d) ->
			d.radius + ''
		bars_t6.exit().remove()
		return

	r.hexbin = ->
		# http://bl.ocks.org/mbostock/4248145 
		# http://bl.ocks.org/mbostock/4248146
		$('body > svg').empty()
		if `State.active != 'hexbin'`
			`randomX = d3.random.normal(State.width / 2, 700)`
			`ps = d3.range(1024).map(function () {
	return randomX();
})`
		State.active = 'hexbin'
		`points = d3.zip(ps, c.normalize(State.height, 0))`
		#randomY = d3.random.normal(height / 2, 300),
		#points = d3.range(2000).map(function() { return [randomX(), randomY()]; });
		`color = d3.scale.linear().domain([
	0,
	20
]).range([
	$('.dotstyle li.current a').css('background-color'),
	$('.dotstyle li.current a').css('background-color')
]).interpolate(d3.interpolateLab)`
		`hexbin = d3.hexbin().size([
	State.width,
	State.height
]).radius(50)`
		`radius = d3.scale.linear().domain([
	0,
	20
]).range([
	0,
	130
])`
		svg.append('g').selectAll('.hexagon').data(hexbin(points)).enter().append('path').attr('class', 'hexagon').attr('id', 'hexx').attr('d', (d) ->
			hexbin.hexagon radius(d.length)
		).attr('transform', (d) ->
			'translate(' + d.x + ',' + d.y + ')'
		).style('fill', (d) ->
			color d.length
		).style 'opacity', (d) ->
			0.8 - radius(d.length) / 180
		return

	r.hexbin_thumb = ->
		# http://bl.ocks.org/mbostock/4248145 
		# http://bl.ocks.org/mbostock/4248146
		width = $('#hexbin').width()
		height = $('#hexbin').height()
		if `State.thumbs_init[6] != 'init'`
			self.svg_thumb_seven = d3.select('#hexbin').append('svg').attr('width', '100%').attr('height', '100%')
			State.thumbs_init[6] = 'init'
			`randomX_t7 = d3.random.normal(width / 2, 50)`
			`ps_t7 = d3.range(1024).map(function () {
	return randomX_t7();
})`
		$('#hexbin svg').empty()
		`points_t7 = d3.zip(ps_t7, c.normalize(height * 1.5, -20))`
		`color_t7 = d3.scale.linear().domain([
	0,
	50
]).range([
	'black',
	'white'
]).interpolate(d3.interpolateLab)`
		`hexbin_t7 = d3.hexbin().size([
	width,
	height
]).radius(15)`
		`radius_t7 = d3.scale.linear().domain([
	0,
	10
]).range([
	0,
	15
])`
		svg_thumb_seven.append('g').selectAll('.hexagon').data(hexbin_t7(points_t7)).enter().append('path').attr('class', 'hexagon').attr('d', (d) ->
			hexbin_t7.hexagon 15
		).attr('transform', (d) ->
			'translate(' + d.x + ',' + d.y + ')'
		).style 'fill', (d) ->
			color_t7 d.length
		return

	r.voronoi = ->
		# http://bl.ocks.org/mbostock/4060366

		redraw = ->
			`vertices = d3.range(100).map(function (d) {
	return [
		Math.random() * width,
		Math.random() * height
	];
})`
			`path = path.data(voronoi(vertices), polygon)`
			path.exit().remove()
			path.enter().append('path').attr('class', (d, i) ->
				'q' + i % 9 + '-9'
			).attr 'd', polygon
			path.order()
			return

		polygon = (d) ->
			'M' + d.join('L') + 'Z'

		if `State.active == 'voronoi'`
			redraw()
			return
		State.active = 'voronoi'
		`width = State.width`
		`height = State.height`
		`vertices = d3.range(100).map(function (d) {
	return [
		Math.random() * width,
		Math.random() * height
	];
})`
		`voronoi = d3.geom.voronoi().clipExtent([
	[
		0,
		0
	],
	[
		width,
		height
	]
])`
		`svg = d3.select('body').append('svg').attr('width', width).attr('height', height)`
		`path = svg.append('g').selectAll('path')`
		svg.selectAll('circle').data(vertices.slice(1)).enter().append('circle').attr('transform', (d) ->
			'translate(' + d + ')'
		).attr 'r', 1.5
		redraw()
		return

	self.Render = r
	# helper methods ///////////////////////////////////////////////////////////////////////////////
	h = {}

	h.toggleMenu = (x) ->
		console.log 'h.toggleMenu'
		if `x == 'toggle'`
			x = if $('.menu').hasClass('menu-open') then 'close' else 'open'
		if `x == 'open'`
			$('.menu').addClass 'menu-open'
			$('.icon-menu').addClass 'fadeOut'
			#$("body > svg").attr("class", "svg-open");
		else
			$('.menu').removeClass 'menu-open'
			#$("body > svg").attr("class", "svg-closed");
		return

	h.toggleFullScreen = ->
		console.log 'h.toggleFullScreen fired'
		# thanks mdn
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
		return

	h.hideHUD = ->
		#$('.icon-knobs').is(':hover') || 
		if $('#mp3_player').is(':hover') or $('.dotstyle').is(':hover') or $('.slider').is(':hover') or $('.icon-expand').is(':hover') or $('.icon-github2').is(':hover') or $('.icon-loop-on').is(':hover') or $('.icon-question').is(':hover') or $('.icon-keyboard2').is(':hover') or $('.song-metadata').is(':hover') or $('.icon-forward2').is(':hover') or $('.icon-backward2').is(':hover') or $('.icon-pause').is(':hover') or $('.schover').is(':hover')
			return
		$('#mp3_player').addClass 'fadeOut'
		$('.icon-menu').addClass 'fadeOut'
		$('.menu-wide').addClass 'fadeOut'
		$('.menu').addClass 'fadeOut'
		$('.menu-controls').addClass 'fadeOut'
		$('#progressBar').addClass 'fadeOut'
		$('html').addClass 'noCursor'
		if `State.metaLock == false`
			$('.song-metadata').removeClass 'show-meta'
		State.hud = 0
		return

	h.showHUD = ->
		$('#mp3_player').removeClass 'fadeOut'
		$('.icon-menu').removeClass 'fadeOut'
		$('.menu-wide').removeClass 'fadeOut'
		$('.menu').removeClass 'fadeOut'
		$('.menu-controls').removeClass 'fadeOut'
		$('#progressBar').removeClass 'fadeOut'
		$('html').removeClass 'noCursor'
		$('.song-metadata').addClass 'show-meta'
		State.hud = 1
		return

	h.showModal = (id) ->
		if $(id).hasClass('md-show')
			h.hideModals()
			return
		if $('.md-show').length > 0
			h.hideModals()
		$(id).addClass 'md-show'
		return

	h.hideModals = ->
		$('.md-modal').removeClass 'md-show'
		return

	h.resize = ->
		console.log 'h.resize fired'
		State.width = $(window).width()
		State.height = $(window).height()
		State.active = State.trigger
		$('body > svg').attr('width', State.width).attr 'height', State.height
		full = document.fullscreen or document.webkitIsFullScreen or document.mozFullScreen
		if !full
			$('.icon-expand').removeClass 'icon-contract'
		return

	h.stop = (e) ->
		e.stopPropagation()
		e.preventDefault()
		return

	h.handleDrop = (e) ->
		`var objectUrl`
		console.log 'h.handleDrop fired'
		h.stop e
		h.removeSoundCloud()
		#if (window.File && window.FileReader && window.FileList && window.Blob) {
		URL.revokeObjectURL objectUrl
		file = e.originalEvent.dataTransfer.files[0]
		if !file.type.match(/audio.*/)
			console.log 'not audio file'
			return
		h.readID3 file
		objectUrl = URL.createObjectURL(file)
		a.loadSoundHTML5 objectUrl
		return

	h.readID3 = (file) ->
		console.log 'h.readID3 fired'
		$('.song-metadata').html ''
		if `typeof file == 'string'`
			ID3.loadTags audio.src, ->
				tags = ID3.getAllTags(audio.src)
				h.renderSongTitle tags
				return
		else
			ID3.loadTags file.urn or file.name, (->
				tags = ID3.getAllTags(file.urn or file.name)
				tags.dragged = true
				h.renderSongTitle tags
				if 'picture' in tags
					image = tags.picture
					base64String = ''
					i = 0
					while i < image.data.length
						base64String += String.fromCharCode(image.data[i])
						i++
					#console.log("data:" + image.format + ";base64," + window.btoa(base64String));
					#$("art").src = "data:" + image.format + ";base64," + window.btoa(base64String);
					#$("art").style.display = "block";
				else
					#console.log("nope.");
					#$("art").style.display = "none";
				return
			), dataReader: FileAPIReader(file)
		return

	h.removeSoundCloud = ->
		State.soundCloudURL = null
		State.soundCloudData = null
		State.soundCloudTracks = null
		$('.song-metadata').html ''
		$('.song-metadata').attr 'data-go', ''
		$('#sc_input').val ''
		$('#sc_url span').html 'SOUNDCLOUD_URL'
		# load local songs?
		return

	h.togglePlay = ->
		if audio and `audio.paused == false` then audio.pause() else audio.play()
		$('.icon-pause').toggleClass 'icon-play'
		return

	h.songEnded = ->
		console.log 'h.songEnded fired'
		h.changeSong 'n'
		return

	h.changeSong = (direction) ->
		console.log 'h.changeSong fired'
		totalTracks = State.soundCloudTracks or State.playlist.length
		if State.soundCloudData and State.soundCloudTracks <= 1
			audio.currentTime = 0
			$('.icon-pause').removeClass 'icon-play'
			return
		if `direction == 'n'`
			State.currentSong = State.currentSong + 1
		else if `direction == 'p'`
			if audio.currentTime < 3
				State.currentSong = if State.currentSong <= 0 then State.currentSong + totalTracks - 1 else State.currentSong - 1
			else
				audio.currentTime = 0
				$('.icon-pause').removeClass 'icon-play'
				return
		else
			State.currentSong = Math.floor(Math.random() * totalTracks)
		if State.soundCloudData
			trackNum = Math.abs(State.currentSong) % State.soundCloudTracks
			h.renderSongTitle State.soundCloudData[trackNum]
			a.loadSoundHTML5 State.soundCloudData[trackNum].uri + '/stream?client_id=67129366c767d009ecc75cec10fa3d0f'
		else
			if audio
				audio.src = 'mp3/' + State.playlist[Math.abs(State.currentSong) % State.playlist.length]
				h.readID3 audio.src
		$('.icon-pause').removeClass 'icon-play'
		return

	h.renderSongTitle = (obj) ->
		`var trackNum`
		`var prettyTitle`
		console.log 'h.renderSongTitle fired'
		if State.soundCloudData
			trackNum = Math.abs(State.currentSong) % State.soundCloudTracks
			regs = new RegExp(obj.user.username, 'gi')
			prettyTitle = obj.title
			if `prettyTitle.search(regs) == -1`
				prettyTitle += ' <b>' + obj.user.username + '</b>'
			#var prettyTitle = obj.title.replace(regs, "<b>"+obj.user.username+"</b>");
			if State.soundCloudTracks > 1
				prettyTitle += ' [' + trackNum + 1 + '/' + State.soundCloudTracks + ']'
			$('.song-metadata').html prettyTitle
			$('.song-metadata').attr 'data-go', obj.permalink_url
		else
			# id3?
			prettyTitle = '"' + obj.title + '" by <b>' + obj.artist + '</b>'
			#  on <i>'+tags.album+'</i>
			trackNum = Math.abs(State.currentSong) % State.playlist.length
			if State.playlist.length > 1 and !obj.dragged
				prettyTitle += ' [' + trackNum + 1 + '/' + State.playlist.length + ']'
			$('.song-metadata').html prettyTitle
			#$('.song-metadata').attr('data-go', State.playListLinks[trackNum]);
		$('.song-metadata').addClass 'show-meta'
		State.metaLock = true
		clearTimeout metaHide
		# in 3 seconds, remove class unless lock
		metaHide = setTimeout((->
			State.metaLock = false
			if `State.hud == 0`
				$('.song-metadata').removeClass 'show-meta'
			return
		), 3000)
		return

	h.tooltipReplace = ->
		console.log 'h.tooltipReplace fired'
		text = $(this).attr('data-hovertext')
		console.log text
		if `text != null`
			State.hoverTemp = $('.song-metadata').html()
			$('.song-metadata').html text
		return

	h.tooltipUnReplace = ->
		console.log 'h.tooltipUnReplace fired'
		if `State.hoverTemp != null`
			$('.song-metadata').html State.hoverTemp
			State.hoverTemp = null
		return

	h.songGo = ->
		console.log 'h.songGo fired.'
		if !$(this).attr('data-go')
			return false
		audio.pause()
		$('.icon-pause').removeClass 'icon-play'
		window.open $(this).attr('data-go'), '_blank'
		return

	h.themeChange = (n) ->
		n = +n
		n = if n < 0 then 5 else n
		n = if n > 5 then 0 else n
		State.theme = n
		console.log 'h.themeChange:' + n
		name = 'theme_' + n
		$('html').attr 'class', name
		$('.dotstyle li.current').removeClass 'current'
		$('.dotstyle li:eq(' + n + ')').addClass 'current'
		return

	h.vizChange = (n) ->
		n = if n < 0 then 6 else n
		n = if n > 6 then 0 else n
		console.log 'h.vizChange:' + n
		State.trigger = n
		$('.menu li.active').removeClass 'active'
		$('.menu li[viz-num="' + n + '"]').addClass 'active'
		return

	h.infiniteChange = (toggle) ->
		console.log 'h.infiniteChange fired: ' + toggle
		clearInterval State.changeInterval
		State.changeInterval = setInterval((->
			h.themeChange Math.floor(Math.random() * 6)
			h.vizChange Math.floor(Math.random() * 8)
			return
		), toggle)
		if `toggle == null`
			clearInterval State.changeInterval
		return

	h.icosahedronFaces = (slide) ->
		slide = slide or 180
		faces = []
		y = Math.atan2(1, 2) * slide / Math.PI
		x = 0
		while x < 360
			faces.push [
				[
					x + 0
					-90
				]
				[
					x + 0
					-y
				]
				[
					x + 72
					-y
				]
			], [
				[
					x + 36
					y
				]
				[
					x + 72
					-y
				]
				[
					x + 0
					-y
				]
			], [
				[
					x + 36
					y
				]
				[
					x + 0
					-y
				]
				[
					x - 36
					y
				]
			], [
				[
					x + 36
					y
				]
				[
					x - 36
					y
				]
				[
					x - 36
					90
				]
			]
			x += 72
		faces

	h.degreesToRads = (n) ->
		d3.scale.linear().domain([
			0
			360
		]).range([
			0
			2 * Math.PI
		]) this

	h.microphoneError = (e) ->
		# user clicked not to let microphone be used
		console.log e
		return

	h.getURLParameter = (sParam) ->
		#http://www.jquerybyexample.net/2012/06/get-url-parameters-using-jquery.html
		sPageURL = window.location.search.substring(1)
		sURLVariables = sPageURL.split('&')
		i = 0
		while i < sURLVariables.length
			sParameterName = sURLVariables[i].split('=')
			if `sParameterName[0] == sParam`
				return sParameterName[1]
			i++
		return

	h.isMobile = ->
		# returns true if user agent is a mobile device
		/iPhone|iPod|iPad|Android|BlackBerry/.test navigator.userAgent

	h.detectEnvironment = ->
		if window.location.protocol.search('chrome-extension') >= 0
			return 'chrome-extension'
		if navigator.userAgent.search('Safari') >= 0 and navigator.userAgent.search('Chrome') < 0
			return 'safari'
		#  https://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
		if ! !window.opera or navigator.userAgent.indexOf(' OPR/') >= 0
			return 'opera'
		if `typeof InstallTrigger != 'undefined'`
			return 'firefox'
		# var isChrome = !!window.chrome && !isOpera;              // Chrome 1+
		# var isIE = /*@cc_on!@*/false || !!document.documentMode; // At least IE6
		'unknown'

	self.Helper = h
	return
).call this

$(document).ready App.init
