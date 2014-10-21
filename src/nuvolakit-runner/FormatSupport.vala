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

namespace Nuvola
{

public class FormatSupport: GLib.Object
{
	public uint n_flash_plugins{ get; private set; default = 0;}
	private List<WebPlugin?> web_plugins = null;
	
	public FormatSupport()
	{
	}
	
	public async void check() throws GLib.Error
	{
		yield collect_web_plugins();
	}
	
	public unowned List<WebPlugin?> list_web_plugins()
	{
		return web_plugins;
	}
	
	private async void collect_web_plugins() throws GLib.Error
	{
		if (web_plugins != null)
			return;
		
		var wc = WebKit.WebContext.get_default();
		var plugins = yield wc.get_plugins(null);
		uint n_flash_plugins = 0;
		foreach (var plugin in plugins)
		{
			var name = plugin.get_name();
			var is_flash = name.down().strip() == "shockwave flash";
			web_plugins.append({name, plugin.get_path(), plugin.get_description(), true, is_flash});
			if (is_flash)
				n_flash_plugins++;
		}
		this.n_flash_plugins = n_flash_plugins;
	}

}

public struct WebPlugin
{
	public string name;
	public string path;
	public string description;
	public bool enabled;
	public bool is_flash;
}

} // namespace Nuvola
