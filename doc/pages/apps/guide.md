Title: Service Integrations Guide
Date: 2014-07-22 19:41 +0200


**NOTE: This guide applies to Nuvola Player 3 that is currently in development.**

This guide describes creation of a new service integration for Nuvola Player 3 from scratch. The
goal is to write an integration script for *Test service* shipped with Nuvola Player

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


Create metadata file
====================

Run Nuvola Player 3 from terminal with following command:
    
    nuvolaplayer3 -D -A ~/projects/nuvola-player

You will see an empty list of services. That's fine, because we told Nuvola Player to load service
integrations only from directory `~/projects/nuvola-player`.

![Empty list of service integrations]({filename}/images/guide/empty_app_list.png)

You will also see an error message in terminal that tells you Nuvola Player failed to load your
service integration because of invalid metadata file.

    :::text
    [Master:WARNING  Nuvola] webappregistry.vala:169: Unable to load app from
    /home/fenryxo/projects/nuvola-player/test-integration: Invalid metadata file
    '/home/fenryxo/projects/nuvola-player/test-integration/metadata.json'.
    Expecting a JSON object, but the root node is of type '(null)'

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

And some optional fields:

`home_url`

:   Home page of your service. The test integration service uses `nuvola://home.html` that refers to
    file  `home.html` in the service's directory. You will use real homepage later in your own
    service integration (e.g. `https://play.google.com/music/` for Google Play Music).
    
    If your service has multiple home pages (e.g. Amazon Cloud Player has some national variants)
    or the address has to be specified by user (e.g. address of users Logitech Media Server or
    Owncloud instance), you have to use custom homepage resolution hooks (TODO) and omit this field
    in metadata.json.

Run `nuvolaplayer3 -D -A ~/projects/nuvola-player` again and you will see a list with one service :-)

![A list with single service integration]({filename}/images/guide/app_list_one_service.png)

If you launch your service, either from the list of services or with command
`nuvolaplayer3 -D -A ~/projects/nuvola-player -a test-integration`, you will see an error
dialog saying "Invalid home page URL - The web app integration script has provided an empty home
page URL." and the app will quit. That because Nuvola Player makes no assumption about where the
homepage URL is stored and expect service integration script provides this information explicitly
during a app runner initialization phase.

App Runner and Web Worker
=========================

Nuvola Player uses two processes for each service (web app):

  * **App Runner process** that manages user interface, desktop integration components and
    a life-cycle of the WebKitGtk WebView.
 
  * **Web Worker process** is created by WebKitGtk WebView and it's the place where the web
    interface of a web app lives, i.e. where the website is loaded.

**On start-up**, Nuvola Player executes ``integrate.js`` script in the App Runner process to perform
initialization of the web app and then executes it again in the WebWorker process everytime a web
page is loaded in it to integrate the wep page.

App Runner Process
==================

Let's create base `integrate.js` script with following content:

    #!js
    /*
     * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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
    
    var WebApp = Nuvola.$WebApp();
    
    WebApp.start();
    
    })(this);  // function(Nuvola)

``Nuvola.$WebApp()`` creates new WebApp prototype object derived from the `Nuvola.WebApp`
prototype. The `Nuvola.WebApp` contains handy default handlers for initialization routines,
so you don't have to process them, but it's good to know they exist and you can override them
if your web app requires more magic ;-)

Initialization routines
-----------------------

On start-up, Nuvola Player performs following actions:

 1. App Runner emits the Nuvola.Core::InitAppRunner signal that is processed by
    Nuvola.WebApp._onInitAppRunner handler by default. This default handler does nothing, feel free
    to override it.
    
      * TODO: Advanced - Web apps with user-specified home page URL
      * TODO: Advanced - Web app with a separated variants with different home page URL
 
 2. App Runner emits the Nuvola.Core::LastPageRequest signal that is processed by
    Nuvola.WebApp._onLastPageRequest handler by default. This handler returns URL
    of the last visited page or null. If the URL is valid, it is loaded in the Web Worker process
    and initialization is finished.
    
      * TODO: Advanced - Specify which URL should not be used as a last visited page

 3. If the last visited page is null, App Runner emits the Nuvola.Core::HomePageRequest signal
    that is processed by Nuvola.WebApp._onHomePageRequest handler by default. This handler returns
    URL specified in the "home_url" field of `metadata.json`. If the URL is valid, it is loaded in
    the Web Worker process and initialization is finished, otherwise Nuvola Player will quit with
    an error "Invalid home page URL - The web app integration script has provided an empty home
    page URL."
    
      * TODO: Advanced - Web app with user-specified home page URL
      * TODO: Advanced - Web app with a separated variants with different home page URL

Run-time events
---------------

During run-time, Nuvola Player performs following actions:

  * App Runner emits the Nuvola.Core::HomePageRequest signal to get home page URL everytime
    user activates "Go Home" action (either by keyboard shortcut, menu item, etc.)

  * App Runner emits Nuvola.Core::NavigationRequest just before navigation to a new page. That
    signal is processed by Nuvola.WebApp._onNavigationRequest handler by default and can be used
    for TODO URL filtering.
    
  * App Runner emits Nuvola.Core::UriChanged signal everytime a new page is loaded. That signal
    is processed by Nuvola.WebApp._onUriChanged handler by default which saves the URI to be later
    returned by Nuvola.Core::LastPageRequest signal handler.
