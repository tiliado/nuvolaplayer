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

public class Nuvola.NotificationsComponent: Component
{
	private SList<NotificationsInterface> objects = null;
	private Diorite.Ipc.MessageServer server;
	
	public NotificationsComponent(Diorite.Ipc.MessageServer server, WebEngine web_engine)
	{
		base(server, web_engine, "Nuvola.Notifications");
		bind("showNotification", handle_show_notification);
	}
	
	public override bool add(GLib.Object object)
	{
		var notifier = object as NotificationsInterface;
		if (notifier == null)
			return false;
			
		objects.prepend(notifier);
		return true;
	}
	
	private Variant? handle_show_notification(Diorite.Ipc.MessageServer server, Variant? data) throws Diorite.Ipc.MessageError
	{
		Diorite.Ipc.MessageServer.check_type_str(data, "(ssssb)");
		string summary = null;
		string body = null;
		string icon_name = null;
		string icon_path = null;
		bool force = false;
		data.get("(ssssb)", &summary, &body, &icon_name, &icon_path, &force);
		
		foreach (var object in objects)
			object.show_anonymous(summary, body, icon_name, icon_path, force);
		
		return null;
	}
}
