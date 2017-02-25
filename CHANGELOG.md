Nuvola Player Changelog
=======================

Release 3.0.6 - February 25th, 2017
-----------------------------------

This is a bug fix release addressing following issues:

  * NuvolaPlayer/SoundCloud 3.0.5 menu item 'Unknown application name'. Issue: tiliado/nuvolaplayer#301
  * SoundCloud 3.0.5 crashes when started from a Ubuntu Launcher. Issue: tiliado/nuvolaplayer#302
  * Web App scripts should provide own desktop files. Issue: tiliado/nuvolaplayer#263

In addition, Nuvola 3.0.6 no longer supports scripts not built with
the [Nuvola SDK](https://github.com/tiliado/nuvolasdk). This backward incompatible change is necessary
for a smooth transition to Nuvola 4.0.
  
Release 3.0.5 - February 18th, 2017
-----------------------------------

This is a bug fix release addressing following issues:

  * False positive "Too many flash plugins" has been fixed.
    Issue: tiliado/nuvolaplayer#159
  * Repeated Runner: prefix in debugging output has been suppressed.
    Issue: tiliado/nuvolaplayer#265
  * Nuvola is compatible with scripts built with the Nuvola SDK build system
    providing own desktop launchers. Moreover, scripts without the desktop files
    are deprecated and might not function properly in the next release.
    Issue: tiliado/nuvolaplayer#263
  * The usage of the old Tiliado API has been removed along with the donation bar.
  * Frequent deadlocks of the web rendering process of recent versions of WebKitGTK
    have been addressed.
    Issue: tiliado/nuvolaplayer#279
  * A workaround addressing a bug in older graphics drivers is now disabled with recent versions
    of WebKitGTK as it is no longer necessary and causes huge CPU usage under Wayland.
    Issue: tiliado/nuvolaplayer#260

Release 3.0.4 - September 17th, 2016
------------------------------------

This is a bug fix release addressing following issues:

  * A crash under Wayland session was fixed (GDK_BACKEND set to x11).
    Issue: tiliado/nuvolaplayer#181
  * The accelerated compositing mode is disabled with WebKitGTK < 2.13.4 due to a WebKitGTK+ bug
    that may crash systems with certain graphic cards.
    Upstream: https://bugs.webkit.org/show_bug.cgi?id=126122
    Issue: tiliado/nuvolaplayer#245
  * A non-functional local-storage-directory setting was removed as it produced a console warning.
  * The design of the Welcome screen was improved.
  * It is possible to disable media keys in the Preferences dialog.
    Issue: tiliado/nuvolaplayer#237

Release 3.0.3 - June 4th, 2016
---------------------------------

This is a bug fix release addressing following issues:

  * A wrong implementation of the CanPlay and CanPause flags of the Media Player Remote Interface Specification (MPRIS)
    was fixed resolving issues with Unity Sound Indicator as a result. Issue: tiliado/nuvolaplayer#224
  * Console warnings produced when notifications component were being disabled were fixed.
    Issue: tiliado/nuvolaplayer#227
  * Initialization of the Web Worker process is more robust. Blank incompletely loaded and improperly initialized
    web pages should no longer occur.
  * Notifications API is no longer called if it is disabled as it is obviously not functional and produces only console
    warnings. Issue: tiliado/nuvolaplayer#227
  * JavaScript API got new Nuvola.VERSION and Nuvola.API_VERSION constants for scripts to be able to detect whether
    currently running instance is NP 3.0.3 or higher and it is possible to run code which caused improper Web Worker
    initialization in older versions.
  * A version of the LibSoup library is shown in `nuvolaplayer3 --version` and in the About dialog. In addition,
    JavaScript API got Nuvola.LIBSOUP_VERSION, Nuvola.LIBSOUP_MAJOR, Nuvola.LIBSOUP_MINOR and LIBSOUP_MICRO constants
    for script to detect not new enough versions and to recommend upgrading. Issue: tiliado/nuvola-app-spotify#13

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
