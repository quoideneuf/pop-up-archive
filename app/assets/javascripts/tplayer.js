/* Pop Up Archive embedded transcript/player 
   Copyright 2014 Pop Up Archive
   Licensed under the AGPL -- see https://github.com/popuparchive/pop-up-archive/blob/master/LICENSE.txt
*/

"use strict"

var PUATPlayer = function(opts) {
  // parse opts
  if (!opts.fileId) {
    throw new Error("fileId required");
  }
  if (!opts.jplayer) {
    throw new Error("jplayer required");
  }
  this.fileId  = opts.fileId;
  this.jplayer = opts.jplayer;

  // create waveform
  this.generateWaveform();
  this.el      = $('#jp_container-' + this.fileId);
  this.element = this.el.find('.scrubber canvas')[0];
  this.jp_pbar = this.el.find('.jp-progress');

  if (!opts.duration) {
    this.time    = parseInt(this.el.find('.jp-time-holder .jp-current-time').html());
    this.ms      = this.el.find('.jp-time-holder .jp-duration').html().split(':');
    this.duration = parseInt(this.ms[0]*60) + parseInt(this.ms[1]);
  }

  this.context = this.element.getContext('2d');
  this.mapped  = this.mapToArray(this.wavformData, this.el.width());
  this.el.find('.jp-progress .calculating').addClass('hidden');
  this.draw();
  this.jp_seek_bar = this.el.find('.jp-progress .jp-seek-bar');
  var img = this.element.toDataURL();
  this.jp_seek_bar.css("background", 'url('+img+') no-repeat');
  // redraw the canvas in different color for the progressive play bar
  this.draw('rgb(255, 190, 48)');
  img = this.element.toDataURL();
  this.jp_play_bar = this.el.find('.jp-progress .jp-play-bar');
  this.jp_play_bar.css("background", 'url('+img+') no-repeat');

  // setup
  this.setListeners();
  this.bindEvents();

  if (opts.play) {
    if (opts.play.start) {
      // playHead takes a percentage and 'start' is an int offset
      this.newHead = Math.floor((opts.play.start / this.duration) * 100);
      //console.log('length', this.ms, 'start', opts.play.start, 'duration', this.duration, 'newHead', this.newHead);
      $(this.jplayer).jPlayer('playHead', this.newHead);
    }
    if (opts.play.end) {
      this.hardStop = opts.play.end;
    }
  }
};

