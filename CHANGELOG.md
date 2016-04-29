Nuvola Player Changelog
=======================

Release 3.0.2 - April 29, 2016
---------------------------------

This is a bug fix release addressing following issues:

  * Added hint how to edit/remove keyboard shortcut in the Keyboard shortcuts tab of the Preferences dialog.
    Issue: tiliado/nuvolaplayer#217
  * WebView used to fail to initialize properly sometimes resulting in empty non-functional window. 
    This should not occur any more. Issue: tiliado/nuvolaplayer#207
  * WebKitGTK version information was added to the JavaScript API for web app scripts to check whether they are
    compatible and notify user if they are not. Issue: tiliado/nuvolaplayer#215
  * Ubuntu 14.04: WebKitGTK 2.8.5 packages have been uploaded to the Nuvola Player repository and Nuvola Player now uses
    this version instead the old packages from the official Ubuntu archive. this should fix various rendering and
    integration issues that happened only in Ubuntu 14.04. Issue: tiliado/nuvolaplayer#216
  * Fedora 22 and 23: Nuvola Player package also depends on the webkitgtk4-plugin-process-gtk2 package.
    Issue: tiliado/nuvolaplayer#223

Release 3.0.1 - February 14, 2016
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
