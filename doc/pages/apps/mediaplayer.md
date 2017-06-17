Title: Media Player Integration

[TOC]

Historically, Nuvola Apps Runtime (previously known as Nuvola Player) has a great support for media players and
offers a high level API for Media Player Integration.

Prerequisites
=============

Before continuing, make sure you are familiar with following topics:

  * [Service Integration Tutorial](tutorial.html): Generic information how to set up Nuvola ADK, create a basic skeleton of your
    script and open web inspector tools.
  * [Document Object Model][DOM]: Methods how to extract metadata from a web page, e.g.
	[document.getElementById](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementById),
    [document.getElementsByName](https://developer.mozilla.org/en-US/docs/Web/API/Document.getElementsByName),
    [document.getElementsByClassName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByClassName),
    [document.getElementsByTagName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByTagName),
    [document.querySelector](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelector),
    [document.querySelectorAll](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelectorAll).
  
[DOM]: https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model

Metadata
========

Media player scripts generally contain these metadata:

  * `"categories": "AudioVideo;Audio;"` - for the launcher to be shown among audio & video applications
  * `"requirements": "Feature[Flash]"` - if your web app requires Flash plugin for media playback
  * `"requirements": "Codec[MP3]"` - if your web app requires HTML5 Audio with MP3 codec for media playback
  

Integration Script
==================

Media player skeleton
---------------------

Save the code bellow as a `integrate.js` file. It performs following actions:

  * Creates new `Nuvola.MediaPlayer` component.
  * Creates new `WebApp` object.
  * Initializes WebWorker process to call `_onPageReady` callback when page is loaded.
  * Creates `update()` loop.
  * Connect handler for actions.

```
#!js
"use strict";

(function(Nuvola)
{

// Create media player component
var player = Nuvola.$object(Nuvola.MediaPlayer);

// Handy aliases
var PlaybackState = Nuvola.PlaybackState;
var PlayerAction = Nuvola.PlayerAction;

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
    // Connect handler for signal ActionActivated
    Nuvola.actions.connect("ActionActivated", this);
    
    // Start update routine
    this.update();
}

// Extract data from the web page
WebApp.update = function()
{
    // ...
    
    // Schedule the next update
    setTimeout(this.update.bind(this), 500);
}

// Handler of playback actions
WebApp._onActionActivated = function(emitter, name, param)
{
}

WebApp.start();

})(this);  // function(Nuvola)
```
 
Playback state
--------------

Looking at the code of a web page shown in the picture bellow, the code to extract playback state
might be. Playback states are defined in an enumeration
[Nuvola.PlaybackState](apiref>Nuvola.PlaybackState) and set by method
[player.setPlaybackState()](apiref>Nuvola.MediaPlayer.setPlaybackState).

```js
...
var PlaybackState = Nuvola.PlaybackState;
...

WebApp.update = function()
{
    ...
    
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
    
    ...
}
```
![Playback state](:images/guide/playback_state.png)

Track details
-------------

Similarly, we can obtain track details and pass them to method [player.setTrack()](apiref>Nuvola.MediaPlayer.setTrack)

```js
WebApp.update = function()
{
    ...
    
    var track = {
        artLocation: null, // always null
        rating: null // same
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
    
    player.setTrack(track);
    
    ...
}
```

![Track details](:images/guide/track_details.png)

Media Player Actions
--------------------

The second responsibility of a service integration is to **manage media player actions**:

 1. Set which actions are enabled.
 2. Invoke the actions when they are activated.

The first part is done via calls [player.setCanPause()](apiref>Nuvola.MediaPlayer.setCanPause),
[player.setCanPlay()](apiref>Nuvola.MediaPlayer.setCanPlay),
[player.setCanGoPrev()](apiref>Nuvola.MediaPlayer.setCanGoPrev) and
[player.setCanGoNext()](apiref>Nuvola.MediaPlayer.setCanGoNext):

```js
WebApp.update = function()
{
    ...
    
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
    
    ...
}
```

![Playback actions](:images/guide/playback_actions.png)

To handle playback actions defined in an enumeration [PlayerAction](apiref>Nuvola.PlayerAction),
it is necessary to connect to [Actions::ActionActivated signal](apiref>Nuvola.Actions%3A%3AActionActivated).
You can use a convenient function [Nuvola.clickOnElement()](apiref>Nuvola.clickOnElement) to
simulate clicking.

```js
var PlayerAction = Nuvola.PlayerAction;

...

WebApp._onPageReady = function()
{
    // Connect handler for signal ActionActivated
    Nuvola.actions.connect("ActionActivated", this);
    
    // Start update routine
    this.update();
}

...

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
    }
}
```

!!! danger "Always test playback actions"
    You should click action buttons in the developer's sidebar to be sure they are working as expected.

!!! info "Custom actions"
    Service integrations can also create [custom Actions](:apps/custom-actions.html) like thumbs
    up/down or star rating.

Progress bar
------------

Since **Nuvola 4.5**, it is also possible to integrate progress bar. If you wish to make your script compatible with
older versions, use respective [Nuvola.checkVersion](apiref>Nuvola.checkVersion) condition as shown in examples bellow.

In order to extract track length and position, use these two API calls:

  * [MediaPlayer.setTrack](apiref>Nuvola.MediaPlayer.setTrack) supports `track.length` property, which holds track
    length either as a string "mm:ss" or number of microseconds. This property is ignored in Nuvola < 4.5.
  * [MediaPlayer.setTrackPosition](apiref>Nuvola.MediaPlayer.setTrackPosition) is used to update track position.
    This method is not available in Nuvola < 4.5 and results in error.
    
```js
WebApp.update = function()
{
    ...
    
    // @API 4.5: track.length ignored in Nuvola < 4.5
    var elm = document.getElementById("timetotal");
    track.length = elm ? elm.innerText || null : null;
    player.setTrack(track);
    
    ...
    
    if (Nuvola.checkVersion && Nuvola.checkVersion(4, 4, 18))  // @API 4.5
    {
        var elm = document.getElementById("timeelapsed");
        player.setTrackPosition(elm ? elm.innerText || null : null);
    }
    
    ...
}
```

If you wish to let user change track position, use this API:

  * [MediaPlayer.setCanSeek](apiref>Nuvola.MediaPlayer.setCanSeek) is used to enable/disable remote seek.
    This method is not available in Nuvola < 4.5 and results in error.
  * Then the [PlayerAction.SEEK](apiref>Nuvola.PlayerAction) is emitted whenever a remote seek is requested.
    The action parameter contains a track position in microseconds. `PlayerAction.SEEK` is undefined in
    Nuvola < 4.5 and the handler is never executed.
  * You may need to use [Nuvola.clickOnElement](apiref>Nuvola.clickOnElement) with coordinates to trigger a click
    event at the position of progress bar corresponding to the track position,
    e.g. `Nuvola.clickOnElement(progressBar, param/Nuvola.parseTimeUsec(trackLength), 0.5)`.

```js
WebApp.update = function()
{
    ...
    if (Nuvola.checkVersion && Nuvola.checkVersion(4, 4, 18))  // @API 4.5
    {
        player.setCanSeek(state !== PlaybackState.UNKNOWN);
    }
    ...
}

...

WebApp._onActionActivated = function(emitter, name, param)
{
    switch (name)
    {
    ...
    case PlayerAction.SEEK:  // @API 4.5: undefined & ignored in Nuvola < 4.5
        var elm = document.getElementById("timetotal");
        var total = Nuvola.parseTimeUsec(elm ? elm.innerText : null);
        if (param > 0 && param <= total)
            Nuvola.clickOnElement(document.getElementById("progresstext"), param/total, 0.5);
        break;
    ...
    }
}

...
```

![Playback time](:images/guide/progress_bar.png)
