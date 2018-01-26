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
namespace Engineio.Parser {

public errordomain Error {
    EMPTY_DATA,
    INVALID_DATA,
    INVALID_TYPE,
    INVALID_OFFSET,
    INVALID_LENGTH;
}

/**
 * Return the number of UTF-16 code points to store given string.
 *
 * It corresponds to JavaScript's String.length.
 *
 * @param str    a string
 * @return a number of UTF-16 code points
 */
public int utf16_strlen(string? str) {
    if (str == null)
    return 0;
    int len = 0;
    unichar c = 0;
    int i = 0;
    while (str.get_next_char(ref i, out c))
    len += (uint) c <= 0xFFFF ? 1 : 2;
    return len;
}

/* *** ENCODING *** */

/**
 * Encode a payload of packets as a data string.
 *
 * @param packets    Packets to encode
 * @return The payload encoded as a data string or null if there are no packets.
 */
public string? encode_payload(SList<Packet> packets) {
    if (packets == null)
    return null;

    var buffer = new StringBuilder();
    foreach (unowned Packet packet in packets) {
        var data = encode_packet(packet);
        /* Engine.io protocol requires a string length to be in UTF-16 characters rather than in bytes */
        buffer.append_printf("%d:", utf16_strlen(data));
        buffer.append((owned) data);
    }
    return buffer.str;
}

/**
 * Encode a payload of packets as data bytes.
 *
 * @param packets    Packets to encode
 * @return The payload encoded as bytes or null if there are no packets.
 */
public Bytes? encode_payload_as_bytes(SList<Packet> packets) {
    critical("TODO: encode_payload_as_bytes");
    return null;
}

/**
 * Encode packet as a data string.
 *
 * @param packet   Packet to encode.
 * @return The packet encoded as a string.
 */
public string encode_packet(Packet packet) {
    if (packet.bin_data != null)
    return "b%d".printf((int) packet.type) + Base64.encode((uchar[]) packet.bin_data.get_data());
    var type = ((int) packet.type).to_string();
    return packet.str_data != null ? type + packet.str_data : type;
}

/**
 * Encode packet as data bytes.
 *
 * @param packet   Packet to encode.
 * @return The packet encoded as bytes.
 */
public Bytes encode_packet_as_bytes(Packet packet) {
    var bytes = packet.bin_data;
    var data_size = bytes != null ? bytes.length : 0;
    var buffer = new ByteArray.sized(1 + data_size);
    buffer.append(new uint8[] {(uint8) packet.type});
    if (data_size > 0)
    buffer.append(bytes.get_data());
    return ByteArray.free_to_bytes((owned) buffer);
}

/* *** DECODING *** */

/**
 * Decode packet from data string
 *
 * @param data    Packet data as string.
 * @return Decoded packet.
 * @throw Error on decode failure.
 */
public Packet decode_packet(owned string data) throws Error {
    if (data[0] == '\0')
    throw new Error.EMPTY_DATA("Data string is empty.");
    if (data[0] == 'b')
    return decode_base64_packet((owned) data, 1);
    var type = int.parse(data.substring(0, 1));
    if (type < 0 || type > (int) PacketType.NOOP)
    throw new Error.INVALID_TYPE("Invalid packet type: %d.", type);
    return new Packet((PacketType) type, data.substring(1), null);
}

/**
 * Decode packet from base64-encoded data string
 *
 * @param data      Packet data as base64-encoded string.
 * @param offset    The offset where data starts.
 * @return Decoded packet.
 * @throw Error on decode failure.
 */
private Packet decode_base64_packet(owned string data, int offset=0) throws Error {
    var size = data.length;
    if (offset < 0 || offset >= size)
    throw new Error.INVALID_OFFSET("Data string offset %d is invalid. Data size is %d.", offset, size);
    var type = int.parse(data.substring(offset, 1));
    if (type < 0 || type > (int) PacketType.NOOP)
    throw new Error.INVALID_TYPE("Invalid packet type: %d.", type);
    Bytes? bytes = null;
    if (offset + 1 < size) {
        unowned string cursor = (string)(((uint8*) data) + offset + 1);
        uint8[] buffer = (uint8[]) Base64.decode(cursor);
        bytes = new Bytes.take((owned) buffer);
    }
    return new Packet((PacketType) type, null, bytes);
}

/**
 * Decode a packet from data bytes.
 *
 * @param bytes    Packet data as bytes.
 * @return Decoded packet.
 * @throw Error on decode failure.
 */
public Packet decode_packet_from_bytes(Bytes bytes) throws Error {
    var size = bytes.length;
    if (size == 0)
    throw new Error.EMPTY_DATA("Data bytes are empty.");
    unowned uint8[] data = bytes.get_data();
    var type = data[0];
    if (type < 0 || type > (int) PacketType.NOOP)
    throw new Error.INVALID_TYPE("Invalid packet type: %d.", type);
    return new Packet((PacketType) type, null, size > 1 ? bytes.slice(1, bytes.length - 1) : null);
}


/**
 * Decodes payload with iterator interface.
 */
public class PayloadDecoder {
    private StringPayloadDecoder string_decoder;
    private BinaryPayloadDecoder binary_decoder;

