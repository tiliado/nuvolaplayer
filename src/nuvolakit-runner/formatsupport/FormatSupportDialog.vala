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

const string FLASH_DETECT_HTML = """<!DOCTYPE html
<html>
<head>
<meta charset="utf-8" />
<script src="./flash_detect.js"></script>
<style type="text/css">
body, html {margin: 0px; padding: 0px;}
p {margin: 0px; padding: 10px;}
</style>
</head>
<body>
<script type="text/javascript">
document.write("<p>" + (FlashDetect.installed
? (FlashDetect.raw + " is the active Flash plugin.")
: "<p>No Flash plugin has been loaded.</p>"
)+ "</p>");
</script>
</body>
</html>
""";

const string HTML5_AUDIO_DETECT_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Audio Support &#8226; Nuvola Apps</title>
<style>
body {background-color: White; color: Black;}
table, td, th {border: 1px solid #EEE; border-collapse: collapse;}
td, th {padding: 5px 10px;}
</style>
<script src="./audio.js"></script>
</head>
<body id="main"></body>
</html>
""";

public class FormatSupportScreen: Gtk.Notebook
{
    public Drtgtk.Application app {get; construct;}
    public FormatSupport format_support {get; construct;}
    public Drt.Storage storage {get; construct;}

    public FormatSupportScreen(Drtgtk.Application app, FormatSupport format_support, Drt.Storage storage, WebKit.WebContext web_context)
    {
        GLib.Object(format_support: format_support, storage: storage, app:app);
        Gtk.Label label = null;
        margin = 10;

        var plugins_view = new Gtk.Grid();
        plugins_view.margin = 10;
        plugins_view.row_spacing = 10;
        plugins_view.column_spacing = 10;
        plugins_view.orientation = Gtk.Orientation.VERTICAL;

        var scrolled_window = new Gtk.ScrolledWindow(null, null);
        scrolled_window.add(plugins_view);
        scrolled_window.expand = true;
        scrolled_window.margin = 10;
        scrolled_window.show();

        var frame = new Gtk.Frame ("<b>Flash plugins</b>");
        (frame.label_widget as Gtk.Label).use_markup = true;
        var flash_plugins_grid = new Gtk.Grid();
        flash_plugins_grid.orientation = Gtk.Orientation.VERTICAL;
        flash_plugins_grid.margin = 10;
        frame.add(flash_plugins_grid);
        plugins_view.attach(frame, 0, 3, 2, 1);
        frame.show();

        var flash_detect = storage.get_data_file("js/flash_detect.js");
        if (flash_detect != null)
        {
            frame = new Gtk.Frame ("<b>Active Flash plugin</b>");
            (frame.label_widget as Gtk.Label).use_markup = true;
            var web_view = new WebView(web_context);
            web_view.get_settings().allow_file_access_from_file_urls = true;
            web_view.get_settings().allow_universal_access_from_file_urls = true;
            frame.add(web_view);
            web_view.set_size_request(-1, 50);
            web_view.show();
            web_view.load_html(FLASH_DETECT_HTML, flash_detect.get_uri() + ".html");
            plugins_view.attach(frame, 0, 4, 2, 1);
            frame.show();
        }

        frame = new Gtk.Frame ("<b>Other plugins</b>");
        (frame.label_widget as Gtk.Label).use_markup = true;
        var other_plugins_grid = new Gtk.Grid();
        other_plugins_grid.orientation = Gtk.Orientation.VERTICAL;
        other_plugins_grid.margin = 10;
        frame.add(other_plugins_grid);
        plugins_view.attach(frame, 0, 5, 2, 1);
        frame.show();

        unowned List<WebPlugin?> plugins = format_support.list_web_plugins();
        foreach (unowned WebPlugin plugin in plugins)
        {
            unowned Gtk.Grid grid = plugin.is_flash ? flash_plugins_grid : other_plugins_grid;
            if (grid.get_child_at(0, 0) != null)
            grid.add(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));

            label = new Gtk.Label(Markup.printf_escaped(
                "<b>%s</b> (%s)", plugin.name, plugin.enabled ? "enabled" : "disabled"));
            label.use_markup = true;
            label.set_line_wrap(true);
            label.margin_top = 5;
            label.hexpand = true;
            grid.add(label);
            label = new Gtk.Label(plugin.path);
            label.set_line_wrap(true);
            label.hexpand = true;
            grid.add(label);
            label = new Gtk.Label(plugin.description);
            label.set_line_wrap(true);
            label.hexpand = true;
            label.justify = Gtk.Justification.FILL;
            label.margin_bottom = 5;
            grid.add(label);
            grid.show_all();
        }

        if (format_support.n_flash_plugins != 1)
        {
            var info_bar = new Gtk.InfoBar();
            info_bar.get_content_area().add(new Gtk.Label(format_support.n_flash_plugins == 0
                ? "No Flash plugins have been found."
                : "Too many Flash plugins have been found, wrong version may have been used."));
            if (format_support.n_flash_plugins == 0)
            info_bar.add_button("Help", 0).clicked.connect(() => {app.show_uri(WEB_APP_REQUIREMENTS_HELP_URL);});
            info_bar.show_all();
            plugins_view.attach(info_bar, 0, 2, 2, 1);
        }

        if (flash_plugins_grid.get_children() == null)
        flash_plugins_grid.get_parent().hide();
        if (other_plugins_grid.get_children() == null)
        other_plugins_grid.get_parent().hide();

        plugins_view.show();
        append_page(scrolled_window, new Gtk.Label("Web Plugins"));
        var help_button = new Gtk.Button.with_label("Help");
        help_button.clicked.connect(() => {app.show_uri(WEB_APP_REQUIREMENTS_HELP_URL);});
        var audio_detect_script = storage.get_data_file("js/audio.js");
        var mp3_view = new Mp3View(format_support, help_button, audio_detect_script, web_context);
        mp3_view.show();
        append_page(mp3_view, new Gtk.Label("MP3 format"));
        show();
    }

    public void show_tab(Tab tab)
    {
        this.page = tab == Tab.DEFAULT ? 0 : (int) tab - 1;
    }

    public enum Tab
    {
        DEFAULT, FLASH, MP3;
    }

    private class Mp3View : Gtk.Grid
    {
        private FormatSupport format_support;
        private Gtk.TextView text_view;
        private Gtk.Button button;
        private Gtk.Label result_label;
        private AudioPipeline? pipeline = null;
        private Gtk.Button help_button;

        public Mp3View(FormatSupport format_support, Gtk.Button help_button, File? audio_detect_script,
            WebKit.WebContext web_context)
        {
            GLib.Object(orientation: Gtk.Orientation.VERTICAL);
            this.format_support = format_support;
            this.help_button = help_button;
            margin = 10;
            row_spacing = 10;
            column_spacing = 10;

            text_view = new Gtk.TextView();
            text_view.editable = false;
            text_view.expand = true;
            result_label = new Gtk.Label(null);
            result_label.hexpand = true;
            update_result_text(format_support.mp3_supported);

            button = new Gtk.Button();
            set_button_label();
            button.clicked.connect(toggle_check);
            attach(result_label, 0, 2, 1, 1);
            attach(help_button, 1, 2, 1, 1);
            attach(button, 2, 2, 1, 1);
            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.expand = true;
            scroll.add(text_view);
            attach(scroll, 0, 3, 3, 1);
            result_label.show();
            button.show();
            scroll.show_all();

            if (audio_detect_script != null)
            {
                var frame = new Gtk.Frame ("<b>HTML5 Audio Support Status</b>");
                (frame.label_widget as Gtk.Label).use_markup = true;
                var web_view = new WebView(web_context);
                web_view.get_settings().allow_file_access_from_file_urls = true;
                web_view.get_settings().allow_universal_access_from_file_urls = true;
                frame.add(web_view);
                frame.vexpand = true;
                frame.valign = Gtk.Align.FILL;
                web_view.set_size_request(-1, 300);
                web_view.vexpand = true;
                web_view.show();
                web_view.load_html(HTML5_AUDIO_DETECT_HTML, audio_detect_script.get_uri() + ".html");
                attach(frame, 0, 4, 3, 1);
                frame.show();
            }
        }

        private void update_result_text(bool result)
        {
            result_label.label = (pipeline != null
                ? "You should be hearing a really bad song now."
                :(result ? "MP3 audio format is supported." : "MP3 audio format is not supported."));
            help_button.visible = !result;
        }

        private void set_button_label()
        {
            button.label = pipeline == null ? "Check again" : "Stop";
        }

        private void toggle_check()
        {
            if (pipeline != null)
            {
                pipeline.stop();
                return;
            }

            pipeline = format_support.get_mp3_pipeline();
            pipeline.info.connect(on_pipeline_info);
            pipeline.warn.connect(on_pipeline_warn);
            text_view.buffer.text = "";
            set_button_label();
            update_result_text(false);
            pipeline.check.begin(false, (o, res) =>
                {
                    pipeline.info.disconnect(on_pipeline_info);
                    pipeline.warn.disconnect(on_pipeline_warn);
                    var result = pipeline.check.end(res);
                    pipeline = null;
                    update_result_text(result);
                    if (result)
                    add_message("Info", "Playback has been successful.");
                    else
                    add_message("Error", "Playback has failed.");
                    set_button_label();
                });
        }

        private void add_message(string type, string text)
        {
            var buffer = text_view.buffer;
            Gtk.TextIter iter;
            buffer.get_end_iter(out iter);
            var data = "%s: %s\n".printf(type, text);
            buffer.insert(ref iter, data, -1);
        }

        private void on_pipeline_info(string text)
        {
            add_message("Info", text);
        }

        private void on_pipeline_warn(string text)
        {
            add_message("Error", text);
        }
    }
}

} // namespace Nuvola
