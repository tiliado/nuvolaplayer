/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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
using JS;
using Nuvola.JSTools;

namespace Nuvola
{

/**
 * Errors thrown from Nuvola Palyer JavaScript API
 */
public errordomain JSError
{
	/**
	 * An object has not been found
	 */
	NOT_FOUND,
	/**
	 * A value has wrong type
	 */
	WRONG_TYPE,
	/**
	 * Call of a JavaScript function failed.
	 */
	FUNC_FAILED,
	/**
	 * Unable to load script from file
	 */
	READ_ERROR,
	/**
	 * JavaScript API does not have any context yet.
	 */
	NO_CONTEXT,
	/**
	 * Execution of a script caused an exception.
	 */
	EXCEPTION,
	
	INITIALIZATION_FAILED;
}


/**
 * Nuvola JavaScript API provides interface for service integrations to communicate
 * with Nuvola Player runtime. Practically, it is a bridge between Service object
 * and JavaScript environment of WebKit WebView.
 * 
 * Main method of the main Nuvola Player JavaScript object are implemented here,
 * other helper functions and tools are loaded from a JavaScript file.
 */
public class JSApi : GLib.Object
{
	private static const string MAIN_JS = "main.js";
	private static const string META_JSON = "metadata.json";
	private static const string META_PROPERTY = "meta";
	private static const string JS_DIR = "js";
	/**
	 * Name of file with integration script.
	 */
	private static const string INTEGRATE_JS = "integrate.js";
	/**
	 * Name of file with settings script.
	 */
	private static const string SETTINGS_SCRIPT = "settings.js";
	/**
	 * Major version of the JavaScript API
	 */
	public static const int API_VERSION_MAJOR = 3;
	public static const int API_VERSION_MINOR = 0;
	
	private static unowned JS.Class klass;
	/**
	 * Identifier of the main frame
	 */
	public static const string MAIN_FRAME_ID = "__main__";
	/**
	 * Identifier of the frame for service's preferences.
	 */
	public static const string PREFERENCES_FRAME_ID = "__preferences__";
	
	private Diorite.Storage storage;
	private File data_dir;
	private File config_dir;
	private Diorite.KeyValueStorage[] key_value_storages;
	private uint[] webkit_version;
	
	public JSApi(Diorite.Storage storage, File data_dir, File config_dir, Diorite.KeyValueStorage config,
	Diorite.KeyValueStorage session, uint[] webkit_version)
	{
		this.storage = storage;
		this.data_dir = data_dir;
		this.config_dir = config_dir;
		this.key_value_storages = {config, session};
		assert(webkit_version.length >= 3);
		this.webkit_version = webkit_version;
	}
	
	public static bool is_supported(int api_major, int api_minor)
	{
		return api_major == API_VERSION_MAJOR && api_minor <= API_VERSION_MINOR;
	}
	
	public uint get_webkit_version()
	{
		return webkit_version[0] * 10000 + webkit_version[1] * 100 + webkit_version[2];
	}
	
	public signal void send_message_async(string name, Variant? data);
	public signal void send_message_sync(string name, Variant? data, ref Variant? result);
	
