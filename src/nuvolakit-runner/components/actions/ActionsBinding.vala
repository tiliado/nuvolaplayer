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

/**
 * ActionBinding provides IPC API binding for actions to be avalable for other processes.
 * The obvious example is the Nuvola Player Controller (nuvolaplayer3ctl) using the actions
 * to control playback (e.g. play, pause, skip to the next song, etc.).
 */
public class Nuvola.ActionsBinding: ObjectBinding<ActionsInterface>
{
    public ActionsBinding(Drt.RpcRouter router, WebWorker web_worker)
    {
        base(router, web_worker, "Nuvola.Actions");
    }

    protected override void bind_methods()
    {
        bind("add-action", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Add a new action.",
            handle_add_action, {
            new Drt.StringParam("group", true, false, null, "Action group"),
            new Drt.StringParam("scope", true, false, null, "Action scope, use `win` for window-specific actions (preferred) or `app` for app-specific actions."),
            new Drt.StringParam("name", true, false, null, "Action name, should be in `dash-separated-lower-case`, e.g. `toggle-play`."),
            new Drt.StringParam("label", false, true, null, "Action label shown in user interface, e.g. `Play`."),
            new Drt.StringParam("mnemo_label", false, true, null, "Action label shown in user interface with keyboard navigation using Alt key and letter prefixed with underscore, e.g. Alt+p for `_Play`."),
            new Drt.StringParam("icon", false, true, null, "Icon name for action."),
            new Drt.StringParam("keybinding", false, true, null, "in-app keyboard shortcut, e.g. `<ctrl>P`."),
            new Drt.VariantParam("state", false, true, null, "Action state - `null` for simple actions, `true/false` for toggle actions (on/off).")
        });
        bind("add-radio-action", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Add a new action.",
            handle_add_radio_action, {
            new Drt.StringParam("group", true, false, null, "Action group"),
            new Drt.StringParam("scope", true, false, null, "Action scope, use `win` for window-specific actions (preferred) or `app` for app-specific actions."),
            new Drt.StringParam("name", true, false, null, "Action name, should be in `dash-separated-lower-case`, e.g. `toggle-play`."),
            new Drt.VariantParam("state", true, false, null, "Initial state of the action. Must be one of states specified in the `options` array."),
            new Drt.VarArrayParam("options", true, false, null, "Array of options definition in form [`stateId`, `label`, `mnemo_label`, `icon`, `keybinding`]. The `stateId` is unique identifier (Number or String), other parameters are described in `add-action` method."),
        });
        bind("is-enabled", Drt.RpcFlags.READABLE,
            "Returns true if action is enabled.",
            handle_is_action_enabled, {
            new Drt.StringParam("name", true, false, null, "Action name"),
        });
        bind("set-enabled", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Sets whether action is enabled.",
            handle_action_set_enabled, {
            new Drt.StringParam("name", true, false, null, "Action name"),
            new Drt.BoolParam("enabled", true, null, "Enabled state")
        });
        bind("get-state", Drt.RpcFlags.READABLE,
            "Returns state of the action.",
            handle_action_get_state, {
            new Drt.StringParam("name", true, false, null, "Action name")
        });
        bind("set-state", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set state of the action.",
            handle_action_set_state, {
            new Drt.StringParam("name", true, false, null, "Action name"),
            new Drt.VariantParam("state", false, true, null, "Action state")
        });
        bind("activate", Drt.RpcFlags.WRITABLE,
            "Activates action",
            handle_action_activate, {
            new Drt.StringParam("name", true, false, null, "Action name"),
            new Drt.VariantParam("parameter", false, true, null, "Action parameter"),
        });
        bind("list-groups", Drt.RpcFlags.READABLE,
            "Lists action groups.",
            handle_list_groups, null);
        bind("list-group-actions", Drt.RpcFlags.READABLE,
            "Returns actions of the given group.",
            handle_list_group_actions, {
            new Drt.StringParam("name", true, false, null, "Group name")
        });
    }

    protected override void object_added(ActionsInterface object)
    {
        object.custom_action_activated.connect(on_custom_action_activated);
    }

    protected override void object_removed(ActionsInterface object)
    {
        object.custom_action_activated.disconnect(on_custom_action_activated);
    }

    private void handle_add_action(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var group = request.pop_string();
        var scope = request.pop_string();
        var action_name = request.pop_string();
        var label = request.pop_string();
        var mnemo_label = request.pop_string();
        var icon = request.pop_string();
        var keybinding = request.pop_string();
        var state = request.pop_variant();
        if (state != null && state.get_type_string() == "mv")
            state = null;
        foreach (var object in objects)
            if (object.add_action(group, scope, action_name, label, mnemo_label, icon, keybinding, state))
                break;
        request.respond(null);
    }

