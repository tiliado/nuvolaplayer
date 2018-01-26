/*
 * Copyright 2012-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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


/**
 * Lyric fetcher for [[http://www.azlyrics.com/|AZ Lyrics]].
 */
public class AZLyricsFetcher : GLib.Object, LyricsFetcher {
    public Soup.Session session {get; construct set;}
    /**
     * URL format of AZ Lyrics
     */
    private const string SONG_PAGE = "http://www.azlyrics.com/lyrics/%s/%s.html";
    private Regex html_tags;

    public AZLyricsFetcher(Soup.Session session) {
        GLib.Object(session: session);
        try {
            html_tags = new Regex("</?\\w+?( /)?>", RegexCompileFlags.CASELESS);
        }
        catch (RegexError e) {
            error("RegexError: %s", e.message);
        }
    }

    /**
     * {@inheritDoc}
     */
    public async string fetch_lyrics(string artist, string song) throws LyricsError {
        Soup.Message message;
        var url = SONG_PAGE.printf(transform_name(artist), transform_name(song));
        message = new Soup.Message("GET", url);

        SourceFunc callback = fetch_lyrics.callback;
        session.queue_message(message, () => {
            Idle.add((owned) callback);
        });
        yield;

        var response = (string) message.response_body.flatten().data;
        if (message.status_code != 200 || response == "")
        throw new LyricsError.NOT_FOUND(@"Song $song was not found on AZ Lyrics");

        response = parse_response(response);
        if (response == "")
        throw new LyricsError.NOT_FOUND(@"Song $song was not found on AZ Lyrics");

        return response;
    }

    private string parse_response(string response) {
        const string START = "<!-- Usage of azlyrics.com content";
        const string END = "</div>";
        var start_pos = response.index_of(START);
        if (start_pos >= 0) {
            start_pos = response.index_of("-->", start_pos) + 4;
            var end_pos = response.index_of(END, start_pos);
            if (end_pos >= 0) {
                var lyrics = response.slice(start_pos, end_pos);
                try {
                    lyrics = html_tags.replace_literal(lyrics, lyrics.length, 0, "");
                }
                catch (RegexError e) {
                    warning("RegexError: %s", e.message);
                }
                return replace_html_entities(lyrics.strip()) + "\n";
            }
        }
        stderr.printf("%s\n", response);
        return "";
    }

    /**
     * Transforms name to match AZLyrics identifiers
     *
     * @param name        original name
     * @return            transformed name
     */
    public static string transform_name(string name) {
        var normalized = name.normalize();
        var buffer = new StringBuilder("");
        unichar c;
        int i = 0;
        while (normalized.get_next_char(ref i, out c)) {
            c = c.tolower();
            if (('a' <= c && c <= 'z') || ('0' <= c && c <= '9'))
            buffer.append_unichar(c);
        }
        return buffer.str;
    }

    public static string replace_html_entities(string text) {
        return text.replace("&quot;", "\"").replace("&amp;", "&");
    }
}

} // namespace Nuvola
