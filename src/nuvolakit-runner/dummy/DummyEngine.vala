/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class DummyEngine : WebEngine {
    private const string ZOOM_LEVEL_CONF = "webview.zoom_level";

    public override Gtk.Widget get_main_web_view() {return view;}

    private Gtk.Label view;


    public DummyEngine(DummyOptions web_options, WebApp web_app) {
        base(web_options, web_app);
        this.view = new Gtk.Label("Dummy Engine");
    }

    public override void early_init(AppRunnerController runner_app, IpcBus ipc_bus,
        Config config, Connection? connection, HashTable<string, Variant> worker_data) {}

    public override void init() {}

    public override void init_app_runner() {}


    public override void load_app() {}

    public override void go_home() {}

    public override bool apply_network_proxy(Connection connection) {
        return true;
    }

    public override string? get_url() {
        return null;
    }

    public override void load_url(string url) {}


    public override void go_back() {
    }

    public override void go_forward() {
    }

    public override void reload() {
    }

    public override void zoom_in() {
    }

    public override void zoom_out() {
    }

    public override void zoom_reset() {
    }

    public override void get_preferences(out Variant values, out Variant entries) {
        values = new Variant.array(new VariantType("{sv}"), {});
        entries = new Variant.array(VariantType.VARIANT, {});
    }

    public override void call_function_sync(string name, ref Variant? params, bool propagate_error=false) throws GLib.Error {
    }
}

public enum NetworkProxyType {
    SYSTEM,
    DIRECT,
    HTTP,
    SOCKS;

    public static NetworkProxyType from_string(string type) {
        switch (type.down()) {
        case "none":
        case "direct":
            return DIRECT;
        case "http":
            return HTTP;
        case "socks":
            return SOCKS;
        default:
            return SYSTEM;
        }
    }

    public string to_string() {
        switch (this) {
        case DIRECT:
            return "direct";
        case HTTP:
            return "http";
        case SOCKS:
            return "socks";
        default:
            return "system";
        }
    }
}

} // namespace Nuvola
