Nuvola Apps Runtime
===================

About Nuvola
------------

**Nuvola Apps™** is a runtime for semi-sandboxed web apps providing more native user experience and tighter
integration with Linux desktop environments than usual web browsers can offer. It tries to feel and look
like a native application as much as possible.
Nuvola™ mostly specializes on music streaming web apps (e.g. Google Play Music, Spotify, Amazon Music, Deezer,
nd more), but progress is being made to support generic web apps (e.g. Google Calendar, Google Keep, etc.).

**Features of Nuvola:** Desktop launchers, integration with media applets (e.g. in GNOME Shell and Ubuntu sound menu),
Unity launcher quick list actions, lyrics fetching, Last.fm audio scrobbler, tray icon, desktop notifications,
media keys binding, password manager, remote control over HTTP and more. Some features may be available only to
users with premium or patron plans available at https://tiliado.eu/nuvolaplayer/funding/
 
**Support:** Users of the genuine Nuvola builds available at https://nuvola.tiliado.eu are eligible for 
a limited user support free of charge. Users of third-party builds should contact the customer care of their distributor
or order paid support provided by the Nuvola developer.

**Trademarks:** Nuvola™, Nuvola Player™ and Nuvola Apps™ are trademarks held by Jiří Janoušek,
the founder of Nuvola project. Nuvola Apps software is not affiliated with the Nuvola icon theme.

Code hosting and issue tracker
------------------------------

Nuvola uses [Git version control system][2] for its code base and [GitHub][3] for
both code hosting and issue tracking. All official Git repositories are located under
[Tiliado organization account](https://github.com/tiliado). The code-base is divided to three parts:

 1. [Diorite library](https://github.com/tiliado/diorite): Private utility and widget library for
    Nuvola Player project based on GLib, GIO and GTK.
 2. [Nuvola Apps](https://github.com/tiliado/nuvolaplayer): The Nuvola Apps run-time without
    service integrations.
 3. Service integrations that have certain degree of independence and are maintained in separate
    [repositories](https://github.com/tiliado) named ``nuvola-app-...``.

[2]: http://git-scm.com/
[3]: https://github.com


How can I help
--------------

If you would like to contribute to Nuvola Apps project development, there are two areas you can
jump in.

  * [**Core development**][4] - development of the Nuvola Apps run-time that loads web app
    integrations and interacts with the Linux desktop components.
    
    *Skills:*
    [Vala](https://wiki.gnome.org/Projects/Vala),
    [GTK+ 3](http://www.gtk.org/),
    [WebKitGtk+](http://webkitgtk.org/),
    [GIT](http://git-scm.com/),
    [JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript)

  * [**Service Integrations**][5] - service integration scripts that runs in the web
    interface and communicates with Nuvola Apps run-time.
    
    *Skills:*
    [JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript),
    [DOM](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model),
    [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML).

[4]: http://tiliado.github.io/nuvolaplayer/development/core.html
[5]: http://tiliado.github.io/nuvolaplayer/development/apps.html

Build and Install
-----------------

### Dependencies

  * [Python 3](http://python.org) >= 3.4
  * [Vala](https://wiki.gnome.org/Projects/Vala) >= 0.34.0
  * [Diorite library](https://github.com/tiliado/diorite) 0.3.x
  * [glib-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.50.0
  * [gio-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.50.0
  * [gobject-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.50.0
  * [gtk+-3.0](http://www.gtk.org/) >= 3.22.0
  * [gdk-3.0](http://www.gtk.org/) >= 3.22.0
  * [gdk-x11-3.0](http://www.gtk.org/) >= 3.22.0
  * [x11](http://www.x.org/wiki/) >= 0.5
  * [json-glib-1.0](https://wiki.gnome.org/Projects/JsonGlib) >= 0.7
  * [libarchive](http://www.libarchive.org/) >= 3.1
  * [webkit2gtk-4.0](http://webkitgtk.org/) >= 2.14.5 (2.16.0 recommended)
  * [javascriptcoregtk-4.0](http://webkitgtk.org/) >= 2.14.5 (2.16.0 recommended)
  * [libnotify](https://git.gnome.org/browse/libnotify/) >= 0.7
  * [gstreamer](https://gstreamer.freedesktop.org/) >= 1.8.3 (>= 1.12 for MSE)
  * libuuid
  * libsecret-1 >= 0.16
  * optional unity >= 3.0
  * optional dbusmenu-glib-0.4 >= 0.4


### Waf

Nuvola uses [waf build system](https://waf.io). You are supposed to use the waf binary bundled with
Nuvola's source code. The build script `wscript` may not be compatible with other versions. If you manage
to port wscript to a newer stable waf release, you may provide us with patches to be merged once we decide
to update our waf binary. Meantime, you can carry them downstream.

To find out what build parameters can be set run ./waf --help 

### Build

    $ ./waf configure [--prefix=...] [--libdir=...] [--noopt] [--nodebug] [--nounity]
    $ ./waf build

### Install

    # ./waf install [--destdir=...]
    # /sbin/ldconfig
    # gtk-update-icon-cache ...
    # gtk-update-icon-cache-3.0 ...
    
### Uninstall

    # ./waf uninstall [--destdir=...]


Changelog
---------

See [CHANGELOG.md](./CHANGELOG.md).