    private void handle_add_radio_action(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var group = request.pop_string();
        var scope = request.pop_string();
        var action_name = request.pop_string();
        var state = request.pop_variant();
        var options_iter = request.pop_variant_array();
        string? label = null;
        string? mnemo_label = null;
        string? icon = null;
        string? keybinding = null;
        Variant? parameter = null;
        Drtgtk.RadioOption[] options = new Drtgtk.RadioOption[options_iter.n_children()];
        var i = 0;
        Variant? array = null;
        while (options_iter.next("v", &array))
        {
            Variant? value = array.get_child_value(0);
            parameter = value.get_variant();
            array.get_child(1, "v", &value);
            label = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
            array.get_child(2, "v", &value);
            mnemo_label = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
            array.get_child(3, "v", &value);
            icon = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
            array.get_child(4, "v", &value);
            keybinding = value.is_of_type(VariantType.STRING) ? value.get_string() : null;
            options[i++] = new Drtgtk.RadioOption(parameter, label, mnemo_label, icon, keybinding);
        }
        foreach (var object in objects)
            if (object.add_radio_action(group, scope, action_name, state, options))
                break;
        request.respond(null);
    }

    private void handle_is_action_enabled(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        string action_name = request.pop_string();
        bool enabled = false;
        foreach (var object in objects)
            if (object.is_enabled(action_name, ref enabled))
                break;
        request.respond(new Variant.boolean(enabled));
    }

    private void handle_action_set_enabled(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var action_name = request.pop_string();
        var enabled = request.pop_bool();
        foreach (var object in objects)
            if (object.set_enabled(action_name, enabled))
                break;
        request.respond(null);
    }

    private void handle_action_get_state(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var action_name = request.pop_string();
        Variant? state = null;
        foreach (var object in objects)
            if (object.get_state(action_name, ref state))
                break;
        request.respond(state);
    }

    private void handle_action_set_state(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var action_name = request.pop_string();
        var state = request.pop_variant();
        foreach (var object in objects)
            if (object.set_state(action_name, state))
                break;
        request.respond(null);
    }

    private void handle_action_activate(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        string action_name = request.pop_string();
        Variant? parameter = request.pop_variant();
        bool handled = false;
        foreach (var object in objects)
            if (handled = object.activate(action_name, parameter))
                break;

        request.respond(new Variant.boolean(handled));
    }

    private void handle_list_groups(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var groups_set = new GenericSet<string>(str_hash, str_equal);
        foreach (var object in objects)
        {
            List<unowned string> groups_list;
            var done = object.list_groups(out groups_list);
            foreach (var group in groups_list)
                groups_set.add(group);

            if (done)
                break;
        }
        var builder = new VariantBuilder(new VariantType ("as"));
        var groups = groups_set.get_values();
        foreach (var name in groups)
            builder.add_value(new Variant.string(name));
        request.respond(builder.end());
    }

    private void handle_list_group_actions(Drt.RpcRequest request) throws Drt.RpcError
    {
        check_not_empty();
        var group_name = request.pop_string();
        var builder = new VariantBuilder(new VariantType("aa{sv}"));
        foreach (var object in objects)
        {
            SList<Drtgtk.Action> actions_list;
            var done = object.list_group_actions(group_name, out actions_list);
            foreach (var action in actions_list)
            {
                builder.open(new VariantType("a{sv}"));
                builder.add("{sv}", "name", new Variant.string(action.name));
                builder.add("{sv}", "label", new Variant.string(action.label ?? ""));
                builder.add("{sv}", "enabled", new Variant.boolean(action.enabled));
                var radio = action as Drtgtk.RadioAction;
                if (radio != null)
                {
                    var radio_builder = new VariantBuilder(new VariantType("aa{sv}"));
                    foreach (var option in radio.get_options())
                    {
                        radio_builder.open(new VariantType("a{sv}"));
                        radio_builder.add("{sv}", "param", option.parameter);
                        radio_builder.add("{sv}", "label", new Variant.string(option.label ?? ""));
                        radio_builder.close();
                    }
                    builder.add("{sv}", "options", radio_builder.end());
                }
                builder.close();
            }
            if (done)
                break;
        }
        request.respond(builder.end());
    }

    private void on_custom_action_activated(string name, Variant? parameter)
    {
        try
        {
            var payload = new Variant("(ssmv)", "ActionActivated", name, parameter);
            call_web_worker("Nuvola.actions.emit", ref payload);
        }
        catch (GLib.Error e)
        {
            warning("Communication failed: %s", e.message);
        }
    }
}
