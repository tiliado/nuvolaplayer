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

public class LyricsSidebar: Gtk.Grid {
    private Gtk.Label status;
    private Gtk.TextView view;
    private LyricsProvider lyrics_provider;

    public LyricsSidebar(AppRunnerController app, LyricsProvider lyrics_provider) {
        this.lyrics_provider = lyrics_provider;
        row_spacing = 5;
        column_homogeneous = false;
        orientation = Gtk.Orientation.VERTICAL;

        status = new Gtk.Label(null);
        status.no_show_all = true;
        add(status);

        view = new Gtk.TextView();
        view.editable = false;
        view.left_margin = 5;
        view.right_margin = 5;
        view.pixels_above_lines = 1;
        view.pixels_below_lines = 1;
        view.wrap_mode = Gtk.WrapMode.WORD;

        var scroll = new Gtk.ScrolledWindow(null, null);
        scroll.vexpand = true;
        scroll.add(view);
        scroll.expand = true;
        add(scroll);

        lyrics_provider.lyrics_available.connect(on_lyrics_available);
        lyrics_provider.lyrics_not_found.connect(on_lyrics_not_found);
        lyrics_provider.lyrics_loading.connect(on_lyrics_loading);
        lyrics_provider.no_song_info.connect(on_no_song_info);
        scroll.show_all();

        on_no_song_info();
    }

    ~LyricsSidebar() {
        lyrics_provider.lyrics_available.disconnect(on_lyrics_available);
        lyrics_provider.lyrics_not_found.disconnect(on_lyrics_not_found);
        lyrics_provider.lyrics_loading.disconnect(on_lyrics_loading);
        lyrics_provider.no_song_info.disconnect(on_no_song_info);
    }

    private void set_status(string? text=null) {
        status.set_text(text ?? "");
        status.visible = text != null;
    }

    private void on_lyrics_available(string artist, string song, string lyrics) {
        set_status(song);
        view.buffer.set_text(lyrics);
    }

    private void on_lyrics_not_found(string artist, string song) {
        set_status(_("No lyrics has been found."));
        view.buffer.set_text("");
    }

    private void on_lyrics_loading(string artist, string song) {
        set_status(_("Fetching lyrics ..."));
        view.buffer.set_text("");
    }

    private void on_no_song_info() {
        set_status(_("No song is playing"));
        view.buffer.set_text("");
    }
}

} // namespace Nuvola
