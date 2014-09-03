Title: Advantages of Nuvola Player 3

Nuvola Player 3 is a brand new code base written from scratch. This article describes reasons for
throwing the old Nuvola Player 2 code away and advantages of this decision.

The Too Old Code
================

Early Days
----------

Nuvola Player 2 code dates back to August 23, 2011 as Google Music Frame. It was my first
experiment with the Vala programming language, so you cannot expect the code is perfect. The
project was renamed to Nuvola Player with release 1.0 on December 23, 2011 bringing support for
other services than Google Music.

Stagnation
----------

Nuvola Player was later ported to from GTK+ 2 to GTK+ 3 with release 2.0 on September 17, 2012.
However, while development of GTK+ 3 and underlying technologies was quite rapid and plenty of old
API was marked as *deprecated*, development of Nuvola Player after release 2.0 stagnated
and was officially discontinued on September 14, 2013 with release 2.2.0.

Crowd-funding
-------------

I tried to crowd-fund my work on Nuvola Player two months after the discontinuation of the project.
Luckily, the attempt was successful and the development was resumed during November 2013 resulting
in Nuvola Player 2.3.0 released on December 24th, 2013. However, it was evident that Nuvola Player 2
code is too bad for further significant improvements:

  * It has many design flaws from the time I started learning Vala.
  * It is hard to extend and maintain.
  * It is build on top of the first generation of WebKitGtk library, that is now deprecated.
    Porting to the second generation is necessary, but requires significant changes.
  * It uses plenty of functions deprecated in recent versions of GNOME libraries.
  * It carries a heavy bag of backward compatibility with old distributions that limits potential of
    the application.
  * The JavaScript API was found not to be very flexible and improvements of this situation would
    break backward compatibility.

Hence, I decided to throw away the old code-base and rewrite the application on top of the second
generation of WebKitGtk library.

The New Era
===========

Flash plugin issues
-------------------

**Nuvola Player 2** uses graphical toolkit GTK+ version 3 for its user interface, while Adobe Flash,
Gnash and Lightspark use GTK+ version 2. The old GTK+ 2 and the new GTK+ 3 are not compatible, so
they cannot live in the same process. The problem is that the first generation WebKitGtk+ web
rendering engine used in Nuvola Player 2 runs plugins in the same process as the rest of the user
interface, so GTK+ 2 based Flash plugins cannot be loaded without conflicts with GTK+ 3.

Nuvola Player 2 has to employ an ugly hack to support Flash: run the Flash plugin in its own
non-conflicting process via nspluginwrapper. However, this approach has **several disadvantages**:

  * nspluginwrapper only supports only 32bit Flash plugin. As a result, you have to install hundreds
    of 32bit libraries on you 64bit system to be able to run 32bit Flash plugin. Yes, this is insane.
  
  * Memory usage is higher and performance is lower.
  
  * Wrapped Flash plugin is less stable, it often crashes and takes down whole Nuvola Player 2
    application.

**Nuvola Player 3** is built on top of WebKit2Gtk+, the second generation of this web rendering
library. The major diference is that plugins are run in a separate GTK+ 2 compatible process, so
there is **no need to** use nspluginwrapper and **install 32bit libraries** on 64bit system. There
is also one extra benefit: If Flash plugin crashes, it doesn't take down whole Nuvola Player
application.

More independent services
-------------------------

  * It's possible to run multiple services side-by-side.
  
  * Each service gets a desktop launcher and can be launched directly from applications menu (XFCE)
    or applications overview (Unity, GNOME 3).

Packages for Fedora and openSuse
--------------------------------

Nuvola Player 2 provides official packages only for Debian and Ubuntu. Nuvola Player 3 will also
provide packages for Fedora and openSUSE (before the first beta release at the latest). It will be
also evaluated whether it is necessary to provide official packages for Arch Linux depending on
a quality of a maintenance of community packages in AUR.

Modern codebase
---------------

Nuvola Player 3 targets Ubuntu 14.04 an newer, so it doesn't have a heavy bag of compatibility code,
but uses new methods and functions instead of the deprecated ones. As a result, it should better
integrate with modern Linux desktop.

More flexible JavaScript API
----------------------------

The new version of JavaScript API has been designed to be more flexible and to support use cases
that haven't been possible in JavaScript API of Nuvola Player 2.

  * Native widgets for service-specific settings.
  
  * Initialization form for services with custom address.
  
  * Flexible handling of home page URL and the last visited page.
  
  * A lot of behavior previously hard-coded in Nuvola Player code is now written in JavaScript
    and can be overridden by service integration scripts.
  

Implemented features
--------------------

There is a selection of features that are available only in Nuvola Player 3:

 *  [Possibility to edit default shortcuts](https://bugs.launchpad.net/nuvola-player/+bug/1294082)
 *  [Add ability to make desktop shortcuts to different services](https://bugs.launchpad.net/nuvola-player/+bug/1211351)
 *  [Keyboard shortcut to show currently playing track in notification](https://bugs.launchpad.net/nuvola-player/+bug/1207926)
 *  [Global keyboard shortcuts](https://bugs.launchpad.net/nuvola-player/+bug/1200911)
 *  ['like' status on tray context menu](https://bugs.launchpad.net/nuvola-player/+bug/1081077)
 *  [allow using multiple streaming services side by side](https://bugs.launchpad.net/nuvola-player/+bug/1007185)
 *  [Support for services with a custom streaming server address](https://bugs.launchpad.net/nuvola-player/+bug/1011097)
 *  [Queue page as a startup screen for Google Play Music is not useful](https://bugs.launchpad.net/nuvola-player/+bug/1306678)

[TOC]
