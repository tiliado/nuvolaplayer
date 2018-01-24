/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola
{

public class MediaKeysClient : GLib.Object, MediaKeysInterface
{
    public bool managed {get; protected set; default=false;}
    private string app_id;
    private Drt.RpcChannel conn;

    public class MediaKeysClient(string app_id, Drt.RpcChannel conn)
    {
        this.conn = conn;
        this.app_id = app_id;
        conn.router.add_method("/nuvola/mediakeys/media-key-pressed", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            null, handle_media_key_pressed, {
            new Drt.StringParam("key", true, false)
        });
    }

    public void manage()
    {
        if (managed)
            return;

        const string METHOD = "/nuvola/mediakeys/manage";
        try
        {
            var data = conn.call_sync(METHOD, new Variant("(s)", app_id));
            Drt.Rpc.check_type_string(data, "b");
            managed = data.get_boolean();
        }
        catch (GLib.Error e)
        {
            warning("Remote call %s failed: %s", METHOD, e.message);
        }
    }

    public void unmanage()
    {
        if (!managed)
            return;

        const string METHOD = "/nuvola/mediakeys/unmanage";
        try
        {
            var data = conn.call_sync(METHOD, new Variant("(s)", app_id));
            Drt.Rpc.check_type_string(data, "b");
            managed = !data.get_boolean();
        }
        catch (GLib.Error e)
        {
            warning("Remote call %s failed: %s", METHOD, e.message);
        }
    }

    private void handle_media_key_pressed(Drt.RpcRequest request) throws Drt.RpcError
    {
        var key = request.pop_string();
        media_key_pressed(key);
        request.respond(new Variant.boolean(true));
    }
}

} // namespace Nuvola
