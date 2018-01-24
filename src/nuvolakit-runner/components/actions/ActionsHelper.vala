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

public class Nuvola.ActionsHelper: GLib.Object, ActionsInterface
{
    private Drtgtk.Actions actions;
    private Config config;

    public ActionsHelper(Drtgtk.Actions actions, Config config)
    {
        this.actions = actions;
        this.config = config;
    }

    public bool activate(string action_name, Variant? parameter=null)
    {
        var action = actions.get_action(action_name);
        if (action == null)
        return Binding.CONTINUE;

        action.activate(parameter);
        return !Binding.CONTINUE;
    }

    public bool set_state(string action_name, Variant? state)
    {
        var action = actions.get_action(action_name);
        if (action == null)
        return Binding.CONTINUE;

        action.state = state;
        return !Binding.CONTINUE;
    }

    public bool get_state(string action_name, ref Variant? state)
    {
        var action = actions.get_action(action_name);
        if (action == null)
        return Binding.CONTINUE;

        state = action.state;
        return !Binding.CONTINUE;
    }

    public bool is_enabled(string action_name, ref bool enabled)
    {
        var action = actions.get_action(action_name);
        if (action == null)
        return Binding.CONTINUE;

        enabled = action.enabled;
        return !Binding.CONTINUE;
    }

    public bool set_enabled(string action_name, bool enabled)
    {
        var action = actions.get_action(action_name);
        if (action == null)
        return Binding.CONTINUE;

        if (action.enabled != enabled)
        action.enabled = enabled;
        return Binding.CONTINUE;
    }

    public bool add_action(string group, string scope, string action_name, string? label, string? mnemo_label, string? icon, string? keybinding, Variant? state)
    {
        Drtgtk.Action action;
        if (state == null)
        action = simple_action(group, scope, action_name, label, mnemo_label, icon, keybinding, null);
        else
        action = toggle_action(group, scope, action_name, label, mnemo_label, icon, keybinding, null, state);

        action.enabled = false;
        action.activated.connect(on_custom_action_activated);
        actions.add_action(action);
        return !Binding.CONTINUE;
    }

    public bool add_radio_action(string group, string scope, string name, Variant state, Drtgtk.RadioOption[] options)
    {
        var radio = new Drtgtk.RadioAction(group, scope, name, null, state, options);
        radio.enabled = false;
        radio.activated.connect(on_custom_action_activated);
        actions.add_action(radio);
        return !Binding.CONTINUE;
    }

    public Drtgtk.SimpleAction simple_action(string group, string scope, string name, string? label, string? mnemo_label, string? icon, string? keybinding, owned Drtgtk.ActionCallback? callback)
    {
        var kbd = config.get_string("nuvola.keybindings." + name) ?? keybinding;
        if (kbd == "")
        kbd = null;
        return new Drtgtk.SimpleAction(group, scope, name, label, mnemo_label, icon, kbd, (owned) callback);
    }

    public Drtgtk.ToggleAction toggle_action(string group, string scope, string name, string? label, string? mnemo_label, string? icon, string? keybinding, owned Drtgtk.ActionCallback? callback, Variant state)
    {
        var kbd = config.get_string("nuvola.keybindings." + name) ?? keybinding;
        return new Drtgtk.ToggleAction(group, scope, name, label, mnemo_label, icon, kbd, (owned) callback, state);
    }

    private void on_custom_action_activated(Drtgtk.Action action, Variant? parameter)
    {
        custom_action_activated(action.name, parameter);
    }

    public bool list_groups(out List<unowned string> groups)
    {
        groups = actions.list_groups();
        return Binding.CONTINUE;
    }

    public bool list_group_actions(string group, out SList<Drtgtk.Action> actions)
    {
        actions = this.actions.get_group(group);
        return Binding.CONTINUE;
    }
}
