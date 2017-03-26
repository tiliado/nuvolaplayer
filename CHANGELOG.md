Nuvola Apps Changelog
=======================

Releases 3.1.x
--------------

Rolling releases.

Milestone 3.1.2 - March 26, 2017
--------------------------------

New Features:

  * Nuvola Player was renamed to Nuvola Apps as non-media player apps (Google Calendar) were enabled
    and should be fully supported in the 4.0 release.
  * Nuvola Apps are distributed as [cross-distribution flatpak builds](https://nuvola.tiliado.eu/).
    There have been a lot of changes under the hood to support this transition.
  * The `nuvolaplayer3` and `nuvolaplayer3ctl` commands are deprecated in favor of `nuvola` and `nuvolactl`.
  * WebApp scripts provide own desktop files so the unnecessary create/delete desktop launchers actions
    were removed.

Enhancements:

  * Enhanced support of HTML5 Audio and Media Source Extension (MSE), which is currently enabled only
    in the BBC iPlayer script with a custom WebKitGTK+ build.
  * Album art is downloaded with WebKit's NetworkProcess to access images that are otherwise restricted.
    Issue: tiliado/nuvolaplayer#76
  * Preferences dialog: Components tab was renamed to Features as it is more user-friendly.

Under the Hood:

  * Inter-process communication has been reworked for greater flexibility as required by the HTTP Remote Control
    feature.
  * Nuvola and individual apps are DBus-activatable.
  * The unique name has been changed to `eu.tiliado.Nuvola` and most of the resources (e.g. icons) use this name.
  * AppData/AppStream metadata have been updated.
  * The build script now honors the VAPIDIR env variable.
  * Added a script to set up Nuvola CDK environment (`setup_nuvolacdk.sh`).

Bug Fixes:

  * "Too many flash plugins" false positives. Resolve symlinks and track final paths not to count duplicates.
    Issue: tiliado/nuvolaplayer#159
  * Repeated Runner: prefix in debugging output. Issue: tiliado/nuvolaplayer#265
  * Disable LIBGL_DRI3_DISABLE workaround with WebKitGTK 2.14+ to fix performance issues.
    Issue: tiliado/nuvolaplayer#260

News for Script Maintainers:

  * Documentation has been updated and Mantainer's Guide merged into the tutorial.
  * Format requirements flag were implemented but not yet documented.
  * Web app scripts are built with Nuvola SDK.


Milestone 3.1.1 - October 30, 2016
----------------------------------

New Features:

  * Support for showing and setting track rating over MPRIS, especially in the GNOME Shell Media Player extension (git
    master version). Issue: tiliado/nuvolaplayer#204
  * The HTTP Remote Control interface to control Nuvola Player over network via an Engine.io socket.
  * The Media Player Controller web page to control Nuvola Player from any device with a web browser (e.g. a phone).
    Uses the HTTP Remote Control interface.
  * The Nuvola Controller Pebble Watchapp to control Nuvola Player from Pebble watches. Uses the HTTP Remote Control
    interface.
  * The Password Manager to store passwords from login forms in a secure keyring.

Enhancements:

  * An option to always run in background regardless a song is playing or not.
  * Better support of HTML5 Audio. It is sufficient for ownCloud Music web app but more work is still necessary to
    support Google Play Music. Issue: tiliado/nuvolaplayer#52
  * Pop-up windows are allowed to pop up a new window, which is required by the SoundCloud's log-in-via-Google feature.
    Issue: tiliado/nuvola-app-soundcloud#3
  * A hint how to edit or remove a keyboard shortcut. Issue: tiliado/nuvolaplayer#217
  * Users can disable media keys bindings in the Preferences dialog. Issue: tiliado/nuvolaplayer#237
  * Inter process communication backed has been rewritten.
  * All web app scripts have been ported to comply with the latest guidelines.

Bug Fixes:

  * Remove config option `--with-appindicator` as the AppIndicator integration is currently unmaintained.
    Issue: tiliado/nuvolaplayer#201, tiliado/nuvolaplayer#45
  * Add missing `-a/--app-id` command-line argument to the `--help` screen. Issue: tiliado/nuvolaplayer#147 
  * MPRIS implementation of CanPlay and CanPause flags has been fixed. Issue: tiliado/nuvolaplayer#224
  * Warnings when Notifications is being disabled has been removed. Issue: tiliado/nuvolaplayer#227
  * Don't use notifications API if disabled as it produces critical warnings. Issue: tiliado/nuvolaplayer#227
  * Set GDK_BACKEND to x11 not to crash under Wayland. Issue: tiliado/nuvolaplayer#181
  * Disable compositing mode in WebKitGTK < 2.13.4 as it may crash some websites. Issue: tiliado/nuvolaplayer#245

News for Script Maintainers:

  * Web app integration template has been moved to [its own repository](https://github.com/tiliado/nuvola-app-template).
  * Added information about Format Requirements Flags. Issue: tiliado/nuvolaplayer#158
  * `Nuvola.VERSION` property contains Nuvola version encoded as single integer, e.g. e.g. 30105 for 3.1.5.
  * `Nuvola.API_VERSION` property contains Nuvola API version encoded as single integer, e.g. e.g. 301 for 3.1.
  * `Nuvola.WEBKITGTK_{VERSION,MAJOR,MINOR,MICRO}` properties contain version information about WebKitGTK+ library.
  * `Nuvola.LIBSOUP_{VERSION,MAJOR,MINOR,MICRO}` properties contain version information about Soup library.
  * New API to set rating.
  * It is possible to set a user agent string via the `user_agent` field of metadata.json.
    Issue: tiliado/nuvolaplayer#91
  * It is possible to enable access to insecure content. This happens when a web page loaded over HTTPS protocol loads
    any content over HTTP protocol.
  * Developer documentation and guidelines have been updated.
  
Changes in Dependencies:

  * Increased: WebKitGTK >= 2.6.2, Valac >= 0.26.1, GLib >= 2.42.1 and GTK+ >= 3.14.5.
  * New: libuuid and libnm-(util/glib)
  
  
Release 3.0.0 - December 30, 2015
---------------------------------

Initial release of the third generation, which has been rewritten from scratch.
