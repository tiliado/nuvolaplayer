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

namespace Nuvola
{

public abstract class WebEngine : GLib.Object, JSExecutor {
	public abstract Gtk.Widget get_main_web_view();
	public WebApp web_app {get; protected set;}
	public WebAppStorage storage {get; protected set;}
	public WebOptions options {get; protected set;}
	public bool ready {get; protected set; default = false;}
	public bool can_go_back {get; protected set; default = false;}
	public bool can_go_forward {get; protected set; default = false;}
	public abstract bool get_web_plugins();
	public abstract void set_web_plugins(bool enabled);
	public abstract bool get_media_source_extension();
	public abstract void set_media_source_extension(bool enabled);
	public WebWorker web_worker {get; protected set;}
	
	public WebEngine(WebOptions options)
	{
		this.options = options;
		this.storage = options.storage;
	}
	
	public signal void init_finished();
	public signal void web_worker_ready();
	public signal void app_runner_ready();
	public signal void init_form(HashTable<string, Variant> values, Variant entries);
	public signal void show_alert_dialog(ref bool handled, string message);
	public signal void context_menu(bool whatewer_fixme_in_future);
	
	public abstract void init();
	
	public abstract void init_app_runner();
	
	public abstract void load_app();
	
	public abstract void go_home();
	
	public abstract void apply_network_proxy(Connection connection);
	
	public abstract void go_back();
	
	public abstract void go_forward();
	
	public abstract void reload();
	
	public abstract void zoom_in();
	
	public abstract void zoom_out();
	
	public abstract void zoom_reset();
	
	public abstract void set_user_agent(string? user_agent);
	
	public abstract void get_preferences(out Variant values, out Variant entries);
	
	public abstract void call_function(string name, ref Variant? params) throws GLib.Error;
}

} // namespace Nuvola
