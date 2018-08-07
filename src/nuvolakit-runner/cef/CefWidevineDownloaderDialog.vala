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

#if HAVE_CEF
namespace Nuvola {

public class CefWidevineDownloaderDialog : Gtk.Dialog {
    public bool is_downloading {get; private set; default = false;}
    private CefWidevineDownloader downloader;
    private Gtk.CheckButton? eula;
    private Gtk.Widget download_button;
    private Gtk.Grid grid;
    private Cancellable? cancellable = null;
    private SourceFunc? resume = null;
    private bool result = false;
    private Gtk.Label? error_label = null;
    private Gtk.Label? progress_text = null;
    private Gtk.Spinner progress;
    private Gtk.ScrolledWindow view;

    public CefWidevineDownloaderDialog(CefWidevineDownloader downloader, string web_app_name) {
        bool needs_update = downloader.needs_update();
        this.downloader = downloader;
        this.title = needs_update ? "Widevine Plugin Update Required" : "Widevine Plugin Required";
        if (needs_update) {
            warning("Widevine needs update from %s.", downloader.chrome_version);
        } else {
            debug("Need to install Widevine.");
        }
        set_default_size(400, -1);
        grid = new Gtk.Grid();
        grid.margin = 10;
        grid.vexpand = true;
        grid.valign = Gtk.Align.FILL;
        grid.orientation = Gtk.Orientation.VERTICAL;
        Gtk.Label label = Drtgtk.Labels.markup(
            (
                "<b>%s web app requires a proprietary Widevine plugin. Would you like to install it?</b>\n\n"
                + "Upon your approval, Nuvola will download Google Chrome and extract the Widevine plugin. "
                + "You need to accept <a href=\"%s\">Google Chrome End User License Agreement</a> to proceed."
            ),
            web_app_name, CefWidevineDownloader.CHROME_EULA_URL);
        grid.add(label);
        eula = new Gtk.CheckButton.with_label("I accept Google Chrome End User License Agreement.");
        eula.margin_top = 10;
        grid.add(eula);
        var box = (Gtk.Box) get_content_area();
        view = new Gtk.ScrolledWindow(null, null);
        view.hscrollbar_policy = Gtk.PolicyType.NEVER;
        view.add(grid);
        box.pack_start(view, true, true, 0);

        add_button("Cancel", Gtk.ResponseType.CLOSE);
        download_button = add_button(needs_update ? "Update plugin" : "Install plugin", Gtk.ResponseType.APPLY);
        eula.bind_property("active", download_button, "sensitive", BindingFlags.SYNC_CREATE);
        progress  = new Gtk.Spinner();
        progress.margin = 10;
        progress.vexpand = false;
        progress.valign = Gtk.Align.END;
        progress.hexpand = false;
        grid.add(progress);
        progress_text = new Gtk.Label("");
        grid.add(progress_text);
        view.show_all();
        downloader.progress_text.connect(on_progress_text);
    }

    ~CefWidevineDownloaderDialog() {
        downloader.progress_text.disconnect(on_progress_text);
    }

    public async bool wait_for_result() {
        present();
        resume = wait_for_result.callback;
        yield;
        return result;
    }

    protected override void show() {
        base.show();
        Idle.add(() => {
            int minimum_height;
            int natural_height;
            grid.get_preferred_height(out minimum_height, out natural_height);
            view.set_size_request(-1, natural_height);
            return false;
        });
    }

    public virtual signal void cancelled() {
        if (resume != null) {
            result = false;
            resume();
        }
    }

    public virtual signal void installed() {
        if (resume != null) {
            result = true;
            resume();
        }
    }

    public virtual signal void failed(GLib.Error reason) {
        if (resume != null) {
            progress_text.label = "";
            result = false;
            progress.hide();
            error_label = Drtgtk.Labels.markup("<b>Error occurred:</b> %s", reason.message);
            error_label.width_chars = 50;
            error_label.vexpand = false;
            error_label.valign = Gtk.Align.START;
            grid.add(error_label);
            error_label.margin_top = 20;
            error_label.show();
            download_button.sensitive = true;
            ((Gtk.Button) download_button).label = "Retry";
        }
    }

    protected override void response(int response_id) {
        if (response_id == Gtk.ResponseType.APPLY) {
            is_downloading = true;
            if (eula != null) {
                grid.remove(eula);
                eula = null;
            }
            if (error_label != null) {
                grid.remove(error_label);
                error_label = null;
            }

            download_button.sensitive = false;
            progress.start();
            progress.set_size_request(50, 50);
            progress.show();
            progress_text.label = "";
            get_content_area().queue_resize();
            cancellable = new Cancellable();
            downloader.download.begin(cancellable, on_download_finished);
        } else {
            warning("Widevine installation cancelled.");
            if (cancellable != null) {
                cancellable.cancel();
            } else {
                cancelled();
            }
        }
    }

    private void on_download_finished(GLib.Object? o, AsyncResult res) {
        progress.stop();
        is_downloading = false;
        cancellable = null;
        try {
            downloader.download.end(res);
            installed();
        } catch (GLib.Error e) {
            if (e is GLib.IOError.CANCELLED) {
                cancelled();
            } else {
                failed(e);
            }
        }
    }

    private void on_progress_text(string text) {
        progress_text.label = text;
    }
}

} // namespace Nuvola
#endif
