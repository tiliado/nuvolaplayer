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

public interface Nuvola.ActionsInterface: GLib.Object {
    public signal void custom_action_activated(string name, Variant? parameter);

    public abstract bool activate(string name, Variant? parameter=null);

    public abstract bool set_state(string name, Variant? state);

    public abstract bool get_state(string name, ref Variant? state);

    public abstract bool is_enabled(string action_name, ref bool enabled);

    public abstract bool set_enabled(string action_name, bool enabled);

    public abstract bool add_action(string group, string scope, string action_name, string? label, string? mnemo_label, string? icon, string? keybinding, Variant? state);

    public abstract bool add_radio_action(string group, string scope, string name, Variant state, Drtgtk.RadioOption[] options);

    public abstract bool list_groups(out List<unowned string> groups);

    public abstract bool list_group_actions(string group, out SList<Drtgtk.Action> actions);
}
