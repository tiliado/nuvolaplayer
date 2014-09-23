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

public class Nuvola.LauncherComponent: GLib.Object, Component
{
	private SList<LauncherInterface> objects = null;
	private Diorite.Ipc.MessageServer server;
	
	public LauncherComponent(ComponentsManager manager, Diorite.Ipc.MessageServer server)
	{
		this.server = server;
		server.add_handler("Nuvola.Launcher.setTooltip", handle_set_tooltip);
		server.add_handler("Nuvola.Launcher.setActions", handle_set_actions);
		server.add_handler("Nuvola.Launcher.addAction", handle_add_action);
		server.add_handler("Nuvola.Launcher.removeAction", handle_remove_action);
		server.add_handler("Nuvola.Launcher.removeActions", handle_remove_actions);
	}
	
	~Launcher()
	{
		server.remove_handler("Nuvola.Launcher.setTooltip");
		server.remove_handler("Nuvola.Launcher.setActions");
		server.remove_handler("Nuvola.Launcher.addAction");
		server.remove_handler("Nuvola.Launcher.removeAction");
		server.remove_handler("Nuvola.Launcher.removeActions");
	}
	
	public bool add(GLib.Object object)
	{
		var launcher = object as LauncherInterface;
		if (launcher == null)
			return false;
			
		objects.prepend(launcher);
		return true;
	}
	
	private Variant? handle_set_tooltip(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string text;
		data.get("(s)", out text);
		
		foreach (var object in objects)
			object.set_tooltip(text);
		
		return null;
	}
	
	private Variant? handle_add_action(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string name;
		data.get("(s)", out name);
		
		foreach (var object in objects)
			object.add_action(name);
		
		return null;
	}
	
	private Variant? handle_remove_action(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string name;
		data.get("(s)", out name);
		
		foreach (var object in objects)
			object.remove_action(name);
		
		return null;
	}
	
	private Variant? handle_set_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(av)");
		
		int i = 0;
		VariantIter iter = null;
		data.get("(av)", &iter);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		foreach (var object in objects)
			object.set_actions(actions);
		
		return null;
	}
	
	private Variant? handle_remove_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, null);
		foreach (var object in objects)
			object.remove_actions();
		
		return null;
	}
}
