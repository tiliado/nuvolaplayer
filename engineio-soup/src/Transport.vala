/*
 * Copyright 2016-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public delegate void CloseCallback();

public abstract class Transport: GLib.Object {
    public string sid {get; set;}
    public string name {get; protected set;}
    public bool writable {get; protected set; default = false;}
    public bool should_close {get; protected set; default = false;}
    public bool discarded {get; protected set; default = false;}
    public ReadyState ready_state {get; protected set; default = ReadyState.OPEN;}
    public bool supports_binary {get; set; default = false;}

    protected Transport(Request request) {
    }

    public void send_one(Packet packet) {
        SList<Packet> packets = null;
        packets.prepend(packet);
        send((owned) packets);
    }

    public abstract void send(owned SList<Packet> packets);

    public signal void draining();

    public signal void headers_requested(Request request, HashTable<string, string> headers);

    public signal void incoming_packet(Packet packet);

    public signal void closed();

    public virtual signal void error_occured(string msg, string? desc) {
        warning("Transport error: %s %s", msg, desc);
    }

    public abstract async void handle_request(Request request, Response response);


    /**
     * Flags the transport as discarded.
     *
     * @api private
     */
    public void discard() {
        discarded = true;
    }

    /**
     * Closes the transport.
     *
     * @api private
     */
    public void close(owned CloseCallback? callback) {
        switch (ready_state) {
        case ReadyState.CLOSED:
        case ReadyState.CLOSING:
            return;
        default:
            ready_state = ReadyState.CLOSING;
            close_transport((owned) callback);
            break;
        }
    }

    /**
     * Called with parsed out a packets from the data stream.
     *
     * @param {Object} packet
     * @api private
     */
    protected virtual async void handle_incoming_packet(Packet packet) {
        incoming_packet(packet);
    }

    protected void handle_decode_error(Parser.Error e) {
        error_occured("decode error", e.message);
    }

    /**
     * Called with the encoded packet data.
     *
     * @param {String} data
     * @api private
     */

    protected virtual async void handle_incoming_data(owned string? string_payload, Bytes? binary_payload) {
        try {
            Packet packet = binary_payload != null
            ? Parser.decode_packet_from_bytes(binary_payload)
            : Parser.decode_packet(string_payload);
            if (packet != null) {
                yield handle_incoming_packet(packet);
            }
        } catch (Parser.Error e) {
            handle_decode_error(e);
        }
    }

    /**
     * Called upon transport close.
     *
     * @api private
     */

    protected virtual void on_close() {
        ready_state = ReadyState.CLOSED;
        closed();
    }

    /**
     * Called to really close the transport
     */
    protected abstract void close_transport(owned CloseCallback? callback);
}

} // namespace Engineio
