/*
 * Copyright 2016-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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
var $mkelm = function (tag, attrs, text)
{
	var elm = document.createElement(tag);
	if (attrs)
		for (var name in attrs)
			if (attrs.hasOwnProperty(name))
				elm.setAttribute(name, attrs[name]);
	if (text !== null && text !== undefined)
		 $addText(elm, text);
	return elm;
}
var $addText = function(elm, text)
{
	elm.appendChild(document.createTextNode("" + text));
	return elm;
}

var Nuvola = {};

Nuvola.onload = function()
{
    this.allApps = {};
    this.appId = null;
    this.socket = eio('ws://' + location.host, {path: "/nuvola.io"});
	this.channel = new Nuvolaio.Channel(this.socket);
	var self = this;
	this.socket.on('open', function()
	{
		console.log("Socket opened");
		self.start();
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
    $id("go-prev").onclick = function()
    {
        Nuvola.channel.send("/app/" + Nuvola.appId + "/actions/activate", {name: "prev-song"});
    };
    $id("go-next").onclick = function()
    {
        Nuvola.channel.send("/app/" + Nuvola.appId + "/actions/activate", {name: "next-song"});
    };
}

Nuvola.start = function()
{
    this.updateAllApps();
}

Nuvola.updateAllApps = function()
{
    var self = this;
    self.channel.on("/master/core/app-started", Nuvola._onAppAppeared.bind(self));
    self.channel.on("/master/httpremotecontrol/app-registered", Nuvola._onAppAppeared.bind(self));
    self.channel.on("/master/core/app-exited", Nuvola._onAppGone.bind(self));
    self.channel.on("/master/httpremotecontrol/app-unregistered", Nuvola._onAppGone.bind(self));
    self.channel.send("/master/core/list_apps", null, function(response)
    {
        try
        {
            self.allApps = {};
            var apps = response.finish().result;
            for (var i = 0; i < apps.length; i++)
				self.allApps[apps[i].id] = apps[i];
            self.updateAppsList();
        }
        catch (e)
        {
            console.log(e);
            $id("error").innerText = "Error";
        }
    });
}

Nuvola._onAppGone = function(notification, data)
{
	var app = data.result;
	delete this.allApps[app];
	this.updateAppsList();
	this.channel.unsubscribePrefix("/app/" + app + "/");
}

Nuvola._onAppAppeared = function(notification, data)
{
	var self = this;
	var app = data.result;
	var app = data.result;
	self.channel.send("/master/core/get_app_info", {id: app}, function(response)
	{
		self.allApps[app] = response.finish();
		self.updateAppsList();
	});
}

Nuvola.updateAppsList = function()
{
	var list = $id("app-list");
	list.onchange = function(){};
	while (list.firstChild)
		list.removeChild(list.firstChild);
	
	var selected = null;
	for (var id in this.allApps)
	{
		if (this.allApps.hasOwnProperty(id))
		{
			var app = this.allApps[id];
			if (app.capabilities.indexOf("httpcontrol") === -1)
				continue;
			if (!selected)
				selected = id;
			var option = $mkelm("option", {value: app.id}, app.name);
			if (id === this.appId)
			{
				selected = id;
				option.selected = true;
			}
			list.appendChild(option);
		}
	}
	var self = this;
	list.onchange = function()
	{
		self.updateAppInfo(this.value);
	};
	this.updateAppInfo(selected);
}

Nuvola.updateAppInfo = function(selected)
{
    if (this.appId)
		this.channel.unsubscribePrefix("/app/" + this.appId + "/");
    
    this.appId = selected;
    var self = this;
    self.channel.on("/app/" + this.appId + "/mediaplayer/track-info-changed", function(name, data)
    {
        self.updateTrackInfo();
    });
    self.updateTrackInfo();
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
            $id("error").innerText = "Error";
            return;
        }
        $id("error").innerText = "";
        $id("track-title").innerText = data.title || "unknown track";
	$id("track-album").innerText = data.album ? "from " +  data.album : "";
        $id("track-artist").innerText = data.artist ? "by " +  data.artist : "";
        $id("playback-state").innerText = data.state || "unknown";
        $id("play-pause").innerText = data.state === "playing" ? "Pause" : "Play";
        
        if (!data.state || data.state == "unknown")
        {
            $id("track-rating").innerText = "";
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
}

window.onload = Nuvola.onload.bind(Nuvola);
})(window);
