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

namespace Nuvola
{

public class GlobalKeybinder: GLib.Object
{
    public delegate void HandlerFunc(string accelerator, Gdk.Event event);

    private List<Keybinding> keybindings = null;
    private static Gdk.ModifierType[] lock_modifiers =
    {
        0,
        Gdk.ModifierType.MOD2_MASK, // NUM_LOCK
        Gdk.ModifierType.LOCK_MASK, // CAPS_LOCK
        Gdk.ModifierType.MOD5_MASK, // SCROLL_LOCK
        Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.LOCK_MASK,
        Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.MOD5_MASK,
        Gdk.ModifierType.LOCK_MASK|Gdk.ModifierType.MOD5_MASK,
        Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.LOCK_MASK|Gdk.ModifierType.MOD5_MASK
    };

    public GlobalKeybinder()
    {
        var root_window = Gdk.get_default_root_window() as Gdk.X11.Window;
        return_if_fail(root_window != null);
        root_window.add_filter(event_filter);
    }

    public bool is_bound(string accelerator)
    {
        foreach (var keybinding in keybindings)
            if (keybinding.accelerator == accelerator)
                return true;
        return false;
    }

    public bool bind(string accelerator, owned HandlerFunc handler)
    {
        int keycode;
        Gdk.ModifierType modifiers;
        if (!grab_ungrab(true, accelerator, out keycode, out modifiers))
            return false;

        var keybinding = new Keybinding(accelerator, keycode, modifiers, (owned) handler);
        keybindings.prepend(keybinding);
        return true;
    }

    public bool unbind(string accelerator)
    {
        if (!grab_ungrab(false, accelerator, null, null))
            return false;

        unowned List<Keybinding> iter = keybindings.first();
        while (iter != null)
        {
            unowned List<Keybinding> next = iter.next;
            var keybinding = iter.data;
            if (keybinding.accelerator == accelerator)
                keybindings.delete_link(iter);
            iter = next;
        }

        return true;
    }

    private bool grab_ungrab(bool grab, string accelerator, out int keycode, out Gdk.ModifierType virt_modifiers)
    {
        keycode = 0;
        virt_modifiers = 0;
        var bound = is_bound(accelerator);

        if (grab == bound)
            return true;

        uint keysym;
        Gtk.accelerator_parse(accelerator, out keysym, out virt_modifiers);
        return_val_if_fail(keysym != 0, false);

        /* Translate virtual modifiers (SUPER, etc.) to real modifiers (Mod2, etc.) */
        var keymap = Gdk.Keymap.get_default();
        Gdk.ModifierType modifiers = virt_modifiers;
        if (!keymap.map_virtual_modifiers(ref modifiers))
        {
            warning("Failed to map virtual modifiers.");
            return false;
        }

        var root_window = Gdk.get_default_root_window() as Gdk.X11.Window;
        return_val_if_fail(root_window != null, false);
        var gdk_display = root_window.get_display() as Gdk.X11.Display;
        return_val_if_fail(gdk_display != null, false);

        unowned X.Display display = gdk_display.get_xdisplay();
        X.ID xid = root_window.get_xid();
        keycode = display.keysym_to_keycode(keysym);
        return_val_if_fail(keycode != 0, false);
        Gdk.error_trap_push();

        foreach (Gdk.ModifierType lock_modifier in lock_modifiers)
        {
            if (grab)
                display.grab_key(keycode, modifiers|lock_modifier, xid, false, X.GrabMode.Async, X.GrabMode.Async);
            else
                display.ungrab_key(keycode, modifiers|lock_modifier, xid);
        }

        Gdk.flush();
        return Gdk.error_trap_pop() == 0;
    }

    private Gdk.FilterReturn event_filter(Gdk.XEvent gdk_xevent, Gdk.Event gdk_event)
    {
        X.Event* xevent = (X.Event*) gdk_xevent;
        if (xevent->type == X.EventType.KeyPress)
        {
            var keymap = Gdk.Keymap.get_default();
            Gdk.ModifierType event_mods = (Gdk.ModifierType) (xevent.xkey.state & ~lock_modifiers[7]);
            Gdk.ModifierType keyboard_state_mods;
            uint keyval;
            /* Ignore keyboard state mods */
            keymap.translate_keyboard_state(xevent->xkey.keycode, event_mods, 0, out keyval, null, null, out keyboard_state_mods);
            event_mods &= ~keyboard_state_mods;
            /* Expand real modifiers to virtual modifiers (SUPER, etc.) */
            keymap.add_virtual_modifiers(ref event_mods);
            /* Ignore insignificant modifiers */
            event_mods &= Gtk.accelerator_get_default_mod_mask();
            /* SUPER + HYPER => SUPER */
            if ((event_mods & (Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.HYPER_MASK)) != 0)
                event_mods &= ~Gdk.ModifierType.HYPER_MASK;

            foreach (var keybinding in keybindings)
            {
                if (xevent->xkey.keycode == keybinding.keycode && event_mods == keybinding.modifiers)
                    keybinding.handler(keybinding.accelerator, gdk_event);
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }

    private class Keybinding
    {
        public string accelerator {get; private set;}
        public int keycode {get; private set;}
        public unowned HandlerFunc handler {get; private set;}
        public Gdk.ModifierType modifiers {get; private set;}

        public Keybinding(string accelerator, int keycode, Gdk.ModifierType modifiers, owned HandlerFunc handler)
        {
            this.accelerator = accelerator;
            this.keycode = keycode;
            this.modifiers = modifiers;
            this.handler = (owned) handler;
        }
    }
}

} // namespace Nuvola
