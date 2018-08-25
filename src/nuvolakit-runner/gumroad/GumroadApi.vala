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

namespace Nuvola {

public class GumroadApi : GLib.Object {
    private static bool debug_soup;
    private Soup.Session soup;
    private string api_endpoint;

    static construct {
        debug_soup = Environment.get_variable("GUMROAD_DEBUG_SOUP") == "yes";
    }

    public GumroadApi(string? api_endpoint) {
        soup = new Soup.Session();
        if (debug_soup) {
            soup.add_feature(new Soup.Logger(Soup.LoggerLogLevel.BODY, -1));
        }
        this.api_endpoint = api_endpoint ?? "https://api.gumroad.com/v2/";
    }

    public async GumroadLicense get_license(string product_id, string license_key, bool increment_uses_count)
    throws Oauth2Error {
        var data = new HashTable<string, string>(str_hash, str_equal);
        data["product_permalink"] = product_id;
        data["license_key"] = license_key;
        data["increment_uses_count"] = increment_uses_count.to_string();
        Drt.JsonObject response = yield call_post("licenses/verify", data);
        response["x_product_id"] = new Drt.JsonValue.@string(product_id);
        response["x_license_key"] = new Drt.JsonValue.@string(license_key);
        return new GumroadLicense.from_json(response);
    }

    public virtual async Drt.JsonObject call_post(string? method, HashTable<string, string>? data=null,
        HashTable<string, string>? params=null, HashTable<string, string>? headers=null)
    throws Oauth2Error {
        var uri = new Soup.URI(api_endpoint + (method ?? ""));
        if (params != null) {
            uri.set_query_from_form(params);
        }
        var msg = new Soup.Message.from_uri("POST", uri);
        if (headers != null) {
            headers.for_each(msg.request_headers.replace);
        }
        if (data != null) {
            string? url_encoded_data = Soup.Form.encode_hash(data);
            if (url_encoded_data != null) {
                msg.set_request(Soup.FORM_MIME_TYPE_URLENCODED, Soup.MemoryUse.COPY, url_encoded_data.data);
            }
        }
        return yield send_message(msg);
    }

    private async Drt.JsonObject send_message(Soup.Message msg) throws Oauth2Error {
        SourceFunc resume_cb = send_message.callback;
        soup.queue_message(msg, (s, m) => {Idle.add((owned) resume_cb);});
        yield;
        unowned string response_data = (string) msg.response_body.flatten().data;
        if (msg.status_code < 200 || msg.status_code >= 300) {
            string http_error = "%u: %s".printf(msg.status_code, Soup.Status.get_phrase(msg.status_code));
            switch (msg.status_code) {
            case 401:
                throw new Oauth2Error.HTTP_UNAUTHORIZED(http_error);
            case 404:
                throw new Oauth2Error.HTTP_NOT_FOUND(http_error);
            default:
                throw new Oauth2Error.HTTP_ERROR(http_error);
            }
        }
        try {
            return Drt.JsonParser.load_object(response_data);
        } catch (GLib.Error e) {
            throw new Oauth2Error.PARSE_ERROR(e.message);
        }
    }
}

} // namespace Nuvola
