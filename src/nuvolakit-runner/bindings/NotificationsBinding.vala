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

public class Nuvola.NotificationsBinding: ObjectBinding<NotificationsInterface>
{
	public NotificationsBinding(Drt.ApiRouter router, WebWorker web_worker)
	{
		base(router, web_worker, "Nuvola.Notifications");
	}
	
	protected override void bind_methods()
	{
		bind2("show-notification", Drt.ApiFlags.WRITABLE,
			"Show notification.",
			handle_show_notification, {
			new Drt.StringParam("title", true, false, null, "Notification title."),
			new Drt.StringParam("message", true, false, null, "Notification message."),
			new Drt.StringParam("icon-name", false, true, null, "Notification icon name."),
			new Drt.StringParam("icon-path", false, true, null, "Notification icon path."),
			new Drt.BoolParam("force", false, false, "Make sure the notification is shown."),
			new Drt.StringParam("category", true, false, null, "Notification category.")
		});
		bind2("is-persistence-supported", Drt.ApiFlags.READABLE,
			"returns true if persistence is supported.",
			handle_is_persistence_supported, null);
	}
	
	private Variant? handle_show_notification(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		var title = params.pop_string();
		var message = params.pop_string();
		var icon_name = params.pop_string();
		var icon_path = params.pop_string();
		var force = params.pop_bool();
		var category = params.pop_string();
		foreach (var object in objects)
			if (object.show_anonymous(title, message, icon_name, icon_path, force, category))
				break;
		return null;
	}
	
	private Variant? handle_is_persistence_supported(Drt.ApiParams? params) throws Diorite.MessageError
	{
		check_not_empty();
		bool supported = false;
		foreach (var object in objects)
			if (object.is_persistence_supported(ref supported))
				break;
		return new Variant.boolean(supported);
	}
}
