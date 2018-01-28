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

public class GlobalKeybindings: GLib.Object {
    public ActionsKeyBinder keybinder {get; private set;}
    private Drtgtk.Actions actions;

    public GlobalKeybindings(ActionsKeyBinder keybinder, Drtgtk.Actions actions) {
        this.keybinder = keybinder;
        this.actions = actions;

        keybinder.action_activated.connect(on_action_activated);
        actions.action_added.connect(update_action);
        actions.action_removed.connect(on_action_removed);
        foreach (Drtgtk.Action action in actions.list_actions())
        update_action(action);
    }

    private void update_action(Drtgtk.Action action) {
        if (!(action is Drtgtk.RadioAction))
        keybinder.bind(action.name);
    }

    private void on_action_removed(Drtgtk.Action action) {
        if (!(action is Drtgtk.RadioAction))
        keybinder.unbind(action.name);
    }

    private void on_action_activated(string name, ref bool handled) {
        if (handled)
        return;

        Drtgtk.Action? action = actions.get_action(name);
        return_if_fail(action != null);
        action.activate(null);
        handled = true;
    }
}

} // namespace Nuvola
