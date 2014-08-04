Title: Service Integrations Tutorial
Date: 2014-07-29 10:45 +0200

[TOC]

**NOTE: This tutorial applies to Nuvola Player 3 that is currently in development.**

This tutorial briefly describes creation of a new service integration for Nuvola Player 3 from
scratch. The goal is to write an integration script for *Test service* shipped with Nuvola Player,

There is also more detailed [Service Integrations Guide]({filename}guide.md) that provides
insight to the NuvolaKit core. 

Prepare development environment
===============================

 1. Install Nuvola Player 3
 2. Create project directory `~/projects/nuvola-player` (or any other name, but don't forget to
    adjust paths in this guide).
    
        :::sh
        mkdir -p ~/projects/nuvola-player
     
 3. Create a copy of the test service
    
        :::sh
        cd ~/projects/nuvola-player
        cp -r /usr/share/nuvolaplayer3/web_apps/test ./test-integration
        # or
        cp -r /usr/local/share/nuvolaplayer3/web_apps/test ./test-integration
    
 4. Rename old integration files
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        mv metadata.json metadata.old.json
        mv integrate.js integrate.old.js
    
 5. Create new integration files
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        touch metadata.json integrate.js
        gedit metadata.json integrate.js >/dev/null 2>&1 &

 6. Initialize Git repository
    
    You can skip this step if you don't know Git version control system. However, if you would like
    to have your service integration maintained as a part of the Nuvola Player project and available
    in Nuvola Player repository, you will increase maintenance burden of the project, because
    somebody (me) will have to create Git repository from tar.gz archive of your service integration
    anyway.
    
    Let's initialize a new Git repository for your service integration.
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git init .
        git add metadata.json integrate.js
        git commit -m "Initial commit"

Create metadata file
====================

Let's create ``metadata.json`` file with following content:

    :::json
    {
        "id": "test-integration",
        "name": "My Test Integration",
        "maintainer_name": "Jiří Janoušek",
        "maintainer_link": "https://github.com/fenryxo",
        "version_major": 1,
        "version_minor": 0,
        "api_major": 3,
        "api_minor": 0,
        "categories": "AudioVideo;Audio;",
        "home_url": "nuvola://home.html"
    }

This file contains several mandatory fields:

`id`

:   Identifier of the service. It can contain only letters `a-z`, digits `0-9` and dash `-` to
    separate words, e.g. `google-play` for Google Play Music, `eight-tracks` for 8tracks.com.

`name`

:   Name of the service (for humans), e.g. "Google Play Music".

`version_major`

:   Major version of the integration, must be an integer > 0. You should use
    `1` for an initial version. This number is increased, when a major change occurs.

`version_minor`

:   a minor version of service integration, an integer >= 0. This field should
    be increased when a new release is made.
    
`maintainer_name`

:   Name of the maintainer of the service integration.

`maintainer_link`

:   link to page with contact to maintainer (including `http://` or `https://`) or email address
    prefixed by `mailto:`.

`api_major` and `api_minor`

:   required version of JavaScript API, currently 3.0.

``categories``

