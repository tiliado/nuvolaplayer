/*
 * Copyright 2011-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

var unprefixWebkit = function(window)
{
    for (var name in window)
    {
        if (name.indexOf("webkit") === 0)
        {
            var unprefixed = name.substring(6);
            if (window[unprefixed] === undefined)
            {
                console.log("Unprefix: " + name + " -> " + unprefixed + " | " + window[name]);
                window[unprefixed] = window[name];
            }
        }
    }
    
    var unprefix = ["MediaSource", "AudioContext", "AudioPannerNode", "OfflineAudioContext", "URL"];
    var size = unprefix.length;
    for (var i = 0; i < size; i++)
    {
        var unprefixed = unprefix[i];
        var prefixed = "webkit" + unprefixed;
        if (!window[prefixed])
        {
            console.log("Missing hidden: " + prefixed + " -> " + unprefixed + " | " + window[unprefixed]);
        }
        else if (!window[unprefixed])
        {
            console.log("Unprefix hidden: " + prefixed + " -> " + unprefixed + " | " + window[prefixed] );
            window[unprefixed] = window[prefixed];
        }
    }
}

var mimeTypes = {
	ogg: {
		mimeType: ["audio/ogg"],
		testFile: "http://www.thewormlab.com/MiaowMusic/ogg/Miaow-snip-Stirring of a fool.ogg"
	},
	mp3: {
		mimeType: ["audio/mpeg", "audio/mpeg; codecs=\"flump3dec\"", "audio/mpeg; codecs=\"mp3\""],
		testFile: "http://www.thewormlab.com/MiaowMusic/mp3/Miaow-snip-Stirring of a fool.mp3"
	},
	wav: {
		mimeType: ["audio/x-wav"],
		testFile: "http://www.thewormlab.com/MiaowMusic/wav/Miaow-snip-Stirring of a fool.wav"
	},
	au: {
		mimeType: ["audio/basic"],
		testFile: "http://www.thewormlab.com/MiaowMusic/au/Miaow-snip-Stirring of a fool.au"
	},
	aif: {
		mimeType: ["audio/x-aiff"],
		testFile: "http://www.thewormlab.com/MiaowMusic/aif/Miaow-snip-Stirring of a fool.aif"
	},
	webm: {
		mimeType: ['video/webm', 'video/webm; codecs="vorbis,vp8"']
	} 
}

var audioTag = document.createElement('audio');
var audioTagSupported = !!audioTag.canPlayType;
try
{
	var audioObject = new Audio("");
	var audioObjectSupported = !!audioObject.canPlayType;
}
catch(e)
{
	var audioObject = null;
	var audioObjectSupported = false;
}

var testAudio = function()
{
	var output = document.createElement("pre");
	var mainDiv = document.getElementById("main");
	var table = document.createElement("table");
	mainDiv.appendChild(table);
	
	var row = document.createElement("tr");
	table.appendChild(row);
	var cell = document.createElement("th");
	row.appendChild(cell);
	cell.appendChild(document.createTextNode("MIME type"));
	cell = document.createElement("th");
	row.appendChild(cell);
	cell.appendChild(document.createTextNode("<audio> tag"));
	cell = document.createElement("th");
	row.appendChild(cell);
	cell.appendChild(document.createTextNode("Audio() object"));
	cell = document.createElement("th");
	row.appendChild(cell);
	cell.appendChild(document.createTextNode("Media Source"));
	
	for (var mime in mimeTypes)
	{
		var info = mimeTypes[mime];
		for (var i = 0; i < info.mimeType.length; i++)
		{
			
			info.audioTag = audioTagSupported ? "" + audioTag.canPlayType(info.mimeType[i]) : "(error)";
			if(info.audioTag === ""){
				info.audioTag = "no";
			}
			info.audioTagOk = info.audioTag === "maybe" || info.audioTag === "probably";
			
			info.audioObject = audioObjectSupported ? "" + audioObject.canPlayType(info.mimeType[i]) : "error";
			if(info.audioObject === ""){
				info.audioObject = "no";
			}
			info.audioObjectOk = info.audioObject === "maybe" || info.audioObject === "probably";
			info.ok = info.audioTagOk || info.audioObjectOk;
			
			info.mediaSource = window.MediaSource ? (MediaSource.isTypeSupported(info.mimeType[i]) ? "yes" : "no") : "null";
			
			row = document.createElement("tr");
			table.appendChild(row);
			cell = document.createElement("td");
			row.appendChild(cell);
			cell.appendChild(document.createTextNode(info.mimeType[i]));
			cell = document.createElement("td");
			row.appendChild(cell);
			cell.appendChild(document.createTextNode(info.audioTag));
			cell = document.createElement("td");
			row.appendChild(cell);
			cell.appendChild(document.createTextNode(info.audioObject));
			cell = document.createElement("td");
			row.appendChild(cell);
			cell.appendChild(document.createTextNode(info.mediaSource));
		}
	}
}

window.onload = function()
{
	unprefixWebkit(window);
	testAudio();
};
