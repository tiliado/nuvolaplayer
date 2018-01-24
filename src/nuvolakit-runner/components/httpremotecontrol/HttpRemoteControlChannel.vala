/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

#if EXPERIMENTAL
namespace Nuvola.HttpRemoteControl
{

public errordomain ChannelError
{
    PARSE_ERROR,
    APP_NOT_FOUND,
    INVALID_REQUEST;
}

public class Channel: Engineio.Channel
{
    private unowned Server http_server;

    public Channel(Engineio.Server eio_server, Server http_server)
    {
        base(eio_server);
        this.http_server = http_server;
    }

    protected override async void handle_request(Engineio.Socket socket, Engineio.MessageType type, int id, string method, Json.Node? node)
    {
        Variant? params = null;
        string status;
        Json.Node? result = null;
        try
        {
            if (node != null)
            {
                try
                {
                    params = Json.gvariant_deserialize(node, "a{smv}");
                }
                catch (GLib.Error e)
                {
                    throw new ChannelError.PARSE_ERROR("Failed to parse JSON params: %s. Ensure you have passed an object/mapping/dictionary.", e.message);
                }
            }

            var variant_result = yield http_server.handle_eio_request(socket, type, method, params);
            if (variant_result == null || !variant_result.get_type().is_subtype_of(VariantType.DICTIONARY))
            {
                var builder = new VariantBuilder(new VariantType("a{smv}"));
                if (variant_result != null)
                g_variant_ref(variant_result); // FIXME: How to avoid this hack
                builder.add("{smv}", "result", variant_result);
                result = Json.gvariant_serialize(builder.end());
            }
            else
            {
                result = Json.gvariant_serialize(variant_result);
            }
            status = "OK";
        }
        catch (GLib.Error e)
        {
            status = "ERROR";
            var builder = new VariantBuilder(new VariantType("a{sv}"));
            builder.add("{sv}", "error", new Variant.int32(e.code));
            builder.add("{sv}", "message", new Variant.string(e.message));
            builder.add("{sv}", "quark", new Variant.string(e.domain.to_string()));
            result = Json.gvariant_serialize(builder.end());
        }

        var msg = Engineio.serialize_message(Engineio.MessageType.RESPONSE, id, status, result);
        socket.send_message(msg);
    }

    public void send_notification(Engineio.Socket socket, string path, Variant? data)
    {
        Json.Node? result = null;
        if (data == null || !data.get_type().is_subtype_of(VariantType.DICTIONARY))
        {
            var builder = new VariantBuilder(new VariantType("a{smv}"));
            if (data != null)
            g_variant_ref(data); // FIXME: How to avoid this hack
            builder.add("{smv}", "result", data);
            result = Json.gvariant_serialize(builder.end());
        }
        else
        {
            result = Json.gvariant_serialize(data);
        }
        var msg = Engineio.serialize_message(Engineio.MessageType.NOTIFICATION, 0, path, result);
        socket.send_message(msg);
    }
}
} // namespace Nuvola.HttpRemoteControl
#endif
