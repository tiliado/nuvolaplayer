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
