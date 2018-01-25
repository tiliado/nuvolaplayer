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

namespace Engineio
{

[CCode(has_target=false)]
public delegate Transport TransportFactory(Request request);

/*
 * Packet: <packet type id>[<data>]
 * Payload:
 * string: <length1>:<packet1>[<length2>:<packet2>[...]]
 * binary: <length of base64 representation of the data + 1 (for packet type)>:b<packet1 type><packet1 data in b64>[...]
 *
 * JSONP: `___eio[` <j> `]("` <encoded payload> `");`
 *
 * POST data: d=<escaped packet payload (URI encoded>
 */

public class Server: GLib.Object
{
    /* protocol revision number */
    public static int PROTOCOL_VERSION = 0;

    /*  map of available transports */
    public HashTable<string, TransportFactory> transport_factories {get; private set;}

    /* hash of connected clients by id. */
    public HashTable<string, Socket> clients;

    public string path {get; private set; default = "/engine.io/";}

    /* number of connected clients.*/
    public int clients_count = 0;

    public Soup.Server? soup {get; private set; default = null;}

    /* how many ms without a pong packet to consider the connection closed (60000) */
    public int ping_timeout = 60 * 1000;

    /* how many ms before sending a new ping packet (25000) */
    public int ping_interval =  25 * 1000;

    /* how many bytes or characters a message can be when polling, before closing the session (to avoid DoS). Default value is 10E7. */
    public int max_http_buffer_size = 10 * 1000 *1000;

    /* transports to allow connections to (['polling', 'websocket']) */
    public string[] available_transports = {"polling"};

    /* whether to allow transport upgrades (true) */
    public bool allow_upgrades = false;

    /* httpCompression (Object|Boolean): parameters of the http compression for the polling transports (see zlib api docs). Set to false to disable. (true) */
    public bool http_compression = false;

    /* cookie (String|Boolean): name of the HTTP cookie that contains the client sid to send as part of handshake response headers. Set to false to not send one. (io)*/
    public string cookie = "io";

    /* cookiePath (String|Boolean): path of the above cookie option. If false, no path will be sent, which means browsers will only send the cookie on the engine.io attached path (/engine.io). Set this to / to send the io cookie on all requests. (false)*/
    public string? cookie_path = null;


    public Server(Soup.Server? soup=null, string? path=null)
    {
        clients = new HashTable<string, Socket>(str_hash, str_equal);
        transport_factories = new HashTable<string, TransportFactory>(str_hash, str_equal);
        transport_factories["polling"] = PollingTransport.new_for_request;
        if (soup != null)
        attach(soup, path);
    }

    /**
     * Emitted when a socket buffer is being flushed.
     *
     * @param socket    socket being flushed
     * @param buffer    write buffer
     */
    public signal void socket_flushed(Socket socket, ref SList<Packet> buffer);

    /**
     * Emitted when a socket buffer is drained.
     *
     * @param socket    socket being flushed
     */
    public signal void socket_drained(Socket socket);

    /**
     * Emitted when a new connection is established.
     *
     * @param socket    a Socket object
     */
    public signal void connection(Socket socket);


    public void attach(Soup.Server soup, string? path=null)
    {
        return_if_fail(this.soup == null);
        this.soup = soup;
        if (path != null)
        this.path = path.has_suffix("/") ? path : path + "/";
        soup.add_handler(this.path, engine_io_handler);
    }

    public string generate_id(Request request)
    {
        return Utils.generate_uuid_hex();
    }

    /**
     * Returns a list of available transports for upgrade given a certain transport.
     *
     * @param transport    The transport to upgrade.
     * @return Array of transport identifiers.
     */
    public string[] list_upgrades(string transport)
    {
        if (!allow_upgrades)
        return {};
        // TODO: transports[transport].upgradesTo || [];
        return {};
    }

    /**
     * Verifies a request.
     *
     * @param {http.ServerRequest}
     * @return {Boolean} whether the request is valid
     * @api private
     */
    protected bool verify_request(Request request, bool upgrade, out EngineError? err)
    {
        // transport check
        err = null;
        var transport = request.transport;
        if (transport == null || !transport_factories.contains(transport))
        {
            debug("unknown transport '%s'", transport);
            err = EngineError.UNKNOWN_TRANSPORT;
            return false;
        }

        // sid check
        var sid = request.sid;
        if (sid != null)
        {
            if (!(sid in clients))
            {
                err = EngineError.UNKNOWN_SID;
                return false;
            }
            if (!upgrade && clients[sid].transport.name != transport)
            {
                debug("bad request: unexpected transport without upgrade");
                err = EngineError.BAD_REQUEST;
                return false;
            }
        }
        else if (request.method != "GET") // handshake is GET only
        {
            err = EngineError.BAD_HANDSHAKE_METHOD;
            return false;
        }
        return true;
    }

