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

(function(Nuvola)
{

Nuvola.Player.init();

var ADDRESS = "app.address";
var HOST = "app.host";
var PORT = "app.port";
var COUNTRY_VARIANT = "app.country_variant";

var Initialization = function()
{
	Nuvola.Config.setDefault(ADDRESS, "default");
	Nuvola.Config.setDefault(HOST, "");
	Nuvola.Config.setDefault(PORT, "");
	Nuvola.Config.setDefault(COUNTRY_VARIANT, "com");
	Nuvola.Core.connect("home-page", this, "onHomePage");
	Nuvola.Core.connect("append-preferences", this, "onAppendPreferences");
	Nuvola.Core.connect("init-app-runner", this, "onInitAppRunner");
}

Initialization.prototype.onHomePage = function(object, result)
{
	result.url = Nuvola.meta.home_url;
}

Initialization.prototype.onAppendPreferences = function(emitter, values, entries)
{
	this.appendPreferences(values, entries);
}

Initialization.prototype.onInitAppRunner = function(emitter, values, entries)
{
	if (!Nuvola.Config.hasKey(ADDRESS))
		this.appendPreferences(values, entries);
}

Initialization.prototype.appendPreferences = function(values, entries)
{
	values[ADDRESS] = Nuvola.Config.get(ADDRESS);
	values[HOST] = Nuvola.Config.get(HOST);
	values[PORT] = Nuvola.Config.get(PORT);
	entries.push(["header", "Logitech Media Server"]);
	entries.push(["label", "Address of your Logitech Media Server"]);
	entries.push(["option", ADDRESS + ":default", "use default address ('localhost:9000')", null, [HOST, PORT]]);
	entries.push(["option", ADDRESS + ":custom", "use custom address", [HOST, PORT], null]);
	entries.push(["string", HOST, "Host"]);
	entries.push(["string", PORT, "Port"]);
	
	values[COUNTRY_VARIANT] = Nuvola.Config.get(COUNTRY_VARIANT);
	entries.push(["header", "Amazon Cloud Player"]);
	entries.push(["label", "Preferred national variant"]);
	entries.push(["option", COUNTRY_VARIANT + ":de", "Germany"]);
	entries.push(["option", COUNTRY_VARIANT + ":fr", "France"]);
	entries.push(["option", COUNTRY_VARIANT + ":co.uk", "United Kingdom"]);
	entries.push(["option", COUNTRY_VARIANT + ":com", "United States"]);
}

Nuvola.initialization = new Initialization();

})(this);  // function(Nuvola)
