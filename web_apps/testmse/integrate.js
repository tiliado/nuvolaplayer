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

"use strict";

(function(Nuvola)
{

// Create media player component
var player = Nuvola.$object(Nuvola.MediaPlayer);

// Handy aliases
var PlaybackState = Nuvola.PlaybackState;
var PlayerAction = Nuvola.PlayerAction;
var fmtv = Nuvola.formatVersion;

// Translations
var _ = Nuvola.Translate.gettext;
var C_ = Nuvola.Translate.pgettext;

// define rating options - 5 states with state id 0-5 representing 0-5 stars
var ratingOptions = [
    // stateId, label, mnemo_label, icon, keybinding
    [0, "Rating: 0 stars", null, null, null, null],
    [1, "Rating: 1 star", null, null, null, null],
    [2, "Rating: 2 stars", null, null, null, null],
    [3, "Rating: 3 stars", null, null, null, null],
    [4, "Rating: 4 stars", null, null, null, null],
    [5, "Rating: 5 stars", null, null, null, null]
];

// Add new radio action named ``rating`` with initial state ``3`` (3 stars)
var ACTION_RATING = "rating";
Nuvola.actions.addRadioAction("playback", "win", ACTION_RATING, 3, ratingOptions);
// Add new togle action
var ACTION_WONDERFUL = "wonderful";
Nuvola.actions.addAction("playback", "win", ACTION_WONDERFUL, "Wonderful song", null, null, null, true);

// Create new WebApp prototype
var WebApp = Nuvola.$WebApp();

// Initialization routines
WebApp._onInitWebWorker = function(emitter)
{
    Nuvola.WebApp._onInitWebWorker.call(this, emitter);
    
    var state = document.readyState;
    if (state === "interactive" || state === "complete")
        this._onPageReady();
    else
        document.addEventListener("DOMContentLoaded", this._onPageReady.bind(this));
}

// Page is ready for magic
WebApp._onPageReady = function()
{
    var actions = [ACTION_WONDERFUL];
    for (var i=0; i <= 5; i++)
        actions.push(ACTION_RATING + "::" + i);
    player.addExtraActions(actions);
    
    try
    {
        document.getElementsByTagName("h1")[0].innerText = Nuvola.format(
            "Nuvola {1}, WebKitGTK {2}, libsoup {3}", fmtv(Nuvola.VERSION), fmtv(Nuvola.WEBKITGTK_VERSION), fmtv(Nuvola.LIBSOUP_VERSION));
    }
    catch (e)
    {
    }
    
    // Connect handler for signal ActionActivated
    Nuvola.actions.connect("ActionActivated", this);
    // Connect rating handler
    player.connect("RatingSet", this);

    // Start update routine
    this.update();
    
    Nuvola.global._config_set_object = function()
    {
        var track = {
        artist: "Jane Bobo",
        album: "Best hits",
        title: "How I met you"
        }
        Nuvola.config.set("integration.track", track);
        console.log(Nuvola.config.get("integration.track"));
    }
}

// Extract data from the web page
WebApp.update = function()
{
    var track = {
        artLocation: null // always null
    }

    var idMap = {title: "track", artist: "artist", album: "album"}
    for (var key in idMap)
    {
        try
        {
            track[key] = document.getElementById(idMap[key]).innerText || null;
        }
        catch(e)
        {
            // Always expect errors, e.g. document.getElementById() might return null
            track[key] = null;
        }
    }
    
    try
    {
        switch (document.getElementById("rating").innerText || null)
        {
        case "good":
            track.rating = 1.0;
            break;
        case "bad":
            track.rating = 0.2;
            break;
        default:
            track.rating = 0.0;
            break;
        }
    }
    catch (e)
    {
    }

    player.setTrack(track);
    
    try
    {
        switch(document.getElementById("status").innerText)
        {
            case "Playing":
                var state = PlaybackState.PLAYING;
                break;
            case "Paused":
                var state = PlaybackState.PAUSED;
                break;
            default:
                var state = PlaybackState.UNKNOWN;
                break;
        }
    }
    catch(e)
    {
        // Always expect errors, e.g. document.getElementById("status") might be null
        var state = PlaybackState.UNKNOWN;
    }

    player.setPlaybackState(state);
    player.setCanRate(state !== PlaybackState.UNKNOWN);
    
    var enabled;
    try
    {
        enabled = !document.getElementById("prev").disabled;
    }
    catch(e)
    {
        enabled = false;
    }
    player.setCanGoPrev(enabled);

    try
    {
        enabled  = !document.getElementById("next").disabled;
    }
    catch(e)
    {
        enabled = false;
    }
    player.setCanGoNext(enabled);

    var playPause = document.getElementById("pp");
    try
    {
        enabled  = playPause.innerText == "Play";
    }
    catch(e)
    {
        enabled = false;
    }
    player.setCanPlay(enabled);

    try
    {
        enabled  = playPause.innerText == "Pause";
    }
    catch(e)
    {
        enabled = false;
    }
    player.setCanPause(enabled);
    
    Nuvola.actions.updateEnabledFlag(ACTION_RATING, true);
    Nuvola.actions.updateEnabledFlag(ACTION_WONDERFUL, true);
    // Schedule the next update
    setTimeout(this.update.bind(this), 500);
}

// Handler of playback actions
WebApp._onActionActivated = function(emitter, name, param)
{
    switch (name)
    {
    case PlayerAction.TOGGLE_PLAY:
    case PlayerAction.PLAY:
    case PlayerAction.PAUSE:
    case PlayerAction.STOP:
        Nuvola.clickOnElement(document.getElementById("pp"));
        break;
    case PlayerAction.PREV_SONG:
        Nuvola.clickOnElement(document.getElementById("prev"));
        break;
    case PlayerAction.NEXT_SONG:
        Nuvola.clickOnElement(document.getElementById("next"));
        break;
    case ACTION_RATING:
        Nuvola.actions.updateState(ACTION_RATING, param);
        break;
    case ACTION_WONDERFUL:
        Nuvola.actions.updateState(ACTION_WONDERFUL, !!param);
        break;
    }
}

WebApp._onRatingSet = function(emitter, rating)
{
    alert("Rating: " + rating);
}

WebApp.start();

})(this);  // function(Nuvola)
