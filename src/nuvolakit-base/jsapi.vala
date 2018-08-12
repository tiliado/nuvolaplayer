/*
 * Copyright 2011-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

/**
 * Errors thrown from Nuvola Palyer JavaScript API
 */
public errordomain JSError {
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
public class JSApi : GLib.Object {
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

    private static unowned JsCore.Class klass;
    /**
     * Identifier of the main frame
     */
    public const string MAIN_FRAME_ID = "__main__";
    /**
     * Identifier of the frame for service's preferences.
     */
    public const string PREFERENCES_FRAME_ID = "__preferences__";

    private Drt.Storage storage;
    private File data_dir;
    private File config_dir;
    private Drt.KeyValueStorage[] key_value_storages;
    private uint[] webkit_version;
    private uint[] libsoup_version;
    private unowned JsEnvironment? env = null;
    private bool warn_on_sync_func;

    public JSApi(Drt.Storage storage, File data_dir, File config_dir, Drt.KeyValueStorage config,
        Drt.KeyValueStorage session, uint[] webkit_version, uint[] libsoup_version, bool warn_on_sync_func) {
        this.storage = storage;
        this.data_dir = data_dir;
        this.config_dir = config_dir;
        this.key_value_storages = {config, session};
        assert(webkit_version.length >= 3);
        this.webkit_version = webkit_version;
        this.libsoup_version = libsoup_version;
        this.warn_on_sync_func = warn_on_sync_func;
    }

    public static bool is_supported(int api_major, int api_minor) {
        int api_version = API_VERSION_MAJOR * 100 + API_VERSION_MINOR + (VERSION_BUGFIX > 0 ? 1 : 0);
        return api_major >= 3 && api_major * 100 + api_minor <= api_version;
    }

    public uint get_webkit_version() {
        return webkit_version[0] * 10000 + webkit_version[1] * 100 + webkit_version[2];
    }

    public uint get_libsoup_version() {
        return libsoup_version[0] * 10000 + libsoup_version[1] * 100 + libsoup_version[2];
    }

    public signal void call_ipc_method_void(string name, Variant? data);
    public signal void call_ipc_method_sync(string name, Variant? data, ref Variant? result);
    public signal void call_ipc_method_async(string name, Variant? data, int id);

    public void send_async_response(int id, Variant? response, GLib.Error? error) {
        if (this.env != null) {
            var args = new Variant("(imvmv)", (int32) id, response,
                error == null ? null : new Variant.string(error.message));
            if (response != null) {
                // FIXME: How are we losing a reference here?
                g_variant_ref(response);
            }
            env.call_function_sync("Nuvola.Async.respond", ref args, false);
        }
    }

    /**
     * Creates the main object and injects it to the JavaScript context
     *
     * @param env    JavaScript environment to use for injection
     */
    public void inject(JsEnvironment env, HashTable<string, Variant?>? properties=null) throws JSError {
        this.env = null;
        unowned JsCore.Context ctx = env.context;
        if (klass == null) {
            create_class();
        }
        unowned JsCore.Object main_object = ctx.make_object(klass, this);
        main_object.protect(ctx);

        o_set_number(ctx, main_object, "API_VERSION_MAJOR", (double)API_VERSION_MAJOR);
        o_set_number(ctx, main_object, "API_VERSION_MINOR", (double)API_VERSION_MINOR);
        o_set_number(ctx, main_object, "API_VERSION", (double) API_VERSION);
        o_set_number(ctx, main_object, "VERSION_MAJOR", (double)VERSION_MAJOR);
        o_set_number(ctx, main_object, "VERSION_MINOR", (double)VERSION_MINOR);
        o_set_number(ctx, main_object, "VERSION_MICRO", (double)VERSION_BUGFIX);
        o_set_number(ctx, main_object, "VERSION_BUGFIX", (double)VERSION_BUGFIX);
        o_set_string(ctx, main_object, "VERSION_SUFFIX", VERSION_SUFFIX);
        o_set_number(ctx, main_object, "VERSION", (double) Nuvola.get_encoded_version());
        o_set_number(ctx, main_object, "WEBKITGTK_VERSION", (double) get_webkit_version());
        o_set_number(ctx, main_object, "WEBKITGTK_MAJOR", (double) webkit_version[0]);
        o_set_number(ctx, main_object, "WEBKITGTK_MINOR", (double) webkit_version[1]);
        o_set_number(ctx, main_object, "WEBKITGTK_MICRO", (double) webkit_version[2]);
        o_set_number(ctx, main_object, "LIBSOUP_VERSION", (double) get_libsoup_version());
        o_set_number(ctx, main_object, "LIBSOUP_MAJOR", (double) libsoup_version[0]);
        o_set_number(ctx, main_object, "LIBSOUP_MINOR", (double) libsoup_version[1]);
        o_set_number(ctx, main_object, "LIBSOUP_MICRO", (double) libsoup_version[2]);

        if (properties != null) {
            HashTableIter<string, Variant?> iter = HashTableIter<string, Variant?>(properties);
            unowned string key;
            unowned Variant? val;
            while (iter.next(out key, out val)) {
                main_object.set_property(ctx, new JsCore.String(key), value_from_variant(ctx, val));
            }
        }

        env.main_object = main_object;
        main_object.unprotect(ctx);

        File? main_js = storage.user_data_dir.get_child(JS_DIR).get_child(MAIN_JS);
        if (!main_js.query_exists()) {
            main_js = null;
            foreach (File dir in storage.data_dirs()) {
                main_js = dir.get_child(JS_DIR).get_child(MAIN_JS);
                if (main_js.query_exists()) {
                    break;
                }
                main_js = null;
            }
        }

        if (main_js == null) {
            throw new JSError.INITIALIZATION_FAILED("Failed to find a core component main.js. This probably means the application has not been installed correctly or that component has been accidentally deleted.");
        }

        try {
            env.execute_script_from_file(main_js);
        }
        catch (JSError e) {
            throw new JSError.INITIALIZATION_FAILED("Failed to initialize a core component main.js located at '%s'. Initialization exited with error:\n\n%s", main_js.get_path(), e.message);
        }

        File meta_json = data_dir.get_child(META_JSON);
        if (!meta_json.query_exists()) {
            throw new JSError.INITIALIZATION_FAILED("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", META_JSON);
        }

        string meta_json_data;
        try {
            meta_json_data = Drt.System.read_file(meta_json);
        }
        catch (GLib.Error e) {
            throw new JSError.INITIALIZATION_FAILED("Failed load a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.\n\n%s", META_JSON, e.message);
        }

        unowned JsCore.Value meta = object_from_JSON(ctx, meta_json_data);
        env.main_object.set_property(ctx, new JsCore.String(META_PROPERTY), meta);
        this.env = env;
    }

    public void initialize(JsEnvironment env) throws JSError {
        integrate(env);
    }

    public void integrate(JsEnvironment env) throws JSError {
        File integrate_js = data_dir.get_child(INTEGRATE_JS);
        if (!integrate_js.query_exists()) {
            throw new JSError.INITIALIZATION_FAILED("Failed to find a web app component %s. This probably means the web app integration has not been installed correctly or that component has been accidentally deleted.", INTEGRATE_JS);
        }

        try {
            env.execute_script_from_file(integrate_js);
        }
        catch (JSError e) {
            throw new JSError.INITIALIZATION_FAILED("Failed to initialize a web app component %s located at '%s'. Initialization exited with error:\n\n%s", INTEGRATE_JS, integrate_js.get_path(), e.message);
        }
    }

    /**
     * Default methods of the main object. Other functions are implemented in JavaScript,
     * see file main.js
     */
    private const JsCore.StaticFunction[] static_functions = {
        {"_callIpcMethodVoid", call_ipc_method_void_func, 0},
        {"_callIpcMethodSync", call_ipc_method_sync_func, 0},
        {"_callIpcMethodAsync", call_ipc_method_async_func, 0},
        {"_keyValueStorageHasKey", key_value_storage_has_key_sync_func, 0},
        {"_keyValueStorageGetValue", key_value_storage_get_value_sync_func, 0},
        {"_keyValueStorageSetValue", key_value_storage_set_value_sync_func, 0},
        {"_keyValueStorageSetDefaultValue", key_value_storage_set_default_value_sync_func, 0},
        {"_keyValueStorageHasKeyAsync", key_value_storage_has_key_async_func, 0},
        {"_keyValueStorageGetValueAsync", key_value_storage_get_value_async_func, 0},
        {"_keyValueStorageSetValueAsync", key_value_storage_set_value_async_func, 0},
        {"_keyValueStorageSetDefaultValueAsync", key_value_storage_set_default_value_async_func, 0},
        {"_log", log_func, 0},
        {"_warn", warn_func, 0},
        {null, null, 0}
    };

    /**
     * Creates Nuvola Player main object class description
     */
    private static void create_class() {
        unowned JsCore.ClassDefinition class_def = {
            1,
            JsCore.ClassAttribute.None,
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
        klass = JsCore.create_class(class_def);
        klass.retain();
    }

    static unowned JsCore.Value call_ipc_method_void_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return call_ipc_method_func(ctx, function, self, args, out exception, JsFuncCallType.VOID);
    }

    static unowned JsCore.Value call_ipc_method_sync_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return call_ipc_method_func(ctx, function, self, args, out exception, JsFuncCallType.SYNC);
    }

    static unowned JsCore.Value call_ipc_method_async_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return call_ipc_method_func(ctx, function, self, args, out exception, JsFuncCallType.ASYNC);
    }

    static unowned JsCore.Value call_ipc_method_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self, JsCore.Value[] args,
        out unowned JsCore.Value exception, JsFuncCallType type) {
        unowned JsCore.Value undefined = JsCore.Value.undefined(ctx);
        exception = null;
        if (args.length == 0) {
            exception = create_exception(ctx, "At least one argument required.");
            return undefined;
        }

        string? name = string_or_null(ctx, args[0]);
        if (name == null) {
            exception = create_exception(ctx, "The first argument must be a non-null string");
            return undefined;
        }

        var js_api = self.get_private() as JSApi;
        if (js_api == null) {
            exception = create_exception(ctx, "JSApi is null");
            return undefined;
        }

        Variant? data = null;
        if (args.length > 1 && !args[1].is_null(ctx)) {
            try {
                data = variant_from_value(ctx, args[1]);
            } catch (JSError e) {
                exception = create_exception(ctx, "Argument %d: %s".printf(1, e.message));
                return undefined;
            }
        }
        switch (type) {
        case JsFuncCallType.VOID:
            Drt.EventLoop.add_idle(() => {js_api.call_ipc_method_void(name, data); return false;});
            return undefined;
        case JsFuncCallType.ASYNC:
            int id = -1;
            if (args.length > 2) {
                try {
                    id = (int) Drt.variant_to_double(variant_from_value(ctx, args[2]));
                } catch (JSError e) {
                    exception = create_exception(ctx, "Argument %d: %s".printf(2, e.message));
                    return undefined;
                }
            }
            if (id <= 0) {
                exception = create_exception(ctx, "Argument %d: Integer expected (%d).".printf(2, id));
                return undefined;
            }
            Drt.EventLoop.add_idle(() => {js_api.call_ipc_method_async(name, data, id); return false;});
            return undefined;
        case JsFuncCallType.SYNC:
            Variant? result = null;
            js_api.warn_sync_func(name);
            js_api.call_ipc_method_sync(name, data, ref result);
            try {
                return value_from_variant(ctx, result);
            } catch (JSError e) {
                exception = create_exception(ctx, "Failed to parse response. %s".printf(e.message));
                return undefined;
            }
        default:
            assert_not_reached();
        }
    }

    static unowned JsCore.Value key_value_storage_has_key_sync_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_has_key_func(ctx, function, self, args, out exception, JsFuncCallType.SYNC);
    }

    static unowned JsCore.Value key_value_storage_has_key_async_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_has_key_func(ctx, function, self, args, out exception, JsFuncCallType.ASYNC);
    }

    static unowned JsCore.Value key_value_storage_has_key_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception, JsFuncCallType type) {
        unowned JsCore.Value _false = JsCore.Value.boolean(ctx, false);
        exception = null;
        if (args.length != (type == JsFuncCallType.ASYNC ? 3 : 2)) {
            exception = create_exception(ctx, "Two arguments required.");
            return _false;
        }
        if (!args[0].is_number(ctx)) {
            exception = create_exception(ctx, "Argument 0 must be a number.");
            return _false;
        }
        int index = (int) args[0].to_number(ctx);
        string? key = string_or_null(ctx, args[1]);
        if (key == null) {
            exception = create_exception(ctx, "The first argument must be a non-null string");
            return _false;
        }

        var js_api = self.get_private() as JSApi;
        if (js_api == null) {
            exception = create_exception(ctx, "JSApi is null");
            return _false;
        }
        if (js_api.key_value_storages.length <= index) {
            exception = create_exception(ctx, "Unknown storage.");
            return _false;
        }

        Drt.KeyValueStorage storage = js_api.key_value_storages[index];
        if (type == JsFuncCallType.SYNC) {
            js_api.warn_sync_func("key_value_storage_has_key(%d, '%s')".printf(index, key));
            return JsCore.Value.boolean(ctx, storage.has_key(key));
        } else {
            var id = (int) args[2].to_number(ctx);
            storage.has_key_async.begin(key, (o, res) => {
                bool result = storage.has_key_async.end(res);
                js_api.send_async_response(id, result, null);
            });
        }
        return _false;
    }

    static unowned JsCore.Value key_value_storage_get_value_sync_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_get_value_func(ctx, function, self, args, out exception, JsFuncCallType.SYNC);
    }

    static unowned JsCore.Value key_value_storage_get_value_async_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_get_value_func(ctx, function, self, args, out exception, JsFuncCallType.ASYNC);
    }

    static unowned JsCore.Value key_value_storage_get_value_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception, JsFuncCallType type) {
        unowned JsCore.Value undefined = JsCore.Value.undefined(ctx);
        exception = null;
        if (args.length != (type == JsFuncCallType.ASYNC ? 3 : 2)) {
            exception = create_exception(ctx, "Two arguments required.");
            return undefined;
        }
        if (!args[0].is_number(ctx)) {
            exception = create_exception(ctx, "Argument 0 must be a number.");
            return undefined;
        }
        int index = (int) args[0].to_number(ctx);
        string? key = string_or_null(ctx, args[1]);
        if (key == null) {
            exception = create_exception(ctx, "Argument 1 must be a non-null string");
            return undefined;
        }

        var js_api = self.get_private() as JSApi;
        if (js_api == null) {
            exception = create_exception(ctx, "JSApi is null");
            return undefined;
        }
        if (js_api.key_value_storages.length <= index) {
            exception = create_exception(ctx, "Unknown storage.");
            return undefined;
        }

        Drt.KeyValueStorage storage = js_api.key_value_storages[index];
        if (type == JsFuncCallType.SYNC) {
            js_api.warn_sync_func("key_value_storage_get_value(%d, '%s')".printf(index, key));
            Variant? value = storage.get_value(key);
            try {
                return value_from_variant(ctx, value);
            } catch (JSError e) {
                exception = create_exception(ctx, "Failed to convert Variant to JavaScript value. %s".printf(e.message));
                return undefined;
            }
        } else {
            var id = (int) args[2].to_number(ctx);
            storage.get_value_async.begin(key, (o, res) => {
                Variant? value = storage.get_value_async.end(res);
                js_api.send_async_response(id, value, null);
            });
        }
        return undefined;
    }

    static unowned JsCore.Value key_value_storage_set_value_sync_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_set_value_func(ctx, function, self, args, out exception, JsFuncCallType.SYNC);
    }

    static unowned JsCore.Value key_value_storage_set_value_async_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_set_value_func(ctx, function, self, args, out exception, JsFuncCallType.ASYNC);
    }

    static unowned JsCore.Value key_value_storage_set_value_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception, JsFuncCallType type) {
        unowned JsCore.Value undefined = JsCore.Value.undefined(ctx);
        exception = null;
        if (args.length != (type == JsFuncCallType.ASYNC ? 4 : 3)) {
            exception = create_exception(ctx, "%d arguments required. %d received.".printf(
                (type == JsFuncCallType.ASYNC ? 4 : 3), args.length));
            return undefined;
        }
        if (!args[0].is_number(ctx)) {
            exception = create_exception(ctx, "Argument 0 must be a number.");
            return undefined;
        }
        int index = (int) args[0].to_number(ctx);
        string? key = string_or_null(ctx, args[1]);
        if (key == null) {
            exception = create_exception(ctx, "Argument 1 must be a non-null string");
            return undefined;
        }

        var js_api = self.get_private() as JSApi;
        if (js_api == null) {
            exception = create_exception(ctx, "JSApi is null");
            return undefined;
        }
        if (js_api.key_value_storages.length <= index) {
            exception = create_exception(ctx, "Unknown storage.");
            return undefined;
        }

        Variant? value = null;
        try {
            value = args[2].is_undefined(ctx) ? null : variant_from_value(ctx, args[2]);
        } catch (JSError e) {
            exception = create_exception(ctx, "Failed to convert JavaScript value to Variant. %s".printf(e.message));
            return undefined;
        }
        Drt.KeyValueStorage storage = js_api.key_value_storages[index];
        if (type == JsFuncCallType.SYNC) {
            js_api.warn_sync_func("key_value_storage_set_value(%d, '%s')".printf(index, key));
            storage.set_value(key, value);
        } else {
            var id = (int) args[3].to_number(ctx);
            storage.set_value_async.begin(key, value, (o, res) => {
                storage.set_value_async.end(res);
                js_api.send_async_response(id, null, null);
            });
        }
        return undefined;
    }

    static unowned JsCore.Value key_value_storage_set_default_value_sync_func(JsCore.Context ctx, JsCore.Object function,
        JsCore.Object self, JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_set_default_value_func(
            ctx, function, self, args, out exception, JsFuncCallType.SYNC);
    }

    static unowned JsCore.Value key_value_storage_set_default_value_async_func(JsCore.Context ctx, JsCore.Object function,
        JsCore.Object self, JsCore.Value[] args, out unowned JsCore.Value exception) {
        return key_value_storage_set_default_value_func(
            ctx, function, self, args, out exception, JsFuncCallType.ASYNC);
    }

    static unowned JsCore.Value key_value_storage_set_default_value_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self,
        JsCore.Value[] args, out unowned JsCore.Value exception, JsFuncCallType type) {
        unowned JsCore.Value undefined = JsCore.Value.undefined(ctx);
        exception = null;
        if (args.length != (type == JsFuncCallType.ASYNC ? 4 : 3)) {
            exception = create_exception(ctx, "%d arguments required. %d received.".printf(
                (type == JsFuncCallType.ASYNC ? 4 : 3), args.length));
            return undefined;
        }
        if (!args[0].is_number(ctx)) {
            exception = create_exception(ctx, "Argument 0 must be a number.");
            return undefined;
        }
        int index = (int) args[0].to_number(ctx);
        string? key = string_or_null(ctx, args[1]);
        if (key == null) {
            exception = create_exception(ctx, "Argument 1 must be a non-null string");
            return undefined;
        }
        var js_api = self.get_private() as JSApi;
        if (js_api == null) {
            exception = create_exception(ctx, "JSApi is null");
            return undefined;
        }
        if (js_api.key_value_storages.length <= index) {
            exception = create_exception(ctx, "Unknown storage.");
            return undefined;
        }

        Variant? value = null;
        try {
            value = args[2].is_undefined(ctx) ? null : variant_from_value(ctx, args[2]);
        } catch (JSError e) {
            exception = create_exception(ctx, "Failed to convert JavaScript value to Variant. %s".printf(e.message));
            return undefined;
        }
        Drt.KeyValueStorage storage = js_api.key_value_storages[index];
        if (type == JsFuncCallType.SYNC) {
            js_api.warn_sync_func("key_value_storage_set_default_value(%d, '%s')".printf(index, key));
            storage.set_default_value(key, value);
        } else {
            var id = (int) args[3].to_number(ctx);
            storage.set_default_value_async.begin(key, value, (o, res) => {
                storage.set_default_value_async.end(res);
                js_api.send_async_response(id, null, null);
            });
        }
        return undefined;
    }

    static unowned JsCore.Value log_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self, JsCore.Value[] args, out unowned JsCore.Value exception) {
        exception = null;
        for (var i = 0; i < args.length; i++) {
            if (args[i].is_undefined(ctx)) {
                debug("Nuvola.log: undefined");
            } else {
                try {
                    debug("Nuvola.log: %s", variant_from_value(ctx, args[i]).print(false));
                }
                catch (JSError e) {
                    warning("Nuvola.log (JSError): %s", e.message);
                }
            }
        }
        return JsCore.Value.undefined(ctx);
    }

    static unowned JsCore.Value warn_func(JsCore.Context ctx, JsCore.Object function, JsCore.Object self, JsCore.Value[] args, out unowned JsCore.Value exception) {
        exception = null;
        for (var i = 0; i < args.length; i++) {
            if (args[i].is_undefined(ctx)) {
                warning("Nuvola.warn: undefined");
            } else {
                try {
                    warning("Nuvola.warn: %s", variant_from_value(ctx, args[i]).print(false));
                }
                catch (JSError e) {
                    warning("Nuvola.warn (JSError): %s", e.message);
                }
            }
        }
        return JsCore.Value.undefined(ctx);
    }

    private void warn_sync_func(string message) {
        if (warn_on_sync_func) {
            warning("Sync func: %s", message);
        }
    }

    private enum JsFuncCallType {
        VOID,
        SYNC,
        ASYNC;
    }
}

} // namespace Nuvola

// FIXME
private extern Variant* g_variant_ref(Variant* variant);
