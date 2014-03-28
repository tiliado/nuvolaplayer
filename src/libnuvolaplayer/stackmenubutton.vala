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

public class StackMenuButton : Gtk.MenuButton
{
	private Gtk.Stack? _stack = null;
	public Gtk.Stack? stack
	{
		get
		{
			return _stack;
		}
		
		set
		{
			if (_stack != null)
			{
				_stack.notify["visible-child"].disconnect(on_stack_child_notify);
				_stack.add.disconnect(on_stack_updated);
				_stack.remove.disconnect(on_stack_updated);
				popup = null;
			}
			_stack = value;
			if (_stack != null)
			{
				_stack.notify["visible-child"].connect_after(on_stack_child_notify);
				_stack.add.connect_after(on_stack_updated);
				_stack.remove.connect_after(on_stack_updated);
				rebuild_cb();
			}
			update_label();
		}
	}
	
	private new Gtk.Label label;
	private Gtk.Menu? menu = null;
	
	public StackMenuButton(Gtk.Stack stack)
	{
		no_show_all = true;
		relief = Gtk.ReliefStyle.NONE;
		
		label = new Gtk.Label(null);
		label.hexpand = true;
		label.halign = Gtk.Align.CENTER;
		label.show();
		var text_attrs = new Pango.AttrList();
		text_attrs.change(Pango.attr_weight_new(Pango.Weight.BOLD));
		label.set_attributes(text_attrs);
		
		var arrow = new Gtk.Arrow(Gtk.ArrowType.DOWN, Gtk.ShadowType.NONE);
		arrow.margin = 2;
		arrow.show();
		
		var box = new Gtk.Grid();
		box.show();
		box.add(label);
		box.add(arrow);
		add(box);
		
		this.stack = stack;
	}
	
	private void append_item(Gtk.Widget child)
	{
		string name;
		string title;
		stack.child_get(child, "name", out name, "title", out title);
		var item = new Gtk.MenuItem.with_label(title);
		item.show();
		item.set_data<string>("page-name", name);
		item.activate.connect(on_item_activated);
		menu.add(item);
	}
	
	private void disconnect_item(Gtk.Widget child)
	{
		var item  = child as Gtk.MenuItem;
		if (item != null)
			item.activate.disconnect(on_item_activated);
	}
	
	private void on_stack_child_notify(GLib.Object o, ParamSpec p)
	{
		Idle.add(() => {update_label(); return false;});
	}
	
	private void on_stack_updated(Gtk.Widget child)
	{
		Idle.add(rebuild_cb);
	}
	
	private void on_item_activated(Gtk.MenuItem item)
	{
		stack.visible_child_name = item.get_data<string>("page-name");
	}
	
	private bool rebuild_cb()
	{
		if (menu != null)
			menu.@foreach(disconnect_item);
		menu = new Gtk.Menu();
		_stack.@foreach(append_item);
		popup = menu;
		return false;
	}
	
	private void update_label()
	{
		if (stack != null && stack.visible_child != null)
		{
			string text;
			var child = stack.visible_child;
			stack.child_get(child, "title", out text);
			label.label = text;
			show();
		}
		else
		{
			label.label = null;
			hide();
		}
	}
}

} // namespace Nuvola
