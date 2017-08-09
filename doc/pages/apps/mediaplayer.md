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
  * `"requirements": "Feature[MSE] Codec[MP3]"` - if your web app requires HTML5 Media Source Extension (MSE)
    with MP3 codec for media playback
  

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

Track Rating
------------

Since **Nuvola 3.1**, it is also possible to integrate track rating. If you wish to make your script compatible with
older versions, use respective [Nuvola.checkVersion](apiref>Nuvola.checkVersion) condition as shown in examples bellow.

In order to provide users with the current rating state, use these API calls:

  * [MediaPlayer.setTrack()](apiref>Nuvola.MediaPlayer.setTrack) method accepts `track.rating` property, which holds
    track rating as a number in range from `0.0` to `1.0` as in 
    [the MPRIS/xesam specification](https://www.freedesktop.org/wiki/Specifications/mpris-spec/metadata/#index22h4).
    This property is ignored in Nuvola < 3.1.
  * [MediaPlayer.setCanRate()](apiref>Nuvola.MediaPlayer.setCanRate) controls whether
    it is allowed to change rating remotely or not. This method is not available in Nuvola < 3.1 and results in error.
  * [MediaPlayer::RatingSet](apiref>Nuvola.MediaPlayer%3A%3ARatingSet) is emitted when rating is changed remotely.
    This signal is not available in Nuvola < 3.1 and results in error.

It's up to you to decide **how to map the double value to the rating system of your web app**.
Here are some suggestions:

  * **Percentage rating** is the simplest case mapping the range `0.0-1.0` to percentage 0%-100%.
  * **Five-star rating** may calculate the number of stars as `stars = rating / 5.0`.
  * **Thumb up/down rating** is a bit tricky. You can use rating `0.2` for thumb down and `1.0` for thumb up in the
    `track.rating` property and interpret rating <= `0.41` (0-2 stars) as thumb down and rating >= `0.79` (4-5 stars)
    as thumb up in the `RatingSet` signal handler.
    

In this example, a track can be rated as *good* (thumb up) or *bad* (thumb down).

```js

...

// Page is ready for magic
WebApp._onPageReady = function()
{
    // Connect handler for signal ActionActivated
    Nuvola.actions.connect("ActionActivated", this);
    
    // Connect rating handler if supported
    if (Nuvola.checkVersion && Nuvola.checkVersion(3, 1))  // @API 3.1
        player.connect("RatingSet", this);

    // Start update routine
    this.update();
}

// Extract data from the web page
WebApp.update = function()
{
    var track = {
        ...
    }

    ...
    
    // Parse rating
    switch (document.getElementById("rating").innerText || null)
    {
    case "good":
        track.rating = 1.0; // five stars
        break;
    case "bad":
        track.rating = 0.2; // one star
        break;
    default:
        track.rating = 0.0; // zero star
        break;
    }

    player.setTrack(track);
    
    ...
    
    var state = PlaybackState.UNKNOWN;
    state = ...

    player.setPlaybackState(state);
    
    if (Nuvola.checkVersion && Nuvola.checkVersion(3.1))  // @API 3.1
        player.setCanRate(state !== PlaybackState.UNKNOWN);
}

...

// Handler for rating
WebApp._onRatingSet = function(emitter, rating)
{
    Nuvola.log("Rating set: {1}", rating);
    var current = document.getElementById("rating").innerText;
    if (rating <= 0.4) // 0-2 stars
        document.getElementById("rating").innerText = current === "bad" ? "-" : "bad";
    else if (rating >= 0.8) // 4-5 stars
        document.getElementById("rating").innerText = current === "good" ? "-" : "good";
    else // three stars
        throw new Error("Invalid rating: " + rating + ".\n\n" 
        + "Have you clicked the three-star button? It isn't supported.");
}

...
```

![Track Rating](:images/guide/track_rating.png)

Progress bar
------------

Since **Nuvola 4.5**, it is also possible to integrate progress bar. If you wish to make your script compatible with
older versions, use respective [Nuvola.checkVersion](apiref>Nuvola.checkVersion) condition as shown in examples bellow.

In order to extract track length and position, use these API calls:

  * [MediaPlayer.setTrack](apiref>Nuvola.MediaPlayer.setTrack) supports `track.length` property, which holds track
    length either as a string "mm:ss" or number of microseconds. This property is ignored in Nuvola < 4.5.
  * [MediaPlayer.setTrackPosition](apiref>Nuvola.MediaPlayer.setTrackPosition) is used to update track position.
    This method is not available in Nuvola < 4.5 and results in error.
  * [Nuvola.parseTimeUsec](apiref>Nuvola.parseTimeUsec) (in Nuvola >= 4.5) can be used to convert track length string (e.g. "2:35")
    into the number of microseconds. [MediaPlayer.setTrack](apiref>Nuvola.MediaPlayer.setTrack) does that automatically
    for the `track.length` property.
    
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

Volume management
-----------------

Since **Nuvola 4.5**, it is also possible to integrate volume management. If you wish to make your script compatible with
older versions, use respective [Nuvola.checkVersion](apiref>Nuvola.checkVersion) condition as shown in examples bellow.

In order to extract volume, use [MediaPlayer.updateVolume](apiref>Nuvola.MediaPlayer.updateVolume) with the parameter
in range 0.0-1.0 (i.e. 0-100%). This method is not available in Nuvola < 4.5 and results in error.
    
```js
WebApp.update = function()
{
    ...
    
    if (Nuvola.checkVersion && Nuvola.checkVersion(4, 4, 18))  // @API 4.5
    {
        var elm = document.getElementById("volume");
        player.updateVolume(elm ? elm.innerText / 100 || null : null);
    }
    
    ...
}
```

If you wish to let user change volume, use this API:

  * [MediaPlayer.setCanChangeVolume](apiref>Nuvola.MediaPlayer.setCanChangeVolume) is used to enable/disable remote
    volume managementThis method is not available in Nuvola < 4.5 and results in error.
  * Then the [PlayerAction.CHANGE_VOLUME](apiref>Nuvola.PlayerAction) is emitted whenever a remote volume change
    requested. The action parameter contains new volume as a double value in range 0.0-1.0.
    `PlayerAction.CHANGE_VOLUME` is undefined in Nuvola < 4.5 and the handler is never executed.
  * You may need to use [Nuvola.clickOnElement](apiref>Nuvola.clickOnElement) with coordinates to trigger a click
    event at the position of volume bar corresponding to the desired volume,
    e.g. `Nuvola.clickOnElement(volumeBar, param, 0.5)`.
```js
WebApp.update = function()
{
    ...
    if (Nuvola.checkVersion && Nuvola.checkVersion(4, 4, 18))  // @API 4.5
    {
        player.setCanChangeVolume(state !== PlaybackState.UNKNOWN);
    }
    ...
}

...

WebApp._onActionActivated = function(emitter, name, param)
{
    switch (name)
    {
    ...
    case PlayerAction.CHANGE_VOLUME:  // @API 4.5: undefined & ignored in Nuvola < 4.5
        document.getElementById("volume").innerText = Math.round(param * 100);
        break;
    ...
    }
}

...
```

![Playback volume](:images/guide/volume_management.png)
