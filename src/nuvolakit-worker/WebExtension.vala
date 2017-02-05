/*
 * Copyright 2014-2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WebExtension: GLib.Object
{
	private WebKit.WebExtension extension;
	private Drt.ApiChannel channel;
	private File data_dir;
	private File user_config_dir;
	private JSApi js_api;
	private string? api_token = null;
	private HashTable<string, Variant>? worker_data;
	private LoginFormManager login_form_manager = null;
	private unowned WebKit.WebPage page = null;
	private FrameBridge bridge = null;
	
	public WebExtension(WebKit.WebExtension extension, Drt.ApiChannel channel, HashTable<string, Variant> worker_data)
	{
		this.extension = extension;
		this.channel = channel;
		this.worker_data = worker_data;
		extension.page_created.connect(on_web_page_created);
		WebKit.ScriptWorld.get_default().window_object_cleared.connect(on_window_object_cleared);
	}
	
	private void init()
	{
		ainit.begin((o, res) => {ainit.end(res);});
	}
	
	private async void ainit()
	{
		var router = channel.api_router;
		router.add_method("/nuvola/webworker/call-function", Drt.ApiFlags.WRITABLE,
			"Call JavaScript function.",
			handle_call_function, {
			new Drt.StringParam("name", true, false, null, "Function name."),
			new Drt.VariantParam("params", true, true, null, "Function parameters.")
		});
		router.add_method("/nuvola/webworker/disable-gstreamer", Drt.ApiFlags.WRITABLE,
			"Disable GStreamer",
			handle_disable_gstreamer, null);
		router.add_method("/nuvola/password-manager/enable", Drt.ApiFlags.WRITABLE,
			"Enable Password Manager", handle_enable_password_manager, null);
		router.add_method("/nuvola/password-manager/disable", Drt.ApiFlags.WRITABLE,
			"Disable Password Manager", handle_disable_password_manager, null);
		
		Variant response;
		try
		{
			response = yield channel.call("/nuvola/core/get-data-dir", null);
			data_dir = File.new_for_path(response.get_string());
			response = yield channel.call("/nuvola/core/get-user-config-dir", null);
			user_config_dir = File.new_for_path(response.get_string());
		}
		catch (GLib.Error e)
		{
			error("Runner client error: %s", e.message);
		}
		var storage = new Diorite.XdgStorage.for_project(Nuvola.get_app_id());
		
		/* Use worker_data and free it. */
		uint[] webkit_version = new uint[3];
		webkit_version[0] = worker_data["WEBKITGTK_MAJOR"].get_uint32();
		webkit_version[1] = worker_data["WEBKITGTK_MINOR"].get_uint32();
		webkit_version[2] = worker_data["WEBKITGTK_MICRO"].get_uint32();
		uint[] libsoup_version = new uint[3];
		libsoup_version[0] = worker_data["LIBSOUP_MAJOR"].get_uint32();
		libsoup_version[1] = worker_data["LIBSOUP_MINOR"].get_uint32();
		libsoup_version[2] = worker_data["LIBSOUP_MICRO"].get_uint32();
		api_token = worker_data["NUVOLA_API_ROUTER_TOKEN"].get_string();
		worker_data = null;
		
		js_api = new JSApi(storage, data_dir, user_config_dir, new KeyValueProxy(channel, "config"),
			new KeyValueProxy(channel, "session"), webkit_version, libsoup_version);
		js_api.call_ipc_method_async.connect(on_call_ipc_method_async);
		js_api.call_ipc_method_sync.connect(on_call_ipc_method_sync);
		js_api.call_ipc_method_with_dict_async.connect(on_call_ipc_method_with_dict_async);
		js_api.call_ipc_method_with_dict_sync.connect(on_call_ipc_method_with_dict_sync);
		
		channel.call.begin("/nuvola/core/web-worker-initialized", null, (o, res) =>
		{
			try
			{
				channel.call.end(res);
			}
			catch (GLib.Error e)
			{
				error("Runner client error: %s", e.message);
			}
		});
	}
	
	private void on_window_object_cleared(WebKit.ScriptWorld world, WebKit.WebPage page, WebKit.Frame frame)
	{
		if (page.get_id() != 1)
		{
			debug("Ignoring JavaScript environment of a page with id = %s", page.get_id().to_string());
			return;
		}
		
		if (!frame.is_main_frame())
			return; // TODO: Add api not to ignore non-main frames
		
		debug("Window object cleared for '%s'", frame.get_uri());
		if (frame.get_uri() == WEB_ENGINE_LOADING_URI)
			return;
		
		init_frame(world, page, frame);
	}
	
	private void init_frame(WebKit.ScriptWorld world, WebKit.WebPage page, WebKit.Frame frame)
	{
		this.bridge = null;
		unowned JS.GlobalContext context = (JS.GlobalContext) frame.get_javascript_context_for_script_world(world);
		debug("Init frame: %s, %p, %p, %p", frame.get_uri(), frame, page, context);
		var bridge = new FrameBridge(frame, context);
		try
		{
			js_api.inject(bridge);
			js_api.integrate(bridge);
		}
		catch (GLib.Error e)
		{
			show_error("Failed to inject JavaScript API. %s".printf(e.message));
		}
		this.bridge = bridge;
	}
	
	private Variant? handle_call_function(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		var name = params.pop_string();
		var func_params = params.pop_variant();
		try
		{
			if (bridge != null)
				bridge.call_function(name, ref func_params);
			else
				warning("Bridge is null");
		}
		catch (GLib.Error e)
		{
			show_error("Error during call of %s: %s".printf(name, e.message));
		}
		return func_params;
	}
	
	private Variant? handle_disable_gstreamer(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		return Nuvola.Gstreamer.disable_gstreamer();
	}
	
	private Variant? handle_enable_password_manager(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		Idle.add(enable_password_manager_cb);
		return null;
	}
	
	private bool enable_password_manager_cb()
	{
		if (login_form_manager == null)
			login_form_manager = new LoginFormManager(channel);
		if (page != null)
			login_form_manager.manage_forms(page);
		return false;
	}
	
	private Variant? handle_disable_password_manager(GLib.Object source, Drt.ApiParams? params) throws Diorite.MessageError
	{
		if (login_form_manager != null)
		{
			login_form_manager.clear_forms();
			login_form_manager = null;
		}
		return null;
	}
	
	private void show_error(string message)
	{
		try
		{
			channel.call_sync("/nuvola/core/show-error", new Variant("(s)", message));
		}
		catch (GLib.Error e)
		{
			critical("Failed to send error message '%s'. %s", message, e.message);
		}
	}
	
	private void on_call_ipc_method_async(string name, Variant? data)
	{
		channel.call.begin(name, data, (o, res) =>
		{
			try
			{
				channel.call.end(res);
			}
			catch (GLib.Error e)
			{
				critical("Failed to send message '%s'. %s", name, e.message);
			}
		});
	}
	
	private void on_call_ipc_method_sync(string name, Variant? data, ref Variant? result)
	{
		try
		{
			result = channel.call_sync(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private void on_call_ipc_method_with_dict_async(string name, Variant? data)
	{
		channel.call_with_dict.begin(name, data, (o, res) =>
		{
			try
			{
				channel.call.end(res);
			}
			catch (GLib.Error e)
			{
				critical("Failed to send message '%s'. %s", name, e.message);
			}
		});
	}
	
	private void on_call_ipc_method_with_dict_sync(string name, Variant? data, ref Variant? result)
	{
		try
		{
			result = channel.call_with_dict_sync(name, data);
		}
		catch (GLib.Error e)
		{
			critical("Failed to send message '%s'. %s", name, e.message);
			result = null;
		}
	}
	
	private void on_web_page_created(WebKit.WebExtension extension, WebKit.WebPage web_page)
	{
		debug("Page %u created for %s", (uint) web_page.get_id(), web_page.get_uri());
		if (web_page.get_id() != 1)
			return;
		
		web_page.document_loaded.connect(on_document_loaded);
		#if HAVE_WEBKIT_2_8
		web_page.context_menu.connect(on_context_menu);
		#endif
	}
	
	private void on_document_loaded(WebKit.WebPage page)
	{
		debug("Document loaded %s", page.uri);
		if (page.uri == WEB_ENGINE_LOADING_URI)
		{
			/*
			 * For unknown reason, if the code of the init() method is executed directly in WebExtension constructor,
			 * it blocks window_object_cleared and other signals.
			 */
			init();
		}
		else
		{
			this.page = page;
			var frame = page.get_main_frame();
			/*
			 * If a page doesn't contain any JavaScript, `window_object_cleared` is never called because no JavaScript
			 * GlobalContext is created. Following line ensures GlobalContext is created if it hasn't been before.
			 */
			unowned JS.GlobalContext? context = (JS.GlobalContext) frame.get_javascript_context_for_script_world(
				WebKit.ScriptWorld.get_default());
			return_if_fail(context != null);
			/*
			 * If InitWebWorker is called already in the window_object_cleared callback,
			 * a local filesystem web page sometimes fails to load.
			 */
			channel.call.begin("/nuvola/core/web-worker-ready", null, (o, res) =>
			{
				try
				{
					channel.call.end(res);
				}
				catch (GLib.Error e)
				{
					warning("Runner client error: %s", e.message);
				}
			});
			try
			{
				var args = new Variant("(s)", "InitWebWorker");
				bridge.call_function("Nuvola.core.emit", ref args);
			}
			catch (GLib.Error e)
			{
				show_error("Failed to inject JavaScript API. %s".printf(e.message));
			}
			
			if (login_form_manager != null)
				login_form_manager.manage_forms(page);
		}
	}
	
	#if HAVE_WEBKIT_2_8
	private bool on_context_menu(WebKit.ContextMenu menu, WebKit.WebHitTestResult hit_test)
	{
		if (login_form_manager != null)
			return login_form_manager.manage_context_menu(menu, hit_test.node);
		return false;
	}
	#endif
}

} // namespace Nuvola
