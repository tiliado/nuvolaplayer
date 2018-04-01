/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

require('prototype')

/**
 * @enum Names on browser's @link{Actions|actions}
 */
var BrowserAction = {
    /**
     * Go back to the previous page
     */
  GO_BACK: 'go-back',
    /**
     * Go forward
     */
  GO_FORWARD: 'go-forward',
    /**
     * Go to the web app's home page.
     */
  GO_HOME: 'go-home',
    /**
     * Reload page
     */
  RELOAD: 'reload'
}

/**
 * Prototype object for web browser management
 */
var Browser = Nuvola.$prototype(null)

/**
 * Initializes new Browser object
 */
Browser.$init = function () {
  this._downloadFileAsyncId = 0
  this._downloadFileAsyncCallbacks = {}
}

/**
 * Request download of a file
 *
 * @param String uri         file to download
 * @param String basename    a filename of the result
 * @param Function callback    function to call after file is downloaded
 * @param Variant data         extra data passed to the callback
 *
 * **callback** will be called with two arguments:
 *
 *   * ``result`` object with properties
 *        - ``success`` - ``true`` if the download has been successful, ``false`` otherwise
 *        - ``statusCode`` - a HTTP status code
 *        - ``statusText`` - description of the HTTP status code
 *        - ``filePath``   - filesystem path to the downloaded file
 *        - ``fileURI``    - URI of the downloaded file (``file:///...``)
 *   * ``data`` - data argument passed to downloadFileAsync
 */
Browser.downloadFileAsync = function (uri, basename, callback, data) {
  var id = this._downloadFileAsyncId++
  if (this._downloadFileAsyncId >= Number.MAX_VALUE - 1) { this._downloadFileAsyncId = 0 }
  this._downloadFileAsyncCallbacks[id] = [callback, data]
  Nuvola._callIpcMethodVoid('/nuvola/browser/download-file-async', [uri, basename, id])
}

Browser._downloadDone = function (id, success, statusCode, statusText, filePath, fileURI) {
  var cb = this._downloadFileAsyncCallbacks[id]
  delete this._downloadFileAsyncCallbacks[id]
  if (cb) {
    cb[0]({
      success: success,
      statusCode: statusCode,
      statusText: statusText,
      filePath: filePath,
      fileURI: fileURI
    }, cb[1])
  }
}

// export public items
Nuvola.BrowserAction = BrowserAction
Nuvola.Browser = Browser

/**
 * Instance object of @link{Browser} prototype connected to Nuvola backend.
 */
Nuvola.browser = Nuvola.$object(Browser)
