/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if EXPERIMENTAL
namespace Nuvola.HttpRemoteControl {

public const string CAPABILITY_NAME = "httpcontrol";

public class Server: Soup.Server {
    public static string mk_address_enabled_key(string address) {
        return "components.httpcontrol.addresses.%s.enabled".printf(address.replace(".", "_"));
    }

    private const string PORT_KEY = "components.httpcontrol.port";
    private const string APP_REGISTERED = "/nuvola/httpremotecontrol/app-registered";
    private const string APP_UNREGISTERED = "/nuvola/httpremotecontrol/app-unregistered";
    public uint service_port {get; set;}
    private MasterBus bus;
    private MasterController app;
    private HashTable<string, AppRunner> app_runners;
    private unowned Queue<AppRunner> app_runners_order;
    private GenericSet<string> registered_runners;
    private bool running = false;
    private File[] www_roots;
    private Channel eio_channel;
    private HashTable<string, Drt.Lst<Subscription>> subscribers;
    private Nm.NetworkManager? nm = null;
    private string? nm_error = null;
    private Drt.Lst<Address> addresses;

    public Server(
        MasterController app, MasterBus bus,
        HashTable<string, AppRunner> app_runners, Queue<AppRunner> app_runners_order, File[] www_roots) {
        this.app = app;
        this.bus = bus;
        this.app_runners = app_runners;
        this.app_runners_order = app_runners_order;
        this.www_roots = www_roots;
        app.config.set_default_value(PORT_KEY, new Variant.int64(8089));
        service_port = (int) app.config.get_int64(PORT_KEY);
        addresses = new Drt.Lst<Address>(Address.equals);
        registered_runners = new GenericSet<string>(str_hash, str_equal);
        subscribers = new HashTable<string, Drt.Lst<Subscription>>(str_hash, str_equal);
        bus.router.add_method("/nuvola/httpremotecontrol/register", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_register, {
                new Drt.StringParam("id", true, false)
            });
        bus.router.add_method("/nuvola/httpremotecontrol/unregister", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_unregister, {
                new Drt.StringParam("id", true, false)
            });
        bus.router.add_method("/nuvola/httpremotecontrol/get-addresses", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_get_addresses, null);
        bus.router.add_method("/nuvola/httpremotecontrol/set-address-enabled", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_set_address_enabled, {
                new Drt.StringParam("address", true, false),
                new Drt.BoolParam("enabled", true, false),
            });
        bus.router.add_method("/nuvola/httpremotecontrol/get-port", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            null, handle_get_port, null);
        bus.router.add_method("/nuvola/httpremotecontrol/set-port", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_set_port, {
                new Drt.IntParam("port", true, false),
            });
        bus.router.add_notification(APP_REGISTERED, Drt.RpcFlags.SUBSCRIBE|Drt.RpcFlags.WRITABLE, null);
        bus.router.add_notification(APP_UNREGISTERED, Drt.RpcFlags.SUBSCRIBE|Drt.RpcFlags.WRITABLE, null);
        app.runner_exited.connect(on_runner_exited);
        bus.router.notification.connect(on_master_notification);
        var eio_server = new Engineio.Server(this, "/nuvola.io/");
        eio_channel = new Channel(eio_server, this);
        Nm.get_client.begin(null, on_nm_client_created);
        notify["port"].connect_after(on_port_changed);
    }

    ~Server() {
        app.runner_exited.disconnect(on_runner_exited);
        bus.router.notification.disconnect(on_master_notification);
    }

    public void start() {
        if (running) {
            return;
        }

        foreach (Address addr in addresses) {
            if (!addr.enabled) {
                continue;
            }
            try {
                message("Start HttpRemoteControlServer at %s:%u", addr.address, service_port);
                listen(new InetSocketAddress.from_string(addr.address, service_port), 0);
                running = true;
            }
            catch (GLib.Error e) {
                critical("Cannot start HttpRemoteControlServer at %s:%u: %s", addr.address, service_port, e.message);
            }
        }
        if (running) {
            add_handler("/", default_handler);
        }
    }

