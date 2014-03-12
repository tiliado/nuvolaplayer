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

using Nuvola.JSTools;

namespace Nuvola
{

public enum ValueType
{
	STRING, INT, DOUBLE, NULL, JS_VALUE;
}

public class JsEnvironment: GLib.Object
{
	public unowned JS.GlobalContext context {get; private set;}
	private unowned JS.Object? _main_object = null;
	public unowned JS.Object? main_object
	{
		get
		{
			return _main_object;
		}
		set
		{
			if (_main_object != null)
				_main_object.unprotect(context);
			
			_main_object = value;
			if (_main_object != null)
				_main_object.protect(context);
		}
	}
	
	public JsEnvironment(JS.GlobalContext context, JS.Object? main_object)
	{
		this.context = context;
		this.main_object = main_object;
	}
	
	~JsEnvironment()
	{
		main_object = null;
		debug("~JsEnvironment %p", this);
	}
	
	/**
	 * Executes script from file.
	 * 
	 * The script will be executed in a context returned by {@link get_context().
	 * The "this" keyword will refer to {@link object_this} if provided.
	 * 
	 * @param file    script to execute
	 * @return        return value of the script
	 * @throw         JSError on failure
	 */
	public unowned Value execute_script_from_file(File file) throws JSError
	{
		string code;
		try
		{
			code = Diorite.System.read_file(file);
		}
		catch (Error e)
		{
			throw new JSError.READ_ERROR("Unable to read script %s: %s",
				file.get_path(), e.message);
		}
		return execute_script(code, file.get_uri(), 1);
	}
	
	/**
	 * Executes script.
	 * 
	 * The script will be executed in a context returned by {@link get_context()}.
	 * The "this" keyword will refer to {@link object_this} if provided.
	 * 
	 * @param script    script to execute
	 * @return          return value of the script
	 * @throw           JSError on failure
	 */
	public unowned Value execute_script(string script, string path = "about:blank", int line=1) throws JSError
	{ 
		JS.Value exception = null;
		unowned Value value = context.evaluate_script(new JS.String(script), main_object, new JS.String(path), line=0, out exception);
		if (exception != null)
			throw new JSError.EXCEPTION(JSTools.exception_to_string(context, exception));
		return value;
	}
	
	public unowned JS.Value call_function(string name, int argc, ...) throws JSError
	{
		unowned JS.Context ctx = context;
		unowned JS.Object? func = o_get_object(ctx, main_object, name);
		if (func == null)
			throw new JSError.NOT_FOUND("Function '%s' not found.'", name);
	
		if(!func.is_function(ctx))
			throw new JSError.WRONG_TYPE("'%s' is not a function.'", name);
		
		void*[] params = new void*[argc];
		var args = va_list();
		for (var i = 0; i < argc; i++)
		{
			ValueType type = args.arg();
			if (type == ValueType.NULL)
			{
				params[i] = (void*) JS.Value.null(ctx);
			}
			else if (type == ValueType.JS_VALUE)
			{
				unowned JS.Value js_val = args.arg();
				params[i] = (void*) js_val;
			}
			else if (type == ValueType.STRING)
			{
				string str_val = args.arg();
				params[i] = (void*) JS.Value.string(ctx, new JS.String(str_val));
			}
			else if (type == ValueType.INT)
			{
				int int_val = args.arg();
				params[i] = (void*) JS.Value.number(ctx, (double) int_val);
			}
			else if (type == ValueType.DOUBLE)
			{
				double double_val = args.arg();
				params[i] = (void*) JS.Value.number(ctx, double_val);
			}
			else
			{
				throw new JSError.WRONG_TYPE("Unsupported type '%s'.", type.to_string());
			}
		}
		
		JS.Value? exception;
		unowned JS.Value result = func.call_as_function(ctx, main_object, (JS.Value[]) params,  out exception);
		if (exception != null)
			throw new JSError.FUNC_FAILED("Function '%s' failed. %s", name, exception_to_string(ctx, exception) ?? "(null)");
		return result;
	}
	
	public unowned JS.Value call_function_variant(string name, Variant args) throws JSError
	{
		unowned JS.Context ctx = context;
		string[] names = name.split(".");
		unowned JS.Object? object = main_object;
		for (var i = 1; i < names.length - 1; i++)
		{
			object = o_get_object(ctx, object, names[i]);
			if (object == null)
				throw new JSError.NOT_FOUND("Attribute '%s' not found.'", names[i]);
		}
		
		unowned JS.Object? func = o_get_object(ctx, object, names[names.length - 1]);
		if (func == null)
			throw new JSError.NOT_FOUND("Attribute '%s' not found.'", names[names.length - 1]);
		if (!func.is_function(ctx))
			throw new JSError.WRONG_TYPE("'%s' is not a function.'", name);
		
		assert(args.is_container()); // FIXME
		void*[] params = new void*[args.n_children()];
		int i = 0;
		foreach (var item in args)
			params[i++] = (void*) value_from_variant(ctx, item);
		
		JS.Value? exception;
		unowned JS.Value result = func.call_as_function(ctx, object, (JS.Value[]) params,  out exception);
		if (exception != null)
			throw new JSError.FUNC_FAILED("Function '%s' failed. %s", name, exception_to_string(ctx, exception) ?? "(null)");
		return result;
	}
}

} // namespace Nuvola
