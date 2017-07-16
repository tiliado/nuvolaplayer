/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

// Constants
var ADDRESS = "app.address";
var ADDRESS_DEFAULT = "default";
var ADDRESS_CUSTOM = "custom";
var HOST = "app.host";
var PORT = "app.port";
var COUNTRY_VARIANT = "app.country_variant";
var COUNTRY_VARIANTS = [
    ["de", C_("Amazon variant", "Germany")],
    ["fr", C_("Amazon variant", "France")],
    ["co.uk", C_("Amazon variant", "United Kingdom")],
    ["com", C_("Amazon variant", "United States")]
];

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

WebApp._onInitAppRunner = function(emitter)
{
    Nuvola.WebApp._onInitAppRunner.call(this, emitter);
    
    Nuvola.config.setDefault(ADDRESS, ADDRESS_DEFAULT);
    Nuvola.config.setDefault(HOST, "");
    Nuvola.config.setDefault(PORT, "");
    Nuvola.config.setDefault(COUNTRY_VARIANT, "com");
    
    Nuvola.core.connect("InitializationForm", this);
    Nuvola.core.connect("PreferencesForm", this);
}

WebApp._onInitWebWorkerHelper = function(emitter)
{
    Nuvola.WebApp._onInitWebWorkerHelper.call(this, emitter);
    Nuvola.core.connect("ResourceRequest", this);
}

// Initialization routines
WebApp._onInitWebWorker = function(emitter)
{
    Nuvola.WebApp._onInitWebWorker.call(this, emitter);
    
    var state = document.readyState;
    if (state === "interactive" || state === "complete")
        this._onPageReady();
    else
        document.addEventListener("DOMContentLoaded", this._onPageReady.bind(this));
    
    this.testPrototypes();
    this.testTranslation();
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
    
    this.runUnitTests();
}

// Extract data from the web page
WebApp.update = function()
{
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
    
    try
    {
        track.length = document.getElementById("timetotal").innerText || null;
    }
    catch (e)
    {
        track.length = null;
    }
    
    try
    {
        var trackPosition = document.getElementById("timeelapsed").innerText || null;
    }
    catch (e)
    {
        var trackPosition = null;
    }

    try
    {
        var volume = document.getElementById("volume").innerText / 100 || null;
    }
    catch (e)
    {
        var volume = null;
    }
    
    player.setTrack(track);
    player.setTrackPosition(trackPosition);
    player.updateVolume(volume);
    player.setPlaybackState(state);
    player.setCanRate(state !== PlaybackState.UNKNOWN);
    player.setCanSeek(state !== PlaybackState.UNKNOWN);
    player.setCanChangeVolume(state !== PlaybackState.UNKNOWN);
    
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
    case PlayerAction.CHANGE_VOLUME:
        document.getElementById("volume").innerText = Math.round(param * 100);
        break;
    case PlayerAction.SEEK:
        var elm = document.getElementById("timetotal");
        var total = Nuvola.parseTimeUsec(elm ? elm.innerText : null);
        if (param > 0 && param <= total)
            Nuvola.clickOnElement(document.getElementById("progresstext"), param/total, 0.5);
        break;
    }
}

WebApp._onRatingSet = function(emitter, rating)
{
    alert("Rating: " + rating);
}

WebApp._onInitializationForm = function(emitter, values, entries)
{
    if (!Nuvola.config.hasKey(ADDRESS))
        this.appendPreferences(values, entries);
}

WebApp._onPreferencesForm = function(emitter, values, entries)
{
    this.appendPreferences(values, entries);
}

WebApp.appendPreferences = function(values, entries)
{
    values[ADDRESS] = Nuvola.config.get(ADDRESS);
    values[HOST] = Nuvola.config.get(HOST);
    values[PORT] = Nuvola.config.get(PORT);
    entries.push(["header", _("Logitech Media Server")]);
    entries.push(["label", _("Address of your Logitech Media Server")]);
    entries.push(["option", ADDRESS, ADDRESS_DEFAULT, _("use default address ('localhost:9000')"), null, [HOST, PORT]]);
    entries.push(["option", ADDRESS, ADDRESS_CUSTOM, _("use custom address"), [HOST, PORT], null]);
    entries.push(["string", HOST, "Host"]);
    entries.push(["string", PORT, "Port"]);
    
    values[COUNTRY_VARIANT] = Nuvola.config.get(COUNTRY_VARIANT);
    entries.push(["header", _("Amazon Cloud Player")]);
    entries.push(["label", _("Preferred national variant")]);
    for (var i = 0; i < COUNTRY_VARIANTS.length; i++)
        entries.push(["option", COUNTRY_VARIANT, COUNTRY_VARIANTS[i][0], COUNTRY_VARIANTS[i][1]]);
}

WebApp._onResourceRequest = function(emitter, request)
{
    request.url = request.url.replace("webcomponents.js", "webcomponents2.js");
}

WebApp.testPrototypes = function()
{
    var Building = Nuvola.$prototype(null);

    Building.$init = function(address)
    {
            this.address = address;
    }
    
    Building.printAddress = function()
    {
        console.log(this.address);
    }
    
    var Shop = Nuvola.$prototype(Building);
    
    Shop.$init = function(address, goods)
    {
            Building.$init.call(this, address)
            this.goods = goods;
    }
    
    Shop.printGoods = function()
    {
            console.log(this.goods);
    }
    
    var house = Nuvola.$object(Building, "King Street 1024, London");
    house.printAddress();
    
    var candyShop = Nuvola.$object(Shop, "King Street 1024, London", "candies");
    candyShop.printAddress();
    candyShop.printGoods();
}

WebApp.testTranslation = function()
{
    var _ = Nuvola.Translate.gettext;
    
    /// You can use tree slashes to add comment for translators.
    /// It has to be on a line preceding the translated string though.
    console.log(_("Hello world!"));
    var name = "Jiří";
    /// {1} will be replaced by name
    console.log(Nuvola.format(_("Hello {1}!"), name));
    
    var ngettext = Nuvola.Translate.ngettext;
    var eggs = 5;
    var text = ngettext(
        /// You can use tree slashes to add comment for translators.
        /// It has to be on a line preceding the singular string though.
        /// {1} will be replaced by number of eggs in both forms,
        /// but can be omitted as shown in singular form.
        "There is one egg in the fridge.",
        "There are {1} eggs in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    var eggs = 1;
    var text = ngettext(
        "There is one egg in the fridge.",
        "There are {1} eggs in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    
    var C_ = Nuvola.Translate.pgettext;
    
    /// You can use tree slashes to add comment for translators.
    /// It has to be on a line preceding the translated string though.
    console.log(C_("Navigation", "Back"));
    console.log(C_("Body part", "Back"));
    
    console.log(Nuvola.Translate.gettext("Bye World!"));
    var name = "Jiří";
    console.log(Nuvola.format(Nuvola.Translate.gettext("Bye {1}!"), name));
    
    var eggs = 5;
    var text = Nuvola.Translate.ngettext(
        "There is one child in the fridge.",
        "There are {1} children in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    var eggs = 1;
    var text = Nuvola.Translate.ngettext(
        "There is one child in the fridge!",
        "There are {1} children in the fridge!",
        eggs);
    console.log(Nuvola.format(text, eggs));
    
    console.log(Nuvola.Translate.pgettext("Navigation", "Forward"));
    console.log(Nuvola.Translate.pgettext("Body part", "Forward"));
}

WebApp.runUnitTests = function()
{
    if (!window.unitjs)
        throw new Error("Unit.js not installed");
}

WebApp.start();

})(this);  // function(Nuvola)