    public void restart() {
        if (running) {
            stop();
            start();
        }
        else if (registered_runners.length > 0) {
            start();
        }
    }

    public void stop() {
        message("Stop HttpRemoteControlServer");
        disconnect();
        remove_handler("/");
        running = false;
    }

    public void refresh_addresses() {
        this.addresses.clear();
        Config config = app.config;
        var addr_str = "127.0.0.1";
        string key = mk_address_enabled_key(addr_str);
        this.addresses.append(new Address(addr_str, "Localhost", config.has_key(key) ? config.get_bool(key) : true));
        if (nm != null) {
            Nm.ActiveConnection[]? connections = nm.get_active_connections();
            if (connections != null) {
                foreach (Nm.ActiveConnection conn in connections) {
                    Nm.Ip4Config? ip4_config =  conn.get_ip4_config();
                    if (ip4_config == null) {
                        continue;
                    }
                    uint[]? addresses = ip4_config.get_addresses();
                    if (addresses == null) {
                        continue;
                    }
                    foreach (uint ip4 in addresses) {
                        addr_str = "%u.%u.%u.%u".printf(
                            (ip4 & 0xFF),
                            (ip4 >> 8) & 0xFF,
                            (ip4 >> 16) & 0xFF,
                            (ip4 >> 24) & 0xFF);
                        key = mk_address_enabled_key(addr_str);
                        bool enabled = config.has_key(key) ? config.get_bool(key) : false;
                        this.addresses.append(new Address(addr_str, conn.id, enabled));
                    }
                }
            }
        }
        restart();
    }

    private void register_app(string app_id) {
        message("HttpRemoteControlServer: Register app id: %s", app_id);
        registered_runners.add(app_id);
        AppRunner? app = app_runners[app_id];
        app.add_capatibility(CAPABILITY_NAME);
        app.notification.connect(on_app_notification);
        if (!running) {
            start();
        }
        bus.router.emit(APP_REGISTERED, app_id, app_id);
    }

    private bool unregister_app(string app_id) {
        message("HttpRemoteControlServer: unregister app id: %s", app_id);
        AppRunner? app = app_runners[app_id];
        if (app != null) {
            app.remove_capatibility(CAPABILITY_NAME);
            app.notification.disconnect(on_app_notification);
        }
        bool result = registered_runners.remove(app_id);
        bus.router.emit(APP_UNREGISTERED, app_id, app_id);
        if (running && registered_runners.length == 0) {
            stop();
        }
        return result;
    }

    private void on_runner_exited(AppRunner runner) {
        unregister_app(runner.app_id);
    }

    private static void default_handler(
        Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
        var self = server as Server;
        assert(self != null);
        self.handle_request(new RequestContext(server, msg, path, query, client));
    }

    public async Variant? handle_eio_request(Engineio.Socket socket, Engineio.MessageType type, string path, Variant? params) throws GLib.Error {
        if (path.has_prefix("/app/")) {
            string app_path = path.substring(5);
            string app_id;
            int slash_pos = app_path.index_of_char('/');
            if (slash_pos <= 0) {
                app_id = app_path;
                app_path = "";
            }
            else {
                app_id = app_path.substring(0, slash_pos);
                app_path = app_path.substring(slash_pos);
            }
            if (!(app_id in registered_runners)) {
                throw new ChannelError.APP_NOT_FOUND("App with id '%s' doesn't exist or HTTP interface is not enabled.", app_id);
            }

            if (type == Engineio.MessageType.SUBSCRIBE) {
                bool subscribe = true;
                string? detail = null;
                string abs_path = "/app/%s/nuvola%s".printf(app_id, path);
                Drt.RpcNotification.parse_params(abs_path, params, out subscribe, out detail);
                yield this.subscribe(app_id, app_path, subscribe, detail, socket);
                return null;
            }

            AppRunner? app = app_runners[app_id];
            return yield app.call_full("/nuvola" + app_path, params, false, "rw");
        }
        if (path.has_prefix("/master/")) {
            string master_path = path.substring(7);
            if (type == Engineio.MessageType.SUBSCRIBE) {
                bool subscribe = true;
                string? detail = null;
                string abs_path = "/master/nuvola%s".printf(master_path);
                Drt.RpcNotification.parse_params(abs_path, params, out subscribe, out detail);
                yield this.subscribe(null, master_path, subscribe, detail, socket);
                return null;
            }

            return bus.local.call_full_sync("/nuvola" + master_path, params, false, "rw");
        }
        throw new ChannelError.INVALID_REQUEST("Request '%s' is invalid.", path);
    }

