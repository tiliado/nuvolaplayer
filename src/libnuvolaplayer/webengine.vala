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

using Nuvola.JSTools;

namespace Nuvola
{

public class WebEngine : GLib.Object
{
	public Gtk.Widget widget {get {return web_view;}}
	public WebApp web_app {get; private set;}
	private WebAppController app;
	private WebKit.WebView web_view;
	private JsEnvironment env;
	private JSApi api;
	private JS.GlobalContext ctx_ref;
	
	public WebEngine(WebAppController app, WebApp web_app)
	{
		this.app = app;
		this.web_app = web_app;
		this.web_view = new WebKit.WebView();
		ctx_ref = JS.GlobalContext.create();
		env = new JsEnvironment(ctx_ref, null);
		api = new JSApi(app.storage);
		api.inject(env);
		message("%s", app.storage.user_data_dir.get_path());
		File? main_js = app.storage.user_data_dir.get_child("js").get_child("main.js");
		if (!main_js.query_exists())
		{
			main_js = null;
			foreach (var dir in app.storage.data_dirs)
			{
				main_js = dir.get_child("js").get_child("main.js");
				if (main_js.query_exists())
					break;
				main_js = null;
			}
		}
		
		if (main_js == null)
		{
			critical("Failed to find main.js.");
			return;
		}
		
		try
		{
			env.execute_script_from_file(main_js);
		}
		catch (JSError e)
		{
			warning("JS Error: %s", e.message);
		}
		
		try
		{
			env.execute_script_from_file(web_app.data_dir.get_child("init.js"));
		}
		catch (JSError e)
		{
			warning("JS Error: %s", e.message);
		}
	}
	
	public void load()
	{
		unowned JS.Context ctx = env.context;
		unowned JS.Object result = ctx.make_object();
		o_set_null(ctx, result, "url");
		try
		{
			env.call_function("emit", 2, ValueType.STRING, "home-page", ValueType.JS_VALUE, result);
			var url = o_get_string(ctx, result, "url");
			if (url == null || url == "")
				critical("Failed to get valid home page url.");
			else
				web_view.load_uri(url);
		}
		catch (JSError e)
		{
			critical("Failed to get home url. %s", e.message);
		}
	}
}

} // namespace Nuvola
