Title: URL Filtering (URL Sandbox)

URL filtering (URL sandbox) is used to decide which URLs are opened in a default web browser instead
of Nuvola Player. For example, a Google Play Music user definitely doesn't want to open a Google
Plus link in Nuvola Player, but in his default web browser.

Default URL Filter
==================

[Nuvola.WebApp](apiref>Nuvola.WebApp) looks at ``allowed_uri`` field of ``metadata.json``.
If this field is not empty, it is compiled as a [regular expression][regexp] and stored at
``WebApp.allowedURI`` property. The default URL filter implemented in
[Nuvola.WebApp._onNavigationRequest](apiref>Nuvola.WebApp._onNavigationRequest) then allows
navigation only to URLs that match that regular expression, other URLs are opened in a default web
browser.

```js
{
  ...
  "allowed_uri": "^https?://(play\\.google\\.com/)"
}
```

[regexp]: https://developer.mozilla.org/en/docs/Web/JavaScript/Guide/Regular_Expressions

Custom URL Filter
=================

Since the default URL filter is a JavaScript function, you can override it to match your needs.
The method [Nuvola.WebApp._onNavigationRequest](apiref>Nuvola.WebApp._onNavigationRequest)
is a handler for [Nuvola.Core::NavigationRequest signal](apiref>Nuvola.Core%3A%3ANavigationRequest).

```js

var WebApp = Nuvola.$WebApp()

...

WebApp._onNavigationRequest = function (emitter, request) {
  if (request.url === 'https://www.npr.org/') {
    // choice.npr.org redirects to 'https://www.npr.org/' regardless of the original domain (one.npr.org)
    // Let's go to the home page instead of showing www.npr.org in a new window.
    request.url = 'https://one.npr.org/'
    request.approved = true
  } else {
    // Apply URL filter otherwise
    Nuvola.WebApp._onNavigationRequest.call(this, emitter, request)
  }
}

...
```

!!! danger "Global window object not available"
    The [Nuvola.Core::NavigationRequest](apiref>Nuvola.Core%3A%3ANavigationRequest) signal is
    executed in a pure JavaScript environment without
    [Window object](https://developer.mozilla.org/en/docs/Web/API/Window).
    Use [Nuvola.log()](apiref>Nuvola.log) to print logging and debugging messages to terminal
    instead of [console.log()](https://developer.mozilla.org/en-US/docs/Web/API/console.log).

Debugging URL Filter
====================

If you run Nuvola Player with ``-D`` or ``--debug`` flag, you will see URL filtering in action:

```text
[Runner:DEBUG    Nuvola] webengine.vala:443: Navigation, current window:
uri = https://checkout.google.com/inapp/frontend/passive?&usid=0&plid=0,
result = true, frame = (null), type = WEBKIT_NAVIGATION_TYPE_OTHER

[Runner:DEBUG    Nuvola] webengine.vala:440: Navigation, new window:
uri = https://plus.google.com/u/0/?tab=YX, result = true, frame = _blank,
type = WEBKIT_NAVIGATION_TYPE_LINK_CLICKED
```

The debugging message contains following information:

  * Whether to open request in a new window or in the current window (``request.newWindow``).
  * The URL of the request (``request.url``).
  * The result of the [Nuvola.Core::NavigationRequest](apiref>Nuvola.Core%3A%3ANavigationRequest)
    signal (``request.approved``).
  * The type of the request.

!!! danger "URL filter works only for link clicks"
    While the [Nuvola.Core::NavigationRequest](apiref>Nuvola.Core%3A%3ANavigationRequest) signal
    is currently emitted for all types of navigation, the result of the URL filter is taken into
    account only for link clicks (``WEBKIT_NAVIGATION_TYPE_LINK_CLICKED``). This may change in the
    future.

[TOC]

[np_devel]: https://groups.google.com/d/forum/nuvola-player-devel
