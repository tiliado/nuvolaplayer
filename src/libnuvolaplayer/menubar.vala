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

public class MenuBar
{
	private Diorite.ActionsRegistry actions_reg;
	private bool export_app_menu;
	private HashTable<string, SubMenu> menus;
	
	public MenuBar(Diorite.ActionsRegistry actions_reg, bool export_app_menu)
	{
		this.actions_reg = actions_reg;
		this.export_app_menu = export_app_menu;
		this.menus = new HashTable<string, SubMenu>(str_hash, str_equal);
	}
	
	public void set_up(Gtk.Application app)
	{
		var menubar = new Menu();
		var app_menu = actions_reg.build_menu({Actions.QUIT}, true, false);
		if (export_app_menu)
		{
			app.set_app_menu(app_menu);
		}
		else
		{
			menubar.append_submenu("_Application", app_menu);
			app.set_app_menu(null);
		}
		var submenus = menus.get_values();
		foreach (var submenu in submenus)
			submenu.append_to_menu(actions_reg, menubar);
		app.set_menubar(menubar);
	}
	
	public void set(string id, SubMenu submenu)
	{
		menus.replace(id, submenu);
	}
}

public class SubMenu
{
	public string label {get; private set;}
	private string[] actions;
	
	public SubMenu(string label, string[] actions)
	{
		this.label = label;
		this.actions = actions;
	}
	
	public void append_to_menu(Diorite.ActionsRegistry actions_reg, Menu menu)
	{
		menu.append_submenu(label, actions_reg.build_menu(actions, true, false));
	}
}

} // namespace Nuvola
