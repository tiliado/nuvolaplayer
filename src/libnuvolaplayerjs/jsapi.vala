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
	private static const string INIT_JS = "init.js";
	private static const string META_JSON = "metadata.json";
	private static const string META_PROPERTY = "meta";
	private static const string JS_DIR = "js";
	/**
	 * Name of file with integration script.
	 */
	private static const string INTEGRATION_FILENAME = "integration.js";
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
	
	public JSApi(Diorite.Storage storage, File data_dir, File config_dir)
	{
		this.storage = storage;
		this.data_dir = data_dir;
		this.config_dir = config_dir;
	}
	
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
		unowned JS.Object main_object = ctx.make_object(klass, null);
		main_object.protect(ctx);
		
		o_set_number(ctx, main_object, "API_VERSION_MAJOR", (double)API_VERSION_MAJOR);
		o_set_number(ctx, main_object, "API_VERSION_MINOR", (double)API_VERSION_MINOR);
		o_set_number(ctx, main_object, "VERSION_MAJOR", (double)VERSION_MAJOR);
		o_set_number(ctx, main_object, "VERSION_MINOR", (double)VERSION_MINOR);
		o_set_number(ctx, main_object, "VERSION_BUGFIX", (double)VERSION_BUGFIX);
		o_set_string(ctx, main_object, "VERSION_SUFFIX", VERSION_SUFFIX);
		
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
		
		var init_js = data_dir.get_child(INIT_JS);
		if (!init_js.query_exists())
			throw new JSError.INITIALIZATION_FAILED("Failed to find a web app component init.js. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.");
		
		try
		{
			env.execute_script_from_file(init_js);
		}
		catch (JSError e)
		{
			throw new JSError.INITIALIZATION_FAILED("Failed to initialize a web app component init.js located at '%s'. Initialization exited with error:\n\n%s", init_js.get_path(), e.message);
		}
	}
	
	/**
	 * Default methods of the main object. Other functions are implemented in JavaScript,
	 * see file main.js
	 */
	private static const JS.StaticFunction[] static_functions =
	{
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
}

} // namespace Nuvola
