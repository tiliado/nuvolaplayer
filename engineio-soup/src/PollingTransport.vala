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


public delegate void OnCloseCallback();

public abstract class PollingTransport: Transport {
    private int close_timeout;
    public int max_http_buffer_size {get; set;}
    private Request? poll_request = null;
    private Response? poll_response = null;
    private Request? data_request = null;
    private Response? data_response = null;
    public bool http_compression = false;
    private uint close_timeout_id = 0;
    private OnCloseCallback on_close_callback = null;


    public static PollingTransport new_for_request(Request request) {
        if (request.jsonp_index < 0) {
            return new XhrTransport(request);
        } else {
            return new JsonpTransport(request);
        }
    }

    protected PollingTransport(Request request) {
        base(request);
        this.name = "polling";
        this.close_timeout = 30 * 1000;
        this.max_http_buffer_size = -1;
        headers_requested.connect(on_headers_requested);
    }

    public override async void handle_request(Request request, Response response) {
        if (request.method == "GET") {
            yield handle_poll_request(request, response);
        } else if (request.method == "POST") {
            yield handle_data_request(request, response);
        } else {
            response.status_code = 500;
            response.end();
        }
    }

    private async void handle_poll_request(Request request, Response response) {
        if (this.poll_request != null) {
            debug("Concurrent poll request discarded.");
            response.status_code = 500;
            response.end(null);
            return;
        }

        this.poll_request = request;
        this.poll_response = response;
        request.msg.finished.connect(on_poll_request_finished);

        writable = true;
        draining();

        if (writable && should_close) {
            debug("Triggering empty send to append close packet");
            send_one(new Packet(PacketType.NOOP, null, null));
        }
    }

    private void on_poll_request_finished(Soup.Message msg) {
        msg.finished.disconnect(on_poll_request_finished);
        writable = false;
        if (writable == true) {
            writable = false;
            discarded = true;
            close_transport(null);
        }
        this.poll_request = null;
        this.poll_response = null;
    }

    private async void handle_data_request(Request request, Response response) {
        if (this.data_request != null) {
            debug("Concurrent data request discarded.");
            response.status_code = 500;
            response.end();
            return;
        }

        bool is_binary = "application/octet-stream" == request.headers.get_one("content-type");
        this.data_request = request;
        this.data_response = response;

        if (request.get_content_length() > max_http_buffer_size) {
            debug("Data request too big.");
            this.data_request = null;
            this.data_response = null;
            response.status_code = 400;
            response.end();
            return;
        }

        if (is_binary) {
            yield handle_incoming_data(null, request.get_data_as_bytes());
        } else {
            yield handle_incoming_data(request.get_data_as_string(), null);
        }

        if (this.data_response != null) {
            response.status_code = 200;
            response.headers["Content-Type"] = "text/html";
            response.headers["Content-Length"] = "2";
            headers_requested(request, response.headers);
            response.end_string("ok");
        }

        this.data_request = null;
        this.data_response = null;
    }

    /**
     * Processes the incoming data payload.
     *
     * @param {String} encoded payload
     * @api private
     */

    protected override async void handle_incoming_data(owned string? string_payload, Bytes? binary_payload) {
        debug("Received payload: string:'%s', bytes:len(%d)", string_payload, binary_payload == null ? 0 : binary_payload.length);
        var decoder = new Parser.PayloadDecoder((owned) string_payload, binary_payload);
        try {
            Packet? packet = null;
            while (decoder.next(out packet)) {
                if (packet.type == PacketType.CLOSE) {
                    debug("Received polling close packet");
                    on_close();
                    break;
                }
                yield handle_incoming_packet(packet);
            }
        } catch (Parser.Error e) {
            handle_decode_error(e);
        }
    }

    protected override void on_close() {
        if (writable) {
            // close pending poll request
            send_one(new Packet(PacketType.NOOP, null, null));
        }
        base.on_close();
    }

    public override void send(owned SList<Packet> packets) {
        writable = false;
        if (should_close) {
            debug("Appending close packet to payload.");
            packets.append(new Packet(PacketType.CLOSE, null, null));
            if (close_timeout_id > 0) {
                GLib.Source.remove(close_timeout_id);
                close_timeout_id = 0;
            }
            if (on_close_callback != null) {
                on_close_callback();
                on_close_callback = null;
            }
            should_close = false;
        }

        string? payload = Parser.encode_payload(packets);
        // TODO: this.supports_binary = > encode_payload_as_bytes
        if (payload != null) {
            var compress = false;
            write(payload, compress);
        } else {
            writable = true;
        }
    }

    /**
     * Writes data as response to poll request.
     *
     * @param {String} data
     * @param {Object} options
     * @api private
     */

    private void write(string data, bool compress=false) {
        debug("Writing '%s'", data);
        do_write(data, null, compress);
        this.poll_request = null;
        this.poll_response = null;
    }


    /**
     * Performs the write.
     *
     * @api private
     */

    protected virtual void do_write(owned string? str_data, Bytes? bin_data, bool compress) {
        bool is_string = str_data != null;
        string content_type = is_string
        ? "text/plain; charset=UTF-8"
        : "application/octet-stream";

        poll_response.headers["Content-Type"] = content_type;

        if (!http_compression || !compress) {
            poll_response.headers["Content-Length"] = (is_string ? str_data.length : bin_data.length).to_string();
            poll_response.status_code = 200;
            if (is_string) {
                poll_response.end_string(str_data);
            } else {
                poll_response.end_bytes(bin_data);
            }

            return;
        }

        /* TODO: compression */
    }

    /**
     * Closes the transport.
     *
     * @api private
     */

    protected override void close_transport(owned CloseCallback? callback) {
        message("Closing");
        if (data_request != null) {
            message("Aborting ongoing data request");
            data_response.status_code = 500;
            data_response.end();
            data_request = null;
            data_response = null;
        }

        if (writable) {
            message("Transport writable - closing right away");
            send_one(new Packet(PacketType.CLOSE, null, null));
            if (callback != null) {
                callback();
            }
            on_close();
        } else if (discarded) {
            message("transport discarded - closing right away");
            if (callback != null) {
                callback();
            }
            on_close();
        } else {
            debug("transport not writable - buffering orderly close");
            this.should_close = true;
            close_timeout_id = Timeout.add(close_timeout, close_timeout_cb);
        }
    }

    private bool close_timeout_cb() {
        close_timeout_id = 0;

        if (on_close_callback != null) {
            on_close_callback();
            on_close_callback = null;
        }
        on_close();
        return false;
    }

    protected virtual void on_headers_requested(Request request, HashTable<string, string> headers) {
        // prevent XSS warnings on IE
        // https://github.com/LearnBoost/socket.io/pull/1333
        string? ua = request.headers.get_one("user-agent");
        if (ua != null && ((";MSIE" in ua) || ("Trident/" in ua))) {
            headers["X-XSS-Protection"] = "0";
        }
    }
}

} // namespace Engineio
