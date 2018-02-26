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

public abstract class WebEngine : GLib.Object, JSExecutor {
    public abstract Gtk.Widget get_main_web_view();
    public WebApp web_app {get; construct;}
    public WebAppStorage storage {get; construct;}
    public WebOptions options {get; construct;}
    public bool ready {get; protected set; default = false;}
    public bool can_go_back {get; protected set; default = false;}
    public bool can_go_forward {get; protected set; default = false;}
    public bool is_loading { get; protected set; default = false;}
    public WebWorker web_worker {get; protected set;}

    public WebEngine(WebOptions options, WebApp web_app) {
        GLib.Object(options: options, storage: options.storage, web_app: web_app);
    }

    public signal void init_finished();
    public signal void web_worker_ready();
    public signal void app_runner_ready();
    public signal void init_form(HashTable<string, Variant> values, Variant entries);
    public signal void show_alert_dialog(ref bool handled, string message);
    public signal void context_menu(bool whatewer_fixme_in_future);

    public abstract void early_init(AppRunnerController runner_app, IpcBus ipc_bus,
        Config config, Connection? connection, HashTable<string, Variant> worker_data);

    public abstract void init();

    public abstract void init_app_runner();

    public abstract void load_app();

    public abstract void go_home();

    public virtual bool apply_network_proxy(Connection connection) {
        return false;
    }

    public abstract void go_back();

    public abstract void go_forward();

    public abstract void reload();

    public abstract void zoom_in();

    public abstract void zoom_out();

    public abstract void zoom_reset();

    public abstract void get_preferences(out Variant values, out Variant entries);

    public abstract string? get_url();

    public abstract void load_url(string url);

    public virtual void call_function_sync(string name, ref Variant? params, bool propagate_error=false) throws GLib.Error {
        warning("FIXME: how to override JSExecutor in PyGObject?. Call '%s' => %s",
            name, params == null ? "null" : params.print(false));
    }
}

} // namespace Nuvola
