/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met: 
 * 
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer. 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

require("prototype");
require("signals");
require("core");

/**
 * Prototype object for web app integration.
 */
var WebApp = $prototype(null, SignalsMixin);

/**
 * @link{ConfigStorage|Configuration} key used to store an address of the last visited page.
 */
WebApp.LAST_URI = "web_app.last_uri";

/**
 * Initializes new web app object.
 */
WebApp.$init = function()
{
    this.meta = Nuvola.meta;
    var allowedURI = this.meta.allowed_uri;
    this.allowedURI = allowedURI ? new RegExp(allowedURI) : null;
    Nuvola.core.connect("HomePageRequest", this);
    Nuvola.core.connect("LastPageRequest", this);
    Nuvola.core.connect("NavigationRequest", this);
    Nuvola.core.connect("UriChanged", this);
    Nuvola.core.connect("InitAppRunner", this);
    Nuvola.core.connect("InitWebWorker", this);
}

/**
 * Convenience function to create new WebApp object linked to Nuvola API.
 * 
 * ```
 * var WebApp = Nuvola.$WebApp();
 * 
 * ...
 * 
 * WebApp.start();
 * ```
 */
WebApp.start = function()
{
    Nuvola.webApp = $object(this);
}

/**
 * Signal handler for @link{Core::HomePageRequest}
 */
WebApp._onHomePageRequest = function(emitter, result)
{
    result.url = this.meta.home_url;
}

/**
 * Signal handler for @link{Core::LastPageRequest}
 */
WebApp._onLastPageRequest = function(emitter, request)
{
    request.url = Nuvola.config.get(this.LAST_URI) || null;
}

/**
 * Signal handler for @link{Core::NavigationRequest}
 */
WebApp._onNavigationRequest = function(object, request)
{
    request.approved = this.allowedURI ? this.allowedURI.test(request.url) : true;
}

/**
 * Signal handler for @link{Core::UriChanged}
 */
WebApp._onUriChanged = function(object, uri)
{
    Nuvola.config.set(this.LAST_URI, uri);
}

/**
 * Signal handler for @link{Core::InitAppRunner}
 */
WebApp._onInitAppRunner = function(emitter)
{
}

/**
 * Signal handler for @link{Core::InitWebWorker}. Override this method to integrate the web page.
 * 
 * ```
 * WebApp._onInitWebWorker = function(emitter)
 * {
 *     Nuvola.WebApp._onInitWebWorker.call(this, emitter);
 *     
 *     var state = document.readyState;
 *     if (state === "interactive" || state === "complete")
 *         this._onPageReady();
 *     else
 *         document.addEventListener("DOMContentLoaded", this._onPageReady.bind(this));
 * }
 * 
 * WebApp._onPageReady = function(event)
 * {
 *     ...
 * }
 * ```
 */
WebApp._onInitWebWorker = function(emitter)
{
}

// export public fields
Nuvola.WebApp = WebApp;

/**
 * Convenience function to create new prototype object extending @link{WebApp} prototype.
 * 
 * @return new prototype object extending @link{WebApp}
 * 
 * ```
 * var WebApp = Nuvola.$WebApp();
 * ```
 */
Nuvola.$WebApp = function()
{
    if (this !== Nuvola)
        throw new Error("Nuvola.$WebApp has been called incorrectly. Use `var WebApp = Nuvola.$WebApp();` idiom.");
    
    return $prototype(WebApp);
}

