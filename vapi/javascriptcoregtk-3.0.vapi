/*
Manually created, incomplete, buggy

Copyright 2011 Jiří Janoušek <janousek.jiri@gmail.com>

*/
[CCode (lower_case_cprefix = "JS", cheader_filename = "JavaScriptCore/JavaScript.h")]
namespace JS{
	[Compact]
	[CCode (cname="const struct OpaqueJSContext", free_function = "")]
	public class Context {
		[CCode (cname = "JSContextGetGlobalObject")]
		public unowned JS.Object get_global_object();
		[CCode (cname = "JSObjectMake")]
		public unowned JS.Object make_object(Class? @class=null, void* @private=null);
		[CCode (cname = "JSObjectMakeArray")]
		public unowned JS.Object make_array([CCode (array_length_pos=0.1, array_length_type="size_t")] Value[] args, out JS.Value exception=null);
		[CCode (cname = "JSObjectMakeFunctionWithCallback")]
		public unowned JS.Object make_function(JS.String? name, JS.ObjectCallAsFunctionCallback callback);
		[CCode (cname = "JSGarbageCollect")]
		public void collect_garbage();
		[CCode (cname = "JSEvaluateScript")]
		public unowned Value evaluate_script(JS.String script, JS.Object? self= null, JS.String? url=null, int line=0, out JS.Value exception=null);
	}
	
	[Compact]
	[CCode (cname="struct OpaqueJSContext", free_function = "JSGlobalContextRelease")]
	public class GlobalContext : JS.Context
	{
		[CCode (cname = "JSGlobalContextCreate")]
		public static GlobalContext create(Class? klass=null);
		
		[CCode (cname = "JSGlobalContextRelease")]
		public void release();
		
		[CCode (cname = "JSGlobalContextRetain")]
		public GlobalContext retain();
	}
	
	[Compact]
	[CCode(cname="const struct OpaqueJSValue", free_function="")]
	public class Value{
		[CCode (cname = "JSValueMakeUndefined")]
		public static unowned Value undefined (Context ctx);
		
		[CCode (cname = "JSValueMakeNull")]
		public static unowned Value @null (Context ctx);
		
		[CCode (cname = "JSValueMakeString")]
		public static unowned Value string (Context ctx, String js_string);
		
		[CCode (cname = "JSValueMakeNumber")]
		public static unowned Value number (Context ctx, double number);
		
		[CCode (cname = "JSValueMakeBoolean")]
		public static unowned Value boolean (Context ctx, bool value);
		
		[CCode (cname = "JSValueIsUndefined", instance_pos=1.1)]
		public bool is_undefined (Context ctx);

		[CCode (cname = "JSValueIsNull", instance_pos=1.1)]
		public bool is_null (Context ctx);

		[CCode (cname = "JSValueIsBoolean", instance_pos=1.1)]
		public bool is_boolean (Context ctx);

		[CCode (cname = "JSValueIsNumber", instance_pos=1.1)]
		public bool is_number (Context ctx);

		[CCode (cname = "JSValueIsString", instance_pos=1.1)]
		public bool is_string (Context ctx);

		[CCode (cname = "JSValueIsObject", instance_pos=1.1)]
		public bool is_object (Context ctx);
		
		[CCode (cname = "JSValueToStringCopy", instance_pos=1.1)]
		public JS.String to_jsstring (Context ctx, Value *exception=null);

		[CCode (cname = "JSValueToObject", instance_pos=1.1)]
		public unowned Object to_object (Context ctx, Value *exception=null);
		
		[CCode (cname = "JSValueToBoolean", instance_pos=1.1)]
		public bool to_boolean (Context ctx);
		
		[CCode (cname = "JSValueToNumber", instance_pos=1.1)]
		public double to_number (Context ctx, Value *exception=null);
		
		[CCode (cname = "JSValueMakeFromJSONString")]
		public static unowned Value from_JSON (Context ctx, String js_string);
		
		[CCode (cname = "JSValueCreateJSONString", instance_pos=1.1)]
		public JS.String to_JSON (Context ctx, uint indent, out Value? exception=null);
		
		[CCode (cname = "JSValueUnprotect", instance_pos=1.1)]
		public void unprotect(Context ctx);
		
		[CCode (cname = "JSValueProtect", instance_pos=1.1)]
		public void protect(Context ctx);
	}
	
