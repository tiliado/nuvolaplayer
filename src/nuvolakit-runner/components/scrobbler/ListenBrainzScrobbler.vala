/*
 * Copyright 2014-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class ListenBrainzScrobbler: AudioScrobbler {
    public const string HTTP_GET = "GET";
    public const string HTTP_POST = "POST";
    private const string SUBMIT_ENDPOINT = "/1/submit-listens";
    private const string VALIDATE_TOKEN_ENDPOINT = "/1/validate-token";

    public string? session {get; protected set; default = null;}
    public override bool has_session { get { return session != null; }}
    protected Soup.Session connection;
    protected string api_root;

    public ListenBrainzScrobbler(Soup.Session connection) {
        GLib.Object(id: "listenbrainz", name: "ListenBrainz");
        this.connection = connection;
        this.api_root = "https://api.listenbrainz.org";

        can_update_now_playing = scrobbling_enabled && has_session;
        can_scrobble = scrobbling_enabled && has_session;
        notify.connect_after(on_notify);
    }

    public override Gtk.Widget? get_settings(Drtgtk.Application app) {
        return new ListenBrainzScrobblerSettings(this, app);
    }

    public override void drop_session() {
        session = null;
        username = null;
    }

    public async Drt.JsonObject validate_token(string token) throws AudioScrobblerError {
        string url = "%s?token=%s".printf(VALIDATE_TOKEN_ENDPOINT, token);
        Drt.JsonObject response = yield send_request(HTTP_GET, url, false, null, 2);

        bool valid = response.get_bool_or("valid", false);
        if (!valid) {
            throw new AudioScrobblerError.NOT_AUTHENTICATED(
                "%d %s",
                response.get_int_or("code", 0),
                response.get_string_or("message")
            );
        }
        return response;
    }

    public override async void retrieve_username() throws AudioScrobblerError {
        if (this.session == null) {
            return;
        }
        Drt.JsonObject response = yield validate_token(this.session);
        username = response.get_string_or("user_name");
    }

    public async void set_token(string token) throws AudioScrobblerError {
        Drt.JsonObject response = yield validate_token(token);
        session = token;
        username = response.get_string_or("user_name");
    }

    /**
     * Updates now playing status on ListenBrainz
     *
     * @param song song name
     * @param artist artist name
     * @throws AudioScrobblerError on failure
     */
    public async override void update_now_playing(string song, string artist) throws AudioScrobblerError {
        return_if_fail(session != null);

        var builder = new Drt.JsonBuilder();
        builder.begin_object();
        builder.set_string("listen_type", "playing_now");
        builder.set_member("payload").begin_array();
        builder.begin_object();
        builder.set_member("track_metadata").begin_object();
        builder.set_string("artist_name", artist);
        builder.set_string("track_name", song);

        var data = (Drt.JsonObject) builder.root;
        yield send_request(HTTP_POST, SUBMIT_ENDPOINT, true, data, 20);
    }

    /**
     * Scrobbles track to ListenBrainz
     *
     * @param song song name
     * @param artist artist name
     * @param timestamp Unix time
     * @throws AudioScrobblerError on failure
     */
    public async override void scrobble_track(string song, string artist, string? album, int64 timestamp)
    throws AudioScrobblerError {
        return_if_fail(session != null);
        debug("%s scrobble: %s by %s from %s, %s", id, song, artist, album, timestamp.to_string());

        var builder = new Drt.JsonBuilder();
        builder.begin_object();
        builder.set_string("listen_type", "single");
        builder.set_member("payload").begin_array();
        builder.begin_object();
        builder.set_int("listened_at", (int) timestamp);
        builder.set_member("track_metadata").begin_object();
        builder.set_string("artist_name", artist);
        builder.set_string("track_name", song);
        if (album != null) {
            builder.set_string("release_name", album);
        }

        var data = (Drt.JsonObject) builder.root;
        yield send_request(HTTP_POST, SUBMIT_ENDPOINT, true, data, 20);
    }

    /**
     * Send Last.fm API request
     *
     * @param method HTTP method to use to send request
     * @param params Last.fm API parameters of request
     * @return Root JSON object of the response
     * @throws AudioScrobblerError on failure
     */
    private async Drt.JsonObject send_request(string method, string endpoint, bool authorize, Drt.JsonObject? data, uint retry=0) throws AudioScrobblerError {
        Soup.Message message;
        if (method == HTTP_GET) {
            message = new Soup.Message(method, api_root + endpoint);
        } else if (method == HTTP_POST) {
            message = new Soup.Message(method, api_root + endpoint);
            message.set_request("application/json", Soup.MemoryUse.COPY, data.to_compact_string().data);
        } else {
            message = null;
            error("%s: Unsupported request method: %s", id, method);
        }


        unowned Soup.MessageHeaders headers = message.request_headers;
        headers.append("Accept", "application/json");

        if (authorize) {
            headers.append("Authorization", "Token " + this.session);
        }

        while (true) {
            try {
                SourceFunc resume = send_request.callback;
                connection.queue_message(message, () => {
                    Idle.add((owned) resume);
                });
                yield;

                if (message.status_code < 200 || message.status_code >= 500) {
                    throw new AudioScrobblerError.RETRY("%u %s", message.status_code, message.reason_phrase);
                }

                string response = (string) message.response_body.flatten().data;
                debug("Status: %u %s", message.status_code, message.reason_phrase);

                Drt.JsonObject root;
                try {
                    root = Drt.JsonParser.load_object(response);
                } catch (Drt.JsonError e) {
                    throw new AudioScrobblerError.JSON_PARSE_ERROR(e.message);
                }

                int code = root.get_int_or("code", (int) message.status_code);
                if (code >= 400) {
                    string error = root.get_string_or("error", message.reason_phrase);
                    throw new AudioScrobblerError.LASTFM_ERROR("%d: %s", code, error);
                }

                return root;
            } catch (AudioScrobblerError e) {
                if (retry == 0 || !(e is AudioScrobblerError.RETRY)) {
                    throw e;
                }

                retry--;
                warning("%s: Retry: %s", id, e.message);
                SourceFunc resume = send_request.callback;
                Timeout.add_seconds(15, (owned) resume);
                yield;
            }
        }
    }

    private void on_notify(ParamSpec param) {
        switch (param.name) {
        case "scrobbling-enabled":
        case "session":
            can_scrobble = can_update_now_playing = scrobbling_enabled && has_session;
            break;
        }
    }
}

} // namespace Nuvola
