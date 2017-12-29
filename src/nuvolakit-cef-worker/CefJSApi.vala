/*
 * Copyright 2011-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

private const string SCRIPT_WRAPPER = "window.__nuvola_func__ = function() {" + "window.__nuvola_func__ = null; "
	+ "if (this == window) throw Error(\"Nuvola object is not bound to 'this'.\"); %s\n;}";
private extern const int VERSION_MAJOR;
private extern const int VERSION_MINOR;
private extern const int VERSION_BUGFIX;
private extern const string VERSION_SUFFIX;

public class CefJSApi : GLib.Object {
	private const string MAIN_JS = "main.js";
	private const string META_JSON = "metadata.json";
	private const string META_PROPERTY = "meta";
	public const string JS_DIR = "js";
	/**
	 * Name of file with integration script.
	 */
	private const string INTEGRATE_JS = "integrate.js";
	/**
	 * Name of file with settings script.
	 */
	private const string SETTINGS_SCRIPT = "settings.js";
	/**
	 * Major version of the JavaScript API
	 */
	public const int API_VERSION_MAJOR = VERSION_MAJOR;
	public const int API_VERSION_MINOR = VERSION_MINOR;
	public const int API_VERSION = API_VERSION_MAJOR * 100 + API_VERSION_MINOR;
	
	private Drt.Storage storage;
	private File data_dir;
	private File config_dir;
	private Drt.KeyValueStorage[] key_value_storages;
	private uint[] webkit_version;
	private uint[] libsoup_version;
	private bool warn_on_sync_func;
	private Cef.V8context? v8_ctx = null;
	private Cef.V8value? main_object = null;
	private CefGtk.RenderSideEventLoop event_loop;
	
	public CefJSApi(CefGtk.RenderSideEventLoop event_loop, Drt.Storage storage, File data_dir, File config_dir,
	Drt.KeyValueStorage config, Drt.KeyValueStorage session,
	uint[] webkit_version, uint[] libsoup_version, bool warn_on_sync_func) {
		Assert.on_glib_thread();
		this.event_loop = event_loop;
		this.storage = storage;
		this.data_dir = data_dir;
		this.config_dir = config_dir;
		this.key_value_storages = {config, session};
		assert(webkit_version.length >= 3);
		this.webkit_version = webkit_version;
		this.libsoup_version = libsoup_version;
		this.warn_on_sync_func = warn_on_sync_func;
	}
	
	public virtual signal void call_ipc_method_void(string name, Variant? data) {
		Assert.on_js_thread();
	}
	
	public virtual signal void call_ipc_method_async(string name, Variant? data, int id) {
		Assert.on_js_thread();
	}
	
	public bool is_valid() {
		Assert.on_js_thread();
		return v8_ctx != null && v8_ctx.is_valid() > 0;
	}
	
	private bool enter_js() {
		Assert.on_js_thread();
		if (is_valid()) {
			v8_ctx.enter();
			return true;
		}
		return false;
	}
	
	private bool exit_js() {
		Assert.on_js_thread();
		if (is_valid()) {
			v8_ctx.exit();
			return true;
		}
		return false;
	}
	
	public void inject(Cef.V8context v8_ctx, HashTable<string, Variant?>? properties=null) throws JSError{
		Assert.on_js_thread();
		if (this.v8_ctx != null) {
			this.v8_ctx = null;
		}
		
		main_object = Cef.v8value_create_object(null, null);
		main_object.ref();
		Cef.V8.set_int(main_object, "API_VERSION_MAJOR", API_VERSION_MAJOR);
		Cef.V8.set_int(main_object, "API_VERSION_MINOR", API_VERSION_MINOR);
		Cef.V8.set_int(main_object, "API_VERSION", API_VERSION);
		Cef.V8.set_int(main_object, "VERSION_MAJOR", VERSION_MAJOR);
		Cef.V8.set_int(main_object, "VERSION_MINOR", VERSION_MINOR);
		Cef.V8.set_int(main_object, "VERSION_MICRO", VERSION_BUGFIX);
		Cef.V8.set_int(main_object, "VERSION_BUGFIX", VERSION_BUGFIX);
		Cef.V8.set_string(main_object, "VERSION_SUFFIX", VERSION_SUFFIX);
		Cef.V8.set_int(main_object, "VERSION", Nuvola.get_encoded_version());
		Cef.V8.set_uint(main_object, "WEBKITGTK_VERSION", get_webkit_version());
		Cef.V8.set_uint(main_object, "WEBKITGTK_MAJOR", webkit_version[0]);
		Cef.V8.set_uint(main_object, "WEBKITGTK_MINOR", webkit_version[1]);
		Cef.V8.set_uint(main_object, "WEBKITGTK_MICRO", webkit_version[2]);
		Cef.V8.set_uint(main_object, "LIBSOUP_VERSION", get_libsoup_version());
		Cef.V8.set_uint(main_object, "LIBSOUP_MAJOR", libsoup_version[0]);
		Cef.V8.set_uint(main_object, "LIBSOUP_MINOR", libsoup_version[1]);
		Cef.V8.set_uint(main_object, "LIBSOUP_MICRO", libsoup_version[2]);
		
		if (properties != null) {
			var iter = HashTableIter<string, Variant?>(properties);
			unowned string key;
			unowned Variant? val;
			while (iter.next(out key, out val)) {
				Cef.V8.set_value(main_object, key, Cef.V8.value_from_variant(val, null));
			}
		}
		
		Cef.V8.set_value(main_object, "_callIpcMethodVoid",
			CefGtk.Function.create("_callIpcMethodVoid", call_ipc_method_void_func));
		Cef.V8.set_value(main_object, "_callIpcMethodAsync",
			CefGtk.Function.create("_callIpcMethodAsync", call_ipc_method_async_func));
		Cef.V8.set_value(main_object, "_keyValueStorageHasKeyAsync",
			CefGtk.Function.create("_keyValueStorageHasKeyAsync", key_value_storage_has_key_async_func));
		Cef.V8.set_value(main_object, "_keyValueStorageGetValueAsync",
			CefGtk.Function.create("_keyValueStorageGetValueAsync", key_value_storage_get_value_async_func));
		Cef.V8.set_value(main_object, "_keyValueStorageSetValueAsync",
			CefGtk.Function.create("_keyValueStorageSetValueAsync", key_value_storage_set_value_async_func));
		Cef.V8.set_value(main_object, "_keyValueStorageSetDefaultValueAsync",
			CefGtk.Function.create("_keyValueStorageSetDefaultValueAsync",
				key_value_storage_set_default_value_async_func));
		Cef.V8.set_value(main_object, "_log", CefGtk.Function.create("_log", log_func));
		Cef.V8.set_value(main_object, "_warn", CefGtk.Function.create("_warn", warn_func));

		File? main_js = storage.user_data_dir.get_child(JS_DIR).get_child(MAIN_JS);
		if (!main_js.query_exists()) {
			main_js = null;
			foreach (var dir in storage.data_dirs) {
				main_js = dir.get_child(JS_DIR).get_child(MAIN_JS);
				if (main_js.query_exists()) {
					break;
				}
				main_js = null;
			}
		}
		
		if (main_js == null) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed to find a core component main.js. This probably means the application has not been"
				+ " installed correctly or that component has been accidentally deleted.");
		}
		try {
			execute_script_from_file(v8_ctx, main_js);
		} catch (JSError e) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed to initialize a core component main.js located at '%s'. Initialization exited with error: %s",
				main_js.get_path(), e.message);
		}
		
		var meta_json = data_dir.get_child(META_JSON);
		if (!meta_json.query_exists()) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed to find a web app component %s. This probably means the web app integration has not been"
				+ " installed correctly or that component has been accidentally deleted.", META_JSON);
		}
		string meta_json_data;
		try {
			meta_json_data = Drt.System.read_file(meta_json);
		} catch (GLib.Error e) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed load a web app component %s. This probably means the web app integration has not been"
				+ " installed correctly or that component has been accidentally deleted.\n\n%s", META_JSON, e.message);
		}
		
		string? json_error = null; 
		var meta = Cef.V8.parse_json(v8_ctx, meta_json_data, out json_error);
		if (meta == null) {
			throw new JSError.INITIALIZATION_FAILED("Failed to parse metadata.json. %s", json_error);
		}
		Cef.V8.set_value(main_object, "meta", meta);
	}
	
	public void integrate(Cef.V8context v8_ctx) throws JSError{
		Assert.on_js_thread();
		var integrate_js = data_dir.get_child(INTEGRATE_JS);
		if (!integrate_js.query_exists()) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed to find a web app component %s. This probably means the web app integration has not been"
				+ " installed correctly or that component has been accidentally deleted.", INTEGRATE_JS);
		}
		try {
			execute_script_from_file(v8_ctx, integrate_js);
		} catch (JSError e) {
			throw new JSError.INITIALIZATION_FAILED(
				"Failed to initialize a web app component %s located at '%s'. Initialization exited with error:\n\n%s",
				INTEGRATE_JS, integrate_js.get_path(), e.message);
		}
	}
	
	public void release_context(Cef.V8context v8_ctx) {
		Assert.on_js_thread();
		if (v8_ctx == this.v8_ctx) {
			this.v8_ctx = null;
		}
	}
	
	public void acquire_context(Cef.V8context v8_ctx) {
		Assert.on_js_thread();
		this.v8_ctx = v8_ctx;
	}
	
	public void execute_script_from_file(Cef.V8context v8_ctx, File file) throws JSError {
		Assert.on_js_thread();
		string script;
		try {
			script = Drt.System.read_file(file);
		} catch (GLib.Error e) 	{
			throw new JSError.READ_ERROR("Unable to read script %s: %s", file.get_path(), e.message);
		}
		execute_script(v8_ctx, script, file.get_uri(), 1);
	}
	
	public void execute_script(Cef.V8context v8_ctx, string script, string path, int line) throws JSError {
		Assert.on_js_thread();
		assert(v8_ctx != null);
        Cef.String _script = {};
        var wrapped_script = SCRIPT_WRAPPER.printf(script).replace("\t", " ");
//~         stderr.puts(wrapped_script);
        Cef.set_string(&_script, wrapped_script);
        Cef.String _path = {};
        Cef.set_string(&_path, path);
        Cef.V8value? retval = null;
        Cef.V8exception? exception = null;
        var result = (bool) v8_ctx.eval(&_script, &_path, line, out retval, out exception);
        if (exception != null) {
			throw new JSError.EXCEPTION(Cef.V8.format_exception(exception));
		}
		if (!result) {
			throw new JSError.EXCEPTION("Failed to execute script '%s'.", path);
		}
		var global_object = v8_ctx.get_global();
		var func = Cef.V8.get_function(global_object, "__nuvola_func__");
		assert(func != null);
		main_object.ref();
		var ret_val = func.execute_function(main_object, {});
		if (ret_val == null) {
			throw new JSError.EXCEPTION(Cef.V8.format_exception(func.get_exception()));
		}
	}
	
	public void send_async_response(int id, Variant? response, GLib.Error? error) throws GLib.Error {
		Assert.on_glib_thread();
		var args = new Variant("(imvmv)", (int32) id, response,
			error == null ? null : new Variant.string(error.message));
		if (response != null) {
			// FIXME: How are we losing a reference here?
			g_variant_ref(response);
		}
		call_function_sync("Nuvola.Async.respond", args, false);
	}
	
	public Variant? call_function_sync(string name, Variant? args, bool propagate_error) throws GLib.Error {
		Assert.on_glib_thread();
		GLib.Error? error = null;
		Variant? result = null;
		var loop = new MainLoop(MainContext.get_thread_default());
		CefGtk.Task.post(Cef.ThreadId.RENDERER, () => {
			Assert.on_js_thread();
			try {
				if (!enter_js()) {
					throw new JSError.NO_CONTEXT("JS Context is not valid.");
				}
				string[] names = name.split(".");
				Cef.V8value object = main_object;
				if (object == null) {
					throw new JSError.NOT_FOUND("Main object not found.'");
				} 
				for (var i = 1; i < names.length - 1; i++) {
					object = Cef.V8.get_object(object, names[i]);
					if (object == null) {
						throw new JSError.NOT_FOUND("Attribute '%s' not found.'", names[i]);
					}
				}
				var func = Cef.V8.get_function(object, names[names.length - 1]);
				if (func == null) {
					throw new JSError.NOT_FOUND("Attribute '%s' not found.'", names[names.length - 1]);
				}  
				Cef.V8value[] params;
				var size = 0;
				if (args != null) {
					assert(args.is_container()); // FIXME
					size = (int) args.n_children();
					params = new Cef.V8value[size];
					int i = 0;
					foreach (var item in args) {
						string? exception = null;
						var param = Cef.V8.value_from_variant(item, out exception);
						if (param == null) {
							throw new JSError.WRONG_TYPE(exception);
						}
						params[i++] = param;
					}
					foreach (var p in params) {
						p.ref();
					}
				} else {
					params = {};
				}
				object.ref();
				var ret_val = func.execute_function(object, params);
				if (ret_val == null) {
					throw new JSError.FUNC_FAILED("Function '%s' failed. %s",
						name, Cef.V8.format_exception(func.get_exception()));
				}
				if (args != null && ret_val.is_undefined() == 0) {
					if (ret_val.is_array() != 0) {
						int n_items = ret_val.get_array_length();
						var items = new Variant[n_items];
						for (int i = 0; i < n_items; i++) {
				            items[i] = Cef.V8.variant_from_value(ret_val.get_value_byindex(i), null);
				        }
						result = new Variant.tuple(items);
				    } else {
						result = Cef.V8.variant_from_value(ret_val, null);
					}
				}
			} catch (GLib.Error e) {
				error = e;
			} finally {
				exit_js();
			}
			loop.quit();
		});
		if (error != null) {
			throw error;
		}
		loop.run();
		return result;
	}
	
	public uint get_webkit_version() {
		return webkit_version[0] * 10000 + webkit_version[1] * 100 + webkit_version[2];
	}
	
	public uint get_libsoup_version() {
		return libsoup_version[0] * 10000 + libsoup_version[1] * 100 + libsoup_version[2];
	}
	
	private void call_ipc_method_void_func(string? name, Cef.V8value? object, Cef.V8value?[] arguments,
    out Cef.V8value? retval, out string? exception) {
		call_ipc_method_func(name, object, arguments, out retval, out exception, true);
	}
	
	private void call_ipc_method_async_func(string? name, Cef.V8value? object, Cef.V8value?[] arguments,
    out Cef.V8value? retval, out string? exception) {
		call_ipc_method_func(name, object, arguments, out retval, out exception, false);
	}
	
	private void call_ipc_method_func(string? name, Cef.V8value? object, Cef.V8value?[] args,
    out Cef.V8value? retval, out string? exception, bool is_void) {
		Assert.on_js_thread();
		retval = null;
		exception = null;
		if (args.length == 0) {
			exception = "At least one argument required.";
			return;
		}
		
		var method = Cef.V8.string_or_null(args[0]);
		if (method == null) {
			exception = "The first argument must be a non-null string.";
			return;
		}
		
		Variant? data = null;
		if (args.length > 1 && args[1].is_null() == 0) {
			data = Cef.V8.variant_from_value(args[1], out exception);
			if (data == null) {
				return;
			}
		}
		/* Void call */
		if (is_void) {
			call_ipc_method_void(method, data);
			retval = Cef.v8value_create_undefined();
			return;
		}
		/* Async call */
		int id = -1;
		if (args.length > 2) {
			id = Cef.V8.any_int(args[2]);
		}
		if (id <= 0) {
			exception = "Argument %d: Integer expected (%d).".printf(2, id);
		} else {
			call_ipc_method_async(method, data, id);
		}
	}
	
	private void key_value_storage_has_key_async_func(string? name, Cef.V8value? object, Cef.V8value?[] args,
    out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		if (args.length != 3) {
			exception = "Three arguments required.";
			return;
		}
		if (args[0].is_int() == 0) {
			exception = "Argument 0 must be a number.";
			return;
		}
		int index = args[0].get_int_value();		
		var key = Cef.V8.string_or_null(args[1]);
		if (key == null) {
			exception = "The first argument must be a non-null string";
			return;
		}
		if (key_value_storages.length <= index) {
			exception = "Unknown storage.";
			return;
		}
		
		var storage = key_value_storages[index];
		var id = Cef.V8.any_int(args[2]);
		event_loop.add_idle(() => {
			storage.has_key_async.begin(key, (o, res) => {
				var result = storage.has_key_async.end(res);
				try {
					send_async_response(id, result, null);
				} catch (GLib.Error e) {
					critical("Failed to send async response: %s", e.message);
				}
			});
			return false;
		});
	}
	
	private void key_value_storage_get_value_async_func(string? name, Cef.V8value? object, Cef.V8value?[] args,
    out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		
		if (args.length != 3) {
			exception = "Three arguments required.";
			return;
		}
		if (args[0].is_int() == 0) {
			exception = "Argument 0 must be a number.";
			return;
		}
		int index = args[0].get_int_value();		
		var key = Cef.V8.string_or_null(args[1]);
		if (key == null) {
			exception = "The first argument must be a non-null string";
			return;
		}
		if (key_value_storages.length <= index) {
			exception = "Unknown storage.";
			return;
		}
		
		var storage = key_value_storages[index];
		var id = Cef.V8.any_int(args[2]);
		event_loop.add_idle(() => {
			storage.get_value_async.begin(key, (o, res) => {
				var value = storage.get_value_async.end(res);
				try {
					send_async_response(id, value, null);
				} catch (GLib.Error e) {
					critical("Failed to send async response: %s", e.message);
				}
			});
			return false;
		});
	}
	
	private void key_value_storage_set_value_async_func(string? name, Cef.V8value? object, Cef.V8value?[] args,
    out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		
		if (args.length != 4) {
			exception = "Four arguments required.";
			return;
		}
		if (args[0].is_int() == 0) {
			exception = "Argument 0 must be a number.";
			return;
		}
		int index = args[0].get_int_value();		
		var key = Cef.V8.string_or_null(args[1]);
		if (key == null) {
			exception = "The first argument must be a non-null string";
			return;
		}
		if (key_value_storages.length <= index) {
			exception = "Unknown storage.";
			return;
		}
		
		Variant? value = args[2].is_undefined() == 1 ? null : Cef.V8.variant_from_value(args[2], out exception);
		if (exception != null) {
			return;
		}
		
		var storage = key_value_storages[index];
		var id = Cef.V8.any_int(args[3]);
		event_loop.add_idle(() => {
			storage.set_value_async.begin(key, value, (o, res) => {
				storage.set_value_async.end(res);
				try {
					send_async_response(id, null, null);
				} catch (GLib.Error e) {
					critical("Failed to send async response: %s", e.message);
				}
			});
			return false;
		});
	}
	
	private void key_value_storage_set_default_value_async_func(string? name, Cef.V8value? object,
	Cef.V8value?[] args, out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		
		if (args.length != 4) {
			exception = "Four arguments required.";
			return;
		}
		if (args[0].is_int() == 0) {
			exception = "Argument 0 must be a number.";
			return;
		}
		int index = args[0].get_int_value();		
		var key = Cef.V8.string_or_null(args[1]);
		if (key == null) {
			exception = "The first argument must be a non-null string";
			return;
		}
		if (key_value_storages.length <= index) {
			exception = "Unknown storage.";
			return;
		}
		
		Variant? value = args[2].is_undefined() == 1 ? null : Cef.V8.variant_from_value(args[2], out exception);
		if (exception != null) {
			return;
		}
		
		var storage = key_value_storages[index];
		var id = Cef.V8.any_int(args[3]);
		event_loop.add_idle(() => {
			storage.set_default_value_async.begin(key, value, (o, res) => {
				storage.set_default_value_async.end(res);
				try {
					send_async_response(id, null, null);
				} catch (GLib.Error e) {
					critical("Failed to send async response: %s", e.message);
				}
			});
			return false;
		});
	}
	
	private void log_func(string? name, Cef.V8value? object,
	Cef.V8value?[] args, out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		for (var i = 0; i < args.length; i++) {
			if (args[i].is_undefined() == 1) {
				debug("Nuvola.log: undefined");
			} else {
				var val = Cef.V8.variant_from_value( args[i], out exception);
				if (exception != null) {
					retval = null;
					return;
				}
				debug("Nuvola.log: %s", val.print(false));
			}
		}
	}
	
	private void warn_func(string? name, Cef.V8value? object,
	Cef.V8value?[] args, out Cef.V8value? retval, out string? exception) {
		Assert.on_js_thread();
		retval = Cef.v8value_create_undefined();
		exception = null;
		for (var i = 0; i < args.length; i++) {
			if (args[i].is_undefined() == 1) {
				warning("Nuvola.warn: undefined");
			} else {
				var val = Cef.V8.variant_from_value( args[i], out exception);
				if (exception != null) {
					retval = null;
					return;
				}
				warning("Nuvola.warn: %s", val.print(false));
			}
		}
	}
}

} // namespace Nuvola

// FIXME
private extern Variant* g_variant_ref(Variant* variant);