	[Compact]
	[CCode(cname="struct OpaqueJSValue", free_function="")]
	public class Object: JS.Value{
		[CCode (cname="JSObjectGetPrivate")]
		public void* get_private();
		[CCode (cname = "JSObjectSetPrivate")]
		public bool set_private (void *data);
		[CCode (cname = "JSObjectGetProperty", instance_pos=1.1)]
		public unowned JS.Value get_property(Context ctx, JS.String propertyName, out JS.Object exception=null);
		[CCode (cname = "JSObjectGetPropertyAtIndex", instance_pos=1.1)]
		public unowned JS.Value get_property_at_index(Context ctx, uint propertyIndex, out JS.Object exception=null);
		[CCode(cname = "JSObjectSetProperty", instance_pos = 1.9)]
		public void set_property(Context ctx, JS.String property_name, JS.Value value, PropertyAttribute attributes = 0, out JS.Object exception = null);
		[CCode(cname = "JSObjectGetPrototype", instance_pos = 1.9)]
		public unowned JS.Value get_prototype(Context ctx);
		[CCode(cname = "JSObjectIsFunction", instance_pos = 1.9)]
		public bool is_function(Context ctx);
		[CCode(cname = "JSObjectCallAsFunction", instance_pos = 1.9)]
		public unowned Value call_as_function(Context ctx, void* this_object, [CCode (array_length_pos=2.9, array_length_type="size_t")] Value[] args, out Value exception);
		[CCode(cname = "JSObjectCopyPropertyNames", instance_pos = 1.9)]
		public Properties get_properties(Context ctx);
	}
	
	[Compact]
	[CCode (cname = "struct OpaqueJSPropertyNameArray", free_function = "JSPropertyNameArrayRelease")]
	public class Properties {
		public size_t size {get{ return get_count();}}
		[CCode(cname = "JSPropertyNameArrayGetCount")]
		public size_t get_count();
		[CCode(cname = "JSPropertyNameArrayGetNameAtIndex")]
		public unowned JS.String get(size_t index);
	}
	
	[Compact]
	[CCode (cname = "struct OpaqueJSString", free_function = "JSStringRelease")]
	public class String {
		[CCode (cname="JSStringCreateWithUTF8CString")]
		public String (string utf8_string);
		[CCode (cname = "JSStringCreateWithCharacters")]
		public String.with_characters (ushort *chars, size_t num_chars);
		
		[CCode (cname = "JSStringCreateWithUTF8CString")]
		public String.with_utf8_c_string (string _string);

		[CCode (cname = "JSStringRetain")]
		public String retain ();

		[CCode (cname = "JSStringGetLength")]
		public size_t get_length ();

		[CCode (cname = "JSStringGetCharactersPtr")]
		public ushort *get_characters_ptr ();

		[CCode (cname = "JSStringGetMaximumUTF8CStringSize")]
		public size_t get_maximum_utf8_string_size ();

		[CCode (cname = "JSStringGetUTF8CString")]
		public size_t get_utf8_string (uint8[] buffer);

		[CCode (cname = "JSStringIsEqual")]
		public bool is_equal (String b);

		[CCode (cname = "JSStringIsEqualToUTF8CString")]
		public bool is_equal_to_utf8_c_string (string b);
		
		[CCode (cname="js_string_to_utf8_string")]
		public string to_string();
	}
	
	[Compact]
	[CCode (cname = "void")]
	public class PropertyNameAccumulator {
		[CCode (cname = "JSPropertyNameAccumulatorAddName")]
		public void add_name (String property_name);
	}
	
	[Compact]
	[CCode(cname= "void", free_function="JSClassRelease")]
	public class Class{
		[CCode (cname="JSClassRetain")]
		public Class retain();
	}
	
// Structs
	public struct ClassDefinition {
		public int version;
		public ClassAttribute attributes;
		[CCode (cname = "className")]
		public string class_name;
		[CCode (cname = "parentClass")]
		public JS.Class parent_class;
		
		[CCode (cname = "staticValues")]
		public StaticValue *static_values;
//~ 		[CCode (cname = "staticFunctions", array_length=false)]
//~ 		public StaticFunction[] static_functions;
		[CCode (cname = "staticFunctions")]
		public StaticFunction* static_functions;

