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

public class Nuvola.NotificationBinding: ObjectBinding<NotificationInterface>
{
	public NotificationBinding(Diorite.Ipc.MessageServer server, WebWorker web_worker)
	{
		base(server, web_worker, "Nuvola.Notification");
	}
	
	protected override void bind_methods()
	{
		bind("update", "(sssssbs)", handle_update);
		bind("setActions", "(sav)", handle_set_actions);
		bind("removeActions", "(s)", handle_remove_actions);
		bind("show", "(sb)", handle_show);
	}
	
	private Variant? handle_update(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		check_not_empty();
		string name = null;
		string title = null;
		string message = null;
		string icon_name = null;
		string icon_path = null;
		bool resident = false;
		string? category = null;
		data.get("(sssssbs)", &name, &title, &message, &icon_name, &icon_path, &resident, &category);
		
		foreach (var object in objects)
			if (object.update(name, title, message, icon_name, icon_path, resident, category))
				break;
		
		return null;
	}
	
	private Variant? handle_set_actions(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		check_not_empty();
		
		string name = null;
		int i = 0;
		VariantIter iter = null;
		data.get("(sav)", &name, &iter);
		string[] actions = new string[iter.n_children()];
		Variant item = null;
		while (iter.next("v", &item))
			actions[i++] = item.get_string();
		
		foreach (var object in objects)
			if (object.set_actions(name, (owned) actions))
				break;
		
		return null;
	}
	
	private Variant? handle_remove_actions(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		check_not_empty();
		string name = null;
		data.get("(s)", &name);
		
		foreach (var object in objects)
			if (object.remove_actions(name))
				break;
		
		return null;
	}
	
	private Variant? handle_show(GLib.Object source, Variant? data) throws Diorite.MessageError
	{
		check_not_empty();
		string name = null;
		bool force = false;
		data.get("(sb)", &name, &force);
		
		foreach (var object in objects)
			if (object.show(name, force))
				break;
		
		return null;
	}
}
