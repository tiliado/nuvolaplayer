/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class LibrariesScreen: Gtk.Grid {
    public LibrariesScreen(WebOptions[]? web_options) {
        Gtk.Label label;
        column_spacing = 5;
        halign = Gtk.Align.CENTER;
        hexpand = true;

        var line = 0;
        label = new Gtk.Label("Diorite: %s".printf(Drt.get_version()));
        label.selectable = true;
        label.margin_top = 10;
        attach(label, 0, line++, 2, 1);
        foreach (WebOptions entry in web_options) {
            label = new Gtk.Label("Web Engine: " + entry.get_name_version());
            label.selectable = true;
            attach(label, 0, line++, 2, 1);
        }
        label = new Gtk.Label("Network Library: libsoup %u.%u.%u".printf(
            Soup.get_major_version(), Soup.get_minor_version(), Soup.get_micro_version()));
        label.selectable = true;
        attach(label, 0, line++, 2, 1);
        show_all();
        hide();
    }
}

} // namespace Nuvola
