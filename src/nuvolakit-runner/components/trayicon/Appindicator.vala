/*
 * Copyright 2011-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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
#if APPINDICATOR
namespace Nuvola {

public class Appindicator: GLib.Object {
    public bool visible {get {return indicator != null && indicator.connected;}}
    private AppRunnerController controller;
    private Drtgtk.Actions actions;
    private LauncherModel model;
    private Gtk.Menu? menu = null;
    private AppIndicator.Indicator? indicator = null;
    private HashTable<string, Gtk.RadioMenuItem?> radio_groups = null;

    public Appindicator(AppRunnerController controller, LauncherModel model) {
        this.controller = controller;
        this.actions = controller.actions;
        this.model = model;
        model.notify.connect_after(on_model_changed);
        indicator = new AppIndicator.Indicator(
            controller.web_app.id, controller.icon, AppIndicator.IndicatorCategory.APPLICATION_STATUS);
        indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE);
        indicator.title = controller.app_name;
        create_menu();
    }

    private void on_model_changed(GLib.Object o, ParamSpec p) {
        switch (p.name) {
        case "actions":
            create_menu();
            break;
        }
    }

    ~Appindicator() {
        indicator = null;
        model.notify.disconnect(on_model_changed);
        menu = null;
        if (radio_groups != null) {
            clean_radio_groups();
        }
    }

    private void create_menu() {
        if (menu != null) {
            menu.@foreach((child) => {
                var item = child as Gtk.MenuItem;
                if (item != null) {
                    item.activate.disconnect(on_menu_item_activated);
                    var toggle_action =  item.get_data<Drtgtk.Action?>("diorite_action") as Drtgtk.ToggleAction;
                    if (toggle_action != null) {
                        toggle_action.notify["state"].disconnect(on_toggle_action_state_changed);
                    }
                }
            });
        }

        if (radio_groups == null) {
            radio_groups = new HashTable<string, Gtk.RadioMenuItem?>(str_hash, str_equal);
        } else {
            clean_radio_groups();
        }
        menu = new Gtk.Menu();
        add_menu_item_for_action("activate");
        foreach (string name in model.actions) {
            add_menu_item_for_action(name);
        }
        menu.show();
        indicator.set_menu(menu);
    }

    private void add_menu_item_for_action(string full_name) {
        Drtgtk.Action action = null;
        string? detailed_name = null;
        Drtgtk.RadioOption? option = null;
        if (!actions.find_and_parse_action(full_name, out detailed_name, out action, out option)) {
            warning("Action %s not found", full_name);
            return;
        }
        Gtk.MenuItem item;
        var radio_action = action as Drtgtk.RadioAction;
        var toggle_action = action as Drtgtk.ToggleAction;
        if (radio_action != null) {
            Gtk.RadioMenuItem radio_group = radio_groups[action.name];
            var radio_item = new Gtk.RadioMenuItem.with_label_from_widget(radio_group, option.label);
            if (radio_group == null) {
                radio_groups[action.name] = radio_item;
                action.notify["state"].connect_after(on_radio_action_state_changed);
            }
            radio_item.active = action.state != null && Drt.VariantUtils.equal(action.state, option.parameter);
            item = radio_item;
            item.set_data<Variant?>("diorite_action_param", option.parameter);
        } else if (toggle_action != null) {
            var check_item = new Gtk.CheckMenuItem.with_label(action.label);
            check_item.active = action.state.get_boolean();
            item = check_item;
            item.set_data<Variant?>("diorite_action_param", null);
            action.notify["state"].connect_after(on_toggle_action_state_changed);
        } else if (action is Drtgtk.SimpleAction) {
            item = new Gtk.MenuItem.with_label(action.label);
            item.set_data<Variant?>("diorite_action_param", null);
        } else {
            item = null;
            warning("%s %s is not supported yet.", action.get_type().name(), full_name);
            return;
        }

        item.set_data<Drtgtk.Action?>("diorite_action", action);
        item.activate.connect(on_menu_item_activated);
        action.bind_property("enabled", item, "sensitive", BindingFlags.DEFAULT|BindingFlags.SYNC_CREATE);
        item.show();
        menu.add(item);
    }

    private void clean_radio_groups() {
        HashTableIter<string, Gtk.RadioMenuItem> iter = HashTableIter<string, Gtk.RadioMenuItem>(radio_groups);
        unowned Gtk.RadioMenuItem item = null;
        while (iter.next(null, out item)) {
            Drtgtk.Action? action = item.get_data<Drtgtk.Action?>("diorite_action");
            action.notify["state"].disconnect(on_radio_action_state_changed);
            iter.remove();
        }
    }

    private void on_menu_item_activated(Gtk.MenuItem item) {
        Drtgtk.Action? action = item.get_data<Drtgtk.Action?>("diorite_action");
        if (action != null) {
            Variant? parameter = item.get_data<Variant?>("diorite_action_param");
            var radio_action = action as Drtgtk.RadioAction;
            var toggle_action = action as Drtgtk.ToggleAction;
            if (radio_action == null || !Drt.VariantUtils.equal(radio_action.state, parameter)) {
                action.activate(parameter);
            }
            if (toggle_action != null) {
                item.set_data<Drtgtk.Action?>("diorite_action", null);
                ((Gtk.CheckMenuItem) item).active = action.state.get_boolean();
                item.set_data<Drtgtk.Action?>("diorite_action", action);
            }
        }
    }

    private void on_radio_action_state_changed(GLib.Object emitter, ParamSpec p) {
        var action = emitter as Drtgtk.RadioAction;
        Variant? state = action.state;
        unowned SList<Gtk.RadioMenuItem> radios = radio_groups[action.name].get_group();

        /* Remove action from the currently active radio item to prevent it from emitting "activated" signal.*/
        Gtk.RadioMenuItem? prev_active_radio = null;
        foreach (Gtk.RadioMenuItem radio in radios) {
            if (radio.active) {
                prev_active_radio = radio;
                prev_active_radio.set_data<Drtgtk.Action?>("diorite_action", null);
                break;
            }
        }

        /* Mark the new active radio */
        foreach (Gtk.RadioMenuItem radio in radios) {
            if (Drt.VariantUtils.equal(state, radio.get_data<Variant?>("diorite_action_param"))) {
                radio.active = true;
                break;
            }
        }

        /* Restore action to the previously active radio */
        if (prev_active_radio != null) {
            prev_active_radio.set_data<Drtgtk.Action?>("diorite_action", action);
        }
    }

    private void on_toggle_action_state_changed(GLib.Object emitter, ParamSpec p) {
        var action = emitter as Drtgtk.ToggleAction;
        List<unowned Gtk.Widget> children = menu.get_children();
        foreach (var widget in children) {
            var toggle_item = widget as Gtk.CheckMenuItem;
            if (toggle_item != null && toggle_item.get_data<Drtgtk.Action?>("diorite_action") == action) {
                toggle_item.set_data<Drtgtk.Action?>("diorite_action", null);
                toggle_item.active = action.state.get_boolean();
                toggle_item.set_data<Drtgtk.Action?>("diorite_action", action);
                break;
            }
        }
    }
}

} // namespace Nuvola
#endif
