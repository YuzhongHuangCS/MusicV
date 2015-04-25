(function() {
  var indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  (function() {
    var WAVE_DATA, a, c, h, metaHide, micStream, objectUrl, old_waveform, r, self, waveform_array;
    self = this;
    waveform_array = void 0;
    old_waveform = void 0;
    objectUrl = void 0;
    metaHide = void 0;
    micStream = void 0;
    WAVE_DATA = [];
    a = {};
    a.init = function() {
      var camMotion, canvas, ctx;
      console.log('a.init fired');
      self.State = {
        playlist: ['dawn.mp3', 'forgot.mp3'],
        width: $(document).width(),
        height: $(document).height(),
        sliderVal: 50,
        canKick: true,
        metaLock: false,
        vendors: ['-webkit-', '-moz-', '-o-', ''],
        drawInterval: 1000 / 24,
        then: Date.now(),
        trigger: 'circle',
        hud: 1,
        active: null,
        vizNum: 0,
        thumbs_init: [0, 0, 0, 0, 0, 0, 0, 0],
        theme: 0,
        currentSong: 0
      };
      self.context = new (window.AudioContext || window.webkitAudioContext)();
      self.svg = d3.select('body').append('svg').attr('id', 'viz').attr('width', State.width).attr('height', State.height);
      a.bind();
      a.keyboard();
      a.loadSound();
      canvas = document.getElementById('canvas-blended');
      ctx = canvas.getContext('2d');
      ctx.fillStyle = '#FF0000';
      ctx.strokeStyle = '#00FF00';
      ctx.lineWidth = 5;
      console.log('Inintializing');
      camMotion = CamMotion.Engine();
      console.log(camMotion);
      camMotion.on('error', function(e) {
        return console.log('error', e);
      });
      console.log(camMotion);
      camMotion.on('streamInit', function(e) {
        return console.log('webcam stream initialized', e);
      });
      camMotion.on('frame', function() {
        var point, str;
        ctx.clearRect(0, 0, 640, 480);
        point = camMotion.getMovementPoint(true);
        console.log(point);
        ctx.beginPath();
        ctx.arc(point.x, point.y, point.r, 0, Math.PI * 2, true);
        ctx.closePath();
        if (camMotion.getAverageMovement(point.x - point.r / 2, point.y - point.r / 2, point.r, point.r) > 4) {
          ctx.fill();
          str = 'rotateX(' + point.x / 10 + 'deg)' + 'rotateY(' + point.y / 10 + 'deg)';
          return $('svg').css('transform', str);
        } else {
          return ctx.stroke();
        }
      });
      return camMotion.start();
    };
    a.bind = function() {
      var click, hide;
      console.log('a.bind fired');
      click = Helper.isMobile() ? 'touchstart' : 'click';
      $('.menu, .icon-menu').on('mouseenter touchstart', function() {
        return h.toggleMenu('open');
      });
      $('.menu').on('mouseleave', function() {
        return h.toggleMenu('close');
      });
      $('.menu').on(click, 'li', function() {
        return h.vizChange(+$(this).attr('viz-num'));
      });
      $('.menu').on(click, '.clicker', function() {
        return h.vizChange(+$(this).closest('li').attr('viz-num'));
      });
      $('.song-metadata').on(click, h.songGo);
      $('.wrapper').on(click, function() {
        return h.toggleMenu('close');
      });
      $('.icon-pause').on(click, h.togglePlay);
      $('.icon-play').on(click, h.togglePlay);
      $('.icon-forward2').on(click, function() {
        return h.changeSong('n');
      });
      $('.icon-backward2').on(click, function() {
        return h.changeSong('p');
      });
      $('.icon-expand').on(click, h.toggleFullScreen);
      $('.icon-microphone').on(click, a.microphone);
      $('.sc_import').on(click, a.soundCloud);
      $('.icon-question').on(click, function() {
        return h.showModal('#modal-about');
      });
      $('.icon-keyboard2').on(click, function() {
        return h.showModal('#modal-keyboard');
      });
      $('.icon-volume-medium').on(click, function() {
        return audio.muted = audio.muted == true ? false : true;
      });
      $('.icon-loop-on').on(click, function() {
        $(this).find('b').text(State.loopText[State.loop % 4]);
        return h.infiniteChange(State.loopDelay[State.loop++ % 4]);
      });
      $('.md-close').on(click, h.hideModals);
      $('.dotstyle').on(click, 'li', function() {
        return h.themeChange($(this).find('a').text());
      });
      $('#slider').on('input change', function() {
        return analyser.smoothingTimeConstant = 1 - this.value / 100;
      });
      $('#slider').on('change', function() {
        return $('#slider').blur();
      });
      $('.i').on('mouseenter', h.tooltipReplace);
      $('.i').on('mouseleave', h.tooltipUnReplace);
      $(document).on('dragenter', h.stop);
      $(document).on('dragover', h.stop);
      $(document).on('drop', h.handleDrop);
      document.addEventListener('waveform', function(e) {
        return waveform_array = e.detail;
      }, false);
      hide = setTimeout(function() {
        return h.hideHUD();
      }, 2000);
      $('body').on('touchstart mousemove', function() {
        h.showHUD();
        clearTimeout(hide);
        return hide = setTimeout(function() {
          return h.hideHUD();
        }, 2000);
      });
      window.onresize = function(event) {
        return h.resize();
      };
      return $(document).on('webkitfullscreenchange mozfullscreenchange fullscreenchange', h.resize);
    };
    a.keyboard = function() {
      console.log('a.keyboard fired');
      Mousetrap.bind('esc', h.hideModals);
      Mousetrap.bind('space', h.togglePlay);
      Mousetrap.bind('f', h.toggleFullScreen);
      Mousetrap.bind('m', function() {
        return h.toggleMenu('toggle');
      });
      Mousetrap.bind('c', function() {
        return h.changeSong();
      });
      Mousetrap.bind('l', function() {
        return $('.icon-loop-on').trigger('click');
      });
      Mousetrap.bind('k', function() {
        return $('.icon-keyboard2').trigger('click');
      });
      Mousetrap.bind('v', function() {
        return h.changeSong('n');
      });
      Mousetrap.bind('x', function() {
        return h.changeSong('p');
      });
      Mousetrap.bind('1', function() {
        return State.trigger = 'circle';
      });
      Mousetrap.bind('3', function() {
        return State.trigger = 'icosahedron';
      });
      Mousetrap.bind('4', function() {
        return State.trigger = 'grid';
      });
      Mousetrap.bind('6', function() {
        return State.trigger = 'spin';
      });
      Mousetrap.bind('7', function() {
        return State.trigger = 'hexbin';
      });
      Mousetrap.bind('8', function() {
        return State.trigger = 'voronoi';
      });
      Mousetrap.bind('up', function() {
        return h.vizChange(State.vizNum - 1);
      });
      Mousetrap.bind('down', function() {
        return h.vizChange(State.vizNum + 1);
      });
      Mousetrap.bind('left', function() {
        return h.themeChange(State.theme - 1);
      });
      return Mousetrap.bind('right', function() {
        return h.themeChange(State.theme + 1);
      });
    };
    a.loadSound = function() {
      var path;
      console.log('a.loadSound fired');
      if (navigator.userAgent.search('Safari') >= 0 && navigator.userAgent.search('Chrome') < 0) {
        console.log(' -- sound loaded via ajax request');
        $('.menu-controls').hide();
        a.loadSoundAJAX();
      } else {
        console.log(' -- sound loaded via html5 audio');
        path = 'mp3/' + State.playlist[0];
        a.loadSoundHTML5(path);
        h.readID3(path);
      }
    };
    a.loadSoundAJAX = function() {
      var audio, request;
      console.log('a.loadSoundAJAX fired');
      audio = null;
      request = new XMLHttpRequest;
      request.open('GET', 'mp3/' + State.playlist[0], true);
      request.responseType = 'arraybuffer';
      request.onload = function(event) {
        var data;
        data = event.target.response;
        return a.audioBullshit(data);
      };
      return request.send();
    };
    a.loadSoundHTML5 = function(f) {
      console.log('a.loadSoundHTML5 fired');
      audio = new Audio();
      audio.src = f;
      audio.autoplay = true;
      audio.addEventListener('ended', (function() {
        h.songEnded();
      }), false);
      $('#audio_box').empty();
      document.getElementById('audio_box').appendChild(audio);
      a.audioBullshit();
    };
    a.microphone = function() {
      console.log('a.microphone fired');
      navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia;
      if (micStream == null) {
        if (navigator.getUserMedia) {
          navigator.getUserMedia({
            audio: true,
            video: false
          }, (function(stream) {
            var src;
            console.log(' --> audio being captured');
            micStream = stream;
            console.log(micStream);
            src = window.URL.createObjectURL(micStream);
            self.source = context.createMediaStreamSource(micStream);
            source.connect(analyser);
            analyser.connect(context.destination);
            audio.pause();
          }), h.microphoneError);
        } else {

        }
      } else {
        console.log(' --> turning off');
        micStream.stop();
        micStream = null;
        audio.play();
      }
    };
    a.audioBullshit = function(data) {
      console.log('a.audioBullshit fired');
      self.analyser = context.createAnalyser();
      if (navigator.userAgent.search('Safari') >= 0 && navigator.userAgent.search('Chrome') < 0) {
        self.source = context.createBufferSource();
        source.buffer = context.createBuffer(data, false);
        source.loop = true;
        source.noteOn(0);
      } else {
        self.source = context.createMediaElementSource(audio);
      }
      source.connect(analyser);
      analyser.connect(context.destination);
      a.frameLooper();
    };
    a.findAudio = function() {
      console.log('a.findAudio fired');
      $('video, audio').each(function() {
        audio = this;
        a.audioBullshit();
      });
    };
    a.frameLooper = function() {
      window.requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame || window.webkitRequestAnimationFrame || window.msRequestAnimationFrame;
      window.requestAnimationFrame(a.frameLooper);
      now = Date.now();
      delta = now - State.then;
      if (audio) {
        $('#progressBar').attr('style', 'width: ' + audio.currentTime / audio.duration * 100 + '%');
      }
      if (delta > State.drawInterval) {
        State.then = now - delta % State.drawInterval;
        if (h.detectEnvironment() != 'chrome-extension') {
          waveform_array = new Uint8Array(analyser.frequencyBinCount);
          analyser.getByteFrequencyData(waveform_array);
        }
        r.circle_thumb();
        r.icosahedron_thumb();
        r.grid_thumb();
        r.spin_thumb();
        r.hexbin_thumb();
        switch (State.trigger) {
          case 'circle':
          case 0:
            State.vizNum = 0;
            r.circle();
            break;
          case 'icosahedron':
          case 2:
            State.vizNum = 2;
            r.icosahedron();
            break;
          case 'grid':
          case 3:
            State.vizNum = 3;
            r.grid();
            break;
          case 'spin':
          case 5:
            State.vizNum = 5;
            r.spin();
            break;
          case 'hexbin':
          case 6:
            State.vizNum = 6;
            r.hexbin();
            break;
          case 'voronoi':
          case 7:
            State.vizNum = 7;
            r.voronoi();
            break;
          default:
            State.vizNum = 0;
            r.circle();
            break;
        }
      }
    };
    self.App = a;
    c = {};
    c.kickDetect = function(threshold) {
      var deltas, kick, s;
      kick = false;
      deltas = $(waveform_array).each(function(n, i) {
        if (!old_waveform) {
          return 0;
        } else {
          return old_waveform[i] - n;
        }
      });
      s = d3.sum(deltas) / 1024;
      if (s > threshold && State.canKick) {
        kick = true;
        State.canKick = false;
        setTimeout((function() {
          State.canKick = true;
        }), 5000);
      }
      self.old_waveform = waveform_array;
      return kick;
    };
    c.normalize = function(coef, offset, neg) {
      var offset;
      var coef;
      var i, l, numbers, numbers2, ratio;
      coef = coef || 1;
      offset = offset || 0;
      numbers = waveform_array;
      numbers2 = [];
      ratio = Math.max.apply(Math, numbers);
      l = numbers.length;
      i = 0;
      while (i < l) {
        if (numbers[i] == 0) {
          numbers2[i] = 0 + offset;
        } else {
          numbers2[i] = numbers[i] / ratio * coef + offset;
        }
        if (i % 2 == 0 && neg) {
          numbers2[i] = -Math.abs(numbers2[i]);
        }
        i++;
      }
      return numbers2;
    };
    c.normalize_binned = function(binsize, coef, offset, neg) {
      var i, l, numbers, numbers2, ratio, temp;
      numbers = [];
      temp = 0;
      i = 0;
      while (i < waveform_array.length) {
        temp += waveform_array[i];
        if (i % binsize == 0) {
          numbers.push(temp / binsize);
          temp = 0;
        }
        i++;
      }
      coef = coef || 1;
      offset = offset || 0;
      numbers2 = [];
      ratio = Math.max.apply(Math, numbers);
      l = numbers.length;
      while (i < l) {
        if (numbers[i] == 0) {
          numbers2[i] = 0 + offset;
        } else {
          numbers2[i] = numbers[i] / ratio * coef + offset;
        }
        if (i % 2 == 0 && neg) {
          numbers2[i] = -Math.abs(numbers2[i]);
        }
        i++;
      }
      return numbers2;
    };
    c.total = function() {
      return Math.floor(d3.sum(waveform_array) / waveform_array.length);
    };
    c.total_normalized = function() {};
    c.bins_select = function(binsize) {
      var copy, i;
      copy = [];
      i = 0;
      while (i < 500) {
        if (i % binsize == 0) {
          copy.push(waveform_array[i]);
        }
        i++;
      }
      return copy;
    };
    c.bins_avg = function(binsize) {
      var binsize;
      var copy, temp;
      binsize = binsize || 100;
      copy = [];
      temp = 0;
      while (i < waveform_array.length) {
        temp += waveform_array[i];
        if (i % binsize == 0) {
          copy.push(temp / binsize);
          temp = 0;
        }
        i++;
      }
      return copy;
    };
    self.Compute = c;
    r = {};
    r.circle = function() {
      var slideScale, x;
      if (State.active != 'circle') {
        State.active = 'circle';
        $('body > svg').empty();
      }
      WAVE_DATA = c.bins_select(70);
      x = d3.scale.linear().domain([0, d3.max(WAVE_DATA)]).range([0, 420]);
      slideScale = d3.scale.linear().domain([1, 100]).range([0, 2]);
      self.bars = svg.selectAll('circle').data(WAVE_DATA, function(d) {
        return d;
      });
      bars.enter().append('circle').attr('transform', 'scale(' + slideScale(State.sliderVal) + ')').attr('cy', function(d, i) {
        return '50%';
      }).attr('cx', function(d, i) {
        return '50%';
      }).attr('r', function(d) {
        return x(d) + '';
      });
      bars.exit().remove();
    };
    r.circle_thumb = function() {
      var bars_t1, x_t1;
      if (State.thumbs_init[0] != 'init') {
        State.thumbs_init[0] = 'init';
        self.svg_thumb_one = d3.select('#circle').append('svg').attr('width', '100%').attr('height', '100%');
      }
      WAVE_DATA = c.bins_select(200);
      x_t1 = d3.scale.linear().domain([0, d3.max(WAVE_DATA)]).range([0, 80]);
      bars_t1 = svg_thumb_one.selectAll('circle').data(WAVE_DATA, function(d) {
        return d;
      });
      bars_t1.enter().append('circle').attr('cy', function(d, i) {
        return '50%';
      }).attr('cx', function(d, i) {
        return '50%';
      }).attr('r', function(d) {
        return x_t1(d) + '';
      });
      bars_t1.exit().remove();
    };
    r.icosahedron = function() {
      var height, i, style, svg, svg2, svg3, t0, time, width, xx;
      if (State.active == 'icosahedron') {
        time = Date.now() - t0;
        xx = c.total() / 100;
        style = '';
        i = 0;
        while (i < State.vendors.length) {
          style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); ';
          i++;
        }
        $('body > svg path').attr('style', style);
        projection.rotate([time * velocity[0], time * velocity[1]]);
        face.each(function(d) {
          d.forEach(function(p, i) {
            d.polygon[i] = projection(p);
          });
        }).style('display', function(d) {
          if (d.polygon.area() > 0) {
            return null;
          } else {
            return 'none';
          }
        }).attr('d', function(d) {
          return 'M' + d.polygon.join('L') + 'Z';
        });
        projection2.rotate([time * velocity2[0], time * velocity2[1]]);
        face2.each(function(d) {
          d.forEach(function(p, i) {
            d.polygon[i] = projection2(p);
          });
        }).style('display', function(d) {
          if (d.polygon.area() > 0) {
            return null;
          } else {
            return 'none';
          }
        }).attr('d', function(d) {
          return 'M' + d.polygon.join('L') + 'Z';
        });
        projection3.rotate([time * velocity3[0], time * velocity3[1]]);
        face3.each(function(d) {
          d.forEach(function(p, i) {
            d.polygon[i] = projection3(p);
          });
        }).style('display', function(d) {
          if (d.polygon.area() > 0) {
            return null;
          } else {
            return 'none';
          }
        }).attr('d', function(d) {
          return 'M' + d.polygon.join('L') + 'Z';
        });
        return;
      }
      State.active = 'icosahedron';
      $('body > svg').empty();
      width = State.width;
      height = State.height;
      self.velocity = [0.10, 0.005];
      self.velocity2 = [-0.10, -0.05];
      self.velocity3 = [0.10, 0.1];
      t0 = Date.now();
      self.projection = d3.geo.orthographic().scale(height / 2).translate([width / 2, height / 2]).center([0, 0]);
      svg = d3.select('body').append('svg').attr('class', 'isoco1').attr('width', width).attr('height', height);
      self.face = svg.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each(function(d) {
        d.polygon = d3.geom.polygon(d.map(projection));
      });
      self.projection2 = d3.geo.orthographic().scale(height / 4).translate([width / 2, height / 2]).center([0, 0]);
      svg2 = d3.select('body').append('svg').attr('class', 'isoco2').attr('width', width).attr('height', height);
      self.face2 = svg2.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each(function(d) {
        d.polygon = d3.geom.polygon(d.map(projection2));
      });
      self.projection3 = d3.geo.orthographic().scale(height / 1).translate([width / 2, height / 2]).center([0, 0]);
      svg3 = d3.select('body').append('svg').attr('class', 'isoco3').attr('width', width).attr('height', height);
      self.face3 = svg3.selectAll('path').data(h.icosahedronFaces).enter().append('path').attr('class', 'isoco').each(function(d) {
        d.polygon = d3.geom.polygon(d.map(projection3));
      });
    };
    r.icosahedron_thumb = function() {
      var height, i, style, time_t0, width, xx_t0;
      if (State.thumbs_init[2] == 'init') {
        xx_t0 = c.total() / 100;
        time_t0 = Date.now() - t0_thumb;
        style = '';
        i = 0;
        while (i < State.vendors.length) {
          style += State.vendors[i] + 'transform: scale(' + xx_t0 + ',' + xx_t0 + '); ';
          i++;
        }
        $('#icosahedron svg path').attr('style', style);
        projection_thumb.rotate([time_t0 * velocity_thumb[0], time_t0 * velocity_thumb[1]]);
        'self.face_thumb.each((d) ->\n	d.forEach (p, i) ->\n		d.polygon[i] = projection_thumb(p)\n		return\n	return\n).style(\'display\', (d) ->\n	if d.polygon.area() > 0 then null else \'none\'\n).attr \'d\', (d) ->\n	\'M\' + d.polygon.join(\'L\') + \'Z\'';
      }
      State.thumbs_init[2] = 'init';
      width = $('#icosahedron').width();
      height = $('#icosahedron').height();
      self.velocity_thumb = [.01, .05];
      self.t0_thumb = Date.now();
      self.projection_thumb = d3.geo.orthographic().scale(height * 1.5).translate([width / 2, height / 2]).center([0, 0]);
      self.svg_thumb_three = d3.select('#icosahedron').append('svg').attr('width', width).attr('height', height);
      return self.face_thumb = svg_thumb_three.selectAll('path').data(h.icosahedronFaces).enter().append('path').each(function(d) {
        d.polygon = d3.geom.polygon(d.map(projection_thumb));
      });
    };
    r.grid2 = function(data) {
      var dt;
      if (State.active == 'grid') {
        dt = Date.now() - time;
        projection.rotate([rotate[0] + velocity[0] * dt, rotate[1] + velocity[1] * dt]);
        feature.attr('d', path);
        return;
      }
      $('body > svg').empty();
      State.active = 'grid';
      self.rotate = [10, -10];
      self.velocity = [.03, -.01];
      self.time = Date.now();
      self.projection = d3.geo.orthographic().scale(240).translate([State.width / 2, State.height / 2]).clipAngle(90 + 1e-6).precision(.3);
      self.path = d3.geo.path().projection(projection);
      graticule = d3.geo.graticule().minorExtent([
	[
		-180,
		-89
	],
	[
		180,
		89 + 0.0001
	]
]);
      svg.append('path').datum({
        type: 'Sphere'
      }).attr('class', 'sphere').attr('d', path);
      svg.append('path').datum(graticule).attr('class', 'graticule').attr('d', path);
      self.feature = svg.selectAll('path');
    };
    r.grid = function(data) {
      var i, style, xx;
      if (State.active == 'grid') {
        xx = c.total() / 100 + 1;
        xx = xx < 1 ? 1 : xx;
        xx = xx > 1.1 ? 1.1 : xx;
        style = '';
        i = 0;
        while (i < State.vendors.length) {
          style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); ';
          i++;
        }
        $('body > svg path').attr('style', style);
        projection.rotate([λ(p), φ(p)]);
        svg.selectAll('path').attr('d', path);
        p = p + 5;
        step = Math.floor(c.total() / 100 * 60);
        step = step < 5 ? 5 : step;
        graticule = d3.geo.graticule().minorStep([
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
]);
        grat.datum(graticule).attr('class', 'graticule').attr('d', path);
        return;
      }
      p = 0;
      State.active = 'grid';
      $('body > svg').empty();
      projection = d3.geo.gnomonic().clipAngle(80).scale(500);
      path = d3.geo.path().projection(projection);
      graticule = d3.geo.graticule().minorStep([
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
]);
      λ = d3.scale.linear().domain([
	0,
	State.width
]).range([
	-180,
	180
]);
      φ = d3.scale.linear().domain([
	0,
	State.height
]).range([
	90,
	-90
]);
      grat = svg.append('path').datum(graticule).attr('class', 'graticule').attr('d', path);
    };
    r.grid_thumb = function(data) {
      var height, i, style, width, xx;
      width = $('#grid').width();
      height = $('#grid').height();
      if (State.thumbs_init[3] == 'init') {
        xx = c.total() / 100 + 1;
        xx = xx == 1 ? 0 : xx;
        style = '';
        i = 0;
        while (i < State.vendors.length) {
          style += State.vendors[i] + 'transform: scale(' + xx + ',' + xx + '); ';
          i++;
        }
        $('#grid svg path').attr('style', style);
        return;
      }
      State.thumbs_init[3] = 'init';
      $('#grid svg').empty();
      projection = d3.geo.gnomonic().clipAngle(80);
      path = d3.geo.path().projection(projection);
      graticule = d3.geo.graticule().minorStep([
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
]);
      svg_thumb_four = d3.select('#grid').append('svg').attr('width', width).attr('height', height);
      grat = svg_thumb_four.append('path').datum(graticule).attr('class', 'graticule').attr('d', path);
    };
    r.spin = function() {
      var $c, elems;
      if (State.active == 'spin') {
        WAVE_DATA = c.total() * 2;
        $c = $('body > svg circle');
        $c.attr('style', 'stroke-width: ' + WAVE_DATA * 4 + 'px');
        $c.attr('stroke-dashoffset', WAVE_DATA + 'px');
        $c.attr('stroke-dasharray', WAVE_DATA / 6 + 'px');
        $c.attr('opacity', WAVE_DATA / 2200);
        return;
      }
      State.active = 'spin';
      $('body > svg').empty();
      elems = [
        {
          id: 'c1',
          radius: 300
        }, {
          id: 'c4',
          radius: 10
        }, {
          id: 'c2',
          radius: 100
        }, {
          id: 'c3',
          radius: 50
        }
      ];
      bars = svg.selectAll('circle').data(elems, function (d, i) {
	return i;
});
      bars.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', function(d) {
        return d.id;
      }).attr('r', function(d) {
        return d.radius + '';
      });
      bars.exit().remove();
    };
    r.spin_thumb = function() {
      var $c, elems;
      if (State.thumbs_init[5] == 'init') {
        WAVE_DATA = c.total() * 2;
        $c = $('#spin svg circle');
        $c.attr('style', 'stroke-width: ' + WAVE_DATA * 4 + 'px');
        $c.attr('stroke-dashoffset', WAVE_DATA + 'px');
        $c.attr('stroke-dasharray', WAVE_DATA / 6 + 'px');
        $c.attr('opacity', WAVE_DATA / 2200);
        return;
      }
      $('#spin svg').empty();
      State.thumbs_init[5] = 'init';
      self.svg_thumb_six = d3.select('#spin').append('svg').attr('width', '100%').attr('height', '100%');
      elems = [
        {
          id: 'c4',
          radius: 10
        }, {
          id: 'c3',
          radius: 50
        }
      ];
      bars_t6 = svg_thumb_six.selectAll('circle').data(elems, function (d, i) {
	return i;
});
      bars_t6.enter().append('circle').attr('class', 'spin').attr('cy', '50%').attr('cx', '50%').attr('id', function(d) {
        return d.id;
      }).attr('r', function(d) {
        return d.radius + '';
      });
      bars_t6.exit().remove();
    };
    r.hexbin = function() {
      $('body > svg').empty();
      if (State.active != 'hexbin') {
        randomX = d3.random.normal(State.width / 2, 700);
        ps = d3.range(1024).map(function () {
	return randomX();
});
      }
      State.active = 'hexbin';
      points = d3.zip(ps, c.normalize(State.height, 0));
      color = d3.scale.linear().domain([
	0,
	20
]).range([
	$('.dotstyle li.current a').css('background-color'),
	$('.dotstyle li.current a').css('background-color')
]).interpolate(d3.interpolateLab);
      hexbin = d3.hexbin().size([
	State.width,
	State.height
]).radius(50);
      radius = d3.scale.linear().domain([
	0,
	20
]).range([
	0,
	130
]);
      svg.append('g').selectAll('.hexagon').data(hexbin(points)).enter().append('path').attr('class', 'hexagon').attr('id', 'hexx').attr('d', function(d) {
        return hexbin.hexagon(radius(d.length));
      }).attr('transform', function(d) {
        return 'translate(' + d.x + ',' + d.y + ')';
      }).style('fill', function(d) {
        return color(d.length);
      }).style('opacity', function(d) {
        return 0.8 - radius(d.length) / 180;
      });
    };
    r.hexbin_thumb = function() {
      var height, width;
      width = $('#hexbin').width();
      height = $('#hexbin').height();
      if (State.thumbs_init[6] != 'init') {
        self.svg_thumb_seven = d3.select('#hexbin').append('svg').attr('width', '100%').attr('height', '100%');
        State.thumbs_init[6] = 'init';
        randomX_t7 = d3.random.normal(width / 2, 50);
        ps_t7 = d3.range(1024).map(function () {
	return randomX_t7();
});
      }
      $('#hexbin svg').empty();
      points_t7 = d3.zip(ps_t7, c.normalize(height * 1.5, -20));
      color_t7 = d3.scale.linear().domain([
	0,
	50
]).range([
	'black',
	'white'
]).interpolate(d3.interpolateLab);
      hexbin_t7 = d3.hexbin().size([
	width,
	height
]).radius(15);
      radius_t7 = d3.scale.linear().domain([
	0,
	10
]).range([
	0,
	15
]);
      svg_thumb_seven.append('g').selectAll('.hexagon').data(hexbin_t7(points_t7)).enter().append('path').attr('class', 'hexagon').attr('d', function(d) {
        return hexbin_t7.hexagon(15);
      }).attr('transform', function(d) {
        return 'translate(' + d.x + ',' + d.y + ')';
      }).style('fill', function(d) {
        return color_t7(d.length);
      });
    };
    r.voronoi = function() {
      var polygon, redraw;
      redraw = function() {
        vertices = d3.range(100).map(function (d) {
	return [
		Math.random() * width,
		Math.random() * height
	];
});
        path = path.data(voronoi(vertices), polygon);
        path.exit().remove();
        path.enter().append('path').attr('class', function(d, i) {
          return 'q' + i % 9 + '-9';
        }).attr('d', polygon);
        path.order();
      };
      polygon = function(d) {
        return 'M' + d.join('L') + 'Z';
      };
      if (State.active == 'voronoi') {
        redraw();
        return;
      }
      State.active = 'voronoi';
      width = State.width;
      height = State.height;
      vertices = d3.range(100).map(function (d) {
	return [
		Math.random() * width,
		Math.random() * height
	];
});
      voronoi = d3.geom.voronoi().clipExtent([
	[
		0,
		0
	],
	[
		width,
		height
	]
]);
      svg = d3.select('body').append('svg').attr('width', width).attr('height', height);
      path = svg.append('g').selectAll('path');
      svg.selectAll('circle').data(vertices.slice(1)).enter().append('circle').attr('transform', function(d) {
        return 'translate(' + d + ')';
      }).attr('r', 1.5);
      redraw();
    };
    self.Render = r;
    h = {};
    h.toggleMenu = function(x) {
      console.log('h.toggleMenu');
      if (x == 'toggle') {
        x = $('.menu').hasClass('menu-open') ? 'close' : 'open';
      }
      if (x == 'open') {
        $('.menu').addClass('menu-open');
        $('.icon-menu').addClass('fadeOut');
      } else {
        $('.menu').removeClass('menu-open');
      }
    };
    h.toggleFullScreen = function() {
      console.log('h.toggleFullScreen fired');
      if (!document.fullscreenElement && !document.mozFullScreenElement && !document.webkitFullscreenElement && !document.msFullscreenElement) {
        $('.icon-expand').addClass('icon-contract');
        if (document.documentElement.requestFullscreen) {
          document.documentElement.requestFullscreen();
        } else if (document.documentElement.msRequestFullscreen) {
          document.documentElement.msRequestFullscreen();
        } else if (document.documentElement.mozRequestFullScreen) {
          document.documentElement.mozRequestFullScreen();
        } else if (document.documentElement.webkitRequestFullscreen) {
          document.documentElement.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
        }
      } else {
        $('.icon-expand').removeClass('icon-contract');
        if (document.exitFullscreen) {
          document.exitFullscreen();
        } else if (document.msExitFullscreen) {
          document.msExitFullscreen();
        } else if (document.mozCancelFullScreen) {
          document.mozCancelFullScreen();
        } else if (document.webkitExitFullscreen) {
          document.webkitExitFullscreen();
        }
      }
    };
    h.hideHUD = function() {
      if ($('#mp3_player').is(':hover') || $('.dotstyle').is(':hover') || $('.slider').is(':hover') || $('.icon-expand').is(':hover') || $('.icon-github2').is(':hover') || $('.icon-loop-on').is(':hover') || $('.icon-question').is(':hover') || $('.icon-keyboard2').is(':hover') || $('.song-metadata').is(':hover') || $('.icon-forward2').is(':hover') || $('.icon-backward2').is(':hover') || $('.icon-pause').is(':hover') || $('.schover').is(':hover')) {
        return;
      }
      $('#mp3_player').addClass('fadeOut');
      $('.icon-menu').addClass('fadeOut');
      $('.menu-wide').addClass('fadeOut');
      $('.menu').addClass('fadeOut');
      $('.menu-controls').addClass('fadeOut');
      $('#progressBar').addClass('fadeOut');
      $('html').addClass('noCursor');
      if (State.metaLock == false) {
        $('.song-metadata').removeClass('show-meta');
      }
      State.hud = 0;
    };
    h.showHUD = function() {
      $('#mp3_player').removeClass('fadeOut');
      $('.icon-menu').removeClass('fadeOut');
      $('.menu-wide').removeClass('fadeOut');
      $('.menu').removeClass('fadeOut');
      $('.menu-controls').removeClass('fadeOut');
      $('#progressBar').removeClass('fadeOut');
      $('html').removeClass('noCursor');
      $('.song-metadata').addClass('show-meta');
      State.hud = 1;
    };
    h.showModal = function(id) {
      if ($(id).hasClass('md-show')) {
        h.hideModals();
        return;
      }
      if ($('.md-show').length > 0) {
        h.hideModals();
      }
      $(id).addClass('md-show');
    };
    h.hideModals = function() {
      $('.md-modal').removeClass('md-show');
    };
    h.resize = function() {
      var full;
      console.log('h.resize fired');
      State.width = $(window).width();
      State.height = $(window).height();
      State.active = State.trigger;
      $('body > svg').attr('width', State.width).attr('height', State.height);
      full = document.fullscreen || document.webkitIsFullScreen || document.mozFullScreen;
      if (!full) {
        $('.icon-expand').removeClass('icon-contract');
      }
    };
    h.stop = function(e) {
      e.stopPropagation();
      e.preventDefault();
    };
    h.handleDrop = function(e) {
      var objectUrl;
      var file;
      console.log('h.handleDrop fired');
      h.stop(e);
      h.removeSoundCloud();
      URL.revokeObjectURL(objectUrl);
      file = e.originalEvent.dataTransfer.files[0];
      if (!file.type.match(/audio.*/)) {
        console.log('not audio file');
        return;
      }
      h.readID3(file);
      objectUrl = URL.createObjectURL(file);
      a.loadSoundHTML5(objectUrl);
    };
    h.readID3 = function(file) {
      console.log('h.readID3 fired');
      $('.song-metadata').html('');
      if (typeof file == 'string') {
        ID3.loadTags(audio.src, function() {
          var tags;
          tags = ID3.getAllTags(audio.src);
          h.renderSongTitle(tags);
        });
      } else {
        ID3.loadTags(file.urn || file.name, (function() {
          var base64String, i, image, tags;
          tags = ID3.getAllTags(file.urn || file.name);
          tags.dragged = true;
          h.renderSongTitle(tags);
          if (indexOf.call(tags, 'picture') >= 0) {
            image = tags.picture;
            base64String = '';
            i = 0;
            while (i < image.data.length) {
              base64String += String.fromCharCode(image.data[i]);
              i++;
            }
          } else {

          }
        }), {
          dataReader: FileAPIReader(file)
        });
      }
    };
    h.removeSoundCloud = function() {
      State.soundCloudURL = null;
      State.soundCloudData = null;
      State.soundCloudTracks = null;
      $('.song-metadata').html('');
      $('.song-metadata').attr('data-go', '');
      $('#sc_input').val('');
      $('#sc_url span').html('SOUNDCLOUD_URL');
    };
    h.togglePlay = function() {
      if (audio && audio.paused == false) {
        audio.pause();
      } else {
        audio.play();
      }
      $('.icon-pause').toggleClass('icon-play');
    };
    h.songEnded = function() {
      console.log('h.songEnded fired');
      h.changeSong('n');
    };
    h.changeSong = function(direction) {
      var totalTracks, trackNum;
      console.log('h.changeSong fired');
      totalTracks = State.soundCloudTracks || State.playlist.length;
      if (State.soundCloudData && State.soundCloudTracks <= 1) {
        audio.currentTime = 0;
        $('.icon-pause').removeClass('icon-play');
        return;
      }
      if (direction == 'n') {
        State.currentSong = State.currentSong + 1;
      } else if (direction == 'p') {
        if (audio.currentTime < 3) {
          State.currentSong = State.currentSong <= 0 ? State.currentSong + totalTracks - 1 : State.currentSong - 1;
        } else {
          audio.currentTime = 0;
          $('.icon-pause').removeClass('icon-play');
          return;
        }
      } else {
        State.currentSong = Math.floor(Math.random() * totalTracks);
      }
      if (State.soundCloudData) {
        trackNum = Math.abs(State.currentSong) % State.soundCloudTracks;
        h.renderSongTitle(State.soundCloudData[trackNum]);
        a.loadSoundHTML5(State.soundCloudData[trackNum].uri + '/stream?client_id=67129366c767d009ecc75cec10fa3d0f');
      } else {
        if (audio) {
          audio.src = 'mp3/' + State.playlist[Math.abs(State.currentSong) % State.playlist.length];
          h.readID3(audio.src);
        }
      }
      $('.icon-pause').removeClass('icon-play');
    };
    h.renderSongTitle = function(obj) {
      var trackNum;
      var prettyTitle;
      var prettyTitle, regs, trackNum;
      console.log('h.renderSongTitle fired');
      if (State.soundCloudData) {
        trackNum = Math.abs(State.currentSong) % State.soundCloudTracks;
        regs = new RegExp(obj.user.username, 'gi');
        prettyTitle = obj.title;
        if (prettyTitle.search(regs) == -1) {
          prettyTitle += ' <b>' + obj.user.username + '</b>';
        }
        if (State.soundCloudTracks > 1) {
          prettyTitle += ' [' + trackNum + 1 + '/' + State.soundCloudTracks + ']';
        }
        $('.song-metadata').html(prettyTitle);
        $('.song-metadata').attr('data-go', obj.permalink_url);
      } else {
        prettyTitle = '"' + obj.title + '" by <b>' + obj.artist + '</b>';
        trackNum = Math.abs(State.currentSong) % State.playlist.length;
        if (State.playlist.length > 1 && !obj.dragged) {
          prettyTitle += ' [' + trackNum + 1 + '/' + State.playlist.length + ']';
        }
        $('.song-metadata').html(prettyTitle);
      }
      $('.song-metadata').addClass('show-meta');
      State.metaLock = true;
      clearTimeout(metaHide);
      metaHide = setTimeout((function() {
        State.metaLock = false;
        if (State.hud == 0) {
          $('.song-metadata').removeClass('show-meta');
        }
      }), 3000);
    };
    h.tooltipReplace = function() {
      var text;
      console.log('h.tooltipReplace fired');
      text = $(this).attr('data-hovertext');
      console.log(text);
      if (text != null) {
        State.hoverTemp = $('.song-metadata').html();
        $('.song-metadata').html(text);
      }
    };
    h.tooltipUnReplace = function() {
      console.log('h.tooltipUnReplace fired');
      if (State.hoverTemp != null) {
        $('.song-metadata').html(State.hoverTemp);
        State.hoverTemp = null;
      }
    };
    h.songGo = function() {
      console.log('h.songGo fired.');
      if (!$(this).attr('data-go')) {
        return false;
      }
      audio.pause();
      $('.icon-pause').removeClass('icon-play');
      window.open($(this).attr('data-go'), '_blank');
    };
    h.themeChange = function(n) {
      var name;
      n = +n;
      n = n < 0 ? 5 : n;
      n = n > 5 ? 0 : n;
      State.theme = n;
      console.log('h.themeChange:' + n);
      name = 'theme_' + n;
      $('html').attr('class', name);
      $('.dotstyle li.current').removeClass('current');
      $('.dotstyle li:eq(' + n + ')').addClass('current');
    };
    h.vizChange = function(n) {
      n = n < 0 ? 6 : n;
      n = n > 6 ? 0 : n;
      console.log('h.vizChange:' + n);
      State.trigger = n;
      $('.menu li.active').removeClass('active');
      $('.menu li[viz-num="' + n + '"]').addClass('active');
    };
    h.infiniteChange = function(toggle) {
      console.log('h.infiniteChange fired: ' + toggle);
      clearInterval(State.changeInterval);
      State.changeInterval = setInterval((function() {
        h.themeChange(Math.floor(Math.random() * 6));
        h.vizChange(Math.floor(Math.random() * 8));
      }), toggle);
      if (toggle == null) {
        clearInterval(State.changeInterval);
      }
    };
    h.icosahedronFaces = function(slide) {
      var faces, x, y;
      slide = slide || 180;
      faces = [];
      y = Math.atan2(1, 2) * slide / Math.PI;
      x = 0;
      while (x < 360) {
        faces.push([[x + 0, -90], [x + 0, -y], [x + 72, -y]], [[x + 36, y], [x + 72, -y], [x + 0, -y]], [[x + 36, y], [x + 0, -y], [x - 36, y]], [[x + 36, y], [x - 36, y], [x - 36, 90]]);
        x += 72;
      }
      return faces;
    };
    h.degreesToRads = function(n) {
      return d3.scale.linear().domain([0, 360]).range([0, 2 * Math.PI])(this);
    };
    h.microphoneError = function(e) {
      console.log(e);
    };
    h.getURLParameter = function(sParam) {
      var i, sPageURL, sParameterName, sURLVariables;
      sPageURL = window.location.search.substring(1);
      sURLVariables = sPageURL.split('&');
      i = 0;
      while (i < sURLVariables.length) {
        sParameterName = sURLVariables[i].split('=');
        if (sParameterName[0] == sParam) {
          return sParameterName[1];
        }
        i++;
      }
    };
    h.isMobile = function() {
      return /iPhone|iPod|iPad|Android|BlackBerry/.test(navigator.userAgent);
    };
    h.detectEnvironment = function() {
      if (window.location.protocol.search('chrome-extension') >= 0) {
        return 'chrome-extension';
      }
      if (navigator.userAgent.search('Safari') >= 0 && navigator.userAgent.search('Chrome') < 0) {
        return 'safari';
      }
      if (!!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0) {
        return 'opera';
      }
      if (typeof InstallTrigger != 'undefined') {
        return 'firefox';
      }
      return 'unknown';
    };
    self.Helper = h;
  }).call(this);

  $(document).ready(App.init);

}).call(this);
