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

public abstract class AppRunner : GLib.Object {
    protected static bool gdb = false;
    public string app_id {get; private set;}
    public bool connected {get { return channel != null;}}
    public bool running {get; protected set; default = false;}
    protected GenericSet<string> capatibilities;
    protected Drt.RpcChannel channel = null;

    static construct {
        gdb = Environment.get_variable("NUVOLA_APP_RUNNER_GDB_SERVER") != null;
    }

    public AppRunner(string app_id, string api_token) throws GLib.Error {
        this.app_id = app_id;
        this.capatibilities = new GenericSet<string>(str_hash, str_equal);
    }

    public signal void notification(string path, string? detail, Variant? data);

    public Variant? query_meta() {
        try {
            var dict = new VariantDict(call_sync(IpcApi.CORE_GET_METADATA, null));
            dict.insert_value("running", new Variant.boolean(true));
            var capatibilities_array = new VariantBuilder(new VariantType("as"));
            List<unowned string> capatibilities = get_capatibilities();
            foreach (unowned string capability in capatibilities) {
                capatibilities_array.add("s", capability);
            }
            dict.insert_value("capabilities", capatibilities_array.end());
            return dict.end();
        }
        catch (GLib.Error e) {
            warning("Failed to query metadata: %s", e.message);
            return null;
        }
    }

    public List<unowned string> get_capatibilities() {
        return capatibilities.get_values();
    }

    public bool has_capatibility(string capatibility) {
        return capatibilities.contains(capatibility.down());
    }

    public void add_capatibility(string capatibility) {
        capatibilities.add(capatibility.down());
    }

    public bool remove_capatibility(string capatibility) {
        return capatibilities.remove(capatibility.down());
    }

    /**
     * Emitted when the subprocess exited.
     */
    public signal void exited();

    public void connect_channel(Drt.RpcChannel channel) {
        this.channel = channel;
        channel.router.notification.connect(on_notification);
    }

    public Variant? call_sync(string name, Variant? params) throws GLib.Error {
        if (channel == null) {
            throw new Drt.RpcError.IOERROR("No connected to app runner '%s'.", app_id);
        }

        return channel.call_sync(name, params);
    }

    public async Variant? call_full(string method, Variant? params, bool allow_private, string flags) throws GLib.Error {
        if (channel == null) {
            throw new Drt.RpcError.IOERROR("No connected to app runner '%s'.", app_id);
        }

        return yield channel.call_full(method, params, allow_private, flags);
    }

    public Variant? call_full_sync(string method, Variant? params, bool allow_private, string flags) throws GLib.Error {
        if (channel == null) {
            throw new Drt.RpcError.IOERROR("No connected to app runner '%s'.", app_id);
        }

        return channel.call_full_sync(method, params, allow_private, flags);
    }

    private void on_notification(Drt.RpcRouter router, GLib.Object source, string path, string? detail, Variant? data) {
        if (source == channel) {
            notification(path, detail, data);
        }
    }
}

public class DbusAppRunner : AppRunner {
    private uint watch_id = 0;
    private string dbus_id;

    public DbusAppRunner(string app_id, string dbus_id, GLib.BusName sender_id, string api_token) throws GLib.Error {
        base(app_id, api_token);
        this.dbus_id = dbus_id;
        watch_id = Bus.watch_name(BusType.SESSION, sender_id, 0, on_name_appeared, on_name_vanished);
    }

    private void on_name_appeared(DBusConnection conn, string name, string name_owner) {
        running = true;
    }

    private void on_name_vanished(DBusConnection conn, string name) {
        debug("%s %s vanished", dbus_id, name);
        Bus.unwatch_name(watch_id);
        running = false;
        exited();
    }
}

} // namespace Nuvola
