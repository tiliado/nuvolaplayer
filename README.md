Nuvola Player 3
===============

*Nuvola Player 2 is a runtime for web-based music streaming services providing more native user
experience and integration with Linux desktop environments than usual web browsers can offer.
Nuvola Players handles multimedia keys, shows desktop notifications, integrates with various sound
menus, applets and launchers and more. Additional features include Last FM and Libre FM scrobling
and lyrics fetching.*

**Nuvola Player 3 is a new code-base written from scratch** and the current development stage can be
described as "early alpha and everything in progress", so please be patient and ask questions at
[a development mailing list][1].

[1]: https://groups.google.com/d/forum/nuvola-player-devel).


Code hosting and issue tracker
------------------------------

Nuvola Player uses [Git version control system][2] for its code base and [GitHub][3] for
both code hosting and issue tracking. All official Git repositories are located under
[Tiliado organization account](gh>tiliado). The code-base is divided to three parts:

 1. [Diorite library](gh>tiliado/diorite): Private utility and widget library for Nuvola Player
    project based on GLib, GIO and GTK.
 2. [Nuvola Player 3](gh>tiliado/nuvolaplayer): The Nuvola Player run-time without service
    integrations.
 3. Service integrations that have certain degree of independence and are maintained in separate
    [repositories](gh>tiliado) named ``nuvola-app-...``.

[2]: https://github.com
[3]: http://git-scm.com/


How can I help
--------------

If you would like to contribute to Nuvola Player project development, there are two areas you can
jump in.

 *  [**Core development**][4] - development of the Nuvola Player run-time that loads web app
    integrations and interacts with the Linux desktop components.
    
    **Skills:**
    [Vala](https://wiki.gnome.org/Projects/Vala),
    [GTK+ 3](http://www.gtk.org/),
    [WebKitGtk+](http://webkitgtk.org/),
    [GIT](http://git-scm.com/),
    [JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript)

  * [**Service Integrations**][5] - service integration scripts that runs in the web
    interface and communicates with Nuvola Player run-time.
    
    **Skills:**
    [JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript),
    [DOM](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model),
    [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML).

[4]: http://tiliado.github.io/nuvolaplayer/development/core.html
[5]: http://tiliado.github.io/nuvolaplayer/development/apps.html

Build and Install
-----------------

**Note:** Following instructions expect you are using a sane distribution
where /usr/bin/python is Python 2, not Python 3. (Hello, Arch Linux!)

### Dependencies

  * [Python](http://python.org) >= 2.7, < 3.0
  * [Vala](https://wiki.gnome.org/Projects/Vala) >= 0.16.1
  * [Diorite library](https://github.com/tiliado/diorite)
  * [glib-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.32
  * [gio-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.32
  * [gobject-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.32
  * [gthread-2.0](https://wiki.gnome.org/Projects/GLib) >= 2.32
  * [gtk+-3.0](http://www.gtk.org/) >= 3.4
  * [gdk-3.0](http://www.gtk.org/) >= 3.4
  * [gdk-x11-3.0](http://www.gtk.org/) >= 3.4
  * [x11](http://www.x.org/wiki/) >= 0.5
  * [json-glib-1.0](https://wiki.gnome.org/Projects/JsonGlib) >= 0.7
  * [libarchive](http://www.libarchive.org/) >= 3.1
  * [webkit2gtk-3.0](http://webkitgtk.org/) >= 2.2
  * [javascriptcoregtk-3.0](http://webkitgtk.org/) >= 1.8
  * [libnotify](https://git.gnome.org/browse/libnotify/) >= 0.7
  * optional unity >= 3.0
  * optional dbusmenu-glib-0.4 >= 0.4

### Help

    $ ./waf --help

### Configure

    $ ./waf configure
    
or
    
    $ ./waf configure --with-unity
    
helpful:
    
    $ ./waf configure --prefix=/usr

### Build

    $ ./waf build

### Install

    # ./waf install
    
or
    
    # ./waf install --no-system-hooks
    # /sbin/ldconfig
    # gtk-update-icon-cache ...
    # gtk-update-icon-cache-3.0 ...
    
helpful:

    # ./waf --no-system-hooks --destdir=/whatever
