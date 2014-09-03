Title: Nuvola Player Development
URL:
save_as: index.html

!!! danger "**Work in progress**"
    **Nuvola Player 3 is a new code-base written from scratch** and the current development stage can be
    described as "early alpha and everything in progress", so please be patient and
    [ask questions](https://groups.google.com/d/forum/nuvola-player-devel). You might also be
    interested in information about
    [advantages of Nuvola Player 3 over Nuvola Player 2]({filename}nuvola_player_3_advantages.md).

Development forum
=================

We use Google Groups for
[Nuvola Player Development forum/mailing list](https://groups.google.com/d/forum/nuvola-player-devel).
Don't hesitate to ask any questions.

Code hosting and issue tracker
==============================

Nuvola Player uses [Git version control system][git] for its code base and [GitHub][github] for
both code hosting and issue tracking. All official Git repositories are located under
[Tiliado organization account](gh>tiliado). The code-base is divided to three parts:

 1. [Diorite library](gh>tiliado/diorite): Private utility and widget library for Nuvola Player
    project based on GLib, GIO and GTK.
 2. [Nuvola Player 3](gh>tiliado/nuvolaplayer): The Nuvola Player run-time without service
    integrations.
 3. Service integrations that have certain degree of independence and are maintained in separate
    [repositories](gh>tiliado) named ``nuvola-app-...``.

Translations
============

Nuvola Player 3 hasn't chosen any platform for translations yet.

How can I help
==============

If you would like to contribute to Nuvola Player project development, there are two areas you can jump in.

Core development
----------------

[**Core development**]({filename}core.md) - development of the Nuvola Player run-time that loads web
app integrations and interacts with the Linux desktop components. **Skills:**
[Vala](https://wiki.gnome.org/Projects/Vala),
[GTK+ 3](http://www.gtk.org/),
[WebKitGtk+](http://webkitgtk.org/),
[GIT](http://git-scm.com/),
[JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript)

Service Integrations
--------------------

[**Service Integrations**]({filename}apps.md) - service integration scripts that runs in the web
interface and communicates with Nuvola Player run-time. **Skills:**
[JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript),
[DOM](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model),
[HTML](https://developer.mozilla.org/en-US/docs/Web/HTML).

[TOC]

[github]: https://github.com
[git]: http://git-scm.com/
