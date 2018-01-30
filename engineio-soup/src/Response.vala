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

public class Response {
    public HashTable<string, string> headers {get; private set;}
    public Soup.Message? msg {get; private set;}
    public uint status_code {get; set;}
    private Soup.Server? server;


    public Response(Soup.Server server, Soup.Message msg) {
        this.server = server;
        this.msg = msg;
        this.status_code = 500;
        headers = new HashTable<string, string>(str_hash, str_equal);
        server.pause_message(msg);
    }

    public void reset(Soup.Server server, Soup.Message msg) {
        this.server = server;
        this.msg = msg;
        this.status_code = 500;
        headers.remove_all();
        server.pause_message(msg);
    }

    public void end_bytes(owned Bytes data) {
        uint8[] buffer = Bytes.unref_to_data((owned) data);
        end((owned) buffer);
    }

    public void end_string(owned string data) {
        end(data.data);
    }

    public void end(owned uint8[]? buffer=null) {
        return_if_fail(msg != null);
        unowned string header;
        unowned string value;
        HashTableIter<string, string> iter = HashTableIter<string, string>(headers);
        while (iter.next(out header, out value)) {
            msg.response_headers.replace(header, value);
        }
        if (buffer != null) {
            msg.response_body.append_take((owned) buffer);
        }
        msg.status_code = status_code;
        server.unpause_message(msg);
        headers.remove_all();
        server = null;
        msg = null;
    }
}

} // namespace Engineio
