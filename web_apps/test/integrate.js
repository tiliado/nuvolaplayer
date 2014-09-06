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
var ADDRESS_DEFAULT = "default";
var ADDRESS_CUSTOM = "custom";
var HOST = "app.host";
var PORT = "app.port";
var COUNTRY_VARIANT = "app.country_variant";

var WebApp = Nuvola.$WebApp();

WebApp._onInitAppRunner = function(emitter, values, entries)
{
	Nuvola.WebApp._onInitAppRunner.call(this, emitter, values, entries);
	
	Nuvola.config.setDefault(ADDRESS, "default");
	Nuvola.config.setDefault(HOST, "");
	Nuvola.config.setDefault(PORT, "");
	Nuvola.config.setDefault(COUNTRY_VARIANT, "com");
	
	Nuvola.core.connect("AppendPreferences", this);
	
	if (!Nuvola.config.hasKey(ADDRESS))
		this.appendPreferences(values, entries);
}

WebApp._onInitWebWorker = function(emitter)
{
	Nuvola.WebApp._onInitWebWorker.call(this);
	
	console.log(Nuvola.session.hasKey("foo"));
	Nuvola.session.set("foo", "boo");
	console.log(Nuvola.session.hasKey("foo"));
	console.log(Nuvola.session.get("foo"));
	
	var Building = Nuvola.$prototype(null);

	Building.$init = function(address)
	{
		this.address = address;
	}
	
	Building.printAddress = function()
	{
	    console.log(this.address);
	}
	
	var Shop = Nuvola.$prototype(Building);
	
	Shop.$init = function(address, goods)
	{
		Building.$init.call(this, address)
		this.goods = goods;
	}
	
	Shop.printGoods = function()
	{
		console.log(this.goods);
	}
	
	var house = Nuvola.$object(Building, "King Street 1024, London");
	house.printAddress();
	
	var candyShop = Nuvola.$object(Shop, "King Street 1024, London", "candies");
	candyShop.printAddress();
	candyShop.printGoods();
	
	this.testTranslation();
}

WebApp._onAppendPreferences = function(emitter, values, entries)
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
	entries.push(["option", ADDRESS, ADDRESS_DEFAULT, "use default address ('localhost:9000')", null, [HOST, PORT]]);
	entries.push(["option", ADDRESS, ADDRESS_CUSTOM, "use custom address", [HOST, PORT], null]);
	entries.push(["string", HOST, "Host"]);
	entries.push(["string", PORT, "Port"]);
	
	values[COUNTRY_VARIANT] = Nuvola.config.get(COUNTRY_VARIANT);
	entries.push(["header", "Amazon Cloud Player"]);
	entries.push(["label", "Preferred national variant"]);
	entries.push(["option", COUNTRY_VARIANT, "de", "Germany"]);
	entries.push(["option", COUNTRY_VARIANT, "fr", "France"]);
	entries.push(["option", COUNTRY_VARIANT, "co.uk", "United Kingdom"]);
	entries.push(["option", COUNTRY_VARIANT, "com", "United States"]);
}

WebApp.testTranslation = function()
{
    var _ = Nuvola.Translate.gettext;
    
    /// You can use tree slashes to add comment for translators.
    /// It has to be on a line preceding the translated string though.
    console.log(_("Hello world!"));
    var name = "Jiří";
    /// {1} will be replaced by name
    console.log(Nuvola.format(_("Hello {1}!"), name));
    
    var ngettext = Nuvola.Translate.ngettext;
    var eggs = 5;
    var text = ngettext(
        /// You can use tree slashes to add comment for translators.
        /// It has to be on a line preceding the singular string though.
        /// {1} will be replaced by number of eggs in both forms,
        /// but can be omitted as shown in singular form.
        "There is one egg in the fridge.",
        "There are {1} eggs in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    var eggs = 1;
    var text = ngettext(
        "There is one egg in the fridge.",
        "There are {1} eggs in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    
    var C_ = Nuvola.Translate.pgettext;
    
    /// You can use tree slashes to add comment for translators.
    /// It has to be on a line preceding the translated string though.
    console.log(C_("Navigation", "Back"));
    console.log(C_("Body part", "Back"));
    
    console.log(Nuvola.Translate.gettext("Bye World!"));
    var name = "Jiří";
    console.log(Nuvola.format(Nuvola.Translate.gettext("Bye {1}!"), name));
    
    var eggs = 5;
    var text = Nuvola.Translate.ngettext(
        "There is one child in the fridge.",
        "There are {1} children in the fridge.",
        eggs);
    console.log(Nuvola.format(text, eggs));
    var eggs = 1;
    var text = Nuvola.Translate.ngettext(
        "There is one child in the fridge!",
        "There are {1} children in the fridge!",
        eggs);
    console.log(Nuvola.format(text, eggs));
    
    console.log(Nuvola.Translate.pgettext("Navigation", "Forward"));
    console.log(Nuvola.Translate.pgettext("Body part", "Forward"));
}

WebApp.start();

})(this);  // function(Nuvola)
