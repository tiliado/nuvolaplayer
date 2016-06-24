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

var HttpRequest = function(method, url, params)
{
    method = method.toUpperCase();
    this.payload = null;
    var payload = null;
    if (params)
    {
        var pairs = [];
        for (var key in params)
        {
            if (params.hasOwnProperty(key))
                pairs.push(encodeURIComponent(key) + "=" + encodeURIComponent(params[key]));
        }
        payload = pairs.length > 0 ? pairs.join("&") : null;
    }
    
    if (method == "GET" && payload)
        url += "?" + payload;
    
    if (method == "POST" && payload)
        this.payload = payload;
   
    this.method = method
    this.url = url;
}

HttpRequest.prototype.send = function()
{
    this.request = new XMLHttpRequest();
    this.request.onreadystatechange = this._onreadystatechange.bind(this);
    this.request.open(this.method, this.url);
    if (this.method == "POST" && this.payload)
        this.request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    this.request.send(this.payload);
}

HttpRequest.prototype._onreadystatechange = function()
{
    if (this.request.readyState === XMLHttpRequest.DONE)
    {
        if (this.request.status === 200)
            this.onsuccess(this);
        else
            this.onerror(this);
    }
}

HttpRequest.prototype.json = function()
{
    return JSON.parse(this.request.responseText);
}

HttpRequest.prototype.text = function()
{
    return this.request.responseText;
}

HttpRequest.prototype.onsuccess = function(request)
{
    console.log("HTTP Request successful");
}

HttpRequest.prototype.onerror = function(request)
{
    console.log("HTTP Request failed");
}


var Nuvola = {};

Nuvola.onload = function()
{
    this.appId = "test"; 
    this.update();
    $id("play-pause").onclick = function()
    {
        var r = new HttpRequest("post", "/+api/app/" + Nuvola.appId + "/actions/activate", {name: "toggle-play"});
        r.send();
        setTimeout(Nuvola.update.bind(Nuvola), 1000);
    };
}

Nuvola.update = function()
{
    var appId = this.appId;
    var request = new HttpRequest("get", "/+api/app/" + appId + "/mediaplayer/track-info", null);
    request.onsuccess = function(request)
    {
        var data;
        try
        {
            data = request.json();
        }
        catch (e)
        {
            this.onerror(request);
            return;
        }
        
        $id("app-name").innerText = appId;
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
    };
    request.onerror = function(request)
    {
        $id("app-name").innerText = "Error";
    }
    request.send();
}

window.onload = Nuvola.onload.bind(Nuvola);
})(window);