PUATPlayer.prototype = {
  setListeners: function() {
    var self = this;
    $("#jp-reverse-button-"+self.fileId).on('click', function() {
      $(self.jplayer).jPlayer('playHead', 0);
    });
    $('#pua-tplayer-'+self.fileId+'-transcript .pua-tplayer-text').click(function() {
      var clicked = this;
      var offset  = parseInt( $(clicked).data('offset') );
      //console.log('clicked on text with id', clicked.id, offset);
      $(self.jplayer).jPlayer('play', offset);
    });
    $('#pua-tplayer-'+self.fileId+'-transcript .pua-tplayer-text').hover(
      function() { $(this).addClass('hover'); },
      function() { $(this).removeClass('hover'); }
    );
  },

  bindEvents: function() {
    var self = this;
    $(self.jplayer).bind($.jPlayer.event.timeupdate, function(ev) { 
      self.scrollOnPlay(ev);
    });
    $(self.jplayer).bind($.jPlayer.event.seeking, function(ev) {
      //console.log('seeking');
      $('#pua-tplayer-'+self.fileId+'-transcript thead').addClass('loading-overlay');
      $('#pua-tplayer-'+self.fileId+'-transcript .loading-indicator').toggleClass('hidden');
    });
    $(self.jplayer).bind($.jPlayer.event.seeked, function(ev) { 
      //console.log('seeked');
      $('#pua-tplayer-'+self.fileId+'-transcript thead').removeClass('loading-overlay');
      $('#pua-tplayer-'+self.fileId+'-transcript .loading-indicator').toggleClass('hidden');
      self.scrollOnSeek(ev);
    });
  },

  scrollOnPlay: function(ev) {
    var self = this;
    var curOffset = Math.floor( ev.jPlayer.status.currentTime );
    // if the current offset matches a text id, select the text
    var target = $('#pua-tplayer-text-'+self.fileId+'-'+curOffset);
    //console.log('play:', ev.jPlayer.status.currentTime, curOffset, target);
    if (target && target.length) {
      self.scrollToLine(target);
    }
    if (self.hardStop && curOffset >= self.hardStop) {
      $(self.jplayer).jPlayer('stop');
    }
  },

  scrollToLine: function(target) {
    var self = this;
    if (target && target.length && !target.hasClass('selected')) {
      //console.log('scrolling to line');
      // de-select any currently selected first
      var curSelected = $("#pua-tplayer-"+self.fileId+"-transcript .pua-tplayer-text.selected");
      curSelected.removeClass('selected');
      // select new target
      target.addClass('selected');
      // scroll
      var scrollMath = {};
      scrollMath.pxBefore = 20;
      scrollMath.lineNum  = parseInt( target.data('idx') );
      var tgtWrap = $("#pua-tplayer-"+self.fileId+"-transcript.scrolling tbody");
      scrollMath.simple = tgtWrap.scrollTop() - tgtWrap.offset().top + target.offset().top - scrollMath.pxBefore;
      //console.log('scrollMath: ', scrollMath);
      tgtWrap.animate({ scrollTop: scrollMath.simple }, 200);
    }
    //console.log('scrollToLine', target, target.length, target.hasClass('selected'));
  },

  scrollOnSeek: function(ev) {
    //console.log('seek finished');
    var self = this;
    var curOffset = Math.floor( ev.jPlayer.status.currentTime );
    // find nearest target
    var target = self.findNearestLine(curOffset);
    //console.log('seek:', curOffset, target);
    self.scrollToLine(target);
  },

  findNearestLine: function(offset) {
    // look for a target matching offset, working backward till we find one.
    var self = this;
    var target = $('#pua-tplayer-text-'+self.fileId+'-'+offset);
    //console.log('looking for line nearest to', offset);
    while (!target.length) {
      offset--;
      target = $('#pua-tplayer-text-'+self.fileId+'-'+offset);
      if (offset <= 0) { break; }
    }
    //console.log('nearest line:', offset, target);
    return target;
  },

  waveformData: [],

  waveform: function() {
    return this.waveformData;
  },

  generateWaveform: function() {
    this.waveformData.length = 0;
    var l = 0;
    var segments = parseInt(Math.random() * 1000 + 1000);

    for (var i=0; i < segments; i++) {
      l = this.waveformData[i] = Math.max(Math.round(Math.random() * 10) + 2, Math.min(Math.round(Math.random() * -20) + 50, Math.round(l + (Math.random() * 25 - 12.5))));
    }   
  },

  canvasWidth: function() {
    return this.jp_pbar.width();
  },

  canvasHeight: function() {
    return this.jp_pbar.height();
  },

  barTop: function(size, height) {
    return Math.round((50 - size) * (height / 50) * 0.5);
  },

  barHeight: function(size, height) {
    return Math.round(size * (height / 50));
  },

  mapToArray: function(waveform, size) {
    var currentPixel = 0;
    var currentChunk = 0;
    var waveform = this.waveformData;
    var chunksPerPixel = waveform.length / size;
    var chunkStart, chunkEnd, sum, j;
    var array = [];
    while (currentPixel < size) {
      chunkStart = Math.ceil(currentChunk);
      currentChunk += chunksPerPixel;
      chunkEnd = Math.floor(currentChunk);

      sum = 0;
      for (j = chunkStart; j <= chunkEnd; j += 1) {
        sum += waveform[j];
      }

      array[currentPixel] = sum / (chunkEnd - chunkStart + 1);
      currentPixel += 1;
    }
    return array;
  },

  draw: function(color) {
    var height = this.canvasHeight();
    var width  = this.mapped.length;
    this.element.width = width;
    this.element.height = height;
    var scrubberEnd = Math.round(width * this.time / this.duration) || 0;
    //console.log('scrubberEnd=', scrubberEnd, 'width=', width, 'height=', height);
    this.context.clearRect(0, 0, width + 200, height + 200);
    if (color) {
      this.context.fillStyle = color;
    }
    else {
      this.context.fillStyle = 'rgb(255, 190, 48)';
    }
    for (var i = 0; i < width; i++) {
      if (i == scrubberEnd && !color) {
        this.context.fillStyle = "rgb(187, 187, 187)";
      }
      this.context.fillRect(i, this.barTop(this.mapped[i], height), 1, this.barHeight(this.mapped[i], height));
    }
  }

};

