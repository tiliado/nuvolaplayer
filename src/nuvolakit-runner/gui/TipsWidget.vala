/*
 * Copyright 2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

using Drtgtk.Labels;

namespace Nuvola {

public class TipsWidget : Gtk.Grid {
    public TipsWidget(WebApp app, Drt.Storage storage) {
        orientation = Gtk.Orientation.HORIZONTAL;
        var stack = new Gtk.Stack();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        unowned string app_name = app.name;
        string url = Nuvola.create_help_url("desktop_launchers");

        (unowned string)[] sections = {
            "<b>Faster Access to Your Music</b>",
            "<b>Tweak Your Experience</b>",
            "<b>Questions? Feedback? Bugs?</b>",
            "<b>Keep in Touch not to Miss Anything</b>",
        };
        Gtk.Label?[] subtitles = {
            markup("Add <i>%s</i> to favorites (<a href=\"%s#gnome-favorites\">more info</a>).", app_name, url),
            markup("Pin <i>%s</i> to dock in GNOME (<a href=\"%s#ubuntu-dock\">more info</a>).", app_name, url),
            markup("Pin <i>%s</i> to dock in Unity (<a href=\"%s#unity-dock\">more info</a>).", app_name, url),
            markup(
                "Pin <i>%s</i> to dock in elementaryOS (<a href=\"%s#elementary-dock\">more info</a>).",
                app_name, url),
            null,
            markup("Click <i>Menu</i> button, then <i>Preferences</i>."),
            markup("Adjust Nuvola to <i>your</i> liking."),
            markup("Open help when unsure, it's just <i>a single click</i>."),
            null,
            markup("We'd like to help but you <i>need to tell us</i>."),
            null,
            markup("There is an update at least once a month."),
        };
        (unowned string?)[] images = {
            "tips/activities_add_to_favorites.png",
            "tips/dock_add_to_favorites_ubuntu.png",
            "tips/lock_to_launcher.png",
            "tips/keep_in_dock.png",
            null,
            "tips/open_preferences.png",
            "tips/preferenes_dialog_configure.png",
            "tips/preferenes_dialog_help.png",
            null,
            "tips/open_links.png",
        };
        (unowned string)[] links = {
            "https://medium.com/nuvola-news", "Read Nuvola News blog",
            "https://plus.google.com/110794636546911932554", "Follow Nuvola on Google+",
            "https://www.facebook.com/nuvolaplayer", "Follow Nuvola on Facebook",
            "https://twitter.com/NuvolaPlayer", "Follow Nuvola on Twitter",
            "https://mastodon.cloud/@nuvola", "Follow Nuvola on Mastodon",
            "http://eepurl.com/dhxrQT", "Subscribe to mailing list",
        };

        int n_sections = sections.length;
        int n_subtitles = subtitles.length;
        int n_images = images.length;
        int subtitles_pos = -1;
        Gtk.Grid? grid = null;
        for (var i = 0; i < n_sections; i++) {
            subtitles_pos++;
            while (subtitles_pos < n_subtitles && subtitles[subtitles_pos] != null) {
                grid = new Gtk.Grid();
                stack.add(grid);
                grid.row_spacing = 10;
                stack.add(grid);
                grid.orientation = Gtk.Orientation.VERTICAL;
                Gtk.Label label = plain(sections[i], false, true);
                label.halign = Gtk.Align.CENTER;
                grid.add(label);
                label = subtitles[subtitles_pos];
                label.halign = Gtk.Align.CENTER;
                grid.add(label);
                if (subtitles_pos < n_images && images[subtitles_pos] != null) {
                    grid.add(new Gtk.Image.from_file(storage.require_data_file(images[subtitles_pos]).get_path()));
                }
                subtitles_pos++;
            }
        }

        int n_links = links.length / 2;
        for (var i = 0; i < n_links; i++) {
            var button = new Gtk.LinkButton.with_label(links[2 * i], links[2 * i + 1]);
            button.halign = Gtk.Align.CENTER;
            button.margin = 10;
            grid.add(button);
        }

        var arrow = new Drtgtk.StackArrow(Gtk.PositionType.LEFT, stack);
        arrow.vexpand = true;
        arrow.valign = Gtk.Align.FILL;
        add(arrow);
        add(stack);
        arrow = new Drtgtk.StackArrow(Gtk.PositionType.RIGHT, stack);
        arrow.vexpand = true;
        arrow.valign = Gtk.Align.FILL;
        add(arrow);
        show_all();
    }
}

} // namespace Nuvola
