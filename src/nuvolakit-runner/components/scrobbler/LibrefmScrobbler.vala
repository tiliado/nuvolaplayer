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

public class LibrefmScrobbler : LastfmCompatibleScrobbler {
    private string handshake_endpoint = null;
    private bool handshake_performed = false;
    private string? session_id = null;
    private string? now_playing_endpoint = null;
    private string? submission_endpoint = null;

    public LibrefmScrobbler(Soup.Session connection) {
        base(connection, "librefm", "Libre.fm",
            "http://libre.fm/api/auth/",
            "nuv",
            "a string 32 characters in length",
            "http://libre.fm/2.0/");
        handshake_endpoint = "http://turtle.libre.fm/";
    }

    public override async void update_now_playing(string song, string artist) throws AudioScrobblerError {
        if (!handshake_performed) {
            yield perform_handhake();
        }
        var params = new HashTable<string, string>(null, null);
        params["s"] = session_id;
        params["a"] = artist;
        params["t"] = song;
        params["b"] = "";
        params["l"] = "";
        params["n"] = "";
        params["m"] = "";
        yield send_request(HTTP_POST, now_playing_endpoint, params, 3);
    }

    /**
     * Scrobbles track to Last.fm
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
        var params = new HashTable<string, string>(null, null);
        params["s"] = session_id;
        params["a[0]"] = artist;
        params["t[0]"] = song;
        params["i[0]"] = timestamp.to_string();
        params["o[0]"] = "R";
        params["r[0]"] = "";
        params["l[0]"] = "";
        params["b[0]"] = "";
        params["n[0]"] = "";
        params["m[0]"] = "";
        yield send_request(HTTP_POST, submission_endpoint, params, 3);
    }

    private async void perform_handhake() throws AudioScrobblerError {
        if (Drt.String.is_empty(username)) {
            yield retrieve_username();
        }
        string timestamp = new DateTime.now_utc().to_unix().to_string();
        var params = new HashTable<string, string>(null, null);
        params["hs"] = "true";
        params["p"] = "1.2.1";
        params["c"] = api_key;
        params["v"] = "1.0";
        params["u"] = username;
        params["t"] = timestamp;
        params["a"] = Checksum.compute_for_string(ChecksumType.MD5, api_secret + timestamp);
        params["api_key"] = api_secret;
        params["sk"] = session;

        string response = yield send_request(HTTP_GET, handshake_endpoint, params, 3);
        string[] lines = response.split("\n");
        if (lines.length < 4) {
            throw new AudioScrobblerError.WRONG_RESPONSE("Invalid response: %s", response);
        }
        session_id = lines[1];
        now_playing_endpoint = lines[2];
        submission_endpoint = lines[3];
        handshake_performed = true;
    }

    /**
     * Send Last.fm API request
     *
     * @param method HTTP method to use to send request
     * @param endpoint The endpoint of the request.
     * @param params Last.fm API parameters of request
     * @return Data of the response
     * @throws AudioScrobblerError on failure
     */
    private async string? send_request(
        string method, string endpoint, HashTable<string, string> params, uint retry=0
    ) throws AudioScrobblerError {
        Soup.Message message;
        var buffer = new StringBuilder();
        HashTableIter<string, string> iter = HashTableIter<string, string>(params);
        unowned string key;
        unowned string value;
        while (iter.next(out key, out value)) {
            if (buffer.len > 0) {
                buffer.append_c('&');
            }
            buffer.append(Uri.escape_string(key, "", true));
            buffer.append_c('=');
            buffer.append(Uri.escape_string(value, "", true));
        }

        if (method == HTTP_GET) {
            message = new Soup.Message(method, endpoint + "?" + buffer.str);
        } else if (method == HTTP_POST) {
            message = new Soup.Message(method, endpoint);
            message.set_request("application/x-www-form-urlencoded",
                Soup.MemoryUse.COPY, buffer.data);
        } else {
            message = null;
            error("%s: Unsupported request method: %s", id, method);
        }

        while (true) {
            try {
                SourceFunc resume = send_request.callback;
                connection.queue_message(message, () => {
                    Idle.add((owned) resume);
                });
                yield;

                string response = (string) message.response_body.flatten().data;
                if (response.has_prefix("OK")) {
                    return (owned) response;
                }
                if (response.has_prefix("BANNED")) {
                    throw new AudioScrobblerError.BANNED("%s: Client was banned.", id);
                }

                if (response.has_prefix("BADTIME")) {
                    throw new AudioScrobblerError.BAD_TIME(
                        "%s: The timestamp provided was not close enough to the current time.", id);
                }

                if (response.has_prefix("BADAUTH")) {
                    drop_session();
                    throw new AudioScrobblerError.NO_SESSION(
                        "%s: Session expired. Please re-authenticate.", id);
                }
                throw new AudioScrobblerError.RETRY(
                    "%s: %s", id, response);
            } catch (AudioScrobblerError e) {
                if (retry == 0 && !(e is AudioScrobblerError.RETRY)) {
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

    public override void drop_session() {
        handshake_performed = false;
        session_id = null;
        now_playing_endpoint = null;
        submission_endpoint = null;
        base.drop_session();
    }
}

} // namespace Nuvola

