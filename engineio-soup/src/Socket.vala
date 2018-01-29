/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 * -> Engine.io-soup - the Vala/libsoup port of the Engine.io library
 *
 * Copyright 2014 Guillermo Rauch <guillermo@learnboost.com>
 * -> The original JavaScript Engine.io library
 * -> https://github.com/socketio/engine.io
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * 'Software'), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

namespace Engineio {

public enum ReadyState {
    OPENING, OPEN, CLOSING, CLOSED;
}

public class Socket : GLib.Object {

    /* unique identifier */
    public string id {get; private set;}
    /* engine parent reference */
    public Server server {get; private set;}
    /* request that originated the Socket */
    public Request request {get; private set;}
    /* whether the transport has been upgraded */
    public bool upgraded {get; private set; default = false;}
    /* opening|open|closing|closed */
    public ReadyState ready_state {get; private set; default = ReadyState.OPENING;}
    /* transport reference */
    public Transport transport {get; private set;}

    private unowned SocketAddress remote_address;
    private SList<SendAdaptor?> sent_callbacks = null;
    private uint ping_timeout_timer = 0;
    private uint check_interval_timer = 0;
    private SList<Packet> write_buffer = null;
    private bool discard = false;

    public Socket (string id, Server server, Transport transport, Request request) {
        debug("New Socket %s originated from %s", id, request.url);
        this.id = id;
        this.server = server;
        this.transport = transport;
        this.request = request;
        this.remote_address = request.remote_address;
        attach_transport(transport);
        do_open();
    }

    /**
     * Emitted when the client is disconnected.
     *
     * @param reason         reason for closing
     * @param description    description object (optional)
     */
    public signal void closed(string reason, string? description);

    public signal void opened();

    /**
     * Emitted when the client sends a message.
     *
     * @param message   the received message
     */
    public signal void message_received(string message);

    /**
     * Emitted when the client sends a message.
     *
     * @param bytes   the received data
     */
    public signal void bytes_received(Bytes bytes);

    /**
     * Emitted when an error occurs.
     *
     * @param msg    error message
     */
    public signal void error_occured(string msg);


    /**
     * Emitted when the write buffer is being flushed.
     *
     * @param buffer    write buffer
     */
    public signal void flushing(ref SList<Packet> buffer);

    /**
     * Emitted when the write buffer is drained
     *
     */
    public signal void draining();

    public signal void heartbeat();


    /**
     * Emitted when a socket received a packet (message, ping)
     *
     * @param type    packet type
     * @param data    packet data (if type is message)
     */
    public signal void packed_received(Packet packet);

    /**
     * Emitted before a socket sends a packet (message, pong).
     *
     * @param type    packet type
     * @param data    packet data (if type is message)
     */
    public signal void packed_created(Packet packet);

    /**
     * Sends a message
     *
     * @param message     a string with outgoing data
     * @param compress    whether to compress sending data. This option might be ignored and forced to be true when using polling.
     */
    public void send_message(string message, bool compress=false) {
        send_packet(PacketType.MESSAGE, message, compress/*, callback*/);
    }

    /**
     * Sends a message
     *
     * @param node        a JSON root node
     * @param compress    whether to compress sending data. This option might be ignored and forced to be true when using polling.
     */
    public void send_json(Json.Node node, bool compress=false) {
        send_packet_json(PacketType.MESSAGE, node, compress/*, callback*/);
    }

    /**
     * Sends a message
     *
     * @param bytes       a string with outgoing data
     * @param compress    whether to compress sending data. This option might be ignored and forced to be true when using polling.
     */
    public void send_bytes(Bytes bytes, bool compress=false) {
        send_packet_bytes(PacketType.MESSAGE, bytes, compress/*, callback*/);
    }

    /**
     * Closes the socket and underlying transport.
     *
     * @param discard    whether to discard pending data
     */
    public void close(bool discard=false) {
        if (ready_state != ReadyState.OPEN) {
            return;
        }

        ready_state = ReadyState.CLOSING;
        if (write_buffer != null) {
            this.discard = discard;
            draining.connect(on_draining_after_close);
            return;
        }
        close_transport(discard);
    }

    private void on_draining_after_close() {
        draining.disconnect(on_draining_after_close);
        close_transport(discard);
    }

    /**
     * Closes the underlying transport.
     *
     * @param {Boolean} discard
     * @api private
     */
    private void close_transport(bool discard) {
        if (discard) {
            transport.discard();
        }
        transport.closed.connect(on_transport_force_closed);
        transport.close(null);
    }

    private void on_transport_force_closed(Transport transport) {
        transport.closed.disconnect(on_transport_force_closed);
        do_close("forced close", null);
    }

    /**
     * Attaches handlers for the given transport.
     *
     * @param {Transport} transport
     * @api private
     */

    private void attach_transport(Transport transport) {
        transport.error_occured.connect(on_error_occured);
        transport.incoming_packet.connect(on_incoming_packet);
        transport.closed.connect(on_closed);
        transport.draining.connect(on_draining);
        this.transport = transport;
    }

    /**
     * Called upon transport considered open.
     *
     * @api private
     */

    private void do_open() {
        ready_state = ReadyState.OPEN;

        // sends an `open` packet
        transport.sid = this.id;
        var builder = new Json.Builder();
        builder.begin_object();
        builder.set_member_name("sid").add_string_value(this.id);
        builder.set_member_name("upgrades").begin_array().end_array();
        builder.set_member_name("pingInterval").add_int_value(server.ping_interval);
        builder.set_member_name("pingTimeout").add_int_value(server.ping_timeout);
        builder.end_object();
        send_packet_json(PacketType.OPEN, builder.get_root());
        opened();
        set_ping_timeout();
    }

