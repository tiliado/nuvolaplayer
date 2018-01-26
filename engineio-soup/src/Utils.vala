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

namespace Engineio.Utils {
/**
 * Converts byte array to hexadecimal string.
 *
 * @param array        byte array to convert
 * @param result       converted value
 * @param separator    separator of hexadecimal pairs ('\0' for none)
 */
public void bin_to_hex(uint8[] array, out string result, char separator='\0') {
    var size = separator == '\0' ? 2 * array.length : 3 * array.length - 1;
    var buffer = new StringBuilder.sized(size);
    bin_to_hex_buf(array, buffer, separator);
    result = buffer.str;
}

/**
 * Converts byte array to hexadecimal string and stores in buffer.
 *
 * @param array        byte array to convert
 * @param buffer       where to store converted value in
 * @param separator    separator of hexadecimal pairs ('\0' for none)
 */
public void bin_to_hex_buf(uint8[] array, StringBuilder buffer, char separator='\0') {
    string hex_chars = "0123456789abcdef";
    for (var i = 0; i < array.length; i++) {
        if (i > 0 && separator != '\0') {
            buffer.append_c(separator);
        }
        buffer.append_c(hex_chars[(array[i] >> 4) & 0x0F]).append_c(hex_chars[array[i] & 0x0F]);
    }
}

/**
 * Generate hexadecimal uuid string
 *
 * @return Hexadecimal uuid string.
 */
public string generate_uuid_hex() {
    uint8 uuid[16] = {};
    UUID.generate(uuid);
    string hex_uuid = null;
    bin_to_hex(uuid, out hex_uuid);
    return hex_uuid;
}

} // namespace Engineio.Utils
