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


public class PreferencesDialog : Gtk.Dialog {
    public Drtgtk.Application app {get; construct;}
    public NetworkSettings network_settings {get; construct;}
    public AppearanceSettings appearance {get; construct;}
    public KeybindingsSettings keybindings {get; construct;}
    public ComponentsManager components_manager {get; construct;}
    public Drtgtk.Form web_app_form {get; construct;}
    private Drtgtk.HeaderBarTitle title_bar;
    private Gtk.HeaderBar header_bar;
    private Gtk.Button back_button;
    private Gtk.Button help_button;
    private Gtk.Stack stack;
    private Panel main_panel;
    private SList<Panel> current_panels = null;

    /**
     * Constructs new main window
     *
     * @param app Application object
     */
    public PreferencesDialog(
        Drtgtk.Application app, Gtk.Window? parent, NetworkSettings network_settings,
        AppearanceSettings appearance, KeybindingsSettings keybindings,
        ComponentsManager components_manager, Drtgtk.Form web_app_form
    ) {
        GLib.Object(
            use_header_bar: (int) app.shell.client_side_decorations, app: app,
            network_settings: network_settings, appearance: appearance,
            keybindings: keybindings, components_manager: components_manager, web_app_form: web_app_form);
        if (parent != null) {
            set_transient_for(parent);
        }
    }

    construct {
        // Window properties
        title = "Preferences";
        window_position = Gtk.WindowPosition.CENTER;
        border_width = 0;
        try {
            icon = Gtk.IconTheme.get_default().load_icon(app.icon, 48, 0);
        } catch (Error e) {
            warning("Unable to load application icon.");
        }
        set_default_size(550, 600);
        modal = true;

        // Title bar
        title_bar = new Drtgtk.HeaderBarTitle();
        title_bar.show();
        back_button = new Gtk.Button.from_icon_name("go-previous-symbolic");
        back_button.no_show_all = true;
        back_button.clicked.connect(on_back_button_clicked);
        help_button = new Gtk.Button.from_icon_name("system-help-symbolic");
        help_button.no_show_all = true;
        help_button.clicked.connect(on_help_button_clicked);
        header_bar = (Gtk.HeaderBar) get_header_bar();
        header_bar.show_close_button = true;
        header_bar.pack_start(back_button);
        header_bar.pack_end(help_button);
        header_bar.custom_title = title_bar;

        if (use_header_bar == 0) {
            remove(header_bar);
            Gtk.Container parent = get_content_area();
            parent.margin = 0;
            parent.border_width = 0;
            parent.add(header_bar);
            header_bar.show_close_button = false;
            header_bar.margin = 0;
            header_bar.margin_bottom = 5;
            header_bar.show();
        }

        // Content
        stack = new Gtk.Stack();
        stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
        get_content_area().add(stack);
        stack.show_all();

        // Panel groups
        SelectorGroup[] groups = {
            new SelectorGroup("General Preferences"),
            components_manager
        };

        // Appearance
        groups[0].add(new SimplePanel(
            "Appearance Tweaks", "Change user interface theme and window decoration preferences.",
            appearance, "appearance"));

        // Network settings
        groups[0].add(new SimplePanel(
            "Network Proxy", "Change network proxy settings for this web app.", network_settings, "network"));

        // Keybindings
        groups[0].add(new SimplePanel(
            "Keyboard Shortcuts", "Modify or disable in-app and global keyboard shortcuts.",
            keybindings, "keyboard_shortcuts"));

        // Web App form
        web_app_form.margin = 15;
        web_app_form.vexpand =  web_app_form.hexpand = true;
        web_app_form.halign = Gtk.Align.FILL;
        web_app_form.check_toggles();
        var scroll = new Gtk.ScrolledWindow(null, null);
        scroll.add(web_app_form);
        scroll.show_all();
        groups[0].add(new SimplePanel(
            "Web App Settings", "Extra settings provided by the web app integration script.",
            scroll, "web_app_settings"));

        // Add panels
        var grid = new Gtk.Grid();
        grid.margin = 15;
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.row_spacing = 10;
        foreach (unowned SelectorGroup group in groups) {
            unowned string? title = group.title;
            if (title != null) {
                Gtk.Label label = Drtgtk.Labels.markup("<b>%s</b>", title);
                label.halign = Gtk.Align.CENTER;
                label.show();
                grid.add(label);
            }
            var selector = new SelectorList(group);
            selector.panel_selected.connect((panel) => {change_panel(panel, true);});
            selector.open_help.connect(on_open_help);
            selector.show();
            grid.add(selector);
        }
        main_panel = new SimplePanel("Preferences", null, grid);
        change_panel(main_panel, false);
    }