    /**
     * Sets and resets ping timeout timer based on client pings.
     *
     * @api private
     */

    private void set_ping_timeout() {
        if (ping_timeout_timer > 0) {
            Source.remove(ping_timeout_timer);
            ping_timeout_timer = 0;
        }
        ping_timeout_timer = Timeout.add(server.ping_interval + server.ping_timeout, on_ping_timeout);
    }

    private bool on_ping_timeout() {
        warning("Ping timeout");
        do_close("ping timeout", null);
        return false;
    }

    private void send_packet_json(PacketType type, Json.Node data, bool compress=false/*, callback*/) {
        var generator = new Json.Generator();
        generator.set_root(data);
        send_packet(type, generator.to_data(null), compress);
    }

    /**
     * Sends a packet.
     *
     * @param {String} packet type
     * @param {String} optional, data
     * @param {Object} options
     * @api private
     */
    private void send_packet(PacketType type, string? data, bool compress/*, callback*/) {
        if (ready_state != ReadyState.CLOSING) {
            debug("Sending packet %s: %s", type.to_string(), data);
            var packet = new Packet(type, data, null, compress);
            packed_created(packet);
            write_buffer.append(packet);
            //a send callback to object
            // this.packetsFn.push(callback);
            flush();
        }
    }

    private void send_packet_bytes(PacketType type, Bytes data, bool compress/*, callback*/) {
        if (ready_state != ReadyState.CLOSING) {
            debug("sending packet '%s' (bytes)", type.to_string());
            var packet = new Packet(type, null, data, compress);

            // exports packetCreate event
            packed_created(packet);
            write_buffer.append(packet);

            //add send callback to object
            // this.packetsFn.push(callback);

            flush();
        }
    }

    /**
     * Attempts to flush the packets buffer.
     *
     * @api private
     */

    private void flush() {
        if (ready_state != ReadyState.CLOSED && transport.writable && write_buffer != null) {
            debug("Flushing buffer to transport (%u items)", write_buffer.length());
            SList<Packet> buffer = (owned) write_buffer;
            write_buffer = null;
            flushing(ref buffer);
            server.socket_flushed(this, ref buffer);
            transport.send((owned) buffer);
            draining();
            server.socket_drained(this);
        }
    }

    /**
     * Called upon transport considered closed.
     * Possible reasons: `ping timeout`, `client error`, `parse error`,
     * `transport error`, `server close`, `transport close`
     */

    private void do_close(string reason, string? description) {
        if (ready_state != ReadyState.CLOSED) {
            ready_state = ReadyState.CLOSED;
            if (ping_timeout_timer > 0) {
                Source.remove(ping_timeout_timer);
                ping_timeout_timer = 0;
            }
            if (check_interval_timer > 0) {
                Source.remove(check_interval_timer);
                check_interval_timer = 0;
            }
            this.sent_callbacks = null;
            this.detach_transport();
            closed(reason, description);
            write_buffer = null;
        }
    }

    /**
     * Called upon transport packet.
     *
     * @param {Object} packet
     * @api private
     */

    private void on_incoming_packet(Packet packet) {
        if (ready_state == ReadyState.OPEN) {
            // export packet event
            debug("Packet received %s %s", packet.type.to_string(), packet.str_data);
            packed_received(packet);

            // Reset ping timeout on any packet, incoming data is a good sign of
            // other side's liveness
            set_ping_timeout();
            switch (packet.type) {
            case PacketType.PING:
                debug("got ping");
                send_packet(PacketType.PONG, null, false);
                heartbeat();
                break;
            case PacketType.MESSAGE:
                if (packet.str_data != null) {
                    message_received(packet.str_data);
                } else if (packet.bin_data != null) {
                    bytes_received(packet.bin_data);
                }
                break;
            }
        } else {
            debug("packet received with closed socket");
        }
    }

    /**
     * Called upon transport error.
     *
     * @param {Error} error object
     * @api private
     */

    private void on_error_occured(string err, string? desc) {
        debug("Error occurred: %s, %s.", err, desc);
        do_close(err, desc);
    }

    private void on_closed() {
        detach_transport();
    }

    private void detach_transport() {
        //~         var cleanup;
        //~         while (cleanup = this.cleanupFn.shift()) cleanup();
        debug("Detaching transport %s", transport != null ? transport.sid : null);
        if (ping_timeout_timer > 0) {
            Source.remove(ping_timeout_timer);
            ping_timeout_timer = 0;
        }
        if (transport != null) {
            transport.error_occured.disconnect(on_error_occured);
            transport.incoming_packet.disconnect(on_incoming_packet);
            transport.closed.disconnect(on_closed);
            transport.draining.disconnect(on_draining);
            transport.close(null);
            transport = null;
        }
    }

    /**
     * Setup and manage send callback
     *
     * @api private
     */

    private void on_draining(Transport transport) {
        flush();
        if (sent_callbacks != null) {
            foreach (unowned SendAdaptor adaptor in sent_callbacks)
            Idle.add(adaptor.source_func);
        }
    }
}

public delegate void SentCallback(Transport? transport);

public class SendAdaptor {
    public SentCallback callback;
    public Transport? transport;

    public SendAdaptor(owned SentCallback callback) {
        this.callback = (owned) callback;
        this.transport = null;
    }

    public bool source_func() {
        callback(transport);
        return false;
    }
}

} // namespace Engineio
