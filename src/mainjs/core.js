/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

/**
 * Prototype object to manage Nuvola Player Core
 */
var Core = $prototype(null, SignalsMixin);

/**
 * Initializes new Core instance object
 */
Core.$init = function()
{
    /** 
     * Emitted at start-up when initialization of the app runner process is needed.
     * You can use it to append entries to initialization form (e. g. preferred national variant
     * or address of custom service instance) and to perform own initialization routine.
     * 
     * @param Object values                       mapping between form field names and their values
     * @param "Array of FormFieldArray" fields    specification of form fields, see
     *     @link{doc>apps/initialization-and-preferences-forms.html|Initialization and Preferences Forms}
     *     for details 
     */
    this.addSignal("InitAppRunner");
    
    /** 
     * @signal InitWebWorker     initialize web worker process hook
     * 
     * This signal is emitted just before a web page is loaded in the main frame of the web view.
     */
    this.addSignal("InitWebWorker");
    
    /**
     * Emitted on request for home page URL.
     * 
     * See @link{doc>apps/variable-home-page-url.html|Web apps with a variable home page URL}.
     * 
     * @param String request.url    property to assign home page url to
     * 
     * ```
     * var _onHomePageRequest = function(emitter, request)
     * {
     *     request.url = "http://tiliado.eu";
     * }
     * ```
     */
    this.addSignal("HomePageRequest");
    
    /**
     * Emitted on request for navigation to a new web page.
     * 
     * @param String request.url    URL of the new page
     * @param Boolean request.approved    whether the navigation is approved, set to ``false`` when
     *     the ``request.url`` should be opened in user's default web browser 
     * 
     * ```
     * var _onNavigationRequest = function(object, request)
     * {
     *     request.approved = isAddressAllowed(request.url);
     * }
     * ```
     */
    this.addSignal("NavigationRequest");
    
    /**
     * Emitted on request for the last visited URL.
     * 
     * @param String|null result.url    property to assign the last visited URL to
     * 
     * ```
     * var _onLastPageRequest = function(emitter, result)
     * {
     *     request.url = Nuvola.config.get("last_uri") || null;
     * }
     * ```
     */
    this.addSignal("LastPageRequest");
    
    /**
     * Emitted after @link{Core::NavigationRequest|approved navigation} to a new page URL.
     * 
     * @param string uri    URI of the new page
     * 
     * ```
     * var _onUriChanged = function(emitter, uri)
     * {
     *     Nuvola.config.set("last_uri", uri);
     * }
     * ```
     */
    this.addSignal("UriChanged");
    
    /**
     * Emitted when preferences dialog is being built.
     * 
     * @param Object values                       mapping between form field names and their values
     * @param "Array of FormFieldArray" entries   specification of form fields, see
     *     @link{doc>apps/initialization-and-preferences-forms.html|Initialization and Preferences Forms}
     *     for details
     */
    this.addSignal("AppendPreferences");
}

/**
 * Set whether the main window should be hidden when close button is pressed
 * and run in background.
 * 
 * @param Boolean hide    whether to hide on close
 */
Core.setHideOnClose = function(hide)
{
    return Nuvola._sendMessageSync("Nuvola.setHideOnClose", hide);
}

// export public items
Nuvola.Core = Core;

/**
 * Instance object of @link{Core|Core prototype} connected to Nuvola backend.
 */
Nuvola.core = $object(Core);