		public ObjectInitializeCallback          initialize;
		public ObjectFinalizeCallback            finalize;
		[CCode (cname = "hasProperty")]
		public ObjectHasPropertyCallback         has_property;
		[CCode (cname = "getProperty")]
		public ObjectGetPropertyCallback         get_property;
		[CCode (cname = "setProperty")]
		public ObjectSetPropertyCallback         set_property;
		[CCode (cname = "deleteProperty")]
		public ObjectDeletePropertyCallback      delete_property;
		[CCode (cname = "getPropertyNames")]
		public ObjectGetPropertyNamesCallback    get_property_names;
		[CCode (cname = "callAsFunction")]
		public ObjectCallAsFunctionCallback      call_as_function;
		[CCode (cname = "callAsConstructor")]
		public ObjectCallAsConstructorCallback   call_as_constructor;
		[CCode (cname = "hasInstance")]
		public ObjectHasInstanceCallback         has_instance;
		[CCode (cname = "convertToType")]
		public ObjectConvertToTypeCallback       convert_to_type;
	}
	
	public struct StaticValue {
		public const string name;
		public ObjectGetPropertyCallback getProperty;
		public ObjectSetPropertyCallback setProperty;
		public PropertyAttribute attributes;
	}

	public struct StaticFunction {
		public string name;
		[CCode (cname="callAsFunction")]
		public ObjectCallAsFunctionCallback @callback;
		public PropertyAttribute attributes;
	}
	
/* * FUNCTIONS * */
	[CCode (cname = "JSClassCreate")]
	public unowned JS.Class create_class(ClassDefinition definition);
	
//~ 	[CCode (cname = "JSObjectMakeConstructor")]
//~ 	public unowned JS.Object make_constructor(Context ctx, Class @class, ObjectCallAsConstructorCallback constructor);
	
	

/* * DELEGATES * */
	
	[CCode (has_target = false)]
	public delegate unowned JS.Value ObjectCallAsFunctionCallback(Context ctx,
		JS.Object function, JS.Object thisObject,
		[CCode (array_length_pos=3.9, array_length_type="size_t")] JS.Value[] arguments,
		out unowned JS.Object exception);
	
	[CCode (has_target = false)]
	public delegate void ObjectInitializeCallback(Context ctx, JS.Object object);

	[CCode (has_target = false)]
	public delegate void ObjectFinalizeCallback(JS.Object object);

	[CCode (has_target = false)]
	public delegate bool ObjectHasPropertyCallback(Context ctx, JS.Object object,
		JS.String propertyName);

	[CCode (has_target = false)]
	public delegate unowned JS.Value ObjectGetPropertyCallback(Context ctx,
	    JS.Object object, JS.String propertyName, out JS.Object exception);

	[CCode (has_target = false)]
	public delegate bool ObjectSetPropertyCallback(Context ctx, JS.Object object,
	    JS.String propertyName, JS.Value @value, out JS.Object exception);

	[CCode (has_target = false)]
	public delegate bool ObjectDeletePropertyCallback(Context ctx, JS.Object object,
		JS.String propertyName, out JS.Object exception);

	[CCode (has_target = false)]
	public delegate void ObjectGetPropertyNamesCallback(Context ctx, JS.Object object,
	    PropertyNameAccumulator propertyNames);
	    
	[CCode (has_target = false)]
	public delegate unowned JS.Object ObjectCallAsConstructorCallback(Context ctx,
	    JS.Object constructor,
	    [CCode (array_length_pos=3.9, array_length_type="size_t")] JS.Value[] arguments,
	    out JS.Value exception);

	[CCode (has_target = false)]
	public delegate bool ObjectHasInstanceCallback (Context ctx, JS.Object constructor,
		JS.Value possibleInstance, out JS.Value exception);

	[CCode (has_target = false)]
	public delegate JS.Value  ObjectConvertToTypeCallback(Context ctx, JS.Object object,
	    JS.Type type, out JS.Value exception);
	   
/* * ENUMS * */
	[CCode (cprefix="kJSPropertyAttribute")]
	[Flags]
	public enum PropertyAttribute {
		None, ReadOnly, DontEnum, DontDelete
	}
	
	[CCode (cprefix="kJSClassAttribute")]
	[Flags]
	public enum ClassAttribute {
		None, NoAutomaticPrototype
	}
	
	[CCode (cprefix="kJSType")]
	public enum Type {
		Undefined, Null, Boolean, Number, String, Object
	}
}
