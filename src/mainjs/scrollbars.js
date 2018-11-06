/*
 * Copyright 2018 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

require('core')
require('storage')

var DARK_SCROLLBAR = 'nuvola.dark_scrollbar'

var Scrollbars = Nuvola.$prototype(null)

Scrollbars.$init = function () {
  this.pageReady = false
  this.dark = null
  this.css = null
  Nuvola.core.connect('InitWebWorker', this)
}

Scrollbars._updateScrollbars = function () {
  Nuvola.config.getAsync(DARK_SCROLLBAR)
    .then((value) => {
      this.dark = value
      this.setTheme()
    })
    .catch(console.log.bind(console))
}

Scrollbars.setTheme = function () {
  if (this.pageReady && this.dark !== null) {
    var old = this.css
    this.css = Nuvola.makeElement('style', {}, this.dark ? this.darkScrollbar() : this.lightScrollbar())
    document.getElementsByTagName('head')[0].appendChild(this.css)
    if (old) {
      old.parentElement.removeChild(old)
    }
  }
}

Scrollbars._onInitWebWorker = function (emitter) {
  Nuvola.config.connect('ConfigChanged', this)
  this._updateScrollbars()
  var state = document.readyState
  if (state === 'interactive' || state === 'complete') {
    this._onPageReady()
  } else {
    document.addEventListener('DOMContentLoaded', this._onPageReady.bind(this))
  }
}

Scrollbars._onPageReady = function () {
  this.pageReady = true
  this.setTheme()
}

Scrollbars._onConfigChanged = function (emitter, key) {
  if (key === DARK_SCROLLBAR) {
    this._updateScrollbars()
  }
}

Scrollbars.darkScrollbar = function () {
  return this.scrollbarCss(
    'rgba(40, 40, 40, 0.9)', 'rgb(80, 80, 80)', 'rgb(40, 40, 40)')
}

Scrollbars.lightScrollbar = function () {
  return this.scrollbarCss(
    'rgb(190, 190, 190)', 'rgb(210, 210, 210)', 'rgb(150, 150, 150)')
}

Scrollbars.scrollbarCss = function (background, track, thumb) {
  return `
  ::-webkit-scrollbar,
  ::-webkit-scrollbar-corner,
  ::-webkit-resizer {
    width: 14px;
    height: 14px;
    background-color: ${background};
  }
  ::-webkit-scrollbar-track {
    border-radius: 10px;
    border-radius: 10px;
    margin: 4px;
    bbox-shadow: inset 0 0 10px 10px transparent;
    border: solid 4px transparent;
  }
  ::-webkit-scrollbar-track:corner-present {
    margin: 4px 0 0 4px;
  }
  ::-webkit-scrollbar-track-piece {
    box-shadow: inset 0 0 10px 10px ${track};
    border: solid 2px transparent;
  }
  ::-webkit-scrollbar-track:horizontal {
    box-shadow: inset 10px 0px 0px 10px transparent;
  }
  ::-webkit-scrollbar-track-piece:horizontal {
    box-shadow: inset 10px 0px 0px 10px ${track};
  }
  ::-webkit-scrollbar-track-piece:start {
    border-radius: 10px 10px 0 0;
    border-width: 2px 2px 0 2px;
  }
  ::-webkit-scrollbar-track-piece:end {
    border-radius: 0 0 10px 10px;
    border-width: 0 2px 2px 2px;
  }
  ::-webkit-scrollbar-track-piece:start:horizontal {
    border-radius: 10px 0 0 10px;
    border-width: 2px 0 2px 2px;
  }
  ::-webkit-scrollbar-track-piece:end:horizontal {
    border-radius: 0 10px 10px 0;
    border-width: 2px 2px 2px 0;
  }
  ::-webkit-scrollbar-thumb {
    border-radius: 10px;
    box-shadow: inset 0 0 10px 10px ${thumb};
    border: solid 3px transparent;
  }
  `
}

Nuvola.scrollbars = Nuvola.$object(Scrollbars)