	/**
	 * Creates the main object and injects it to the JavaScript context
	 * 
	 * @param env    JavaScript environment to use for injection
	 */
	public void inject(JsEnvironment env) throws JSError
	{
		unowned JS.Context ctx = env.context;
		if (klass == null)
			create_class();
		unowned JS.Object main_object = ctx.make_object(klass, this);
		main_object.protect(ctx);
		
		o_set_number(ctx, main_object, "API_VERSION_MAJOR", (double)API_VERSION_MAJOR);
		o_set_number(ctx, main_object, "API_VERSION_MINOR", (double)API_VERSION_MINOR);
		o_set_number(ctx, main_object, "VERSION_MAJOR", (double)VERSION_MAJOR);
		o_set_number(ctx, main_object, "VERSION_MINOR", (double)VERSION_MINOR);
		o_set_number(ctx, main_object, "VERSION_BUGFIX", (double)VERSION_BUGFIX);
		o_set_string(ctx, main_object, "VERSION_SUFFIX", VERSION_SUFFIX);
		o_set_number(ctx, main_object, "WEBKITGTK_VERSION", (double) get_webkit_version());
		o_set_number(ctx, main_object, "WEBKITGTK_MAJOR", (double) webkit_version[0]);
		o_set_number(ctx, main_object, "WEBKITGTK_MINOR", (double) webkit_version[1]);
		o_set_number(ctx, main_object, "WEBKITGTK_MICRO", (double) webkit_version[2]);
		
		env.main_object = main_object;
		main_object.unprotect(ctx);
		
		File? main_js = storage.user_data_dir.get_child(JS_DIR).get_child(MAIN_JS);
		if (!main_js.query_exists())
		{
			main_js = null;
			foreach (var dir in storage.data_dirs)
			{
				main_js = dir.get_child(JS_DIR).get_child(MAIN_JS);
				if (main_js.query_exists())
					break;
				main_js = null;
			}
		}
		
		if (main_js == null)
			throw new JSError.INITIALIZATION_FAILED("Failed to find a core component main.js. This probably means the application has not been installed correctly or that component has been accidentally deleted.");
		
		try
		{
			env.execute_script_from_file(main_js);
		}
		catch (JSError e)
		{
			throw new JSError.INITIALIZATION_FAILED("Failed to initialize a core component main.js located at '%s'. Initialization exited with error:\n\n%s", main_js.get_path(), e.message);
		}
		
		var meta_json = data_dir.get_child(META_JSON);
		if (!meta_json.query_exists())
			throw new JSError.INITIALIZATION_FAILED("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", META_JSON);
		
		string meta_json_data;
		try
		{
			meta_json_data = Diorite.System.read_file(meta_json);
		}
		catch (GLib.Error e)
		{
			throw new JSError.INITIALIZATION_FAILED("Failed load a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.\n\n%s", META_JSON, e.message);
		}
		
		unowned JS.Value meta = object_from_JSON(ctx, meta_json_data);
		env.main_object.set_property(ctx, new JS.String(META_PROPERTY), meta);
	}
	
	public void initialize(JsEnvironment env) throws JSError
	{
		integrate(env);
	}
	
	public void integrate(JsEnvironment env) throws JSError
	{
		var integrate_js = data_dir.get_child(INTEGRATE_JS);
		if (!integrate_js.query_exists())
			throw new JSError.INITIALIZATION_FAILED("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", INTEGRATE_JS);
		
		try
		{
			env.execute_script_from_file(integrate_js);
		}
		catch (JSError e)
		{
			throw new JSError.INITIALIZATION_FAILED("Failed to initialize a web app component %s located at '%s'. Initialization exited with error:\n\n%s", INTEGRATE_JS, integrate_js.get_path(), e.message);
		}
	}
	
	/**
	 * Default methods of the main object. Other functions are implemented in JavaScript,
	 * see file main.js
	 */
	private static const JS.StaticFunction[] static_functions =
	{
		{"_sendMessageAsync", send_message_async_func, 0},
		{"_sendMessageSync", send_message_sync_func, 0},
		{"_keyValueStorageHasKey", key_value_storage_has_key_func, 0},
		{"_keyValueStorageGetValue", key_value_storage_get_value_func, 0},
		{"_keyValueStorageSetValue", key_value_storage_set_value_func, 0},
		{"_keyValueStorageSetDefaultValue", key_value_storage_set_default_value_func, 0},
		{"_log", log_func, 0},
		{"_warn", warn_func, 0},
		{null, null, 0}
	};
	
