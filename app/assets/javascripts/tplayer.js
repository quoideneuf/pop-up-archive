/* Pop Up Archive embedded transcript/player */

"use strict"

var PUATPlayer = function(el, opts) {
  this.generateWaveform();
  this.el      = el;
  this.element = el.find('.scrubber canvas')[0];
  this.jp_pbar = el.find('.jp-progress');

  if (!opts) {
    this.time    = parseInt(el.find('.jp-time-holder .jp-current-time').html());
    this.ms      = el.find('.jp-time-holder .jp-duration').html().split(':');
    this.duration = parseInt(this.ms[0]*60 + this.ms[1]);
  }

  this.context = this.element.getContext('2d');
  this.mapped  = this.mapToArray(this.wavformData, el.width());
  this.draw();
  this.jp_seek_bar = el.find('.jp-progress .jp-seek-bar');
  var img = this.element.toDataURL();
  this.jp_seek_bar.css("background", 'url('+img+') no-repeat');
  // redraw the canvas in different color for the progressive play bar
  this.draw('rgb(255, 190, 48)');
  img = this.element.toDataURL();
  this.jp_play_bar = el.find('.jp-progress .jp-play-bar');
  this.jp_play_bar.css("background", 'url('+img+') no-repeat');
};

PUATPlayer.prototype = {
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
    console.log('scrubberEnd=', scrubberEnd, 'width=', width, 'height=', height);
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

