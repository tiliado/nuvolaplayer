/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MasterService : GLib.Object {
    public MasterDbusIfce dbus {get; construct;}
    public Drt.KeyValueStorage? config {get; private set; default = null;}
    public bool version_compatible {get; private set; default = false;}
    public int version_major {get; private set; default = -1;}
    public int version_minor {get; private set; default = -1;}
    public int version_micro {get; private set; default = -1;}
    public string? revision {get; private set; default = null;}
    public GLib.Socket? socket {get; private set; default = null;}
    public MasterServiceError? error {get; private set; default = null;}

    public MasterService() {
        GLib.Object();
    }

    construct {
        try {
            dbus = Bus.get_proxy_sync<MasterDbusIfce>(
                BusType.SESSION, Nuvola.get_dbus_id(), Nuvola.get_dbus_path(),
                DBusProxyFlags.DO_NOT_CONNECT_SIGNALS|DBusProxyFlags.DO_NOT_LOAD_PROPERTIES);
        } catch (GLib.IOError e) {
            GLib.error("Failed to connect to dbus service: %s", e.message);
        }
    }

    public bool is_connected() {
        return socket != null && error == null;
    }

    public bool init(IpcBus ipc_bus, string web_app_id, string dbus_id) {
        this.socket = null;
        try {
            check_version();
            connect_socket(ipc_bus, web_app_id, dbus_id);
            register_app(ipc_bus, web_app_id);
            this.error = null;
            return true;
        } catch (MasterServiceError e) {
            this.error = (owned) e;
            return false;
        }
    }

    private void check_version() throws MasterServiceError {
        var allowed_timeouts = 10;
        while (true) {
            try {
                int major = -1;
                int minor = -1;
                int micro = -1;
                string? revision = null;
                // TODO: @async
                dbus.get_version(out major, out minor, out micro, out revision);
                this.version_major = major;
                this.version_minor = minor;
                this.version_micro = micro;
                this.revision = (owned) revision;
                version_compatible = (
                    major == Nuvola.get_version_major() &&
                    minor == Nuvola.get_version_minor() &&
                    micro == Nuvola.get_version_micro());
                if (!version_compatible) {
                    throw new MasterServiceError.INCOMPATIBLE_VERSION(
                        "Version mismatch: Nuvola Service %d.%d.%d (%s) != Nuvola Runtime %s (%s).",
                        major, minor, micro, this.revision, Nuvola.get_version(), Nuvola.get_revision());
                }
                break;
            } catch (MasterServiceError e) {
                throw e;
            } catch (GLib.Error e) {
                if (e is GLib.DBusError.UNKNOWN_METHOD) {
                    throw new MasterServiceError.NO_VERSION_INFO(
                        "Failed to get Nuvola Service version. Update Nuvola Runtime Service.");
                } else if (allowed_timeouts < 1 || !(e is GLib.IOError.TIMED_OUT || e is GLib.DBusError.TIMED_OUT)) {
                    throw new MasterServiceError.OTHER("Failed to get Nuvola Service version. %s", e.message);
                } else {
                    allowed_timeouts--;
                    warning("Nuvola.get_version() timed out. Attempts left: %d", allowed_timeouts);
                }
            }
        }
    }

    private void connect_socket(IpcBus ipc_bus, string web_app_id, string dbus_id) throws MasterServiceError {
        GLib.Socket? socket = null;
        string? api_token = null;
        try {
            // TODO: @async
            dbus.get_connection(web_app_id, dbus_id, out socket, out api_token);
        } catch (GLib.Error e) {
            throw new MasterServiceError.OTHER("Failed to get Nuvola Service socket. %s", e.message);
        }
        if (socket == null) {
            throw new MasterServiceError.NULL_SOCKET("Nuvola Service refused to provide socket.");
        }
        try {
            ipc_bus.connect_master_socket(socket, api_token);
        } catch (Drt.IOError e) {
            throw new MasterServiceError.SOCKET_IOERROR(
                "Failed to connect to Nuvola Service socket. %s", e.message);
        }
        config = new Drt.KeyValueStorageClient(ipc_bus.master).get_proxy("master.config");
        this.socket = socket;

    }

    private void register_app(IpcBus ipc_bus, string web_app_id) throws MasterServiceError {
        try {
            Variant? response = ipc_bus.master.call_sync(
                "/nuvola/core/runner-started", new Variant("(ss)", web_app_id, ipc_bus.router.hex_token));
            assert(response.equal(new Variant.boolean(true)));
        } catch (GLib.Error e) {
            throw new MasterServiceError.REGISTRATION_FAILED(
                "Failed to register app with Nuvola Apps Service. %s", e.message);
        }
    }
}

public errordomain MasterServiceError {
    OTHER,
    NO_VERSION_INFO,
    INCOMPATIBLE_VERSION,
    NULL_SOCKET,
    SOCKET_IOERROR,
    TIMED_OUT,
    REGISTRATION_FAILED;
}

} // namespace Nuvola
