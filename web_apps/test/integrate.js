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
var player = Nuvola.$object(Nuvola.MediaPlayer);

var ADDRESS = "app.address";
var HOST = "app.host";
var PORT = "app.port";
var COUNTRY_VARIANT = "app.country_variant";

var WebApp = Nuvola.$WebApp();

WebApp.onInitAppRunner = function(emitter, values, entries)
{
	Nuvola.WebApp.onInitAppRunner.call(this, emitter, values, entries);
	
	Nuvola.config.setDefault(ADDRESS, "default");
	Nuvola.config.setDefault(HOST, "");
	Nuvola.config.setDefault(PORT, "");
	Nuvola.config.setDefault(COUNTRY_VARIANT, "com");
	
	Nuvola.core.connect("AppendPreferences", this, "onAppendPreferences");
	
	if (!Nuvola.config.hasKey(ADDRESS))
		this.appendPreferences(values, entries);
}

WebApp.onInitWebWorker = function(emitter)
{
	Nuvola.WebApp.onInitWebWorker.call(this);
	
	console.log(Nuvola.session.hasKey("foo"));
	Nuvola.session.set("foo", "boo");
	console.log(Nuvola.session.hasKey("foo"));
	console.log(Nuvola.session.get("foo"));
}

WebApp.onAppendPreferences = function(emitter, values, entries)
{
	this.appendPreferences(values, entries);
}

WebApp.appendPreferences = function(values, entries)
{
	values[ADDRESS] = Nuvola.config.get(ADDRESS);
	values[HOST] = Nuvola.config.get(HOST);
	values[PORT] = Nuvola.config.get(PORT);
	entries.push(["header", "Logitech Media Server"]);
	entries.push(["label", "Address of your Logitech Media Server"]);
	entries.push(["option", ADDRESS + ":default", "use default address ('localhost:9000')", null, [HOST, PORT]]);
	entries.push(["option", ADDRESS + ":custom", "use custom address", [HOST, PORT], null]);
	entries.push(["string", HOST, "Host"]);
	entries.push(["string", PORT, "Port"]);
	
	values[COUNTRY_VARIANT] = Nuvola.config.get(COUNTRY_VARIANT);
	entries.push(["header", "Amazon Cloud Player"]);
	entries.push(["label", "Preferred national variant"]);
	entries.push(["option", COUNTRY_VARIANT + ":de", "Germany"]);
	entries.push(["option", COUNTRY_VARIANT + ":fr", "France"]);
	entries.push(["option", COUNTRY_VARIANT + ":co.uk", "United Kingdom"]);
	entries.push(["option", COUNTRY_VARIANT + ":com", "United States"]);
}

WebApp.start();

})(this);  // function(Nuvola)
