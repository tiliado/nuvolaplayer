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
	public NotificationBinding(Drt.ApiRouter router, WebWorker web_worker)
	{
		base(router, web_worker, "Nuvola.Notification");
	}
	
	protected override void bind_methods()
	{
		bind2("update", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Update notification.",
			handle_update, {
			new Drt.StringParam("name", true, false, null, "Notification name."),
			new Drt.StringParam("title", true, false, null, "Notification title."),
			new Drt.StringParam("message", true, false, null, "Notification message."),
			new Drt.StringParam("icon-name", false, true, null, "Notification icon name."),
			new Drt.StringParam("icon-path", false, true, null, "Notification icon path."),
			new Drt.BoolParam("resident", false, false, "Whether the notification is resident."),
			new Drt.StringParam("category", false, true, null, "Notification category."),
		});
		bind2("set-actions", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Set notification actions.",
			handle_set_actions, {
			new Drt.StringParam("name", true, false, null, "Notification name."),
			new Drt.StringArrayParam("actions", true, null, "Notification actions.")
		});
		bind2("remove-actions", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Remove notification actions.",
			handle_remove_actions, {
			new Drt.StringParam("name", true, false, null, "Notification name.")
		});
		bind2("show", Drt.ApiFlags.PRIVATE|Drt.ApiFlags.WRITABLE,
			"Show notification.",
			handle_show, {
			new Drt.StringParam("name", true, false, null, "Notification name."),
			new Drt.BoolParam("force", false, false, "Make sure the notification is shown.")
		});
	}
	
	private Variant? handle_update(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		var name = params.pop_string();
		var title = params.pop_string();
		var message = params.pop_string();
		var icon_name = params.pop_string();
		var icon_path = params.pop_string();
		var resident = params.pop_bool();
		var category = params.pop_string();
		foreach (var object in objects)
			if (object.update(name, title, message, icon_name, icon_path, resident, category))
				break;
		return null;
	}
	
	private Variant? handle_set_actions(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		var name = params.pop_string();
		var actions = params.pop_strv();
		foreach (var object in objects)
			if (object.set_actions(name, (owned) actions))
				break;
		return null;
	}
	
	private Variant? handle_remove_actions(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		var name = params.pop_string();
		foreach (var object in objects)
			if (object.remove_actions(name))
				break;
		return null;
	}
	
	private Variant? handle_show(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		var name = params.pop_string();
		var force = params.pop_bool();
		foreach (var object in objects)
			if (object.show(name, force))
				break;
		return null;
	}
}
