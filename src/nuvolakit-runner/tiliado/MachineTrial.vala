/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class MachineTrial : GLib.Object {
    public TiliadoMembership tier {get; construct;}
    public string? name {get; construct;}
    public DateTime? created {get; construct;}
    public DateTime? expires {get; construct;}

    public MachineTrial.from_json(Drt.JsonObject? json) {
        string? name = null;
        string? created = null;
        string? expires = null;
        int tier = 0;
        if (json != null) {
            tier = json.get_int_or("tier");
            name = json.get_string_or("name");
            created = json.get_string_or("created");
            expires = json.get_string_or("expires");
        }
        GLib.Object(
            tier: TiliadoMembership.from_int(tier), name: (owned) name,
            created: created != null ? new DateTime.from_iso8601(created, new TimeZone.utc()) : null,
            expires: expires != null ? new DateTime.from_iso8601(expires, new TimeZone.utc()) : null
        );
    }

    public MachineTrial.from_string(string json) {
        Drt.JsonObject? object = null;
        try {
            object = Drt.JsonParser.load_object(json);
        } catch (Drt.JsonError e) {
            Drt.warn_error(e, "Failed to load trial:");
        }
        this.from_json(object);
    }

    public Drt.JsonBuilder to_json() {
        var builder = new Drt.JsonBuilder();
        builder.begin_object();
        builder.set_int("tier", (int) tier);
        if (created != null) {
            builder.set_string("created", Drt.Utils.datetime_to_iso_8601(created));
        } else {
            builder.set_null("created");
        }
        if (expires != null) {
            builder.set_string("expires", Drt.Utils.datetime_to_iso_8601(expires));
        } else {
            builder.set_null("expires");
        }
        builder.set_string_or_null("name", name);
        return builder;
    }

    public bool has_expired() {
        return expires == null || expires.compare(new DateTime.now_local()) < 0;
    }

    public string to_string() {
        return to_json().to_pretty_string();
    }

    public string to_compact_string() {
        return to_json().to_compact_string();
    }
}

} // namespace Nuvola
