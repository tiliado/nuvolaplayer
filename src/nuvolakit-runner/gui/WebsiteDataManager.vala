/*
 * Copyright 2017-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class WebsiteDataManager: Gtk.Grid
{
    private WebKit.WebsiteDataManager data_manager;
    private Gtk.CheckButton[] check_buttons;
    private WebKit.WebsiteDataTypes[] data_types;
    private Gtk.Button clear_button;
    public WebsiteDataManager(WebKit.WebsiteDataManager data_manager)
    {
        this.data_manager = data_manager;
        orientation = Gtk.Orientation.VERTICAL;
        hexpand = true;
        halign = Gtk.Align.FILL;
        margin = 18;
        row_spacing = 8;
        column_spacing = 18;

        var label = new Gtk.Label("Web app stores some data on your computer.");
        label.set_line_wrap(true);
        add(label);
        label.show();

        string[] labels = {
            "Cookies (small data files)",
            "Cache and temporary data",
            "IndexedDB databases",
            "WebSQL databases",
            "Local storage data",
        };
        data_types = {
            WebKit.WebsiteDataTypes.COOKIES,
            WebKit.WebsiteDataTypes.MEMORY_CACHE|WebKit.WebsiteDataTypes.DISK_CACHE
            |WebKit.WebsiteDataTypes.OFFLINE_APPLICATION_CACHE|WebKit.WebsiteDataTypes.SESSION_STORAGE
            |WebKit.WebsiteDataTypes.PLUGIN_DATA,
            WebKit.WebsiteDataTypes.INDEXEDDB_DATABASES,
            WebKit.WebsiteDataTypes.WEBSQL_DATABASES,
            WebKit.WebsiteDataTypes.LOCAL_STORAGE,
        };
        check_buttons = new Gtk.CheckButton[data_types.length];
        for (var i = 0; i < data_types.length; i++)
        {
            var check_button = check_buttons[i] = new Gtk.CheckButton.with_label(labels[i]);
            add(check_button);
            check_button.show();
        }

        label = new Gtk.Label("You cannot undo this action. The data you are choosing to clear will be removed forever.");
        label.set_line_wrap(true);
        add(label);
        label.show();

        var button = clear_button = new Gtk.Button.with_label("Clear selected data");
        button.get_style_context().add_class("destructive-action");
        button.clicked.connect(on_clear_button_clicked);
        add(button);
        button.show();
    }

    private void on_clear_button_clicked()
    {

        WebKit.WebsiteDataTypes data_to_clear = 0;
        for (var i = 0; i < check_buttons.length; i++)
        if (check_buttons[i].active)
        data_to_clear |= data_types[i];
        if (data_to_clear != 0)
        {
            clear_button.sensitive = false;
            data_manager.clear.begin(data_to_clear, 0, null, on_data_cleared);
        }
    }

    private void on_data_cleared(GLib.Object? o, AsyncResult res)
    {
        try
        {
            data_manager.clear.end(res);
        }
        catch (GLib.Error e)
        {
            warning("Failed to clear data: %s", e.message);
        }
        clear_button.sensitive = true;
    }
}

} // namespace Nuvola
