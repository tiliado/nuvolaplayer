Nuvola Build Instructions
=========================

Branding
--------

To avoid a violation of *Nuvola Apps Runtime™* trademark, the default branding is set to *Web Apps Runtime*.
You **should not** set it to *Nuvola Apps Runtime* without our permission. You may, however, use any branding that does
not violate the trademark.

To change branding, pass `--branding=NAME` to `waf configure`, where `NAME` is used to construct paths to relevant
branding files.

### File branding/NAME.json

A file in JSON format. All keys are optional.

  * "name": The name of your Nuvola derivative, e.g. "Cloud Apps".
  * "help_url": The web page to be opened when users activates a Help menu item or command. It should provide
    basic documentation.
    [Default page](https://github.com/tiliado/nuvolaplayer/wiki/Unofficial).
  * "requirements_help_url": The web page to be opened when system fails to satisfy requirements of a particular app.
    It should provide information on how to install missing requirements (e.g. Adobe Flash plugin).
    [Default page](https://github.com/tiliado/nuvolaplayer/wiki/Web-App-Requirements).

### File branding/NAME/welcome.xml

A file in XML-like format. A subset of HTML formatting is supported (e.g. h1, h2, p, a, i and b).
This file is shown in the Welcome tab. It should answer following questions:

  * How to find out which Nuvola apps are available and in which version?
  * Where to report bugs and how to get support?

Web App Requirements
--------------------

Individual web apps specify their requirements in the `requirements` field of the `metadata.in.json` file.
It is your responsibility to make sure you ship only the scripts whose requirements can be satisfied by
your custom Nuvola build. Otherwise, they may refuse to start.

  * **Feature[Flash]** - [Adobe Flash plugin](https://get.adobe.com/flashplayer/) is required.
  * **Feature[MSE]** - Media Source Extension feature is required. Use Chromium web engine or build
    [WebKitGTK+](https://webkitgtk.org/) with `-DENABLE_MEDIA_SOURCE=ON` and Nuvola with `--webkitgtk-supports-mse`.
  * **Feature[Widevine]** - Widevine CDM plugin. Currently supported by Chromium web engine.
  * **Codec[MP3]** - A MP3 decoder for [GStreamer](https://gstreamer.freedesktop.org/) is required.
    It should be included in the `gst-plugins-ugly` suite.
  * **Codec[H264]** - A H264 decoder for [GStreamer](https://gstreamer.freedesktop.org/) is required.
  * **WebKitGTK[X.Y.Z]** - A particular version of [WebKitGTK+](https://webkitgtk.org/) is required.
  * **Chromium[X.Y.Z]** - A particular version of Chromium web engine is required.

Web Engines
-----------

Nuvola can be built with two web engines: **WebKitGTK** (default) and **Chromium Embedded Framework (CEF)**
(can be disabled with `--no-cef` configure option). While the Chromium engine is optional, bear in mind that
**some websites no longer work with the old WebKitGTK backend** (Spotify, YouTube, Mixcloud) because they dropped
Flash-based player and require HTML5 Audio with MSE or even Widevine DRM plugin.

The goal of Nuvola is to switch all scripts from Flash to HTML5 Audio sooner then we are forced to by the websites
dropping Flash player. That's why some scripts (e.g. Deezer) already depend on CEF while Flash-based playback is still
possible. If you are stuck with the WebKitGTK backend, you can try to set their requirements back to `Feature[Flash]`.
This should be done on a case-by-case basis and after careful testing.

Dependencies
------------

  * [Python 3](http://python.org) >= 3.4
  * [Vala](https://wiki.gnome.org/Projects/Vala) >= 0.40.4 && < 0.41.
    If you use Vala >= 0.41, modify `wscript` and check that the `vapi/*.patch`
    patches still apply cleanly.
  * [Diorite library](https://github.com/tiliado/diorite) (version number is in sync with Nuvola)
  * [glib-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.52.0
  * [gio-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.52.0
  * [gobject-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.52.0
  * [gtk+-3.0](http://www.gtk.org/) >= 3.22.0
  * [gdk-3.0](http://www.gtk.org/) >= 3.22.0
  * [gdk-x11-3.0](http://www.gtk.org/) >= 3.22.0
  * [x11](http://www.x.org/wiki/) >= 0.5
  * [json-glib-1.0](https://wiki.gnome.org/Projects/JsonGlib) >= 0.7
  * [webkit2gtk-4.0](http://webkitgtk.org/) >= 2.18.0
  * [javascriptcoregtk-4.0](http://webkitgtk.org/) >= 2.18.0
  * [libnotify](https://git.gnome.org/browse/libnotify/) >= 0.7
  * [gstreamer](https://gstreamer.freedesktop.org/) >= 1.8.3 (>= 1.12 for MSE)
  * [libdri2](https://github.com/robclark/libdri2) >= 1.0.0
  * [libdrm](https://dri.freedesktop.org/libdrm/) >= 2.2
  * libuuid
  * libsecret-1 >= 0.16
  * libarchive >= 3.2
  * g-ir-compiler
  * [valalint](https://github.com/tiliado/valalint) or configure with `--no-vala-lint`
  * [standardjs](https://standardjs.com) or configure with `--no-js-lint`
  * [ValaCEF](https://github.com/tiliado/valacef) or configure with `--no-cef`
  * unity >= 3.0 or configure with `--no-unity`
  * dbusmenu-glib-0.4 >= 0.4 or configure with `--no-appindicator`
  * libayatana-appindicator3-0.1 >= 0.4 or configure with `--no-appindicator`
  * optional [engine.io-client](https://github.com/socketio/engine.io-client) >= 3.1.0
    (installed as /usr/share/javascript/engine.io-client/engine.io.js)
  * optional [unit.js](https://github.com/unitjs/unit.js/releases/tag/v2.0.0) 2.0.0
    (installed as /usr/share/javascript/unitjs/unit.js) for JavaScript unit tests
    (included in the test service - web_apps/test subdirectory)


Build & Install Nuvola Runtime
------------------------------

### Waf Build System

Nuvola uses [waf build system](https://waf.io). You are supposed to use the waf binary bundled with
Nuvola's source code. The build script `wscript` may not be compatible with other versions. If you manage
to port wscript to a newer stable waf release, you may provide us with patches to be merged once we decide
to update our waf binary. Meantime, you can carry them downstream.

To find out what build parameters can be set run ./waf --help

### Build

    $ ./waf --help
    $ ./waf configure [--prefix=...] [--libdir=...] [--branding=...] [--no-...]
    $ ./waf build

### Install


    # ./waf install [--destdir=...]
    # /sbin/ldconfig
    # gtk-update-icon-cache ...
    # gtk-update-icon-cache-3.0 ...

### Uninstall

    # ./waf uninstall [--destdir=...]

Build & Install Nuvola Apps
---------------------------

Individual Nuvola apps are maintained in `nuvola-app-XXX` GitHub repositories under
[Tiliado organization](https://github.com/tiliado).
They use [Nuvola SDK](https://github.com/tiliado/nuvolasdk#create-new-project). Please refer to
the [Build a Project Using Nuvola SDK](https://github.com/tiliado/nuvolasdk#build-a-project-using-nuvola-sdk)
page in order to obtain information about dependencies and installation instructions.
