/*
 * Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
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
namespace Nuvola.Messaging {

public class Server: GLib.Object {
    public string path {get; construct;}
    public Codec codec {get; construct;}
    public Connection? connection {get; private set; default = null;}
    public bool running {get; private set; default = false;}
    private Cancellable? cancellable;
    private GLib.Socket? socket;
    private Thread<bool>? accept_thread;
    private MainContext? ctx;


    public Server(string path, Codec codec) {
        GLib.Object(path: path, codec: codec);
    }

    public void start() throws GLib.Error {
        if (running) {
            return;
        }

        ctx = MainContext.ref_thread_default();
        cancellable = new Cancellable();
        var address = new UnixSocketAddress.with_type(path, -1, UnixSocketAddressType.ABSTRACT);
        socket = new GLib.Socket(SocketFamily.UNIX, SocketType.SEQPACKET, SocketProtocol.DEFAULT);
        socket.bind(address, true);
        socket.set_listen_backlog(10);
        socket.listen();
        accept_thread = new Thread<bool>(path + "::accept", accept);
        running = true;
    }

    public void stop() {
        if (!running) {
            return;
        }

        debug("Server stop");
        if (cancellable != null) {
            cancellable.cancel();
        }

        if (this.connection != null) {
            this.connection.stop();
        }

        if (accept_thread != null) {
            accept_thread.join();
        }

        ctx = null;
        accept_thread = null;
        socket = null;
        connection = null;
        cancellable = null;
        running = false;
    }

    private bool accept() {
        while (!cancellable.is_cancelled()) {
            GLib.Socket client;
            try {
                client = socket.accept(cancellable);
            } catch (GLib.Error e) {
                warning("Failed to accept connection: %s", e.message);
                stop();
                return false;
            }

            Connection conn = new Connection(new Transport(client, path), codec, ctx);

            if (this.connection != null) {
                this.connection.stop();
            }

            conn.start();
            this.connection = conn;
        }
        return true;
    }
}

} // namespace Nuvola.Messaging
