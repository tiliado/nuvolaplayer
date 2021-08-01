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

public class PatronBox : Gtk.Grid {
    public PatronBox() {
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 20;
        hexpand = vexpand = false;
        valign = halign = Gtk.Align.CENTER;
        (unowned string?)[] patrons = {
            "Andrew Azores", null,
            "Christian Dannie Storgaard", null,
            "José Antonio Rey", "https://google.com/+JoséAntonioRey",
            "Ryan Wagner", null,
            "Simon Law", "https://facebook.com/sfllaw",
            "Bart Libert", "https://bitbucket.org/bartl/",
            "Chris Beeley", "http://chrisbeeley.net/",
            "Bryan Wyatt", "https://github.com/brwyatt",
            "Balázs", null,
            "Denton Davenport", null,
            "Ben MacLeod", null,
            "David Wiczer", null,
            "Andrew Allen", null,
            "Nathan Warkentin", "https://www.facebook.com/fur0n",
            "Chuck Talk", "https://www.linkedin.com/in/ctalk",
            "Peter Tillemans", "https://www.snamellit.com",
        };
        var buffer = new StringBuilder("");
        int count = patrons.length / 2;
        for (var i = 0; i < count; i++) {
            unowned string? name = patrons[2 * i];
            unowned string? url = patrons[2 * i + 1];
            assert(name != null);
            if (i > 0) {
                buffer.append(",\n");
            }
            buffer.append(
                url != null ? Markup.printf_escaped("<a href=\"%s\">%s</a>", url, name): Markup.escape_text(name));
        }
        buffer.append_c('.');
        Gtk.Label label = Drtgtk.Labels.header("Nuvola Patrons");
        add(label);
        label = Drtgtk.Labels.plain(buffer.str, true, true);
        label.max_width_chars = 20;
        label.halign = Gtk.Align.CENTER;
        add(label);
        var button = new Gtk.LinkButton.with_label(
            "https://tiliado.eu/nuvolaplayer/funding/", "Become Patron");
        add(button);
        show_all();
    }
}

} // namespace Nuvola
