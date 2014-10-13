/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class XKeyGrabber: GLib.Object
{
	
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
	
	private HashTable<string, uint> keybindings;
	
	public  XKeyGrabber()
	{
		keybindings = new HashTable<string, uint>(str_hash, str_equal);
		var root_window = Gdk.get_default_root_window() as Gdk.X11.Window;
		return_if_fail(root_window != null);
		root_window.add_filter(event_filter);
	}
	
	public signal void keybinding_pressed(string accelerator, uint32 time);
	
	public bool is_grabbed(string accelerator)
	{
		return accelerator in keybindings;
	}
	
	public bool grab(string accelerator, bool allow_multiple)
	{ 
		if (is_grabbed(accelerator))
		{
			if (!allow_multiple)
				return false;
			
			var count = keybindings[accelerator] + 1;
			keybindings[accelerator] = count;
			debug("Grabbed %s, count %u", accelerator, count);
			return true;
		}
		
		if (!grab_ungrab(true, accelerator))
			return false;
		
		keybindings[accelerator] = 1;
		debug("Grabbed %s, count %d", accelerator, 1);
		return true;
	}
	
	public bool ungrab(string accelerator)
	{
		if (!is_grabbed(accelerator))
			return false;
		
		var count = keybindings[accelerator] - 1;
		if (count > 0)
		{
			keybindings[accelerator] = count;
			debug("Ungrabbed %s, count %u", accelerator, count);
			return true;
		}
		
		if (!grab_ungrab(false, accelerator))
			return false;
		
		keybindings.remove(accelerator);
		debug("Ungrabbed %s, count %u", accelerator, count);
		return true;
	}
	
	private bool grab_ungrab(bool grab, string accelerator)
	{
		uint keysym;
		Gdk.ModifierType modifiers;
		Gtk.accelerator_parse(accelerator, out keysym, out modifiers);
		return_val_if_fail(keysym != 0, false);
		
		/* Translate virtual modifiers (SUPER, etc.) to real modifiers (Mod2, etc.) */
		var keymap = Gdk.Keymap.get_default();
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
		var keycode = display.keysym_to_keycode(keysym);            
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
			/* Ignore keyboard state mods, but preserve shift (e.g. in Super+Shift+t) */
			keymap.translate_keyboard_state(xevent->xkey.keycode, event_mods, 0, out keyval, null, null, out keyboard_state_mods);
			event_mods &= ~(keyboard_state_mods & ~Gdk.ModifierType.SHIFT_MASK);
			/* Expand real modifiers to virtual modifiers (SUPER, etc.) */
			keymap.add_virtual_modifiers(ref event_mods);
			/* Ignore insignificant modifiers */
			event_mods &= Gtk.accelerator_get_default_mod_mask();
			/* SUPER + HYPER => SUPER */
			if ((event_mods & (Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.HYPER_MASK)) != 0)
				event_mods &= ~Gdk.ModifierType.HYPER_MASK;
			
			var accelerator = Gtk.accelerator_name(keyval, event_mods);
			if (is_grabbed(accelerator))
				keybinding_pressed(accelerator, gdk_event.get_time());
			else
				warning("Unknown keybinding %s", accelerator);
		}
		return Gdk.FilterReturn.CONTINUE;
	}
}

} // namespace Nuvola
