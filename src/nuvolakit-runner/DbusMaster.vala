/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

[DBus(name="eu.tiliado.Nuvola")]
public class MasterDbusApi: GLib.Object {
    private unowned MasterController controller;

    public MasterDbusApi(MasterController controller) {
        this.controller = controller;
    }

    public bool get_version(out int major, out int minor, out int micro, out string? revision) throws GLib.Error {
        major = Nuvola.get_version_major();
        minor = Nuvola.get_version_minor();
        micro = Nuvola.get_version_micro();
        revision = Nuvola.get_revision();
        return true;
    }

    public void get_connection(string app_id, string dbus_id, out Socket? socket, out string? token)
    throws GLib.Error {
        if (controller.start_app_from_dbus(app_id, dbus_id, out token)) {
            socket = Drt.SocketChannel.create_socket_from_name(build_master_ipc_id()).socket;
        } else {
            throw new Drt.Error.ACCESS_DENIED("Nuvola refused connection.");
        }
    }
}

[DBus(name="eu.tiliado.NuvolaApp")]
public interface AppDbusIfce: GLib.Object {
    public abstract void activate() throws GLib.Error;
    public abstract bool get_version(out int major, out int minor, out int micro, out string? revision) throws GLib.Error;
    public abstract void get_connection(out Socket? socket) throws GLib.Error;
}

} // namespace Nuvola
