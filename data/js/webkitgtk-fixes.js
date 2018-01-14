/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

(function(window)
{

for (var name in window)
{
	if (name.indexOf("webkit") === 0)
	{
		var unprefixed = name.substring(6);
		if (window[unprefixed] === undefined)
		{
			console.log("Unprefix: " + name + " -> " + unprefixed + " => " + !!window[name]);
			window[unprefixed] = window[name];
		}
	}
}

var unprefix = [
	"MediaSource", "AudioContext", "AudioPannerNode", "OfflineAudioContext", "URL", "ArrayBuffer", "ReadableStream",
	"SourceBuffer", "TransformStream", "Uint8Array", "Worker", "WritableStream"];
var size = unprefix.length;
for (var i = 0; i < size; i++)
{
	var unprefixed = unprefix[i];
	var prefixed = "webkit" + unprefixed;
	if (window[prefixed] && !window[unprefixed])
	{
		console.log("Unprefix hidden: " + prefixed + " -> " + unprefixed + " => " + !!window[prefixed]);
		window[unprefixed] = window[prefixed];
	}
}

var fixMimeType = function (mimeType)
{
	switch (mimeType)
	{
	case "audio/mpeg":
		return "audio/mpeg; codecs=\"mp3\"";
	case "video/webm":
		return "video/webm; codecs=\"vorbis,vp8\"";
	default:
	   return mimeType;
	}
}

if (window.MediaSource)
{
	var origMediaSourceIsTypeSupported = window.MediaSource.isTypeSupported;
	window.MediaSource.isTypeSupported = function (mimeType)
	{
		var mimeType = fixMimeType(mimeType);
		var result1 = origMediaSourceIsTypeSupported(mimeType);
		var result2 = new Audio("").canPlayType(mimeType);
		var result = result1 || (result2 == "probably");
		console.log(
			mimeType + ": MediaSource.isTypeSupported => " + result
			+ "; Audio.canPlayType => " + result2 + "; result => " + result);
		return result;
	}
}

if (window.Audio)
{
	var _canPlayType = window.Audio.prototype.canPlayType;
	window.Audio.prototype.canPlayType = function (mimeType)
	{
		var canPlayType = _canPlayType.bind(this);
		var result1 = canPlayType(mimeType);
		var mimeType2 = fixMimeType(mimeType);
		var result2 = canPlayType(mimeType2);
		console.log("Audio.canPlayType: " + mimeType + " => " + result1 + "; " + mimeType2 + " => " + result2);
		return result1 || result2;
	}
}

})(window);