    /**
     * Create new PayloadDecoder.
     *
     * @param str_payload    Payload as data string.
     * @param bin_payload    Payload as binary data.
     */
    public PayloadDecoder(owned string? str_payload, Bytes? bin_payload) {
        if (bin_payload != null) {
            binary_decoder = new BinaryPayloadDecoder(bin_payload);
            string_decoder = null;
        }
        else if (str_payload != null) {
            string_decoder = new StringPayloadDecoder((owned) str_payload);
            binary_decoder = null;
        }
        else {
            string_decoder = null;
            binary_decoder = null;
        }
    }

    /**
     * Get a next packet.
     *
     * @param packet    New packet.
     * @return    true if there is a packet, false when the iterator is exhausted.
     * @throw Error on decode error.
     */
    public bool next(out Packet packet) throws Error {
        if (binary_decoder != null)
        return binary_decoder.next(out packet);
        if (string_decoder != null)
        return string_decoder.next(out packet);
        packet = null;
        return false;
    }

}

/**
 * Decodes payload with iterator interface.
 */
public class StringPayloadDecoder {
    private string payload;
    private int cursor;
    private int size;
    private bool exhausted = false;

    /**
     * Create new StringPayloadDecoder.
     *
     * @param payload    Payload as data string.
     */
    public StringPayloadDecoder(owned string payload) {
        cursor = 0;
        size = payload.length;
        exhausted = false;
        this.payload = (owned) payload;
    }

    /**
     * Get a next packet.
     *
     * @param packet    New packet.
     * @return    true if there is a packet, false when the iterator is exhausted.
     * @throw Error on decode error.
     */
    public bool next(out Packet packet) throws Error {
        packet = null;
        if (exhausted || cursor >= size)
        return false;

        var length = new StringBuilder();
        unowned string data = payload;
        for (var i = cursor; i < size; i++) {
            if (data[i] != ':') {
                length.append_c(data[i]);
            }
            else {
                var packet_len = int.parse(length.str);
                if (packet_len < 0) {
                    exhausted = true;
                    throw new Error.INVALID_LENGTH("Packet length cannot be negative: %d.", packet_len);
                }
                if (packet_len == 0) {
                    length.truncate();
                    continue;
                }
                // FIXME: Is packet_length in UTF-16 code points?
                var msg = data.substring(i + 1, packet_len);
                if (msg.length != packet_len) {
                    exhausted = true;
                    throw new Error.INVALID_LENGTH("Packet length '%d' doesn't match the real data length '%d'.", packet_len, msg.length);
                }
                packet = decode_packet((owned) msg);
                cursor = i + 1 + packet_len;
                return true;
            }
        }
        if (length.len != 0) {
            exhausted = true;
            throw new Error.INVALID_DATA("The last packet is incomplete: '%s'.", length.str);
        }
        packet = null;
        return false;
    }
}

/**
 * Decodes payload with iterator interface.
 */
public class BinaryPayloadDecoder {
    private Bytes payload;
    private int cursor;
    private int size;
    private bool exhausted = false;

    /**
     * Create new BinaryPayloadDecoder.
     *
     * @param payload    Payload as binary data.
     */
    public BinaryPayloadDecoder(Bytes payload) {
        this.payload = payload;
        cursor = 0;
        size = payload.length;
        exhausted = false;
    }

    /**
     * Get a next packet.
     *
     * @param packet    New packet.
     * @return    true if there is a packet, false when the iterator is exhausted.
     * @throw Error on decode error.
     */
    public bool next(out Packet packet) throws Error {
        packet = null;
        if (exhausted || cursor >= size)
        return false;

        unowned uint8[] data = payload.get_data();
        bool is_string = data[cursor++] == '\0';
        var length = new StringBuilder();
        var length_too_long = false;
        for (var i = cursor; i < size; i++) {
            if (data[i] == 255)
            break;
            // 310 = char length of Number.MAX_VALUE
            if (length.len > 310) {
                length_too_long = true;
                break;
            }
            length.append_c((char) data[i]);
        }
        if (length_too_long) {
            exhausted = true;
            throw new Error.INVALID_LENGTH("Packet length is too long: %d.", (int) length.len);
        }

        var packet_len = int.parse(length.str);
        if (packet_len < 0) {
            exhausted = true;
            throw new Error.INVALID_LENGTH("Packet length cannot be negative: %d.", packet_len);
        }
        cursor += 1 + (int) length.len;

        if (packet_len == 0)
        return next(out packet);

        if (is_string) {
            var buffer = new uint8[packet_len + 1];
            GLib.Memory.copy((void*) buffer, (void*) (((uint8*) data) + cursor), sizeof(uint8) * packet_len);
            //~             for (var j = 0; j < packet_len; j++)
            //~                 buffer[j] = data[cursor + j];
            buffer[packet_len] = '\0';
            string str =  (string) ((owned) buffer);
            packet = decode_packet((owned) str);
        }
        else {
            var bytes = payload.slice(cursor, cursor + packet_len);
            packet = decode_packet_from_bytes(bytes);
        }
        cursor += packet_len;
        return true;
    }
}

} // namespace Engineio.Parser
