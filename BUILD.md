Nuvola Build Instructions
=========================

Branding
--------

To avoid a violation of *Nuvola Apps Runtime™* trademark, the default branding is set to *Web Apps Runtime*.
You **should not** set it to *Nuvola Apps Runtime* without our permission. You may, however, use any branding that does
not violate the trademark.

To change branding, pass `--branding=NAME` to `waf configure`, where `NAME` is used to construct paths to relevant
branding files, then `cp branding/default.json branding/NAME.json` and edit this file (it has comments, btw.).

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

Nuvola can be built with two web engines: **Chromium Embedded Framework (CEF)** and **WebKitGTK**.
While the Chromium engine is still optional (can be disabled with `--no-cef` configure option), bear in mind that
**some websites no longer work with the old WebKitGTK backend** (Spotify, YouTube, Mixcloud) because they dropped
Flash-based player and require HTML5 Audio with MSE or even Widevine DRM plugin.

In addition, most scripts are tested only with the Chromium backend and specify `Chromium[X.Y.Z]` requirement
for that reason. If you are stuck with the WebKitGTK backend, you may remove `Chromium[X.Y.Z] Feature[MSE]` requirements
to make the script run with WebKitGTK+ backend and add `Feature[Flash]` to use Flash plugin for audio playback.
However, this should be done on a case-by-case basis and after careful testing.

Dependencies
------------

  * [Python 3](http://python.org) >= 3.4
  * [Vala compiler](https://wiki.gnome.org/Projects/Vala) >= 0.42.0 && < 0.43.
    If your system contains a different version of Vala, we cannot guarantee that Nuvola builds correctly and it
    may lead to memory leaks or [invalid memory access](https://github.com/tiliado/nuvolaruntime/issues/464).
    We recommend [building the correct Vala version from source](https://github.com/tiliado/nuvolaruntime/commit/eb2332ee6802e89537d68a9c859f1aa51db6abcf)
    prior to building Nuvola. You can then throw it away as Vala compiler is not needed after Nuvola is built.
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
  * gee-0.8 >= 0.20.1
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