:   [Application categories](http://standards.freedesktop.org/menu-spec/latest/apa.html) suitable
    for the web app, it is used to place a desktop launcher to proper category in applications menu.
    Nuvola Player services should be in ``"AudioVideo;Audio;"``.

`home_url`

:   Home page of your service. The test integration service uses `nuvola://home.html` that refers to
    file  `home.html` in the service's directory. You will use real homepage later in your own
    service integration (e.g. `https://play.google.com/music/` for Google Play Music).
    
    This field is optional if you use custom function to handle home page request:
    
      * TODO: Advanced - Web apps with user-specified home page URL
      * TODO: Advanced - Web app with a separated variants with different home page URL

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add metadata.json
        git commit -m "Add initial metadata for service"

Create integration script
=========================

Let's create base `integrate.js` script with following content:

```
#!js
/*
 * Copyright 2014 Your name <your e-mail>
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
    var track = {
        title: null,
        artist: null,
        album: null,
        artLocation: null
    }
    
    player.setTrack(track);
    player.setPlaybackState(PlaybackState.UNKNOWN);
    
    // Schedule the next update
    setTimeout(this.update.bind(this), 500);
}

// Handler of playback actions
WebApp._onActionActivated = function(object, name, param)
{
}

WebApp.start();

})(this);  // function(Nuvola)
```

This script is called once at start-up of the web app to perform initialization of the main process
(covered in [the guide]({filename}guide.md)) and again in the web page rendering process everytime
a web page is loaded in the web view.

Let's go through the code.

Lines 2-22

:   Copyright and license information. While you can choose any license for your work, it's
    recommended to use the license of Nuvola Player as shown in the example.

Line 25

:   Use strict JavaScipt mode in your scripts.

Lines 27-28 and 86

:   Use anonymous function to create closure with Nuvola object.

Line 31

:   Create MediaPlayer component that adds playback actions and is later used to provide playback
    details.

Line 38

:   Create new WebApp prototype object derived from the `Nuvola.WebApp` prototype that contains
    handy default handlers for initialization routines and signals from Nuvola core. 
    You can override them if your web app requires more magic ;-)

Lines 41-50

:   Handler for `Nuvola.Core::InitWebWorker` signal that emitted in clear JavaScript environment
    with a brand new global ``window`` object. You should not touch it, only perform necessary
    initialization (usually not needed) and set your listener for either `document`'s
    `DOMContentLoaded` event (preferred) or `window`'s `load` event.

Lines 53-60

:   When document object model of a web page is ready, we register a signal handler for playback
    actions and call update() method.

Lines 63-77

:   The update() method periodically extracts playback state and track details.

Lines 81-82

:   Actions handler is used to respond to player actions.

Line 84

:   Convenience method to create and register new instance of your web app integration.

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add integrate.js
        git commit -m "Add skeleton of integration script"

Launch Nuvola Player
====================

Run Nuvola Player 3 from terminal with following command and you will see a list with only one
service, because we told Nuvola Player to load service integrations only from directory
`~/projects/nuvola-player`.
    
    nuvolaplayer3 -D -A ~/projects/nuvola-player

![A list with single service integration]({filename}/images/guide/app_list_one_service.png)

Launch your service integration and a new window will be opened with the test service. Right-click
the web page anywhere and select "Inspect element" to show WebKit Web Inspector.

![Inspect element]({filename}/images/guide/inspect_element.png)
![Inspect playback state]({filename}/images/guide/inspect_playback_state.png)

You can also launch your service integration with id `test-integration` directly with command

    nuvolaplayer3 -D -A ~/projects/nuvola-player -a test-integration

Playback state and track details
================================

The first task of your service integration is to extract playback state and track details from the
web page and provide them to media player component. There are two ways how to extract playback
state and track details:

 1. Use [Document Object Model][DOM] to get information from the HTML code of the web page.
 2. Use JavaScript API provided by the web page if there is any.

[DOM]: https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model

The first way is more general and will be described here.

Playback state
--------------

The code to extract playback state might be

```js
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
![Playback state]({filename}/images/guide/playback_state.png)

Track details
-------------

Similarly, we can obtain track details:

```js
WebApp.update = function()
{
    ...
    
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
    
    player.setTrack(track);
    
    ...
}
```

![Track details]({filename}/images/guide/track_details.png)

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add integrate.js
        git commit -m "Extract metadata and playback state"

Player Actions
==============

The second responsibility of a service integration is to manage media player actions:

 1. Set which actions are enabled.
 2. Invoke the actions when they are activated.

The first part is done via calls player.setCanPause(), player.setCanPlay(),
player.setCanGoPrev() and player.setCanGoNext():

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
![Playback actions]({filename}/images/guide/playback_actions.png)

To handle playback actions, it is neccessary to connect to Actions::ActionActivated signal.
This signal is emitted for every UI action, not only for player actions.

```js
WebApp._onActionActivated = function(object, name, param)
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
You should click action buttons in the developer's sidebar to be sure they are working as expected.

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add integrate.js
        git commit -m "Add player actions handling"

TODO: Advanced - custom actions.
