/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 * -> Engine.io-soup - the Vala/libsoup port of the Engine.io library
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

public class Channel: GLib.Object {
    public Server server {get; private set;}
    private SList<Socket> clients = null;

    public Channel(Server server) {
        this.server = server;
        server.connection.connect(on_server_connection);
    }

    private void on_server_connection(Engineio.Server server, Engineio.Socket socket) {
        clients.prepend(socket);
        socket.message_received.connect(on_message_received);
    }

    private void on_message_received(Engineio.Socket socket, string msg) {
        MessageType type;
        int id;
        string method;
        Json.Node? data = null;
        if (!deserialize_message(msg, out type, out id, out method, out data)) {
            warning("Failed to deserialize message: %s", msg);
            return;
        }
        switch (type) {
        case MessageType.REQUEST:
        case MessageType.SUBSCRIBE:
            handle_request.begin(socket, type, id, method, data, (o, res) => {handle_request.end(res);});
            break;
        default:
            warning("Other message types unsupported: %s", type.to_string());
            break;
        }
    }

    protected virtual async void handle_request(Engineio.Socket socket, MessageType type, int id, string method, Json.Node? node) {
        Idle.add(handle_request.callback);
        yield;
        string msg = serialize_message(MessageType.RESPONSE, id, method, node);
        socket.send_message(msg);
    }
}

} // namespace Engineio
