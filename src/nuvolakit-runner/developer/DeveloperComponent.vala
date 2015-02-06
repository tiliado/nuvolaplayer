/*
 * Copyright 2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class DeveloperComponent: Component
{
	private Bindings bindings;
	private RunnerApplication app;
	private DeveloperSidebar? sidebar = null;
	
	public DeveloperComponent(RunnerApplication app, Bindings bindings, Diorite.KeyValueStorage config)
	{
		base("developer", "Developer's tools", "Enables developer's sidebar ");
		this.bindings = bindings;
		this.app = app;
		config.bind_object_property("component.%s.".printf(id), this, "enabled").set_default(true).update_property();
		enabled_set = true;
		if (enabled)
			activate();
	}
	
	protected override void activate()
	{
		sidebar = new DeveloperSidebar(app, bindings.get_model<MediaPlayerModel>());
		app.main_window.sidebar.add_page("developersidebar", _("Developer"), sidebar);
	}
	
	protected override void deactivate()
	{
		app.main_window.sidebar.remove_page(sidebar);
		sidebar = null;
	}
}

} // namespace Nuvola
