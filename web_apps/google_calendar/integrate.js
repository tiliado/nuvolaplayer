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

"use strict";

(function(Nuvola)
{

// Translations
var _ = Nuvola.Translate.gettext;

// Constants
var RUN_IN_BACKGROUND = "app.run_in_background";

// Create new WebApp prototype
var WebApp = Nuvola.$WebApp();


WebApp._onInitAppRunner = function(emitter)
{
    Nuvola.launcher.setActions(["quit"]);
    Nuvola.WebApp._onInitAppRunner.call(this, emitter);
    Nuvola.config.setDefault(RUN_IN_BACKGROUND, true);
    Nuvola.core.connect("QuitRequest", this);
    Nuvola.core.connect("PreferencesForm", this);
}


// Initialization routines
WebApp._onInitWebWorker = function(emitter)
{
    Nuvola.WebApp._onInitWebWorker.call(this, emitter);

    var state = document.readyState;
    if (state === "interactive" || state === "complete")
        this._onPageReady();
    else
        document.addEventListener("DOMContentLoaded", this._onPageReady.bind(this));
    
    // Override default window.alert() to propagate event alerts as desktop notifications
    var alert = window.alert;
    window.alert = function(text)
    {
        Nuvola.Notifications.showNotification(_("Google Calendar Alert"), text, "appointment-soon", null, false);
        return alert(text);
    };
}


// Page is ready for magic
WebApp._onPageReady = function()
{
    // Nothing to do for now.
}


WebApp._onPreferencesForm = function(emitter, values, entries)
{
    this.appendPreferences(values, entries);
}


WebApp._onQuitRequest = function(emitter, result)
{
    if (Nuvola.config.get(RUN_IN_BACKGROUND))
        result.approved = false;
}


WebApp.appendPreferences = function(values, entries)
{
    values[RUN_IN_BACKGROUND] = Nuvola.config.get(RUN_IN_BACKGROUND);
    entries.push(["bool", RUN_IN_BACKGROUND, _("Run in background"), null, null]);
}


WebApp._onNavigationRequest = function(emitter, request)
{
    // Google Calendar uses target="_blank" for external links :-) 
    request.approved = !request.newWindow;
}


WebApp.start();

})(this);  // function(Nuvola)
