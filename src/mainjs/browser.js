/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

var BrowserAction = {
	GO_BACK: "go-back",
	GO_FORWARD: "go-forward",
	GO_HOME: "go-home",
	RELOAD: "reload",
}

var Browser = function()
{
	this._downloadFileAsyncId = 0;
	this._downloadFileAsyncCallbacks = {}
}

Browser.prototype.downloadFileAsync = function(uri, basename, callback, data)
{
	var id = this._downloadFileAsyncId++;
	if (this._downloadFileAsyncId >= Number.MAX_VALUE - 1)
		this._downloadFileAsyncId = 0;
	this._downloadFileAsyncCallbacks[id] = [callback, data];
	Nuvola._sendMessageAsync("Nuvola.Browser.downloadFileAsync", uri, basename, id);
},

Browser.prototype._downloadDone = function(id, result, statusCode, statusText, filePath, fileURI)
{
	var cb = this._downloadFileAsyncCallbacks[id];
	delete this._downloadFileAsyncCallbacks[id];
	cb[0]({
		result: result,
		statusCode: statusCode,
		statusText: statusText,
		filePath: filePath,
		fileURI: fileURI
	}, cb[1]);
}

// export public items
Nuvola.BrowserAction = BrowserAction;
Nuvola.BrowserClass = Browser;
Nuvola.Browser = new Browser();
