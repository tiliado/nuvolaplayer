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
require("core");

var WebAppPrototype = $prototype(null, SignalsMixin);
WebAppPrototype.LAST_URI = "web_app.last_uri";

WebAppPrototype.$init = function()
{
	this.meta = Nuvola.meta;
	var allowedURI = this.meta.allowed_uri;
	this.allowedURI = allowedURI ? new RegExp(allowedURI) : null;
	Nuvola.Core.connect("home-page", this, "onHomePage");
	Nuvola.Core.connect("last-page", this, "onLastPage");
	Nuvola.Core.connect("navigation-request", this, "onNavigationRequest");
	Nuvola.Core.connect("uri-changed", this, "onURIChanged");
	Nuvola.Core.connect("init-app-runner", this, "onInitAppRunner");
}

WebAppPrototype.start = function()
{
	Nuvola.WebAppObject = $object(this);
}

WebAppPrototype.onHomePage = function(object, result)
{
	result.url = this.meta.home_url;
}

WebAppPrototype.onLastPage = function(object, result)
{
	result.url = Nuvola.Config.get(this.LAST_URI) || null;
}

WebAppPrototype.onNavigationRequest = function(object, request)
{
	request.approved = this.allowedURI ? true : this.allowedURI.test(request.url);
}

WebAppPrototype.onURIChanged = function(object, uri)
{
	Nuvola.Config.set(this.LAST_URI, uri);
}

WebAppPrototype.onInitAppRunner = function(emitter, values, entries)
{
}

// export public fields
Nuvola.WebAppPrototype = WebAppPrototype;
Nuvola.$WebApp = function()
{
	if (this !== Nuvola)
		throw new Error("Nuvola.$WebApp has been called incorrectly. Use `var WebApp = Nuvola.$WebApp();` idiom.");
	
	return $prototype(WebAppPrototype);
}

