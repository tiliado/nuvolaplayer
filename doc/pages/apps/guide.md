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
integrations only from directory `~/projects/nuvola-player`. You will also see an error message
in terminal that tells you Nuvola Player failed to load your service integration because of invalid
metadata file.

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

`home_url`

:   Home page of your service. The test integration service uses `nuvola://home.html` that refers to
    file  `home.html` in the service's directory. You will use real homepage later in your own
    service integration (e.g. `https://play.google.com/music/` for Google Play Music).
    
    If your service has multiple home pages (e.g. Amazon Cloud Player has some national variants)
    or the address has to be specified by user (e.g. address of users Logitech Media Server or
    Owncloud instance), you have to use custom homepage resolution hooks (TODO).
    
