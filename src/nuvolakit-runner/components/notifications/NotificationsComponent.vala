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

public class NotificationsComponent: Component
{
	private Bindings bindings;
	private AppRunnerController app;
	private ActionsHelper actions_helper;
	private Notifications? notifications = null;
	
	
	public NotificationsComponent(AppRunnerController app, Bindings bindings, ActionsHelper actions_helper)
	{
		base("notifications", "Notifications", "Shows desktop notifications.");
		this.bindings = bindings;
		this.actions_helper = actions_helper;
		this.app = app;
		app.config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(false).update_property();
	}
	
	protected override bool activate()
	{
		notifications = new Notifications(app, actions_helper);
		notifications.start();
		bindings.add_object(notifications);
		return true;
	}
	
	protected override bool deactivate()
	{
		bindings.remove_object(notifications);
		notifications.stop();
		notifications = null;
		return true;
	}
}

} // namespace Nuvola
