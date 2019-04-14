/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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
    private int resize_delay_remaining = -1;
    private Gtk.SpinButton resize_delay_spin;
    private Gtk.Button resize_button;
    #if HAVE_CEF
    private Gtk.SpinButton delay_spin;
    private int delay_remaining = -1;
    private Gtk.Button snapshot_button;
    #endif
    private unowned AppRunnerController app;

    public WebViewSidebar(AppRunnerController app) {
        this.app = app;
        web_view = app.web_engine.get_main_web_view();
        orientation = Gtk.Orientation.VERTICAL;
        hexpand = vexpand = true;
        row_spacing = column_spacing = 5;

        var row = 0;
        var label = new Gtk.Label("Width:");
        label.halign = Gtk.Align.START;
        attach(label, 0, row, 1, 1);
        width_entry = new Gtk.Entry();
        width_entry.max_width_chars = 4;
        width_entry.input_purpose = Gtk.InputPurpose.NUMBER;
        width_entry.halign = Gtk.Align.END;
        width_entry.hexpand = false;
        attach(width_entry, 1, row, 1, 1);
        label = new Gtk.Label("Height:");
        label.halign = Gtk.Align.START;
        attach(label, 0, ++row, 1, 1);
        height_entry = new Gtk.Entry();
        height_entry.max_width_chars = 4;
        height_entry.hexpand = false;
        height_entry.input_purpose = Gtk.InputPurpose.NUMBER;
        height_entry.halign = Gtk.Align.END;
        attach(height_entry, 1, row, 1, 1);
        var button = new Gtk.Button.with_label("Update dimensions");
        button.clicked.connect(update);
        attach(button, 0, ++row, 2, 1);

        label = new Gtk.Label("Delay:");
        label.halign = Gtk.Align.START;
        attach(label, 0, ++row, 1, 1);
        resize_delay_spin = new Gtk.SpinButton.with_range(0, 3600, 1);
        resize_delay_spin.numeric = true;
        resize_delay_spin.digits = 0;
        resize_delay_spin.snap_to_ticks = true;
        attach(resize_delay_spin, 1, row, 1, 1);
        button = new Gtk.Button.with_label("Resize web view");
        button.clicked.connect(resize_or_cancel);
        resize_button = button;
        attach(button, 0, ++row, 2, 1);

        #if HAVE_CEF
        if (web_view is CefGtk.WebView) {
            label = new Gtk.Label("Delay:");
            label.halign = Gtk.Align.START;
            attach(label, 0, ++row, 1, 1);
            delay_spin = new Gtk.SpinButton.with_range(0, 3600, 1);
            delay_spin.numeric = true;
            delay_spin.digits = 0;
            delay_spin.snap_to_ticks = true;
            attach(delay_spin, 1, row, 1, 1);

            button = new Gtk.Button.with_label("Take snapshot");
            button.clicked.connect(take_cancel_snapshot);
            attach(button, 0, ++row, 2, 1);
            snapshot_button = button;
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

    private void resize_or_cancel() {
        if (resize_delay_remaining < 0) {
            resize_delay_remaining = resize_delay_spin.get_value_as_int();
            apply();
        } else {
            resize_delay_remaining = 0;
        }
    }

    private void apply() {
        if (resize_delay_remaining > 0) {
            Timeout.add(1000, () => {apply(); return false; });
            resize_button.label = "Resize web view ... %d".printf(resize_delay_remaining);
            resize_delay_remaining--;
            return;
        }
        resize_button.label = "Resize web view";
        resize_delay_remaining = -1;

        Gtk.Allocation allocation;
        web_view.get_allocation(out allocation);
        int width = int.parse(width_entry.text);
        int height = int.parse(height_entry.text);
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
    private void take_cancel_snapshot() {
        if (delay_remaining < 0) {
            delay_remaining = delay_spin.get_value_as_int();
            take_snapshot();
        } else {
            delay_remaining = 0;
        }
    }

    private void take_snapshot() {
        if (delay_remaining > 0) {
            Timeout.add(1000, () => { take_snapshot(); return false; });
            snapshot_button.label = "Take snapshot ... %d".printf(delay_remaining);
            delay_remaining--;
            return;
        }
        snapshot_button.label = "Take snapshot";
        delay_remaining = -1;

        Gdk.Pixbuf? snapshot = ((CefGtk.WebView) web_view).get_snapshot();
        if (snapshot != null) {
            var dialog = new Gtk.FileChooserNative(
                "Save snapshot",
                /* TODO use (get_toplevel() as Gtk.Window) when https://gitlab.gnome.org/GNOME/gtk/issues/83 lands */
                null, Gtk.FileChooserAction.SAVE, "Save snapshot", "Cancel");
            dialog.do_overwrite_confirmation = true;
            var filter = new Gtk.FileFilter();
            filter.set_filter_name("PNG images");
            filter.add_pattern("*.png");
            dialog.add_filter(filter);
            dialog.response.connect((response_id) => {
                if (response_id == Gtk.ResponseType.ACCEPT) {
                    try {
                        snapshot.save(dialog.get_filename(), "png", "compression", "9", null);
                    } catch (GLib.Error e) {
                        app.show_warning("Failed to save snapshot", e.message);
                    }
                }
                dialog.destroy();
            });
            dialog.show();
        } else {
            app.show_warning("Snapshot failure", "Failed to take a snapshot.");
        }
    }
    #endif
}

} // namespace Nuvola

