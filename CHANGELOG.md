Nuvola Apps Changelog
=======================

Release 4.7.0 - September 1st, 2017
--------------------------------

New Features:

  * New web app:  Jupiter Broadcasting by Andrew Stubbs.
  * The genuine flatpak builds offers free trial and $1/month subscription.
  * For sake of transparency, preferences dialog shows placeholders for features which were disabled by a distributor.

Bug Fixes:

  * VAAPI/VDPAU checks are not run under Wayland. Issue: tiliado/nuvolaruntime#280 Issue: tiliado/nuvolaruntime#359
  * URL sandbox was not honoured properly: Issue: tiliado/nuvolaruntime#367

News for Script Maintainers:

  * API 4.6 is required for new scripts.

Under the Hood:

  * Nuvola no longer bundles `*.vapi` files but depends on those of Valac 0.36.3. However, glib-2.0.vapi and
    webkit2gtk-web-extension-4.0.vapi must be patched to work properly (see `vapi/*.patch`). You may need to
    modify wscript if you don't use Valac 0.36. Issue: tiliado/nuvolaruntime#369
  * Valac and GLib dependencies were raised to 0.36.3 and 2.52. Issue: tiliado/nuvolaruntime#369
  * GIR XML and typelib files are generated. Introduces new dependency on g-ir-compiler.
  * There was a lot of refactoring to allow usage of Python-GObject and to support multiple web engines in future.
  * Future warning: Nuvola is likely to introduce dependency on Python 3.6.

Release 4.6.0 - 29th July, 2017
-------------------------------

New Features:

  * Start-up system checks run in parallel to decrease start-up time. In case of any problem, only a single dialog is
    shown instead of multiple error dialogs or info bars.
  * WebKitGTK+ was upgraded to 2.16.6 fixing many security vulnerabilities and rendering issue.
  * Media Source Extension (MSE) is enabled in WebKitGTK as well as in Nuvola itself. This applies only to the genuine
    flatpak builds of Nuvola. MSE is required by some web apps for Flash-free audio/video playback.
  * New web app: BBC iPlayer by Andrew Stubbs. Note that this script requires MSE and may not work with third-party
    builds of Nuvola. Issue: tiliado/nuvolaruntime#321

Bug fixes:

  * Graphics.dri2_get_driver_name() now throws error instead of an uncaught critical warning if it cannot connect to
    X Server.  Issue: tiliado/nuvolaruntime#359
  * Fixed typo in Nuvola.parseTimeUsec. Issue: tiliado/nuvolaruntime#357
  * int64 is used for track position to avoid integer overflow. Issue: tiliado/nuvolaruntime#358
    
News for Script Maintainers:

  * Developer sidebar can now change track rating.
  * Media player API documentation was updated with track rating.
  