    private void change_panel(Panel panel, bool forward) {
        back_button.hide();
        help_button.hide();
        title_bar.set_title(panel.get_title());
        title_bar.set_subtitle(panel.get_subtitle());
        if (panel.has_widget || panel.has_alert) {
            Gtk.Widget? widget = panel.has_alert ? panel.get_alert_widget() : panel.get_widget();
            if (widget != null) {
                Gtk.Container? parent = widget.get_parent();
                if (parent != null) {
                    if (parent != stack || forward) {
                        parent.remove(widget);
                        stack.add(widget);
                    }
                } else {
                    stack.add(widget);
                }

                widget.show();
                stack.visible_child = widget;
                if (panel != main_panel) {
                    back_button.show();
                    header_bar.show();
                } else if (use_header_bar == 0) {
                    header_bar.hide();
                }
                if (panel.has_help) {
                    help_button.show();
                }
            }
        }
        current_panels.prepend(panel);
    }

    public override bool delete_event(Gdk.EventAny event) {
        return false;
    }

    private void on_back_button_clicked() {
        if (current_panels != null) {
            current_panels.delete_link(current_panels);
            assert(current_panels != null);
            change_panel(current_panels.data, false);
        }
    }

    private void on_help_button_clicked() {
        if (current_panels != null) {
            on_open_help(current_panels.data);
        }
    }

    private void on_open_help(Panel panel) {
        unowned string? url = panel.get_help_url();
        if (url != null) {
            app.show_uri(url);
        }
    }

    public abstract class Panel: GLib.Object {
        public virtual bool is_enabled {get; set; default = true;}
        public virtual bool is_toggle {get; set; default = false;}
        public virtual bool is_available {get; set; default = true;}
        public virtual bool has_help {get; set; default = false;}
        public virtual bool has_widget {get; set; default = false;}
        public virtual bool has_alert {get; set; default = false;}
        public virtual string widget_icon {get; set; default = "emblem-system-symbolic";}

        public abstract unowned string get_title();

        public virtual unowned string? get_subtitle() {
            return null;
        }

        public virtual Gtk.Widget? get_widget() {
            return null;
        }

        public virtual Gtk.Widget? get_alert_widget() {
            return null;
        }

        public virtual unowned string? get_help_url() {
            return null;
        }
    }

    public class SelectorList : Gtk.ListBox {
        public SelectorGroup group {get; construct;}

        public SelectorList(SelectorGroup group) {
            GLib.Object(group: group);
        }

        construct {
            activate_on_single_click = true;
            selection_mode = Gtk.SelectionMode.NONE;
            foreach (unowned Panel panel in group.panels) {
                add_panel(panel);
            }
            row_activated.connect(on_row_activated);
            set_sort_func(group.sort_list_box);
        }

        public signal void panel_selected(Panel panel);
        public signal void open_help(Panel panel);

        private void add_panel(Panel panel) {
            var row = new Row(panel);
            row.open_help.connect(on_open_help);
            row.show();
            add(row);
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            panel_selected(((Row) row).panel);
        }

        private void on_open_help(Panel panel) {
            open_help(panel);
        }
    }

    public class SimplePanel : Panel {
        private string title;
        private string? subtitle;
        private string? help_url;
        private Gtk.Widget? widget;

        public SimplePanel(
            owned string title, owned string? subtitle=null, Gtk.Widget? widget=null, string? help_page=null
        ) {
            this.title = (owned) title;
            this.subtitle = (owned) subtitle;
            this.has_widget = widget != null;
            if (widget != null) {
                var scroll = new Gtk.ScrolledWindow(null, null);
                widget.show();
                scroll.add(widget);
                scroll.vexpand = true;
                scroll.hexpand = false;
                scroll.halign = Gtk.Align.FILL;
                scroll.show();
                this.widget = scroll;
            }
            if (help_page != null) {
                this.help_url = create_help_url(help_page);
                has_help = true;
            }
        }

        public override Gtk.Widget? get_widget() {
            return widget;
        }

        public override unowned string get_title() {
            return title;
        }

        public override unowned string? get_subtitle() {
            return subtitle;
        }

        public override unowned string? get_help_url() {
            return help_url;
        }
    }

    public class SelectorGroup {
        public string? title;
        public SList<Panel> panels;

        public SelectorGroup(owned string? title, owned SList<Panel>? panels = null) {
            this.title = (owned) title;
            this.panels = (owned) panels;
        }

        public void add(Panel panel) {
            panels.append(panel);
        }

        public virtual int sort_list_box(Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
            return 0;
        }
    }

    public class Row : Gtk.ListBoxRow {
        public Panel panel {get; construct;}
        private unowned Gtk.Switch? toggle;
        private unowned Gtk.Label label;
        private unowned Gtk.Button? help_button;
        private unowned Gtk.Button? widget_button;
        private Gtk.Grid grid;

        public Row(Panel panel) {
            GLib.Object(panel: panel);
        }

