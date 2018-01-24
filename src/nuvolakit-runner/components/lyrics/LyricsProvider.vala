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

namespace Nuvola
{

public enum LyricsStatus
{
    NO_SONG,
    LOADING,
    DONE,
    NOT_FOUND;
}

public class LyricsProvider: GLib.Object
{
    public string? title {get; private set; default = null;}
    public string? artist {get; private set; default = null;}
    public string? lyrics {get; private set; default = null;}
    public LyricsStatus status {get; private set; default = LyricsStatus.NO_SONG;}
    private MediaPlayerModel player;
    private SList<LyricsFetcher> fetchers;
    private LyricsFetcherCache? cache = null;

    public LyricsProvider(MediaPlayerModel player, owned SList<LyricsFetcher> fetchers)
    {
        this.player = player;
        this.fetchers = (owned) fetchers;
        foreach (var fetcher in this.fetchers)
        {
            if (fetcher is LyricsFetcherCache)
            {
                cache = (LyricsFetcherCache) fetcher;
                break;
            }
        }
        player.set_track_info.connect(on_song_changed);
        song_changed(player.title, player.artist);
    }

    ~LyricsProvider()
    {
        player.set_track_info.disconnect(on_song_changed);
    }

    private void on_song_changed(string? title, string? artist, string? album, string? state,
        string? artwork_location, string? artwork_file)
    {
        song_changed(title, artist);
    }

    private void song_changed(string? title, string? artist)
    {
        if (this.title == title && this.artist == artist)
        return;

        this.title = title;
        this.artist = artist;

        if (title == null || artist == null)
        {
            status = LyricsStatus.NO_SONG;
            lyrics = null;
            no_song_info();
        }
        else
        {
            queue_fetch_lyrics(artist, title);
        }
    }

    private void queue_fetch_lyrics(string artist, string song)
    {
        lyrics_loading(artist, song);
        fetch_lyrics.begin(artist, song);
    }

    private async void fetch_lyrics(string artist, string song)
    {
        foreach (var fetcher in fetchers)
        {
            debug("Fetcher: %s", fetcher.get_type().name());
            try
            {
                var lyrics = yield fetcher.fetch_lyrics(artist, song);
                lyrics_available(artist, song, lyrics);
                if (cache != null && fetcher != cache)
                yield cache.store(artist, song, lyrics);

                return;
            }
            catch (GLib.Error e)
            {
                debug("Fetch error: %s", e.message);
            }
        }

        lyrics_not_found(artist, song);
    }

    /**
     * Emitted when there is no valid song info, so there is nothing to fetch.
     */
    public signal void no_song_info();

    /**
     * Emitted when lyrics is available.
     *
     * @param artist    artist name
     * @param song      song name
     * @param lyrics    lyrics text
     */
    public signal void lyrics_available(string artist, string song, string lyrics);

    /**
     * Emitted when lyrics has not been found.
     *
     * @param artist    artist name
     * @param song      song name
     */
    public signal void lyrics_not_found(string artist, string song);

    /**
     * Emitted when lyrics fetching was enqueued.
     *
     * @param artist    artist name
     * @param song      song name
     */
    public signal void lyrics_loading(string artist, string song);
}

} // namespace Nuvola
