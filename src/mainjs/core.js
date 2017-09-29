/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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
require("logging");

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
     * You can use it to perform own initialization routine.
     */
    this.addSignal("InitAppRunner");
    
    /** 
     * Emitted at start-up when initialization form is being built.
     * 
     * @param Object values                       mapping between form field names and their values
     * @param "Array of FormFieldArray" fields    specification of form fields, see
     *     @link{doc>apps/initialization-and-preferences-forms.html|Initialization and Preferences Forms}
     *     for details 
     */
    this.addSignal("InitializationForm");
    
    /** 
     * @signal InitWebWorker     initialize web worker process hook
     * 
     * This signal is emitted every time just before a web page is loaded in the main frame of the web view.
     */
    this.addSignal("InitWebWorker");
    
    /** 
     * @signal InitWebWorkerHelper     initialize web worker helper hook
     * 
     * This signal is emitted only once just before a web page is loaded in the main frame of the web view.
     */
    this.addSignal("InitWebWorkerHelper");
    
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
     * @param String request.url           URL of the new page
     * @param Boolean request.newWindow    whether to open request in a new window, you can overwrite this field
     * @param Boolean request.approved     whether the navigation is approved, set to ``false`` when
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
     * Emitted on request for web page settings.
     * 
     * @param String request.url            URL of the new page
     * @param Boolean request.newWindow     whether to open request in a new window, you can overwrite this field
     * @param Boolean request.javascript    whether javascript should be enabled
     * @param String request.userAgent       whether to override user agent string
     * 
     * ```
     * var _onPageSettings = function(object, request)
     * {
     *     request.userAgent = (
     *         request.url.startsWith("https://accounts.google.com/")
     *         || request.url.startsWith("https://accounts.youtube.com/")
     *         ? "WEBKIT" : null
     *     );
     * }
     * ```
     */
    this.addSignal("PageSettings");
    
    /**
     * Emitted on request for loading a web resource.
     * 
     * @param String request.url           URL of the resource (can be overwritten)
     * @param Boolean request.approved     whether the resource loading is approved
     * 
     * ```
     * var _onResourceRequest = function(emitter, request)
     * {
     *     request.url = request.url.replace("webcomponents.js", "webcomponents2.js");
     * }
     * ```
     */
    this.addSignal("ResourceRequest");
    
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
     * Emitted on request to quit the application by closing the main window.
     * 
     * This signal is emitted in both App Runner and Web Worker processes.
     * 
     * @param bool result.approved    Whether application can quit. If false, application will continue
     *     running in background.
     * 
     * ```
     * var _onQuitRequest = function(emitter, result)
     * {
     *      if (Nuvola.config.get("myapp.run_in_background"))
     *          result.approved = false;
     * }
     * ```
     */
    this.addSignal("QuitRequest");
    
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
    this.addSignal("PreferencesForm");
    /**
     * Emitted when a component has been loaded.
     * 
     * @param string name    the name of the component
     */
    this.addSignal("ComponentLoaded");
    /**
     * Emitted when a component has been unloaded.
     * 
     * @param string id      the id of the component
     * @param string name    the name of the component
     */
    this.addSignal("ComponentUnloaded");
}

/**
 * Returns information about a component
 * 
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param id id of the component
 * @return Object component info
 */
Core.getComponentInfo = function(id) {
    Nuvola.log("Core.getComponentInfo is deprecated since Nuvola 4.8. Use async variant instead.");
    return Nuvola._callIpcMethodSync("/nuvola/core/get-component-info", [id + ""]);
}

/**
 * Returns information about a component
 * 
 * @since Nuvola 4.8
 * @async
 * @param id id of the component
 * @return Object component info
 */
Core.getComponentInfoAsync = function(id) {
    return Nuvola.Async.call("/nuvola/core/get-component-info", [id + ""]);
}

/**
 * Returns whether a component is loaded
 * 
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param id    id of the component
 * @return Boolean true if the component is loaded
 */
Core.isComponentLoaded = function(id) {
    Nuvola.log("Core.isComponentLoaded is deprecated since Nuvola 4.8. Use async variant instead.");
    var info = this.getComponentInfo(id);
    return info.loaded;
}

/**
 * Returns whether a component is loaded
 * 
 * @since Nuvola 4.8
 * @async
 * @param id    id of the component
 * @return Boolean true if the component is loaded
 */
Core.isComponentLoadedAsync = function(id) {
    return this.getComponentInfoAsync(id).then((info) => info.loaded);
}

/**
 * Activates or deactivates a component
 * 
 * The component must be loaded.
 * 
 * @param id id of the component
 * @param Boolean active whether to activate or deactivate the component
 * @return Boolean true (since Nuvola 4.8)
 */
Core.toggleComponentActive = function(id, active) {
    Nuvola._callIpcMethodVoid("/nuvola/core/toggle-component-active", [id + "", !!active]);
    return true;
}


/**
 * Returns whether a component is loaded and active
 * 
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param id    id of the component
 * @return Boolean true if the component is active
 */
Core.isComponentActive = function(id) {
    Nuvola.log("Core.isComponentActive is deprecated since Nuvola 4.8. Use async variant instead.");
    var info = this.getComponentInfo(id);
    return info.active;
}

/**
 * Returns whether a component is loaded and active
 * 
 * @since Nuvola 4.8
 * @async
 * @param id    id of the component
 * @return Boolean true if the component is active
 */
Core.isComponentActiveAsync = function(id) {
    return this.getComponentInfoAsync(id).then((info) => info.active);
}

// export public items
Nuvola.Core = Core;

/**
 * Instance object of @link{Core|Core prototype} connected to Nuvola backend.
 */
Nuvola.core = $object(Core);
