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

public class MenuBar: GLib.Object, MenuBarInterface
{
    private unowned Drtgtk.Application app;
    private HashTable<string, SubMenu> menus;

    public MenuBar(Drtgtk.Application app)
    {
        this.app = app;
        this.menus = new HashTable<string, SubMenu>(str_hash, str_equal);
    }

    public void update()
    {
        var menubar = app.reset_menubar();
        var submenus = menus.get_keys();
        submenus.sort(strcmp);
        foreach (var submenu in submenus)
        menus[submenu].append_to_menu(app.actions, menubar);
    }

    public void set_submenu(string id, SubMenu submenu)
    {
        menus[id] = submenu;
    }

    public bool set_menu(string id, string label, string[] actions)
    {
        set_submenu(id, new SubMenu(label, actions));
        update();
        return !Binding.CONTINUE;
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

    public void append_to_menu(Drtgtk.Actions actions, Menu menu)
    {
        menu.append_submenu(label, actions.build_menu(this.actions, true, false));
    }
}

} // namespace Nuvola
