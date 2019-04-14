/*
 * Copyright 2014 Martin Pöhlmann <martin.deimos@gmx.de>
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

public class WebView: WebKit.WebView {
    public const double ZOOM_DEFAULT = 1.0;
    public const double ZOOM_STEP = 1.2;
    private Gee.List<WebWindow> web_windows = new Gee.LinkedList<WebWindow>();

    public WebView(WebKit.WebContext context) {
        GLib.Object(web_context: context);
        unowned WebKit.Settings ws = get_settings();
        ws.enable_developer_extras = true;
        ws.enable_java = false;
        ws.enable_page_cache = false;
        ws.enable_smooth_scrolling = true;
        ws.enable_write_console_messages_to_stdout = true;
        ws.enable_caret_browsing = true;  // accessibility
        ws.enable_webaudio = true;
        ws.enable_media_stream = true;
        ws.enable_mediasource = true;
        button_release_event.connect(on_button_released);
        create.connect(on_web_view_create);
    }

    /**
     * Handles special mouse buttons (back & forward navigation)
     */
    private bool on_button_released(Gdk.EventButton event) {
        switch (event.button) {
        case 8:  // mouse back button
            go_back();
            return true;
        case 9:  // mouse forward button
            go_forward();
            return true;
        default:
            return false;
        }
    }

    public void zoom_in() {
        zoom_level *= ZOOM_STEP;
    }

    public void zoom_out() {
        zoom_level /= ZOOM_STEP;
    }

    public void zoom_reset() {
        zoom_level = ZOOM_DEFAULT;
    }

    private Gtk.Widget on_web_view_create() {
        var web_view = new WebView(web_context);
        var web_window = new WebWindow(web_view);
        web_window.destroy.connect(on_web_window_destroy);
        web_windows.add(web_window);
        return web_view;
    }

    private void on_web_window_destroy(Gtk.Widget window) {
        var web_window = window as WebWindow;
        assert(web_window != null);
        web_windows.remove(web_window);
    }
}

} // namespace Nuvola
