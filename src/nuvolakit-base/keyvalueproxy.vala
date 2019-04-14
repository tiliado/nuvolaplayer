/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

public class KeyValueProxy: Drt.KeyValueStorage {
    private Drt.RpcChannel channel;
    private string prefix;

    public KeyValueProxy(Drt.RpcChannel channel, string prefix) {
        this.channel = channel;
        this.prefix = prefix;
    }

    public override bool has_key(string key) {
        try {
            Variant response = channel.call_sync("/nuvola/core/" + prefix + "-has-key", new Variant("(s)", key));
            if (response.is_of_type(VariantType.BOOLEAN)) {
                return response.get_boolean();
            }
            critical("Invalid response to KeyValueProxy.has_key: %s", response.print(false));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
        return false;
    }

    public override async bool has_key_async(string key) {
        try {
            Variant response = yield channel.call("/nuvola/core/" + prefix + "-has-key", new Variant("(s)", key));
            if (response.is_of_type(VariantType.BOOLEAN)) {
                return response.get_boolean();
            }
            critical("Invalid response to KeyValueProxy.has_key: %s", response.print(false));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
        return false;
    }

    public override Variant? get_value(string key) {
        try {
            Variant response = channel.call_sync("/nuvola/core/"+ prefix + "-get-value", new Variant("(s)", key));
            return response;
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
            return null;
        }
    }

    public override async Variant? get_value_async(string key) {
        try {
            return yield channel.call("/nuvola/core/"+ prefix + "-get-value", new Variant("(s)", key));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
            return null;
        }
    }

    protected override void set_value_unboxed(string key, Variant? value) {
        try {
            channel.call_sync("/nuvola/core/" + prefix + "-set-value", new Variant("(smv)", key, value));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
    }

    protected override async void set_value_unboxed_async(string key, Variant? value) {
        try {
            yield channel.call("/nuvola/core/" + prefix + "-set-value", new Variant("(smv)", key, value));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
    }

    protected override void set_default_value_unboxed(string key, Variant? value) {
        try {
            channel.call_sync("/nuvola/core/" + prefix + "-set-default-value", new Variant("(smv)", key, value));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
    }

    protected override async void set_default_value_unboxed_async(string key, Variant? value) {
        try {
            yield channel.call("/nuvola/core/" + prefix + "-set-default-value", new Variant("(smv)", key, value));
        } catch (GLib.Error e) {
            critical("Master client error: %s", e.message);
        }
    }

    public override void unset(string key) {
        warn_if_reached(); // FIXME
    }

    public override async void unset_async(string key) {
        warn_if_reached(); // FIXME
        yield Drt.EventLoop.resume_later();
    }
}

} // namespace Nuvola
