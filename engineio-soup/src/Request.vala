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
namespace Engineio
{

public class Request
{
    public Soup.Message? msg {get; private set;}
    public string url;
    public string method;
    public unowned Soup.MessageHeaders headers;
    public unowned SocketAddress remote_address;
    private GLib.HashTable<string,string>? query;
    /* transport: indicates the transport name. Supported ones by default are polling, flashsocket, websocket. */
    public string? transport = null;
    /* j: if the transport is polling but a JSONP response is required, j must be set with the JSONP response index. */
    public int jsonp_index = -1;
    /* sid: if the client has been given a session id, it must be included in the querystring. */
    public string? sid = null;
    /* b64: if the client doesn't support XHR2, b64=1 is sent in the query string to signal the server that all binary data should be sent base64 encoded.*/
    public bool base64 = false;

    public Request(Soup.ClientContext client, Soup.Message msg, GLib.HashTable<string,string>? query)
    {
        this.msg = msg;
        this.method = msg.method;
        this.headers = msg.request_headers;
        this.query = query;
        this.url = msg.get_uri().to_string(false);
        this.remote_address = client.get_remote_address();
        if (query != null)
        {
            transport = query["transport"];
            var jsonp_str = query["j"];
            if (jsonp_str != null)
            jsonp_index = int.parse(jsonp_str);
            sid = query["sid"];
            base64 = query["b64"] != null && query["b64"] == "1";
        }
    }

    public bool in_query(string key)
    {
        return query != null && key in query;
    }

    public string? get_query_param(string param)
    {
        return query != null ? query[param] : null;
    }

    public int64 get_content_length()
    {
        return msg.request_body.length;
    }

    public string get_data_as_string()
    {
        assert(msg.request_body.data != null);
        return (string) msg.request_body.data;
    }

    public Bytes get_data_as_bytes()
    {
        assert(msg.request_body.data != null);
        return new Bytes(msg.request_body.data);
    }

}

} // namespace Engineio