    protected void handle_request(RequestContext request) {
        string path = request.path;
        if (path == "/+api/app" || path == "/+api/app/") {
            request.respond_json(200, list_apps());
            return;
        }
        if (path.has_prefix("/+api/app/")) {
            string app_path = path.substring(10);
            string app_id;
            int slash_pos = app_path.index_of_char('/');
            if (slash_pos <= 0) {
                app_id = app_path;
                app_path = "";
            }
            else {
                app_id = app_path.substring(0, slash_pos);
                app_path = app_path.substring(slash_pos + 1);
            }
            if (!(app_id in registered_runners)) {
                request.respond_not_found();
            }
            else {
                var app_request = new AppRequest.from_request_context(app_path, request);
                message("App-specific request %s: %s => %s", app_id, app_path, app_request.to_string());
                try {
                    Json.Node data = send_app_request(app_id, app_request);
                    request.respond_json(200, data);
                }
                catch (GLib.Error e) {
                    var builder = new VariantBuilder(new VariantType("a{sv}"));
                    builder.add("{sv}", "error", new Variant.int32(e.code));
                    builder.add("{sv}", "message", new Variant.string(e.message));
                    builder.add("{sv}", "quark", new Variant.string(e.domain.to_string()));
                    request.respond_json(400, Json.gvariant_serialize(builder.end()));
                }
            }
            return;
        }
        else if (path.has_prefix("/+api/")) {
            try {
                Json.Node data = send_local_request(path.substring(6), request);
                request.respond_json(200, data);
            }
            catch (GLib.Error e) {
                var builder = new VariantBuilder(new VariantType("a{sv}"));
                builder.add("{sv}", "error", new Variant.int32(e.code));
                builder.add("{sv}", "message", new Variant.string(e.message));
                builder.add("{sv}", "quark", new Variant.string(e.domain.to_string()));
                request.respond_json(400, Json.gvariant_serialize(builder.end()));
            }
            return;
        }
        serve_static(request);
    }

    public async void subscribe(string? app_id, string path, bool subscribe, string? detail, Engineio.Socket socket) throws GLib.Error {
        string abs_path = app_id != null ? "/app/%s/nuvola%s".printf(app_id, path) : "/master/nuvola%s".printf(path);
        Drt.Lst<Subscription>? subscribers = this.subscribers[abs_path];
        if (subscribers == null) {
            subscribers = new Drt.Lst<Subscription>(Subscription.equals);
            this.subscribers[abs_path] = subscribers;
        }

        bool call_to_subscribe = false;
        var subscription = new Subscription(this, socket, app_id, path, detail);
        if (subscribe) {
            call_to_subscribe = subscribers.length == 0;
            subscribers.append(subscription);
            socket.closed.connect(subscription.unsubscribe);
        }
        else {
            socket.closed.disconnect(subscription.unsubscribe);
            subscribers.remove(subscription);
            call_to_subscribe = subscribers.length == 0;
        }
        if (call_to_subscribe) {
            var builder = new VariantBuilder(new VariantType("a{smv}"));
            builder.add("{smv}", "subscribe", new Variant.boolean(subscribe));
            builder.add("{smv}", "detail", detail != null ? new Variant.string(detail) : null);
            Variant params = builder.end();
            if (app_id != null) {
                AppRunner app = app_runners[app_id];
                if (app == null) {
                    throw new ChannelError.APP_NOT_FOUND("App with id '%s' doesn't exist or HTTP interface is not enabled.", app_id);
                }

                yield app.call_full("/nuvola" + path, params, false, "rws");
            }
            else {
                bus.local.call_full_sync("/nuvola" + path, params, false, "rws");
            }
        }
    }

