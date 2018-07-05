Title: Service Integration Development

Introduction
============

Service integration scripts live in a web browser engine ([WebKitGtk+](http://webkitgtk.org/)) and
are written in [JavaScript](https://developer.mozilla.org/en/docs/Web/JavaScript). Since the major
responsibility of these scripts is to extract information from a web page and interact with it, you
need a good knowledge of [HTML](https://developer.mozilla.org/en-US/docs/Web/HTML) and
[Document Object Model API](https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model).

Service integrations are maintained as [git repositories at Github](https://github.com/tiliado).
Although it isn't strictly required, experiences with [Git version control system][git] and
[Github code hosting platform][github] are very appreciated. Otherwise you can distribute your work
in tar archives and we will create and maintain a Git repository for you, but it will obviously
increase maintenance burden of the project.

Documentation
=============

Basic
-----

  * [Service Integration Tutorial]({filename}apps/tutorial.md): This guide briefly describes
    creation of a new service integration for Nuvola Runtime from scratch. Then you should be ready
    to create your service integration.
  * [Service Integration Guidelines]({filename}apps/guidelines.md): These rules apply if you would
    like to have your service integration maintained as a part of the Nuvola Apps project and
    distributed in the Nuvola Apps repository.
  * [NuvolaKit JavaScript API reference](apps/api_reference.html).

Advanced
--------

  * [URL Filtering (URL Sandbox)]({filename}apps/url-filtering.md):
    Decide which urls are opened in a default web browser instead of Nuvola Player.
  * [Configuration and session storage]({filename}apps/configuration-and-session-storage.md):
    Nuvola Runtime allows service integrations to store both a persistent configuration and a temporary session information.
  * [Initialization and Preferences Forms]({filename}apps/initialization-and-preferences-forms.md):
    These forms are useful when you need to get user input.
  * [Web apps with a variable home page URL]({filename}apps/variable-home-page-url.md):
    This article covers Web apps that don't have a single (constant) home page URL, so their home page has to be specified by user.
  * [Custom Actions]({filename}apps/custom-actions.md):
    This article covers API that allows you to add custom actions like thumbs up/down rating.
  * [Translations]({filename}apps/translations.md): How to mark translatable strings for
    [Gettext-based](http://www.gnu.org/software/gettext/manual/gettext.html)
    translations framework for service integration scripts.

[git]: http://git-scm.com/
[github]: https://github.com/

[TOC]
