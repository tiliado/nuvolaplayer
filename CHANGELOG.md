Nuvola Player Changelog
=======================

Release 3.0.1 - February 14, 2015
---------------------------------

This is a bug fix release addressing following issues:

  * Configuration option --with-appindicator was removed as AppIndicator integration is currently unmaintained.
    Issues: tiliado/nuvolaplayer#201 and tiliado/nuvolaplayer#45

  * Web app integration template was moved to [its own repository](https://github.com/tiliado/nuvola-app-template)
    to keep it up-to-date independently on Nuvola Player releases. Developer documentation was updated accordingly.

  * The `nuvolaplayer3 --help` screen now lists also the `-a/--app-id` argument used to launch a particular service.
    Issue: tiliado/nuvolaplayer#147
    
  * All pop-up windows now can pop up a new window, which is required by the SoundCloud's log-in-via-Google feature,
    for instance. Issue: tiliado/nuvola-app-soundcloud#3

Release 3.0.0 - December 30, 2015
---------------------------------

Initial release of the third generation, which has been rewritten from scratch.
