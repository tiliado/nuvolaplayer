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


public class Connection : GLib.Object {
    private HashTable<void*, RequestCallback?> outgoing_requests;
    private HashTable<void*, Result?> incoming_responses;
    private Codec codec;
    private Transport transport;
    private MainContext ctx;
    private uint last_payload_id = 0;
    private const int MAX_ID = int32.MAX;

    public Connection(Transport transport, Codec codec, MainContext ctx) {
        this.codec = codec;
        this.transport = transport;
        this.ctx = ctx;
    }

    public void start() {
        transport.received.connect(on_payload_received);
        transport.start();
    }

    public void stop() {
        transport.received.disconnect(on_payload_received);
        transport.stop();
    }

    [Signal (detailed = true)]
    public signal void notification_received(uint id, string name, Variant? params);

    [Signal (detailed = true)]
    public signal void request_received(uint id, string name, Variant? params, int[]? fds);

    public signal void error_occured(Error e);

    public async Result call(string func, Variant? data, owned int[]? fds) throws Error {
        var tuple = new Variant.tuple({func, data ?? new Variant("mv", null)});
        Payload payload = create_payload(MessageType.REQUEST, codec.encode(tuple, null), (owned) fds, call.callback);
        transport.send(payload);
        debug("Call #%u '%s' dispatched.", payload.id, func);
        yield;
        return get_result(payload.id);

    }

    public void send_notification(string name, Variant? data) throws Error {
        var tuple = new Variant.tuple({name, data ?? new Variant("mv", null)});
        Payload payload = create_payload(MessageType.NOTIFICATION, codec.encode(tuple, null), null, null);
        transport.send(payload);
        debug("Notification #%u '%s' dispatched.", payload.id, name);
    }

    public void send_response(uint request_id, Variant? data, owned int[]? fds) throws Error {
        var tuple = new Variant.tuple(
            {new Variant.int32(0), new Variant("ms", null), data ?? new Variant("mv", null)}
        );
        var payload = new Payload(request_id, MessageType.RESPONSE, codec.encode(tuple, fds), (owned) fds);
        transport.send(payload);
    }

    public void send_error(uint request_id, int error_code, string? error_message) throws Error {
        var tuple = new Variant.tuple({
            new Variant.int32(error_code), new Variant("ms", error_message), new Variant("mv", null)}
        );
        var payload = new Payload(request_id, MessageType.RESPONSE, codec.encode(tuple, null), null);
        transport.send(payload);
    }

    private Payload create_payload(MessageType type, owned ByteArray? data, owned int[]? fds, owned SourceFunc? cb) {
        Payload payload;
        lock (last_payload_id) {
            lock (outgoing_requests) {
                uint id = last_payload_id;
                do {
                    if (id == MAX_ID) {
                        id = 1;
                    } else {
                        id++;
                    }
                }
                while (outgoing_requests.contains(id.to_pointer()));

                last_payload_id = id;
                payload = new Payload(id, type, (owned) data, (owned) fds);
                if (type == MessageType.REQUEST) {
                    outgoing_requests[id.to_pointer()] = new RequestCallback((owned) cb);
                }
            }
        }
        return payload;
    }

    /**
     * Return response for given message id
     *
     * @param id    Message id
     * @return response data
     * @throw local or remote errors arisen from the request
     */
    private Result get_result(uint id) throws Error {
        Result? result;
        lock (outgoing_requests) {
            result = incoming_responses[id.to_pointer()];
            incoming_responses.remove(id.to_pointer());
        }
        if (result == null) {
            throw new Error.NOT_FOUND("Response with id %u has not been found.", id);
        }
        return result;
    }

    private void on_payload_received(Payload payload) {
        try {
            Bytes bytes = ByteArray.free_to_bytes((owned) payload.data);
            Variant data = codec.decode(bytes, payload.fds);

            switch (payload.type) {
            case MessageType.NOTIFICATION:
                process_notification(payload.id, data);
                break;
            case MessageType.REQUEST:
                process_request(payload.id, data, (owned) payload.fds);
                break;
            case MessageType.RESPONSE:
                process_response(payload.id, data, (owned) payload.fds);
                break;
            default:
                throw new Error.MALFORMED("Unknown flags.");
            }
        } catch (Error e) {
            Error err = e; // Vala bug
            Drt.EventLoop.add_idle(() => {
                error_occured(err);
                return false;
            }, Priority.HIGH_IDLE, ctx);
        }
    }


    private void process_notification(uint id, Variant data) throws Error {
        Variant? tuple = Drt.VariantUtils.unbox(data);
        if (tuple == null || !tuple.is_container() || tuple.n_children() != 2) {
            throw new Error.MALFORMED(
                "Malformed tuple %u - wrong type %s.",
                id,
                tuple == null ? null : tuple.get_type_string()
            );
        }

        Variant? item = Drt.VariantUtils.unbox(tuple.get_child_value(0));
        if (item == null || !item.is_of_type(VariantType.STRING)) {
            throw new Error.MALFORMED(
                "Malformed tuple %u - wrong error code type %s.",
                id,
                item == null ? null : item.get_type_string()
            );
        }

        var notification = new Notification(
            this, id, item.get_string(), Drt.VariantUtils.unbox(tuple.get_child_value(1))
        );
        notification.invoke(ctx);
    }

