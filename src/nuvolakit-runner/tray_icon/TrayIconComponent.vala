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

public class TrayIconComponent: Component
{
	private AppRunnerController controller;
	private Bindings bindings;
	private TrayIcon tray_icon = null;
	
	public TrayIconComponent(AppRunnerController controller, Bindings bindings, Diorite.KeyValueStorage config)
	{
		base("tray_icon", "Tray Icon", "Small icon with menu shown in the notification area.");
		this.bindings = bindings;
		this.controller = controller;
		var enabled_key = "component.tray_icon.enabled";
		
		if (config.has_key(enabled_key))
		{
			config.bind_object_property(enabled_key, this, "enabled").update_property();
			enabled_set = true;
			if (enabled)
				activate();
		}
		else
		{
			uint watch_id = 0;
			watch_id = Bus.watch_name(BusType.SESSION, "org.gnome.Shell", BusNameWatcherFlags.NONE,
				() =>
				{
					toggle(false);
					enabled_set = true;
					config.bind_object_property(enabled_key, this, "enabled");
					Bus.unwatch_name(watch_id);
				},
				() =>
				{
					toggle(true);
					enabled_set = true;
					config.bind_object_property(enabled_key, this, "enabled");
					Bus.unwatch_name(watch_id);
				});
		}
	}
	
	public override void toggle(bool enabled)
	{
		if (this.enabled != enabled)
		{
			if (enabled)
				activate();
			else
				deactivate();
		}
		
		this.enabled = enabled;
	}
	
	private void activate()
	{
		tray_icon = new TrayIcon(controller, bindings.get_model<LauncherModel>());
	}
	
	private void deactivate()
	{
		tray_icon = null;
	}
}

} // namespace Nuvola
