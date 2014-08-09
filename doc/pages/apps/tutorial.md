Title: Service Integrations Tutorial

[TOC]

This tutorial briefly describes creation of **a new service integration for Nuvola Player 3 from
scratch**. The goal is to write an integration script for *Test service* shipped with Nuvola Player
and to prepare you to create your own service integration. I'm looking forward to a code review ;-)
There is also more detailed [Service Integrations Guide]({filename}guide.md) that provides
insight to the NuvolaKit core. 

Prepare development environment
===============================

 1. Install Nuvola Player 3
 2. Create a project directory `~/projects/nuvola-player` (or any other name, but don't forget to
    adjust paths in this tutorial).
    
        :::sh
        mkdir -p ~/projects/nuvola-player
     
 3. Create a copy of the test service shipped with Nuvola Player 3.
    
        :::sh
        cd ~/projects/nuvola-player
        cp -r /usr/share/nuvolaplayer3/web_apps/test ./test-integration
        # or
        cp -r /usr/local/share/nuvolaplayer3/web_apps/test ./test-integration
    
 4. Rename old integration files (or remove it).
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        mv metadata.json metadata.old.json
        mv integrate.js integrate.old.js
    
 5. Create new integration files and open them in your preferred plan-text editor (Gedit,
    for example).
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        touch metadata.json integrate.js
        gedit metadata.json integrate.js >/dev/null 2>&1 &

 6. Initialize a new [Git][git] repository for your service integration.
    
    You can skip this step if you don't know [Git version control system][git]. However, if you
    would like to have your service integration maintained as a part of the Nuvola Player project
    and available in the Nuvola Player repository, you will increase maintenance burden of the
    project, because somebody ([*me*][me]) will have to create Git repository from tar.gz archive of your
    service integration anyway.
    
    See [Git tutorial](https://try.github.io/levels/1/challenges/1).
    
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git init .
        git add metadata.json integrate.js
        git commit -m "Initial commit"

Create metadata file
====================

**Metadata file contains basic information about your service integrations.** It uses
[JSON format](http://en.wikipedia.org/wiki/JSON) and it's called ``metadata.json``.
Let's look at the example:

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
    separate words, e.g. `google-play` for Google Play Music, `8tracks` for 8tracks.com.
    (Nuvola Player 2 required the id must be same as the directory name of the service
    integration, but Nuvola Player 3 doesn't have this limitation.)

`name`

:   Name of the service (for humans), e.g. "Google Play Music".

`version_major`

:   Major version of the integration, must be an integer > 0. You should use
    `1` for an initial version. This number is increased, when a major change occurs.

`version_minor`

:   A minor version of service integration, an integer >= 0. This field should
    be increased when a new release is made.
    
`maintainer_name`

:   A name of the maintainer of the service integration.

`maintainer_link`

:   A link to a page with contact to maintainer (including `http://` or `https://`) or an email
    address prefixed by `mailto:`.

`api_major` and `api_minor`

:   A required version of JavaScript API, currently ``3.0``.

``categories``

:   [Application categories](http://standards.freedesktop.org/menu-spec/latest/apa.html) suitable
    for the web app. It is used to place a desktop launcher to proper category in applications menu.
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

**The integration script is the fundamental part of the service integration.** It's written in
JavaScript and called ``integrate.js``. This script is called once at start-up of the web app to
perform initialization of the main process (covered in [the guide]({filename}guide.md)) and again
in the web page rendering process every-time a web page is loaded in the web view. Let's look at the
next sample integration script that doesn't actually do much, but will be used as a base for further
modifications.

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

Lines 2-22

:   Copyright and license information. While you can choose any license for your work, it's
    recommended to use the license of Nuvola Player as shown in the example.

Line 25

:   Use [strict JavaScript mode][JS_STRICT] in your scripts.

Lines 27-28 and 86

:   Use [self-executing anonymous function][JS_SEAF] to create closure with Nuvola object.
    (Integration script are executed with ``Nuvola`` object bound to ``this``).

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

Launch your service integration and a new window will be opened with the test service. First of all,
show **developer's sidebar** (menu Application → Show sidebar → select "Developer" in the right 
sidebar), then enable **WebKit Web Inspector** (right-click the web page anywhere and select
"Inspect element").

![Show sidebar]({filename}/images/guide/show_sidebar.png)
![Inspect element]({filename}/images/guide/inspect_element.png)
![WebKit Web Inspector]({filename}/images/guide/webkit_web_inspector.png)

You can also launch your service integration with id `test-integration` directly.

    nuvolaplayer3 -D -A ~/projects/nuvola-player -a test-integration

Playback state and track details
================================

The first task of your service integration is to **extract playback state and track details from the
web page** and provide them to the media player component. There are two ways how to extract playback
state and track details:

 1. Use [Document Object Model][DOM] to get information from the HTML code of the web page.
 2. Use JavaScript API provided by the web page if there is any.

[DOM]: https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model

The first way is more general and will be described here. The folowing methods are useful:

  * [document.getElementById](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementById) -
    look-up an element by ``id`` attribute
  * [document.getElementsByName](https://developer.mozilla.org/en-US/docs/Web/API/Document.getElementsByName) -
    look-up elements by ``name`` attribute
  * [document.getElementsByClassName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByClassName) -
    look-up elements by ``class`` attribute
  * [document.getElementsByTagName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByTagName) -
    look-up elements by tag name (e.g. ``a``, ``div``, etc.)
  * [document.querySelector](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelector) -
    look-up the first element that matches provided [CSS selector][B1]
  * [document.querySelectorAll](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelectorAll) -
    look-up all elements that match provided [CSS selector][B1]

[B1]: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Getting_Started/Selectors

Playback state
--------------

Looking at the code of a web page shown in the picture bellow, the code to extract playback state
might be.

```js
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

The second responsibility of a service integration is to **manage media player actions**:

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

!!! danger "Always test playback actions"
    You should click action buttons in the developer's sidebar to be sure they are working as expected.

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add integrate.js
        git commit -m "Add player actions handling"

TODO: Advanced - custom actions.

What to do next
===============

Supposing you have followed this tutorial, you have enough knowledge to create your own service
integration. If you would like to have your service integration maintained as a part of Nuvola
Player project and distributed in Nuvola Player repository, you have to follow
[Service Integration Guidelines]({filename}guidelines.md)

If you have **finished your service integration**, the next step is to
[distribute]({filename}distribute.md) it.


[git]: http://git-scm.com/
[me]: http://fenryxo.cz
[JS_STRICT]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/Strict_mode
[JS_SEAF]: http://markdalgleish.com/2011/03/self-executing-anonymous-functions/
