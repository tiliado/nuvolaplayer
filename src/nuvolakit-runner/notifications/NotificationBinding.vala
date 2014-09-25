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

public class Nuvola.NotificationBinding: Binding<NotificationInterface>
{
	public NotificationBinding(Diorite.Ipc.MessageServer server, WebEngine web_engine)
	{
		base(server, web_engine, "Nuvola.Notification");
		bind("update", handle_update);
		bind("setActions", handle_set_actions);
		bind("removeActions", handle_remove_actions);
		bind("show", handle_show);
	}
	
	private Variant? handle_update(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sssssb)");
		string name = null;
		string title = null;
		string message = null;
		string icon_name = null;
		string icon_path = null;
		bool resident = false;
		data.get("(sssssb)", &name, &title, &message, &icon_name, &icon_path);
		
		foreach (var object in objects)
			object.update(name, title, message, icon_name, icon_path, resident);
		
		return null;
	}
	
	private Variant? handle_set_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sav)");
		
		string name = null;
		int i = 0;
		VariantIter iter = null;
		data.get("(sav)", &name, &iter);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		foreach (var object in objects)
			object.set_actions(name, (owned) actions);
		
		return null;
	}
	
	private Variant? handle_remove_actions(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(s)");
		string name = null;
		data.get("(s)", &name);
		
		foreach (var object in objects)
			object.remove_actions(name);
		
		return null;
	}
	
	private Variant? handle_show(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(sb)");
		string name = null;
		bool force = false;
		data.get("(sb)", &name, &force);
		
		foreach (var object in objects)
			object.show(name, force);
		
		return null;
	}
}
