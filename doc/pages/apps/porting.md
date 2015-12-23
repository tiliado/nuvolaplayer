Title: Porting from Nuvola Player 2 to Nuvola Player 3

This guide describes porting of service integrations from Nuvola Player 2 to Nuvola Player 3.

Prepare development environment
===============================

[Tiliado organization account](gh>tiliado) at Github.com might already contain a repository for
your service integration you can base your work on. Names of the repositories of service
integrations start with ``nuvola-app-``. If there is no repository for your service integration,
follow steps described in section Prepare development environment of the
[service integrations tutorial](:apps/tutorial.html).

If you are not familiar with the
[Git version control system][git], you can check
[Git tutorial](https://try.github.io/levels/1/challenges/1) and
[Pro Git Book](http://git-scm.com/book).

Port metadata
=============

**Metadata file contains basic information about your service integration.** While Nuvola Player 2
read metadata from a INI-style file ``metadata.conf``, Nuvola Player 3 uses
a [JSON file](http://en.wikipedia.org/wiki/JSON) ``metadata.json``.
See [sample metadata file in tutorial](:apps/tutorial.html#create-metadata-file).

Mapping of old ``metadata.conf`` fields to the new ``metadata.json`` fields:

:   
      * ``id`` - it can now contain letters ``a-z``, digits ``0-9`` and dash ``_`` to separate
        words, e.g. ``google_play_music`` for Google Play Music, ``8tracks`` for 8tracks.com.
        The id can differ from the directory name of the service integration.
      * ``name`` - unchanged
      * ``version`` - increase major version number by one
      * ``version_minor`` - set minor version number to 0
      * ``home_page`` - name changed to ``home_url``
      * ``sandbox_pattern`` - name changed to ``allowed_uri``, optional field. See the article
        [URL Filtering (URL Sandbox)](:apps/url-filtering.html).
      * ``maintainer_name`` - unchanged
      * ``maintainer_link`` - if you want to have your service integration shipped with Nuvola
        Player, you must use link to your Github profile. (See
        [guidelines](:apps/guidelines.html).)
      * ``flash_plugin`` - no longer used (Flash plugin is currently enabled by default)
      * ``api_major`` and ``api_minor`` - you have to use API >= 3.0
      * ``requirements_specified`` - no longer used

The extra ``metadata.json`` fields not present in ``metadata.conf``

:     * ``categories``: Application categories suitable for the web app. It is used to place a desktop
        launcher to proper category in applications menu. Nuvola Player services should be in
        "AudioVideo;Audio;".

Port integration script
=======================

File name of the integration script has changed to ``integrate.js`` and the Nuvola Player 3
JavaScript API is completely different. You should
[create a new service integration script from scratch](:apps/tutorial.html#create-integration-script)
taking into account following porting notes:

  * You can reuse code of your ``update()`` method dealing with extraction of track details from
    the web page.
  
  * ``Nuvola.bind()`` function is gone, because Nuvola Player 3 depends on a young enough WebKitGtk
    library that supports [Function.prototype.bind()](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/bind).

  * It is necessary to explicitly initialize [MediaPlayer](apiref>Nuvola.MediaPlayer) component:
    ``var player = Nuvola.$object(Nuvola.MediaPlayer);``
    
  * Playback states are in an enumeration [Nuvola.PlaybackState](apiref>Nuvola.PlaybackState)
    instead of constants ``Nuvola.STATE_NONE/STATE_PAUSED/STATE_PLAYING``.
    
  * The replacements for ``Nuvola.updateSong()`` are methods
    [player.setPlaybackState()](apiref>Nuvola.MediaPlayer.setPlaybackState) and
    [player.setTrack()](apiref>Nuvola.MediaPlayer.setTrack).

  * The replacements for ``Nuvola.updateAction()`` are methods
    [player.setCanPause()](apiref>Nuvola.MediaPlayer.setCanPause),
    [player.setCanPlay()](apiref>Nuvola.MediaPlayer.setCanPlay),
    [player.setCanGoPrev()](apiref>Nuvola.MediaPlayer.setCanGoPrev) and
    [player.setCanGoNext()](apiref>Nuvola.MediaPlayer.setCanGoNext).

  * The replacement for ``Nuvola.onMessageReceived`` is a signal
    [Actions::ActionActivated](apiref>Nuvola.Actions%3A%3AActionActivated). Player action
    names are defined in an enumeration [Nuvola.PlayerAction](apiref>Nuvola.PlayerAction). Tutorial
    describes how to use this new API.
  
  * Actions ``Nuvola.ACTION_THUMBS_UP/ACTION_THUMBS_DOWN/ACTION_LOVE`` are not defined by default,
    but you can create them using [Custom Actions API ](:apps/custom-actions.html).


Port settings
=============

While Nuvola Player 2 uses a settings script ``settings.js``, Nuvola Player 3 uses ``integrate.js``
also for settings management. See article
[Initialization and Preferences Forms](:apps/initialization-and-preferences-forms.html)
for details how to get user input and manage preferences and article
[Web apps with a variable home page URL](:apps/variable-home-page-url.html) for
use cases of Initialization and Preferences Forms to allow user specify a custom home page url.

Distribute your work
====================

While service integrations in Nuvola Player 2 are maintained in the same repository as the Nuvola Player itself,
service integrations for Nuvola Player 3 are more independent and are maintained in separate repositories.
See article [Distribute Service Integration](:apps/distribute.html) for details.

[TOC]

[git]: http://git-scm.com/
