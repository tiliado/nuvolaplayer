/*
 * Copyright 2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

(function(window, undefined)
{

var $id = document.getElementById.bind(document);
var $class = document.getElementsByClassName.bind(document);
var $1 = document.querySelector.bind(document);
var $all = document.querySelectorAll.bind(document);

var Nuvola = {};

Nuvola.onload = function()
{
    this.appId = "test"; 
    this.appInfo = null;
    this.socket = eio('ws://' + location.host, {path: "/nuvola.io"});
	this.channel = new Nuvolaio.Channel(this.socket);
	var self = this;
	this.socket.on('open', function()
	{
		console.log("Socket opened");
		self.update();
	});
    this.socket.on('message', function(data)
    {
		console.log("Message received: " + data); 
	});
    this.socket.on('close', function()
    {
		console.log("Connection closed");
	});
    $id("play-pause").onclick = function()
    {
        Nuvola.channel.send("/app/" + Nuvola.appId + "/actions/activate", {name: "toggle-play"});
    };
}

Nuvola.update = function()
{
    this.updateAppId();
}

Nuvola.updateAppId = function()
{
    var self = this;
    self.channel.send("/master/core/get_top_runner", null, function(response)
    {
        try
        {
            self.appId = response.finish().result;
            self.updateAppInfo();
        }
        catch (e)
        {
            console.log(e);
            $id("app-name").innerText = "Error";
        }
    });
}

Nuvola.updateAppInfo = function()
{
    var self = this;
    self.channel.on("/app/" + this.appId + "/mediaplayer/track-info-changed", function(name, data)
    {
        self.updateTrackInfo();
    });
    self.channel.send("/master/core/get_app_info", {"id": this.appId}, function(response)
    {
        try
        {
            self.appInfo = response.finish();
            self.updateTrackInfo();
        }
        catch (e)
        {
            console.log(e);
            $id("app-name").innerText = "Error";
        }
    });
}

Nuvola.updateTrackInfo = function()
{
    var self = this;
    self.channel.send("/app/" + this.appId + "/mediaplayer/track-info", null, function(response)
    {
        try
        {
            var data = response.finish();
        }
        catch (e)
        {
            console.log(e);
            $id("app-name").innerText = "Error";
            return;
        }
        
        $id("app-name").innerText = self.appInfo ? self.appInfo.name : self.appId;
        $id("track-title").innerText = data.title || "unknown";
        $id("track-album").innerText = data.album || "unknown";
        $id("track-artist").innerText = data.artist || "unknown";
        $id("playback-state").innerText = data.state || "unknown";
        $id("play-pause").innerText = data.state === "playing" ? "pause" : "play";
        
        if (!data.state || data.state == "unknown")
        {
            $id("track-rating").innerText = "unknown";
        }
        else
        {
            var rating = Math.round((data.rating || 0) * 5);
            var stars = "";
            for (var i = 0; i < rating; i++)
            stars += "★";
            for (var i = 0; i < 5 - rating; i++)
            stars += "☆";
            $id("track-rating").innerText = stars;
        }
    });
	return;
}

window.onload = Nuvola.onload.bind(Nuvola);
})(window);