    private void process_request(uint id, Variant data, owned int[]? fds) throws Error {
        Variant? tuple = Drt.VariantUtils.unbox(data);
        if (tuple == null || !tuple.is_container() || tuple.n_children() != 2) {
            throw new Error.MALFORMED(
                "Malformed tuple %u - wrong type %s.",
                id,
                tuple == null ? null : tuple.get_type_string()
            );
        }

        Variant? item = Drt.VariantUtils.unbox(tuple.get_child_value(0));
        if (item == null || !item.is_of_type(VariantType.STRING)) {
            throw new Error.MALFORMED(
                "Malformed tuple %u - wrong error code type %s.",
                id,
                item == null ? null : item.get_type_string()
            );
        }

        var request = new Request(
            this, id, item.get_string(), Drt.VariantUtils.unbox(tuple.get_child_value(1)), (owned) fds
        );
        request.invoke(ctx);
    }

    private void process_response(uint id, Variant data, owned int[]? fds) throws Error {
        RequestCallback? cb;
        lock (outgoing_requests) {
            cb = outgoing_requests[id.to_pointer()];
            outgoing_requests.remove(id.to_pointer());
        }
        if (cb == null) {
            throw new Error.NOT_FOUND("Response with id %u has not been found.", id);
        }

        int error_code = 0;
        string? error_message = null;
        Variant? params = null;

        Variant? tuple = Drt.VariantUtils.unbox(data);

        if (tuple == null || !tuple.is_container() || tuple.n_children() != 3) {
            error_code = -1;
            error_message = "Malformed tuple %u - wrong type %s.".printf(
                id, tuple == null ? null : tuple.get_type_string()
            );
        } else {
            Variant? item = Drt.VariantUtils.unbox(tuple.get_child_value(0));
            if (item == null || !item.is_of_type(VariantType.INT32)) {
                error_code = -1;
                error_message = "Malformed tuple %u - wrong error code type %s.".printf(
                    id,
                    item == null ? null : item.get_type_string()
                );
            } else {
                error_code = item.get_int32();
                item = Drt.VariantUtils.unbox(tuple.get_child_value(1));
                if (item == null) {
                    error_message  = null;
                    params = tuple.get_child_value(2);
                } else if (item.is_of_type(VariantType.STRING)) {
                    error_message = item.get_string();
                    params = tuple.get_child_value(2);
                } else {
                    error_code = -1;
                    error_message = "Malformed tuple %u - wrong error_message type %s.".printf(
                        id,
                        item.get_type_string()
                    );
                }
            }
        }

        lock (incoming_responses) {
            incoming_responses[id.to_pointer()] = new Result(error_code, (owned) error_message, params, (owned) fds);
        }

        cb.invoke(ctx);
    }
}

public class Result {
    public int error_code;
    public string? error_message;
    public Variant? data;
    public int[]? fds;

    public Result(int error_code, owned string? error_message, owned Variant? data, owned int[]? fds) {
        this.error_code = error_code;
        this.error_message = (owned) error_message;
        this.data = (owned) data;
        this.fds = (owned) fds;
    }

    public Variant? get() throws Error {
        if (!is_ok()) {
            throw new Error.REMOTE_ERROR("%d: %s", error_code, error_message);
        }
        return data;
    }

    public bool is_ok() {
        return error_code == 0;
    }
}

private class RequestCallback {
    public SourceFunc cb;

    public RequestCallback(owned SourceFunc cb) {
        this.cb = (owned) cb;
    }

    public void invoke(MainContext ctx) {
        Drt.EventLoop.add_idle((owned) cb, Priority.HIGH_IDLE, ctx);
    }
}




private class Notification {
    public Connection conn;
    public uint id;
    public string name;
    public Variant? params;


    public Notification(Connection conn, uint id, owned string name, Variant? params) {
        this.conn = conn;
        this.id = id;
        this.name = (owned) name;
        this.params = params;

    }


    public void invoke(MainContext ctx) {
        Drt.EventLoop.add_idle(idle_callback, Priority.HIGH_IDLE, ctx);
    }

    private bool idle_callback() {
        conn.notification_received[name](id, name, params);
        return false;
    }
}

private class Request {
    public Connection conn;
    public uint id;
    public string name;
    public Variant? params;
    public int[]? fds;

    public Request(Connection conn, uint id, owned string name, Variant? params, owned int[]? fds) {
        this.conn = conn;
        this.id = id;
        this.name = (owned) name;
        this.params = params;
        this.fds = (owned) fds;
    }


    public void invoke(MainContext ctx) {
        Drt.EventLoop.add_idle(idle_callback, Priority.HIGH_IDLE, ctx);
    }

    private bool idle_callback() {
        conn.request_received[name](id, name, params, fds);
        return false;
    }
}


} // namespace Nuvola.Messaging
