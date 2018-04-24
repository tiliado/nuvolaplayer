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

public class WebViewSidebar: Gtk.Grid {
    private Gtk.Entry? width_entry = null;
    private Gtk.Entry? height_entry = null;
    private Gtk.Widget web_view;
    private unowned AppRunnerController app;

    public WebViewSidebar(AppRunnerController app) {
        this.app = app;
        web_view = app.web_engine.get_main_web_view();
        orientation = Gtk.Orientation.VERTICAL;
        hexpand = vexpand = true;
        row_spacing = 5;

        var label = new Gtk.Label("Width:");
        label.halign = Gtk.Align.START;
        add(label);
        width_entry = new Gtk.Entry();
        width_entry.max_width_chars = 4;
        width_entry.input_purpose = Gtk.InputPurpose.NUMBER;
        width_entry.halign = Gtk.Align.END;
        width_entry.hexpand = false;
        attach_next_to(width_entry, label, Gtk.PositionType.BOTTOM, 1, 1);

        label = new Gtk.Label("Height:");
        label.halign = Gtk.Align.START;
        add(label);
        height_entry = new Gtk.Entry();
        height_entry.max_width_chars = 4;
        height_entry.hexpand = false;
        height_entry.input_purpose = Gtk.InputPurpose.NUMBER;
        height_entry.halign = Gtk.Align.END;
        attach_next_to(height_entry, label, Gtk.PositionType.BOTTOM, 1, 1);

        var button = new Gtk.Button.with_label("Refresh");
        button.clicked.connect(update);
        add(button);
        button = new Gtk.Button.with_label("Resize");
        button.clicked.connect(apply);
        add(button);

        #if HAVE_CEF
        if (web_view is CefGtk.WebView) {
            button = new Gtk.Button.with_label("Take snapshot");
            button.clicked.connect(take_snapshot);
            add(button);
        }
        #endif

        show_all();
        update();
        Timeout.add(300, () => { update(); return false; });
    }

    ~WebViewSidebar() {
    }

    private void update() {
        height_entry.text = web_view.get_allocated_height().to_string();
        width_entry.text = web_view.get_allocated_width().to_string();
    }

    private void apply() {
        Gtk.Allocation allocation;
        web_view.get_allocation(out allocation);
        var width = int.parse(width_entry.text);
        var height = int.parse(height_entry.text);
        web_view.set_size_request(width, height);
        if (height < allocation.height || width < allocation.width) {
            var window = get_toplevel() as Gtk.Window;
            assert(window != null);
            int window_width;
            int window_height;
            window.get_size(out window_width, out window_height);
            window_width -= allocation.width - width + 10;
            window_height -= allocation.height - height + 10;
            window.resize(int.max(10, window_width), int.max(10, window_height));
        }
        Timeout.add(100, () => {web_view.set_size_request(-1, -1); return false;});
    }

    #if HAVE_CEF
    private void take_snapshot() {
        Gdk.Pixbuf? snapshot = ((CefGtk.WebView) web_view).get_snapshot();
        if (snapshot != null) {
            var dialog = new Gtk.FileChooserNative(
                "Save snapshot", get_toplevel() as Gtk.Window, Gtk.FileChooserAction.SAVE, "Save snapshot", "Cancel");
            dialog.do_overwrite_confirmation = true;
            var filter = new Gtk.FileFilter();
            filter.set_filter_name("PNG images");
            filter.add_pattern("*.png");
            dialog.add_filter(filter);
            if (dialog.run() == Gtk.ResponseType.ACCEPT) {
                try {
                    snapshot.save(dialog.get_filename(), "png", "compression", "9", null);
                } catch (GLib.Error e) {
                    app.show_warning("Failed to save snapshot", e.message);
                }
            }
            dialog.destroy();
        } else {
            app.show_warning("Snapshot failure", "Failed to take a snapshot.");
        }

    }
    #endif
}

} // namespace Nuvola

