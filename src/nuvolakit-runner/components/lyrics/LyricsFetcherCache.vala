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
 * File-based cache for lyrics
 */
public class LyricsFetcherCache : GLib.Object, LyricsFetcher {
    public File lyrics_cache {get; construct set;}
    private const string FILE_FORMAT = "%s/%s.txt";

    /**
     * Creates new lyrics cache
     *
     * @param storage    where to store lyrics
     */
    public LyricsFetcherCache(File lyrics_cache) {
        GLib.Object(lyrics_cache: lyrics_cache);
    }

    /**
     * {@inheritDoc}
     */
    public async string fetch_lyrics(string artist, string song) throws LyricsError {
        string fixed_artist = escape_name(artist.down());
        string fixed_song = escape_name(song.down());

        if (fixed_artist == "" || fixed_song == "") {
            throw new LyricsError.NOT_FOUND(@"Song $song was not found in cache");
        }

        File cached = lyrics_cache.get_child(FILE_FORMAT.printf(fixed_artist, fixed_song));
        try {
            uint8[] contents;
            yield cached.load_contents_async(null, out contents, null);
            string lyrics = (string) (owned) contents;
            if (lyrics != null && lyrics != "") {
                return lyrics;
            }
        } catch (GLib.Error e) {
            if (e.code != 1) {
                warning("Unable to load cached lyrics: [%d] ]%s", e.code, e.message);
                throw new LyricsError.NOT_FOUND(@"Unable to load song $song from cache");
            }
        }
        throw new LyricsError.NOT_FOUND(@"Song $song was not found in cache");
    }

    /**
     * Store lyrics to cache.
     *
     * @param artist    artist name
     * @param song      song name
     * @param lyrics    lyrics text
     */
    public async void store(string artist, string song, owned string lyrics) {
        string fixed_artist = escape_name(artist.down());
        string fixed_song = escape_name(song.down());

        if (fixed_artist == "" || fixed_song == "") {
            return;
        }

        try {
            File cached_file = lyrics_cache.get_child(FILE_FORMAT.printf(fixed_artist, fixed_song));
            yield Drt.System.write_to_file_async(cached_file, (owned) lyrics);
        } catch (GLib.Error e) {
            warning("Unable to store lyrics: %s", e.message);
        }
    }

    /**
     * Escapes name for safe usage in file names
     *
     * @param name    string to escape
     * @return        escaped name
     */
    private string escape_name(string name) {
        return GLib.Uri.escape_string(name, " ").replace("%", ",");
    }
}

} // namespace Nuvola