        construct {
            panel.notify.connect_after(on_notify);
            grid = new Gtk.Grid();
            grid.margin = 10;
            grid.column_spacing = 15;
            grid.orientation = Gtk.Orientation.HORIZONTAL;
            create_toggle();
            create_label();
            create_help_button();
            create_widget_button();
            grid.show();
            add(grid);
        }

        public signal void open_help(Panel panel);

        private void create_label() {
            Gtk.Label? label = this.label;
            if (label == null) {
                unowned string title = panel.get_title();
                unowned string? subtitle = panel.get_subtitle();
                if (subtitle != null) {
                    label = new Gtk.Label(Markup.printf_escaped(
                        "<span size='medium'><b>%s</b></span>\n<span size='small'>%s</span>", title, subtitle));
                } else {
                    label = new Gtk.Label(Markup.printf_escaped(
                        "<span size='medium'><b>%s</b></span>", title));
                }
                label.use_markup = true;
                label.sensitive = panel.is_available;
                label.vexpand = false;
                label.hexpand = true;
                label.halign = Gtk.Align.START;
                ((Gtk.Misc) label).yalign = 0.0f;
                ((Gtk.Misc) label).xalign = 0.0f;
                label.set_line_wrap(true);
                label.show();
                this.label = label;
                grid.attach(label, 1, 0, 1, 1);
            }
            label.sensitive = panel.is_available;
        }

        private void create_toggle() {
            Gtk.Switch? toggle = this.toggle;
            if (panel.is_toggle) {
                if (toggle == null) {
                    toggle = new Gtk.Switch();
                    this.toggle = toggle;
                    toggle.vexpand = toggle.hexpand = false;
                    toggle.halign = toggle.valign = Gtk.Align.CENTER;
                    toggle.show();
                    grid.attach(toggle, 0, 0, 1, 1);
                    toggle.notify.connect_after(on_toggle_notify);
                }
                if (panel.is_available) {
                    toggle.sensitive = true;
                    if (toggle.active != panel.is_enabled) {
                        toggle.active = panel.is_enabled;
                    }
                } else {
                    toggle.active = false;
                    toggle.sensitive = false;
                }
            } else if (toggle != null) {
                grid.remove(toggle);
                this.toggle = null;
            }
        }

        private void create_help_button() {
            Gtk.Button? button = this.help_button;
            if (panel.has_help) {
                if (button == null) {
                    button = new Gtk.Button.from_icon_name("system-help-symbolic");
                    button.vexpand = button.hexpand = false;
                    button.halign = button.valign = Gtk.Align.CENTER;
                    button.clicked.connect(on_help_button_clicked);
                    button.show();
                    this.help_button = button;
                    grid.attach(button, 3, 0, 1, 1);
                }
            } else if (button != null) {
                grid.remove(button);
                button.clicked.disconnect(on_help_button_clicked);
                this.help_button = null;
            }
        }

        private void create_widget_button() {
            Gtk.Button? button = this.widget_button;
            if (panel.has_widget || panel.has_alert) {
                if (button == null) {
                    button = new Gtk.Button.from_icon_name(
                        panel.has_alert ? "dialog-warning-symbolic" : panel.widget_icon);
                    button.vexpand = button.hexpand = false;
                    button.halign = button.valign = Gtk.Align.CENTER;
                    button.clicked.connect(on_widget_button_clicked);
                    button.show();
                    grid.attach(button, 2, 0, 1, 1);
                    this.widget_button = button;
                } else {
                    var image = (Gtk.Image) button.image;
                    image.icon_name = panel.has_alert ? "dialog-warning-symbolic" : panel.widget_icon;
                }
                bool sensitive = panel.has_alert || panel.is_available && panel.is_enabled;
                button.sensitive = sensitive;
                activatable = sensitive;
            } else {
                activatable = false;
                if (button != null) {
                    button.clicked.disconnect(on_widget_button_clicked);
                    grid.remove(button);
                    this.widget_button = null;
                }
            }
        }

        private void on_widget_button_clicked(Gtk.Button button) {
            activate();
        }

        private void on_help_button_clicked(Gtk.Button button) {
            open_help(panel);
        }

        private void on_notify(GLib.Object emitter, ParamSpec param) {
            switch (param.name) {
            case "is-enabled":
            case "is-available":
                create_toggle();
                create_label();
                create_widget_button();
                ((Gtk.ListBox) get_parent()).invalidate_sort();
                break;
            case "has-widget":
            case "has-alert":
            case "widget-icon":
                create_widget_button();
                break;
            case "has-help":
                create_help_button();
                break;
            }

        }

        private void on_toggle_notify(GLib.Object emitter, ParamSpec param) {
            switch (param.name) {
            case "active":
                panel.is_enabled = toggle.active;
                break;
            }

        }
    }
}

} // namespace Nuvola
