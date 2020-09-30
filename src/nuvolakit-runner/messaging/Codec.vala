/*
 * Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
namespace Nuvola.Messaging {


public class Codec {
    public Variant decode(GLib.Bytes data, int[]? fds) throws Error {
        ulong offset = 0;
        Marker marker;
        Variant? result = deserialize(data.get_data(), fds, ref offset, out marker);
        if (result == null) {
            throw new Error.DECODE("Unexpected type marker %d.", marker);
        }
        if (offset != data.length) {
            throw new Error.DECODE("Not all data were consumed: %d bytes left.", data.length - (int) offset);
        }
        return result;
    }

    public GLib.ByteArray encode(Variant? data, int[]? fds) throws Error {
        var result = new GLib.ByteArray();
        serialize(data, result, fds);
        return result;
    }
}


public Variant? deserialize(uint8[] data, int[]? fds, ref ulong offset, out Marker marker) throws Error {
    if (!next_marker(data, ref offset, out marker)) {
        throw new Error.DECODE("Cannot read type marker.");
    }

    unowned uint8[] buffer;

    switch (marker) {
    case Marker.FALSE:
        return new Variant.boolean(false);
    case Marker.TRUE:
        return new Variant.boolean(true);
    case Marker.NONE:
        return new Variant("mv", null);
    case Marker.INT64:
        buffer = slice(data, ref offset, sizeof(int64));
        if (buffer == null) {
            throw new Error.DECODE("Not enough bytes left to read int64: %d", data.length - (int) offset);
        }
        int64 i64;
        Drt.Blobs.int64_from_blob(buffer, out i64);
        return new Variant.int64(i64);
    case Marker.DOUBLE:
        buffer = slice(data, ref offset, sizeof(double));
        if (buffer == null) {
            throw new Error.DECODE("Not enough bytes left to read double: %d", data.length - (int) offset);
        }
        double d = 0.0;
        double* dp = &d;
        Posix.memcpy((void*) dp, buffer, sizeof(double));
        return new Variant.double(d);
    case Marker.STRING:
        return new Variant.string(deserialize_string(data, ref offset));
    case Marker.FD:
        int32 handle = 0;
        buffer = slice(data, ref offset, sizeof(int32));
        if (buffer == null) {
            throw new Error.DECODE("Not enough bytes left to read int32: %d", data.length - (int) offset);
        }
        Drt.Blobs.int32_from_blob(buffer, out handle);
        if (fds == null || handle < 0 || handle >= fds.length) {
            throw new Error.DECODE("Wrong handle value %d (max %d).", handle, fds == null ? -1 : fds.length);
        }
        return new Variant.handle(handle);
    case Marker.ARRAY_START:
        var builder = new VariantBuilder(new VariantType ("av"));
        Marker item_marker;
        Variant? item;
        while ((item = deserialize(data, fds, ref offset, out item_marker)) != null) {
            builder.add("v", item);
        }
        if (item_marker != Marker.ARRAY_END) {
            throw new Error.DECODE("Expected %d, got %d.", Marker.ARRAY_END, item_marker);
        }
        return builder.end();
    case Marker.DICT_START:
        var builder = new VariantBuilder(new VariantType("a{sv}"));
        Marker item_marker;
        Variant? item;
        while (true) {
            if (!next_marker(data, ref offset, out item_marker)) {
                throw new Error.DECODE("Cannot read type marker.");
            }
            if (item_marker == Marker.DICT_END) {
                break;
            }
            if (item_marker != Marker.STRING) {
                throw new Error.DECODE("Expected %d, got %d.", Marker.STRING, item_marker);
            }

            string key = deserialize_string(data, ref offset);
            item = deserialize(data, fds, ref offset, out item_marker);
            if (item == null) {
                throw new Error.DECODE("Expected dictionary value, got %d.", item_marker);
            }
            builder.add("{sv}", key, item);
        }
        return builder.end();
    case Marker.ARRAY_END:
    case Marker.DICT_END:
        return null;
    default:
        throw new Error.DECODE("Unknown type marker %d.", marker);
    }
}

public string deserialize_string(uint8[] data, ref ulong offset) throws Error {
    unowned uint8[] buffer = slice(data, ref offset, sizeof(int32));
    if (buffer == null) {
        throw new Error.DECODE("Not enough bytes left to read int32: %d", data.length - (int) offset);
    }
    int length;
    Drt.Blobs.int32_from_blob(buffer, out length);
    if (length < 0) {
        throw new Error.DECODE("Cannot read string of negative length %d.", length);
    }
    buffer = slice(data, ref offset, length + 1); // length + \0
    if (buffer == null) {
        throw new Error.DECODE("Not enough bytes left to read string(%d): %d", length, data.length - (int) offset);
    }
    return (string) buffer;
}

public unowned uint8[]? slice(uint8[] data, ref ulong offset, ulong length) {
    ulong next = offset + length;
    if (next >= data.length) {
        return null;
    }
    unowned uint8[] buffer = (uint8[]) ((uint8*) data + offset);
    buffer.length = (int) length;
    offset = next;
    return buffer;
}

public bool next_marker(uint8[] data, ref ulong offset, out Marker marker) {
    unowned uint8[]? buffer = slice(data, ref offset, sizeof(int32));
    if (buffer == null) {
        marker = Marker.NONE;
        return false;
    }
    int32 value = 0;
    Drt.Blobs.int32_from_blob(buffer, out value);
    marker = (Marker) value;
    return Marker.FALSE <= value <= Marker.FD;
}


public void serialize(Variant? data, GLib.ByteArray result, int[]? fds) throws Error {
    Variant? variant = Drt.VariantUtils.unbox(data);
    uint8[] int32_buffer = new uint8[sizeof(int32)];
    if (variant == null) {
        Drt.Blobs.int32_to_blob(Marker.NONE, int32_buffer);
        result.append(int32_buffer);
    } else if (variant.is_of_type(VariantType.VARIANT)) {
        serialize(variant.get_variant(), result, fds);
    } else {
        var object_type = new VariantType("a{s*}");
        VariantType type = variant.get_type();

        if (type.is_subtype_of(VariantType.MAYBE)) {
            Variant? maybe_variant = null;
            variant.get("m*", &maybe_variant);
            serialize(maybe_variant, result, fds);
        } else if (type.is_subtype_of(object_type)) {
            Drt.Blobs.int32_to_blob(Marker.DICT_START, int32_buffer);
            result.append(int32_buffer);
            VariantIter iter = null; // "a{s*}" (new allocation)
            variant.get("a{s*}", out iter);
            unowned string? key = null; // "&s" (unowned)
            Variant? value = null; // "*" (new reference)
            while (iter.next("{&s*}", out key, out value)) {
                Drt.Blobs.int32_to_blob(Marker.STRING, int32_buffer);
                result.append(int32_buffer);
                Drt.Blobs.int32_to_blob(key.length, int32_buffer);
                result.append(int32_buffer);
                result.append(key.data);
                serialize(value, result, fds);
                value = null; // https://gitlab.gnome.org/GNOME/vala/issues/722
            }
            Drt.Blobs.int32_to_blob(Marker.DICT_END, int32_buffer);
            result.append(int32_buffer);
        } else if (variant.is_of_type(VariantType.STRING)) {
            unowned string? str = variant.get_string();
            Drt.Blobs.int32_to_blob(Marker.STRING, int32_buffer);
            result.append(int32_buffer);
            unowned uint8[] buffer = str.data;
            Drt.Blobs.int32_to_blob(buffer.length, int32_buffer); // without terminating \0
            result.append(int32_buffer);
            result.append(buffer); // without terminating \0
            result.append({0});
        } else  if (variant.is_of_type(VariantType.BOOLEAN)) {
            Drt.Blobs.int32_to_blob(variant.get_boolean() ? Marker.TRUE : Marker.FALSE, int32_buffer);
            result.append(int32_buffer);
        } else if (variant.is_of_type(VariantType.DOUBLE)) {
            double d = variant.get_double();
            double* dp = &d;
            uint8[] double_buffer = new uint8[sizeof(double)];
            Posix.memcpy(double_buffer, (void*) dp, sizeof(double));
            result.append(double_buffer);
        } else if (variant.is_of_type(VariantType.INT64)) {
            Drt.Blobs.int32_to_blob(Marker.INT64, int32_buffer);
            result.append(int32_buffer);
            uint8[] int64_buffer = new uint8[sizeof(int64)];
            Drt.Blobs.int64_to_blob(variant.get_int64(), out int64_buffer);
            result.append(int64_buffer);
        } else if (variant.is_of_type(VariantType.HANDLE)) {
            int32 h = variant.get_handle();
            if (fds == null || h < 0 || h >= fds.length) {
                throw new Error.ENCODE("Wrong handle value %d (max %d).", h, fds == null ? -1 : fds.length);
            }
            Drt.Blobs.int32_to_blob(Marker.FD, int32_buffer);
            result.append(int32_buffer);
            Drt.Blobs.int32_to_blob(h, int32_buffer);
            result.append(int32_buffer);
        } else if (variant.is_container()) {
            Drt.Blobs.int32_to_blob(Marker.ARRAY_START, int32_buffer);
            result.append(int32_buffer);
            size_t size = variant.n_children();
            for (var i = 0; i < size; i++) {
                serialize(variant.get_child_value(i), result, fds);

            }
            Drt.Blobs.int32_to_blob(Marker.ARRAY_END, int32_buffer);
            result.append(int32_buffer);
        } else {
            throw new Error.ENCODE("Unsupported type '%s'. Content: %s", variant.get_type_string(), variant.print(true));
        }
    }
}

} // namespace Nuvola.Messaging
