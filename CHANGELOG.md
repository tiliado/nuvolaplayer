Nuvola Apps Changelog
=======================

  * Release announcements for users are posted to [Nuvola News blog](https://medium.com/nuvola-news)
    and social network channels.
  * Developers, maintainers and packagers are supposed to subscribe to
    [Nuvola Devel mailing list](https://groups.google.com/d/forum/nuvola-player-devel)
    to receive more technical announcements and important information about future development.

Release 4.11.0 - May 8th, 2018
------------------------------

### Changes for Users

  * [Nuvola Adds Detection of Headphones and Changes Approach to GTK Theming](https://medium.com/nuvola-news/nuvola-adds-detection-of-headphones-and-changes-approach-to-gtk-theming-274cab6772fe):
    Nuvola can detect when **headphones are (un)plugged** and mute, pause or resume playback accordingly.
    Theming has changed: **Greybird** is used as a fallback theme instead of Adwaita, and Nuvola no longer bundles
    other GTK+ themes but embraces Flatpak **GTK+ theme extensions** instead.
  * [Nuvola Updates 8tracks, Bandcamp, Google Play Music, and Google Calendar](https://medium.com/nuvola-news/nuvola-4-10-23-325c54a9d494):
    Flatpaks of **8tracks, Bandcamp, and Google Play Music**were updated to use Chromium-based backend for music
    playback without Flash plugin. **Google Calendar** also uses Chromium engine for better performance and desktop
    notifications instead of web app alerts.
  * [Nuvola Supports Ubuntu 18.04; Updates OwnCloud Music, Plex Music, Pocket Casts, and SiriusXM](https://medium.com/nuvola-news/nuvola-4-10-29-784f90063b44):
    Flatpaks of **OwnCloud Music, Plex Music, Pocket Casts, and SiriusXM** were updated to use Chromium-based backend
    for music playback without Flash plugin and to improve desktop integration features such as a track progress bar
    and volume slider. [Installation instructions](https://nuvola.tiliado.eu/nuvola/ubuntu/bionic/) were updated
    for **Ubuntu 18.04 LTS**.
  * [Nuvola Updates Amazon Cloud Player, BBC iPlayer & Jupiter Broadcasting; Supports Fedora 28](https://medium.com/nuvola-news/nuvola-updates-amazon-cloud-player-bbc-iplayer-jupiter-broadcasting-supports-fedora-28-38c809a08639):
    Flatpaks of** Amazon Cloud Player, BBC iPlayer & Jupiter Broadcasting **— all maintained by Andrew Stubbs — were
    updated to use Chromium-based backend for music playback without Flash plugin whenever possible.
    [Installation instructions](https://nuvola.tiliado.eu/nuvola/ubuntu/bionic/) were updated for **Fedora 28**,
    and **Nuvola Runtime** received a few tweaks.

### Changes for Script Maintainers

  * New utility function `Nuvola.queryText()`
    ([doc](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html#Nuvola.queryText))
    used to query an element by a CSS selector expression and return text content or null.
  * New utility function `Nuvola.queryAttribute()`
    ([doc](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html#Nuvola.queryAttribute))
    used to query an element by a CSS selector expression and return its attribute or null.
  * New utility function `Nuvola.setInputValueWithEvent()`
    ([doc](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html#Nuvola.setInputValueWithEvent))
    used to set the value of an input element and then emit an`input` event.
  * New utility function `Nuvola.exportImageAsBase64()`
    ([doc](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html#Nuvola.exportImageAsBase64))
    used to load and export an image as base64 data URI, e.g., in the case of `blob://` resources.
  * The Chromium-based backend now supports URL filtering for external links, which is more powerful than that of
    WebKitGTK backend, e.g., it can detect JavaScript redirects in initially empty pop-up windows.
  * Developer tools add the WebView sidebar to retrieve and change the dimensions of the web view or to take a snapshot.
    It will be used to provide
    [AppStream metadata with per-app screenshots](https://github.com/tiliado/nuvolasdk/issues/5)
    to be shown in GNOME Software, for example.
  * Nuvola ADK includes [Standard JavaScript code style checker](https://standardjs.com/). You can use the `standard`
    command to check the style of your script or use `standard --fix` to convert it.
  * [NuvolaKit JavaScript API Reference](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html)
    was updated with new symbols and
    [changelogs](https://tiliado.github.io/nuvolaplayer/development/apps/api_reference.html#x-changelog-4-11)
    were added to track changes more easily.
  * Nuvola SDK calculates a micro version number from git as the number of commits from the last tag and adds it to
    `metadata.json`. The micro version number is shown in the About dialog.
  * Nuvola SDK uses two spaces for the indentation of JSON files.

### Changes for Third-Party Packagers

  * Nuvola can still be
    [built without the Chromium-based backend](https://github.com/tiliado/nuvolaruntime/blob/master/BUILD.md#web-engines).
    Please let us know whether you still need that possibility or the WebKitGTK-based backend can be removed.
  * Vala ≥ 0.40.4 is required and all compatibility issues with Valac 0.40 were fixed.
    [[GitHub 1](https://github.com/tiliado/diorite/issues/19), [GitHub 2](https://github.com/tiliado/diorite/issues/23)]
  * New dependencies: libpulse and libpulse-mainloop-glib.
  * Canonical’s appindicator3 was replaced with a better maintained fork (libayatana-appindicator3) from
    [Ayatana Indicators project](https://ayatanaindicators.github.io/).
  * The WebKitGTK+ VAPI patch was dropped.
  * WAF build system was upgraded to 2.0.6.
  * Build instructions were updated and moved to a`BUILD.md` file
    [[GitHub](https://github.com/tiliado/nuvolaruntime/blob/master/BUILD.md#web-engines)].
  * Another batch of scripts was ported to use the Chromium-based backend: 8tracks, Bandcamp, Google Calendar,
    OwnCloud Music, Plex Music, Pocket Casts, SiriusXM, Amazon Cloud Player, BBC iPlayer, and Jupiter Broadcasting.
    If you still support only the WebKitGTK-based backend, you can try to remove `Chromium[] Feature[MSE]` flags from
    their requirements and add `Feature[Flash]` when necessary. However, this should be done on a case-by-case basis
    and only after careful testing. We do not test and support these modifications though.

Release 4.10.0 - March 4th, 2018
--------------------------------

New features:

* Nuvola introduces a new experimental backend based on Chromium Embedded Framework, which facilitates a switch to audio
  playback without Flash plugin. At present, only Spotify, Deezer, YouTube, Mixcloud, and BBC iPlayer use the new
  engine, mostly because these scripts simply does not work with the old WebKitGTK backend. However, the goal of the
  project is to eventually port all scripts from Flash plugin to HTML5-Audio-based playback.

Enhancements:

* **Amazon Cloud Player 5.6** by Andrew Stubbs: Updated album name extraction, added thumbs up/down actions and fixed
  compatibility with CEF backend.
* **BBC iPlayer 1.4** by Andrew Stubbs: Update live TV & radio integration; fixed compatibility with CEF backend.
* **Deezer 2.8** by Jiří Janoušek: Switched to HTML5 Audio playback instead of the Flash plugin; fixed
  "Add to Favorite tracks" action.
* **Micxloud 4.1** adopted by Jiří Janoušek: Ported to support the new interface and added CEF backend requirement.
* **Spotify 3.0** adopted by Jiří Janoušek: Updated to support new Spotify web player. Requires CEF backend.
* **YouTube 2.0** adopted by Jiří Janoušek: Fixed metadata parsing and ported to use HTML5 Audio/Video.
  Requires CEF backend.

Under the hood:

* `Nuvola.parseTimeUsec` now supports negative time specs.
* Increased requirements: Vala >= 0.38.4.
* New mandatory dependency: libarchive >= 3.2
* New optional dependencies: ValaCEF (`--no-cef`), Vala linter (`--no-vala-lint`).
* Source code was refactored to use a united coding style which is checked with Vala linter.
* Some configure options were renamed (e.g. `--noxxx` → `--no-xxx`)
* GIR generation is now optional, you can pass `--no-gir` to disable it.
* Welcome screen is now shown from App Runner process instead of the Nuvola Service process, which makes start-up
  faster.
* App Runner is now installed as `bin/nuvolaruntime` and can be invoked independently on Nuvola Service. However, some
  features are not available if the service cannot be launched via DBus activation.
* Nuvola Service lost most of command line parameters and cannot be used to launch scripts with `nuvola -a ID`. Use
 `nuvolaruntime` instead.
* The default unique id is now `eu.tiliado.WebRuntime`, which is used consistently.
* Test scripts from `web_apps` directory are no longer installed. You may install them manually if you deem it
  necessary.

Release 4.9.0 - December 17th, 2017
-------------------------------

Nuvola 4.9.0 is mostly a maintenance release as most of energy is invested in the Chromium port of Nuvola and
the development of other features has slowed down. The current status of this ambitious effort will be described
in a separate announcement.

Enhancements:

  * **URL entry widget** was added: Press Ctrl+L or click the *gear menu* button → *Load URL* to display/change
    the current URL.
  * Updated script: **Yandex Music 1.5** was adopted by Aleksey Zhidkov and enhanced with an integrated Like button.
    An album art fix by Alexander Konarev has been also incorporated.
    Issue: tiliado/nuvola-app-yandex-music#2, tiliado/nuvola-app-yandex-music#10.
  * Updated script: **SiriusXM 1.4** by Jiří Janoušek. Metadata parsing adapted to recent SiriusXM changes.
  * Updated script: **BBC iPlayer 1.3** by Andrew Stubbs. Fixed integration of radio shows, added integration of
    progress bar, volume bar and skip action.
  * New script: **NPR One 1.0** by Jiří Janoušek.
  * Page **loading indicator** was added. Issue: tiliado/nuvolaruntime#229
  * If Bumblebeed is detected, Nuvola assumes that the integrated Intel graphics card is the primary and skips
    unnecessary checks for an NVidia flatpak driver. Issue: tiliado/nuvolaruntime#380
  * Various fixes regarding VDPAU & VA-API drivers. Issue: tiliado/nuvolaruntime#380

Under the hood:

  * WebKitGTK >= 2.18.0 is required.
  * If Nuvola is told that WebKitGTK supports MSE, it checks whether it is so and aborts otherwise.
    Don't use `--webkitgtk-supports-mse` if it isn't true.
  * Fixed various memory leaks.
  * Ongoing optimizations to replace synchronous IPC calls with asynchronous variants.
  * [ValaCEF project](https://github.com/tiliado/valacef) has been created to provide Nuvola with Vala bindings
    for Chromium Embedded Framework (CEF).

Release 4.8.0 - September 29th, 2017
--------------------------------

New Features:

  * New script: **Pocket Casts** by Jiří Janoušek. Pocket Casts is the only podcatcher you’ll ever need. Listen to your
    favorite shows in one place, keep in sync progress across various devices, find great new content with curated
    featured podcasts, currently trending podcasts and much more. Now also with desktop integration provided by Nuvola.
  * Updated script: **Groove Music script 2.0** by Joel Cumberland works again in Nuvola after being ported to use Media
    Source Extension instead of Flash plugin.
  * Updated script: **Amazon Cloud Player script 5.5** by Andrew Stubbs integrates a track progress bar and volume
    controls.
  * Updated script: **Google Play Music script 6.0** by Jiří Janoušek uses new asynchronous API to improve
    responsiveness and reduce lags, but also drops support for Nuvola 4.7 and older.

Discontinued Features:

  * **Spotify script** is temporarily unsupported until Nuvola is ported to Chromium Embedded framework because
    Spotify dropped support for WebKit browsers (including Nuvola and Safari).
  * **Yandex Music** script is currently orphaned and needs a new maintainer. The script is still shipped with
    Nuvola 4.8 but may be removed in the future unless somebody adopts it. If anyone is interested, please get in touch
    with me at [Nuvola Devel mailing list](https://groups.google.com/d/forum/nuvola-player-devel).

News for Script Maintainers:

  * Asynchronous variants of various JavaScript API calls were introduced deprecating original synchronous methods.
    The async methods return
    [a Promise object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises),
    which is used to resolve the result of the async operation.
  * List of async methods: Notifications.isPersistenceSupportedAsync, Actions.isEnabledAsync, Actions.getStateAsync,
    Core.getComponentInfoAsync, Core.isComponentLoadedAsync, Core.isComponentActiveAsync,
    KeyValueStorage.setDefaultAsync, KeyValueStorage.hasKeyAsync, KeyValueStorage.getAsync
    and KeyValueStorage.setAsync.
  * New function: Nuvola.logException to log exceptions to terminal.
  * JavaScript API reference now supports new annotations such as "Deprecated since", "Available since" and
    "asynchronous" function.

Under the Hood:

  * Nuvola uses new IPC API from Diorite 4.8 and replaced a lot of synchronous IPC calls between WebWorker and
    AppRunner processes with asynchronous variants. This should improve the performance of the WebKit WebProcess,
    reduce lags and prevent occasional deadlocks. However, scripts must use the newly-introduced async JavaScript API
    to reach the full potential. Google Play Music is the first one.

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