    private void serve_static(RequestContext request) {
        string path = request.path == "/" ? "index" : request.path.substring(1);
        if (path.has_suffix("/")) {
            path += "index";
        }

        File file = find_static_file(path);
        if (file == null) {
            request.respond_not_found();
            return;
        }
        request.serve_file(file);
    }

    private File? find_static_file(string path) {
        foreach (File www_root in www_roots) {
            File file = www_root.get_child(path);
            if (file.query_file_type(0) == FileType.REGULAR) {
                return file;
            }
            file = www_root.get_child(path + ".html");
            if (file.query_file_type(0) == FileType.REGULAR) {
                return file;
            }
        }
        return null;
    }

    private Json.Node send_app_request(string app_id, AppRequest app_request) throws GLib.Error {
        AppRunner app = app_runners[app_id];
        string flags = app_request.method == "POST" ? "rw" : "r";
        string method = "/nuvola/" + app_request.app_path;
        unowned string? form_data = app_request.method == "POST" ? (string) app_request.body.data : app_request.uri.query;
        return to_json(app.call_full_sync(method, serialize_params(form_data), false, flags));
    }

    private Json.Node send_local_request(string path, RequestContext request) throws GLib.Error {
        Soup.Message msg = request.msg;
        Soup.Buffer body = msg.request_body.flatten();
        string flags = msg.method == "POST" ? "rw" : "r";
        string method = "/nuvola/" + path;
        unowned string? form_data = msg.method == "POST" ? (string) body.data : msg.uri.query;
        return to_json(bus.local.call_full_sync(method, serialize_params(form_data), false, flags));
    }

    private Variant? serialize_params(string? form_data) {
        if (form_data != null) {
            HashTable<string, string> query_params = Soup.Form.decode(form_data);
            return Drt.str_table_to_variant_dict(query_params);
        }
        return null;
    }

    private Json.Node to_json(Variant? data) {
        Variant? result = data;
        if (data == null || !data.get_type().is_subtype_of(VariantType.DICTIONARY)) {
            var builder = new VariantBuilder(new VariantType("a{smv}"));
            if (data != null) {
                g_variant_ref(data);
            } // FIXME: How to avoid this hack
            builder.add("{smv}", "result", data);
            result = builder.end();
        }
        return Json.gvariant_serialize(result);
    }

    private Json.Node? list_apps() {
        var builder = new Json.Builder();
        builder.begin_object().set_member_name("apps").begin_array();
        List<unowned string> keys = registered_runners.get_values();
        keys.sort(string.collate);
        foreach (unowned string app_id in keys)
        builder.add_string_value(app_id);
        builder.end_array().end_object();
        return builder.get_root();
    }

    private void handle_register(Drt.RpcRequest request) throws Drt.RpcError {
        register_app(request.pop_string());
        request.respond(null);
    }

    private void handle_unregister(Drt.RpcRequest request) throws Drt.RpcError {
        string? app_id = request.pop_string();
        if (!unregister_app(app_id)) {
            warning("App %s hasn't been registered yet!", app_id);
        }
        request.respond(null);
    }

    private void handle_get_addresses(Drt.RpcRequest request) throws GLib.Error {
        var builder = new VariantBuilder(new VariantType("a(ssb)"));
        foreach (var addr in addresses) {
            builder.add("(ssb)", addr.address, addr.name, addr.enabled);
        }
        request.respond(new Variant("(a(ssb)ms)", builder, nm_error));
    }

