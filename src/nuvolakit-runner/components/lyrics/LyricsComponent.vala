/*
 * Copyright 2015-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class LyricsComponent: Component {
    private const string SIDEBAR_PAGE = "lyricssidebar";
    public bool auto_open {get; set; default = false;}
    private Bindings bindings;
    private AppRunnerController app;
    private LyricsSidebar? sidebar = null;
    private LyricsProvider? provider = null;

    public LyricsComponent(AppRunnerController app, Bindings bindings, Drt.KeyValueStorage config) {
        base(config, "lyrics", "Lyrics", "Shows lyrics for the current song.", "lyrics");
        this.premium = true;
        this.has_settings = true;
        this.bindings = bindings;
        this.app = app;
        bind_config_property("auto_open", false);
        auto_activate = false;
    }

    protected override bool activate() {
        SList<LyricsFetcher> fetchers = null;
        fetchers.append(new LyricsFetcherCache(app.storage.get_cache_path("lyrics")));
        fetchers.append(new AZLyricsFetcher(app.connection.session));
        fetchers.append(new GecimiLyricsFetcher(app.connection.session));
        provider = new LyricsProvider(bindings.get_model<MediaPlayerModel>(), (owned) fetchers);
        sidebar = new LyricsSidebar(app, provider);
        unowned Sidebar app_sidebar = app.main_window.sidebar;
        app_sidebar.add_page(
            SIDEBAR_PAGE, _("Lyrics"), sidebar, !auto_open || provider.status == LyricsStatus.HAVE_LYRICS);
        provider.no_song_info.connect(on_lyrics_not_found);
        provider.lyrics_not_found.connect(on_lyrics_not_found);
        provider.lyrics_available.connect(on_lyrics_available);

        if (app_sidebar.frozen) {
            app_sidebar.notify["frozen"].connect_after(on_sidebar_frozen_changed);
        } else {
            auto_open_or_close();
        }
        return true;
    }

    protected override bool deactivate() {
        app.main_window.sidebar.remove_page(sidebar);
        provider.no_song_info.disconnect(on_lyrics_not_found);
        provider.lyrics_not_found.disconnect(on_lyrics_not_found);
        provider.lyrics_available.disconnect(on_lyrics_available);
        sidebar = null;
        provider = null;
        unowned Sidebar app_sidebar = app.main_window.sidebar;
        if (app_sidebar.frozen) {
            app_sidebar.notify["frozen"].disconnect(on_sidebar_frozen_changed);
        }
        return true;
    }

    public override Gtk.Widget? get_settings() {
        return new LyricsSettings(this);
    }

    private void auto_open_or_close() {
        if (provider.status == LyricsStatus.HAVE_LYRICS) {
            on_lyrics_available();
        } else {
            on_lyrics_not_found();
        }
    }

    private void on_lyrics_not_found() {
        if (auto_open) {
            unowned Sidebar sidebar = app.main_window.sidebar;
            if (sidebar.visible && sidebar.page == SIDEBAR_PAGE) {
                sidebar.hide();
            }
        }
    }

    private void on_lyrics_available() {
        if (auto_open) {
            unowned Sidebar sidebar = app.main_window.sidebar;
            sidebar.page = SIDEBAR_PAGE;
            sidebar.show();
        }
    }

    private void on_sidebar_frozen_changed(GLib.Object emitter, ParamSpec param) {
        Sidebar sidebar = (Sidebar) emitter;
        if (!sidebar.frozen) {
            sidebar.notify["frozen"].disconnect(on_sidebar_frozen_changed);
            auto_open_or_close();
        }
    }
}

public class LyricsSettings : Gtk.Grid {
    private Gtk.Switch auto_open_switch;

    public LyricsSettings(LyricsComponent component) {
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 10;
        column_spacing = 10;
        var line = 0;
        BindingFlags bind_flags = BindingFlags.BIDIRECTIONAL|BindingFlags.SYNC_CREATE;
        Gtk.Label label = Drtgtk.Labels.plain(
            "Automatically open/close lyrics sidebar depending on whether the lyrics of the current song is found.",
            true);
        attach(label, 1, line, 1, 1);
        label.show();
        auto_open_switch = new Gtk.Switch();
        auto_open_switch.vexpand = false;
        auto_open_switch.valign = Gtk.Align.CENTER;
        component.bind_property("auto-open", auto_open_switch, "active", bind_flags);
        attach(auto_open_switch, 0, line, 1, 1);
        auto_open_switch.show();
    }
}

} // namespace Nuvola