Under the Hood:

  * New dependency: [unit.js](https://github.com/unitjs/unit.js/releases/tag/v2.0.0) 2.0.0
    (installed as /usr/share/javascript/unitjs/unit.js) is used for JavaScript unit tests
    (included in the test service - web_apps/test subdirectory).
  * Added support for org.gnome.SettingsDaemon.MediaKeys D-Bus name.
    [Upstream ticket](https://bugzilla.gnome.org/show_bug.cgi?id=781326).
  * The content of format support dialog was moved to Preferences dialog and various toggles were removed.
  * The content of bindings, models and interfaces directories was merged into components directory. 
    
Release 4.5.0 - 24th June, 2017
-------------------------------

New Features:

  * Nuvola Apps Runtime supports the integration of a progress bar and volume management. Web app scripts
    which use this feature can not only provide track length & position and current volume but also allow
    user to change that remotely, e.g. from Media Player GNOME Shell extension. At the present, only Deezer
    and Google Play Music scripts use these features but others will follow.
    Issue: tiliado/nuvolaruntime#22 Issue: tiliado/nuvolaruntime#155
  * If Nuvola Apps Runtime detect a Nvidia graphics card, it checks whether the flatpak extension with 
    corresponding graphics driver is installed. If it isn't, e.g. because of a bug in GNOME Software,
    an error message is shown to provide the user with installation instructions. Issue: tiliado/nuvolaruntime#342
  * After a lot of effort, a workaround for the instability of Flash plugin was found out and is used until
    WebKitGTK developers find a proper fix. However, it is applied only in flatpak builds because it may have
    negative impact on other WebKitGTK applications otherwise. Issue: tiliado/nuvolaruntime#354

Bug fixes:

  * Wrong command in desktop launcher was fixed. Issue: tiliado/nuvolaruntime#348
  * Fix wscript for non-git builds. Issue: tiliado/diorite#16

News for Script Maintainers:

  * `Nuvola.VERSION_MICRO` contains micro version of Nuvola Runtime.
  * `Nuvola.API_VERSION_MAJOR` and `Nuvola.API_VERSION_MINOR` are now deprecated aliases of `Nuvola.VERSION_MAJOR`
    and `Nuvola.VERSION_MINOR`.
  * Tutorial was updated to use Nuvola ADK 4.4.
  * Added documentation of web app requirement flags.
  * Added documentation of user agent quirks.
  * New API for progress bar integration.
  * New API for volume management integration.
  * New utility functions `Nuvola.encodeVersion` and `Nuvola.checkVersion`.
  * `Nuvola.triggerMouseEvent` and `clickOnElement` support relative x & y coordinates.

Under the Hood:

  * New dependencies: libdrm >= 2.2 and libdri2 >= 1.0
  * Nuvola checks whether VDPAU and VA-API drivers are installed and prints debugging information to console.
    It will show error dialog in the future though, so make sure the drivers are installed.
    Issue: tiliado/nuvolaruntime#280
  * Internal icon loading code was refactored. Legacy icon.png and nuvolaplayer3_XXX icons are no longer supported.
    eu.tiliado.NuvolaAppXxx is used everywhere. Issue: tiliado/nuvolaruntime#353

Release 4.4.0 - 27th May, 2017
------------------------------

New Features:

  * Tray icon feature can now use AppIndicator library instead of obsolete X11 tray icons. Although app indicators
    are mostly known from Ubuntu's Unity desktop, they also work in elementaryOS and GNOME Shell (with
    [AppIndicator extension](https://extensions.gnome.org/extension/615/appindicator-support)) and provide
    superior user experience. Issue: tiliado/nuvolaplayer#45
  * Users can easily clear cookies, cache and temporary files, IndexedDB and WebSQL databases and local storage
    from the Preferences dialog → tab Website Data. Issue: tiliado/nuvolaplayer#331

Enhancements:

  * Versioning scheme was changed to be more compact, e.g. 4.4.1 instead of 3.1.4-1.gabcd. Nuvola 4.0 was re-targeted
    as Nuvola 5.0.
  * Nuvola can do its own user agent quirks (i.e. to disguise itself as a different web browser) in order to work
    around web pages that doesn't work with the WebKit's user agent string. Issue: tiliado/nuvolaplayer#336
  * Flatpak builds use the latest stable WebKitGTK+ 2.16.3 bringing fixes for three security vulnerabilities as well as
    several crashes and rendering issues.

Web App Scripts:

  * Google Play Music script uses own user agent quirks to work around the malfunctioning Google sign-in web page.
    Issue: tiliado/nuvolaplayer#336

Bug fixes:

  * The build script now raises error if it is ran with Python < 3.4.
  * Fixed a bug when the menus of tray icons and dock items were not updated.
  * Nuvola now aborts when required data files are not found (e.g. in incomplete installation) rather they running
    with errors in the background.
  * Obsolete test suite has been removed. A new one will be created during ongoing modernization.
    Issue: tiliado/nuvolaplayer#335
  * Broken -L/--log-file options were removed. Issue: tiliado/nuvolaplayer#338
  * Various fixes of HTTP Remote Control feature.

Under the Hood:

  * Nuvola's filesystem namespace was changed from `nuvolaplayer3` to `nuvolaruntime`. The data dir is installed at
    PREFIX/share/nuvolaruntime, libraries were renamed to `libnuvolaruntime-*.so` and binaries to `nuvola(ctl)`.
    Users' configuration, data and cache is migrated automatically.
  * Nuvola's git repository was moved to https://github.com/tiliado/nuvolaruntime.
  * WebKitGTK+ >= 2.16.0 is required as all new API is now used unconditionally to make maintenance easier.
  * Added optional dependency on appindicator3-0.1 >= 0.4. Use `./waf configure --noappindicator` to disable
    this dependency and related functionality (Tray icon feature).
  * Nuvola no longer bundles Engine.io-client JavaScript library but expect version 3.1.0 of it located at the
    JSDIR/engine.io-client/engine.io.js (JSDIR is DATADIR/javascript unless changed with --jsdir).
    Issue: tiliado/nuvolaplayer#341
  * Nuvola no longer supports web app scripts without a desktop file.
  * Test suite was reintroduced (build/run-nuvolaruntime-tests). Issue: tiliado/nuvolaplayer#335
  * A lot of refactoring and removal of obsolete code and other improvements.
    
Milestone 3.1.3 - April 30, 2017
--------------------------------

New Features:

  * elementaryOS Loki has been added among officially supported distributions. Nuvola flatpaks contain
    a work-in-progress GTK+ 3.22 port of the elementary theme to provide elementaryOS users with a native look.
    Installation instructions and documentation have been updated accordingly.
    Issue: tiliado/nuvolaplayer#4
  * All three variants of the Arc theme have been added to Nuvola flatpaks. Issue: tiliado/nuvolaplayer/issues/318

Enhancements:

  * Ubuntu themes have been updated. Issue: tiliado/nuvolaplayer#324
  * Initial start-up of flatpak builds is faster.
  * The text of Welcome dialog was moved to the first tab of the main window because it may contain useful information.
  * WebKitGTK+ 2.16 API to set network proxy is used replacing previous legacy hacks.
  * The official builds of Nuvola are marked as "genuine flatpak builds"

Bug fixes:

  * Apps that are not media players no longer steal media keys. Issue: tiliado/nuvolaplayer#230
  * Fixed activation for Premium users. Issue: tiliado/nuvolaplayer#325
  * App menu, toolbar & menu bar handling was refactored and double app menus fixed. Issue: tiliado/diorite#4

Under the Hood:

  * Build script of Nuvola was reworked, ported to Waf 1.9.10 and supports branding. See Readme.md
    for more information.
  * Build script of Diorite was reworked and ported to Waf 1.9.10. See Diorite's Readme.md for more information.
  * Modernisation has begun. Dependencies were raised and legacy code is being removed.
  * All Python scripts require Python >= 3.4.
  * Code has been ported to Valac 0.36.
  
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
