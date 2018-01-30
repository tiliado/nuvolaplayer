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

public class WebAppList : Gtk.Grid {
    public WebAppListView view {get; private set;}
    public WebAppListFilter model {get; private set;}
    public string? category {get; set; default = null;}
    public string? selected_web_app {get; private set; default = null;}
    private AppCategoriesView categories;
    private unowned MasterController app;
    private Gtk.Grid details;
    private Gtk.Label app_name;
    private Gtk.Label app_version;
    private Gtk.Label app_maintainer;

    public WebAppList(MasterController app, WebAppListFilter model) {
        this.app = app;
        app.actions.get_action(MasterUserInterface.START_APP).enabled = false;
        this.model = model;
        view = new WebAppListView(model);
        view.selection_changed.connect(on_selection_changed);
        view.halign = Gtk.Align.FILL;
        view.vexpand = true;
        view.hexpand = true;

        var scroll = new Gtk.ScrolledWindow(null, null);
        scroll.add(view);
        scroll.halign = Gtk.Align.FILL;
        scroll.vexpand = true;
        scroll.hexpand = true;
        scroll.show_all();

        details = new Gtk.Grid();
        details.orientation = Gtk.Orientation.HORIZONTAL;
        details.halign = Gtk.Align.CENTER;
        var label = new Gtk.Label("<b>Name:</b>");
        label.hexpand = label.vexpand = false;
        label.use_markup = true;
        label.margin = 5;
        details.add(label);
        app_name = new Gtk.Label(null);
        app_name.vexpand = false;
        app_name.hexpand = false;
        details.attach_next_to(app_name, label, Gtk.PositionType.RIGHT, 1, 1);
        label = new Gtk.Label("<b>Version:</b>");
        label.hexpand = label.vexpand = false;
        label.use_markup = true;
        label.margin = 5;
        details.add(label);
        app_version = new Gtk.Label(null);
        app_version.vexpand = false;
        app_version.hexpand = false;
        details.attach_next_to(app_version, label, Gtk.PositionType.RIGHT, 1, 1);
        label = new Gtk.Label("<b>Maintainer:</b>");
        label.hexpand = label.vexpand = false;
        label.use_markup = true;
        label.margin = 5;
        details.add(label);
        app_maintainer = new Gtk.Label(null);
        app_maintainer.vexpand = false;
        app_maintainer.hexpand = false;
        app_maintainer.use_markup = true;
        details.attach_next_to(app_maintainer, label, Gtk.PositionType.RIGHT, 1, 1);
        details.show_all();
        details.hide();
        details.no_show_all = true;

        categories = new AppCategoriesView();
        categories.hexpand = false;
        categories.no_show_all = true;
        categories.margin_right = 8;
        categories.no_show_all = true;
        categories.hide();

        margin = 8;
        attach(categories, 0, 0, 1, 1);
        attach(scroll, 1, 0, 1, 1);
        attach(details, 0, 1, 2, 1);

        view.select_path(new Gtk.TreePath.first());
        category = model.category;
        notify["category"].connect_after(on_category_changed);
        model.bind_property(
            "category", categories, "category", GLib.BindingFlags.BIDIRECTIONAL|GLib.BindingFlags.SYNC_CREATE);
    }

    private void on_selection_changed() {
        List<Gtk.TreePath> items = view.get_selected_items();
        Gtk.TreePath? path = null;
        foreach (Gtk.TreePath my_path in items) {
            path = my_path;
        }

        if (path == null) {
            details.hide();
            selected_web_app = null;
            app.actions.get_action(MasterUserInterface.START_APP).enabled = false;
            return;
        }

        Gtk.TreeModel model = view.get_model();
        Gtk.TreeIter iter;
        if (!model.get_iter(out iter, path)) {
            details.hide();
            selected_web_app = null;
            app.actions.get_action(MasterUserInterface.START_APP).enabled = false;
            return;
        }

        string id;
        string name;
        string version;
        string maintainer_name;
        string maintainer_link;
        model.get(iter,
            WebAppListModel.Pos.ID, out id,
            WebAppListModel.Pos.NAME, out name,
            WebAppListModel.Pos.VERSION, out version,
            WebAppListModel.Pos.MAINTAINER_NAME, out maintainer_name,
            WebAppListModel.Pos.MAINTAINER_LINK, out maintainer_link
        );

        selected_web_app = id;
        app_version.label = version;
        app_name.label = name;
        app_maintainer.label = "<a href=\"%s\">%s</a>".printf(
            Markup.escape_text(maintainer_link), Markup.escape_text(maintainer_name));
        details.show();
        app.actions.get_action(MasterUserInterface.START_APP).enabled = true;
    }

    private void on_category_changed(GLib.Object o, ParamSpec param) {
        model.category = category;
        categories.visible = category == null;
    }
}

} // namespace Nuvola
