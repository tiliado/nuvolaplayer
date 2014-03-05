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
	private JS.GlobalContext? ctx_ref = null;
	private static const string MAIN_JS = "main.js";
	private static const string INIT_JS = "init.js";
	private static const string JS_DIR = "js";
	
	public WebEngine(WebAppController app, WebApp web_app)
	{
		this.app = app;
		this.web_app = web_app;
		this.web_view = new WebKit.WebView();
	}
	
	private bool inject_api()
	{
		if (ctx_ref != null)
			return true;
		ctx_ref = JS.GlobalContext.create();
		env = new JsEnvironment(ctx_ref, null);
		api = new JSApi(app.storage);
		api.inject(env);
		File? main_js = app.storage.user_data_dir.get_child(JS_DIR).get_child(MAIN_JS);
		if (!main_js.query_exists())
		{
			main_js = null;
			foreach (var dir in app.storage.data_dirs)
			{
				main_js = dir.get_child(JS_DIR).get_child(MAIN_JS);
				if (main_js.query_exists())
					break;
				main_js = null;
			}
		}
		
		if (main_js == null)
		{
			app.fatal_error("Initialization error", "%s failed to find a core component main.js. This probably means the application has not been installed correctly or that component has been accidentally deleted.".printf(app.app_name));
			return false;
		}
		
		try
		{
			env.execute_script_from_file(main_js);
		}
		catch (JSError e)
		{
			app.fatal_error("Initialization error", "%s failed to initialize a core component main.js located at '%s'. Initialization exited with error:\n\n%s".printf(app.app_name, main_js.get_path(), e.message));
			return false;
		}
		
		var init_js = web_app.data_dir.get_child(INIT_JS);
		if (!init_js.query_exists())
		{
			app.fatal_error("Initialization error", "%s failed to find a web app component init.js. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.".printf(app.app_name));
			return false;
		}
		try
		{
			env.execute_script_from_file(init_js);
		}
		catch (JSError e)
		{
			app.fatal_error("Initialization error", "%s failed to initialize a web app component init.js located at '%s'. Initialization exited with error:\n\n%s".printf(app.app_name, init_js.get_path(), e.message));
			return false;
		}
		return true;
	}
	
	public bool load()
	{
		if (!inject_api())
			return false;
		
		unowned JS.Context ctx = env.context;
		unowned JS.Object result = ctx.make_object();
		o_set_null(ctx, result, "url");
		try
		{
			env.call_function("emit", 2, ValueType.STRING, "home-page", ValueType.JS_VALUE, result);
			var url = o_get_string(ctx, result, "url");
			if (url == null || url == "")
				app.show_error("Invalid home page URL", "The web app integration script has not provided a valid home page URL.");
			else
				web_view.load_uri(url);
		}
		catch (JSError e)
		{
			app.fatal_error("Initialization error", "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(app.app_name, e.message));
			return false;
		}
		return true;
	}
}

} // namespace Nuvola