	/**
	 * Creates Nuvola Player main object class description
	 */
	private static void create_class()
	{
		unowned ClassDefinition class_def =
		{
			1,
			JS.ClassAttribute.None,
			"Nuvola JavaScript API",
			null,   
			null,
			static_functions,
			null, 
			null, 
			null, 
			null,
			null, 
			null, 
			null, 
			null, 
			null, 
			null, 
			null  
		};
		klass = JS.create_class(class_def);
		klass.retain();
	}
	
	static unowned JS.Value send_message_async_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		return send_message_func(ctx, function, self, args, out exception, true);
	}
	
	static unowned JS.Value send_message_sync_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		return send_message_func(ctx, function, self, args, out exception, false);
	}
	
	static unowned JS.Value send_message_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception, bool @async)
	{
		unowned JS.Value undefined = JS.Value.undefined(ctx);
		exception = null;
		if (args.length == 0)
		{
			exception = create_exception(ctx, "At least one argument required.");
			return undefined;
		}
		
		var name = string_or_null(ctx, args[0]);
		if (name == null)
		{
			exception = create_exception(ctx, "The first argument must be a non-null string");
			return undefined;
		}
		
		var js_api = (self.get_private() as JSApi);
		if (js_api == null)
		{
			exception = create_exception(ctx, "JSApi is null");
			return undefined;
		}
		
		Variant? data = null;
		if (args.length > 1)
		{
			Variant[] tuple = new Variant[args.length - 1];
			for (var i = 1; i < args.length; i++)
			{
				try
				{
					tuple[i - 1] = variant_from_value(ctx, args[i]);
				}
				catch (JSError e)
				{
					exception = create_exception(ctx, "Argument %d: %s".printf(i, e.message));
					return undefined;
				}
			}
			data = new Variant.tuple(tuple);
		}
		
		if (@async)
		{
			js_api.send_message_async(name, data);
			return undefined;
		}
		
		Variant? result = null;
		js_api.send_message_sync(name, data, ref result);
		
		try
		{
			return value_from_variant(ctx, result);
		}
		catch (JSError e)
		{
			exception = create_exception(ctx, "Failed to parse response. %s".printf(e.message));
			return undefined;
		}
	}
	
	static unowned JS.Value key_value_storage_has_key_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		unowned JS.Value _false = JS.Value.boolean(ctx, false);
		exception = null;
		if (args.length != 2)
		{
			exception = create_exception(ctx, "Two arguments required.");
			return _false;
		}
		
		if (!args[0].is_number(ctx))
		{
			exception = create_exception(ctx, "Argument 0 must be a number.");
			return _false;
		}
		
		int index = (int) args[0].to_number(ctx);
		
		var key = string_or_null(ctx, args[1]);
		if (key == null)
		{
			exception = create_exception(ctx, "The first argument must be a non-null string");
			return _false;
		}
		
		var js_api = (self.get_private() as JSApi);
		if (js_api == null)
		{
			exception = create_exception(ctx, "JSApi is null");
			return _false;
		}
		
		if (js_api.key_value_storages.length <= index)
			return _false;
		
		return JS.Value.boolean(ctx, js_api.key_value_storages[index].has_key(key));
	}
	
	static unowned JS.Value key_value_storage_get_value_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		unowned JS.Value undefined = JS.Value.undefined(ctx);
		exception = null;
		if (args.length != 2)
		{
			exception = create_exception(ctx, "Two arguments required.");
			return undefined;
		}
		
		if (!args[0].is_number(ctx))
		{
			exception = create_exception(ctx, "Argument 0 must be a number.");
			return undefined;
		}
		
		int index = (int) args[0].to_number(ctx);
		var key = string_or_null(ctx, args[1]);
		if (key == null)
		{
			exception = create_exception(ctx, "Argument 1 must be a non-null string");
			return undefined;
		}
		
		var js_api = (self.get_private() as JSApi);
		if (js_api == null)
		{
			exception = create_exception(ctx, "JSApi is null");
			return undefined;
		}
		
		if (js_api.key_value_storages.length <= index)
			return undefined;
		
		var value = js_api.key_value_storages[index].get_value(key);
		if (value == null)
			return undefined;
		
		try
		{
			return value_from_variant(ctx, value);
		}
		catch (JSError e)
		{
			exception = create_exception(ctx, "Failed to convert Variant to JavaScript value. %s".printf(e.message));
			return undefined;
		}
	}
	
	static unowned JS.Value key_value_storage_set_value_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		unowned JS.Value undefined = JS.Value.undefined(ctx);
		exception = null;
		if (args.length != 3)
		{
			exception = create_exception(ctx, "Three arguments required.");
			return undefined;
		}
		
		if (!args[0].is_number(ctx))
		{
			exception = create_exception(ctx, "Argument 0 must be a number.");
			return undefined;
		}
		
		int index = (int) args[0].to_number(ctx);
		var key = string_or_null(ctx, args[1]);
		if (key == null)
		{
			exception = create_exception(ctx, "Argument 1 must be a non-null string");
			return undefined;
		}
		
		var js_api = (self.get_private() as JSApi);
		if (js_api == null)
		{
			exception = create_exception(ctx, "JSApi is null");
			return undefined;
		}
		
		if (js_api.key_value_storages.length <= index)
			return undefined;
		
		try
		{
			var value = args[2].is_undefined(ctx) ? null : variant_from_value(ctx, args[2]);
			js_api.key_value_storages[index].set_value(key, value);
		}
		catch (JSError e)
		{
			exception = create_exception(ctx, "Failed to convert JavaScript value to Variant. %s".printf(e.message));
		}
		
		return undefined;
	}
	
	static unowned JS.Value key_value_storage_set_default_value_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		unowned JS.Value undefined = JS.Value.undefined(ctx);
		exception = null;
		if (args.length != 3)
		{
			exception = create_exception(ctx, "Three arguments required.");
			return undefined;
		}
		
		if (!args[0].is_number(ctx))
		{
			exception = create_exception(ctx, "Argument 0 must be a number.");
			return undefined;
		}
		
		int index = (int) args[0].to_number(ctx);
		var key = string_or_null(ctx, args[1]);
		if (key == null)
		{
			exception = create_exception(ctx, "Argument 1 must be a non-null string");
			return undefined;
		}
		
		var js_api = (self.get_private() as JSApi);
		if (js_api == null)
		{
			exception = create_exception(ctx, "JSApi is null");
			return undefined;
		}
		
		if (js_api.key_value_storages.length <= index)
			return undefined;
		
		try
		{
			var value = args[2].is_undefined(ctx) ? null : variant_from_value(ctx, args[2]);
			js_api.key_value_storages[index].set_default_value(key, value);
		}
		catch (JSError e)
		{
			exception = create_exception(ctx, "Failed to convert JavaScript value to Variant. %s".printf(e.message));
		}
		
		return undefined;
	}
	
	static unowned JS.Value log_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		exception = null;
		for (var i = 0; i < args.length; i++)
		{
			if (args[i].is_undefined(ctx))
			{
				debug("Nuvola.log: undefined");
			}
			else
			{
				try
				{
					debug("Nuvola.log: %s", variant_from_value(ctx, args[i]).print(false));
				}
				catch (JSError e)
				{
					warning("Nuvola.log (JSError): %s", e.message);
				}
			}
		}
		return JS.Value.undefined(ctx);
	}
	
	static unowned JS.Value warn_func(Context ctx, JS.Object function, JS.Object self, JS.Value[] args, out unowned JS.Value exception)
	{
		exception = null;
		for (var i = 0; i < args.length; i++)
		{
			if (args[i].is_undefined(ctx))
			{
				warning("Nuvola.warn: undefined");
			}
			else
			{
				try
				{
					warning("Nuvola.warn: %s", variant_from_value(ctx, args[i]).print(false));
				}
				catch (JSError e)
				{
					warning("Nuvola.warn (JSError): %s", e.message);
				}
			}
		}
		return JS.Value.undefined(ctx);
	}
}

} // namespace Nuvola
