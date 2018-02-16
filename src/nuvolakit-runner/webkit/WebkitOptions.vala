/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WebkitOptions : WebOptions {
    public override VersionTuple engine_version {get; protected set;}
    public WebKit.WebContext default_context {
        get {if (_default_context == null) {init();} return _default_context;}
        private set {_default_context = value;}
    }
    private WebKit.WebContext _default_context = null;
    public bool flash_required {get; private set; default = false;}
    public bool mse_required {get; private set; default = false;}
    public bool mse_supported {get; private set; default = false;}
    public bool h264_supported {get; private set; default = false;}
    public FormatSupport format_support {get; set;}

    public WebkitOptions(WebAppStorage storage, Connection? connection) {
        base(storage, connection);
    }

    construct {
        engine_version = {WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version(), 0};
        #if WEBKIT_SUPPORTS_MSE
        mse_supported = true;
        h264_supported = true;
        debug("MSE supported: yes");
        #else
        debug("MSE supported: no");
        #endif
    }

    public override string get_name_version() {
        return "WebKitGTK %u.%u.%u".printf(
            WebKit.get_major_version(), WebKit.get_minor_version(), WebKit.get_micro_version());
    }

    public override string get_name() {
        return "WebKitGTK";
    }

    private void init() {
        var data_manager = (WebKit.WebsiteDataManager) GLib.Object.@new(
            typeof(WebKit.WebsiteDataManager),
            "base-cache-directory", storage.create_cache_subdir("webkit").get_path(),
            "disk-cache-directory", storage.create_cache_subdir("webcache").get_path(),
            "offline-application-cache-directory", storage.create_cache_subdir("offline_apps").get_path(),
            "base-data-directory", storage.create_data_subdir("webkit").get_path(),
            "local-storage-directory", storage.create_data_subdir("local_storage").get_path(),
            "indexeddb-directory", storage.create_data_subdir("indexeddb").get_path(),
            "websql-directory", storage.create_data_subdir("websql").get_path());
        var web_context =  new WebKit.WebContext.with_website_data_manager(data_manager);
        web_context.set_favicon_database_directory(storage.create_data_subdir("favicons").get_path());
        /* Persistence must be set up after WebContext is created! */
        WebKit.CookieManager cookie_manager = data_manager.get_cookie_manager();
        cookie_manager.set_persistent_storage(storage.data_dir.get_child("cookies.dat").get_path(),
            WebKit.CookiePersistentStorage.SQLITE);
        default_context = web_context;
    }

    public static uint get_webkit_version() {
        return WebKit.get_major_version() * 10000 + WebKit.get_minor_version() * 100 + WebKit.get_micro_version();
    }

    public override WebEngine create_web_engine(WebApp web_app) {
        return new WebkitEngine(this, web_app);
    }

    public override Drt.RequirementState supports_requirement(string type, string? parameter, out string? error) {
        error = null;
        switch (type) {
        case "webkitgtk":
            if (parameter == null) {
                return Drt.RequirementState.SUPPORTED;
            }
            string param = parameter.strip().down();
            if (param[0] == 0) {
                return Drt.RequirementState.SUPPORTED;
            }
            string[] versions = param.split(".");
            if (versions.length > 3) {
                error = "WebKitGtk[] received invalid version parameter '%s'.".printf(param);
                return Drt.RequirementState.ERROR;
            }
            uint[] uint_versions = {0, 0, 0, 0};
            for (var i = 0; i < versions.length; i++) {
                int version = int.parse(versions[i]);
                if (i < 0) {
                    error = "WebKitGtk[] received invalid version parameter '%s'.".printf(param);
                    return Drt.RequirementState.ERROR;
                }
                uint_versions[i] = (uint) version;
            }
            return (engine_version.gte(VersionTuple.uintv(uint_versions))
                ? Drt.RequirementState.SUPPORTED : Drt.RequirementState.UNSUPPORTED);
        default:
            return Drt.RequirementState.UNSUPPORTED;
        }
    }

    public override Drt.RequirementState supports_feature(string name, out string? error) {
        error = null;
        switch (name) {
        case "mse":
            mse_required = true;
            return mse_supported ? Drt.RequirementState.SUPPORTED : Drt.RequirementState.UNSUPPORTED;
        case "flash":
            flash_required = true;
            if (format_support == null) {
                return Drt.RequirementState.UNKNOWN;
            } else {
                unowned List<WebPlugin?> plugins = format_support.list_web_plugins();
                foreach (unowned WebPlugin plugin in plugins) {
                    debug(
                        "Nuvola.WebPlugin: %s (%s, %s) at %s: %s", plugin.name, plugin.enabled ? "enabled" : "disabled",
                        plugin.is_flash ? "flash" : "not flash", plugin.path, plugin.description);
                }

                return (format_support.n_flash_plugins > 0
                    ? Drt.RequirementState.SUPPORTED : Drt.RequirementState.UNSUPPORTED);
            }
        default:
            return Drt.RequirementState.UNSUPPORTED;
        }
    }

    public override Drt.RequirementState supports_codec(string name, out string? error) {
        error = null;
        switch (name) {
        case "mp3":
            if (format_support == null) {
                return Drt.RequirementState.UNKNOWN;
            } else if (format_support.mp3_supported) {
                return Drt.RequirementState.SUPPORTED;
            } else {
                warning("MP3 Audio not supported.");
                return Drt.RequirementState.UNSUPPORTED;
            }
        case "h264":
            return h264_supported ? Drt.RequirementState.SUPPORTED : Drt.RequirementState.UNSUPPORTED;
        default:
            return Drt.RequirementState.UNSUPPORTED;
        }
    }

    public override string[] get_format_support_warnings() {
        string[] warnings = {};
        if (flash_required) {
            uint flash_plugins = format_support.n_flash_plugins;
            if (flash_plugins == 0) {
                warnings += "<b>Flash plugin issue:</b> No Flash Player plugin has been found. Music playback may fail.";
            } else if (flash_plugins > 1) {
                warnings += "<b>Flash plugin issue:</b> More Flash Player plugins have been found. Wrong version may be in use.";
            }
        }
        return warnings;
    }
}

} // namespace Nuvola