    private void handle_set_address_enabled(Drt.RpcRequest request) throws Drt.RpcError {
        string? address = request.pop_string();
        bool enabled = request.pop_bool();
        foreach (Address addr in this.addresses) {
            if (addr.address == address) {
                if (addr.enabled != enabled) {
                    addr.enabled = enabled;
                    Idle.add(() => {restart(); return false;});
                }
                app.config.set_bool(mk_address_enabled_key(address), enabled);
                break;
            }
        }
        request.respond(null);
    }

    private void handle_get_port(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(service_port);
    }

    private void handle_set_port(Drt.RpcRequest request) throws Drt.RpcError {
        int port = request.pop_int();
        if (port != service_port) {
            service_port = port;
            Idle.add(() => {restart(); return false;});
            app.config.set_int64(PORT_KEY, port);
        }
        request.respond(null);
    }

    private void on_master_notification(Drt.RpcRouter router, GLib.Object conn, string path, string? detail, Variant? data) {
        if (conn != bus) {
            return;
        }
        string full_path = "/master" + path;
        Drt.Lst<Subscription>? subscribers = this.subscribers[full_path];
        if (subscribers == null) {
            warning("No subscriber for %s!", full_path);
            return;
        }
        string path_without_nuvola = "/master" + path.substring(7);
        foreach (Subscription subscriber in subscribers)
        eio_channel.send_notification(subscriber.socket, path_without_nuvola, data);
    }

    private void on_app_notification(AppRunner app, string path, string? detail, Variant? data) {
        string full_path = "/app/" + app.app_id + path;
        Drt.Lst<Subscription>? subscribers = this.subscribers[full_path];
        if (subscribers == null) {
            warning("No subscriber for %s!", full_path);
            return;
        }
        string path_without_nuvola = "/app/" + app.app_id + path.substring(7);
        foreach (Subscription subscriber in subscribers)
        eio_channel.send_notification(subscriber.socket, path_without_nuvola, data);
    }

    private void on_nm_client_created(GLib.Object? o, AsyncResult res) {
        try {
            nm = Nm.get_client.end(res);
        }
        catch (GLib.Error e) {
            warning("Failed to create NM client: %s", e.message);
            nm = null;
            nm_error = e.message;
        }
        refresh_addresses();
    }

    private void on_port_changed(GLib.Object o, ParamSpec p) {
        restart();
    }

    private class Address {
        public string address;
        public string name;
        public bool enabled;

        public Address(string address, string name, bool enabled=false) {
            this.address = address;
            this.name = name;
            this.enabled = enabled;
        }

        public bool equals(Address other) {
            return this.address == other.address;
        }
    }

    private class Subscription: GLib.Object {
        public Server server;
        public Engineio.Socket socket;
        public string? app_id;
        public string path;
        public string? detail;

        public Subscription(Server server, Engineio.Socket socket, string? app_id, string path, string? detail) {
            assert(socket != null);
            this.server = server;
            this.socket = socket;
            this.app_id = app_id;
            this.path = path;
            this.detail = detail;
        }

        public void unsubscribe() {
            this.ref(); // Keep alive for a while
            server.subscribe.begin(app_id, path, false, detail, socket, on_unsubscribe_done);
        }

        private void on_unsubscribe_done(GLib.Object? o, AsyncResult res) {
            try {
                this.unref(); // free
                server.subscribe.end(res);
            }
            catch (GLib.Error e) {
                warning("Failed to unsubscribe a closed socket: %s %s", app_id, path);
            }
        }

        public bool equals(Subscription other) {
            return this == other || this.socket == other.socket && this.app_id == other.app_id && this.path == other.path;
        }
    }
}

} // namespace Nuvola.HttpRemoteControl

// FIXME
private extern Variant* g_variant_ref(Variant* variant);
#endif

