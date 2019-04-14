/*
 * Copyright 2016-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class HttpRequest {
    public Soup.Message message {get; private set;}
    public uint status_code {get {return message.status_code;}}
    public uint retry_attempts {get; private set; default = 0;}
    public int64 duration {get; private set;}
    private int64 timestamp = 0;
    private HttpClient client;
    bool reauthorization_disabled = false;


    public HttpRequest(HttpClient client, Soup.Message message) {
        this.client = client;
        this.message = message;
    }

    public async bool send(bool retry=true) {
        this.timestamp = GLib.get_monotonic_time();
        yield send_internal(retry, 0);
        return is_ok();
    }

    private async void send_internal(bool retry, uint attempt) {
        Soup.Message msg = this.message;
        client.add_headers(msg);
        SourceFunc resume = send_internal.callback;
        client.soup.queue_message(msg, (s, m) => {Drt.EventLoop.add_idle((owned) resume);});
        yield;

        if (retry && attempt <= 10 && (msg.status_code < 200 || msg.status_code >= 500)) {
            float backoff = attempt > 0 ? 1.0f * (Math.powf(2.0f, (float) (attempt - 1))) : 0.0f;
            warning(
                "HTTP Retry (%u, back off %f) because of %u %s",
                attempt + 1, backoff, msg.status_code, Soup.Status.get_phrase(msg.status_code));
            if (backoff > 0) {
                yield Drt.EventLoop.sleep((uint) (backoff * 1000));
            }
            yield send_internal(retry, attempt + 1);
            return;
        }
        if (msg.status_code == 401 && !reauthorization_disabled) {
            reauthorization_disabled = true;
            msg.request_headers.remove("Authorization");
            if (yield client.authorize()) {
                yield send_internal(retry, attempt + 1);
                reauthorization_disabled = false;
                return;
            }
            reauthorization_disabled = false;
        }
        this.retry_attempts = attempt;
        this.duration = GLib.get_monotonic_time() - timestamp;
    }

    public string get_reason() {
        return "%u: %s".printf(message.status_code, Soup.Status.get_phrase(message.status_code));
    }

    public unowned string get_reason_phrase() {
        return Soup.Status.get_phrase(message.status_code);
    }

    public bool is_ok() {
        return status_code >= 200 && status_code < 400;
    }

    public bool is_not_found() {
        return status_code == 404;
    }

    public bool is_unauthorized() {
        return status_code == 401;
    }

    public bool is_network_error() {
        return status_code < 100;
    }

    public Drt.JsonObject get_json_object() throws Drt.JsonError {
        return Drt.JsonParser.load_object(get_string());
    }

    public Drt.JsonObject? get_json_object_or_null() {
        try {
            return get_json_object();
        } catch (Drt.JsonError e) {
            Drt.warn_error(e, "Failed to parse response as JSON object.");
            return null;
        }
    }

    public Drt.JsonArray get_json_array() throws Drt.JsonError {
        return Drt.JsonParser.load_array(get_string());
    }

    public Drt.JsonArray? get_json_array_or_null() {
        try {
            return get_json_array();
        } catch (Drt.JsonError e) {
            Drt.warn_error(e, "Failed to parse response as JSON array.");
            return null;
        }
    }

    public unowned string? get_string() {
        return (string) message.response_body.flatten().data;
    }
}


public class HttpClient : GLib.Object {
    public Soup.Session soup {get; set;}
    public string? base_uri {get; set;}

    public HttpClient(string? base_uri, bool debug_soup) {
        this.base_uri = base_uri;
        soup = new Soup.Session();
        if (debug_soup) {
            soup.add_feature(new Soup.Logger(Soup.LoggerLogLevel.BODY, -1));
        }
    }

    public Soup.URI? make_uri(string? uri) {
        if (Drt.String.is_empty(uri)) {
            // Both base_uri and URI are empty
            return_val_if_fail(!Drt.String.is_empty(base_uri), null);
            return new Soup.URI(base_uri);
        }
        if (uri.has_prefix("https://") || uri.has_prefix("http://")) {
            return new Soup.URI(uri);
        }
        // URI must start with http or https when base_uri is empty.
        return_val_if_fail(!Drt.String.is_empty(base_uri), null);
        return new Soup.URI(base_uri + uri);
    }

    public virtual HttpRequest? call(
        string? url, HashTable<string, string>? params=null, HashTable<string, string>? headers=null
    ) {
        Soup.URI? uri = make_uri(url);
        return_val_if_fail(uri != null, null);
        if (params != null) {
            uri.set_query_from_form(params);
        }
        var msg = new Soup.Message.from_uri("GET", uri);
        debug("HttpJsonClient GET %s", uri.to_string(false));
        if (headers != null) {
            headers.for_each(msg.request_headers.replace);
        }
        return create_request(msg);
    }

    public virtual HttpRequest? post(string? url, HashTable<string, string>? data=null,
        HashTable<string, string>? params=null, HashTable<string, string>? headers=null
    ) {
        Soup.URI? uri = make_uri(url);
        return_val_if_fail(uri != null, null);
        if (params != null) {
            uri.set_query_from_form(params);
        }
        var msg = new Soup.Message.from_uri("POST", uri);
        debug("HttpJsonClient POST %s", uri.to_string(false));
        if (headers != null) {
            headers.for_each(msg.request_headers.replace);
        }
        if (data != null) {
            string? url_encoded_data = Soup.Form.encode_hash(data);
            if (url_encoded_data != null) {
                msg.set_request(Soup.FORM_MIME_TYPE_URLENCODED, Soup.MemoryUse.COPY, url_encoded_data.data);
            }
        }
        return create_request(msg);
    }

    public HttpRequest create_request(Soup.Message msg) {
        return new HttpRequest(this, msg);
    }

    public virtual async bool authorize() {
        return true;
    }

    public virtual void add_headers(Soup.Message msg) {
    }
}

} // namespace Nuvola