    /**
     * Closes all clients
     */
    public void close()
    {
        debug("closing all open clients");
        unowned string id = null;
        unowned Socket socket = null;
        var iter = HashTableIter<string, Socket>(clients);
        while (iter.next(out id, out socket))
        {
            socket.close(true);
        }
    }

    /**
     * Called internally when a Engine request is intercepted.
     *
     * Request: a node request object
     * Response: a node response object
     */
    public async void handle_request(Request request, Response response)
    {
        debug("Handling '%s' http request '%s'", request.method, request.url);
        EngineError? err = null;
        if (!verify_request(request, false, out err))
        {
            send_error_message(request, response, err);
            return;
        }

        if (request.sid != null)
        {
            debug("Setting new request for existing client %s", request.sid);
            yield clients[request.sid].transport.handle_request(request, response);
        }
        else
        {
            yield perform_handshake(request.transport, request, response);
        }
    }

    /**
     * Sends an Engine.IO Error Message
     *
     * @param {http.ServerResponse} response
     * @param {code} error code
     * @api private
     */

    private void send_error_message(Request request, Response response, EngineError code)
    {
        response.headers["Content-Type"] = "application/json";

        var origin = request.headers.get_one("origin");
        if (origin != null)
        {
            response.headers["Access-Control-Allow-Credentials"] = "true";
            response.headers["Access-Control-Allow-Origin"] = origin;
        }
        else
        {
            response.headers["Access-Control-Allow-Origin"] = "*";
        }
        response.status_code = 400;
        response.end_string("""{"code": "%d", "message": "%s"}""".printf((int) code, code.to_string()));
    }

    /**
     * Handshakes a new client.
     *
     * @param {String} transport name
     * @param {Object} request object
     * @api private
     */

    private async void perform_handshake(string transport_name, Request request, Response response)
    {
        var id = generate_id(request);
        debug("Handshaking new client '%s'", id);

        var transport_factory = transport_factories[transport_name];
        if (transport_factory == null)
        {
            send_error_message(request, response, EngineError.UNKNOWN_TRANSPORT);
            return;
        }
        var transport = transport_factory(request);
        transport.sid = id;
        var polling = transport as PollingTransport;
        if (polling != null)
        {
            polling.max_http_buffer_size = this.max_http_buffer_size;
            polling.http_compression = this.http_compression;
        }
        else if ("websocket" == transport_name)
        {
            // TODO: transport.perMessageDeflate = this.perMessageDeflate;
        }

        transport.supports_binary = !request.base64;

        var socket = new Socket(id, this, transport, request);
        transport.headers_requested.connect(on_transport_headers_requested);
        yield transport.handle_request(request, response);

        clients[id] = socket;
        clients_count++;
        socket.closed.connect(on_socket_closed);
        connection(socket);
    }

    private void on_transport_headers_requested(Transport transport, Request request, HashTable<string, string> headers)
    {
        if (this.cookie != null)
        {
            var cookie = this.cookie + "=" + transport.sid;
            if (cookie_path != null)
            cookie += "; path=" + cookie_path;
            headers["Set-Cookie"] = cookie;
        }
    }

    private void on_socket_closed(Socket socket, string reason, string? description)
    {
        socket.closed.disconnect(on_socket_closed);
        clients.remove(socket.id);
        clients_count--;
    }

    private void engine_io_handler(Soup.Server server, Soup.Message msg, string request_path,
        GLib.HashTable<string, string>? query, Soup.ClientContext client)
    {
        var request = new Request(client, msg, query);
        var response = new Response(server, msg);
        debug("New engine.io request: %s %s, transport %s", request.method, request_path, request.transport);
        handle_request.begin(request, response, (o, res) => {handle_request.end(res);});
    }

}

public enum EngineError
{
    OK,
    UNKNOWN_TRANSPORT,
    UNKNOWN_SID,
    BAD_HANDSHAKE_METHOD,
    BAD_REQUEST;

    public string to_string()
    {
        switch (this)
        {
        case OK:
            return "Ok";
        case UNKNOWN_TRANSPORT:
            return "Transport unknown";
        case UNKNOWN_SID:
            return "Session ID unknown";
        case BAD_HANDSHAKE_METHOD:
            return "Bad handshake method";
        case BAD_REQUEST:
            return "Bad request";
        default:
            return "";
        }
    }
}

} // namespace Engineio
