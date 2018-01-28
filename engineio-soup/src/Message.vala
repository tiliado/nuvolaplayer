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

public enum MessageType {
    REQUEST, RESPONSE, SUBSCRIBE, NOTIFICATION;
}

public string stringify_json(Json.Node? node, out int size) {
    if (node == null) {
        size = 0;
        return "";
    }
    var generator = new Json.Generator();
    generator.pretty = true;
    generator.indent = 4;
    generator.set_root(node);
    size_t data_size = 0;
    string data = generator.to_data(out data_size);
    size = (int) data_size;
    return (owned) data;
}

public string serialize_message(MessageType type, int id, string method, Json.Node? data) {
    int data_size = 0;
    string data_str = stringify_json(data, out data_size);
    return "%d%d:%d:%s%d:%s".printf(
        (int) type, id, Parser.utf16_strlen(method), method, Parser.utf16_strlen(data_str), data_str);
}

public bool deserialize_message(string message, out MessageType type, out int id, out string method, out Json.Node? data) {
    // FIXME: Str len is in utf-16 code points.
    type = (MessageType) int.parse(message.substring(0, 1));
    id = 0;
    data = null;
    method = null;

    int msg_size = message.length;
    var int_str = new StringBuilder();
    int i;
    for (i = 1; i < msg_size; i++) {
        if (message[i] != ':') {
            int_str.append_c((char) message[i]);
        }
        else {
            id = int.parse(int_str.str);
            if (id < 0)
            return false;
            i++;
            break;
        }
    }

    int_str.truncate();
    for (; i < msg_size; i++) {
        if (message[i] != ':') {
            int_str.append_c((char) message[i]);
        }
        else {
            int size = int.parse(int_str.str);
            if (size <= 0)
            return false;
            i++;
            method = message.substring(i, size);
            i += size;
            break;
        }
    }

    int_str.truncate();
    for (; i < msg_size; i++) {
        if (message[i] != ':') {
            int_str.append_c((char) message[i]);
        }
        else {
            int size = int.parse(int_str.str);
            if (size < 0)
            return false;

            i++;
            if (size == 0) {
                data = null;
            }
            else {
                var parser = new Json.Parser();
                try {
                    parser.load_from_data(message.substring(i, size));
                }
                catch (GLib.Error e) {
                    data = null;
                    return false;
                }
                if (parser.get_root() == null)
                data = null;
                else
                data = parser.get_root().copy();
            }
            break;
        }
    }
    return true;
}

} // namespace Engineio
