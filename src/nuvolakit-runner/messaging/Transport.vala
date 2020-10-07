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

const ulong HEADER_SIZE = 4 * sizeof(int32);
const int SOL_SOCKET = 1;
const int SCM_RIGHTS = 1;


public class Payload {
    public uint id;
    public MessageType type;
    public ByteArray? data = null;
    public int[]? fds = null;

    public Payload(uint id, MessageType type, owned ByteArray? data, owned int[]? fds) {
        this.id = id;
        this.type = type;
        this.data = (owned) data;
        this.fds = (owned) fds;
    }
}


public class Transport : GLib.Object {
    public string name {get; construct;}
    public GLib.Socket socket {get; construct;}
    private Cancellable cancellable;
    private Thread<bool>? sender_thread;
    private Thread<bool>? receiver_thread;
    private AsyncQueue<Payload?> outgoing_queue;
    private MainContext ctx;

    public Transport(GLib.Socket socket, string name) {
        GLib.Object(socket: socket, name: name);
        outgoing_queue = new AsyncQueue<Payload?>();
    }

    /** This signal may is emitted from the thread that called start(). */
    public virtual signal void error_occured(GLib.Error e) {
        Drt.warn_error(e, "Transport error:");
    }

    /** This signal may be emitted from any thread. */
    public signal void received(Payload payload);

    public void start() {
        cancellable = new Cancellable();
        ctx = MainContext.ref_thread_default();
        receiver_thread = new Thread<bool>(name + "::receiver", receive_from_socket);
        sender_thread = new Thread<bool>(name + "::sender", send_to_socket);
    }

    public void stop() {
        if (cancellable != null) {
            cancellable.cancel();
        }
        if (receiver_thread != null) {
            receiver_thread.join();
            receiver_thread = null;
        }
        if (sender_thread != null) {
            sender_thread.join();
            receiver_thread = null;
        }
        if (cancellable != null) {
            cancellable = null;
        }
    }

    public void send(Payload payload) {
        outgoing_queue.push(payload);
    }

    private bool receive_from_socket() {
        try {
            while (!cancellable.is_cancelled()) {
                // The first record is a msg header without any ancillary data. Each SEQPACKET record
                // must be read with with a single recv/recvmsg call with sufficient buffer size.
                uint8 header[HEADER_SIZE];

                ssize_t n_bytes = socket.receive(header, cancellable);

                if (n_bytes == 0) {
                    throw new Error.NO_DATA("Cannot read header."); // Probably EOF
                }
                if (n_bytes != HEADER_SIZE) {
                    throw new Error.MALFORMED("Malformed header.");
                }


                ulong offset = 0;
                int32 header_id;
                int32 header_flags;
                int32 header_body_size;
                int32 header_n_fds;
                Drt.Blobs.int32_from_blob(slice(header, ref offset, sizeof(int32)), out header_id);
                Drt.Blobs.int32_from_blob(slice(header, ref offset, sizeof(int32)), out header_flags);
                Drt.Blobs.int32_from_blob(slice(header, ref offset, sizeof(int32)), out header_body_size);
                Drt.Blobs.int32_from_blob(slice(header, ref offset, sizeof(int32)), out header_n_fds);

                uint8[] body = new uint8[header_body_size];
                SocketControlMessage[]? ancillary;
                int flags = SocketMsgFlags.NONE;
                n_bytes = socket.receive_message(
                    null,
                    {InputVector() {buffer = (void*) body, size = body.length}},
                    out ancillary,
                    ref flags,
                    cancellable
                );
                if (n_bytes == 0) {
                    throw new Error.NO_DATA("Cannot read header."); // Probably EOF
                }
                if (n_bytes != header_body_size) {
                    throw new Error.MALFORMED("Malformed body.");
                }

                int[] fds = new int[header_n_fds];

                if (ancillary != null) {
                    foreach(unowned SocketControlMessage anc in ancillary) {
                        if (anc.get_level() != SOL_SOCKET || anc.get_type() != SCM_RIGHTS) {
                            throw new Error.MALFORMED(
                                "Unsupported anc level (%d) or type (%d).",
                                anc.get_level(),
                                anc.get_type()
                            );
                        }
                        if (anc.get_size() != header_n_fds * sizeof(int)) {
                            throw new Error.MALFORMED("Wrong anc size.");
                        }

                        unowned uint8[] anc_buffer = (uint8[]) ((void*) fds);
                        anc_buffer.length = (int) (header_n_fds * sizeof(int));
                        anc.serialize(anc_buffer);

                    }
                } else if (header_n_fds > 0) {
                    throw new Error.MALFORMED("File descriptors expected.");
                }

                var payload = new Payload(
                    (uint) header_id,
                    (MessageType) header_flags,
                    new GLib.ByteArray.take((owned) body),
                    (owned) fds
                );

                received(payload);
            }

            return true;
        } catch (GLib.Error e) {
            GLib.Error err = e; // Vala bug
            Drt.EventLoop.add_idle(() => {
                error_occured(err);
                stop();
                return false;
            }, Priority.HIGH_IDLE, ctx);
            return false;
        }
    }

    private bool send_to_socket() {
        try {
            while (!cancellable.is_cancelled()) {
                Payload? payload = outgoing_queue.pop();
                if (payload == null) {
                    break;
                }

                uint8 header[HEADER_SIZE];
                ulong offset = 0;
                Drt.Blobs.int32_to_blob((int32) payload.id, slice(header, ref offset, sizeof(int32)));
                Drt.Blobs.int32_to_blob(payload.type, slice(header, ref offset, sizeof(int32)));
                Drt.Blobs.int32_to_blob((int32) payload.data.len, slice(header, ref offset, sizeof(int32)));
                Drt.Blobs.int32_to_blob(payload.fds == null ? 0 : payload.fds.length, slice(header, ref offset, sizeof(int32)));

                ssize_t n_bytes = socket.send(header, cancellable);
                if (n_bytes != HEADER_SIZE) {
                    throw new Error.WRITE("Could not write a complete header but only %d/%u bytes.", (int) n_bytes, (uint) HEADER_SIZE);
                }

                SocketControlMessage[]? ancillary = null;

                if (payload.fds != null && payload.fds.length > 0) {
                    unowned uint8[] buffer = (uint8[])((void*) payload.fds);
                    buffer.length = (int) (payload.fds.length * sizeof(int));
                    ancillary = {SocketControlMessage.deserialize(SOL_SOCKET, SCM_RIGHTS, buffer)};
                }

                n_bytes = socket.send_message(
                    null,
                    {OutputVector() {buffer = payload.data, size = payload.data.len}},
                    ancillary,
                    SocketMsgFlags.NONE,
                    cancellable
                );
                if (n_bytes != payload.data.len) {
                    throw new Error.WRITE("Could not write a complete payload but only %d/%u bytes.", (int) n_bytes, payload.data.len);
                }

            }
            return true;
        } catch (GLib.Error e) {
            GLib.Error err = e; // Vala bug
            Drt.EventLoop.add_idle(() => {
                error_occured(err);
                stop();
                return false;
            }, Priority.HIGH_IDLE, ctx);
            return false;
        }
    }
}

} // namespace Nuvola.Messaging
